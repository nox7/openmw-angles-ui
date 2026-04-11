--- AnglesUI Test Suite — GridLayout
--- Tests for grid template resolution, item placement, gap handling,
--- and content alignment in mw-grid containers.

package.path = "?.lua;scripts/Nox/AnglesUI/?.lua;scripts/Nox/AnglesUI/Tests/?.lua;scripts/Nox/AnglesUI/Renderer/?.lua;scripts/Nox/AnglesUI/Parser/?.lua;scripts/Nox/AnglesUI/Parser/HTML/?.lua;scripts/Nox/AnglesUI/DOM/?.lua;scripts/Nox/AnglesUI/Parser/CSS/?.lua;" .. package.path

local lu = require("luaunit")
local DomNode = require("DomNode")

-- Pre-load dotted modules
local LayoutUtils = require("LayoutUtils")
local TextMeasure = require("TextMeasure")
package.loaded["scripts.Nox.AnglesUI.Renderer.LayoutUtils"] = LayoutUtils
package.loaded["scripts.Nox.AnglesUI.TextMeasure"] = TextMeasure

local BoxModel   = require("BoxModel")
local GridLayout = require("GridLayout")

-- Wire up delegates
GridLayout.SetBoxModelLayout(BoxModel.Layout)
BoxModel.SetDelegates(nil, GridLayout.Layout, nil)

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

local function makeGrid(styles, children)
    local node = makeNode("mw-grid", styles)
    for _, child in ipairs(children) do
        child.parent = node
    end
    node.children = children
    return node
end

---------------------------------------------------------------------------
-- TestGridBasicPlacement
---------------------------------------------------------------------------
TestGridBasicPlacement = {}

function TestGridBasicPlacement:testAutoPlacesInOrder()
    local c1 = makeNode("mw-flex", { width = "50px", height = "50px" })
    local c2 = makeNode("mw-flex", { width = "50px", height = "50px" })
    local c3 = makeNode("mw-flex", { width = "50px", height = "50px" })
    local grid = makeGrid({
        ["grid-template-columns"] = "100px 100px",
        ["grid-template-rows"] = "100px 100px",
    }, { c1, c2, c3 })
    BoxModel.Layout(grid, 800, 600)
    -- c1 at col 1, c2 at col 2, c3 wraps to row 2 col 1
    lu.assertAlmostEquals(c1.layoutData.x, 0, 1)
    lu.assertAlmostEquals(c2.layoutData.x, 100, 1)
    lu.assertAlmostEquals(c3.layoutData.y, 100, 1)
end

function TestGridBasicPlacement:testExplicitPlacement()
    local c1 = makeNode("mw-flex", {
        width = "50px", height = "50px",
        ["grid-column-start"] = "2",
        ["grid-row-start"] = "1",
    })
    local grid = makeGrid({
        ["grid-template-columns"] = "100px 100px",
        ["grid-template-rows"] = "100px",
    }, { c1 })
    BoxModel.Layout(grid, 800, 600)
    lu.assertAlmostEquals(c1.layoutData.x, 100, 1)
end

---------------------------------------------------------------------------
-- TestGridFrUnits
---------------------------------------------------------------------------
TestGridFrUnits = {}

function TestGridFrUnits:testEqualFrDistribution()
    local c1 = makeNode("mw-flex", { width = "50px", height = "50px" })
    local c2 = makeNode("mw-flex", { width = "50px", height = "50px" })
    local grid = makeGrid({
        ["grid-template-columns"] = "1fr 1fr",
        ["grid-template-rows"] = "100px",
        width = "400px",
    }, { c1, c2 })
    BoxModel.Layout(grid, 800, 600)
    -- Each column should be roughly 200px (400/2)
    lu.assertAlmostEquals(c2.layoutData.x - c1.layoutData.x, 200, 5)
end

function TestGridFrUnits:testUnequalFrDistribution()
    local c1 = makeNode("mw-flex", { width = "50px", height = "50px" })
    local c2 = makeNode("mw-flex", { width = "50px", height = "50px" })
    local grid = makeGrid({
        ["grid-template-columns"] = "1fr 2fr",
        ["grid-template-rows"] = "100px",
        width = "300px",
    }, { c1, c2 })
    BoxModel.Layout(grid, 800, 600)
    -- Column 1 ≈ 100px, Column 2 ≈ 200px
    lu.assertAlmostEquals(c2.layoutData.x, 100, 5)
end

---------------------------------------------------------------------------
-- TestGridGaps
---------------------------------------------------------------------------
TestGridGaps = {}

