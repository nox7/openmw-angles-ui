--- AnglesUI Test Suite — TextMeasure
--- Tests for text dimension estimation: width, line height, and bounding
--- boxes with word/character wrapping.

package.path = "scripts/Nox/AnglesUI/?.lua;scripts/Nox/AnglesUI/Tests/?.lua;" .. package.path

local lu = require("luaunit")
local TextMeasure = require("TextMeasure")

---------------------------------------------------------------------------
-- TestMeasureWidth
---------------------------------------------------------------------------
TestMeasureWidth = {}

function TestMeasureWidth:testEmptyString()
    local w = TextMeasure.MeasureWidth("", 16)
    lu.assertEquals(w, 0)
end

function TestMeasureWidth:testSingleAverageChar()
    -- A character with no override uses factor 1.0
    -- baseCharWidth = 0.52 * 16 = 8.32
    local w = TextMeasure.MeasureWidth("a", 16)
    lu.assertAlmostEquals(w, 8.32, 0.01)
end

function TestMeasureWidth:testMultipleAverageChars()
    local w = TextMeasure.MeasureWidth("aaa", 16)
    lu.assertAlmostEquals(w, 8.32 * 3, 0.01)
end

function TestMeasureWidth:testNarrowChar()
    -- "l" has override 0.40
    local baseCharWidth = 0.52 * 16
    local expected = baseCharWidth * 0.40
    local w = TextMeasure.MeasureWidth("l", 16)
    lu.assertAlmostEquals(w, expected, 0.01)
end

function TestMeasureWidth:testWideChar()
    -- "m" has override 1.50
    local baseCharWidth = 0.52 * 16
    local expected = baseCharWidth * 1.50
    local w = TextMeasure.MeasureWidth("m", 16)
    lu.assertAlmostEquals(w, expected, 0.01)
end

function TestMeasureWidth:testMixedChars()
    -- "lm" = narrow + wide
    local baseCharWidth = 0.52 * 16
    local expected = (baseCharWidth * 0.40) + (baseCharWidth * 1.50)
    local w = TextMeasure.MeasureWidth("lm", 16)
    lu.assertAlmostEquals(w, expected, 0.01)
end

function TestMeasureWidth:testDefaultFontSize()
    -- Omitting fontSize should use DEFAULT_FONT_SIZE (16)
    local withExplicit = TextMeasure.MeasureWidth("hello", 16)
    local withDefault = TextMeasure.MeasureWidth("hello")
    lu.assertAlmostEquals(withDefault, withExplicit, 0.001)
end

function TestMeasureWidth:testCustomFontSize()
    -- Doubling font size should double the width
    local w16 = TextMeasure.MeasureWidth("abc", 16)
    local w32 = TextMeasure.MeasureWidth("abc", 32)
    lu.assertAlmostEquals(w32, w16 * 2, 0.01)
end

function TestMeasureWidth:testSpaceCharacter()
    -- " " has override 0.50
    local baseCharWidth = 0.52 * 16
    local expected = baseCharWidth * 0.50
    local w = TextMeasure.MeasureWidth(" ", 16)
    lu.assertAlmostEquals(w, expected, 0.01)
end

---------------------------------------------------------------------------
-- TestMeasureLineHeight
---------------------------------------------------------------------------
TestMeasureLineHeight = {}

function TestMeasureLineHeight:testDefaultFontSize()
    -- 16 * 1.2 = 19.2
    local h = TextMeasure.MeasureLineHeight()
    lu.assertAlmostEquals(h, 19.2, 0.01)
end

function TestMeasureLineHeight:testExplicitFontSize()
    local h = TextMeasure.MeasureLineHeight(20)
    lu.assertAlmostEquals(h, 24.0, 0.01)
end

function TestMeasureLineHeight:testScalesLinearly()
    local h1 = TextMeasure.MeasureLineHeight(10)
    local h2 = TextMeasure.MeasureLineHeight(20)
    lu.assertAlmostEquals(h2, h1 * 2, 0.01)
end

---------------------------------------------------------------------------
-- TestMeasureBounds
---------------------------------------------------------------------------
TestMeasureBounds = {}

function TestMeasureBounds:testSingleLineNoWrap()
    local w, h = TextMeasure.MeasureBounds("hello", 16)
    local expectedW = TextMeasure.MeasureWidth("hello", 16)
    local expectedH = TextMeasure.MeasureLineHeight(16)
    lu.assertAlmostEquals(w, expectedW, 0.01)
    lu.assertAlmostEquals(h, expectedH, 0.01)
