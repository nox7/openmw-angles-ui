--- AnglesUI Test Suite — HTML Parser
--- Tests for converting an HTML token stream into an AST of nodes:
--- elements, text, output directives, @if/@else if/@else, @for.

package.path = "?.lua;scripts/Nox/AnglesUI/?.lua;scripts/Nox/AnglesUI/Tests/?.lua;scripts/Nox/AnglesUI/Parser/HTML/?.lua;" .. package.path

local lu         = require("luaunit")
local HtmlParser = require("HtmlParser")
local HtmlNodes  = require("HtmlNodes")

local NT = HtmlNodes.NodeType
local AT = HtmlNodes.AttributeType

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function parse(source)
    return HtmlParser.Parse(source)
end

--- Find the first node of a given type in a flat children list.
local function findFirst(children, nodeType)
    for _, child in ipairs(children) do
        if child.type == nodeType then return child end
    end
    return nil
end

---------------------------------------------------------------------------
-- TestSimpleElement
---------------------------------------------------------------------------
TestSimpleElement = {}

function TestSimpleElement:testSingleElement()
    local nodes = parse("<mw-root></mw-root>")
    lu.assertEquals(#nodes, 1)
    lu.assertEquals(nodes[1].type, NT.Element)
    lu.assertEquals(nodes[1].tag, "mw-root")
end

function TestSimpleElement:testSelfClosingElement()
    local nodes = parse("<mw-image />")
    lu.assertEquals(#nodes, 1)
    lu.assertEquals(nodes[1].type, NT.Element)
    lu.assertEquals(nodes[1].tag, "mw-image")
    lu.assertTrue(nodes[1].selfClosing)
end

function TestSimpleElement:testNestedElements()
    local nodes = parse("<mw-root><mw-text></mw-text></mw-root>")
    lu.assertEquals(#nodes, 1)
    local root = nodes[1]
    lu.assertEquals(#root.children, 1)
    lu.assertEquals(root.children[1].tag, "mw-text")
end

function TestSimpleElement:testMultipleChildren()
    local nodes = parse("<mw-root><mw-text></mw-text><mw-image /></mw-root>")
    local root = nodes[1]
    lu.assertEquals(#root.children, 2)
    lu.assertEquals(root.children[1].tag, "mw-text")
    lu.assertEquals(root.children[2].tag, "mw-image")
end

function TestSimpleElement:testEngineComponentFlag()
    local nodes = parse("<mw-root></mw-root>")
    lu.assertTrue(nodes[1].isEngine)
end

function TestSimpleElement:testUserComponentFlag()
    local nodes = parse("<nox-custom></nox-custom>")
    lu.assertTrue(nodes[1].isUserComponent)
    lu.assertFalse(nodes[1].isEngine)
end

---------------------------------------------------------------------------
-- TestAttributes
---------------------------------------------------------------------------
TestParserAttributes = {}

function TestParserAttributes:testStaticAttribute()
    local nodes = parse('<mw-root Layer="Windows"></mw-root>')
    local attrs = nodes[1].attributes
    lu.assertEquals(#attrs, 1)
    lu.assertEquals(attrs[1].type, AT.Static)
    lu.assertEquals(attrs[1].name, "Layer")
    lu.assertEquals(attrs[1].value, "Windows")
end

function TestParserAttributes:testPropertyBinding()
    local nodes = parse('<mw-image [Resource]="item.Icon" />')
    local attrs = nodes[1].attributes
    lu.assertEquals(#attrs, 1)
    lu.assertEquals(attrs[1].type, AT.Binding)
    lu.assertEquals(attrs[1].name, "Resource")
    lu.assertEquals(attrs[1].value, "item.Icon")
end

function TestParserAttributes:testStyleBinding()
    local nodes = parse('<mw-root [style.width]="\'800px\'"></mw-root>')
    local attrs = nodes[1].attributes
    lu.assertEquals(#attrs, 1)
    lu.assertEquals(attrs[1].type, AT.StyleBinding)
    lu.assertEquals(attrs[1].name, "style")
    lu.assertEquals(attrs[1].property, "width")
end

function TestParserAttributes:testAttrBinding()
    local nodes = parse('<mw-root [attr.id]="myId"></mw-root>')
    local attrs = nodes[1].attributes
    lu.assertEquals(#attrs, 1)
    lu.assertEquals(attrs[1].type, AT.AttrBinding)
    lu.assertEquals(attrs[1].name, "attr")
    lu.assertEquals(attrs[1].property, "id")
end

function TestParserAttributes:testEventBinding()
    local nodes = parse('<mw-text (click)="DoIt()"></mw-text>')
    local attrs = nodes[1].attributes
    lu.assertEquals(#attrs, 1)
    lu.assertEquals(attrs[1].type, AT.Event)
    lu.assertEquals(attrs[1].name, "click")
    lu.assertEquals(attrs[1].value, "DoIt()")
end

---------------------------------------------------------------------------
-- TestTextNode
---------------------------------------------------------------------------
TestTextNode = {}

function TestTextNode:testPlainText()
    local nodes = parse("<mw-text>Hello</mw-text>")
    local text = findFirst(nodes[1].children, NT.Text)
    lu.assertNotNil(text)
    lu.assertEquals(text.content, "Hello")
end

function TestTextNode:testWhitespacePreserved()
    local nodes = parse("<mw-text>  spaces  </mw-text>")
    local text = findFirst(nodes[1].children, NT.Text)
    lu.assertNotNil(text)
    lu.assertEquals(text.content, "  spaces  ")
end

---------------------------------------------------------------------------
-- TestOutputDirective
---------------------------------------------------------------------------
TestOutputDirective = {}

function TestOutputDirective:testSimpleOutput()
    local nodes = parse("<mw-text>{{ name() }}</mw-text>")
    local out = findFirst(nodes[1].children, NT.Output)
    lu.assertNotNil(out)
    lu.assertStrContains(out.expression, "name()")
end

function TestOutputDirective:testOutputBetweenText()
    local nodes = parse("<mw-text>Hello {{ name() }} World</mw-text>")
    local children = nodes[1].children
    lu.assertTrue(#children >= 3) -- TEXT, OUTPUT, TEXT
end

---------------------------------------------------------------------------
-- TestIfDirective
---------------------------------------------------------------------------
TestIfDirective = {}

function TestIfDirective:testSimpleIf()
    local nodes = parse("<mw-root>@if (show()) { <mw-text></mw-text> }</mw-root>")
    local ifDir = findFirst(nodes[1].children, NT.IfDirective)
    lu.assertNotNil(ifDir)
    lu.assertStrContains(ifDir.condition, "show()")
    lu.assertTrue(#ifDir.children >= 1)
end

function TestIfDirective:testIfElse()
    local src = "<mw-root>@if (a()) { <mw-text></mw-text> } @else { <mw-image /> }</mw-root>"
    local nodes = parse(src)
    local ifDir = findFirst(nodes[1].children, NT.IfDirective)
    lu.assertNotNil(ifDir)
    -- The else branch is stored as elseBranch
    lu.assertNotNil(ifDir.elseBranch)
end

function TestIfDirective:testIfElseIf()
    local src = "<mw-root>@if (a()) { } @else if (b()) { }</mw-root>"
    local nodes = parse(src)
    local ifDir = findFirst(nodes[1].children, NT.IfDirective)
    lu.assertNotNil(ifDir)
end

function TestIfDirective:testNestedIf()
    local src = "<mw-root>@if (a()) { @if (b()) { <mw-text></mw-text> } }</mw-root>"
    local nodes = parse(src)
    local ifDir = findFirst(nodes[1].children, NT.IfDirective)
    lu.assertNotNil(ifDir)
    local nestedIf = findFirst(ifDir.children, NT.IfDirective)
    lu.assertNotNil(nestedIf)
end

---------------------------------------------------------------------------
-- TestForDirective
---------------------------------------------------------------------------
TestForDirective = {}

function TestForDirective:testSimpleFor()
    local src = "<mw-root>@for (item in list()) { <mw-text></mw-text> }</mw-root>"
    local nodes = parse(src)
    local forDir = findFirst(nodes[1].children, NT.ForDirective)
    lu.assertNotNil(forDir)
    lu.assertEquals(forDir.iteratorName, "item")
    lu.assertStrContains(forDir.iterableExpression, "list()")
    lu.assertTrue(#forDir.children >= 1)
end

function TestForDirective:testNestedFor()
    local src = "<mw-root>@for (a in A()) { @for (b in B()) { } }</mw-root>"
    local nodes = parse(src)
    local forDir = findFirst(nodes[1].children, NT.ForDirective)
    lu.assertNotNil(forDir)
    local nestedFor = findFirst(forDir.children, NT.ForDirective)
    lu.assertNotNil(nestedFor)
    lu.assertEquals(nestedFor.iteratorName, "b")
end

function TestForDirective:testForWithOutput()
    local src = "<mw-root>@for (item in items()) { <mw-text>{{ item.Name }}</mw-text> }</mw-root>"
    local nodes = parse(src)
    local forDir = findFirst(nodes[1].children, NT.ForDirective)
    lu.assertNotNil(forDir)
    local textEl = findFirst(forDir.children, NT.Element)
    lu.assertNotNil(textEl)
    local outDir = findFirst(textEl.children, NT.Output)
    lu.assertNotNil(outDir)
end

---------------------------------------------------------------------------
-- TestParentReferences
---------------------------------------------------------------------------
TestParentReferences = {}

function TestParentReferences:testChildHasParent()
    local nodes = parse("<mw-root><mw-text></mw-text></mw-root>")
    local child = nodes[1].children[1]
    lu.assertNotNil(child.parent)
    lu.assertEquals(child.parent.tag, "mw-root")
end

function TestParentReferences:testTopLevelHasNoParent()
    local nodes = parse("<mw-root></mw-root>")
    lu.assertNil(nodes[1].parent)
end

---------------------------------------------------------------------------
-- TestComplexTemplate
---------------------------------------------------------------------------
TestComplexTemplate = {}

function TestComplexTemplate:testFullTemplate()
    local src = [[
<mw-root Layer="Something" [style.width]="'800px'">
  @if (SomeSignal()) {
    <mw-flex>
      <mw-text>Hello world!</mw-text>
    </mw-flex>
  }

  @for (item in Items().Armor) {
    <mw-flex (click)="OnClick()">
      <mw-image [Resource]="item.Icon" />
      <mw-text>{{ item.Name }}</mw-text>
    </mw-flex>
  }
</mw-root>
]]
    local nodes = parse(src)
    lu.assertTrue(#nodes >= 1)
    lu.assertEquals(nodes[1].tag, "mw-root")
    -- Should have @if and @for as children (among possible text nodes)
    local ifDir = findFirst(nodes[1].children, NT.IfDirective)
    local forDir = findFirst(nodes[1].children, NT.ForDirective)
    lu.assertNotNil(ifDir)
    lu.assertNotNil(forDir)
end

---------------------------------------------------------------------------
-- Run
---------------------------------------------------------------------------
lu.run()
