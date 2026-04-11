--- AnglesUI TextMeasure — Utility for estimating text dimensions in OpenMW.
--- OpenMW's Lua API provides no way to measure rendered text, so we estimate
--- width and height from character count, per-character width factors, and
--- font size. This module is intentionally isolated so that if OpenMW adds a
--- native text measurement API in the future, only this file needs updating.

---@class AnglesUI.TextMeasure
local TextMeasure = {}

---------------------------------------------------------------------------
-- Configuration
---------------------------------------------------------------------------

--- Default font size used when none is specified.
---@type number
TextMeasure.DEFAULT_FONT_SIZE = 16

--- Base width factor — the *average* character width expressed as a fraction
--- of the font size. At font size 16 with factor 0.52 an average character
--- is ~8.3 px wide. Tweak this to taste.
---@type number
TextMeasure.BASE_WIDTH_FACTOR = 0.52

--- Per-character width overrides, expressed as a multiplier relative to the
--- base width (`BASE_WIDTH_FACTOR * fontSize`). For example a value of 0.5
--- means the character is half as wide as an average character.
--- Only characters that differ noticeably from the average need entries.
---@type table<string, number>
TextMeasure.CharWidthOverrides = {
    -- Narrow characters
    ["i"] = 0.45,
    ["l"] = 0.40,
    ["I"] = 0.45,
    ["1"] = 0.55,
    ["!"] = 0.40,
    ["|"] = 0.35,
    ["."] = 0.40,
    [","] = 0.40,
    [":"] = 0.40,
    [";"] = 0.40,
    ["'"] = 0.35,
    [" "] = 0.50,
    ["t"] = 0.60,
    ["f"] = 0.55,
    ["r"] = 0.60,
    ["j"] = 0.50,

    -- Wide characters
    ["m"] = 1.50,
    ["w"] = 1.35,
    ["M"] = 1.40,
    ["W"] = 1.50,
    ["@"] = 1.30,
    ["G"] = 1.15,
    ["O"] = 1.15,
    ["Q"] = 1.15,
    ["D"] = 1.10,
    ["H"] = 1.10,
    ["N"] = 1.10,
    ["U"] = 1.10,
}

--- Line-height multiplier relative to font size.
--- A value of 1.2 means a 16 px font produces ~19 px line height.
---@type number
TextMeasure.LINE_HEIGHT_FACTOR = 1.2

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

--- Estimate the width (in pixels) of a single line of text.
---@param text string The text to measure
---@param fontSize? number Font size in pixels (defaults to DEFAULT_FONT_SIZE)
---@return number width Estimated width in pixels
---@nodiscard
function TextMeasure.MeasureWidth(text, fontSize)
    fontSize = fontSize or TextMeasure.DEFAULT_FONT_SIZE
    local baseCharWidth = TextMeasure.BASE_WIDTH_FACTOR * fontSize
    local totalWidth = 0

    for i = 1, #text do
        local ch = text:sub(i, i)
        local factor = TextMeasure.CharWidthOverrides[ch] or 1.0
        totalWidth = totalWidth + (baseCharWidth * factor)
    end

    return totalWidth
end

--- Estimate the height (in pixels) of a single line of text.
---@param fontSize? number Font size in pixels (defaults to DEFAULT_FONT_SIZE)
---@return number height Estimated line height in pixels
---@nodiscard
function TextMeasure.MeasureLineHeight(fontSize)
    fontSize = fontSize or TextMeasure.DEFAULT_FONT_SIZE
    return fontSize * TextMeasure.LINE_HEIGHT_FACTOR
end

