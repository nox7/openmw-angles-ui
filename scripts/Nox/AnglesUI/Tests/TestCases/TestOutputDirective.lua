--- AnglesUI Test Suite — Output Directive
--- Tests for {{ expression }} interpolation evaluation and tree resolution.

package.path = "?.lua;scripts/Nox/AnglesUI/?.lua;scripts/Nox/AnglesUI/Tests/?.lua;scripts/Nox/AnglesUI/Runtime/?.lua;scripts/Nox/AnglesUI/Parser/?.lua;scripts/Nox/AnglesUI/Parser/HTML/?.lua;scripts/Nox/AnglesUI/DOM/?.lua;scripts/Nox/AnglesUI/Parser/CSS/?.lua;" .. package.path

local lu = require("luaunit")
local HtmlNodes       = require("HtmlNodes")
local DomNode         = require("DomNode")
local DomTreeBuilder  = require("DomTreeBuilder")
local OutputDirective = require("OutputDirective")

local DomNodeKind = DomNode.DomNodeKind

---------------------------------------------------------------------------
-- TestEvaluate
---------------------------------------------------------------------------
TestEvaluate = {}

function TestEvaluate:testSimpleVariable()
    local out = HtmlNodes.CreateOutput("name", 1, 1)
    local dom = DomTreeBuilder.Build({ out })
    local outputNode = dom.children[1]
    local result = OutputDirective.Evaluate(outputNode, { name = "Brad" })
    lu.assertEquals(result, "Brad")
end

function TestEvaluate:testSignalCall()
    local out = HtmlNodes.CreateOutput("Name()", 1, 1)
    local dom = DomTreeBuilder.Build({ out })
    local outputNode = dom.children[1]
    local result = OutputDirective.Evaluate(outputNode, { Name = function() return "Jill" end })
    lu.assertEquals(result, "Jill")
end

function TestEvaluate:testNumericResult()
    local out = HtmlNodes.CreateOutput("count", 1, 1)
    local dom = DomTreeBuilder.Build({ out })
    local outputNode = dom.children[1]
    local result = OutputDirective.Evaluate(outputNode, { count = 42 })
    lu.assertEquals(result, "42")
end

function TestEvaluate:testNilResultReturnsEmpty()
    local out = HtmlNodes.CreateOutput("missing", 1, 1)
    local dom = DomTreeBuilder.Build({ out })
    local outputNode = dom.children[1]
    local result = OutputDirective.Evaluate(outputNode, {})
    lu.assertEquals(result, "")
end

function TestEvaluate:testBooleanTrue()
    local out = HtmlNodes.CreateOutput("flag", 1, 1)
    local dom = DomTreeBuilder.Build({ out })
    local outputNode = dom.children[1]
    local result = OutputDirective.Evaluate(outputNode, { flag = true })
    lu.assertEquals(result, "true")
end

function TestEvaluate:testStringLiteral()
    local out = HtmlNodes.CreateOutput("'Hello World'", 1, 1)
    local dom = DomTreeBuilder.Build({ out })
    local outputNode = dom.children[1]
    local result = OutputDirective.Evaluate(outputNode, {})
    lu.assertEquals(result, "Hello World")
end

---------------------------------------------------------------------------
-- TestResolveTree
---------------------------------------------------------------------------
TestResolveTree = {}

function TestResolveTree:testSetsResolvedText()
    local out = HtmlNodes.CreateOutput("title", 1, 1)
    local dom = DomTreeBuilder.Build({ out })
    OutputDirective.ResolveTree(dom, { title = "Test" })
    lu.assertEquals(dom.children[1].resolvedText, "Test")
end

function TestResolveTree:testNonOutputNodeUnchanged()
    local el = HtmlNodes.CreateElement("mw-text", 1, 1)
    local dom = DomTreeBuilder.Build({ el })
    OutputDirective.ResolveTree(dom, {})
    lu.assertNil(dom.children[1].resolvedText)
end

function TestResolveTree:testNestedOutputResolved()
    local el = HtmlNodes.CreateElement("mw-flex", 1, 1)
    local out = HtmlNodes.CreateOutput("msg", 2, 1)
    el.children = { out }
    local dom = DomTreeBuilder.Build({ el })
    OutputDirective.ResolveTree(dom, { msg = "hi" })
    -- Output should be resolved in the nested position
    local flex = dom.children[1]
    lu.assertTrue(#flex.children > 0)
    local found = false
    for _, c in ipairs(flex.children) do
        if c.resolvedText == "hi" then found = true end
    end
    lu.assertTrue(found)
end

function TestResolveTree:testMultipleOutputsResolved()
    local o1 = HtmlNodes.CreateOutput("a", 1, 1)
    local o2 = HtmlNodes.CreateOutput("b", 2, 1)
    local dom = DomTreeBuilder.Build({ o1, o2 })
    OutputDirective.ResolveTree(dom, { a = "X", b = "Y" })
    lu.assertEquals(dom.children[1].resolvedText, "X")
    lu.assertEquals(dom.children[2].resolvedText, "Y")
end

---------------------------------------------------------------------------
-- Run
---------------------------------------------------------------------------
lu.run()
