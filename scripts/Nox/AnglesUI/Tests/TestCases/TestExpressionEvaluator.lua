--- AnglesUI Test Suite — Expression Evaluator
--- Tests for the JS-like expression evaluator: literals, identifiers,
--- property access, function calls, operators, ternary, and Defer.

package.path = "scripts/Nox/AnglesUI/?.lua;scripts/Nox/AnglesUI/Tests/?.lua;scripts/Nox/AnglesUI/Parser/?.lua;" .. package.path

local lu = require("luaunit")
local ExpressionEvaluator = require("ExpressionEvaluator")

local eval = ExpressionEvaluator.Evaluate

---------------------------------------------------------------------------
-- TestLiterals
---------------------------------------------------------------------------
TestLiterals = {}

function TestLiterals:testNumber()
    lu.assertEquals(eval("42", {}), 42)
end

function TestLiterals:testDecimalNumber()
    lu.assertAlmostEquals(eval("3.14", {}), 3.14, 0.001)
end

function TestLiterals:testSingleQuotedString()
    lu.assertEquals(eval("'hello'", {}), "hello")
end

function TestLiterals:testDoubleQuotedString()
    lu.assertEquals(eval('"world"', {}), "world")
end

function TestLiterals:testBoolTrue()
    lu.assertEquals(eval("true", {}), true)
end

function TestLiterals:testBoolFalse()
    lu.assertEquals(eval("false", {}), false)
end

function TestLiterals:testNil()
    lu.assertNil(eval("nil", {}))
end

function TestLiterals:testNull()
    lu.assertNil(eval("null", {}))
end

---------------------------------------------------------------------------
-- TestIdentifiers
---------------------------------------------------------------------------
TestIdentifiers = {}

function TestIdentifiers:testSimpleIdent()
    lu.assertEquals(eval("x", { x = 10 }), 10)
end

function TestIdentifiers:testUndefinedIdent()
    lu.assertNil(eval("y", {}))
end

function TestIdentifiers:testDollarIdent()
    lu.assertEquals(eval("$index", { ["$index"] = 3 }), 3)
end

function TestIdentifiers:testEvent1()
    lu.assertEquals(eval("$event1", { ["$event1"] = "click" }), "click")
end

---------------------------------------------------------------------------
-- TestPropertyAccess
---------------------------------------------------------------------------
TestPropertyAccess = {}

function TestPropertyAccess:testDotAccess()
    lu.assertEquals(eval("item.Name", { item = { Name = "Sword" } }), "Sword")
end

function TestPropertyAccess:testChainedDotAccess()
    lu.assertEquals(eval("a.b.c", { a = { b = { c = 99 } } }), 99)
end

function TestPropertyAccess:testBracketAccess()
    lu.assertEquals(eval("arr[0]", { arr = { [0] = "first" } }), "first")
end

function TestPropertyAccess:testBracketStringAccess()
    lu.assertEquals(eval("obj['key']", { obj = { key = "val" } }), "val")
end

---------------------------------------------------------------------------
-- TestFunctionCalls
---------------------------------------------------------------------------
TestFunctionCalls = {}

function TestFunctionCalls:testSimpleCall()
    lu.assertEquals(eval("Greet()", { Greet = function() return "Hi" end }), "Hi")
end

function TestFunctionCalls:testCallWithArgs()
    lu.assertEquals(eval("Add(1, 2)", { Add = function(a, b) return a + b end }), 3)
end

function TestFunctionCalls:testSignalPattern()
    -- Signals are callable tables / functions that return a value
    lu.assertEquals(eval("Count()", { Count = function() return 5 end }), 5)
end

function TestFunctionCalls:testChainedCall()
    lu.assertEquals(eval("Items().Name", {
        Items = function() return { Name = "Armor" } end
    }), "Armor")
end

function TestFunctionCalls:testMethodCall()
    local obj = { Get = function(self) return self.value end, value = 42 }
    -- Our evaluator uses dot-call (no self), so adjust
    lu.assertEquals(eval("obj.Get()", {
        obj = { Get = function() return 42 end }
    }), 42)
end

---------------------------------------------------------------------------
-- TestArithmetic
---------------------------------------------------------------------------
TestArithmetic = {}

function TestArithmetic:testAddition()
    lu.assertEquals(eval("3 + 4", {}), 7)
end

function TestArithmetic:testSubtraction()
    lu.assertEquals(eval("10 - 3", {}), 7)
end

function TestArithmetic:testMultiplication()
    lu.assertEquals(eval("6 * 7", {}), 42)
end

function TestArithmetic:testDivision()
    lu.assertEquals(eval("10 / 2", {}), 5)
end

function TestArithmetic:testModulo()
    lu.assertEquals(eval("10 % 3", {}), 1)
end

