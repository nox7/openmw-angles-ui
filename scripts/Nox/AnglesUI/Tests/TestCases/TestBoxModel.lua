--- AnglesUI Test Suite — BoxModel
--- Tests for box model layout: padding/margin/border resolution,
--- block flow, text element sizing, child bounds measurement.

package.path = "?.lua;scripts/Nox/AnglesUI/?.lua;scripts/Nox/AnglesUI/Tests/?.lua;scripts/Nox/AnglesUI/Renderer/?.lua;scripts/Nox/AnglesUI/Parser/?.lua;scripts/Nox/AnglesUI/Parser/HTML/?.lua;scripts/Nox/AnglesUI/DOM/?.lua;scripts/Nox/AnglesUI/Parser/CSS/?.lua;" .. package.path

-- BoxModel uses dotted requires - we need them on path too
package.path = "scripts/Nox/AnglesUI/Renderer/?.lua;scripts/Nox/AnglesUI/?.lua;" .. package.path

local lu = require("luaunit")
local DomNode = require("DomNode")

-- BoxModel uses dotted require paths internally, so we pre-load modules
-- under the dotted keys to bypass filesystem resolution.
local LayoutUtils = require("LayoutUtils")
local TextMeasure = require("TextMeasure")
package.loaded["scripts.Nox.AnglesUI.Renderer.LayoutUtils"] = LayoutUtils
package.loaded["scripts.Nox.AnglesUI.TextMeasure"] = TextMeasure

local BoxModel = require("BoxModel")

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

--- Create a minimal element DomNode for testing.
--- @param tag string
--- @param styles table<string, string>?
--- @param attrs table<string, table>?
--- @return AnglesUI.DomNode
local function makeNode(tag, styles, attrs)
    local node = DomNode.FromElement({
        tag = tag,
        attributes = {},
        children = {},
        isEngine = true,
        isUserComponent = false,
    })
    node.computedStyles = styles or {}
    node.children = {}
    if attrs then
        node.attributes = attrs
    end
    return node
end

--- Create a text DomNode child.
--- @param text string
--- @return AnglesUI.DomNode
local function makeTextNode(text)
    local node = DomNode.FromText({ content = text })
    node.layoutData = {}
    return node
end

---------------------------------------------------------------------------
-- TestInitLayoutData
---------------------------------------------------------------------------
TestInitLayoutData = {}

function TestInitLayoutData:testLayoutDataInitialisedToZero()
    local node = makeNode("mw-flex")
    BoxModel.Layout(node, 800, 600)
    local ld = node.layoutData
    lu.assertNotNil(ld)
    lu.assertEquals(ld.paddingTop, 0)
    lu.assertEquals(ld.marginLeft, 0)
    lu.assertEquals(ld.borderRight, 0)
end

---------------------------------------------------------------------------
-- TestPaddingResolution
---------------------------------------------------------------------------
TestPaddingResolution = {}

function TestPaddingResolution:testResolvesPaddingFromStyles()
    local node = makeNode("mw-flex", { padding = "10px 20px" })
    BoxModel.Layout(node, 800, 600)
    local ld = node.layoutData
    lu.assertAlmostEquals(ld.paddingTop, 10, 0.001)
    lu.assertAlmostEquals(ld.paddingRight, 20, 0.001)
    lu.assertAlmostEquals(ld.paddingBottom, 10, 0.001)
    lu.assertAlmostEquals(ld.paddingLeft, 20, 0.001)
end

---------------------------------------------------------------------------
-- TestMarginResolution
---------------------------------------------------------------------------
TestMarginResolution = {}

function TestMarginResolution:testResolvesMarginFromStyles()
    local node = makeNode("mw-flex", { margin = "5px" })
    BoxModel.Layout(node, 800, 600)
    local ld = node.layoutData
    lu.assertAlmostEquals(ld.marginTop, 5, 0.001)
    lu.assertAlmostEquals(ld.marginRight, 5, 0.001)