--- Estimate the bounding box of a block of text. For single-line text the
--- returned height is one line height. When `maxWidth` is provided the text
--- is soft-wrapped (word-wrap style) and the height reflects the number of
--- resulting lines.
---@param text string The text to measure
---@param fontSize? number Font size in pixels (defaults to DEFAULT_FONT_SIZE)
---@param maxWidth? number Maximum width in pixels before wrapping (nil = no wrap)
---@param wordWrap? boolean Whether to break at word boundaries (default true if maxWidth given)
---@return number width The width of the widest line
---@return number height The total height of all lines
---@nodiscard
function TextMeasure.MeasureBounds(text, fontSize, maxWidth, wordWrap)
    fontSize = fontSize or TextMeasure.DEFAULT_FONT_SIZE
    local lineHeight = TextMeasure.MeasureLineHeight(fontSize)

    -- No wrapping — fast path
    if not maxWidth then
        local w = TextMeasure.MeasureWidth(text, fontSize)
        return w, lineHeight
    end

    -- Default wordWrap to true when maxWidth is given
    if wordWrap == nil then
        wordWrap = true
    end

    -- Split the input into hard lines first (explicit newlines)
    local hardLines = TextMeasure._splitLines(text)
    local totalLines = 0
    local widestLine = 0

    for _, line in ipairs(hardLines) do
        local wrappedWidth, lineCount = TextMeasure._wrapLine(line, fontSize, maxWidth, wordWrap)
        totalLines = totalLines + lineCount
        if wrappedWidth > widestLine then
            widestLine = wrappedWidth
        end
    end

    return widestLine, totalLines * lineHeight
end

---------------------------------------------------------------------------
-- Internal helpers
---------------------------------------------------------------------------

--- Split text on newline characters into an array of lines.
---@private
---@param text string
---@return string[]
function TextMeasure._splitLines(text)
    local lines = {}
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        lines[#lines + 1] = line
    end
    return lines
end

--- Wrap a single hard line into soft lines constrained by `maxWidth`.
--- Returns the widest soft-line width and the number of soft lines.
---@private
---@param line string
---@param fontSize number
---@param maxWidth number
---@param wordWrap boolean
---@return number widestWidth
---@return integer lineCount
function TextMeasure._wrapLine(line, fontSize, maxWidth, wordWrap)
    if #line == 0 then
        return 0, 1
    end

    local baseCharWidth = TextMeasure.BASE_WIDTH_FACTOR * fontSize
    local lineCount = 1
    local currentWidth = 0
    local widestWidth = 0

    if wordWrap then
        -- Word-wrap: break between words (spaces)
        local wordStart = 1
        while wordStart <= #line do
            -- Skip leading spaces
            local spaceEnd = wordStart
            while spaceEnd <= #line and line:sub(spaceEnd, spaceEnd) == " " do
                spaceEnd = spaceEnd + 1
            end

            -- Find the end of the next word
            local wordEnd = spaceEnd
            while wordEnd <= #line and line:sub(wordEnd, wordEnd) ~= " " do
                wordEnd = wordEnd + 1
            end

            -- Measure the chunk (spaces + word)
            local chunkWidth = 0
            for ci = wordStart, wordEnd - 1 do
                local ch = line:sub(ci, ci)
                local factor = TextMeasure.CharWidthOverrides[ch] or 1.0
                chunkWidth = chunkWidth + (baseCharWidth * factor)
            end

            if currentWidth + chunkWidth > maxWidth and currentWidth > 0 then
                -- Wrap to a new line
                if currentWidth > widestWidth then
                    widestWidth = currentWidth
                end
                lineCount = lineCount + 1
                currentWidth = 0

                -- Re-measure without leading spaces for the new line
                chunkWidth = 0
                for ci = spaceEnd, wordEnd - 1 do
                    local ch = line:sub(ci, ci)
                    local factor = TextMeasure.CharWidthOverrides[ch] or 1.0
                    chunkWidth = chunkWidth + (baseCharWidth * factor)
                end
            end

            currentWidth = currentWidth + chunkWidth
            wordStart = wordEnd
        end
    else
        -- Character-wrap: break anywhere
        for i = 1, #line do
            local ch = line:sub(i, i)
            local factor = TextMeasure.CharWidthOverrides[ch] or 1.0
            local charW = baseCharWidth * factor

            if currentWidth + charW > maxWidth and currentWidth > 0 then
                if currentWidth > widestWidth then
                    widestWidth = currentWidth
                end
                lineCount = lineCount + 1
                currentWidth = 0
            end

            currentWidth = currentWidth + charW
        end
    end

    -- Account for the last soft line
    if currentWidth > widestWidth then
        widestWidth = currentWidth
    end

    return widestWidth, lineCount
end

return TextMeasure
