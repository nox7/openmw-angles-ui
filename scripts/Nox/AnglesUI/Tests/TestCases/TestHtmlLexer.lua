--- AnglesUI Test Suite — HTML Lexer
--- Tests for the HTML tokenizer: tags, attributes, bindings, events,
--- directives, output interpolation, and text nodes.

package.path = "scripts/Nox/AnglesUI/?.lua;scripts/Nox/AnglesUI/Tests/?.lua;scripts/Nox/AnglesUI/Parser/HTML/?.lua;" .. package.path

local lu        = require("luaunit")
local HtmlLexer = require("HtmlLexer")

local TT = HtmlLexer.TokenType

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

--- Tokenize and strip whitespace-only TEXT tokens for easier assertions.
local function tokenize(source)
    return HtmlLexer.Tokenize(source)
end

--- Return only non-EOF tokens.
local function tokensNoEof(source)
    local all = tokenize(source)
    local out = {}
    for _, t in ipairs(all) do
        if t.type ~= TT.EOF then out[#out + 1] = t end
    end
    return out
end

---------------------------------------------------------------------------
-- TestTagTokens — Basic open/close tag tokenization
---------------------------------------------------------------------------
TestTagTokens = {}

function TestTagTokens:testSimpleTag()
    local tokens = tokensNoEof("<mw-root></mw-root>")
    lu.assertEquals(tokens[1].type, TT.TAG_OPEN)
    lu.assertEquals(tokens[1].value, "mw-root")
    lu.assertEquals(tokens[2].type, TT.TAG_END)
    lu.assertEquals(tokens[3].type, TT.TAG_CLOSE)
    lu.assertEquals(tokens[3].value, "mw-root")
end

function TestTagTokens:testSelfClosingTag()
    local tokens = tokensNoEof("<mw-image />")
    lu.assertEquals(tokens[1].type, TT.TAG_OPEN)
    lu.assertEquals(tokens[1].value, "mw-image")
    lu.assertEquals(tokens[2].type, TT.SELF_CLOSE)
end

function TestTagTokens:testNestedTags()
    local tokens = tokensNoEof("<mw-root><mw-text></mw-text></mw-root>")
    lu.assertEquals(tokens[1].type, TT.TAG_OPEN)
    lu.assertEquals(tokens[1].value, "mw-root")
    lu.assertEquals(tokens[2].type, TT.TAG_END)
    lu.assertEquals(tokens[3].type, TT.TAG_OPEN)
    lu.assertEquals(tokens[3].value, "mw-text")
    lu.assertEquals(tokens[4].type, TT.TAG_END)
    lu.assertEquals(tokens[5].type, TT.TAG_CLOSE)
    lu.assertEquals(tokens[5].value, "mw-text")
    lu.assertEquals(tokens[6].type, TT.TAG_CLOSE)
    lu.assertEquals(tokens[6].value, "mw-root")
end

function TestTagTokens:testEofEmitted()
    local tokens = HtmlLexer.Tokenize("")
    lu.assertEquals(#tokens, 1)
    lu.assertEquals(tokens[1].type, TT.EOF)
end

---------------------------------------------------------------------------
-- TestAttributes — Static attributes
---------------------------------------------------------------------------
TestAttributes = {}

function TestAttributes:testUnquotedAttribute()
    local tokens = tokensNoEof('<mw-root Layer="Windows"></mw-root>')
    -- TAG_OPEN, ATTRIBUTE, TAG_END, TAG_CLOSE
    lu.assertEquals(tokens[2].type, TT.ATTRIBUTE)
    lu.assertEquals(tokens[2].value, "Layer")
    lu.assertEquals(tokens[2].extra, "Windows")
end

function TestAttributes:testMultipleAttributes()
    local tokens = tokensNoEof('<mw-root Layer="Windows" Resizable="true"></mw-root>')
    lu.assertEquals(tokens[2].type, TT.ATTRIBUTE)
    lu.assertEquals(tokens[2].value, "Layer")
    lu.assertEquals(tokens[3].type, TT.ATTRIBUTE)
    lu.assertEquals(tokens[3].value, "Resizable")
    lu.assertEquals(tokens[3].extra, "true")
end

---------------------------------------------------------------------------
-- TestBindings — Square bracket bindings
---------------------------------------------------------------------------
TestBindings = {}

function TestBindings:testPropertyBinding()
    local tokens = tokensNoEof('<mw-image [Resource]="item.Icon"></mw-image>')
    lu.assertEquals(tokens[2].type, TT.BINDING)
    lu.assertEquals(tokens[2].value, "Resource")
    lu.assertEquals(tokens[2].extra, "item.Icon")
end

function TestBindings:testStyleBinding()
    local tokens = tokensNoEof('<mw-root [style.width]="\'800px\'"></mw-root>')
    lu.assertEquals(tokens[2].type, TT.STYLE_BINDING)
    lu.assertEquals(tokens[2].value, "width")
end

function TestBindings:testAttrBinding()
    local tokens = tokensNoEof('<mw-root [attr.id]="myId"></mw-root>')
    lu.assertEquals(tokens[2].type, TT.ATTR_BINDING)
    lu.assertEquals(tokens[2].value, "id")
end

---------------------------------------------------------------------------
-- TestEvents — Parenthesized event bindings
---------------------------------------------------------------------------
TestEvents = {}

function TestEvents:testClickEvent()
    local tokens = tokensNoEof('<mw-text (click)="OnClick()"></mw-text>')
    lu.assertEquals(tokens[2].type, TT.EVENT)
    lu.assertEquals(tokens[2].value, "click")
    lu.assertEquals(tokens[2].extra, "OnClick()")
end

function TestEvents:testMultipleEvents()
    local tokens = tokensNoEof('<mw-text (click)="A()" (mouseMove)="B()"></mw-text>')
    lu.assertEquals(tokens[2].type, TT.EVENT)
    lu.assertEquals(tokens[2].value, "click")
    lu.assertEquals(tokens[3].type, TT.EVENT)
    lu.assertEquals(tokens[3].value, "mouseMove")
end

---------------------------------------------------------------------------
-- TestTextTokens — Plain text content
---------------------------------------------------------------------------
TestTextTokens = {}

function TestTextTokens:testPlainText()
    local tokens = tokensNoEof("<mw-text>Hello world!</mw-text>")
    -- TAG_OPEN, TAG_END, TEXT, TAG_CLOSE
    local textToken = nil
    for _, t in ipairs(tokens) do
        if t.type == TT.TEXT then textToken = t; break end
    end
    lu.assertNotNil(textToken)
    lu.assertEquals(textToken.value, "Hello world!")
end

function TestTextTokens:testWhitespaceText()
    local tokens = tokensNoEof("<mw-text>   </mw-text>")
    local textToken = nil
    for _, t in ipairs(tokens) do
        if t.type == TT.TEXT then textToken = t; break end
    end
    lu.assertNotNil(textToken)
    lu.assertEquals(textToken.value, "   ")
end

---------------------------------------------------------------------------
-- TestOutputDirective — {{ expression }}
---------------------------------------------------------------------------
TestOutputDirective = {}

function TestOutputDirective:testSimpleOutput()
    local tokens = tokensNoEof("<mw-text>{{ item.Name }}</mw-text>")
    local outToken = nil
    for _, t in ipairs(tokens) do
        if t.type == TT.OUTPUT then outToken = t; break end
    end
    lu.assertNotNil(outToken)
    lu.assertStrContains(outToken.value, "item.Name")
end

function TestOutputDirective:testOutputWithTernary()
    local tokens = tokensNoEof("<mw-text>{{ x ? 'a' : 'b' }}</mw-text>")
    local outToken = nil
    for _, t in ipairs(tokens) do
        if t.type == TT.OUTPUT then outToken = t; break end
    end
    lu.assertNotNil(outToken)
    lu.assertStrContains(outToken.value, "?")
end

function TestOutputDirective:testTextAroundOutput()
    local tokens = tokensNoEof("<mw-text>Hello {{ name() }} World</mw-text>")
    local types = {}
    for _, t in ipairs(tokens) do
        types[#types + 1] = t.type
    end
    lu.assertNotNil(types)
    -- Should contain TEXT, OUTPUT, TEXT between TAG_END and TAG_CLOSE
    local foundText = false
    local foundOutput = false
    for _, t in ipairs(tokens) do
        if t.type == TT.TEXT then foundText = true end
        if t.type == TT.OUTPUT then foundOutput = true end
    end
    lu.assertTrue(foundText)
    lu.assertTrue(foundOutput)
end

---------------------------------------------------------------------------
-- TestIfDirective — @if, @else if, @else
---------------------------------------------------------------------------
TestIfDirective = {}

function TestIfDirective:testIfStart()
    local tokens = tokensNoEof("@if (x()) { }")
    lu.assertEquals(tokens[1].type, TT.IF_START)
    lu.assertStrContains(tokens[1].value, "x()")
end

function TestIfDirective:testElseIfStart()
    local tokens = tokensNoEof("@if (a) { } @else if (b) { }")
    local elseIfToken = nil
    for _, t in ipairs(tokens) do
        if t.type == TT.ELSE_IF_START then elseIfToken = t; break end
    end
    lu.assertNotNil(elseIfToken)
    lu.assertStrContains(elseIfToken.value, "b")
end

function TestIfDirective:testElseStart()
    local tokens = tokensNoEof("@if (a) { } @else { }")
    local elseToken = nil
    for _, t in ipairs(tokens) do
        if t.type == TT.ELSE_START then elseToken = t; break end
    end
    lu.assertNotNil(elseToken)
end

function TestIfDirective:testBlockOpenClose()
    local tokens = tokensNoEof("@if (cond) { }")
    -- Should have IF_START, BLOCK_OPEN, BLOCK_CLOSE
    local hasOpen = false
    local hasClose = false
    for _, t in ipairs(tokens) do
        if t.type == TT.BLOCK_OPEN then hasOpen = true end
        if t.type == TT.BLOCK_CLOSE then hasClose = true end
    end
    lu.assertTrue(hasOpen)
    lu.assertTrue(hasClose)
end

---------------------------------------------------------------------------
-- TestForDirective — @for
---------------------------------------------------------------------------
TestForDirective = {}

function TestForDirective:testForStart()
    local tokens = tokensNoEof("@for (item in Items()) { }")
    lu.assertEquals(tokens[1].type, TT.FOR_START)
end

function TestForDirective:testForHasBlockTokens()
    local tokens = tokensNoEof("@for (x in Y) { }")
    local hasOpen = false
    local hasClose = false
    for _, t in ipairs(tokens) do
        if t.type == TT.BLOCK_OPEN then hasOpen = true end
        if t.type == TT.BLOCK_CLOSE then hasClose = true end
    end
    lu.assertTrue(hasOpen)
    lu.assertTrue(hasClose)
end

---------------------------------------------------------------------------
-- TestDirectivesInTags — Directives inside element content
---------------------------------------------------------------------------
TestDirectivesInTags = {}

function TestDirectivesInTags:testIfInsideElement()
    local src = '<mw-root>@if (show()) { <mw-text>Hi</mw-text> }</mw-root>'
    local tokens = tokensNoEof(src)
    local types = {}
    for _, t in ipairs(tokens) do types[#types + 1] = t.type end
    lu.assertTrue(#types > 5)

    -- Should find TAG_OPEN(mw-root), TAG_END, IF_START, BLOCK_OPEN, TAG_OPEN(mw-text), ...
    lu.assertEquals(tokens[1].type, TT.TAG_OPEN)
    lu.assertEquals(tokens[1].value, "mw-root")
end

function TestDirectivesInTags:testForInsideElement()
    local src = '<mw-root>@for (item in list) { <mw-text>{{ item }}</mw-text> }</mw-root>'
    local tokens = tokensNoEof(src)
    local foundFor = false
    local foundOutput = false
    for _, t in ipairs(tokens) do
        if t.type == TT.FOR_START then foundFor = true end
        if t.type == TT.OUTPUT then foundOutput = true end
    end
    lu.assertTrue(foundFor)
    lu.assertTrue(foundOutput)
end

---------------------------------------------------------------------------
-- TestLineAndColumn — Position tracking
---------------------------------------------------------------------------
TestLineAndColumn = {}

function TestLineAndColumn:testFirstTokenLine()
    local tokens = tokenize("<mw-root></mw-root>")
    lu.assertEquals(tokens[1].line, 1)
end

function TestLineAndColumn:testSecondLineToken()
    local tokens = tokenize("<mw-root>\n<mw-text></mw-text>\n</mw-root>")
    -- Find the mw-text TAG_OPEN
    for _, t in ipairs(tokens) do
        if t.type == TT.TAG_OPEN and t.value == "mw-text" then
            lu.assertEquals(t.line, 2)
            return
        end
    end
    lu.fail("mw-text TAG_OPEN not found")
end

---------------------------------------------------------------------------
-- Run
---------------------------------------------------------------------------
lu.run()
