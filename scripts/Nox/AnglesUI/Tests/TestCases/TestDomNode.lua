--- AnglesUI Test Suite — DomNode
--- Tests for DomNode construction, child management, traversal, containers,
--- positioned ancestors, dirty marking, and attribute caching.

package.path = "?.lua;scripts/Nox/AnglesUI/?.lua;scripts/Nox/AnglesUI/Tests/?.lua;scripts/Nox/AnglesUI/DOM/?.lua;scripts/Nox/AnglesUI/Parser/HTML/?.lua;scripts/Nox/AnglesUI/Parser/CSS/?.lua;" .. package.path

local lu = require("luaunit")
local HtmlNodes = require("HtmlNodes")
local DomNode   = require("DomNode")

local DomNodeKind = DomNode.DomNodeKind

--- Helper: make an element DomNode quickly.
local function makeEl(tag, opts)
    opts = opts or {}
    local html = HtmlNodes.CreateElement(tag, 0, 0)
    if opts.id then
        html.attributes[#html.attributes + 1] = HtmlNodes.CreateAttribute("Static", "id", opts.id)
    end
    if opts.class then
        html.attributes[#html.attributes + 1] = HtmlNodes.CreateAttribute("Static", "class", opts.class)
    end
    if opts.attrs then
        for k, v in pairs(opts.attrs) do
            html.attributes[#html.attributes + 1] = HtmlNodes.CreateAttribute("Static", k, v)
        end
    end
    return DomNode.FromElement(html, nil, opts.depth or 0)
end

---------------------------------------------------------------------------
-- TestConstruction
---------------------------------------------------------------------------
TestConstruction = {}

function TestConstruction:testFromElement()
    local node = makeEl("mw-flex")
    lu.assertEquals(node.kind, DomNodeKind.Element)
    lu.assertEquals(node.tag, "mw-flex")
    lu.assertTrue(node.isEngine)
    lu.assertFalse(node.isUserComponent)
    lu.assertEquals(#node.children, 0)
    lu.assertTrue(node.isDirty)
end

function TestConstruction:testFromText()
    local html = HtmlNodes.CreateText("hello", 1, 1)
    local node = DomNode.FromText(html, nil, 0)
    lu.assertEquals(node.kind, DomNodeKind.Text)
    lu.assertNil(node.tag)
end

function TestConstruction:testFromOutput()
    local html = HtmlNodes.CreateOutput("x + 1", 1, 1)
    local node = DomNode.FromOutput(html, nil, 0)
    lu.assertEquals(node.kind, DomNodeKind.Output)
end

function TestConstruction:testFromIfDirective()
    local html = HtmlNodes.CreateIfDirective("Show()", 1, 1)
    local node = DomNode.FromIfDirective(html, nil, 0)
    lu.assertEquals(node.kind, DomNodeKind.IfDirective)
end

function TestConstruction:testFromForDirective()
    local html = HtmlNodes.CreateForDirective("item", "Items()", 1, 1)
    local node = DomNode.FromForDirective(html, nil, 0)
    lu.assertEquals(node.kind, DomNodeKind.ForDirective)
end

function TestConstruction:testIdCached()
    local node = makeEl("mw-text", { id = "title" })
    lu.assertEquals(node.id, "title")
end

function TestConstruction:testClassesCached()
    local node = makeEl("mw-flex", { class = "a b c" })
    lu.assertTrue(node.classes["a"])
    lu.assertTrue(node.classes["b"])
    lu.assertTrue(node.classes["c"])
    lu.assertNil(node.classes["d"])
end

function TestConstruction:testUserComponent()
    local node = makeEl("nox-panel")
    lu.assertFalse(node.isEngine)
    lu.assertTrue(node.isUserComponent)
end

---------------------------------------------------------------------------
-- TestChildManagement
---------------------------------------------------------------------------
TestChildManagement = {}

function TestChildManagement:testAppendChild()
    local parent = makeEl("mw-flex")
    local child = makeEl("mw-text")
    parent:AppendChild(child)
    lu.assertEquals(#parent.children, 1)
    lu.assertEquals(child.parent, parent)
    lu.assertEquals(child.depth, 1)
end

function TestChildManagement:testSiblingLinks()
    local parent = makeEl("mw-flex")
    local a = makeEl("mw-text")
    local b = makeEl("mw-text")
    local c = makeEl("mw-text")
    parent:AppendChild(a)
    parent:AppendChild(b)
    parent:AppendChild(c)
    lu.assertEquals(a.nextSibling, b)
    lu.assertEquals(b.prevSibling, a)
    lu.assertEquals(b.nextSibling, c)
    lu.assertEquals(c.prevSibling, b)
    lu.assertNil(a.prevSibling)
    lu.assertNil(c.nextSibling)
end

function TestChildManagement:testRemoveChild()
    local parent = makeEl("mw-flex")
    local a = makeEl("mw-text")
    local b = makeEl("mw-text")
    local c = makeEl("mw-text")
    parent:AppendChild(a)
    parent:AppendChild(b)
    parent:AppendChild(c)
    parent:RemoveChild(b)
    lu.assertEquals(#parent.children, 2)
    lu.assertEquals(a.nextSibling, c)
    lu.assertEquals(c.prevSibling, a)
    lu.assertNil(b.parent)
end

function TestChildManagement:testSetChildren()
    local parent = makeEl("mw-flex")
    local a = makeEl("mw-text")
    local b = makeEl("mw-text")
    parent:AppendChild(a)
    local x = makeEl("mw-image")
    local y = makeEl("mw-image")
    parent:SetChildren({ x, y })
    lu.assertEquals(#parent.children, 2)
    lu.assertEquals(parent.children[1], x)
    lu.assertEquals(parent.children[2], y)
    lu.assertNil(a.parent)
    lu.assertEquals(x.nextSibling, y)
end

---------------------------------------------------------------------------
-- TestTraversal
---------------------------------------------------------------------------
TestTraversal = {}

function TestTraversal:testGetAncestors()
    local root = makeEl("mw-root")
    local mid = makeEl("mw-flex")
    local leaf = makeEl("mw-text")
    root:AppendChild(mid)
    mid:AppendChild(leaf)
    local anc = leaf:GetAncestors()
    lu.assertEquals(#anc, 2)
    lu.assertEquals(anc[1], mid)
    lu.assertEquals(anc[2], root)
end

function TestTraversal:testGetDescendants()
    local root = makeEl("mw-root")
    local a = makeEl("mw-flex")
    local b = makeEl("mw-text")
    root:AppendChild(a)
    a:AppendChild(b)
    local desc = root:GetDescendants()
    lu.assertEquals(#desc, 2)
    lu.assertEquals(desc[1], a)
    lu.assertEquals(desc[2], b)
end

function TestTraversal:testGetElementDescendants()
    local root = makeEl("mw-root")
    local el = makeEl("mw-text")
    local txt = DomNode.FromText(HtmlNodes.CreateText("hi", 0, 0), nil, 0)
    root:AppendChild(el)
    root:AppendChild(txt)
    local elDesc = root:GetElementDescendants()
    lu.assertEquals(#elDesc, 1)
    lu.assertEquals(elDesc[1], el)
end

function TestTraversal:testWalk()
    local root = makeEl("mw-root")
    local a = makeEl("mw-flex")
    local b = makeEl("mw-text")
    root:AppendChild(a)
    a:AppendChild(b)
    local visited = {}
    root:Walk(function(n) visited[#visited + 1] = n.tag; return false end)
    lu.assertEquals(#visited, 3)
    lu.assertEquals(visited[1], "mw-root")
    lu.assertEquals(visited[2], "mw-flex")
    lu.assertEquals(visited[3], "mw-text")
end

function TestTraversal:testWalkEarlyStop()
    local root = makeEl("mw-root")
    local a = makeEl("mw-flex")
    local b = makeEl("mw-text")
    root:AppendChild(a)
    a:AppendChild(b)
    local visited = {}
    root:Walk(function(n)
        visited[#visited + 1] = n.tag
        return n.tag == "mw-flex"
    end)
    lu.assertEquals(#visited, 2) -- stopped at mw-flex
end

---------------------------------------------------------------------------
-- TestContainerLookup
---------------------------------------------------------------------------
TestContainerLookup = {}

function TestContainerLookup:testFindNearestContainer()
    local root = makeEl("mw-root")
    root.isContainer = true
    local mid = makeEl("mw-flex")
    local leaf = makeEl("mw-text")
    root:AppendChild(mid)
    mid:AppendChild(leaf)
    lu.assertEquals(leaf:FindNearestContainer(), root)
end

function TestContainerLookup:testFindNearestContainerClosest()
    local root = makeEl("mw-root")
    root.isContainer = true
    local mid = makeEl("mw-flex")
    mid.isContainer = true
    local leaf = makeEl("mw-text")
    root:AppendChild(mid)
    mid:AppendChild(leaf)
    lu.assertEquals(leaf:FindNearestContainer(), mid)
end

function TestContainerLookup:testFindNamedContainer()
    local root = makeEl("mw-root")
    root.isContainer = true
    root.containerName = "main"
    local mid = makeEl("mw-flex")
    mid.isContainer = true
    mid.containerName = "sidebar"
    local leaf = makeEl("mw-text")
    root:AppendChild(mid)
    mid:AppendChild(leaf)
    lu.assertEquals(leaf:FindNamedContainer("main"), root)
    lu.assertEquals(leaf:FindNamedContainer("sidebar"), mid)
end

function TestContainerLookup:testFindNearestContainerNone()
    local node = makeEl("mw-text")
    lu.assertNil(node:FindNearestContainer())
end

---------------------------------------------------------------------------
-- TestPositionedAncestor
---------------------------------------------------------------------------
TestPositionedAncestor = {}

function TestPositionedAncestor:testFindPositioned()
    local root = makeEl("mw-root")
    root.computedStyles["position"] = "relative"
    local child = makeEl("mw-text")
    root:AppendChild(child)
    lu.assertEquals(child:FindPositionedAncestor(), root)
end

function TestPositionedAncestor:testSkipsStatic()
    local root = makeEl("mw-root")
    root.computedStyles["position"] = "relative"
    local mid = makeEl("mw-flex")
    mid.computedStyles["position"] = "static"
    local leaf = makeEl("mw-text")
    root:AppendChild(mid)
    mid:AppendChild(leaf)
    lu.assertEquals(leaf:FindPositionedAncestor(), root)
end

function TestPositionedAncestor:testNoneFound()
    local node = makeEl("mw-text")
    lu.assertNil(node:FindPositionedAncestor())
end

---------------------------------------------------------------------------
-- TestDirtyMarking
---------------------------------------------------------------------------
TestDirtyMarking = {}

function TestDirtyMarking:testMarkDirtyPropagatesUp()
    local root = makeEl("mw-root")
    root:ClearDirty()
    local child = makeEl("mw-text")
    root:AppendChild(child)
    child:ClearDirty()
    root:ClearDirty()
    child:MarkDirty()
    lu.assertTrue(child.isDirty)
    lu.assertTrue(root.isDirty)
end

function TestDirtyMarking:testClearDirty()
    local node = makeEl("mw-text")
    lu.assertTrue(node.isDirty)
    node:ClearDirty()
    lu.assertFalse(node.isDirty)
end

function TestDirtyMarking:testClearDirtyRecursive()
    local root = makeEl("mw-root")
    local child = makeEl("mw-text")
    root:AppendChild(child)
    lu.assertTrue(root.isDirty)
    lu.assertTrue(child.isDirty)
    root:ClearDirtyRecursive()
    lu.assertFalse(root.isDirty)
    lu.assertFalse(child.isDirty)
end

---------------------------------------------------------------------------
-- Run
---------------------------------------------------------------------------
lu.run()
