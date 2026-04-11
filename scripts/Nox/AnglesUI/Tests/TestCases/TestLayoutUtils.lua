--- AnglesUI Test Suite — LayoutUtils
--- Tests for CSS value parsing, unit resolution, shorthand expansion,
--- color parsing, grid template parsing, and text alignment helpers.

package.path = "?.lua;scripts/Nox/AnglesUI/?.lua;scripts/Nox/AnglesUI/Tests/?.lua;scripts/Nox/AnglesUI/Renderer/?.lua;" .. package.path

local lu = require("luaunit")
local LayoutUtils = require("LayoutUtils")

---------------------------------------------------------------------------
-- TestResolveLengthOrNil
---------------------------------------------------------------------------
TestResolveLengthOrNil = {}

function TestResolveLengthOrNil:testPixelValue()
    lu.assertAlmostEquals(LayoutUtils.ResolveLengthOrNil("100px", 800), 100, 0.001)
end

function TestResolveLengthOrNil:testPercentage()
    lu.assertAlmostEquals(LayoutUtils.ResolveLengthOrNil("50%", 800), 400, 0.001)
end

function TestResolveLengthOrNil:testPlainNumber()
    lu.assertAlmostEquals(LayoutUtils.ResolveLengthOrNil("42", 0), 42, 0.001)
end

function TestResolveLengthOrNil:testAutoReturnsNil()
    lu.assertNil(LayoutUtils.ResolveLengthOrNil("auto", 800))
end

function TestResolveLengthOrNil:testNilReturnsNil()
    lu.assertNil(LayoutUtils.ResolveLengthOrNil(nil, 800))
end

function TestResolveLengthOrNil:testEmptyReturnsNil()
    lu.assertNil(LayoutUtils.ResolveLengthOrNil("", 800))
end

function TestResolveLengthOrNil:testNoneReturnsNil()
    lu.assertNil(LayoutUtils.ResolveLengthOrNil("none", 800))
end

function TestResolveLengthOrNil:testZeroPixels()
    lu.assertAlmostEquals(LayoutUtils.ResolveLengthOrNil("0px", 800), 0, 0.001)
end

function TestResolveLengthOrNil:testNegativePixels()
    lu.assertAlmostEquals(LayoutUtils.ResolveLengthOrNil("-10px", 800), -10, 0.001)
end

---------------------------------------------------------------------------
-- TestResolveLength
---------------------------------------------------------------------------
TestResolveLength = {}

function TestResolveLength:testPixelValue()
    lu.assertAlmostEquals(LayoutUtils.ResolveLength("100px", 800), 100, 0.001)
end

function TestResolveLength:testAutoReturnsZero()
    lu.assertAlmostEquals(LayoutUtils.ResolveLength("auto", 800), 0, 0.001)
end

function TestResolveLength:testNilReturnsZero()
    lu.assertAlmostEquals(LayoutUtils.ResolveLength(nil, 800), 0, 0.001)
end

---------------------------------------------------------------------------
-- TestParseNumber
---------------------------------------------------------------------------
TestParseNumber = {}

function TestParseNumber:testPlainNumber()
    lu.assertAlmostEquals(LayoutUtils.ParseNumber("42"), 42, 0.001)
end

function TestParseNumber:testPixelNumber()
    lu.assertAlmostEquals(LayoutUtils.ParseNumber("16px"), 16, 0.001)
end

function TestParseNumber:testNilReturnsZero()
    lu.assertAlmostEquals(LayoutUtils.ParseNumber(nil), 0, 0.001)
end

function TestParseNumber:testNonNumericReturnsZero()
    lu.assertAlmostEquals(LayoutUtils.ParseNumber("abc"), 0, 0.001)
end

---------------------------------------------------------------------------
-- TestParseAspectRatio
---------------------------------------------------------------------------
TestParseAspectRatio = {}

