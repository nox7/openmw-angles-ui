package.path = package.path .. ";./?.lua"

local CSSParser = dofile("scripts/Nox/AnglesUI/CSSParser/CSSParser.lua")

-- ── Test 1: top-level unnamed @container ─────────────────────────────────────
local css1 = [[
mw-widget {
  flex-grow: 1;
}

@container (width <= 500px) {
  mw-widget {
    height: 100%;
    flex-grow: 2;
  }
}
]]

local r1 = CSSParser.New():Parse(css1)
assert(#r1.rules == 1,               "test1: expected 1 rule, got " .. #r1.rules)
assert(#r1.containerQueryRules == 1, "test1: expected 1 CQ rule, got " .. #r1.containerQueryRules)
local cq1 = r1.containerQueryRules[1]
assert(cq1.condition.property == "width",    "test1: cq property")
assert(cq1.condition.operator == "<=",       "test1: cq operator")
assert(cq1.condition.value == 500,           "test1: cq value")
assert(cq1.containerName == nil,             "test1: cq should be unnamed")
assert(cq1.declarations["height"] == "100%", "test1: cq height decl")
assert(cq1.declarations["flex-grow"] == "2", "test1: cq flex-grow decl")
print("test1 PASS - top-level unnamed @container")

-- ── Test 2: top-level named @container ───────────────────────────────────────
local css2 = [[
@container my-container (max-width: 300px) {
  mw-text {
    font-size: 12;
  }
}
]]

local r2 = CSSParser.New():Parse(css2)
assert(#r2.containerQueryRules == 1,           "test2: expected 1 CQ rule")
local cq2 = r2.containerQueryRules[1]
assert(cq2.condition.property == "width",      "test2: property")
assert(cq2.condition.operator == "<=",         "test2: operator (max-width colon syntax)")
assert(cq2.condition.value == 300,             "test2: value")
assert(cq2.containerName == "my-container",    "test2: container name stored")
assert(cq2.declarations["font-size"] == "12",  "test2: font-size decl")
print("test2 PASS - top-level named @container")

-- ── Test 3: @container inside @media ─────────────────────────────────────────
local css3 = [[
@media (max-width: 1200px) {
  @container (height <= 200px) {
    mw-widget {
      width: 50%;
    }
  }
}
]]

local r3 = CSSParser.New():Parse(css3)
assert(#r3.mediaQueries == 1,                        "test3: media queries")
assert(#r3.mediaQueries[1].containerQueryRules == 1, "test3: CQ inside media")
local cq3 = r3.mediaQueries[1].containerQueryRules[1]
assert(cq3.condition.property == "height",           "test3: property")
assert(cq3.condition.operator == "<=",               "test3: operator")
assert(cq3.condition.value == 200,                   "test3: value")
assert(cq3.containerName == nil,                     "test3: unnamed")
assert(cq3.declarations["width"] == "50%",           "test3: width decl")
print("test3 PASS - @container inside @media")

-- ── Test 4: EvaluateContainerCondition ───────────────────────────────────────
local cond = { property = "width", operator = "<=", value = 500 }
assert(CSSParser.EvaluateContainerCondition(cond, { x = 400, y = 300 }) == true,  "test4a")
assert(CSSParser.EvaluateContainerCondition(cond, { x = 600, y = 300 }) == false, "test4b")
assert(CSSParser.EvaluateContainerCondition(cond, nil) == false,                   "test4c nil")
print("test4 PASS - EvaluateContainerCondition")

-- ── Test 5: px stripped from container condition and declarations ─────────────
local css5 = [[
@container (width <= 300px) {
  mw-flex {
    gap: 5px;
  }
}
]]

local r5 = CSSParser.New():Parse(css5)
assert(#r5.containerQueryRules == 1,                         "test5: cq count")
assert(r5.containerQueryRules[1].condition.value == 300,     "test5: px stripped from condition")
assert(r5.containerQueryRules[1].declarations["gap"] == "5", "test5: px stripped from declaration")
print("test5 PASS - px stripped from @container condition and declarations")

-- ── Test 6: ApplyContainerRulesToNode - named vs unnamed dispatch ─────────────
local css6 = [[
@container sidebar (width < 200px) {
  mw-text {
    font-size: 10;
  }
}

@container (width < 800px) {
  mw-text {
    font-size: 14;
  }
}
]]

local r6 = CSSParser.New():Parse(css6)
assert(#r6.containerQueryRules == 2, "test6: 2 CQ rules")

local textNode    = { tagName = "mw-text", attributes = {} }
local noAncestors = {}

-- Named container (sidebar = 150px) matches; unnamed (900px) does not → font-size 10
local ctx1 = { pixelSize = { x = 900, y = 600 }, named = { sidebar = { x = 150, y = 400 } } }
local d1   = CSSParser.ApplyContainerRulesToNode(r6.containerQueryRules, textNode, noAncestors, ctx1)
assert(d1["font-size"] == "10", "test6a: named container applied, got " .. tostring(d1["font-size"]))

-- Unnamed container (700px) matches; named (sidebar = 900px) does not → font-size 14
local ctx2 = { pixelSize = { x = 700, y = 600 }, named = { sidebar = { x = 900, y = 400 } } }
local d2   = CSSParser.ApplyContainerRulesToNode(r6.containerQueryRules, textNode, noAncestors, ctx2)
assert(d2["font-size"] == "14", "test6b: unnamed container applied, got " .. tostring(d2["font-size"]))

-- nil containerContext → nothing applies
local d3 = CSSParser.ApplyContainerRulesToNode(r6.containerQueryRules, textNode, noAncestors, nil)
assert(d3["font-size"] == nil, "test6c: nil context, nothing applied")
print("test6 PASS - ApplyContainerRulesToNode named vs unnamed dispatch")

print("\nAll container query tests PASS")
