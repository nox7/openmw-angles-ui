--- AnglesUI Test Suite — DomTreeBuilder
--- Tests for building a linked DomNode tree from an HTML AST.

package.path = "?.lua;scripts/Nox/AnglesUI/?.lua;scripts/Nox/AnglesUI/Tests/?.lua;scripts/Nox/AnglesUI/DOM/?.lua;scripts/Nox/AnglesUI/Parser/HTML/?.lua;scripts/Nox/AnglesUI/Parser/CSS/?.lua;" .. package.path

local lu = require("luaunit")
local HtmlNodes      = require("HtmlNodes")
local DomNode        = require("DomNode")
local DomTreeBuilder = require("DomTreeBuilder")

local NodeType    = HtmlNodes.NodeType
local DomNodeKind = DomNode.DomNodeKind

---------------------------------------------------------------------------
-- TestBuild
---------------------------------------------------------------------------
TestBuild = {}

function TestBuild:testEmptyAst()
    local root = DomTreeBuilder.Build({})
    lu.assertEquals(root.tag, "__document__")
    lu.assertEquals(#root.children, 0)
end

function TestBuild:testSingleElement()
    local el = HtmlNodes.CreateElement("mw-root", 1, 1)
    local root = DomTreeBuilder.Build({ el })
    lu.assertEquals(#root.children, 1)
    lu.assertEquals(root.children[1].kind, DomNodeKind.Element)
    lu.assertEquals(root.children[1].tag, "mw-root")
    lu.assertEquals(root.children[1].parent, root)
end

function TestBuild:testNestedElements()
    local outer = HtmlNodes.CreateElement("mw-flex", 1, 1)
    local inner = HtmlNodes.CreateElement("mw-text", 2, 1)
    outer.children = { inner }
    inner.parent = outer

    local root = DomTreeBuilder.Build({ outer })
    lu.assertEquals(#root.children, 1)
    local flex = root.children[1]
    lu.assertEquals(flex.tag, "mw-flex")
    lu.assertEquals(#flex.children, 1)
    lu.assertEquals(flex.children[1].tag, "mw-text")
    lu.assertEquals(flex.children[1].depth, 2)
end

function TestBuild:testTextNode()
    local txt = HtmlNodes.CreateText("hello", 1, 1)
    local root = DomTreeBuilder.Build({ txt })
    lu.assertEquals(#root.children, 1)
    lu.assertEquals(root.children[1].kind, DomNodeKind.Text)
end

function TestBuild:testOutputDirective()
    local out = HtmlNodes.CreateOutput("x + 1", 1, 1)
    local root = DomTreeBuilder.Build({ out })
    lu.assertEquals(root.children[1].kind, DomNodeKind.Output)
end

function TestBuild:testIfDirective()
    local ifDir = HtmlNodes.CreateIfDirective("Show()", 1, 1)
    local child = HtmlNodes.CreateElement("mw-text", 2, 1)
    ifDir.children = { child }
    local root = DomTreeBuilder.Build({ ifDir })
    lu.assertEquals(root.children[1].kind, DomNodeKind.IfDirective)
    lu.assertEquals(#root.children[1].children, 1)
end

function TestBuild:testForDirective()
    local forDir = HtmlNodes.CreateForDirective("item", "Items()", 1, 1)
    local child = HtmlNodes.CreateElement("mw-text", 2, 1)
    forDir.children = { child }
    local root = DomTreeBuilder.Build({ forDir })
    lu.assertEquals(root.children[1].kind, DomNodeKind.ForDirective)
    lu.assertEquals(#root.children[1].children, 1)
end

function TestBuild:testSiblingLinks()
    local a = HtmlNodes.CreateElement("mw-text", 1, 1)
    local b = HtmlNodes.CreateElement("mw-image", 2, 1)
    local root = DomTreeBuilder.Build({ a, b })
    lu.assertEquals(#root.children, 2)
    lu.assertEquals(root.children[1].nextSibling, root.children[2])
    lu.assertEquals(root.children[2].prevSibling, root.children[1])
end

function TestBuild:testDepthTracking()
    local outer = HtmlNodes.CreateElement("mw-flex", 1, 1)
    local mid = HtmlNodes.CreateElement("mw-grid", 2, 1)
    local inner = HtmlNodes.CreateElement("mw-text", 3, 1)
    mid.children = { inner }
    inner.parent = mid
    outer.children = { mid }
    mid.parent = outer

    local root = DomTreeBuilder.Build({ outer })
    lu.assertEquals(root.depth, 0)
    lu.assertEquals(root.children[1].depth, 1)          -- mw-flex
    lu.assertEquals(root.children[1].children[1].depth, 2) -- mw-grid
    lu.assertEquals(root.children[1].children[1].children[1].depth, 3) -- mw-text
end

function TestBuild:testAttributesCached()
    local el = HtmlNodes.CreateElement("mw-flex", 1, 1)
    el.attributes = {
        HtmlNodes.CreateAttribute("Static", "id", "main"),
        HtmlNodes.CreateAttribute("Static", "class", "wide centered"),
    }
    local root = DomTreeBuilder.Build({ el })
    local node = root.children[1]
    lu.assertEquals(node.id, "main")
    lu.assertTrue(node.classes["wide"])
    lu.assertTrue(node.classes["centered"])
end

function TestBuild:testEngineFlagPreserved()
    local engine = HtmlNodes.CreateElement("mw-root", 1, 1)
    local user = HtmlNodes.CreateElement("nox-panel", 2, 1)
    local root = DomTreeBuilder.Build({ engine, user })
    lu.assertTrue(root.children[1].isEngine)
    lu.assertFalse(root.children[1].isUserComponent)
    lu.assertFalse(root.children[2].isEngine)
    lu.assertTrue(root.children[2].isUserComponent)
end

---------------------------------------------------------------------------
-- Run
---------------------------------------------------------------------------
lu.run()
