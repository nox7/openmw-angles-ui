--- AnglesUI Test Suite — CSS Scoping
--- Tests for component-level CSS scope isolation: assigning scopes,
--- filtering rules by scope, creating and merging scope maps.

package.path = "?.lua;scripts/Nox/AnglesUI/?.lua;scripts/Nox/AnglesUI/Tests/?.lua;scripts/Nox/AnglesUI/Components/?.lua;scripts/Nox/AnglesUI/DOM/?.lua;scripts/Nox/AnglesUI/Parser/HTML/?.lua;scripts/Nox/AnglesUI/Parser/CSS/?.lua;" .. package.path

local lu = require("luaunit")
local HtmlNodes  = require("HtmlNodes")
local DomNode    = require("DomNode")
local CssScoping = require("CssScoping")

--- Helper: create element DomNode.
local function makeEl(tag, opts)
    opts = opts or {}
    local html = HtmlNodes.CreateElement(tag, 0, 0)
    return DomNode.FromElement(html, nil, opts.depth or 0)
end

--- Helper: create a dummy flat rule.
local function makeRule(sel, order)
    return { resolvedSelector = sel, sourceOrder = order or 1, declarations = {} }
end

---------------------------------------------------------------------------
-- TestAssignScope
---------------------------------------------------------------------------
TestAssignScope = {}

function TestAssignScope:testAssignsToAll()
    local root = makeEl("mw-flex")
    local a = makeEl("mw-text")
    local b = makeEl("mw-image")
    root:AppendChild(a)
    root:AppendChild(b)
    CssScoping.AssignScope(root, "scope-1")
    lu.assertEquals(root.scopeId, "scope-1")
    lu.assertEquals(a.scopeId, "scope-1")
    lu.assertEquals(b.scopeId, "scope-1")
end

function TestAssignScope:testDoesNotOverwriteExisting()
    local root = makeEl("mw-flex")
    local projected = makeEl("mw-text")
    projected.scopeId = "parent-scope"
    root:AppendChild(projected)
    CssScoping.AssignScope(root, "child-scope")
    lu.assertEquals(root.scopeId, "child-scope")
    lu.assertEquals(projected.scopeId, "parent-scope") -- kept original
end

function TestAssignScope:testAssignScopeToNode()
    local node = makeEl("mw-text")
    CssScoping.AssignScopeToNode(node, "s1")
    lu.assertEquals(node.scopeId, "s1")
end

function TestAssignScope:testAssignScopeToNodeNoOverwrite()
    local node = makeEl("mw-text")
    node.scopeId = "existing"
    CssScoping.AssignScopeToNode(node, "new")
    lu.assertEquals(node.scopeId, "existing")
end

---------------------------------------------------------------------------
-- TestFilterRulesForNode
---------------------------------------------------------------------------
TestFilterRulesForNode = {}

function TestFilterRulesForNode:testGlobalRulesAlwaysPass()
    local node = makeEl("mw-text")
    node.scopeId = "scope-A"
    local rule = makeRule("mw-text")
    local scopeMap = { [rule] = nil } -- nil = global
    local filtered = CssScoping.FilterRulesForNode({ rule }, node, scopeMap)
    lu.assertEquals(#filtered, 1)
end

function TestFilterRulesForNode:testMatchingScopeAllowed()
    local node = makeEl("mw-text")
    node.scopeId = "scope-A"
    local rule = makeRule("mw-text")
    local scopeMap = { [rule] = "scope-A" }
    local filtered = CssScoping.FilterRulesForNode({ rule }, node, scopeMap)
    lu.assertEquals(#filtered, 1)
end

function TestFilterRulesForNode:testDifferentScopeBlocked()
    local node = makeEl("mw-text")
    node.scopeId = "scope-A"
    local rule = makeRule("mw-text")
    local scopeMap = { [rule] = "scope-B" }
    local filtered = CssScoping.FilterRulesForNode({ rule }, node, scopeMap)
    lu.assertEquals(#filtered, 0)
end

function TestFilterRulesForNode:testMixedScopes()
    local node = makeEl("mw-text")
    node.scopeId = "scope-A"
    local globalRule = makeRule("mw-text", 1)
    local matchedRule = makeRule(".highlight", 2)
    local foreignRule = makeRule(".other", 3)
    local scopeMap = {
        [globalRule] = nil,
        [matchedRule] = "scope-A",
        [foreignRule] = "scope-B",
    }
    local filtered = CssScoping.FilterRulesForNode(
        { globalRule, matchedRule, foreignRule }, node, scopeMap)
    lu.assertEquals(#filtered, 2)
    lu.assertEquals(filtered[1], globalRule)
    lu.assertEquals(filtered[2], matchedRule)
end

---------------------------------------------------------------------------
-- TestCreateRuleScopeMap
---------------------------------------------------------------------------
TestCreateRuleScopeMap = {}

function TestCreateRuleScopeMap:testMapsAllRules()
    local r1 = makeRule("a")
    local r2 = makeRule("b")
    local map = CssScoping.CreateRuleScopeMap({ r1, r2 }, "scope-X")
    lu.assertEquals(map[r1], "scope-X")
    lu.assertEquals(map[r2], "scope-X")
end

function TestCreateRuleScopeMap:testNilScopeForGlobal()
    local r1 = makeRule("a")
    local map = CssScoping.CreateRuleScopeMap({ r1 }, nil)
    lu.assertNil(map[r1])
end

---------------------------------------------------------------------------
-- TestMergeRuleScopeMaps
---------------------------------------------------------------------------
TestMergeRuleScopeMaps = {}

function TestMergeRuleScopeMaps:testMergeTwoMaps()
    local r1 = makeRule("a")
    local r2 = makeRule("b")
    local m1 = { [r1] = "scope-1" }
    local m2 = { [r2] = "scope-2" }
    local merged = CssScoping.MergeRuleScopeMaps(m1, m2)
    lu.assertEquals(merged[r1], "scope-1")
    lu.assertEquals(merged[r2], "scope-2")
end

function TestMergeRuleScopeMaps:testMergeOverlapping()
    local r1 = makeRule("a")
    local m1 = { [r1] = "scope-1" }
    local m2 = { [r1] = "scope-2" }
    local merged = CssScoping.MergeRuleScopeMaps(m1, m2)
    lu.assertEquals(merged[r1], "scope-2") -- last wins
end

function TestMergeRuleScopeMaps:testMergeWithNil()
    local r1 = makeRule("a")
    local m1 = { [r1] = "scope-1" }
    local merged = CssScoping.MergeRuleScopeMaps(m1, nil)
    lu.assertEquals(merged[r1], "scope-1")
end

---------------------------------------------------------------------------
-- Run
---------------------------------------------------------------------------
lu.run()
