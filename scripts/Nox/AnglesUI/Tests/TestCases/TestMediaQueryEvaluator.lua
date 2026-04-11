--- AnglesUI Test Suite — Media Query Evaluator
--- Tests for evaluating @media rule preludes against screen dimensions.

package.path = "?.lua;scripts/Nox/AnglesUI/?.lua;scripts/Nox/AnglesUI/Tests/?.lua;scripts/Nox/AnglesUI/DOM/?.lua;" .. package.path

local lu = require("luaunit")
local MediaQueryEvaluator = require("MediaQueryEvaluator")

---------------------------------------------------------------------------
-- TestConstruction
---------------------------------------------------------------------------
TestConstruction = {}

function TestConstruction:testNew()
    local mq = MediaQueryEvaluator.New(1920, 1080)
    local w, h = mq:GetScreenSize()
    lu.assertEquals(w, 1920)
    lu.assertEquals(h, 1080)
end

function TestConstruction:testSetScreenSize()
    local mq = MediaQueryEvaluator.New(800, 600)
    mq:SetScreenSize(1920, 1080)
    local w, h = mq:GetScreenSize()
    lu.assertEquals(w, 1920)
    lu.assertEquals(h, 1080)
end

---------------------------------------------------------------------------
-- TestMaxWidth
---------------------------------------------------------------------------
TestMaxWidth = {}

function TestMaxWidth:testTrue()
    local mq = MediaQueryEvaluator.New(500, 800)
    lu.assertTrue(mq:Evaluate("(max-width: 600px)"))
end

function TestMaxWidth:testFalse()
    local mq = MediaQueryEvaluator.New(800, 600)
    lu.assertFalse(mq:Evaluate("(max-width: 600px)"))
end

function TestMaxWidth:testEqual()
    local mq = MediaQueryEvaluator.New(600, 800)
    lu.assertTrue(mq:Evaluate("(max-width: 600px)"))
end

---------------------------------------------------------------------------
-- TestMinWidth
---------------------------------------------------------------------------
TestMinWidth = {}

function TestMinWidth:testTrue()
    local mq = MediaQueryEvaluator.New(800, 600)
    lu.assertTrue(mq:Evaluate("(min-width: 600px)"))
end

function TestMinWidth:testFalse()
    local mq = MediaQueryEvaluator.New(400, 600)
    lu.assertFalse(mq:Evaluate("(min-width: 600px)"))
end

---------------------------------------------------------------------------
-- TestHeight
---------------------------------------------------------------------------
TestHeight = {}

function TestHeight:testMaxHeightTrue()
    local mq = MediaQueryEvaluator.New(800, 400)
    lu.assertTrue(mq:Evaluate("(max-height: 600px)"))
end

function TestHeight:testMinHeightFalse()
    local mq = MediaQueryEvaluator.New(800, 400)
    lu.assertFalse(mq:Evaluate("(min-height: 600px)"))
end

---------------------------------------------------------------------------
-- TestComparisonSyntax
---------------------------------------------------------------------------
TestComparisonSyntax = {}

function TestComparisonSyntax:testWidthLte()
    local mq = MediaQueryEvaluator.New(600, 800)
    lu.assertTrue(mq:Evaluate("(width <= 600px)"))
    lu.assertTrue(mq:Evaluate("(width <= 700px)"))
    lu.assertFalse(mq:Evaluate("(width <= 500px)"))
end

function TestComparisonSyntax:testWidthGte()
    local mq = MediaQueryEvaluator.New(600, 800)
    lu.assertTrue(mq:Evaluate("(width >= 600px)"))
    lu.assertTrue(mq:Evaluate("(width >= 500px)"))
    lu.assertFalse(mq:Evaluate("(width >= 700px)"))
end

function TestComparisonSyntax:testWidthLt()
    local mq = MediaQueryEvaluator.New(600, 800)
    lu.assertFalse(mq:Evaluate("(width < 600px)"))
    lu.assertTrue(mq:Evaluate("(width < 700px)"))
end

function TestComparisonSyntax:testWidthGt()
    local mq = MediaQueryEvaluator.New(600, 800)
    lu.assertFalse(mq:Evaluate("(width > 600px)"))
    lu.assertTrue(mq:Evaluate("(width > 500px)"))
end

function TestComparisonSyntax:testHeightComparison()
    local mq = MediaQueryEvaluator.New(800, 600)
    lu.assertTrue(mq:Evaluate("(height <= 600px)"))
    lu.assertFalse(mq:Evaluate("(height > 600px)"))
end

---------------------------------------------------------------------------
-- TestCompound
---------------------------------------------------------------------------
TestCompound = {}

function TestCompound:testAndBothTrue()
    local mq = MediaQueryEvaluator.New(500, 800)
    lu.assertTrue(mq:Evaluate("(min-width: 400px) and (max-width: 600px)"))
end

function TestCompound:testAndOneFalse()
    local mq = MediaQueryEvaluator.New(700, 800)
    lu.assertFalse(mq:Evaluate("(min-width: 400px) and (max-width: 600px)"))
end

function TestCompound:testCommaOrFirstTrue()
    local mq = MediaQueryEvaluator.New(400, 800)
    lu.assertTrue(mq:Evaluate("(max-width: 500px), (min-width: 800px)"))
end

function TestCompound:testCommaOrSecondTrue()
    local mq = MediaQueryEvaluator.New(900, 800)
    lu.assertTrue(mq:Evaluate("(max-width: 500px), (min-width: 800px)"))
end

function TestCompound:testCommaOrBothFalse()
    local mq = MediaQueryEvaluator.New(600, 800)
    lu.assertFalse(mq:Evaluate("(max-width: 500px), (min-width: 800px)"))
end

---------------------------------------------------------------------------
-- TestEdgeCases
---------------------------------------------------------------------------
TestEdgeCases = {}

function TestEdgeCases:testEmptyPrelude()
    local mq = MediaQueryEvaluator.New(800, 600)
    lu.assertTrue(mq:Evaluate(""))
end

function TestEdgeCases:testCreateEvaluatorFunc()
    local mq = MediaQueryEvaluator.New(800, 600)
    local fn = mq:CreateEvaluatorFunc()
    lu.assertEquals(type(fn), "function")
    lu.assertTrue(fn("(min-width: 600px)"))
    lu.assertFalse(fn("(max-width: 600px)"))
end

---------------------------------------------------------------------------
-- Run
---------------------------------------------------------------------------
lu.run()
