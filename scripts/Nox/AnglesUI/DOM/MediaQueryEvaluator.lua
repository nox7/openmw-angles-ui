--- AnglesUI Media Query Evaluator.
--- Evaluates CSS @media rule preludes against the current screen size.
--- The screen size is obtained from OpenMW's UI layer size:
---   ui.layers[ui.layers.indexOf(LAYER_NAME)].size  → Vector2
---
--- Supported media features:
---   - (max-width: Npx)
---   - (min-width: Npx)
---   - (max-height: Npx)
---   - (min-height: Npx)
---   - (width: Npx)
---   - (height: Npx)
---   - (width <= N), (width >= N), (width < N), (width > N)
---   - Compound: (min-width: 400px) and (max-width: 800px)

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

--- @class AnglesUI.MediaQueryEvaluator
--- @field private _screenWidth number Current screen width in pixels
--- @field private _screenHeight number Current screen height in pixels
local MediaQueryEvaluator = {}
MediaQueryEvaluator.__index = MediaQueryEvaluator

---------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------

--- Create a new media query evaluator.
--- @param screenWidth number Screen width in pixels
--- @param screenHeight number Screen height in pixels
--- @return AnglesUI.MediaQueryEvaluator
---@nodiscard
function MediaQueryEvaluator.New(screenWidth, screenHeight)
    local self = setmetatable({}, MediaQueryEvaluator)
    self._screenWidth = screenWidth or 0
    self._screenHeight = screenHeight or 0
    return self
end

--- Update the screen dimensions.
--- @param screenWidth number
--- @param screenHeight number
function MediaQueryEvaluator:SetScreenSize(screenWidth, screenHeight)
    self._screenWidth = screenWidth
    self._screenHeight = screenHeight
end

--- @return number width
--- @return number height
function MediaQueryEvaluator:GetScreenSize()
    return self._screenWidth, self._screenHeight
end

---------------------------------------------------------------------------
-- Parsing helpers
---------------------------------------------------------------------------

--- Trim whitespace.
--- @param s string
--- @return string
local function trim(s)
    return s:match("^%s*(.-)%s*$")
end

--- Parse a numeric value, stripping "px" suffix if present.
--- @param s string
--- @return number?
local function parseNumber(s)
    s = trim(s)
    s = s:gsub("px$", "")
    return tonumber(s)
end

--- Evaluate a single media feature condition like "(max-width: 600px)".
--- @param condition string The condition text (without outer parens)
--- @param screenW number
--- @param screenH number
--- @return boolean
local function evaluateCondition(condition, screenW, screenH)
    condition = trim(condition)

    -- Remove surrounding parentheses if still present
    if condition:sub(1, 1) == "(" and condition:sub(-1) == ")" then
        condition = condition:sub(2, -2)
        condition = trim(condition)
    end

    -- Try "property: value" syntax (e.g. "max-width: 600px")
    local prop, value = condition:match("^([%w%-]+)%s*:%s*(.+)$")
    if prop and value then
        prop = trim(prop):lower()
        local num = parseNumber(value)
        if not num then return false end

        if prop == "max-width" then return screenW <= num
        elseif prop == "min-width" then return screenW >= num
        elseif prop == "max-height" then return screenH <= num
        elseif prop == "min-height" then return screenH >= num
        elseif prop == "width" then return screenW == num
        elseif prop == "height" then return screenH == num
        end

        return false
    end

    -- Try comparison syntax (e.g. "width <= 600px", "width >= 400")
    local feature, op, numStr = condition:match("^([%w%-]+)%s*([<>=!]+)%s*(.+)$")
    if feature and op and numStr then
        feature = trim(feature):lower()
        local num = parseNumber(numStr)
        if not num then return false end

        local actual = nil
        if feature == "width" then actual = screenW
        elseif feature == "height" then actual = screenH
        end

        if actual == nil then return false end

        if op == "<=" then return actual <= num
        elseif op == ">=" then return actual >= num
        elseif op == "<" then return actual < num
        elseif op == ">" then return actual > num
        elseif op == "=" or op == "==" then return actual == num
        end

        return false
    end

    return false
end

---------------------------------------------------------------------------
-- Public evaluation
---------------------------------------------------------------------------

--- Evaluate a @media prelude string.
--- Supports 'and' / 'or' / ',' (comma = or) compounds.
--- @param prelude string The raw media query prelude (e.g. "(max-width: 600px)")
--- @return boolean
function MediaQueryEvaluator:Evaluate(prelude)
    if not prelude or #prelude == 0 then return true end

    prelude = trim(prelude)

    -- Split on comma (each comma-group is an OR branch)
    local orGroups = {}
    local depth = 0
    local current = ""
    for i = 1, #prelude do
        local ch = prelude:sub(i, i)
        if ch == "(" then depth = depth + 1
        elseif ch == ")" then depth = depth - 1 end

        if ch == "," and depth == 0 then
            orGroups[#orGroups + 1] = trim(current)
            current = ""
        else
            current = current .. ch
        end
    end
    orGroups[#orGroups + 1] = trim(current)

    -- Any OR group matching = true
    for _, group in ipairs(orGroups) do
        if self:_evaluateAndGroup(group) then
            return true
        end
    end

    return false
end

--- Evaluate an "and"-joined group.
--- @private
--- @param group string
--- @return boolean
function MediaQueryEvaluator:_evaluateAndGroup(group)
    -- Split on " and " (case-insensitive)
    local parts = {}
    local remaining = group

    while true do
        -- Find " and " (case insensitive) at depth 0
        local andPos = nil
        local depth = 0
        for i = 1, #remaining do
            local ch = remaining:sub(i, i)
            if ch == "(" then depth = depth + 1
            elseif ch == ")" then depth = depth - 1
            elseif depth == 0 and i + 4 <= #remaining then
                local sub = remaining:sub(i, i + 4):lower()
                if sub == " and " then
                    andPos = i
                    break
                end
            end
        end

        if andPos then
            parts[#parts + 1] = trim(remaining:sub(1, andPos - 1))
            remaining = remaining:sub(andPos + 5)
        else
            parts[#parts + 1] = trim(remaining)
            break
        end
    end

    -- All parts must match for AND
    for _, part in ipairs(parts) do
        if not evaluateCondition(part, self._screenWidth, self._screenHeight) then
            return false
        end
    end

    return true
end

--- Create an evaluator function suitable for passing to CssCascade.
--- @return fun(prelude: string): boolean
function MediaQueryEvaluator:CreateEvaluatorFunc()
    return function(prelude)
        return self:Evaluate(prelude)
    end
end

return MediaQueryEvaluator
