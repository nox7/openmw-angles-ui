--- AnglesUI Test Suite — FlexLayout
--- Tests for flex-direction, justify-content, align-items, gap,
--- flex-grow, flex-shrink, and item positioning.

package.path = "?.lua;scripts/Nox/AnglesUI/?.lua;scripts/Nox/AnglesUI/Tests/?.lua;scripts/Nox/AnglesUI/Renderer/?.lua;scripts/Nox/AnglesUI/Parser/?.lua;scripts/Nox/AnglesUI/Parser/HTML/?.lua;scripts/Nox/AnglesUI/DOM/?.lua;scripts/Nox/AnglesUI/Parser/CSS/?.lua;" .. package.path

local lu = require("luaunit")
local DomNode = require("DomNode")

-- Pre-load dotted modules
local LayoutUtils = require("LayoutUtils")
local TextMeasure = require("TextMeasure")
package.loaded["scripts.Nox.AnglesUI.Renderer.LayoutUtils"] = LayoutUtils
package.loaded["scripts.Nox.AnglesUI.TextMeasure"] = TextMeasure

local BoxModel  = require("BoxModel")
local FlexLayout = require("FlexLayout")

-- Wire up delegates
FlexLayout.SetBoxModelLayout(BoxModel.Layout)
BoxModel.SetDelegates(FlexLayout.Layout, nil, nil)

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function makeNode(tag, styles)
    local node = DomNode.FromElement({
        tag = tag, attributes = {}, children = {},
        isEngine = true, isUserComponent = false,
    })
    node.computedStyles = styles or {}
    node.children = {}
    return node
end

local function makeFlex(styles, children)
    local node = makeNode("mw-flex", styles)
    for _, child in ipairs(children) do
        child.parent = node
    end
    node.children = children
    return node
end

---------------------------------------------------------------------------
-- TestFlexRow
---------------------------------------------------------------------------
TestFlexRow = {}

function TestFlexRow:testChildrenLaidOutHorizontally()
    local c1 = makeNode("mw-flex", { width = "100px", height = "50px" })
    local c2 = makeNode("mw-flex", { width = "100px", height = "50px" })
    local flex = makeFlex({ ["flex-direction"] = "row" }, { c1, c2 })
    BoxModel.Layout(flex, 800, 600)
    -- c2 should be to the right of c1
    lu.assertTrue(c2.layoutData.x >= c1.layoutData.x + c1.layoutData.width)
end

function TestFlexRow:testGapBetweenItems()
    local c1 = makeNode("mw-flex", { width = "100px", height = "50px" })
    local c2 = makeNode("mw-flex", { width = "100px", height = "50px" })
    local flex = makeFlex({ ["flex-direction"] = "row", gap = "20px" }, { c1, c2 })
    BoxModel.Layout(flex, 800, 600)
    local gapActual = c2.layoutData.x - (c1.layoutData.x + c1.layoutData.width)
    lu.assertAlmostEquals(gapActual, 20, 1)
end

---------------------------------------------------------------------------
-- TestFlexColumn
---------------------------------------------------------------------------
TestFlexColumn = {}

function TestFlexColumn:testChildrenLaidOutVertically()
    local c1 = makeNode("mw-flex", { width = "100px", height = "50px" })
    local c2 = makeNode("mw-flex", { width = "100px", height = "50px" })
    local flex = makeFlex({ ["flex-direction"] = "column" }, { c1, c2 })
    BoxModel.Layout(flex, 800, 600)
    lu.assertTrue(c2.layoutData.y >= c1.layoutData.y + c1.layoutData.height)
end

---------------------------------------------------------------------------
-- TestFlexGrow
---------------------------------------------------------------------------
TestFlexGrow = {}

function TestFlexGrow:testGrowDistributesFreeSpace()
    local c1 = makeNode("mw-flex", { width = "100px", height = "50px", ["flex-grow"] = "1" })
    local c2 = makeNode("mw-flex", { width = "100px", height = "50px", ["flex-grow"] = "1" })
    local flex = makeFlex({ ["flex-direction"] = "row", width = "400px" }, { c1, c2 })
    BoxModel.Layout(flex, 800, 600)
    -- Each should get roughly 200px (400 available / 2 items)
    lu.assertAlmostEquals(c1.layoutData.width, c2.layoutData.width, 1)
    lu.assertTrue(c1.layoutData.width > 100) -- grew from 100px
end