function TestArithmetic:testNegativeUnary()
    lu.assertEquals(eval("-5", {}), -5)
end

function TestArithmetic:testParenGrouping()
    lu.assertEquals(eval("(2 + 3) * 4", {}), 20)
end

function TestArithmetic:testStringConcat()
    lu.assertEquals(eval("'hello' + ' ' + 'world'", {}), "hello world")
end

---------------------------------------------------------------------------
-- TestComparison
---------------------------------------------------------------------------
TestComparison = {}

function TestComparison:testEqTrue()
    lu.assertTrue(eval("1 === 1", {}))
end

function TestComparison:testEqFalse()
    lu.assertFalse(eval("1 === 2", {}))
end

function TestComparison:testNeqTrue()
    lu.assertTrue(eval("1 !== 2", {}))
end

function TestComparison:testGt()
    lu.assertTrue(eval("5 > 3", {}))
    lu.assertFalse(eval("3 > 5", {}))
end

function TestComparison:testGte()
    lu.assertTrue(eval("5 >= 5", {}))
    lu.assertTrue(eval("6 >= 5", {}))
end

function TestComparison:testLt()
    lu.assertTrue(eval("3 < 5", {}))
    lu.assertFalse(eval("5 < 3", {}))
end

function TestComparison:testLte()
    lu.assertTrue(eval("5 <= 5", {}))
    lu.assertTrue(eval("4 <= 5", {}))
end

function TestComparison:testDoubleEq()
    lu.assertTrue(eval("1 == 1", {}))
end

function TestComparison:testBangEq()
    lu.assertTrue(eval("1 != 2", {}))
end

---------------------------------------------------------------------------
-- TestLogical
---------------------------------------------------------------------------
TestLogical = {}

function TestLogical:testAndTrue()
    lu.assertTrue(eval("true && true", {}))
end

function TestLogical:testAndFalse()
    lu.assertFalse(eval("true && false", {}))
end

function TestLogical:testOrTrue()
    lu.assertTrue(eval("false || true", {}))
end

function TestLogical:testOrFalse()
    lu.assertFalse(eval("false || false", {}))
end

function TestLogical:testBangTrue()
    lu.assertFalse(eval("!true", {}))
end

function TestLogical:testBangFalse()
    lu.assertTrue(eval("!false", {}))
end

function TestLogical:testAndShortResult()
    -- false && anything => false (result check, evaluator evaluates both sides)
    lu.assertFalse(eval("false && true", {}))
end

function TestLogical:testOrShortResult()
    -- true || anything => true (result check, evaluator evaluates both sides)
    lu.assertTrue(eval("true || false", {}))
end

---------------------------------------------------------------------------
-- TestTernary
---------------------------------------------------------------------------
TestTernary = {}

function TestTernary:testTrueCase()
    lu.assertEquals(eval("true ? 'yes' : 'no'", {}), "yes")
end

function TestTernary:testFalseCase()
    lu.assertEquals(eval("false ? 'yes' : 'no'", {}), "no")
end

function TestTernary:testWithExpression()
    lu.assertEquals(eval("x > 5 ? 'big' : 'small'", { x = 10 }), "big")
end

function TestTernary:testNestedTernary()
    lu.assertEquals(eval("true ? false ? 'a' : 'b' : 'c'", {}), "b")
end

---------------------------------------------------------------------------
-- TestComplexExpressions
---------------------------------------------------------------------------
TestComplexExpressions = {}

function TestComplexExpressions:testSignalCondition()
    lu.assertTrue(eval("Show()", { Show = function() return true end }))
end

function TestComplexExpressions:testAndWithSignals()
    lu.assertTrue(eval("A() && B()", {
        A = function() return true end,
        B = function() return true end,
    }))
end

function TestComplexExpressions:testOutputLike()
    lu.assertEquals(eval("item.Name", { item = { Name = "Sword" } }), "Sword")
end

function TestComplexExpressions:testEmptyExpression()
    lu.assertNil(eval("", {}))
end

---------------------------------------------------------------------------
-- TestDefer
---------------------------------------------------------------------------
TestDefer = {}

function TestDefer:testDeferReturnsFunction()
    local fn = ExpressionEvaluator.Defer("x + 1")
    lu.assertEquals(type(fn), "function")
end

function TestDefer:testDeferEvaluatesLater()
    local fn = ExpressionEvaluator.Defer("x + 1")
    lu.assertEquals(fn({ x = 5 }), 6)
    lu.assertEquals(fn({ x = 10 }), 11)
end

function TestDefer:testDeferWithFunctionCall()
    local fn = ExpressionEvaluator.Defer("Name()")
    lu.assertEquals(fn({ Name = function() return "Brad" end }), "Brad")
end

---------------------------------------------------------------------------
-- Run
---------------------------------------------------------------------------
lu.run()
