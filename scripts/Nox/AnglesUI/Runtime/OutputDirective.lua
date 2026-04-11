--- AnglesUI Output Directive Runtime.
--- Evaluates `{{ expression }}` output directives within the DOM tree,
--- resolving them to text values using the current evaluation context.
---
--- Output directives can contain any expression supported by the
--- ExpressionEvaluator, including ternary statements, function calls,
--- property access, and so on.

local ExpressionEvaluator = require("scripts.Nox.AnglesUI.Parser.ExpressionEvaluator")
local DomNode             = require("scripts.Nox.AnglesUI.DOM.DomNode")

local DomNodeKind = DomNode.DomNodeKind

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

--- @class AnglesUI.OutputDirective
local OutputDirective = {}

---------------------------------------------------------------------------
-- Evaluate a single output directive node
---------------------------------------------------------------------------

--- Evaluate a single {{ expression }} DomNode and return the text value.
--- @param domNode AnglesUI.DomNode An Output-kind DomNode
--- @param context table<string, any> The evaluation scope
--- @return string text The evaluated text (tostring of result, or "")
---@nodiscard
function OutputDirective.Evaluate(domNode, context)
    if domNode.kind ~= DomNodeKind.Output then
        return ""
    end

    --- @type AnglesUI.OutputDirectiveNode
    local htmlNode = domNode.htmlNode
    local expression = htmlNode.expression

    if not expression or #expression == 0 then
        return ""
    end

    local result = ExpressionEvaluator.Evaluate(expression, context)
    if result == nil then
        return ""
    end

    return tostring(result)
end

---------------------------------------------------------------------------
-- Resolve all output directives in a tree
---------------------------------------------------------------------------

--- Walk a DOM tree and evaluate all output directive nodes, storing
--- the resolved text on each node for later use by the transpiler.
---
--- The resolved text is stored on `domNode.resolvedText` (a custom field)
--- so the transpiler can read it when converting to OpenMW UI elements.
---
--- @param root AnglesUI.DomNode
--- @param context table<string, any>
function OutputDirective.ResolveTree(root, context)
    root:Walk(function(node)
        if node.kind == DomNodeKind.Output then
            node.resolvedText = OutputDirective.Evaluate(node, context)
        end
        return false -- continue walking
    end)
end

return OutputDirective