function TestFlexGrow:testUnequalGrowRatio()
    local c1 = makeNode("mw-flex", { width = "0px", height = "50px", ["flex-grow"] = "1", ["flex-basis"] = "0px" })
    local c2 = makeNode("mw-flex", { width = "0px", height = "50px", ["flex-grow"] = "2", ["flex-basis"] = "0px" })
    local flex = makeFlex({ ["flex-direction"] = "row", width = "300px" }, { c1, c2 })
    BoxModel.Layout(flex, 800, 600)
    -- c2 should be roughly twice c1
    lu.assertAlmostEquals(c2.layoutData.width / c1.layoutData.width, 2, 0.5)
end

---------------------------------------------------------------------------
-- TestFlexJustifyContent
---------------------------------------------------------------------------
TestFlexJustifyContent = {}

function TestFlexJustifyContent:testCenter()
    local c1 = makeNode("mw-flex", { width = "100px", height = "50px" })
    local flex = makeFlex({
        ["flex-direction"] = "row",
        ["justify-content"] = "center",
        width = "400px",
    }, { c1 })
    BoxModel.Layout(flex, 800, 600)
    -- c1 should be centered: (400 - 100) / 2 = 150
    lu.assertAlmostEquals(c1.layoutData.x, 150, 2)
end

function TestFlexJustifyContent:testEnd()
    local c1 = makeNode("mw-flex", { width = "100px", height = "50px" })
    local flex = makeFlex({
        ["flex-direction"] = "row",
        ["justify-content"] = "end",
        width = "400px",
    }, { c1 })
    BoxModel.Layout(flex, 800, 600)
    -- c1 should be at 300
    lu.assertAlmostEquals(c1.layoutData.x, 300, 2)
end

function TestFlexJustifyContent:testSpaceBetween()
    local c1 = makeNode("mw-flex", { width = "100px", height = "50px" })
    local c2 = makeNode("mw-flex", { width = "100px", height = "50px" })
    local flex = makeFlex({
        ["flex-direction"] = "row",
        ["justify-content"] = "space-between",
        width = "400px",
    }, { c1, c2 })
    BoxModel.Layout(flex, 800, 600)
    -- c1 at 0, c2 at 300
    lu.assertAlmostEquals(c1.layoutData.x, 0, 2)
    lu.assertAlmostEquals(c2.layoutData.x, 300, 2)
end

---------------------------------------------------------------------------
-- TestFlexAlignItems
---------------------------------------------------------------------------
TestFlexAlignItems = {}

function TestFlexAlignItems:testCenterCross()
    local c1 = makeNode("mw-flex", { width = "100px", height = "50px" })
    local flex = makeFlex({
        ["flex-direction"] = "row",
        ["align-items"] = "center",
        width = "400px",
        height = "200px",
    }, { c1 })
    BoxModel.Layout(flex, 800, 600)
    -- centered in 200px cross: (200 - 50) / 2 = 75
    lu.assertAlmostEquals(c1.layoutData.y, 75, 2)
end

function TestFlexAlignItems:testEndCross()
    local c1 = makeNode("mw-flex", { width = "100px", height = "50px" })
    local flex = makeFlex({
        ["flex-direction"] = "row",
        ["align-items"] = "end",
        width = "400px",
        height = "200px",
    }, { c1 })
    BoxModel.Layout(flex, 800, 600)
    lu.assertAlmostEquals(c1.layoutData.y, 150, 2)
end

---------------------------------------------------------------------------
-- TestFlexReverse
---------------------------------------------------------------------------
TestFlexReverse = {}

function TestFlexReverse:testRowReverse()
    local c1 = makeNode("mw-flex", { width = "100px", height = "50px" })
    local c2 = makeNode("mw-flex", { width = "100px", height = "50px" })
    local flex = makeFlex({
        ["flex-direction"] = "row-reverse",
        width = "400px",
    }, { c1, c2 })
    BoxModel.Layout(flex, 800, 600)
    -- In reverse, c2 should be before c1 visually
    lu.assertTrue(c2.layoutData.x < c1.layoutData.x)
end

---------------------------------------------------------------------------
-- TestFlexEmptyContainer
---------------------------------------------------------------------------
TestFlexEmptyContainer = {}

function TestFlexEmptyContainer:testNoChildrenNoError()
    local flex = makeFlex({ ["flex-direction"] = "row" }, {})
    BoxModel.Layout(flex, 800, 600)
    lu.assertNotNil(flex.layoutData)
end

---------------------------------------------------------------------------
-- Run
---------------------------------------------------------------------------
lu.run()
