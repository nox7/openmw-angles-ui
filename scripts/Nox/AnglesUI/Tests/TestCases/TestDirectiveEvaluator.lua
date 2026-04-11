--- AnglesUI Test Suite — Directive Evaluator
--- Tests for @if/@else if/@else and @for directive expansion at runtime.

package.path = "?.lua;scripts/Nox/AnglesUI/?.lua;scripts/Nox/AnglesUI/Tests/?.lua;scripts/Nox/AnglesUI/Runtime/?.lua;scripts/Nox/AnglesUI/Parser/?.lua;scripts/Nox/AnglesUI/Parser/HTML/?.lua;scripts/Nox/AnglesUI/DOM/?.lua;scripts/Nox/AnglesUI/Parser/CSS/?.lua;" .. package.path

local lu = require("luaunit")
local HtmlNodes          = require("HtmlNodes")
local DomNode            = require("DomNode")
local DomTreeBuilder     = require("DomTreeBuilder")
local DirectiveEvaluator = require("DirectiveEvaluator")

local DomNodeKind = DomNode.DomNodeKind

--- Helper to build a DOM tree and evaluate directives.
local function buildAndEvaluate(htmlAst, context)
    local root = DomTreeBuilder.Build(htmlAst)
    DirectiveEvaluator.Evaluate(root, context)
    return root
end

---------------------------------------------------------------------------
-- TestIfDirective
---------------------------------------------------------------------------
TestIfDirective = {}

