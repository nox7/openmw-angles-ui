--- AnglesUI Layout Utilities.
--- CSS value parsing, unit resolution, shorthand expansion, and color parsing.
--- All layout modules share these utilities.

local TextMeasure = require("scripts.Nox.AnglesUI.TextMeasure")

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

--- @class AnglesUI.LayoutUtils
local LayoutUtils = {}

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------

--- Default values for CSS properties used during layout.
--- @type table<string, string>
LayoutUtils.DEFAULTS = {
    ["position"]         = "static",
    ["width"]            = "auto",
    ["height"]           = "auto",
    ["left"]             = "auto",
    ["top"]              = "auto",
    ["right"]            = "auto",
    ["bottom"]           = "auto",
    ["padding-top"]      = "0",
    ["padding-right"]    = "0",
    ["padding-bottom"]   = "0",
    ["padding-left"]     = "0",
    ["margin-top"]       = "0",
    ["margin-right"]     = "0",
    ["margin-bottom"]    = "0",
    ["margin-left"]      = "0",
    ["flex-direction"]   = "row",
    ["justify-content"]  = "start",
    ["align-items"]      = "stretch",
    ["align-content"]    = "start",
    ["gap"]              = "0",
    ["grid-row-gap"]     = "0",
    ["grid-column-gap"]  = "0",
    ["flex-grow"]        = "0",
    ["flex-shrink"]      = "1",
    ["flex-basis"]       = "auto",
    ["opacity"]          = "1",
    ["visibility"]       = "visible",
    ["aspect-ratio"]     = "auto",
    ["font-size"]        = "16px",
    ["scrollbar-width"]  = "13px",
    ["background-image-opacity"] = "1",
    ["background-repeat"]        = "no-repeat",
    ["container-type"]           = "none",
}

---------------------------------------------------------------------------
-- CSS Value Parsing
---------------------------------------------------------------------------

--- Parse a CSS length value to pixels.
--- Accepts: "123px", "50%", "auto", plain numbers, "0".
--- Returns nil for "auto" or unresolved values.
--- @param value string|nil The CSS value
--- @param referenceSize number The reference size for percentage resolution (parent width/height)
--- @return number|nil pixels The resolved pixel value, or nil for "auto"
function LayoutUtils.ResolveLengthOrNil(value, referenceSize)
    if not value or value == "auto" or value == "" or value == "none" then
        return nil
    end

    -- Strip whitespace
    value = value:match("^%s*(.-)%s*$")

    -- Percentage
    local pct = value:match("^([%d%.%-]+)%%$")
    if pct then
        return (tonumber(pct) or 0) / 100 * referenceSize
    end

    -- Pixels
    local px = value:match("^([%d%.%-]+)px$")
    if px then
        return tonumber(px) or 0
    end

    -- Plain number
    local num = tonumber(value)
    if num then
        return num
    end

    return nil
end

--- Same as ResolveLengthOrNil but returns 0 instead of nil.
--- @param value string|nil The CSS value
--- @param referenceSize number The reference size for percentage resolution
--- @return number pixels
function LayoutUtils.ResolveLength(value, referenceSize)
    return LayoutUtils.ResolveLengthOrNil(value, referenceSize) or 0
end

--- Parse a CSS number (unitless + optional unit stripped). Returns 0 for non-numeric.
--- @param value string|nil
--- @return number
function LayoutUtils.ParseNumber(value)
    if not value then return 0 end
    local num = value:match("^([%d%.%-]+)")
    return tonumber(num) or 0
end

--- Parse an aspect-ratio value. Returns nil for "auto".
--- Accepts "16/9", "1.7777", etc.
--- @param value string|nil
--- @return number|nil ratio (width / height)
function LayoutUtils.ParseAspectRatio(value)
    if not value or value == "auto" then return nil end
    local w, h = value:match("^([%d%.]+)%s*/%s*([%d%.]+)$")
    if w and h then
        local hVal = tonumber(h)
        if hVal and hVal ~= 0 then
            return tonumber(w) / hVal
        end
        return nil
    end
    return tonumber(value)
end