end

function TestMeasureBounds:testEmptyStringNoWrap()
    local w, h = TextMeasure.MeasureBounds("", 16)
    lu.assertEquals(w, 0)
    lu.assertAlmostEquals(h, TextMeasure.MeasureLineHeight(16), 0.01)
end

function TestMeasureBounds:testWithMaxWidthWrapsWordWrap()
    -- Force text to wrap by setting a very small maxWidth
    local text = "hello world"
    local w, h = TextMeasure.MeasureBounds(text, 16, 50, true)
    local lineH = TextMeasure.MeasureLineHeight(16)
    -- With a 50px max width, "hello world" should wrap to at least 2 lines
    lu.assertTrue(h >= lineH * 2)
    -- The widest line should be <= maxWidth (or at least a single word)
    lu.assertTrue(w > 0)
end

function TestMeasureBounds:testWithMaxWidthCharacterWrap()
    -- Character wrap: break anywhere
    local text = "abcdefghij"
    local w, h = TextMeasure.MeasureBounds(text, 16, 30, false)
    local lineH = TextMeasure.MeasureLineHeight(16)
    -- With 30px max and ~8.32px per char, about 3 chars per line => ~4 lines
    lu.assertTrue(h >= lineH * 2)
end

function TestMeasureBounds:testNoWrapWhenTextFits()
    -- Text fits within maxWidth → single line
    local text = "hi"
    local w, h = TextMeasure.MeasureBounds(text, 16, 500, true)
    local lineH = TextMeasure.MeasureLineHeight(16)
    lu.assertAlmostEquals(h, lineH, 0.01)
end

function TestMeasureBounds:testHardNewlines()
    -- Explicit newlines always break regardless of maxWidth
    local text = "line1\nline2\nline3"
    local w, h = TextMeasure.MeasureBounds(text, 16, 1000, true)
    local lineH = TextMeasure.MeasureLineHeight(16)
    lu.assertAlmostEquals(h, lineH * 3, 0.01)
end

function TestMeasureBounds:testWordWrapDefaultsTrueWhenMaxWidthGiven()
    -- When maxWidth is given and wordWrap is nil, it defaults to true
    local text = "hello world foo bar"
    local w1, h1 = TextMeasure.MeasureBounds(text, 16, 60, true)
    local w2, h2 = TextMeasure.MeasureBounds(text, 16, 60) -- wordWrap omitted
    lu.assertAlmostEquals(h1, h2, 0.01)
    lu.assertAlmostEquals(w1, w2, 0.01)
end

function TestMeasureBounds:testDefaultFontSizeUsed()
    local w1, h1 = TextMeasure.MeasureBounds("test", 16)
    local w2, h2 = TextMeasure.MeasureBounds("test")
    lu.assertAlmostEquals(w1, w2, 0.001)
    lu.assertAlmostEquals(h1, h2, 0.001)
end

---------------------------------------------------------------------------
-- TestCharWidthOverrides — verify override mechanism
---------------------------------------------------------------------------
TestCharWidthOverrides = {}

function TestCharWidthOverrides:testOverrideCanBeChanged()
    local originalFactor = TextMeasure.CharWidthOverrides["i"]
    lu.assertNotNil(originalFactor)

    -- Temporarily override
    local saved = TextMeasure.CharWidthOverrides["i"]
    TextMeasure.CharWidthOverrides["i"] = 2.0

    local baseCharWidth = TextMeasure.BASE_WIDTH_FACTOR * 16
    local w = TextMeasure.MeasureWidth("i", 16)
    lu.assertAlmostEquals(w, baseCharWidth * 2.0, 0.01)

    -- Restore
    TextMeasure.CharWidthOverrides["i"] = saved
end

function TestCharWidthOverrides:testNewCharOverride()
    -- Add override for a character that doesn't have one
    lu.assertIsNil(TextMeasure.CharWidthOverrides["z"])

    TextMeasure.CharWidthOverrides["z"] = 0.75
    local baseCharWidth = TextMeasure.BASE_WIDTH_FACTOR * 16
    local w = TextMeasure.MeasureWidth("z", 16)
    lu.assertAlmostEquals(w, baseCharWidth * 0.75, 0.01)

    -- Cleanup
    TextMeasure.CharWidthOverrides["z"] = nil
end

os.exit(lu.run())
