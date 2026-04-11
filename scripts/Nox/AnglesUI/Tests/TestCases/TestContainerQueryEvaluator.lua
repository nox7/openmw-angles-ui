--- AnglesUI Test Suite — Container Query Evaluator
--- Tests for evaluating @container rule preludes against container dimensions.

package.path = "?.lua;scripts/Nox/AnglesUI/?.lua;scripts/Nox/AnglesUI/Tests/?.lua;scripts/Nox/AnglesUI/DOM/?.lua;scripts/Nox/AnglesUI/Parser/HTML/?.lua;scripts/Nox/AnglesUI/Parser/CSS/?.lua;" .. package.path

local lu = require("luaunit")
local HtmlNodes               = require("HtmlNodes")
local DomNode                 = require("DomNode")
local ContainerQueryEvaluator = require("ContainerQueryEvaluator")

local DomNodeKind = DomNode.DomNodeKind

--- Helper: create a DomNode element.
local function makeEl(tag, opts)
    opts = opts or {}
    local html = HtmlNodes.CreateElement(tag, 0, 0)
    if opts.id then
        html.attributes[#html.attributes + 1] = HtmlNodes.CreateAttribute("Static", "id", opts.id)
    end
    if opts.class then
        html.attributes[#html.attributes + 1] = HtmlNodes.CreateAttribute("Static", "class", opts.class)
    end
    return DomNode.FromElement(html, nil, opts.depth or 0)
end

--- Helper: build a tree root(container) -> child.
local function makeContainerTree(containerW, containerH, containerName)
    local root = makeEl("mw-root")
    root.isContainer = true
    root.containerName = containerName
    root.computedStyles["width"] = tostring(containerW) .. "px"
    root.computedStyles["height"] = tostring(containerH) .. "px"
    root.layoutData = { width = containerW, height = containerH }
    local child = makeEl("mw-text")
    root:AppendChild(child)
    return root, child
end

---------------------------------------------------------------------------
-- TestBasicConditions
---------------------------------------------------------------------------
TestBasicConditions = {}

function TestBasicConditions:testWidthLte()
    local root, child = makeContainerTree(500, 400)
    lu.assertTrue(ContainerQueryEvaluator.Evaluate("(width <= 600px)", child))
end

function TestBasicConditions:testWidthLteFalse()
    local root, child = makeContainerTree(800, 400)
    lu.assertFalse(ContainerQueryEvaluator.Evaluate("(width <= 600px)", child))
end

function TestBasicConditions:testMinWidth()
    local root, child = makeContainerTree(700, 400)
    lu.assertTrue(ContainerQueryEvaluator.Evaluate("(min-width: 600px)", child))
end

function TestBasicConditions:testMaxWidth()
    local root, child = makeContainerTree(500, 400)
    lu.assertTrue(ContainerQueryEvaluator.Evaluate("(max-width: 600px)", child))
end

function TestBasicConditions:testHeightGt()
    local root, child = makeContainerTree(800, 700)
    lu.assertTrue(ContainerQueryEvaluator.Evaluate("(height > 600px)", child))
end

function TestBasicConditions:testHeightLt()
    local root, child = makeContainerTree(800, 500)
    lu.assertTrue(ContainerQueryEvaluator.Evaluate("(height < 600px)", child))
end

---------------------------------------------------------------------------
-- TestNamedContainer
---------------------------------------------------------------------------
TestNamedContainer = {}

function TestNamedContainer:testNamedMatch()
    local root, child = makeContainerTree(500, 400, "sidebar")
    lu.assertTrue(ContainerQueryEvaluator.Evaluate("sidebar (width <= 600px)", child))
end

function TestNamedContainer:testNamedMismatch()
    local root, child = makeContainerTree(500, 400, "sidebar")
    -- Looking for "main" but only "sidebar" exists
    lu.assertFalse(ContainerQueryEvaluator.Evaluate("main (width <= 600px)", child))
end

---------------------------------------------------------------------------
-- TestCompound
---------------------------------------------------------------------------
TestCompound = {}

function TestCompound:testAndBothTrue()
    local root, child = makeContainerTree(500, 400)
    lu.assertTrue(ContainerQueryEvaluator.Evaluate("(min-width: 400px) and (max-width: 600px)", child))
end

function TestCompound:testAndOneFalse()
    local root, child = makeContainerTree(700, 400)
    lu.assertFalse(ContainerQueryEvaluator.Evaluate("(min-width: 400px) and (max-width: 600px)", child))
end

---------------------------------------------------------------------------
-- TestNoContainer
---------------------------------------------------------------------------
TestNoContainer = {}

function TestNoContainer:testNoContainerReturnsFalse()
    local node = makeEl("mw-text")
    lu.assertFalse(ContainerQueryEvaluator.Evaluate("(width <= 600px)", node))
end

---------------------------------------------------------------------------
-- TestCreateEvaluatorFunc
---------------------------------------------------------------------------
TestCreateEvaluatorFunc = {}

function TestCreateEvaluatorFunc:testReturnsFunction()
    local fn = ContainerQueryEvaluator.CreateEvaluatorFunc()
    lu.assertEquals(type(fn), "function")
end

function TestCreateEvaluatorFunc:testFuncWorks()
    local root, child = makeContainerTree(500, 400)
    local fn = ContainerQueryEvaluator.CreateEvaluatorFunc()
    lu.assertTrue(fn("(width <= 600px)", child))
end

---------------------------------------------------------------------------
-- Run
---------------------------------------------------------------------------
lu.run()
