--- AnglesUI CSS Variable Resolver.
--- Manages CSS custom properties (--var-name) and resolves var() references
--- in declaration values. Supports:
---   - Collecting variable declarations from CSS rules
---   - External (programmatic) variable injection
---   - var(--name) and var(--name, fallback) syntax
---   - Nested var() references in fallbacks
---   - Scoped variable inheritance (child inherits parent variables)

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

--- @class AnglesUI.CssVariableResolver
--- @field private _variables table<string, string> Global/root variable store
local CssVariableResolver = {}
CssVariableResolver.__index = CssVariableResolver

---------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------

--- Create a new variable resolver instance.
--- @param initialVars? table<string, string> Optional initial variables
--- @return AnglesUI.CssVariableResolver
---@nodiscard
function CssVariableResolver.New(initialVars)
    local self = setmetatable({}, CssVariableResolver)
    self._variables = {}
    if initialVars then
        for k, v in pairs(initialVars) do
            self._variables[k] = v
        end
    end
    return self
end

---------------------------------------------------------------------------
-- Variable management
---------------------------------------------------------------------------

--- Set a CSS variable value.
--- @param name string Variable name including the -- prefix (e.g. "--primary-color")
--- @param value string The value to assign
function CssVariableResolver:Set(name, value)
    self._variables[name] = value
end

--- Get a CSS variable value.
--- @param name string Variable name including the -- prefix
--- @return string? value The value, or nil if not defined
function CssVariableResolver:Get(name)
    return self._variables[name]
end

--- Remove a CSS variable.
--- @param name string Variable name including the -- prefix
function CssVariableResolver:Remove(name)
    self._variables[name] = nil
end

--- Set multiple variables at once from a table.
--- @param vars table<string, string> Table of name→value pairs
function CssVariableResolver:SetAll(vars)
    for k, v in pairs(vars) do
        self._variables[k] = v
    end
end

--- Get all current variables as a shallow copy.
--- @return table<string, string>
function CssVariableResolver:GetAll()
    local copy = {}
    for k, v in pairs(self._variables) do
        copy[k] = v
    end
    return copy
end

---------------------------------------------------------------------------
-- Collecting variables from CSS declarations
---------------------------------------------------------------------------

--- Scan a list of CSS declarations and register any custom property
--- declarations (property names starting with "--") into this resolver.
--- @param declarations AnglesUI.CssDeclaration[]
function CssVariableResolver:CollectFromDeclarations(declarations)
    for _, decl in ipairs(declarations) do
        if decl.property:sub(1, 2) == "--" then
            self._variables[decl.property] = decl.value
        end
    end
end

--- Recursively collect variables from an entire stylesheet.
--- Processes all rules (including nested) and at-rules.
--- @param stylesheet AnglesUI.CssStylesheet
function CssVariableResolver:CollectFromStylesheet(stylesheet)
    self:_collectFromRuleList(stylesheet.rules)
end

--- @private
--- @param rules (AnglesUI.CssRule | AnglesUI.CssAtRule)[]
function CssVariableResolver:_collectFromRuleList(rules)
    for _, rule in ipairs(rules) do
        if rule.type == "Rule" then
            --- @cast rule AnglesUI.CssRule
            self:CollectFromDeclarations(rule.declarations)
            if rule.nestedRules then
                self:_collectFromRuleList(rule.nestedRules)
            end
        elseif rule.type == "AtRule" then
            --- @cast rule AnglesUI.CssAtRule
            if rule.rules then
                self:_collectFromRuleList(rule.rules)
            end
        end
    end
end

---------------------------------------------------------------------------
-- Scoped variable contexts
---------------------------------------------------------------------------

--- Create a child resolver that inherits all current variables but can
--- override them without affecting the parent. Useful for per-element
--- scoped variable resolution.
--- @return AnglesUI.CssVariableResolver child
function CssVariableResolver:CreateChild()
    local child = CssVariableResolver.New()
    -- Copy parent variables (child inherits)
    for k, v in pairs(self._variables) do
        child._variables[k] = v
    end
    return child
