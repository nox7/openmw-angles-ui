--- AnglesUI Test Suite — CSS Lexer
--- Tests for CSS tokenization: identifiers, hashes, strings, numbers,
--- dimensions, percentages, functions, at-keywords, operators, etc.

package.path = "scripts/Nox/AnglesUI/?.lua;scripts/Nox/AnglesUI/Tests/?.lua;scripts/Nox/AnglesUI/Parser/CSS/?.lua;" .. package.path

local lu       = require("luaunit")
local CssLexer = require("CssLexer")

local TT = CssLexer.TokenType

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function tokenize(source)
    return CssLexer.Tokenize(source)
end

--- Return all tokens except WHITESPACE and EOF.
local function significant(source)
    local all = tokenize(source)
    local out = {}
    for _, t in ipairs(all) do
        if t.type ~= TT.WHITESPACE and t.type ~= TT.EOF then
            out[#out + 1] = t
        end
    end
    return out
end

--- Return types of all significant tokens.
local function types(source)
    local toks = significant(source)
    local out = {}
    for _, t in ipairs(toks) do out[#out + 1] = t.type end
    return out
end

---------------------------------------------------------------------------
-- TestIdentTokens
---------------------------------------------------------------------------
TestIdentTokens = {}

function TestIdentTokens:testSimpleIdent()
    local toks = significant("color")
    lu.assertEquals(#toks, 1)
    lu.assertEquals(toks[1].type, TT.IDENT)
    lu.assertEquals(toks[1].value, "color")
end

function TestIdentTokens:testHyphenatedIdent()
    local toks = significant("background-color")
    lu.assertEquals(#toks, 1)
    lu.assertEquals(toks[1].type, TT.IDENT)
    lu.assertEquals(toks[1].value, "background-color")
end

function TestIdentTokens:testCustomProperty()
    local toks = significant("--my-var")
    lu.assertEquals(#toks, 1)
    lu.assertEquals(toks[1].type, TT.IDENT)
    lu.assertEquals(toks[1].value, "--my-var")
end

---------------------------------------------------------------------------
-- TestHashTokens
---------------------------------------------------------------------------
TestHashTokens = {}

function TestHashTokens:testIdSelector()
    local toks = significant("#myId")
    lu.assertEquals(#toks, 1)
    lu.assertEquals(toks[1].type, TT.HASH)
    lu.assertEquals(toks[1].value, "myId")
end

function TestHashTokens:testHexColor()
    local toks = significant("#ff0000")
    lu.assertEquals(#toks, 1)
    lu.assertEquals(toks[1].type, TT.HASH)
    lu.assertEquals(toks[1].value, "ff0000")
end

---------------------------------------------------------------------------
-- TestStringTokens
---------------------------------------------------------------------------
TestStringTokens = {}

function TestStringTokens:testDoubleQuotedString()
    local toks = significant('"hello world"')
    lu.assertEquals(#toks, 1)
    lu.assertEquals(toks[1].type, TT.STRING)
    lu.assertEquals(toks[1].value, "hello world")
end

function TestStringTokens:testSingleQuotedString()
    local toks = significant("'textures/img.dds'")
    lu.assertEquals(#toks, 1)
    lu.assertEquals(toks[1].type, TT.STRING)
    lu.assertEquals(toks[1].value, "textures/img.dds")
end

---------------------------------------------------------------------------
-- TestNumericTokens
---------------------------------------------------------------------------
TestNumericTokens = {}

function TestNumericTokens:testPlainNumber()
    local toks = significant("42")
    lu.assertEquals(#toks, 1)
    lu.assertEquals(toks[1].type, TT.NUMBER)
    lu.assertEquals(toks[1].value, "42")
end

function TestNumericTokens:testDecimalNumber()
    local toks = significant("3.14")
    lu.assertEquals(#toks, 1)
    lu.assertEquals(toks[1].type, TT.NUMBER)
    lu.assertEquals(toks[1].value, "3.14")
end

function TestNumericTokens:testDimension()
    local toks = significant("16px")
    lu.assertEquals(#toks, 1)
    lu.assertEquals(toks[1].type, TT.DIMENSION)
    lu.assertEquals(toks[1].value, "16px")
end

function TestNumericTokens:testPercentage()
    local toks = significant("50%")
    lu.assertEquals(#toks, 1)
    lu.assertEquals(toks[1].type, TT.PERCENTAGE)
    lu.assertEquals(toks[1].value, "50%")
end

function TestNumericTokens:testFrUnit()
    local toks = significant("1fr")
    lu.assertEquals(#toks, 1)
    lu.assertEquals(toks[1].type, TT.DIMENSION)
    lu.assertEquals(toks[1].value, "1fr")
end

function TestNumericTokens:testNegativeDimension()
    local toks = significant("-10px")
    lu.assertEquals(#toks, 1)
    lu.assertEquals(toks[1].type, TT.DIMENSION)
    lu.assertEquals(toks[1].value, "-10px")
end

---------------------------------------------------------------------------
-- TestFunctionToken
---------------------------------------------------------------------------
TestFunctionToken = {}

function TestFunctionToken:testVarFunction()
    local toks = significant("var(")
    lu.assertEquals(toks[1].type, TT.FUNCTION_TOKEN)
    lu.assertEquals(toks[1].value, "var")
end

function TestFunctionToken:testRepeatFunction()
    local toks = significant("repeat(")
    lu.assertEquals(toks[1].type, TT.FUNCTION_TOKEN)
    lu.assertEquals(toks[1].value, "repeat")
end

function TestFunctionToken:testRgbFunction()
    local toks = significant("rgb(")
    lu.assertEquals(toks[1].type, TT.FUNCTION_TOKEN)
    lu.assertEquals(toks[1].value, "rgb")
end

---------------------------------------------------------------------------
-- TestAtKeyword
---------------------------------------------------------------------------
TestAtKeyword = {}

function TestAtKeyword:testMediaKeyword()
    local toks = significant("@media")
    lu.assertEquals(#toks, 1)
    lu.assertEquals(toks[1].type, TT.AT_KEYWORD)
    lu.assertEquals(toks[1].value, "media")
end

function TestAtKeyword:testContainerKeyword()
    local toks = significant("@container")
    lu.assertEquals(#toks, 1)
    lu.assertEquals(toks[1].type, TT.AT_KEYWORD)
    lu.assertEquals(toks[1].value, "container")
end

---------------------------------------------------------------------------
-- TestOperators
---------------------------------------------------------------------------
TestOperators = {}

function TestOperators:testGreater()
    local toks = significant(">")
    lu.assertEquals(toks[1].type, TT.GREATER)
end

function TestOperators:testPlus()
    local toks = significant("+")
    lu.assertEquals(toks[1].type, TT.PLUS)
end

function TestOperators:testTilde()
    local toks = significant("~")
    lu.assertEquals(toks[1].type, TT.TILDE)
end

function TestOperators:testStar()
    local toks = significant("*")
    lu.assertEquals(toks[1].type, TT.STAR)
end

function TestOperators:testAmpersand()
    local toks = significant("&")
    lu.assertEquals(toks[1].type, TT.AMPERSAND)
end

function TestOperators:testLessEqual()
    local toks = significant("<=")
    lu.assertEquals(toks[1].type, TT.LESS_EQUAL)
end

function TestOperators:testGreaterEqual()
    local toks = significant(">=")
    lu.assertEquals(toks[1].type, TT.GREATER_EQUAL)
end

---------------------------------------------------------------------------
-- TestPunctuation
---------------------------------------------------------------------------
TestPunctuation = {}

function TestPunctuation:testColon()
    local toks = significant(":")
    lu.assertEquals(toks[1].type, TT.COLON)
end

function TestPunctuation:testSemicolon()
    local toks = significant(";")
    lu.assertEquals(toks[1].type, TT.SEMICOLON)
end

function TestPunctuation:testBraces()
    local toks = significant("{}")
    lu.assertEquals(toks[1].type, TT.LBRACE)
    lu.assertEquals(toks[2].type, TT.RBRACE)
end

function TestPunctuation:testParens()
    local toks = significant("()")
    lu.assertEquals(toks[1].type, TT.LPAREN)
    lu.assertEquals(toks[2].type, TT.RPAREN)
end

function TestPunctuation:testDot()
    local toks = significant(".")
    lu.assertEquals(toks[1].type, TT.DOT)
end

function TestPunctuation:testComma()
    local toks = significant(",")
    lu.assertEquals(toks[1].type, TT.COMMA)
end

---------------------------------------------------------------------------
-- TestComments
---------------------------------------------------------------------------
TestComments = {}

function TestComments:testCommentStripped()
    local toks = significant("/* comment */ color")
    lu.assertEquals(#toks, 1)
    lu.assertEquals(toks[1].type, TT.IDENT)
    lu.assertEquals(toks[1].value, "color")
end

function TestComments:testMultiLineComment()
    local toks = significant("/* line1\nline2 */ width")
    lu.assertEquals(#toks, 1)
    lu.assertEquals(toks[1].value, "width")
end

---------------------------------------------------------------------------
-- TestWhitespace
---------------------------------------------------------------------------
TestWhitespace = {}

function TestWhitespace:testWhitespaceTokenEmitted()
    local all = tokenize("a b")
    -- Should be: IDENT, WHITESPACE, IDENT, EOF
    lu.assertEquals(all[1].type, TT.IDENT)
    lu.assertEquals(all[2].type, TT.WHITESPACE)
    lu.assertEquals(all[3].type, TT.IDENT)
end

---------------------------------------------------------------------------
-- TestComplexDeclaration
---------------------------------------------------------------------------
TestComplexDeclaration = {}

function TestComplexDeclaration:testBorderShorthand()
    local toks = significant('2px "textures/border.dds" true false')
    -- DIMENSION, STRING, IDENT, IDENT
    lu.assertEquals(toks[1].type, TT.DIMENSION)
    lu.assertEquals(toks[2].type, TT.STRING)
    lu.assertEquals(toks[3].type, TT.IDENT)
    lu.assertEquals(toks[3].value, "true")
    lu.assertEquals(toks[4].type, TT.IDENT)
    lu.assertEquals(toks[4].value, "false")
end

function TestComplexDeclaration:testVarExpression()
    local toks = significant("var(--my-color)")
    -- FUNCTION_TOKEN(var), IDENT(--my-color), RPAREN
    lu.assertEquals(toks[1].type, TT.FUNCTION_TOKEN)
    lu.assertEquals(toks[1].value, "var")
    lu.assertEquals(toks[2].type, TT.IDENT)
    lu.assertEquals(toks[2].value, "--my-color")
    lu.assertEquals(toks[3].type, TT.RPAREN)
end

function TestComplexDeclaration:testGridTemplate()
    local toks = significant("repeat(3, 1fr)")
    -- FUNCTION_TOKEN(repeat), NUMBER(3), COMMA, DIMENSION(1fr), RPAREN
    lu.assertEquals(toks[1].type, TT.FUNCTION_TOKEN)
    lu.assertEquals(toks[1].value, "repeat")
    lu.assertEquals(toks[2].type, TT.NUMBER)
    lu.assertEquals(toks[2].value, "3")
    lu.assertEquals(toks[3].type, TT.COMMA)
    lu.assertEquals(toks[4].type, TT.DIMENSION)
    lu.assertEquals(toks[4].value, "1fr")
    lu.assertEquals(toks[5].type, TT.RPAREN)
end

---------------------------------------------------------------------------
-- TestEof
---------------------------------------------------------------------------
TestEof = {}

function TestEof:testEmptyInput()
    local toks = tokenize("")
    lu.assertEquals(#toks, 1)
    lu.assertEquals(toks[1].type, TT.EOF)
end

function TestEof:testEofAlwaysLast()
    local toks = tokenize("a")
    lu.assertEquals(toks[#toks].type, TT.EOF)
end

---------------------------------------------------------------------------
-- Run
---------------------------------------------------------------------------
lu.run()
