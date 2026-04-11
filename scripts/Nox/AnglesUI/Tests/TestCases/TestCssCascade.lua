--- AnglesUI Test Suite — CSS Cascade
--- Tests for flattening stylesheets, matching rules to DOM nodes,
--- computing styles, and the full ApplyToTree cascade.

package.path = "?.lua;scripts/Nox/AnglesUI/?.lua;scripts/Nox/AnglesUI/Tests/?.lua;scripts/Nox/AnglesUI/DOM/?.lua;scripts/Nox/AnglesUI/Parser/HTML/?.lua;scripts/Nox/AnglesUI/Parser/CSS/?.lua;" .. package.path

local lu = require("luaunit")
local HtmlNodes           = require("HtmlNodes")
local DomNode             = require("DomNode")
local CssCascade          = require("CssCascade")
local CssVariableResolver = require("CssVariableResolver")

local DomNodeKind = DomNode.DomNodeKind

--- Helper: create a DomNode element quickly.
local function makeEl(tag, opts)
    opts = opts or {}
    local html = HtmlNodes.CreateElement(tag, 0, 0)
    if opts.id then
        html.attributes[#html.attributes + 1] = HtmlNodes.CreateAttribute("Static", "id", opts.id)
    end
    if opts.class then
        html.attributes[#html.attributes + 1] = HtmlNodes.CreateAttribute("Static", "class", opts.class)
    end
    return DomNode.FromElement(html, nil, opts.depth or 0)
end

--- Helper: create a minimal flat rule entry.
local function makeFlatRule(selector, declarations, order, atRuleName, atRuleCondition)
    local CssSelectorEngine = require("CssSelectorEngine")
    return {
        resolvedSelector = selector,
        parsedSelectors = CssSelectorEngine.Parse(selector),
        declarations = declarations,
        sourceOrder = order or 1,
        atRuleName = atRuleName,
        atRuleCondition = atRuleCondition,
    }
end

---------------------------------------------------------------------------
-- TestFlattenStylesheet
---------------------------------------------------------------------------
TestFlattenStylesheet = {}

function TestFlattenStylesheet:testSimpleRule()
    local stylesheet = {
        rules = {
            {
                type = "Rule",
                selectorText = "mw-text",
                declarations = { { property = "color", value = "red" } },
                nestedRules = {},
            },
        },
    }
    local flat = CssCascade.FlattenStylesheet(stylesheet)
    lu.assertEquals(#flat, 1)
    lu.assertEquals(flat[1].resolvedSelector, "mw-text")
    lu.assertEquals(#flat[1].declarations, 1)
end

function TestFlattenStylesheet:testNestedRule()
    local stylesheet = {
        rules = {
            {
                type = "Rule",
                selectorText = "mw-flex",
                declarations = { { property = "gap", value = "10px" } },
                nestedRules = {
                    {
                        type = "Rule",
                        selectorText = ".child",
                        declarations = { { property = "color", value = "blue" } },
                        nestedRules = {},
                    },
                },
            },
        },
    }
    local flat = CssCascade.FlattenStylesheet(stylesheet)
    lu.assertEquals(#flat, 2)
    lu.assertEquals(flat[1].resolvedSelector, "mw-flex")
    -- The nested .child should be resolved relative to parent
    lu.assertStrContains(flat[2].resolvedSelector, "child")
end

function TestFlattenStylesheet:testMediaAtRule()
    local stylesheet = {
        rules = {
            {
                type = "AtRule",
                name = "media",
                prelude = "(max-width: 600px)",
                rules = {
                    {
                        type = "Rule",
                        selectorText = "mw-text",
                        declarations = { { property = "font-size", value = "12px" } },
                        nestedRules = {},
                    },
                },
            },
        },
    }
    local flat = CssCascade.FlattenStylesheet(stylesheet)
    lu.assertEquals(#flat, 1)
    lu.assertEquals(flat[1].atRuleName, "media")
    lu.assertEquals(flat[1].atRuleCondition, "(max-width: 600px)")
end

function TestFlattenStylesheet:testSourceOrder()
    local stylesheet = {
        rules = {
            {
                type = "Rule",
                selectorText = ".a",
                declarations = { { property = "color", value = "red" } },
                nestedRules = {},
            },
            {
                type = "Rule",
                selectorText = ".b",
                declarations = { { property = "color", value = "blue" } },
                nestedRules = {},
            },
        },
    }
    local flat = CssCascade.FlattenStylesheet(stylesheet)
    lu.assertTrue(flat[1].sourceOrder < flat[2].sourceOrder)
end

function TestFlattenStylesheet:testEmptyDeclarationsSkipped()
    local stylesheet = {
        rules = {
            {
                type = "Rule",
                selectorText = "mw-text",
                declarations = {},
                nestedRules = {},
            },
        },
    }
    local flat = CssCascade.FlattenStylesheet(stylesheet)
    lu.assertEquals(#flat, 0)
end

---------------------------------------------------------------------------
-- TestMatchRules
---------------------------------------------------------------------------
TestMatchRules = {}

function TestMatchRules:testBasicTagMatch()
    local node = makeEl("mw-text")
    local flat = { makeFlatRule("mw-text", { { property = "color", value = "red" } }) }
    local matched = CssCascade.MatchRules(flat, node)
    lu.assertEquals(#matched, 1)
end

function TestMatchRules:testNoMatch()
    local node = makeEl("mw-text")
    local flat = { makeFlatRule("mw-image", { { property = "color", value = "red" } }) }
    local matched = CssCascade.MatchRules(flat, node)
    lu.assertEquals(#matched, 0)
end

function TestMatchRules:testClassMatch()
    local node = makeEl("mw-text", { class = "highlight" })
    local flat = { makeFlatRule(".highlight", { { property = "color", value = "red" } }) }
    local matched = CssCascade.MatchRules(flat, node)
    lu.assertEquals(#matched, 1)
end

function TestMatchRules:testIdMatch()
    local node = makeEl("mw-text", { id = "title" })
    local flat = { makeFlatRule("#title", { { property = "color", value = "red" } }) }
    local matched = CssCascade.MatchRules(flat, node)
    lu.assertEquals(#matched, 1)
end

function TestMatchRules:testSpecificityOrder()
    local node = makeEl("mw-text", { id = "title", class = "big" })
    local r1 = makeFlatRule(".big", { { property = "color", value = "blue" } }, 1)
    local r2 = makeFlatRule("#title", { { property = "color", value = "red" } }, 2)
    local matched = CssCascade.MatchRules({ r1, r2 }, node)
    lu.assertEquals(#matched, 2)
    -- ID selector has higher specificity, should be last (ascending order)
    lu.assertEquals(matched[2].rule.resolvedSelector, "#title")
end

function TestMatchRules:testMediaRuleSkippedWhenFalse()
    local node = makeEl("mw-text")
    local flat = { makeFlatRule("mw-text", { { property = "color", value = "red" } }, 1, "media", "(max-width: 600px)") }
    local mediaEval = function(prelude) return false end
    local matched = CssCascade.MatchRules(flat, node, nil, nil, mediaEval, nil)
    lu.assertEquals(#matched, 0)
end

function TestMatchRules:testMediaRuleIncludedWhenTrue()
    local node = makeEl("mw-text")
    local flat = { makeFlatRule("mw-text", { { property = "color", value = "red" } }, 1, "media", "(max-width: 600px)") }
    local mediaEval = function(prelude) return true end
    local matched = CssCascade.MatchRules(flat, node, nil, nil, mediaEval, nil)
    lu.assertEquals(#matched, 1)
end

---------------------------------------------------------------------------
-- TestComputeStyles
---------------------------------------------------------------------------
TestComputeStyles = {}

function TestComputeStyles:testBasicCompute()
    local matched = {
        { rule = { declarations = { { property = "color", value = "red" } } } },
    }
    local styles = CssCascade.ComputeStyles(matched)
    lu.assertEquals(styles["color"], "red")
end

function TestComputeStyles:testLaterRuleOverrides()
    local matched = {
        { rule = { declarations = { { property = "color", value = "red" } } } },
        { rule = { declarations = { { property = "color", value = "blue" } } } },
    }
    local styles = CssCascade.ComputeStyles(matched)
    lu.assertEquals(styles["color"], "blue")
end

function TestComputeStyles:testSkipsCustomProperties()
    local matched = {
        { rule = { declarations = {
            { property = "--bg", value = "red" },
            { property = "color", value = "blue" },
        } } },
    }
    local styles = CssCascade.ComputeStyles(matched)
    lu.assertNil(styles["--bg"])
    lu.assertEquals(styles["color"], "blue")
end

function TestComputeStyles:testVariableResolution()
    local resolver = CssVariableResolver.New({ ["--main-color"] = "green" })
    local matched = {
        { rule = { declarations = { { property = "color", value = "var(--main-color)" } } } },
    }
    local styles = CssCascade.ComputeStyles(matched, resolver)
    lu.assertEquals(styles["color"], "green")
end

---------------------------------------------------------------------------
-- TestApplyToTree
---------------------------------------------------------------------------
TestApplyToTree = {}

function TestApplyToTree:testBasicApply()
    local root = makeEl("mw-root")
    local child = makeEl("mw-text")
    root:AppendChild(child)
    local flat = { makeFlatRule("mw-text", { { property = "color", value = "red" } }) }
    CssCascade.ApplyToTree(root, flat)
    lu.assertEquals(child.computedStyles["color"], "red")
end

function TestApplyToTree:testNonElementsUntouched()
    local root = makeEl("mw-root")
    local txt = DomNode.FromText(HtmlNodes.CreateText("hi", 0, 0), nil, 0)
    root:AppendChild(txt)
    local flat = { makeFlatRule("mw-text", { { property = "color", value = "red" } }) }
    CssCascade.ApplyToTree(root, flat)
    lu.assertEquals(#txt.matchedRules, 0)
end

---------------------------------------------------------------------------
-- Run
---------------------------------------------------------------------------
lu.run()
