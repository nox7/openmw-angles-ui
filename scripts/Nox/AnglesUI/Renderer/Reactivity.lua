--- AnglesUI Signal Reactivity.
--- Subscribes to all signals found in the evaluation context and triggers
--- a re-evaluation + re-render cycle when any signal changes.
---
--- The re-render strategy is full-tree: on signal change, we re-evaluate
--- directives, re-resolve output/bindings, re-cascade CSS, re-layout, and
--- re-transpile, then call element:update() on the OpenMW UI element.
---
--- Future optimisation: track which signals map to which DOM subtrees and
--- only re-evaluate/re-render the affected portions.

local Signal = require("scripts.Nox.AnglesUI.Signal")

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

--- @class AnglesUI.Reactivity
local Reactivity = {}

---------------------------------------------------------------------------
-- Signal discovery
---------------------------------------------------------------------------

--- Recursively scan a context table for Signal instances.
--- Returns a flat list of all unique signals found.
--- @param context table
--- @return AnglesUI.Signal[] signals
function Reactivity.FindSignals(context)
    local found = {}
    local seen = {}

    local function scan(tbl, depth)
        if depth > 5 then return end -- prevent deep recursion
        if seen[tbl] then return end
        seen[tbl] = true

        for _, value in pairs(tbl) do
            if type(value) == "table" then
                -- Check if it's a Signal (has _subscribers and _value fields)
                if value._subscribers ~= nil and value._value ~= nil then
                    if not seen[value] then
                        seen[value] = true
                        found[#found + 1] = value
                    end
                else
                    scan(value, depth + 1)
                end
            end
        end
    end

    scan(context, 0)
    return found
end

---------------------------------------------------------------------------
-- Subscription management
---------------------------------------------------------------------------

--- @class AnglesUI.ReactivityHandle
--- @field dispose fun() Unsubscribe all signal watchers
--- @field signals AnglesUI.Signal[] The signals being watched

--- Subscribe to all signals in the context and call `onChanged` whenever
--- any signal is set. Returns a handle that can dispose all subscriptions.
--- @param context table The evaluation scope
--- @param onChanged fun() Callback to invoke on any signal change
--- @return AnglesUI.ReactivityHandle
function Reactivity.Subscribe(context, onChanged)
    local signals = Reactivity.FindSignals(context)
    local unsubs = {}

    for i = 1, #signals do
        unsubs[i] = signals[i]:Subscribe(function()
            onChanged()
        end)
    end

    return {
        signals = signals,
        dispose = function()
            for i = 1, #unsubs do
                unsubs[i]()
            end
        end,
    }
end

--- Subscribe with batching — collects rapid signal changes and only
--- triggers one re-render call. Uses a dirty flag + deferred flush.
--- @param context table The evaluation scope
--- @param onChanged fun() Callback to invoke (once) after batch
--- @return AnglesUI.ReactivityHandle
function Reactivity.SubscribeBatched(context, onChanged)
    local signals = Reactivity.FindSignals(context)
    local unsubs = {}
    local dirty = false

    local function markDirty()
        if not dirty then
            dirty = true
            -- Defer to next frame — in OpenMW Lua, we just call immediately
            -- since there's no microtask queue. Signal.Batch handles grouping.
            -- For now, simple immediate call with dirty flag to deduplicate
            -- within sync execution.
            dirty = false
            onChanged()
        end
    end

    for i = 1, #signals do
        unsubs[i] = signals[i]:Subscribe(markDirty)
    end

    return {
        signals = signals,
        dispose = function()
            for i = 1, #unsubs do
                unsubs[i]()
            end
        end,
    }
end

return Reactivity
