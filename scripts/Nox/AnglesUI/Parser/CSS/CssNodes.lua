--- AnglesUI CSS AST Node definitions.
--- Provides node type enums and factory functions for the CSS abstract syntax tree.

---------------------------------------------------------------------------
-- Enums
---------------------------------------------------------------------------

--- @enum AnglesUI.CssNodeType
local CssNodeType = {
    Stylesheet  = "Stylesheet",
    Rule        = "Rule",
    Declaration = "Declaration",
    AtRule      = "AtRule",
}

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

--- @class AnglesUI.CssNodes
--- @field CssNodeType AnglesUI.CssNodeType
local CssNodes = {
    CssNodeType = CssNodeType,
}

---------------------------------------------------------------------------
-- Node type definitions (for documentation / type checking)
---------------------------------------------------------------------------

--- @class AnglesUI.CssStylesheet
--- @field type "Stylesheet"
--- @field rules (AnglesUI.CssRule | AnglesUI.CssAtRule)[]

--- @class AnglesUI.CssRule
--- @field type "Rule"
--- @field selectorText string Raw selector text (e.g. "mw-root .foo > mw-text:hover")
--- @field selectors any[] Parsed selector structures (populated by the selector engine)
--- @field declarations AnglesUI.CssDeclaration[]
--- @field nestedRules AnglesUI.CssRule[] Nested child rules
--- @field parent AnglesUI.CssRule? Parent rule (for nested rules)
--- @field line integer
--- @field column integer

--- @class AnglesUI.CssDeclaration
--- @field type "Declaration"
--- @field property string CSS property name (e.g. "padding-top", "--my-var")
--- @field value string Raw value text (e.g. "10px 20px", "var(--color)")
--- @field line integer
--- @field column integer

--- @class AnglesUI.CssAtRule
--- @field type "AtRule"
--- @field name string At-rule keyword (e.g. "media", "container")
--- @field prelude string Raw condition/prelude text (e.g. "(max-width: 600px)")
--- @field rules (AnglesUI.CssRule | AnglesUI.CssAtRule)[] Rules inside the at-rule block
--- @field line integer
--- @field column integer

---------------------------------------------------------------------------
-- Factory functions
---------------------------------------------------------------------------

--- Create a top-level stylesheet container.
--- @return AnglesUI.CssStylesheet
---@nodiscard
function CssNodes.CreateStylesheet()
    return {
        type  = CssNodeType.Stylesheet,
        rules = {},
    }
end

--- Create a CSS rule (selector + declarations + optional nested rules).
--- @param selectorText string Raw selector text
--- @param line? integer Source line
--- @param column? integer Source column
--- @return AnglesUI.CssRule
---@nodiscard
function CssNodes.CreateRule(selectorText, line, column)
    return {
        type         = CssNodeType.Rule,
        selectorText = selectorText,
        selectors    = {},
        declarations = {},
        nestedRules  = {},
        parent       = nil,
        line         = line or 0,
        column       = column or 0,
    }
end

--- Create a CSS declaration (property: value).
--- @param property string The property name
--- @param value string The raw value text
--- @param line? integer Source line
--- @param column? integer Source column
--- @return AnglesUI.CssDeclaration
---@nodiscard
function CssNodes.CreateDeclaration(property, value, line, column)
    return {
        type     = CssNodeType.Declaration,
        property = property,
        value    = value,
        line     = line or 0,
        column   = column or 0,
    }
end

--- Create a CSS at-rule (@media, @container, etc.).
--- @param name string The at-rule keyword (without @)
--- @param prelude string Raw prelude/condition text
--- @param line? integer Source line
--- @param column? integer Source column
--- @return AnglesUI.CssAtRule
---@nodiscard
function CssNodes.CreateAtRule(name, prelude, line, column)
    return {
        type    = CssNodeType.AtRule,
        name    = name,
        prelude = prelude,
        rules   = {},
        line    = line or 0,
        column  = column or 0,
    }
end

return CssNodes