function TestGridGaps:testColumnGap()
    local c1 = makeNode("mw-flex", { width = "50px", height = "50px" })
    local c2 = makeNode("mw-flex", { width = "50px", height = "50px" })
    local grid = makeGrid({
        ["grid-template-columns"] = "100px 100px",
        ["grid-template-rows"] = "100px",
        ["grid-column-gap"] = "20px",
    }, { c1, c2 })
    BoxModel.Layout(grid, 800, 600)
    -- c2 at 100 + 20 = 120
    lu.assertAlmostEquals(c2.layoutData.x, 120, 1)
end

function TestGridGaps:testRowGap()
    local c1 = makeNode("mw-flex", { width = "50px", height = "50px" })
    local c2 = makeNode("mw-flex", { width = "50px", height = "50px" })
    local c3 = makeNode("mw-flex", { width = "50px", height = "50px" })
    local grid = makeGrid({
        ["grid-template-columns"] = "100px",
        ["grid-template-rows"] = "100px 100px",
        ["grid-row-gap"] = "10px",
    }, { c1, c2 })
    BoxModel.Layout(grid, 800, 600)
    -- c2 at 100 + 10 = 110
    lu.assertAlmostEquals(c2.layoutData.y, 110, 1)
end

function TestGridGaps:testShorthandGap()
    local c1 = makeNode("mw-flex", { width = "50px", height = "50px" })
    local c2 = makeNode("mw-flex", { width = "50px", height = "50px" })
    local grid = makeGrid({
        ["grid-template-columns"] = "100px 100px",
        ["grid-template-rows"] = "100px",
        gap = "15px",
    }, { c1, c2 })
    BoxModel.Layout(grid, 800, 600)
    lu.assertAlmostEquals(c2.layoutData.x, 115, 1)
end

---------------------------------------------------------------------------
-- TestGridSpan
---------------------------------------------------------------------------
TestGridSpan = {}

function TestGridSpan:testColumnSpan()
    local c1 = makeNode("mw-flex", {
        width = "50px", height = "50px",
        ["grid-column"] = "1 / 3",
    })
    local grid = makeGrid({
        ["grid-template-columns"] = "100px 100px",
        ["grid-template-rows"] = "100px",
    }, { c1 })
    BoxModel.Layout(grid, 800, 600)
    -- c1 should start at 0 and span 2 columns
    lu.assertAlmostEquals(c1.layoutData.x, 0, 1)
end

---------------------------------------------------------------------------
-- TestGridAlignment
---------------------------------------------------------------------------
TestGridAlignment = {}

function TestGridAlignment:testJustifyContentCenter()
    local c1 = makeNode("mw-flex", { width = "50px", height = "50px" })
    local grid = makeGrid({
        ["grid-template-columns"] = "100px",
        ["grid-template-rows"] = "100px",
        ["justify-content"] = "center",
        width = "400px",
    }, { c1 })
    BoxModel.Layout(grid, 800, 600)
    -- Grid content is 100px in 400px → offset 150
    lu.assertAlmostEquals(c1.layoutData.x, 150, 5)
end

function TestGridAlignment:testAlignContentEnd()
    local c1 = makeNode("mw-flex", { width = "50px", height = "50px" })
    local grid = makeGrid({
        ["grid-template-columns"] = "100px",
        ["grid-template-rows"] = "100px",
        ["align-content"] = "end",
        width = "400px",
        height = "400px",
    }, { c1 })
    BoxModel.Layout(grid, 800, 600)
    lu.assertAlmostEquals(c1.layoutData.y, 300, 5)
end

---------------------------------------------------------------------------
-- TestGridEmptyContainer
---------------------------------------------------------------------------
TestGridEmptyContainer = {}

function TestGridEmptyContainer:testNoChildrenNoError()
    local grid = makeGrid({
        ["grid-template-columns"] = "100px",
        ["grid-template-rows"] = "100px",
    }, {})
    BoxModel.Layout(grid, 800, 600)
    lu.assertNotNil(grid.layoutData)
end

---------------------------------------------------------------------------
-- TestGridHelpers
---------------------------------------------------------------------------
TestGridHelpers = {}

function TestGridHelpers:testSpanSize()
    local sizes = { 100, 200, 300 }
    local result = GridLayout._SpanSize(sizes, 1, 3, 10)
    -- 100 + 200 + 10 (1 inner gap) = 310
    lu.assertAlmostEquals(result, 310, 0.001)
end

function TestGridHelpers:testTrackStarts()
    local sizes = { 100, 200 }
    local starts = GridLayout._TrackStarts(sizes, 10)
    lu.assertAlmostEquals(starts[1], 0, 0.001)
    lu.assertAlmostEquals(starts[2], 110, 0.001)
end

function TestGridHelpers:testTotalSize()
    local sizes = { 100, 200, 300 }
    local total = GridLayout._TotalSize(sizes, 10)
    -- 100 + 200 + 300 + 2*10 = 620
    lu.assertAlmostEquals(total, 620, 0.001)
end

---------------------------------------------------------------------------
-- Run
---------------------------------------------------------------------------
lu.run()
