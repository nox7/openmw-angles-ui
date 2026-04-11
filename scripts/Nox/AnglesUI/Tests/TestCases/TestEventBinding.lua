--- AnglesUI Test Suite — Event Binding
--- Tests for event name mapping, handler collection, callback building,
--- and callback map merging.

package.path = "?.lua;scripts/Nox/AnglesUI/?.lua;scripts/Nox/AnglesUI/Tests/?.lua;scripts/Nox/AnglesUI/Runtime/?.lua;scripts/Nox/AnglesUI/Parser/?.lua;scripts/Nox/AnglesUI/Parser/HTML/?.lua;scripts/Nox/AnglesUI/DOM/?.lua;scripts/Nox/AnglesUI/Parser/CSS/?.lua;" .. package.path

local lu = require("luaunit")
local HtmlNodes    = require("HtmlNodes")
local DomNode      = require("DomNode")
local EventBinding = require("EventBinding")

local AttributeType = HtmlNodes.AttributeType

--- Helper: create element DomNode with event attributes.
local function makeEl(tag, rawAttrs)
    local html = HtmlNodes.CreateElement(tag, 0, 0)
    if rawAttrs then
        for _, a in ipairs(rawAttrs) do
            html.attributes[#html.attributes + 1] = a
        end
    end
    return DomNode.FromElement(html, nil, 0)
end

local function eventAttr(name, expr)
    return HtmlNodes.CreateAttribute("Event", name, expr)
end

---------------------------------------------------------------------------
-- TestCollectHandlers
---------------------------------------------------------------------------
TestCollectHandlers = {}

function TestCollectHandlers:testSingleEvent()
    local node = makeEl("mw-text", { eventAttr("click", "DoStuff()") })
    local handlers = EventBinding.CollectHandlers(node)
    lu.assertEquals(#handlers, 1)
    lu.assertEquals(handlers[1].eventName, "mousePress") -- mapped
    lu.assertEquals(handlers[1].expression, "DoStuff()")
    lu.assertEquals(type(handlers[1].deferred), "function")
end

function TestCollectHandlers:testMultipleEvents()
    local node = makeEl("mw-text", {
        eventAttr("click", "A()"),
        eventAttr("blur", "B()"),
    })
    local handlers = EventBinding.CollectHandlers(node)
    lu.assertEquals(#handlers, 2)
end

function TestCollectHandlers:testNoEvents()
    local node = makeEl("mw-text", {
        HtmlNodes.CreateAttribute("Static", "id", "x"),
    })
    local handlers = EventBinding.CollectHandlers(node)
    lu.assertEquals(#handlers, 0)
end

function TestCollectHandlers:testEventNameMapping()
    local mappings = {
        { "click", "mousePress" },
        { "mousedown", "mousePress" },
        { "mouseup", "mouseRelease" },
        { "mousemove", "mouseMove" },
        { "keydown", "keyPress" },
        { "keyup", "keyRelease" },
        { "focus", "focusGain" },
        { "blur", "focusLoss" },
        { "input", "textInput" },
        { "textchanged", "textChanged" },
    }
    for _, m in ipairs(mappings) do
        local node = makeEl("mw-text", { eventAttr(m[1], "F()") })
        local handlers = EventBinding.CollectHandlers(node)
        lu.assertEquals(handlers[1].eventName, m[2],
            "Expected " .. m[1] .. " → " .. m[2])
    end
end

function TestCollectHandlers:testUnmappedNamePassthrough()
    local node = makeEl("mw-text", { eventAttr("focusGain", "F()") })
    local handlers = EventBinding.CollectHandlers(node)
    lu.assertEquals(handlers[1].eventName, "focusGain")
end

---------------------------------------------------------------------------
-- TestBuildCallbackMap
---------------------------------------------------------------------------
TestBuildCallbackMap = {}

function TestBuildCallbackMap:testSingleCallback()
    local called = false
    local node = makeEl("mw-text", { eventAttr("click", "OnClick()") })
    local ctx = { OnClick = function() called = true end }
    local map = EventBinding.BuildCallbackMap(node, ctx)
    lu.assertNotNil(map["mousePress"])
    map["mousePress"](nil, nil)
    lu.assertTrue(called)
end

function TestBuildCallbackMap:testInjectsEventPlaceholders()
    local capturedE1, capturedE2
    local node = makeEl("mw-text", { eventAttr("click", "Handle($event1, $event2)") })
    local ctx = {
        Handle = function(e1, e2)
            capturedE1 = e1
            capturedE2 = e2
        end,
    }
    local map = EventBinding.BuildCallbackMap(node, ctx)
    map["mousePress"]("mouseEvt", "layoutObj")
    lu.assertEquals(capturedE1, "mouseEvt")
    lu.assertEquals(capturedE2, "layoutObj")
end

function TestBuildCallbackMap:testMergesMultipleSameEvent()
    local order = {}
    local node = makeEl("mw-text", {
        eventAttr("click", "A()"),
        eventAttr("click", "B()"),
    })
    local ctx = {
        A = function() order[#order + 1] = "A" end,
        B = function() order[#order + 1] = "B" end,
    }
    local map = EventBinding.BuildCallbackMap(node, ctx)
    map["mousePress"](nil, nil)
    lu.assertEquals(#order, 2)
    lu.assertEquals(order[1], "A")
    lu.assertEquals(order[2], "B")
end

function TestBuildCallbackMap:testEmptyWhenNoEvents()
    local node = makeEl("mw-text", {})
    local map = EventBinding.BuildCallbackMap(node, {})
    lu.assertNil(next(map))
end

---------------------------------------------------------------------------
-- TestMergeCallbackMaps
---------------------------------------------------------------------------
TestMergeCallbackMaps = {}

function TestMergeCallbackMaps:testMergesDifferentEvents()
    local map1 = { mousePress = function() end }
    local map2 = { focusGain = function() end }
    local merged = EventBinding.MergeCallbackMaps(map1, map2)
    lu.assertNotNil(merged["mousePress"])
    lu.assertNotNil(merged["focusGain"])
end

function TestMergeCallbackMaps:testMergesSameEventCallsBoth()
    local order = {}
    local map1 = { mousePress = function() order[#order + 1] = "first" end }
    local map2 = { mousePress = function() order[#order + 1] = "second" end }
    local merged = EventBinding.MergeCallbackMaps(map1, map2)
    merged["mousePress"](nil, nil)
    lu.assertEquals(#order, 2)
    lu.assertEquals(order[1], "first")
    lu.assertEquals(order[2], "second")
end

function TestMergeCallbackMaps:testEmptyMerge()
    local merged = EventBinding.MergeCallbackMaps({}, {})
    lu.assertNil(next(merged))
end

---------------------------------------------------------------------------
-- Run
---------------------------------------------------------------------------
lu.run()