end

---------------------------------------------------------------------------
-- TestBorderResolution
---------------------------------------------------------------------------
TestBorderResolution = {}

function TestBorderResolution:testResolvesBorderWidths()
    local node = makeNode("mw-flex", {
        ["border-top"] = '5px "t.dds" false false',
    })
    BoxModel.Layout(node, 800, 600)
    lu.assertAlmostEquals(node.layoutData.borderTop, 5, 0.001)
    lu.assertAlmostEquals(node.layoutData.borderBottom, 0, 0.001)
end

---------------------------------------------------------------------------
-- TestPositionMode
---------------------------------------------------------------------------
TestPositionMode = {}

function TestPositionMode:testAbsolutePosition()
    local node = makeNode("mw-flex", { position = "absolute" })
    BoxModel.Layout(node, 800, 600)
    lu.assertTrue(node.layoutData.isAbsolute)
    lu.assertFalse(node.layoutData.isRelative)
end

function TestPositionMode:testRelativePosition()
    local node = makeNode("mw-flex", { position = "relative" })
    BoxModel.Layout(node, 800, 600)
    lu.assertFalse(node.layoutData.isAbsolute)
    lu.assertTrue(node.layoutData.isRelative)
end

function TestPositionMode:testStaticIsDefault()
    local node = makeNode("mw-flex")
    BoxModel.Layout(node, 800, 600)
    lu.assertFalse(node.layoutData.isAbsolute)
    lu.assertFalse(node.layoutData.isRelative)
end

---------------------------------------------------------------------------
-- TestExplicitSizing
---------------------------------------------------------------------------
TestExplicitSizing = {}

function TestExplicitSizing:testExplicitWidthAndHeight()
    local node = makeNode("mw-flex", { width = "200px", height = "100px" })
    BoxModel.Layout(node, 800, 600)
    lu.assertAlmostEquals(node.layoutData.contentWidth, 200, 0.001)
    lu.assertAlmostEquals(node.layoutData.contentHeight, 100, 0.001)
end

function TestExplicitSizing:testExplicitWidthWithPadding()
    local node = makeNode("mw-flex", {
        width = "200px",
        height = "100px",
        padding = "10px"
    })
    BoxModel.Layout(node, 800, 600)
    -- contentWidth = 200 - 10 - 10 = 180
    lu.assertAlmostEquals(node.layoutData.contentWidth, 180, 0.001)
    lu.assertAlmostEquals(node.layoutData.contentHeight, 80, 0.001)
    -- outer = 200
    lu.assertAlmostEquals(node.layoutData.width, 200, 0.001)
    lu.assertAlmostEquals(node.layoutData.height, 100, 0.001)
end

---------------------------------------------------------------------------
-- TestAspectRatio
---------------------------------------------------------------------------
TestAspectRatio = {}

function TestAspectRatio:testWidthDeterminesHeight()
    local node = makeNode("mw-flex", {
        width = "160px",
        ["aspect-ratio"] = "16/9",
    })
    BoxModel.Layout(node, 800, 600)
    lu.assertAlmostEquals(node.layoutData.contentHeight, 160 / (16 / 9), 1)
end

---------------------------------------------------------------------------
-- TestBlockChildrenLayout
---------------------------------------------------------------------------
TestBlockChildrenLayout = {}

function TestBlockChildrenLayout:testChildrenStackVertically()
    local parent = makeNode("mw-root")
    local c1 = makeNode("mw-flex", { width = "100px", height = "50px" })
    local c2 = makeNode("mw-flex", { width = "100px", height = "30px" })
    c1.parent = parent
    c2.parent = parent
    parent.children = { c1, c2 }

    BoxModel.Layout(parent, 800, 600)

    lu.assertAlmostEquals(c1.layoutData.y, 0, 0.001)
    lu.assertAlmostEquals(c2.layoutData.y, 50, 0.001)
end