function TestParseAspectRatio:testRatioFormat()
    local r = LayoutUtils.ParseAspectRatio("16/9")
    lu.assertAlmostEquals(r, 16 / 9, 0.001)
end

function TestParseAspectRatio:testSingleNumber()
    lu.assertAlmostEquals(LayoutUtils.ParseAspectRatio("1.5"), 1.5, 0.001)
end

function TestParseAspectRatio:testAutoReturnsNil()
    lu.assertNil(LayoutUtils.ParseAspectRatio("auto"))
end

function TestParseAspectRatio:testNilReturnsNil()
    lu.assertNil(LayoutUtils.ParseAspectRatio(nil))
end

---------------------------------------------------------------------------
-- TestGetStyle
---------------------------------------------------------------------------
TestGetStyle = {}

function TestGetStyle:testExistingProperty()
    lu.assertEquals(LayoutUtils.GetStyle({ width = "200px" }, "width"), "200px")
end

function TestGetStyle:testFallsBackToDefault()
    lu.assertEquals(LayoutUtils.GetStyle({}, "position"), "static")
end

function TestGetStyle:testUnknownPropertyReturnsEmpty()
    lu.assertEquals(LayoutUtils.GetStyle({}, "unknown-prop"), "")
end

---------------------------------------------------------------------------
-- TestExpandBoxShorthand
---------------------------------------------------------------------------
TestExpandBoxShorthand = {}

function TestExpandBoxShorthand:testSingleValue()
    local t, r, b, l = LayoutUtils.ExpandBoxShorthand("10px")
    lu.assertEquals(t, "10px")
    lu.assertEquals(r, "10px")
    lu.assertEquals(b, "10px")
    lu.assertEquals(l, "10px")
end

function TestExpandBoxShorthand:testTwoValues()
    local t, r, b, l = LayoutUtils.ExpandBoxShorthand("10px 20px")
    lu.assertEquals(t, "10px")
    lu.assertEquals(r, "20px")
    lu.assertEquals(b, "10px")
    lu.assertEquals(l, "20px")
end

function TestExpandBoxShorthand:testThreeValues()
    local t, r, b, l = LayoutUtils.ExpandBoxShorthand("10px 20px 30px")
    lu.assertEquals(t, "10px")
    lu.assertEquals(r, "20px")
    lu.assertEquals(b, "30px")
    lu.assertEquals(l, "20px")
end

function TestExpandBoxShorthand:testFourValues()
    local t, r, b, l = LayoutUtils.ExpandBoxShorthand("10px 20px 30px 40px")
    lu.assertEquals(t, "10px")
    lu.assertEquals(r, "20px")
    lu.assertEquals(b, "30px")
    lu.assertEquals(l, "40px")
end

function TestExpandBoxShorthand:testEmptyString()
    local t, r, b, l = LayoutUtils.ExpandBoxShorthand("")
    lu.assertEquals(t, "0")
end

---------------------------------------------------------------------------
-- TestResolvePadding
---------------------------------------------------------------------------
TestResolvePadding = {}

function TestResolvePadding:testShorthand()
    local t, r, b, l = LayoutUtils.ResolvePadding({ padding = "10px 20px" }, 800, 600)
    lu.assertAlmostEquals(t, 10, 0.001)
    lu.assertAlmostEquals(r, 20, 0.001)
    lu.assertAlmostEquals(b, 10, 0.001)
    lu.assertAlmostEquals(l, 20, 0.001)
end

function TestResolvePadding:testIndividualOverridesShorthand()
    local t, r, b, l = LayoutUtils.ResolvePadding({
        padding = "10px",
        ["padding-right"] = "50px"
    }, 800, 600)
    lu.assertAlmostEquals(t, 10, 0.001)
    lu.assertAlmostEquals(r, 50, 0.001)
end

function TestResolvePadding:testNoStyles()
    local t, r, b, l = LayoutUtils.ResolvePadding({}, 800, 600)
    lu.assertAlmostEquals(t, 0, 0.001)
    lu.assertAlmostEquals(r, 0, 0.001)
