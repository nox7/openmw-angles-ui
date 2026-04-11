--- AnglesUI Test Suite — Hover Tracker
--- Tests for counter-based hover tracking via focusGain/focusLoss.

package.path = "?.lua;scripts/Nox/AnglesUI/?.lua;scripts/Nox/AnglesUI/Tests/?.lua;scripts/Nox/AnglesUI/DOM/?.lua;scripts/Nox/AnglesUI/Parser/HTML/?.lua;scripts/Nox/AnglesUI/Parser/CSS/?.lua;" .. package.path

local lu = require("luaunit")
local HtmlNodes    = require("HtmlNodes")
local DomNode      = require("DomNode")
local HoverTracker = require("HoverTracker")

--- Helper: create element DomNode.
local function makeEl(tag)
    local html = HtmlNodes.CreateElement(tag, 0, 0)
    return DomNode.FromElement(html, nil, 0)
end

---------------------------------------------------------------------------
-- TestFocusGain
---------------------------------------------------------------------------
TestFocusGain = {}

function TestFocusGain:testSingleNode()
    local ht = HoverTracker.New()
    local node = makeEl("mw-text")
    ht:OnFocusGain(node)
    lu.assertTrue(ht:IsHovered(node))
    lu.assertEquals(node.hoverCount, 1)
end

function TestFocusGain:testPropagatesUp()
    local ht = HoverTracker.New()
    local root = makeEl("mw-root")
    local child = makeEl("mw-text")
    root:AppendChild(child)
    ht:OnFocusGain(child)
    lu.assertTrue(ht:IsHovered(child))
    lu.assertTrue(ht:IsHovered(root))
    lu.assertEquals(root.hoverCount, 1)
end

function TestFocusGain:testMultipleDescendantsAccumulate()
    local ht = HoverTracker.New()
    local root = makeEl("mw-root")
    local a = makeEl("mw-text")
    local b = makeEl("mw-text")
    root:AppendChild(a)
    root:AppendChild(b)
    ht:OnFocusGain(a)
    ht:OnFocusGain(b)
    lu.assertEquals(root.hoverCount, 2)
    lu.assertTrue(ht:IsHovered(root))
end

---------------------------------------------------------------------------
-- TestFocusLoss
---------------------------------------------------------------------------
TestFocusLoss = {}

function TestFocusLoss:testSingleNodeLoss()
    local ht = HoverTracker.New()
    local node = makeEl("mw-text")
    ht:OnFocusGain(node)
    ht:OnFocusLoss(node)
    lu.assertFalse(ht:IsHovered(node))
    lu.assertEquals(node.hoverCount, 0)
end

function TestFocusLoss:testPropagatesLossUp()
    local ht = HoverTracker.New()
    local root = makeEl("mw-root")
    local child = makeEl("mw-text")
    root:AppendChild(child)
    ht:OnFocusGain(child)
    ht:OnFocusLoss(child)
    lu.assertFalse(ht:IsHovered(child))
    lu.assertFalse(ht:IsHovered(root))
end

function TestFocusLoss:testPartialLoss()
    local ht = HoverTracker.New()
    local root = makeEl("mw-root")
    local a = makeEl("mw-text")
    local b = makeEl("mw-text")
    root:AppendChild(a)
    root:AppendChild(b)
    ht:OnFocusGain(a)
    ht:OnFocusGain(b)
    ht:OnFocusLoss(a)
    lu.assertFalse(ht:IsHovered(a))
    lu.assertTrue(ht:IsHovered(b))
    lu.assertTrue(ht:IsHovered(root))
    lu.assertEquals(root.hoverCount, 1)
end

function TestFocusLoss:testCounterNeverNegative()
    local ht = HoverTracker.New()
    local node = makeEl("mw-text")
    ht:OnFocusLoss(node) -- loss without gain
    lu.assertEquals(node.hoverCount, 0)
    lu.assertFalse(ht:IsHovered(node))
end

---------------------------------------------------------------------------
-- TestHoverSet
---------------------------------------------------------------------------
TestHoverSet = {}

function TestHoverSet:testGetHoverSet()
    local ht = HoverTracker.New()
    local root = makeEl("mw-root")
    local child = makeEl("mw-text")
    root:AppendChild(child)
    ht:OnFocusGain(child)
    local set = ht:GetHoverSet()
    lu.assertTrue(set[child])
    lu.assertTrue(set[root])
end

function TestHoverSet:testHoverSetUpdatesOnLoss()
    local ht = HoverTracker.New()
    local node = makeEl("mw-text")
    ht:OnFocusGain(node)
    ht:OnFocusLoss(node)
    local set = ht:GetHoverSet()
    lu.assertNil(set[node])
end

---------------------------------------------------------------------------
-- TestReset
---------------------------------------------------------------------------
TestReset = {}

function TestReset:testResetClearsAll()
    local ht = HoverTracker.New()
    local root = makeEl("mw-root")
    local child = makeEl("mw-text")
    root:AppendChild(child)
    ht:OnFocusGain(child)
    ht:Reset()
    lu.assertFalse(ht:IsHovered(child))
    lu.assertFalse(ht:IsHovered(root))
    lu.assertEquals(child.hoverCount, 0)
    lu.assertEquals(root.hoverCount, 0)
    local set = ht:GetHoverSet()
    lu.assertNil(set[child])
    lu.assertNil(set[root])
end

---------------------------------------------------------------------------
-- Run
---------------------------------------------------------------------------
lu.run()