function TestBlockChildrenLayout:testAbsoluteChildSkippedInFlow()
    local parent = makeNode("mw-root")
    local c1 = makeNode("mw-flex", { width = "100px", height = "50px" })
    local c2 = makeNode("mw-flex", { width = "100px", height = "30px", position = "absolute" })
    local c3 = makeNode("mw-flex", { width = "100px", height = "20px" })
    c1.parent = parent
    c2.parent = parent
    c3.parent = parent
    parent.children = { c1, c2, c3 }

    BoxModel.Layout(parent, 800, 600)

    -- c3 should be placed right after c1 since c2 is absolute
    lu.assertAlmostEquals(c1.layoutData.y, 0, 0.001)
    lu.assertAlmostEquals(c3.layoutData.y, 50, 0.001)
end

---------------------------------------------------------------------------
-- TestTextElementLayout
---------------------------------------------------------------------------
TestTextElementLayout = {}

function TestTextElementLayout:testTextNodeWithExplicitSize()
    local node = makeNode("mw-text", { width = "200px", height = "30px" })
    local textChild = makeTextNode("Hello world")
    textChild.parent = node
    node.children = { textChild }
    BoxModel.Layout(node, 800, 600)
    lu.assertAlmostEquals(node.layoutData.contentWidth, 200, 0.001)
    lu.assertAlmostEquals(node.layoutData.contentHeight, 30, 0.001)
end

function TestTextElementLayout:testCollectsTextContent()
    local node = makeNode("mw-text")
    local textChild = makeTextNode("Hello")
    textChild.parent = node
    node.children = { textChild }
    local result = BoxModel._CollectText(node)
    lu.assertEquals(result, "Hello")
end

---------------------------------------------------------------------------
-- TestImageElementLayout
---------------------------------------------------------------------------
TestImageElementLayout = {}

function TestImageElementLayout:testImageWithExplicitSize()
    local node = makeNode("mw-image", { width = "200px", height = "150px" })
    BoxModel.Layout(node, 400, 300)
    lu.assertAlmostEquals(node.layoutData.contentWidth, 200, 0.001)
    lu.assertAlmostEquals(node.layoutData.contentHeight, 150, 0.001)
end

function TestImageElementLayout:testImageLayoutSetsContentArea()
    -- _LayoutImageElement sets contentWidth/Height to available space,
    -- but outer Layout overrides with childBounds when no explicit size.
    -- With explicit size, content area is correct.
    local node = makeNode("mw-image", { width = "100px", height = "80px" })
    BoxModel.Layout(node, 400, 300)
    lu.assertAlmostEquals(node.layoutData.width, 100, 0.001)
    lu.assertAlmostEquals(node.layoutData.height, 80, 0.001)
end

---------------------------------------------------------------------------
-- TestMeasureChildBounds
---------------------------------------------------------------------------
TestMeasureChildBounds = {}

function TestMeasureChildBounds:testBoundsFromChildren()
    local parent = makeNode("mw-root")
    local c1 = makeNode("mw-flex", { width = "100px", height = "50px" })
    c1.parent = parent
    parent.children = { c1 }

    BoxModel.Layout(parent, 800, 600)

    -- Parent should grow to contain child
    lu.assertTrue(parent.layoutData.contentWidth >= 100)
    lu.assertTrue(parent.layoutData.contentHeight >= 50)
end

---------------------------------------------------------------------------
-- TestCollectText
---------------------------------------------------------------------------
TestCollectText = {}

function TestCollectText:testCollectsFromTextChildren()
    local node = makeNode("mw-text")
    local t1 = makeTextNode("Hello ")
    local t2 = makeTextNode("World")
    t1.parent = node
    t2.parent = node
    node.children = { t1, t2 }
    local result = BoxModel._CollectText(node)
    lu.assertEquals(result, "Hello World")
end

---------------------------------------------------------------------------
-- Run
---------------------------------------------------------------------------
lu.run()