end

---------------------------------------------------------------------------
-- TestResolveMargin
---------------------------------------------------------------------------
TestResolveMargin = {}

function TestResolveMargin:testShorthand()
    local t, r, b, l = LayoutUtils.ResolveMargin({ margin = "5px 10px 15px 20px" }, 800, 600)
    lu.assertAlmostEquals(t, 5, 0.001)
    lu.assertAlmostEquals(r, 10, 0.001)
    lu.assertAlmostEquals(b, 15, 0.001)
    lu.assertAlmostEquals(l, 20, 0.001)
end

---------------------------------------------------------------------------
-- TestParseBorderValue
---------------------------------------------------------------------------
TestParseBorderValue = {}

function TestParseBorderValue:testQuotedPath()
    local size, path, tH, tV =
        LayoutUtils.ParseBorderValue('10px "textures/border.dds" true false')
    lu.assertAlmostEquals(size, 10, 0.001)
    lu.assertEquals(path, "textures/border.dds")
    lu.assertTrue(tH)
    lu.assertFalse(tV)
end

function TestParseBorderValue:testUnquotedPath()
    local size, path, tH, tV =
        LayoutUtils.ParseBorderValue("10px textures/border.dds false true")
    lu.assertAlmostEquals(size, 10, 0.001)
    lu.assertEquals(path, "textures/border.dds")
    lu.assertFalse(tH)
    lu.assertTrue(tV)
end

function TestParseBorderValue:testNoneReturnsNil()
    local size = LayoutUtils.ParseBorderValue("none")
    lu.assertNil(size)
end

function TestParseBorderValue:testNilReturnsNil()
    local size = LayoutUtils.ParseBorderValue(nil)
    lu.assertNil(size)
end

---------------------------------------------------------------------------
-- TestResolveBorderWidths
---------------------------------------------------------------------------
TestResolveBorderWidths = {}

function TestResolveBorderWidths:testSideBorders()
    local t, r, b, l = LayoutUtils.ResolveBorderWidths({
        ["border-top"] = '5px "tex.dds" false false',
        ["border-right"] = '3px "tex.dds" false false',
    })
    lu.assertAlmostEquals(t, 5, 0.001)
    lu.assertAlmostEquals(r, 3, 0.001)
    lu.assertAlmostEquals(b, 0, 0.001)
    lu.assertAlmostEquals(l, 0, 0.001)
end

function TestResolveBorderWidths:testCornerContributes()
    local t, r, b, l = LayoutUtils.ResolveBorderWidths({
        ["border-top-left-corner"] = '8px "tex.dds" false false',
    })
    lu.assertAlmostEquals(t, 8, 0.001)
    lu.assertAlmostEquals(l, 8, 0.001)
end

---------------------------------------------------------------------------
-- TestParseBackgroundImage
---------------------------------------------------------------------------
TestParseBackgroundImage = {}

function TestParseBackgroundImage:testQuoted()
    lu.assertEquals(LayoutUtils.ParseBackgroundImage('"textures/bg.dds"'), "textures/bg.dds")
end

function TestParseBackgroundImage:testNone()
    lu.assertNil(LayoutUtils.ParseBackgroundImage("none"))
end

function TestParseBackgroundImage:testNil()
    lu.assertNil(LayoutUtils.ParseBackgroundImage(nil))
end

---------------------------------------------------------------------------
-- TestParseBackgroundRepeat
---------------------------------------------------------------------------
TestParseBackgroundRepeat = {}

function TestParseBackgroundRepeat:testRepeatX()
    local tH, tV = LayoutUtils.ParseBackgroundRepeat("repeat-x")
    lu.assertTrue(tH)
    lu.assertFalse(tV)
end

function TestParseBackgroundRepeat:testRepeat()
    local tH, tV = LayoutUtils.ParseBackgroundRepeat("repeat")
    lu.assertTrue(tH)
    lu.assertTrue(tV)
