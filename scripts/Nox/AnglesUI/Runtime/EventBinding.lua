--- AnglesUI Event Binding Runtime.
--- Handles `(eventName)="Func()"` event bindings on DomNodes.
---
--- Key responsibilities:
--- - Pre-tokenize event handler expressions via ExpressionEvaluator.Defer()
--- - Merge multiple callbacks for the same event into a single callback
---   (OpenMW only allows one callback per event)
--- - Inject $event1 and $event2 placeholders into the context at call time
--- - Produce a table of event name → callback suitable for the OpenMW UI API

local ExpressionEvaluator = require("scripts.Nox.AnglesUI.Parser.ExpressionEvaluator")
local HtmlNodes           = require("scripts.Nox.AnglesUI.Parser.HTML.HtmlNodes")

local AttributeType = HtmlNodes.AttributeType

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

--- @class AnglesUI.EventBinding
local EventBinding = {}

---------------------------------------------------------------------------
-- Types
---------------------------------------------------------------------------

--- @class AnglesUI.EventHandler
--- @field eventName string The OpenMW event name (e.g. "mousePress")
--- @field expression string The raw expression string
--- @field deferred fun(context: table<string, any>): any Pre-tokenized evaluator

--- @class AnglesUI.EventCallbackMap
--- A table mapping event names to a single merged callback function.
--- Each callback has signature: function(event1Arg, layout) where event1Arg
--- is the OpenMW event argument and layout is the OpenMW widget layout.

---------------------------------------------------------------------------
-- Event name mapping
---------------------------------------------------------------------------

--- Map from our HTML template event names to OpenMW UI API event names.
--- If a name isn't in this table, we use it as-is (pass-through).
--- @type table<string, string>
local EVENT_NAME_MAP = {
    click       = "mousePress",
    mousedown   = "mousePress",
    mouseup     = "mouseRelease",
    mousemove   = "mouseMove",
    keydown     = "keyPress",
    keyup       = "keyRelease",
    focus       = "focusGain",
    blur        = "focusLoss",
    input       = "textInput",
    textchanged = "textChanged",
    -- Direct OpenMW names pass through
}

--- Map a template event name to the OpenMW UI API event name.
--- @param templateName string
--- @return string
local function MapEventName(templateName)
    local lower = templateName:lower()
    return EVENT_NAME_MAP[lower] or templateName
end

---------------------------------------------------------------------------
-- Collect event attributes from a DomNode
---------------------------------------------------------------------------

--- Collect all event binding attributes from a DomNode's HTML AST.
--- @param domNode AnglesUI.DomNode
--- @return AnglesUI.EventHandler[]
function EventBinding.CollectHandlers(domNode)
    local handlers = {}
    local htmlNode = domNode.htmlNode
    if not htmlNode or not htmlNode.attributes then
        return handlers
    end

    --- @type AnglesUI.Attribute[]
    local attributes = htmlNode.attributes

    for i = 1, #attributes do
        local attr = attributes[i]
        if attr.type == AttributeType.Event then
            handlers[#handlers + 1] = {
                eventName = MapEventName(attr.name),
                expression = attr.value,
                deferred = ExpressionEvaluator.Defer(attr.value),
            }
        end
    end

    return handlers
end

---------------------------------------------------------------------------
-- Build merged callback map
---------------------------------------------------------------------------

--- Build a callback map for a DomNode, merging multiple handlers for the
--- same event into a single callback. The context table is captured by
--- reference so signal changes are reflected.
---
--- Each callback receives (event1Arg, layout) from OpenMW:
--- - event1Arg: the event-specific argument (MouseEvent, KeyboardEvent, etc.)
---   or nil for events like focusGain/focusLoss
--- - layout: the OpenMW widget layout table
---
--- These are injected into the context as $event1 and $event2 respectively.
---
--- @param domNode AnglesUI.DomNode
--- @param context table<string, any> The evaluation context (by reference)
--- @return table<string, fun(event1: any, layout: any)> callbackMap
function EventBinding.BuildCallbackMap(domNode, context)
    local handlers = EventBinding.CollectHandlers(domNode)
    if #handlers == 0 then
        return {}
    end

    -- Group handlers by event name
    --- @type table<string, AnglesUI.EventHandler[]>
    local grouped = {}
    for i = 1, #handlers do
        local h = handlers[i]
        local name = h.eventName
        if not grouped[name] then
            grouped[name] = {}
        end
        local list = grouped[name]
        list[#list + 1] = h
    end

    -- Build single callback per event
    --- @type table<string, fun(event1: any, layout: any)>
    local callbackMap = {}

    for eventName, eventHandlers in pairs(grouped) do
        if #eventHandlers == 1 then
            -- Single handler — no merging needed
            local handler = eventHandlers[1]
            callbackMap[eventName] = function(event1, layout)
                local evalContext = setmetatable({
                    ["$event1"] = event1,
                    ["$event2"] = layout,
                }, { __index = context })
                handler.deferred(evalContext)
            end
        else
            -- Multiple handlers — merge into a single callback
            -- Copy the handler list to avoid external mutation
            local handlersCopy = {}
            for i = 1, #eventHandlers do
                handlersCopy[i] = eventHandlers[i]
            end

            callbackMap[eventName] = function(event1, layout)
                local evalContext = setmetatable({
                    ["$event1"] = event1,
                    ["$event2"] = layout,
                }, { __index = context })
                for i = 1, #handlersCopy do
                    handlersCopy[i].deferred(evalContext)
                end
            end
        end
    end

    return callbackMap
end

---------------------------------------------------------------------------
-- Merge additional callbacks into an existing map
---------------------------------------------------------------------------

--- Merge additional event callbacks (e.g. from hover tracking, scroll, drag)
--- into an existing callback map. Each existing callback for the same event
--- is wrapped to call both the original and the new callback.
--- @param existing table<string, fun(event1: any, layout: any)>
--- @param additional table<string, fun(event1: any, layout: any)>
--- @return table<string, fun(event1: any, layout: any)>
function EventBinding.MergeCallbackMaps(existing, additional)
    local merged = {}

    -- Copy existing
    for k, v in pairs(existing) do
        merged[k] = v
    end

    -- Merge additional
    for eventName, newCb in pairs(additional) do
        local oldCb = merged[eventName]
        if oldCb then
            -- Wrap both into a single callback
            merged[eventName] = function(event1, layout)
                oldCb(event1, layout)
                newCb(event1, layout)
            end
        else
            merged[eventName] = newCb
        end
    end

    return merged
end

return EventBinding
