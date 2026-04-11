--- AnglesUI Test Suite — CSS Selector Engine
--- Tests for selector parsing, specificity calculation, matching, and
--- nested selector resolution.

package.path = "scripts/Nox/AnglesUI/?.lua;scripts/Nox/AnglesUI/Tests/?.lua;scripts/Nox/AnglesUI/Parser/CSS/?.lua;" .. package.path

local lu = require("luaunit")
local CssSelectorEngine = require("CssSelectorEngine")

---------------------------------------------------------------------------
-- Helpers — build mock elements
---------------------------------------------------------------------------

--- Create a mock element node suitable for selector matching.
--- @param tag string
--- @param opts? table {id?, classes?, parent?, children?}
local function makeEl(tag, opts)
    opts = opts or {}
    local attrs = {}
    if opts.id then
        attrs[#attrs + 1] = { name = "id", value = opts.id }
    end
    if opts.classes then
        attrs[#attrs + 1] = { name = "class", value = opts.classes }
    end
    local el = {
        type = "Element",
        tag = tag,
        attributes = attrs,
        parent = opts.parent or nil,
        children = opts.children or {},
    }
    -- Set parent refs on children
    for _, child in ipairs(el.children) do
        child.parent = el
    end
    return el
end

---------------------------------------------------------------------------
-- TestParse — Selector parsing
---------------------------------------------------------------------------
TestParse = {}

function TestParse:testSimpleTag()
    local selectors = CssSelectorEngine.Parse("mw-text")
    lu.assertEquals(#selectors, 1)
    lu.assertEquals(#selectors[1], 1)
    lu.assertEquals(selectors[1][1].simple.tag, "mw-text")
end

function TestParse:testClassSelector()
    local selectors = CssSelectorEngine.Parse(".my-class")
    lu.assertEquals(#selectors, 1)
    local simple = selectors[1][1].simple
    lu.assertEquals(#simple.classes, 1)
    lu.assertEquals(simple.classes[1], "my-class")
end

function TestParse:testIdSelector()
    local selectors = CssSelectorEngine.Parse("#my-id")
    lu.assertEquals(#selectors, 1)
    lu.assertEquals(selectors[1][1].simple.id, "my-id")
end

function TestParse:testUniversalSelector()
    local selectors = CssSelectorEngine.Parse("*")
    lu.assertEquals(#selectors, 1)
    lu.assertTrue(selectors[1][1].simple.isUniversal)
end

function TestParse:testCompoundSelector()
    local selectors = CssSelectorEngine.Parse("mw-text.active#main")
    lu.assertEquals(#selectors, 1)
    local simple = selectors[1][1].simple
    lu.assertEquals(simple.tag, "mw-text")
    lu.assertEquals(simple.id, "main")
    lu.assertEquals(#simple.classes, 1)
    lu.assertEquals(simple.classes[1], "active")
end

function TestParse:testMultipleClasses()
    local selectors = CssSelectorEngine.Parse(".a.b.c")
    local simple = selectors[1][1].simple
    lu.assertEquals(#simple.classes, 3)
end

function TestParse:testDescendantCombinator()
    local selectors = CssSelectorEngine.Parse("mw-root mw-text")
    lu.assertEquals(#selectors[1], 2)
    lu.assertEquals(selectors[1][1].simple.tag, "mw-root")
    lu.assertEquals(selectors[1][2].combinator, " ")
    lu.assertEquals(selectors[1][2].simple.tag, "mw-text")
end

function TestParse:testChildCombinator()
    local selectors = CssSelectorEngine.Parse("mw-root > mw-text")
    lu.assertEquals(#selectors[1], 2)
    lu.assertEquals(selectors[1][2].combinator, ">")
end

function TestParse:testAdjacentSiblingCombinator()
    local selectors = CssSelectorEngine.Parse("mw-text + mw-image")
    lu.assertEquals(selectors[1][2].combinator, "+")
end

function TestParse:testGeneralSiblingCombinator()
    local selectors = CssSelectorEngine.Parse("mw-text ~ mw-image")
    lu.assertEquals(selectors[1][2].combinator, "~")
end

function TestParse:testCommaList()
    local selectors = CssSelectorEngine.Parse(".a, .b, .c")
    lu.assertEquals(#selectors, 3)
end

function TestParse:testHoverPseudo()
    local selectors = CssSelectorEngine.Parse("mw-text:hover")
    local pseudos = selectors[1][1].simple.pseudos
    lu.assertEquals(#pseudos, 1)
    lu.assertEquals(pseudos[1].name, "hover")
end

function TestParse:testHostPseudo()
    local selectors = CssSelectorEngine.Parse(":host")
    local pseudos = selectors[1][1].simple.pseudos
    lu.assertEquals(#pseudos, 1)
    lu.assertEquals(pseudos[1].name, "host")
end

function TestParse:testHostWithArgument()
    local selectors = CssSelectorEngine.Parse(":host(.active)")
    local pseudos = selectors[1][1].simple.pseudos
    lu.assertEquals(pseudos[1].name, "host")
    lu.assertNotNil(pseudos[1].argument)
end

function TestParse:testNotPseudo()
    local selectors = CssSelectorEngine.Parse(".item:not(.active)")
    local simple = selectors[1][1].simple
    lu.assertEquals(#simple.classes, 1)
    lu.assertEquals(simple.classes[1], "item")
    lu.assertEquals(simple.pseudos[1].name, "not")
    lu.assertNotNil(simple.pseudos[1].argument)
end

function TestParse:testAmpersand()
    local selectors = CssSelectorEngine.Parse("& > .child")
    lu.assertTrue(selectors[1][1].simple.isAmpersand)
end

---------------------------------------------------------------------------
-- TestSpecificity
---------------------------------------------------------------------------
TestSpecificity = {}

function TestSpecificity:testTagOnly()
    local sels = CssSelectorEngine.Parse("mw-text")
    local a, b, c = CssSelectorEngine.Specificity(sels[1])
    lu.assertEquals(a, 0)
    lu.assertEquals(b, 0)
    lu.assertEquals(c, 1)
end

function TestSpecificity:testClassOnly()
    local sels = CssSelectorEngine.Parse(".my-class")
    local a, b, c = CssSelectorEngine.Specificity(sels[1])
    lu.assertEquals(a, 0)
    lu.assertEquals(b, 1)
    lu.assertEquals(c, 0)
end

function TestSpecificity:testIdOnly()
    local sels = CssSelectorEngine.Parse("#my-id")
    local a, b, c = CssSelectorEngine.Specificity(sels[1])
    lu.assertEquals(a, 1)
    lu.assertEquals(b, 0)
    lu.assertEquals(c, 0)
end

function TestSpecificity:testCompound()
    -- mw-text.active#id => a=1, b=1, c=1
    local sels = CssSelectorEngine.Parse("mw-text.active#main")
    local a, b, c = CssSelectorEngine.Specificity(sels[1])
    lu.assertEquals(a, 1)
    lu.assertEquals(b, 1)
    lu.assertEquals(c, 1)
end

function TestSpecificity:testHoverAddsToB()
    local sels = CssSelectorEngine.Parse("mw-text:hover")
    local a, b, c = CssSelectorEngine.Specificity(sels[1])
    lu.assertEquals(a, 0)
    lu.assertEquals(b, 1)
    lu.assertEquals(c, 1)
end

function TestSpecificity:testUniversalZero()
    local sels = CssSelectorEngine.Parse("*")
    local a, b, c = CssSelectorEngine.Specificity(sels[1])
    lu.assertEquals(a, 0)
    lu.assertEquals(b, 0)
    lu.assertEquals(c, 0)
end

function TestSpecificity:testDescendantChain()
    -- mw-root .child => c=1 + b=1 = (0,1,1)
    local sels = CssSelectorEngine.Parse("mw-root .child")
    local a, b, c = CssSelectorEngine.Specificity(sels[1])
    lu.assertEquals(a, 0)
    lu.assertEquals(b, 1)
    lu.assertEquals(c, 1)
end

function TestSpecificity:testCompareSpecificity()
    -- (1,0,0) > (0,5,5)
    lu.assertTrue(CssSelectorEngine.CompareSpecificity(1, 0, 0, 0, 5, 5))
    lu.assertFalse(CssSelectorEngine.CompareSpecificity(0, 5, 5, 1, 0, 0))
    -- Equal returns false
    lu.assertFalse(CssSelectorEngine.CompareSpecificity(0, 1, 0, 0, 1, 0))
end

---------------------------------------------------------------------------
-- TestMatchSimple — Simple selector matching
---------------------------------------------------------------------------
TestMatchSimple = {}

function TestMatchSimple:testTagMatch()
    local sels = CssSelectorEngine.Parse("mw-text")
    local el = makeEl("mw-text")
    lu.assertTrue(CssSelectorEngine.MatchSimple(sels[1][1].simple, el))
end

function TestMatchSimple:testTagMismatch()
    local sels = CssSelectorEngine.Parse("mw-image")
    local el = makeEl("mw-text")
    lu.assertFalse(CssSelectorEngine.MatchSimple(sels[1][1].simple, el))
end

function TestMatchSimple:testClassMatch()
    local sels = CssSelectorEngine.Parse(".active")
    local el = makeEl("mw-text", { classes = "active" })
    lu.assertTrue(CssSelectorEngine.MatchSimple(sels[1][1].simple, el))
end

function TestMatchSimple:testClassMismatch()
    local sels = CssSelectorEngine.Parse(".active")
    local el = makeEl("mw-text", { classes = "inactive" })
    lu.assertFalse(CssSelectorEngine.MatchSimple(sels[1][1].simple, el))
end

function TestMatchSimple:testIdMatch()
    local sels = CssSelectorEngine.Parse("#main")
    local el = makeEl("mw-text", { id = "main" })
    lu.assertTrue(CssSelectorEngine.MatchSimple(sels[1][1].simple, el))
end

function TestMatchSimple:testIdMismatch()
    local sels = CssSelectorEngine.Parse("#main")
    local el = makeEl("mw-text", { id = "other" })
    lu.assertFalse(CssSelectorEngine.MatchSimple(sels[1][1].simple, el))
end

function TestMatchSimple:testUniversalMatchesAny()
    local sels = CssSelectorEngine.Parse("*")
    lu.assertTrue(CssSelectorEngine.MatchSimple(sels[1][1].simple, makeEl("mw-text")))
    lu.assertTrue(CssSelectorEngine.MatchSimple(sels[1][1].simple, makeEl("mw-root")))
end

function TestMatchSimple:testMultipleClassesMatch()
    local sels = CssSelectorEngine.Parse(".a.b")
    local el = makeEl("mw-text", { classes = "a b c" })
    lu.assertTrue(CssSelectorEngine.MatchSimple(sels[1][1].simple, el))
end

function TestMatchSimple:testMultipleClassesPartialFail()
    local sels = CssSelectorEngine.Parse(".a.b")
    local el = makeEl("mw-text", { classes = "a c" })
    lu.assertFalse(CssSelectorEngine.MatchSimple(sels[1][1].simple, el))
end

function TestMatchSimple:testHoverMatch()
    local sels = CssSelectorEngine.Parse("mw-text:hover")
    local el = makeEl("mw-text")
    local hoverSet = { [el] = true }
    lu.assertTrue(CssSelectorEngine.MatchSimple(sels[1][1].simple, el, hoverSet))
end

function TestMatchSimple:testHoverNoMatch()
    local sels = CssSelectorEngine.Parse("mw-text:hover")
    local el = makeEl("mw-text")
    lu.assertFalse(CssSelectorEngine.MatchSimple(sels[1][1].simple, el, {}))
end

function TestMatchSimple:testNotMatch()
    local sels = CssSelectorEngine.Parse(".item:not(.active)")
    local el = makeEl("mw-text", { classes = "item" })
    lu.assertTrue(CssSelectorEngine.MatchSimple(sels[1][1].simple, el))
end

function TestMatchSimple:testNotExcludes()
    local sels = CssSelectorEngine.Parse(".item:not(.active)")
    local el = makeEl("mw-text", { classes = "item active" })
    lu.assertFalse(CssSelectorEngine.MatchSimple(sels[1][1].simple, el))
end

function TestMatchSimple:testHostMatch()
    local sels = CssSelectorEngine.Parse(":host")
    local el = makeEl("nox-component")
    lu.assertTrue(CssSelectorEngine.MatchSimple(sels[1][1].simple, el, nil, el))
end

function TestMatchSimple:testHostMismatch()
    local sels = CssSelectorEngine.Parse(":host")
    local host = makeEl("nox-component")
    local other = makeEl("mw-text")
    lu.assertFalse(CssSelectorEngine.MatchSimple(sels[1][1].simple, other, nil, host))
end

---------------------------------------------------------------------------
-- TestMatch — Full selector chain matching
---------------------------------------------------------------------------
TestMatch = {}

function TestMatch:testDescendantMatch()
    local sels = CssSelectorEngine.Parse("mw-root mw-text")
    local root = makeEl("mw-root")
    local text = makeEl("mw-text", { parent = root })
    root.children = { text }
    lu.assertTrue(CssSelectorEngine.Match(sels[1], text))
end

function TestMatch:testDescendantDeep()
    local sels = CssSelectorEngine.Parse("mw-root mw-text")
    local root = makeEl("mw-root")
    local flex = makeEl("mw-flex", { parent = root })
    local text = makeEl("mw-text", { parent = flex })
    root.children = { flex }
    flex.children = { text }
    lu.assertTrue(CssSelectorEngine.Match(sels[1], text))
end

function TestMatch:testDescendantNoMatch()
    local sels = CssSelectorEngine.Parse("mw-root mw-text")
    local text = makeEl("mw-text")
    lu.assertFalse(CssSelectorEngine.Match(sels[1], text))
end

function TestMatch:testChildMatch()
    local sels = CssSelectorEngine.Parse("mw-root > mw-text")
    local root = makeEl("mw-root")
    local text = makeEl("mw-text", { parent = root })
    root.children = { text }
    lu.assertTrue(CssSelectorEngine.Match(sels[1], text))
end

function TestMatch:testChildNoMatchWhenNested()
    local sels = CssSelectorEngine.Parse("mw-root > mw-text")
    local root = makeEl("mw-root")
    local flex = makeEl("mw-flex", { parent = root })
    local text = makeEl("mw-text", { parent = flex })
    root.children = { flex }
    flex.children = { text }
    lu.assertFalse(CssSelectorEngine.Match(sels[1], text))
end

function TestMatch:testAdjacentSibling()
    local sels = CssSelectorEngine.Parse("mw-text + mw-image")
    local parent = makeEl("mw-flex")
    local text = makeEl("mw-text", { parent = parent })
    local img = makeEl("mw-image", { parent = parent })
    parent.children = { text, img }
    lu.assertTrue(CssSelectorEngine.Match(sels[1], img))
end

function TestMatch:testAdjacentSiblingNoMatch()
    local sels = CssSelectorEngine.Parse("mw-text + mw-image")
    local parent = makeEl("mw-flex")
    local a = makeEl("mw-text", { parent = parent })
    local b = makeEl("mw-flex", { parent = parent })
    local img = makeEl("mw-image", { parent = parent })
    parent.children = { a, b, img }
    -- img's previous element sibling is mw-flex, not mw-text
    lu.assertFalse(CssSelectorEngine.Match(sels[1], img))
end

function TestMatch:testGeneralSibling()
    local sels = CssSelectorEngine.Parse("mw-text ~ mw-image")
    local parent = makeEl("mw-flex")
    local text = makeEl("mw-text", { parent = parent })
    local mid = makeEl("mw-flex", { parent = parent })
    local img = makeEl("mw-image", { parent = parent })
    parent.children = { text, mid, img }
    lu.assertTrue(CssSelectorEngine.Match(sels[1], img))
end

---------------------------------------------------------------------------
-- TestMatchAny
---------------------------------------------------------------------------
TestMatchAny = {}

function TestMatchAny:testMatchesFirst()
    local sels = CssSelectorEngine.Parse(".a, .b")
    local el = makeEl("mw-text", { classes = "a" })
    lu.assertTrue(CssSelectorEngine.MatchAny(sels, el))
end

function TestMatchAny:testMatchesSecond()
    local sels = CssSelectorEngine.Parse(".a, .b")
    local el = makeEl("mw-text", { classes = "b" })
    lu.assertTrue(CssSelectorEngine.MatchAny(sels, el))
end

function TestMatchAny:testMatchesNone()
    local sels = CssSelectorEngine.Parse(".a, .b")
    local el = makeEl("mw-text", { classes = "c" })
    lu.assertFalse(CssSelectorEngine.MatchAny(sels, el))
end

---------------------------------------------------------------------------
-- TestResolveNested
---------------------------------------------------------------------------
TestResolveNested = {}

function TestResolveNested:testAmpersandReplacement()
    local result = CssSelectorEngine.ResolveNested("mw-root", "& > .child")
    lu.assertStrContains(result, "mw-root")
    lu.assertStrContains(result, ".child")
end

function TestResolveNested:testNoAmpersandPrepends()
    local result = CssSelectorEngine.ResolveNested("mw-root", ".child")
    lu.assertStrContains(result, "mw-root")
    lu.assertStrContains(result, ".child")
end

function TestResolveNested:testEmptyParent()
    local result = CssSelectorEngine.ResolveNested("", ".child")
    lu.assertEquals(result, ".child")
end

---------------------------------------------------------------------------
-- Run
---------------------------------------------------------------------------
lu.run()