end

function TestParseBackgroundRepeat:testNoRepeat()
    local tH, tV = LayoutUtils.ParseBackgroundRepeat("no-repeat")
    lu.assertFalse(tH)
    lu.assertFalse(tV)
end

---------------------------------------------------------------------------
-- TestParseColor
---------------------------------------------------------------------------
TestParseColor = {}

function TestParseColor:testHex6()
    local r, g, b = LayoutUtils.ParseColor("#ff0000")
    lu.assertAlmostEquals(r, 1, 0.01)
    lu.assertAlmostEquals(g, 0, 0.01)
    lu.assertAlmostEquals(b, 0, 0.01)
end

function TestParseColor:testHex3()
    local r, g, b = LayoutUtils.ParseColor("#f00")
    lu.assertAlmostEquals(r, 1, 0.01)
    lu.assertAlmostEquals(g, 0, 0.01)
    lu.assertAlmostEquals(b, 0, 0.01)
end

function TestParseColor:testRgb()
    local r, g, b = LayoutUtils.ParseColor("rgb(255, 128, 0)")
    lu.assertAlmostEquals(r, 1, 0.01)
    lu.assertAlmostEquals(g, 128 / 255, 0.01)
    lu.assertAlmostEquals(b, 0, 0.01)
end

function TestParseColor:testNamedColor()
    local r, g, b = LayoutUtils.ParseColor("red")
    lu.assertAlmostEquals(r, 1, 0.01)
    lu.assertAlmostEquals(g, 0, 0.01)
    lu.assertAlmostEquals(b, 0, 0.01)
end

function TestParseColor:testNilReturnsNil()
    lu.assertNil(LayoutUtils.ParseColor(nil))
end

---------------------------------------------------------------------------
-- TestParseGridTemplate
---------------------------------------------------------------------------
TestParseGridTemplate = {}