function TestIfDirective:testTrueCondition()
    local ifNode = HtmlNodes.CreateIfDirective("visible", 1, 1)
    local child = HtmlNodes.CreateElement("mw-text", 2, 1)
    ifNode.children = { child }
    local root = buildAndEvaluate({ ifNode }, { visible = true })
    lu.assertEquals(#root.children, 1)
    lu.assertEquals(root.children[1].tag, "mw-text")
end

function TestIfDirective:testFalseCondition()
    local ifNode = HtmlNodes.CreateIfDirective("visible", 1, 1)
    local child = HtmlNodes.CreateElement("mw-text", 2, 1)
    ifNode.children = { child }
    local root = buildAndEvaluate({ ifNode }, { visible = false })
    lu.assertEquals(#root.children, 0)
end

function TestIfDirective:testElseBranch()
    local ifNode = HtmlNodes.CreateIfDirective("visible", 1, 1)
    local ifChild = HtmlNodes.CreateElement("mw-text", 2, 1)
    ifNode.children = { ifChild }
    local elseDir = HtmlNodes.CreateElseDirective(3, 1)
    local elseChild = HtmlNodes.CreateElement("mw-image", 4, 1)
    elseDir.children = { elseChild }
    ifNode.elseBranch = elseDir
    local root = buildAndEvaluate({ ifNode }, { visible = false })
    lu.assertEquals(#root.children, 1)
    lu.assertEquals(root.children[1].tag, "mw-image")
end

function TestIfDirective:testElseIfBranch()
    local ifNode = HtmlNodes.CreateIfDirective("a", 1, 1)
    ifNode.children = { HtmlNodes.CreateElement("mw-text", 2, 1) }
    local elseIf = HtmlNodes.CreateElseIfDirective("b", 3, 1)
    elseIf.children = { HtmlNodes.CreateElement("mw-image", 4, 1) }
    ifNode.elseIfBranches = { elseIf }
    local root = buildAndEvaluate({ ifNode }, { a = false, b = true })
    lu.assertEquals(#root.children, 1)
    lu.assertEquals(root.children[1].tag, "mw-image")
end

function TestIfDirective:testElseIfFallsToElse()
    local ifNode = HtmlNodes.CreateIfDirective("a", 1, 1)
    ifNode.children = { HtmlNodes.CreateElement("mw-text", 2, 1) }
    local elseIf = HtmlNodes.CreateElseIfDirective("b", 3, 1)
    elseIf.children = { HtmlNodes.CreateElement("mw-image", 4, 1) }
    ifNode.elseIfBranches = { elseIf }
    local elseDir = HtmlNodes.CreateElseDirective(5, 1)
    elseDir.children = { HtmlNodes.CreateElement("mw-flex", 6, 1) }
    ifNode.elseBranch = elseDir
    local root = buildAndEvaluate({ ifNode }, { a = false, b = false })
    lu.assertEquals(#root.children, 1)
    lu.assertEquals(root.children[1].tag, "mw-flex")
end

function TestIfDirective:testSignalCondition()
    local ifNode = HtmlNodes.CreateIfDirective("Show()", 1, 1)
    ifNode.children = { HtmlNodes.CreateElement("mw-text", 2, 1) }
    local root = buildAndEvaluate({ ifNode }, { Show = function() return true end })
    lu.assertEquals(#root.children, 1)
end

---------------------------------------------------------------------------
-- TestForDirective
---------------------------------------------------------------------------
TestForDirective = {}

function TestForDirective:testBasicIteration()
    local forNode = HtmlNodes.CreateForDirective("item", "items", 1, 1)
    forNode.children = { HtmlNodes.CreateElement("mw-text", 2, 1) }
    local root = buildAndEvaluate({ forNode }, { items = { "a", "b", "c" } })
    lu.assertEquals(#root.children, 3)
end

function TestForDirective:testEmptyIterable()
    local forNode = HtmlNodes.CreateForDirective("item", "items", 1, 1)
    forNode.children = { HtmlNodes.CreateElement("mw-text", 2, 1) }
    local root = buildAndEvaluate({ forNode }, { items = {} })
    lu.assertEquals(#root.children, 0)
end

function TestForDirective:testNonTableIterable()
    local forNode = HtmlNodes.CreateForDirective("item", "items", 1, 1)
    forNode.children = { HtmlNodes.CreateElement("mw-text", 2, 1) }
    local root = buildAndEvaluate({ forNode }, { items = nil })
    lu.assertEquals(#root.children, 0)
end

function TestForDirective:testIteratorContextAvailable()
    -- We can't easily check context inside the loop in a test, but we can
    -- verify the right number of nodes are created per iteration
    local forNode = HtmlNodes.CreateForDirective("item", "items", 1, 1)
    local inner = HtmlNodes.CreateElement("mw-flex", 2, 1)
    forNode.children = { inner }
    local root = buildAndEvaluate({ forNode }, { items = { 1, 2, 3, 4, 5 } })
    lu.assertEquals(#root.children, 5)
    for _, child in ipairs(root.children) do
        lu.assertEquals(child.tag, "mw-flex")
    end
end

function TestForDirective:testSignalIterable()
    local forNode = HtmlNodes.CreateForDirective("item", "Items()", 1, 1)
    forNode.children = { HtmlNodes.CreateElement("mw-text", 2, 1) }
    local root = buildAndEvaluate({ forNode }, { Items = function() return { "x", "y" } end })
    lu.assertEquals(#root.children, 2)
end

---------------------------------------------------------------------------
-- TestNestedDirectives
---------------------------------------------------------------------------
TestNestedDirectives = {}

function TestNestedDirectives:testForInsideIf()
    local ifNode = HtmlNodes.CreateIfDirective("show", 1, 1)
    local forNode = HtmlNodes.CreateForDirective("item", "items", 2, 1)
    forNode.children = { HtmlNodes.CreateElement("mw-text", 3, 1) }
    ifNode.children = { forNode }
    local root = buildAndEvaluate({ ifNode }, { show = true, items = { 1, 2 } })
    lu.assertEquals(#root.children, 2)
end

function TestNestedDirectives:testIfInsideFor()
    local forNode = HtmlNodes.CreateForDirective("item", "items", 1, 1)
    local ifNode = HtmlNodes.CreateIfDirective("item", 2, 1)
    ifNode.children = { HtmlNodes.CreateElement("mw-text", 3, 1) }
    forNode.children = { ifNode }
    -- Only truthy items produce children
    local root = buildAndEvaluate({ forNode }, { items = { true, false, true } })
    lu.assertEquals(#root.children, 2)
end

---------------------------------------------------------------------------
-- TestMixedContent
---------------------------------------------------------------------------
TestMixedContent = {}

function TestMixedContent:testStaticElementsPreserved()
    local staticEl = HtmlNodes.CreateElement("mw-flex", 1, 1)
    local ifNode = HtmlNodes.CreateIfDirective("true", 2, 1)
    ifNode.children = { HtmlNodes.CreateElement("mw-text", 3, 1) }
    local root = buildAndEvaluate({ staticEl, ifNode }, {})
    lu.assertEquals(#root.children, 2)
    lu.assertEquals(root.children[1].tag, "mw-flex")
    lu.assertEquals(root.children[2].tag, "mw-text")
end

function TestMixedContent:testTextNodesPassThrough()
    local txt = HtmlNodes.CreateText("hello", 1, 1)
    local root = buildAndEvaluate({ txt }, {})
    lu.assertEquals(#root.children, 1)
    lu.assertEquals(root.children[1].kind, DomNodeKind.Text)
end

---------------------------------------------------------------------------
-- Run
---------------------------------------------------------------------------
lu.run()