end

---------------------------------------------------------------------------
-- var() resolution
---------------------------------------------------------------------------

--- Resolve all var() references in a CSS value string.
--- Supports nested var() in fallback values.
--- @param value string The raw CSS value possibly containing var() calls
--- @param scopeVars? table<string, string> Optional per-element scope overrides
--- @return string resolved The value with all var() references resolved
function CssVariableResolver:Resolve(value, scopeVars)
    -- Quick check: if no "var(" present, return as-is
    if not value:find("var(", 1, true) then
        return value
    end

    return self:_resolveVarRefs(value, scopeVars, 0)
end

--- Maximum recursion depth to prevent infinite loops in circular references.
local MAX_RESOLVE_DEPTH = 16

--- @private
--- @param value string
--- @param scopeVars? table<string, string>
--- @param depth integer Current recursion depth
--- @return string
function CssVariableResolver:_resolveVarRefs(value, scopeVars, depth)
    if depth > MAX_RESOLVE_DEPTH then
        return value
    end

    local result = ""
    local pos = 1
    local len = #value

    while pos <= len do
        -- Look for "var("
        local varStart = value:find("var(", pos, true)
        if not varStart then
            result = result .. value:sub(pos)
            break
        end

        -- Append everything before this var(
        result = result .. value:sub(pos, varStart - 1)

        -- Find the matching closing paren, respecting nesting
        local parenStart = varStart + 4 -- position after "var("
        local parenDepth = 1
        local scanPos = parenStart

        while scanPos <= len and parenDepth > 0 do
            local ch = value:sub(scanPos, scanPos)
            if ch == "(" then
                parenDepth = parenDepth + 1
            elseif ch == ")" then
                parenDepth = parenDepth - 1
            end
            if parenDepth > 0 then
                scanPos = scanPos + 1
            end
        end

        local innerContent = value:sub(parenStart, scanPos - 1)
        pos = scanPos + 1 -- skip past the closing )

        -- Parse the inner content: var-name [, fallback]
        local varName, fallback = self:_parseVarArgs(innerContent)
        varName = varName:match("^%s*(.-)%s*$") -- trim

        -- Look up the variable
        local resolved = nil
        if scopeVars then
            resolved = scopeVars[varName]
        end
        if resolved == nil then
            resolved = self._variables[varName]
        end

        if resolved then
            -- Recursively resolve in case the value itself contains var()
            resolved = self:_resolveVarRefs(resolved, scopeVars, depth + 1)
            result = result .. resolved
        elseif fallback then
            -- Resolve the fallback value
            fallback = self:_resolveVarRefs(fallback, scopeVars, depth + 1)
            result = result .. fallback
        else
            -- No value and no fallback — leave empty string
            result = result .. ""
        end
    end

    return result
end

--- Parse the arguments inside a var() call. Separates the variable name
--- from the optional fallback value. The fallback is everything after the
--- first comma (which may itself contain commas or nested var() calls).
--- @private
--- @param inner string The content between var( and )
--- @return string varName
--- @return string? fallback
function CssVariableResolver:_parseVarArgs(inner)
    -- Find the first comma that is not inside a nested function call
    local depth = 0
    for i = 1, #inner do
        local ch = inner:sub(i, i)
        if ch == "(" then
            depth = depth + 1
        elseif ch == ")" then
            depth = depth - 1
        elseif ch == "," and depth == 0 then
            local varName  = inner:sub(1, i - 1)
            local fallback = inner:sub(i + 1)
            return varName:match("^%s*(.-)%s*$"), fallback:match("^%s*(.-)%s*$")
        end
    end

    return inner:match("^%s*(.-)%s*$"), nil
end

---------------------------------------------------------------------------
-- Utility: check if a value contains var() references
---------------------------------------------------------------------------

--- Check whether a CSS value string contains any var() references.
--- @param value string
--- @return boolean
---@nodiscard
function CssVariableResolver.ContainsVar(value)
    return value:find("var(", 1, true) ~= nil
end

return CssVariableResolver
