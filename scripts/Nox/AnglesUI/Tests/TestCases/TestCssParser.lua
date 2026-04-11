--- AnglesUI Test Suite — CSS Parser
--- Tests for converting a CSS token stream into a stylesheet AST:
--- rules, declarations, nested rules, @media and @container at-rules.

package.path = "?.lua;scripts/Nox/AnglesUI/?.lua;scripts/Nox/AnglesUI/Tests/?.lua;scripts/Nox/AnglesUI/Parser/CSS/?.lua;" .. package.path

local lu        = require("luaunit")
local CssParser = require("CssParser")
local CssNodes  = require("CssNodes")

local NT = CssNodes.CssNodeType

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function parse(source)
    return CssParser.Parse(source)
end

---------------------------------------------------------------------------
-- TestSimpleRule
---------------------------------------------------------------------------
TestSimpleRule = {}

function TestSimpleRule:testSingleRule()
    local ss = parse("mw-root { width: 100px; }")
    lu.assertEquals(ss.type, NT.Stylesheet)
    lu.assertEquals(#ss.rules, 1)
    lu.assertEquals(ss.rules[1].type, NT.Rule)
    lu.assertStrContains(ss.rules[1].selectorText, "mw-root")
end

function TestSimpleRule:testClassSelector()
    local ss = parse(".my-class { color: red; }")
    lu.assertEquals(#ss.rules, 1)
    lu.assertStrContains(ss.rules[1].selectorText, ".my-class")
end

function TestSimpleRule:testIdSelector()
    local ss = parse("#myId { opacity: 0.5; }")
    lu.assertEquals(#ss.rules, 1)
    lu.assertStrContains(ss.rules[1].selectorText, "#myId")
end

function TestSimpleRule:testMultipleRules()
    local ss = parse("mw-text { color: red; } mw-image { width: 50px; }")
    lu.assertEquals(#ss.rules, 2)
end

function TestSimpleRule:testCompoundSelector()
    local ss = parse(".a.b { width: 10px; }")
    lu.assertEquals(#ss.rules, 1)
    lu.assertStrContains(ss.rules[1].selectorText, ".a.b")
end

---------------------------------------------------------------------------
-- TestDeclarations
---------------------------------------------------------------------------
TestDeclarations = {}

function TestDeclarations:testSingleDeclaration()
    local ss = parse("div { width: 100px; }")
    local decls = ss.rules[1].declarations
    lu.assertEquals(#decls, 1)
    lu.assertEquals(decls[1].property, "width")
    lu.assertEquals(decls[1].value, "100px")
end

function TestDeclarations:testMultipleDeclarations()
    local ss = parse("div { width: 100px; height: 50px; color: red; }")
    local decls = ss.rules[1].declarations
    lu.assertEquals(#decls, 3)
    lu.assertEquals(decls[1].property, "width")
    lu.assertEquals(decls[2].property, "height")
    lu.assertEquals(decls[3].property, "color")
end

function TestDeclarations:testDeclarationWithFunction()
    local ss = parse("div { background-image: var(--bg); }")
    local decls = ss.rules[1].declarations
    lu.assertEquals(#decls, 1)
    lu.assertEquals(decls[1].property, "background-image")
    lu.assertStrContains(decls[1].value, "var(--bg)")
end

function TestDeclarations:testDeclarationWithMultipleValues()
    local ss = parse("div { padding: 10px 20px 30px 40px; }")
    local decls = ss.rules[1].declarations
    lu.assertEquals(decls[1].property, "padding")
    lu.assertStrContains(decls[1].value, "10px")
    lu.assertStrContains(decls[1].value, "40px")
end

function TestDeclarations:testCustomProperty()
    local ss = parse(":root { --my-color: #ff0000; }")
    local decls = ss.rules[1].declarations
    lu.assertEquals(decls[1].property, "--my-color")
    lu.assertStrContains(decls[1].value, "#ff0000")
end

function TestDeclarations:testBorderDeclaration()
    local ss = parse('mw-root { border-top: 2px "textures/border.dds" true false; }')
    local decls = ss.rules[1].declarations
    lu.assertEquals(decls[1].property, "border-top")
    lu.assertStrContains(decls[1].value, "2px")
    lu.assertStrContains(decls[1].value, "textures/border.dds")
end

function TestDeclarations:testLastDeclWithoutSemicolon()
    local ss = parse("div { width: 100px }")
    local decls = ss.rules[1].declarations
    lu.assertEquals(#decls, 1)
    lu.assertEquals(decls[1].property, "width")
    lu.assertEquals(decls[1].value, "100px")
end

---------------------------------------------------------------------------
-- TestNestedRules
---------------------------------------------------------------------------
TestNestedRules = {}

function TestNestedRules:testSimpleNesting()
    local ss = parse("mw-root { .child { color: red; } }")
    local rule = ss.rules[1]
    lu.assertEquals(#rule.nestedRules, 1)
    lu.assertStrContains(rule.nestedRules[1].selectorText, ".child")
end

function TestNestedRules:testAmpersandNesting()
    local ss = parse("#my-id { & > mw-text { color: blue; } }")
    local rule = ss.rules[1]
    lu.assertEquals(#rule.nestedRules, 1)
    lu.assertStrContains(rule.nestedRules[1].selectorText, "&")
    lu.assertStrContains(rule.nestedRules[1].selectorText, "mw-text")
end

function TestNestedRules:testNestedRuleHasParentRef()
    local ss = parse("mw-root { .inner { width: 10px; } }")
    local nested = ss.rules[1].nestedRules[1]
    lu.assertNotNil(nested.parent)
    lu.assertStrContains(nested.parent.selectorText, "mw-root")
end

function TestNestedRules:testDeclarationsAndNestedRules()
    local ss = parse("mw-root { width: 100px; .child { height: 50px; } }")
    local rule = ss.rules[1]
    lu.assertEquals(#rule.declarations, 1)
    lu.assertEquals(rule.declarations[1].property, "width")
    lu.assertEquals(#rule.nestedRules, 1)
end

function TestNestedRules:testDeeplyNested()
    local ss = parse("a { b { c { color: red; } } }")
    local a = ss.rules[1]
    lu.assertEquals(#a.nestedRules, 1)
    local b = a.nestedRules[1]
    lu.assertEquals(#b.nestedRules, 1)
    local c = b.nestedRules[1]
    lu.assertEquals(#c.declarations, 1)
    lu.assertEquals(c.declarations[1].property, "color")
end

---------------------------------------------------------------------------
-- TestMediaAtRule
---------------------------------------------------------------------------
TestMediaAtRule = {}

function TestMediaAtRule:testSimpleMedia()
    local ss = parse("@media (max-width: 600px) { mw-text { color: red; } }")
    lu.assertEquals(#ss.rules, 1)
    lu.assertEquals(ss.rules[1].type, NT.AtRule)
    lu.assertEquals(ss.rules[1].name, "media")
    lu.assertStrContains(ss.rules[1].prelude, "max-width")
end

function TestMediaAtRule:testMediaContainsRules()
    local ss = parse("@media (max-width: 600px) { mw-text { color: red; } mw-image { width: 50px; } }")
    lu.assertEquals(#ss.rules[1].rules, 2)
end

function TestMediaAtRule:testMediaPrelude()
    local ss = parse("@media (max-width: 600px) { div { } }")
    lu.assertStrContains(ss.rules[1].prelude, "600px")
end

---------------------------------------------------------------------------
-- TestContainerAtRule
---------------------------------------------------------------------------
TestContainerAtRule = {}

function TestContainerAtRule:testSimpleContainer()
    local ss = parse("@container (width <= 600px) { mw-text { font-size: 12px; } }")
    lu.assertEquals(#ss.rules, 1)
    lu.assertEquals(ss.rules[1].type, NT.AtRule)
    lu.assertEquals(ss.rules[1].name, "container")
end

function TestContainerAtRule:testNamedContainer()
    local ss = parse("@container sidebar (width <= 300px) { mw-text { font-size: 10px; } }")
    lu.assertStrContains(ss.rules[1].prelude, "sidebar")
end

function TestContainerAtRule:testContainerContainsRules()
    local ss = parse("@container (width <= 400px) { .a { } .b { } }")
    lu.assertEquals(#ss.rules[1].rules, 2)
end

---------------------------------------------------------------------------
-- TestEmptyInputs
---------------------------------------------------------------------------
TestEmptyInputs = {}

function TestEmptyInputs:testEmptySource()
    local ss = parse("")
    lu.assertEquals(ss.type, NT.Stylesheet)
    lu.assertEquals(#ss.rules, 0)
end

function TestEmptyInputs:testEmptyRule()
    local ss = parse("div { }")
    lu.assertEquals(#ss.rules, 1)
    lu.assertEquals(#ss.rules[1].declarations, 0)
    lu.assertEquals(#ss.rules[1].nestedRules, 0)
end

---------------------------------------------------------------------------
-- TestPseudoSelectors
---------------------------------------------------------------------------
TestPseudoSelectors = {}

function TestPseudoSelectors:testHoverSelector()
    local ss = parse("mw-text:hover { color: red; }")
    lu.assertStrContains(ss.rules[1].selectorText, ":hover")
end

function TestPseudoSelectors:testHostSelector()
    local ss = parse(":host { width: 200px; }")
    lu.assertStrContains(ss.rules[1].selectorText, ":host")
end

function TestPseudoSelectors:testNotSelector()
    local ss = parse(".item:not(.active) { opacity: 0.5; }")
    lu.assertStrContains(ss.rules[1].selectorText, ":not")
end

function TestPseudoSelectors:testHostWithArg()
    local ss = parse(".some-class:host(.active) { opacity: 0.5; }")
    lu.assertStrContains(ss.rules[1].selectorText, ":host")
    lu.assertStrContains(ss.rules[1].selectorText, ".active")
end

---------------------------------------------------------------------------
-- TestComplexStylesheet
---------------------------------------------------------------------------
TestComplexStylesheet = {}

function TestComplexStylesheet:testMixedContent()
    local src = [[
mw-root {
    width: 800px;
    height: 600px;

    .header {
        height: 40px;
    }
}

@media (max-width: 600px) {
    mw-root {
        width: 100%;
    }
}

mw-text:hover {
    color: red;
}
]]
    local ss = parse(src)
    -- 3 top-level: mw-root rule, @media, mw-text:hover rule
    lu.assertEquals(#ss.rules, 3)
    lu.assertEquals(ss.rules[1].type, NT.Rule)
    lu.assertEquals(ss.rules[2].type, NT.AtRule)
    lu.assertEquals(ss.rules[3].type, NT.Rule)
    -- mw-root has nested .header
    lu.assertEquals(#ss.rules[1].nestedRules, 1)
end

---------------------------------------------------------------------------
-- Run
---------------------------------------------------------------------------
lu.run()
