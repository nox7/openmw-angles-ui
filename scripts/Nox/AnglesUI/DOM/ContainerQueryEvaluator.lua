--- AnglesUI Container Query Evaluator.
--- Evaluates CSS @container rule preludes against the nearest container
--- ancestor (or named container) of a DOM node.
---
--- A DOM node is a container when it has `container-type: size` in its
--- computed styles. It may optionally have a `container-name`.
---
--- Supported syntax:
---   @container (width <= 600px) { }
---   @container (min-width: 400px) { }
---   @container name-of-container (width <= 600px) { }

local DomNode = require("scripts.Nox.AnglesUI.DOM.DomNode")

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

--- @class AnglesUI.ContainerQueryEvaluator
local ContainerQueryEvaluator = {}

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

--- Parse the container prelude to extract the optional name and condition.
--- @param prelude string
--- @return string? containerName (nil if unnamed)
--- @return string condition The parenthesised condition part
local function parsePrelude(prelude)
    prelude = trim(prelude)

    -- Find the first '('
    local parenStart = prelude:find("%(")
    if not parenStart then
        return nil, prelude
    end

    local beforeParen = trim(prelude:sub(1, parenStart - 1))
    local conditionPart = prelude:sub(parenStart)

    if #beforeParen > 0 then
        return beforeParen, conditionPart
    end

    return nil, conditionPart
end

--- Evaluate a single container condition against container dimensions.
--- @param condition string e.g. "(width <= 600px)" or "(min-width: 400px)"
--- @param containerW number Container width in pixels
--- @param containerH number Container height in pixels
--- @return boolean
local function evaluateCondition(condition, containerW, containerH)
    condition = trim(condition)

    -- Strip outer parens
    if condition:sub(1, 1) == "(" and condition:sub(-1) == ")" then
        condition = condition:sub(2, -2)
        condition = trim(condition)
    end

    -- Try "property: value" syntax (e.g. "min-width: 400px")
    local prop, value = condition:match("^([%w%-]+)%s*:%s*(.+)$")
    if prop and value then
        prop = trim(prop):lower()
        local num = parseNumber(value)
        if not num then return false end

        if prop == "max-width" then return containerW <= num
        elseif prop == "min-width" then return containerW >= num
        elseif prop == "max-height" then return containerH <= num
        elseif prop == "min-height" then return containerH >= num
        elseif prop == "width" then return containerW == num
        elseif prop == "height" then return containerH == num
        end
        return false
    end

    -- Try comparison syntax (e.g. "width <= 600")
    local feature, op, numStr = condition:match("^([%w%-]+)%s*([<>=!]+)%s*(.+)$")
    if feature and op and numStr then
        feature = trim(feature):lower()
        local num = parseNumber(numStr)
        if not num then return false end

        local actual = nil
        if feature == "width" then actual = containerW
        elseif feature == "height" then actual = containerH
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

--- Evaluate a full condition string, handling 'and' compounds.
--- @param conditionStr string
--- @param containerW number
--- @param containerH number
--- @return boolean
local function evaluateFullCondition(conditionStr, containerW, containerH)
    conditionStr = trim(conditionStr)

    -- Split on " and "
    local parts = {}
    local remaining = conditionStr

    while true do
        local depth = 0
        local andPos = nil
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

    for _, part in ipairs(parts) do
        if not evaluateCondition(part, containerW, containerH) then
            return false
        end
    end

    return true
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

--- Evaluate a @container prelude against a DOM node's nearest container.
--- @param prelude string The @container prelude (e.g. "my-container (width <= 600px)")
--- @param domNode AnglesUI.DomNode The element the container query applies to
--- @return boolean
function ContainerQueryEvaluator.Evaluate(prelude, domNode)
    local containerName, conditionStr = parsePrelude(prelude)

    -- Find the relevant container ancestor
    local container = nil
    if containerName then
        container = domNode:FindNamedContainer(containerName)
    else
        container = domNode:FindNearestContainer()
    end

    if not container then
        return false
    end

    -- Get container dimensions from layout data or computed size
    local w = 0
    local h = 0
    if container.layoutData then
        w = container.layoutData.width or 0
        h = container.layoutData.height or 0
    end
    -- Fallback: try computed styles for explicit width/height
    if w == 0 and container.computedStyles["width"] then
        w = parseNumber(container.computedStyles["width"]) or 0
    end
    if h == 0 and container.computedStyles["height"] then
        h = parseNumber(container.computedStyles["height"]) or 0
    end

    return evaluateFullCondition(conditionStr, w, h)
end

--- Create an evaluator function suitable for passing to CssCascade.
--- @return fun(prelude: string, node: AnglesUI.DomNode): boolean
function ContainerQueryEvaluator.CreateEvaluatorFunc()
    return function(prelude, node)
        return ContainerQueryEvaluator.Evaluate(prelude, node)
    end
end

return ContainerQueryEvaluator