--- Get a computed style with fallback to defaults.
--- @param styles table<string, string>
--- @param property string
--- @return string
function LayoutUtils.GetStyle(styles, property)
    return styles[property] or LayoutUtils.DEFAULTS[property] or ""
end

---------------------------------------------------------------------------
-- Shorthand Expansion
---------------------------------------------------------------------------

--- Expand a CSS padding/margin shorthand into four individual values.
--- @param value string The shorthand value (e.g., "10px 20px 30px 40px", "10px 20px", "10px")
--- @return string top, string right, string bottom, string left
function LayoutUtils.ExpandBoxShorthand(value)
    if not value or value == "" then
        return "0", "0", "0", "0"
    end

    local parts = {}
    for part in value:gmatch("%S+") do
        parts[#parts + 1] = part
    end

    if #parts == 1 then
        return parts[1], parts[1], parts[1], parts[1]
    elseif #parts == 2 then
        return parts[1], parts[2], parts[1], parts[2]
    elseif #parts == 3 then
        return parts[1], parts[2], parts[3], parts[2]
    else
        return parts[1], parts[2], parts[3], parts[4]
    end
end

--- Resolve padding for a DOM node into four pixel values.
--- Handles both shorthand "padding" and individual "padding-top", etc.
--- @param styles table<string, string>
--- @param refWidth number Reference width for percentage resolution
--- @param refHeight number Reference height for percentage resolution
--- @return number top, number right, number bottom, number left
function LayoutUtils.ResolvePadding(styles, refWidth, refHeight)
    local top, right, bottom, left

    -- Check shorthand first
    local shorthand = styles["padding"]
    if shorthand then
        local t, r, b, l = LayoutUtils.ExpandBoxShorthand(shorthand)
        top    = LayoutUtils.ResolveLength(t, refHeight)
        right  = LayoutUtils.ResolveLength(r, refWidth)
        bottom = LayoutUtils.ResolveLength(b, refHeight)
        left   = LayoutUtils.ResolveLength(l, refWidth)
    else
        top    = 0
        right  = 0
        bottom = 0
        left   = 0
    end

    -- Individual properties override shorthand
    if styles["padding-top"]    then top    = LayoutUtils.ResolveLength(styles["padding-top"],    refHeight) end
    if styles["padding-right"]  then right  = LayoutUtils.ResolveLength(styles["padding-right"],  refWidth)  end
    if styles["padding-bottom"] then bottom = LayoutUtils.ResolveLength(styles["padding-bottom"], refHeight) end
    if styles["padding-left"]   then left   = LayoutUtils.ResolveLength(styles["padding-left"],   refWidth)  end

    return top, right, bottom, left
end

--- Resolve margin for a DOM node into four pixel values.
--- @param styles table<string, string>
--- @param refWidth number Reference width for percentage resolution
--- @param refHeight number Reference height for percentage resolution
--- @return number top, number right, number bottom, number left
function LayoutUtils.ResolveMargin(styles, refWidth, refHeight)
    local top, right, bottom, left

    local shorthand = styles["margin"]
    if shorthand then
        local t, r, b, l = LayoutUtils.ExpandBoxShorthand(shorthand)
        top    = LayoutUtils.ResolveLength(t, refHeight)
        right  = LayoutUtils.ResolveLength(r, refWidth)
        bottom = LayoutUtils.ResolveLength(b, refHeight)
        left   = LayoutUtils.ResolveLength(l, refWidth)
    else
        top    = 0
        right  = 0
        bottom = 0
        left   = 0
    end

    if styles["margin-top"]    then top    = LayoutUtils.ResolveLength(styles["margin-top"],    refHeight) end
    if styles["margin-right"]  then right  = LayoutUtils.ResolveLength(styles["margin-right"],  refWidth)  end
    if styles["margin-bottom"] then bottom = LayoutUtils.ResolveLength(styles["margin-bottom"], refHeight) end
    if styles["margin-left"]   then left   = LayoutUtils.ResolveLength(styles["margin-left"],   refWidth)  end

    return top, right, bottom, left
end

---------------------------------------------------------------------------
-- Border Property Parsing
---------------------------------------------------------------------------

--- Parse a border side CSS value.
--- Format: "10px \"textures/border.dds\" true false"
--- Or: "10px textures/border.dds true false"
--- Returns: size (px), texturePath (string), tileH (bool), tileV (bool)
--- @param value string|nil
--- @return number|nil size
--- @return string|nil texturePath
--- @return boolean tileH
--- @return boolean tileV
function LayoutUtils.ParseBorderValue(value)
    if not value or value == "" or value == "none" then
        return nil, nil, false, false
    end

    -- Match: size "path" tileH tileV or size path tileH tileV
    local size, path, tH, tV

    -- Try quoted path first
    size, path, tH, tV = value:match('^([%d%.]+)px%s+"([^"]+)"%s+(%a+)%s+(%a+)')
    if not size then
        -- Try single-quoted path
        size, path, tH, tV = value:match("^([%d%.]+)px%s+'([^']+)'%s+(%a+)%s+(%a+)")
    end
    if not size then
        -- Try unquoted path (backward compat)
        size, path, tH, tV = value:match("^([%d%.]+)px%s+(%S+)%s+(%a+)%s+(%a+)")
    end

    if not size then
        return nil, nil, false, false
    end

    return tonumber(size), path, (tH == "true"), (tV == "true")
end

--- Parse the border sizes from computed styles.
--- Returns the border widths for each side.
--- @param styles table<string, string>
--- @return number top, number right, number bottom, number left
function LayoutUtils.ResolveBorderWidths(styles)
    local BORDER_PROPS = {
        "border-top", "border-right", "border-bottom", "border-left"
    }
    local CORNER_PROPS = {
        "border-top-left-corner", "border-top-right-corner",
        "border-bottom-right-corner", "border-bottom-left-corner"
    }

    local top, right, bottom, left = 0, 0, 0, 0

    -- Side borders
    local sideSize = LayoutUtils.ParseBorderValue(styles["border-top"])
    if sideSize then top = math.max(top, sideSize) end

    sideSize = LayoutUtils.ParseBorderValue(styles["border-right"])
    if sideSize then right = math.max(right, sideSize) end

    sideSize = LayoutUtils.ParseBorderValue(styles["border-bottom"])
    if sideSize then bottom = math.max(bottom, sideSize) end

    sideSize = LayoutUtils.ParseBorderValue(styles["border-left"])
    if sideSize then left = math.max(left, sideSize) end

    -- Corner borders contribute to adjacent sides
    local cornerSize = LayoutUtils.ParseBorderValue(styles["border-top-left-corner"])
    if cornerSize then
        top  = math.max(top, cornerSize)
        left = math.max(left, cornerSize)
    end

    cornerSize = LayoutUtils.ParseBorderValue(styles["border-top-right-corner"])
    if cornerSize then
        top   = math.max(top, cornerSize)
        right = math.max(right, cornerSize)
    end

    cornerSize = LayoutUtils.ParseBorderValue(styles["border-bottom-right-corner"])
    if cornerSize then
        bottom = math.max(bottom, cornerSize)
        right  = math.max(right, cornerSize)
    end

    cornerSize = LayoutUtils.ParseBorderValue(styles["border-bottom-left-corner"])
    if cornerSize then
        bottom = math.max(bottom, cornerSize)
        left   = math.max(left, cornerSize)
    end

    return top, right, bottom, left
end

---------------------------------------------------------------------------
-- Background Image Parsing
---------------------------------------------------------------------------

--- Parse a background-image CSS value.
--- Accepts: "textures/foo.dds", 'textures/foo.dds', textures/foo.dds, "none", none
--- Returns the file path string (without quotes) or nil.
--- @param value string|nil
--- @return string|nil path
function LayoutUtils.ParseBackgroundImage(value)
    if not value or value == "" or value == "none" then
        return nil
    end

    -- Strip quotes if present
    local path = value:match('^"([^"]*)"$') or value:match("^'([^']*)'$") or value
    if path == "none" then return nil end

    return path
end

--- Parse background-repeat into tileH, tileV booleans.
--- @param value string|nil
--- @return boolean tileH
--- @return boolean tileV
function LayoutUtils.ParseBackgroundRepeat(value)
    if not value or value == "no-repeat" then
        return false, false
    elseif value == "repeat-x" then
        return true, false
    elseif value == "repeat-y" then
        return false, true
    elseif value == "repeat" then
        return true, true
    end
    return false, false
end

---------------------------------------------------------------------------
-- Color Parsing
---------------------------------------------------------------------------

--- Parse a CSS color value into r, g, b (0-1 range).
--- Supports: hex (#rgb, #rrggbb), rgb(), named colors (basic set).
--- Returns nil if unrecognized.
--- @param value string|nil
--- @return number|nil r
--- @return number|nil g
--- @return number|nil b
function LayoutUtils.ParseColor(value)
    if not value or value == "" then return nil, nil, nil end

    value = value:match("^%s*(.-)%s*$")

    -- Hex color
    if value:sub(1, 1) == "#" then
        local hex = value:sub(2)
        if #hex == 3 then
            local r = tonumber(hex:sub(1, 1) .. hex:sub(1, 1), 16) / 255
            local g = tonumber(hex:sub(2, 2) .. hex:sub(2, 2), 16) / 255
            local b = tonumber(hex:sub(3, 3) .. hex:sub(3, 3), 16) / 255
            return r, g, b
        elseif #hex == 6 then
            local r = tonumber(hex:sub(1, 2), 16) / 255
            local g = tonumber(hex:sub(3, 4), 16) / 255
            local b = tonumber(hex:sub(5, 6), 16) / 255
            return r, g, b
        end
    end

    -- rgb(r, g, b) — values 0-255
    local r, g, b = value:match("^rgb%(%s*([%d%.]+)%s*,%s*([%d%.]+)%s*,%s*([%d%.]+)%s*%)$")
    if r then
        return (tonumber(r) or 0) / 255, (tonumber(g) or 0) / 255, (tonumber(b) or 0) / 255
    end

    -- Named colors (common set)
    local NAMED_COLORS = {
        black   = { 0, 0, 0 },
        white   = { 1, 1, 1 },
        red     = { 1, 0, 0 },
        green   = { 0, 0.502, 0 },
        blue    = { 0, 0, 1 },
        yellow  = { 1, 1, 0 },
        cyan    = { 0, 1, 1 },
        magenta = { 1, 0, 1 },
        gray    = { 0.502, 0.502, 0.502 },
        grey    = { 0.502, 0.502, 0.502 },
        orange  = { 1, 0.647, 0 },
        purple  = { 0.502, 0, 0.502 },
        transparent = { 0, 0, 0 },
    }

    local named = NAMED_COLORS[value:lower()]
    if named then
        return named[1], named[2], named[3]
    end

    return nil, nil, nil
end

---------------------------------------------------------------------------
-- Grid Template Parsing
---------------------------------------------------------------------------

--- @class AnglesUI.GridTrack
--- @field type "px"|"percent"|"fr"|"auto"
--- @field value number The numeric value (px, percent fraction, fr count)

--- Parse a grid-template-columns or grid-template-rows value.
--- Supports: lengths, percentages, fr units, auto, repeat(count, track-list).
--- @param value string|nil
--- @return AnglesUI.GridTrack[]
function LayoutUtils.ParseGridTemplate(value)
    if not value or value == "" or value == "none" then
        return {}
    end

    local tracks = {}

    -- Expand repeat() functions first
    local expanded = value:gsub("repeat%(%s*(%d+)%s*,%s*(.-)%s*%)", function(count, trackList)
        local n = tonumber(count) or 1
        local result = {}
        for _ = 1, n do
            result[#result + 1] = trackList
        end
        return table.concat(result, " ")
    end)

    -- Parse individual track values
    for token in expanded:gmatch("%S+") do
        local track = LayoutUtils.ParseGridTrackToken(token)
        if track then
            tracks[#tracks + 1] = track
        end
    end

    return tracks
end

--- Parse a single grid track token.
--- @param token string
--- @return AnglesUI.GridTrack|nil
function LayoutUtils.ParseGridTrackToken(token)
    -- fr unit
    local fr = token:match("^([%d%.]+)fr$")
    if fr then
        return { type = "fr", value = tonumber(fr) or 1 }
    end

    -- percentage
    local pct = token:match("^([%d%.]+)%%$")
    if pct then
        return { type = "percent", value = tonumber(pct) or 0 }
    end

    -- pixels
    local px = token:match("^([%d%.]+)px$")
    if px then
        return { type = "px", value = tonumber(px) or 0 }
    end

    -- auto
    if token == "auto" then
        return { type = "auto", value = 0 }
    end

    -- Plain number (treat as px)
    local num = tonumber(token)
    if num then
        return { type = "px", value = num }
    end

    return nil
end

--- Resolve grid tracks into pixel sizes.
--- @param tracks AnglesUI.GridTrack[]
--- @param availableSpace number Total available space in pixels
--- @param autoSizes number[]|nil Per-track auto content sizes
--- @return number[] sizes Resolved pixel sizes for each track
---@nodiscard
function LayoutUtils.ResolveGridTracks(tracks, availableSpace, autoSizes)
    local sizes = {}
    local totalFixed = 0
    local totalFr = 0

    -- First pass: resolve fixed sizes and count fr units
    for i, track in ipairs(tracks) do
        if track.type == "px" then
            sizes[i] = track.value
            totalFixed = totalFixed + track.value
        elseif track.type == "percent" then
            sizes[i] = track.value / 100 * availableSpace
            totalFixed = totalFixed + sizes[i]
        elseif track.type == "auto" then
            local autoSize = (autoSizes and autoSizes[i]) or 0
            sizes[i] = autoSize
            totalFixed = totalFixed + autoSize
        elseif track.type == "fr" then
            sizes[i] = 0
            totalFr = totalFr + track.value
        end
    end

    -- Second pass: distribute remaining space to fr tracks
    if totalFr > 0 then
        local remaining = math.max(0, availableSpace - totalFixed)
        local perFr = remaining / totalFr
        for i, track in ipairs(tracks) do
            if track.type == "fr" then
                sizes[i] = track.value * perFr
            end
        end
    end

    return sizes
end

---------------------------------------------------------------------------
-- Grid Placement Parsing
---------------------------------------------------------------------------

--- Parse a grid-column/grid-row shorthand value.
--- Format: "start / end" or "start" (end = auto).
--- @param value string|nil
--- @return string startVal, string endVal
---@nodiscard
function LayoutUtils.ParseGridLineShorthand(value)
    if not value or value == "" or value == "auto" then
        return "auto", "auto"
    end

    local startVal, endVal = value:match("^(.-)%s*/%s*(.-)$")
    if startVal then
        return startVal:match("^%s*(.-)%s*$"), endVal:match("^%s*(.-)%s*$")
    end

    return value:match("^%s*(.-)%s*$"), "auto"
end

--- Parse a grid line value (for grid-column-start, etc.).
--- Returns: line number (1-based) or nil for auto, and span count.
--- @param value string|nil
--- @return integer|nil lineNumber
--- @return integer|nil spanCount
---@nodiscard
function LayoutUtils.ParseGridLine(value)
    if not value or value == "" or value == "auto" then
        return nil, nil
    end

    -- "span N"
    local spanCount = value:match("^span%s+(%d+)$")
    if spanCount then
        return nil, tonumber(spanCount)
    end

    -- Line number
    local num = tonumber(value)
    if num then
        return num, nil
    end

    return nil, nil
end

---------------------------------------------------------------------------
-- Text Alignment Mapping
---------------------------------------------------------------------------

--- Map CSS text-align values to OpenMW UI alignment constants.
--- @param value string|nil CSS value ("start", "center", "end")
--- @return string alignment "Start"|"Center"|"End"
---@nodiscard
function LayoutUtils.MapTextAlignH(value)
    if value == "center" then return "Center" end
    if value == "end"    then return "End" end
    return "Start"
end

--- Map CSS vertical-align values to OpenMW UI alignment constants.
--- @param value string|nil CSS value ("top", "middle", "bottom")
--- @return string alignment "Start"|"Center"|"End"
---@nodiscard
function LayoutUtils.MapVerticalAlign(value)
    if value == "middle" then return "Center" end
    if value == "bottom" then return "End" end
    return "Start"
end

return LayoutUtils
