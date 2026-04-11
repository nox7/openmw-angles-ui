--- AnglesUI Test Suite — Content Projection
--- Tests for Angular-style content projection via <mw-content> elements:
--- default slots, select slots, multiple slots, and stripping.

package.path = "?.lua;scripts/Nox/AnglesUI/?.lua;scripts/Nox/AnglesUI/Tests/?.lua;scripts/Nox/AnglesUI/Components/?.lua;scripts/Nox/AnglesUI/Parser/HTML/?.lua;scripts/Nox/AnglesUI/Parser/CSS/?.lua;" .. package.path

local lu = require("luaunit")
local HtmlNodes          = require("HtmlNodes")
local ContentProjection  = require("ContentProjection")

local NodeType = HtmlNodes.NodeType

--- Helper: create element node.
local function el(tag, children, attrs)
    local node = HtmlNodes.CreateElement(tag, 0, 0)
    if children then
        for _, c in ipairs(children) do
            node.children[#node.children + 1] = c
            c.parent = node
        end
    end
    if attrs then
        for _, a in ipairs(attrs) do
            node.attributes[#node.attributes + 1] = a
        end
    end
    return node
end

--- Helper: create text node.
local function txt(content)
    return HtmlNodes.CreateText(content, 0, 0)
end

--- Helper: create mw-content node with optional select attribute.
local function contentSlot(selector)
    local node = el("mw-content")
    if selector then
        node.attributes[#node.attributes + 1] = HtmlNodes.CreateAttribute("Static", "select", selector)
    end
    return node
end

---------------------------------------------------------------------------
-- TestDefaultSlot
---------------------------------------------------------------------------
TestDefaultSlot = {}

function TestDefaultSlot:testProjectIntoDefaultSlot()
    -- Template: <mw-flex><mw-content></mw-content></mw-flex>
    -- Projected: <mw-text>Hello</mw-text>
    local template = { el("mw-flex", { contentSlot() }) }
    local projected = { el("mw-text", { txt("Hello") }) }
    local result = ContentProjection.Project(template, projected)
    lu.assertEquals(#result, 1)
    lu.assertEquals(result[1].tag, "mw-flex")
    lu.assertEquals(#result[1].children, 1)
    lu.assertEquals(result[1].children[1].tag, "mw-text")
end

function TestDefaultSlot:testMultipleProjectedChildren()
    local template = { el("mw-flex", { contentSlot() }) }
    local projected = { el("mw-text"), el("mw-image") }
    local result = ContentProjection.Project(template, projected)
    lu.assertEquals(#result[1].children, 2)
    lu.assertEquals(result[1].children[1].tag, "mw-text")
    lu.assertEquals(result[1].children[2].tag, "mw-image")
end

function TestDefaultSlot:testNoProjectedContent()
    local template = { el("mw-flex", { contentSlot() }) }
    local result = ContentProjection.Project(template, {})
    lu.assertEquals(#result, 1)
    lu.assertEquals(result[1].tag, "mw-flex")
    lu.assertEquals(#result[1].children, 0)
end

function TestDefaultSlot:testNilProjectedContent()
    local template = { el("mw-flex", { contentSlot() }) }
    local result = ContentProjection.Project(template, nil)
    lu.assertEquals(#result, 1)
    lu.assertEquals(#result[1].children, 0)
end

---------------------------------------------------------------------------
-- TestSelectSlot
---------------------------------------------------------------------------
TestSelectSlot = {}

function TestSelectSlot:testSelectByClass()
    -- Template: <mw-flex><mw-content select=".header"></mw-content><mw-content></mw-content></mw-flex>
    -- Projected: <mw-text class="header">Title</mw-text>, <mw-text>Body</mw-text>
    local template = { el("mw-flex", { contentSlot(".header"), contentSlot() }) }
    local header = el("mw-text", { txt("Title") }, { HtmlNodes.CreateAttribute("Static", "class", "header") })
    local body = el("mw-text", { txt("Body") })
    local projected = { header, body }
    local result = ContentProjection.Project(template, projected)
    -- The flex should have two children: the header (from select) and body (from default)
    lu.assertEquals(#result[1].children, 2)
    lu.assertEquals(result[1].children[1], header)
    lu.assertEquals(result[1].children[2], body)
end

function TestSelectSlot:testSelectByTag()
    local template = { el("mw-flex", { contentSlot("mw-image"), contentSlot() }) }
    local img = el("mw-image")
    local text = el("mw-text")
    local projected = { text, img }
    local result = ContentProjection.Project(template, projected)
    lu.assertEquals(#result[1].children, 2)
    -- Image should be first (from select slot), text second (default slot)
    lu.assertEquals(result[1].children[1], img)
    lu.assertEquals(result[1].children[2], text)
end

function TestSelectSlot:testSelectClaimsChildrenFromDefault()
    -- Select slot claims the matching child, default gets the rest
    local template = { el("mw-flex", { contentSlot(".special"), contentSlot() }) }
    local special = el("mw-text", nil, { HtmlNodes.CreateAttribute("Static", "class", "special") })
    local normal1 = el("mw-text")
    local normal2 = el("mw-text")
    local projected = { normal1, special, normal2 }
    local result = ContentProjection.Project(template, projected)
    lu.assertEquals(#result[1].children, 3)
    lu.assertEquals(result[1].children[1], special)
    lu.assertEquals(result[1].children[2], normal1)
    lu.assertEquals(result[1].children[3], normal2)
end

---------------------------------------------------------------------------
-- TestMultipleSlots
---------------------------------------------------------------------------
TestMultipleSlots = {}

function TestMultipleSlots:testTwoSelectSlots()
    local template = { el("mw-flex", {
        contentSlot(".a"),
        contentSlot(".b"),
        contentSlot(),
    }) }
    local childA = el("mw-text", nil, { HtmlNodes.CreateAttribute("Static", "class", "a") })
    local childB = el("mw-text", nil, { HtmlNodes.CreateAttribute("Static", "class", "b") })
    local childC = el("mw-text")
    local projected = { childA, childB, childC }
    local result = ContentProjection.Project(template, projected)
    lu.assertEquals(#result[1].children, 3)
    lu.assertEquals(result[1].children[1], childA)
    lu.assertEquals(result[1].children[2], childB)
    lu.assertEquals(result[1].children[3], childC)
end

function TestMultipleSlots:testSecondDefaultSlotGetsNothing()
    -- Two default slots: first gets unclaimed, second gets nothing
    local template = { el("mw-flex", { contentSlot(), contentSlot() }) }
    local projected = { el("mw-text") }
    local result = ContentProjection.Project(template, projected)
    -- Only one child projected into first default slot
    lu.assertEquals(#result[1].children, 1)
end

---------------------------------------------------------------------------
-- TestNestedContentSlots
---------------------------------------------------------------------------
TestNestedContentSlots = {}

function TestNestedContentSlots:testSlotInsideNestedElement()
    -- Template: <mw-flex><mw-grid><mw-content></mw-content></mw-grid></mw-flex>
    local inner = el("mw-grid", { contentSlot() })
    local template = { el("mw-flex", { inner }) }
    local projected = { el("mw-text") }
    local result = ContentProjection.Project(template, projected)
    lu.assertEquals(result[1].tag, "mw-flex")
    local grid = result[1].children[1]
    lu.assertEquals(grid.tag, "mw-grid")
    lu.assertEquals(#grid.children, 1)
    lu.assertEquals(grid.children[1].tag, "mw-text")
end

---------------------------------------------------------------------------
-- TestStripContentNodes
---------------------------------------------------------------------------
TestStripContentNodes = {}

function TestStripContentNodes:testStripsWhenNoProjectedContent()
    local template = { el("mw-flex", { contentSlot(), el("mw-text") }) }
    local result = ContentProjection.Project(template, nil)
    lu.assertEquals(#result[1].children, 1)
    lu.assertEquals(result[1].children[1].tag, "mw-text")
end

function TestStripContentNodes:testStripsNestedContentSlots()
    local inner = el("mw-grid", { contentSlot() })
    local template = { el("mw-flex", { inner }) }
    local result = ContentProjection.Project(template, nil)
    local grid = result[1].children[1]
    lu.assertEquals(#grid.children, 0)
end

---------------------------------------------------------------------------
-- TestEdgeCases
---------------------------------------------------------------------------
TestEdgeCases = {}

function TestEdgeCases:testTextNodeProjected()
    local template = { el("mw-flex", { contentSlot() }) }
    local projected = { txt("Hello world") }
    local result = ContentProjection.Project(template, projected)
    lu.assertEquals(#result[1].children, 1)
    lu.assertEquals(result[1].children[1].type, NodeType.Text)
    lu.assertEquals(result[1].children[1].content, "Hello world")
end

function TestEdgeCases:testNoContentSlotInTemplate()
    -- Template has no mw-content at all — projected content is lost
    local template = { el("mw-flex", { el("mw-text") }) }
    local projected = { el("mw-image") }
    local result = ContentProjection.Project(template, projected)
    lu.assertEquals(#result, 1)
    lu.assertEquals(#result[1].children, 1)
    lu.assertEquals(result[1].children[1].tag, "mw-text")
end

---------------------------------------------------------------------------
-- Run
---------------------------------------------------------------------------
lu.run()