function TestParseGridTemplate:testPixelTracks()
    local tracks = LayoutUtils.ParseGridTemplate("200px 100px")
    lu.assertEquals(#tracks, 2)
    lu.assertEquals(tracks[1].type, "px")
    lu.assertAlmostEquals(tracks[1].value, 200, 0.001)
    lu.assertAlmostEquals(tracks[2].value, 100, 0.001)
end

function TestParseGridTemplate:testFrTracks()
    local tracks = LayoutUtils.ParseGridTemplate("1fr 2fr")
    lu.assertEquals(#tracks, 2)
    lu.assertEquals(tracks[1].type, "fr")
    lu.assertAlmostEquals(tracks[1].value, 1, 0.001)
    lu.assertAlmostEquals(tracks[2].value, 2, 0.001)
end

function TestParseGridTemplate:testRepeatSyntax()
    local tracks = LayoutUtils.ParseGridTemplate("repeat(3, 1fr)")
    lu.assertEquals(#tracks, 3)
    for _, t in ipairs(tracks) do
        lu.assertEquals(t.type, "fr")
    end
end

function TestParseGridTemplate:testAutoTrack()
    local tracks = LayoutUtils.ParseGridTemplate("auto 100px")
    lu.assertEquals(tracks[1].type, "auto")
    lu.assertEquals(tracks[2].type, "px")
end

function TestParseGridTemplate:testNoneReturnsEmpty()
    lu.assertEquals(#LayoutUtils.ParseGridTemplate("none"), 0)
end

---------------------------------------------------------------------------
-- TestResolveGridTracks
---------------------------------------------------------------------------
TestResolveGridTracks = {}

function TestResolveGridTracks:testFixedTracks()
    local tracks = {{ type = "px", value = 100 }, { type = "px", value = 200 }}
    local sizes = LayoutUtils.ResolveGridTracks(tracks, 600)
    lu.assertAlmostEquals(sizes[1], 100, 0.001)
    lu.assertAlmostEquals(sizes[2], 200, 0.001)
end

function TestResolveGridTracks:testFrDistribution()
    local tracks = {{ type = "fr", value = 1 }, { type = "fr", value = 2 }}
    local sizes = LayoutUtils.ResolveGridTracks(tracks, 300)
    lu.assertAlmostEquals(sizes[1], 100, 0.001)
    lu.assertAlmostEquals(sizes[2], 200, 0.001)
end

function TestResolveGridTracks:testMixedFixedAndFr()
    local tracks = {{ type = "px", value = 100 }, { type = "fr", value = 1 }}
    local sizes = LayoutUtils.ResolveGridTracks(tracks, 500)
    lu.assertAlmostEquals(sizes[1], 100, 0.001)
    lu.assertAlmostEquals(sizes[2], 400, 0.001)
end

function TestResolveGridTracks:testPercentage()
    local tracks = {{ type = "percent", value = 50 }}
    local sizes = LayoutUtils.ResolveGridTracks(tracks, 800)
    lu.assertAlmostEquals(sizes[1], 400, 0.001)
end

function TestResolveGridTracks:testAutoWithSizes()
    local tracks = {{ type = "auto", value = 0 }}
    local sizes = LayoutUtils.ResolveGridTracks(tracks, 800, { 120 })
    lu.assertAlmostEquals(sizes[1], 120, 0.001)
end

---------------------------------------------------------------------------
-- TestParseGridLineShorthand
---------------------------------------------------------------------------
TestParseGridLineShorthand = {}

function TestParseGridLineShorthand:testStartAndEnd()
    local s, e = LayoutUtils.ParseGridLineShorthand("1 / 3")
    lu.assertEquals(s, "1")
    lu.assertEquals(e, "3")
end

function TestParseGridLineShorthand:testStartOnly()
    local s, e = LayoutUtils.ParseGridLineShorthand("2")
    lu.assertEquals(s, "2")
    lu.assertEquals(e, "auto")
end

function TestParseGridLineShorthand:testAutoReturnsAutoAuto()
    local s, e = LayoutUtils.ParseGridLineShorthand("auto")
    lu.assertEquals(s, "auto")
    lu.assertEquals(e, "auto")
end

---------------------------------------------------------------------------
-- TestParseGridLine
---------------------------------------------------------------------------
TestParseGridLine = {}

function TestParseGridLine:testLineNumber()
    local num, span = LayoutUtils.ParseGridLine("3")
    lu.assertEquals(num, 3)
    lu.assertNil(span)
end

function TestParseGridLine:testSpan()
    local num, span = LayoutUtils.ParseGridLine("span 2")
    lu.assertNil(num)
    lu.assertEquals(span, 2)
end

function TestParseGridLine:testAutoReturnsNilNil()
    local num, span = LayoutUtils.ParseGridLine("auto")
    lu.assertNil(num)
    lu.assertNil(span)
end

---------------------------------------------------------------------------
-- TestTextAlignment
---------------------------------------------------------------------------
TestTextAlignment = {}

function TestTextAlignment:testHorizontalCenter()
    lu.assertEquals(LayoutUtils.MapTextAlignH("center"), "Center")
end

function TestTextAlignment:testHorizontalEnd()
    lu.assertEquals(LayoutUtils.MapTextAlignH("end"), "End")
end

function TestTextAlignment:testHorizontalDefault()
    lu.assertEquals(LayoutUtils.MapTextAlignH("start"), "Start")
end

function TestTextAlignment:testVerticalMiddle()
    lu.assertEquals(LayoutUtils.MapVerticalAlign("middle"), "Center")
end

function TestTextAlignment:testVerticalBottom()
    lu.assertEquals(LayoutUtils.MapVerticalAlign("bottom"), "End")
end

function TestTextAlignment:testVerticalDefault()
    lu.assertEquals(LayoutUtils.MapVerticalAlign("top"), "Start")
end

---------------------------------------------------------------------------
-- Run
---------------------------------------------------------------------------
lu.run()
