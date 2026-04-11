--- AnglesUI Test Suite — CSS Variable Resolver
--- Tests for custom property management, var() resolution, scoped
--- inheritance, fallback values, and stylesheet collection.

package.path = "scripts/Nox/AnglesUI/?.lua;scripts/Nox/AnglesUI/Tests/?.lua;scripts/Nox/AnglesUI/Parser/CSS/?.lua;" .. package.path

local lu = require("luaunit")
local CssVariableResolver = require("CssVariableResolver")

---------------------------------------------------------------------------
-- TestConstruction
---------------------------------------------------------------------------
TestConstruction = {}

function TestConstruction:testNewEmpty()
    local r = CssVariableResolver.New()
    lu.assertNotNil(r)
    lu.assertEquals(#r:GetAll(), 0) -- empty table, # is 0 for dict but GetAll returns dict
end

function TestConstruction:testNewWithInitial()
    local r = CssVariableResolver.New({ ["--color"] = "red", ["--size"] = "10px" })
    lu.assertEquals(r:Get("--color"), "red")
    lu.assertEquals(r:Get("--size"), "10px")
end

---------------------------------------------------------------------------
-- TestSetGet
---------------------------------------------------------------------------
TestSetGet = {}

function TestSetGet:testSetAndGet()
    local r = CssVariableResolver.New()
    r:Set("--primary", "#ff0000")
    lu.assertEquals(r:Get("--primary"), "#ff0000")
end

function TestSetGet:testGetUndefined()
    local r = CssVariableResolver.New()
    lu.assertNil(r:Get("--nonexistent"))
end

function TestSetGet:testRemove()
    local r = CssVariableResolver.New({ ["--x"] = "1" })
    r:Remove("--x")
    lu.assertNil(r:Get("--x"))
end

function TestSetGet:testSetAll()
    local r = CssVariableResolver.New()
    r:SetAll({ ["--a"] = "1", ["--b"] = "2" })
    lu.assertEquals(r:Get("--a"), "1")
    lu.assertEquals(r:Get("--b"), "2")
end

function TestSetGet:testGetAllCopy()
    local r = CssVariableResolver.New({ ["--x"] = "1" })
    local copy = r:GetAll()
    copy["--x"] = "changed"
    lu.assertEquals(r:Get("--x"), "1") -- original unchanged
end

---------------------------------------------------------------------------
-- TestResolve
---------------------------------------------------------------------------
TestResolve = {}

function TestResolve:testNoVarPassthrough()
    local r = CssVariableResolver.New()
    lu.assertEquals(r:Resolve("100px"), "100px")
end

function TestResolve:testSimpleVar()
    local r = CssVariableResolver.New({ ["--color"] = "red" })
    lu.assertEquals(r:Resolve("var(--color)"), "red")
end

function TestResolve:testVarWithFallback()
    local r = CssVariableResolver.New()
    lu.assertEquals(r:Resolve("var(--missing, blue)"), "blue")
end

function TestResolve:testVarWithFallbackNotUsed()
    local r = CssVariableResolver.New({ ["--color"] = "red" })
    lu.assertEquals(r:Resolve("var(--color, blue)"), "red")
end

function TestResolve:testNestedVar()
    local r = CssVariableResolver.New({ ["--a"] = "var(--b)", ["--b"] = "42px" })
    lu.assertEquals(r:Resolve("var(--a)"), "42px")
end

function TestResolve:testVarInMiddleOfValue()
    local r = CssVariableResolver.New({ ["--gap"] = "10px" })
    lu.assertEquals(r:Resolve("padding: var(--gap) 20px"), "padding: 10px 20px")
end

function TestResolve:testMissingVarNoFallback()
    local r = CssVariableResolver.New()
    lu.assertEquals(r:Resolve("var(--missing)"), "")
end

function TestResolve:testScopeVarsOverride()
    local r = CssVariableResolver.New({ ["--color"] = "red" })
    local result = r:Resolve("var(--color)", { ["--color"] = "green" })
    lu.assertEquals(result, "green")
end

function TestResolve:testMultipleVarsInOneValue()
    local r = CssVariableResolver.New({ ["--w"] = "100px", ["--h"] = "50px" })
    local result = r:Resolve("var(--w) var(--h)")
    lu.assertEquals(result, "100px 50px")
end

---------------------------------------------------------------------------
-- TestContainsVar
---------------------------------------------------------------------------
TestContainsVar = {}

function TestContainsVar:testTrue()
    lu.assertTrue(CssVariableResolver.ContainsVar("var(--x)"))
end

function TestContainsVar:testFalse()
    lu.assertFalse(CssVariableResolver.ContainsVar("100px"))
end

function TestContainsVar:testEmpty()
    lu.assertFalse(CssVariableResolver.ContainsVar(""))
end

---------------------------------------------------------------------------
-- TestCollectFromDeclarations
---------------------------------------------------------------------------
TestCollectFromDeclarations = {}

function TestCollectFromDeclarations:testCollectsCustomProps()
    local r = CssVariableResolver.New()
    r:CollectFromDeclarations({
        { type = "Declaration", property = "--primary", value = "#ff0000", line = 1, column = 1 },
        { type = "Declaration", property = "width", value = "100px", line = 2, column = 1 },
        { type = "Declaration", property = "--secondary", value = "blue", line = 3, column = 1 },
    })
    lu.assertEquals(r:Get("--primary"), "#ff0000")
    lu.assertEquals(r:Get("--secondary"), "blue")
    lu.assertNil(r:Get("width")) -- regular props not collected
end

---------------------------------------------------------------------------
-- TestCollectFromStylesheet
---------------------------------------------------------------------------
TestCollectFromStylesheet = {}

function TestCollectFromStylesheet:testCollectsFromRules()
    local r = CssVariableResolver.New()
    r:CollectFromStylesheet({
        type = "Stylesheet",
        rules = {
            {
                type = "Rule",
                selectorText = ":root",
                declarations = {
                    { type = "Declaration", property = "--bg", value = "white", line = 1, column = 1 },
                },
                nestedRules = {},
            },
        },
    })
    lu.assertEquals(r:Get("--bg"), "white")
end

function TestCollectFromStylesheet:testCollectsFromNestedRules()
    local r = CssVariableResolver.New()
    r:CollectFromStylesheet({
        type = "Stylesheet",
        rules = {
            {
                type = "Rule",
                selectorText = "mw-root",
                declarations = {},
                nestedRules = {
                    {
                        type = "Rule",
                        selectorText = ".inner",
                        declarations = {
                            { type = "Declaration", property = "--nested", value = "yes", line = 1, column = 1 },
                        },
                        nestedRules = {},
                    },
                },
            },
        },
    })
    lu.assertEquals(r:Get("--nested"), "yes")
end

---------------------------------------------------------------------------
-- TestCreateChild
---------------------------------------------------------------------------
TestCreateChild = {}

function TestCreateChild:testChildInheritsParent()
    local parent = CssVariableResolver.New({ ["--x"] = "1" })
    local child = parent:CreateChild()
    lu.assertEquals(child:Get("--x"), "1")
end

function TestCreateChild:testChildOverrideDoesNotAffectParent()
    local parent = CssVariableResolver.New({ ["--x"] = "1" })
    local child = parent:CreateChild()
    child:Set("--x", "2")
    lu.assertEquals(parent:Get("--x"), "1")
    lu.assertEquals(child:Get("--x"), "2")
end

function TestCreateChild:testChildCanAddNew()
    local parent = CssVariableResolver.New()
    local child = parent:CreateChild()
    child:Set("--y", "new")
    lu.assertNil(parent:Get("--y"))
    lu.assertEquals(child:Get("--y"), "new")
end

---------------------------------------------------------------------------
-- Run
---------------------------------------------------------------------------
lu.run()
