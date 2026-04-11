--- AnglesUI Directive Evaluator.
--- Evaluates @if/@else if/@else and @for directives at runtime, producing
--- concrete DomNode children from the directive templates and the current
--- evaluation context.
---
--- @if — evaluates condition; when true, builds children from the if-block.
---        Falls through to @else if / @else branches when false.
--- @for — iterates `for (x in y)`, cloning template children per iteration
---        with scoped context containing the iterator variable and $index.

local ExpressionEvaluator = require("scripts.Nox.AnglesUI.Parser.ExpressionEvaluator")
local HtmlNodes           = require("scripts.Nox.AnglesUI.Parser.HTML.HtmlNodes")
local DomNode             = require("scripts.Nox.AnglesUI.DOM.DomNode")
local DomTreeBuilder      = require("scripts.Nox.AnglesUI.DOM.DomTreeBuilder")

local DomNodeKind = DomNode.DomNodeKind
local NodeType    = HtmlNodes.NodeType

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

--- @class AnglesUI.DirectiveEvaluator
local DirectiveEvaluator = {}

---------------------------------------------------------------------------
-- Forward declarations
---------------------------------------------------------------------------

--- Forward-declared: evaluates a list of DomNode children, expanding any
--- directives encountered. Returns the flattened list of concrete nodes.
--- @type fun(children: AnglesUI.DomNode[], context: table<string, any>, parentDom: AnglesUI.DomNode): AnglesUI.DomNode[]
local evaluateChildren

---------------------------------------------------------------------------
-- @if directive evaluation
---------------------------------------------------------------------------

--- Evaluate an @if directive node. Tests the condition; if true, returns
--- the expanded children of the if-block. Otherwise, tries each @else if
--- branch and finally the @else branch. Returns an empty table if no
--- branch matches.
--- @param domNode AnglesUI.DomNode The @if directive DomNode
--- @param context table<string, any> The current evaluation scope
--- @return AnglesUI.DomNode[] expandedNodes Concrete nodes to insert in place of the directive
local function evaluateIfDirective(domNode, context)
    --- @type AnglesUI.IfDirectiveNode
    local htmlNode = domNode.htmlNode

    -- Test the @if condition
    local condResult = ExpressionEvaluator.Evaluate(htmlNode.condition, context)
    if condResult then
        return evaluateChildren(domNode.children, context, domNode.parent)
    end

    -- Test @else if branches
    if htmlNode.elseIfBranches then
        for i = 1, #htmlNode.elseIfBranches do
            local branch = htmlNode.elseIfBranches[i]
            local branchResult = ExpressionEvaluator.Evaluate(branch.condition, context)
            if branchResult then
                -- Build DomNodes from the branch's HTML children
                local branchNodes = DirectiveEvaluator.BuildFromHtmlChildren(
                    branch.children, context, domNode.parent
                )
                return branchNodes
            end
        end
    end

    -- Test @else branch
    if htmlNode.elseBranch then
        local elseNodes = DirectiveEvaluator.BuildFromHtmlChildren(
            htmlNode.elseBranch.children, context, domNode.parent
        )
        return elseNodes
    end

    return {}
end

---------------------------------------------------------------------------
-- @for directive evaluation
---------------------------------------------------------------------------

--- Evaluate a @for directive node. Iterates over the iterable expression
--- and clones the template children for each iteration with a scoped context.
--- @param domNode AnglesUI.DomNode The @for directive DomNode
--- @param context table<string, any> The current evaluation scope
--- @return AnglesUI.DomNode[] expandedNodes Concrete nodes for all iterations
local function evaluateForDirective(domNode, context)
    --- @type AnglesUI.ForDirectiveNode
    local htmlNode = domNode.htmlNode

    -- Evaluate the iterable expression
    local iterable = ExpressionEvaluator.Evaluate(htmlNode.iterableExpression, context)
    if type(iterable) ~= "table" then
        return {}
    end

    local iteratorName = htmlNode.iteratorName
    local templateChildren = htmlNode.children
    local results = {}

    -- Iterate over the table (ipairs for array-like tables)
    local index = 0
    for _, item in ipairs(iterable) do
        -- Create scoped context for this iteration
        local iterContext = setmetatable({
            [iteratorName] = item,
            ["$index"] = index,
        }, { __index = context })

        -- Build fresh DomNodes from the HTML template children
        local iterNodes = DirectiveEvaluator.BuildFromHtmlChildren(
            templateChildren, iterContext, domNode.parent
        )

        -- Recursively evaluate any nested directives in the cloned nodes
        local expanded = evaluateChildren(iterNodes, iterContext, domNode.parent)

        for j = 1, #expanded do
            results[#results + 1] = expanded[j]
        end

        index = index + 1
    end

    return results
end

---------------------------------------------------------------------------
-- Build DomNodes from raw HTML AST children
---------------------------------------------------------------------------

--- Build DomNodes from a list of HTML AST children. Used when we need to
--- instantiate nodes from @else if, @else, or @for template branches that
--- were stored as raw HTML AST rather than pre-built DomNodes.
--- @param htmlChildren AnglesUI.BaseNode[] HTML AST nodes
--- @param context table<string, any> Evaluation context
--- @param parentDom AnglesUI.DomNode? Parent to set on built nodes
--- @return AnglesUI.DomNode[]
function DirectiveEvaluator.BuildFromHtmlChildren(htmlChildren, context, parentDom)
    if not htmlChildren or #htmlChildren == 0 then
        return {}
    end

    local depth = parentDom and (parentDom.depth + 1) or 0
    local nodes = {}

    for i = 1, #htmlChildren do
        local htmlChild = htmlChildren[i]
        local domNode = DirectiveEvaluator.BuildDomNode(htmlChild, parentDom, depth)
        if domNode then
            nodes[#nodes + 1] = domNode
        end
    end

    return nodes
end

--- Build a single DomNode from an HTML AST node.
--- @param htmlNode AnglesUI.BaseNode
--- @param parentDom AnglesUI.DomNode?
--- @param depth integer
--- @return AnglesUI.DomNode?
function DirectiveEvaluator.BuildDomNode(htmlNode, parentDom, depth)
    if htmlNode.type == NodeType.Element then
        --- @cast htmlNode AnglesUI.ElementNode
        local domNode = DomNode.FromElement(htmlNode, parentDom, depth)
        -- Recursively build children
        if htmlNode.children then
            for _, child in ipairs(htmlNode.children) do
                local childDom = DirectiveEvaluator.BuildDomNode(child, domNode, depth + 1)
                if childDom then
                    domNode:AppendChild(childDom)
                end
            end
        end
        return domNode

    elseif htmlNode.type == NodeType.Text then
        --- @cast htmlNode AnglesUI.TextNode
        return DomNode.FromText(htmlNode, parentDom, depth)

    elseif htmlNode.type == NodeType.Output then
        --- @cast htmlNode AnglesUI.OutputDirectiveNode
        return DomNode.FromOutput(htmlNode, parentDom, depth)

    elseif htmlNode.type == NodeType.IfDirective then
        --- @cast htmlNode AnglesUI.IfDirectiveNode
        local domNode = DomNode.FromIfDirective(htmlNode, parentDom, depth)
        -- Build the if-block children
        if htmlNode.children then
            for _, child in ipairs(htmlNode.children) do
                local childDom = DirectiveEvaluator.BuildDomNode(child, domNode, depth + 1)
                if childDom then
                    domNode:AppendChild(childDom)
                end
            end
        end
        return domNode

    elseif htmlNode.type == NodeType.ForDirective then
        --- @cast htmlNode AnglesUI.ForDirectiveNode
        local domNode = DomNode.FromForDirective(htmlNode, parentDom, depth)
        if htmlNode.children then
            for _, child in ipairs(htmlNode.children) do
                local childDom = DirectiveEvaluator.BuildDomNode(child, domNode, depth + 1)
                if childDom then
                    domNode:AppendChild(childDom)
                end
            end
        end
        return domNode
    end

    return nil
end

---------------------------------------------------------------------------
-- Core: Evaluate children of a node
---------------------------------------------------------------------------

--- Recursively evaluate a list of DomNode children, expanding @if and @for
--- directives into concrete nodes. Non-directive nodes are passed through
--- as-is, but their children are also recursively evaluated.
--- @param children AnglesUI.DomNode[]
--- @param context table<string, any>
--- @param parentDom AnglesUI.DomNode?
--- @return AnglesUI.DomNode[]
evaluateChildren = function(children, context, parentDom)
    local result = {}

    for i = 1, #children do
        local child = children[i]

        if child.kind == DomNodeKind.IfDirective then
            -- Expand the @if directive
            local expanded = evaluateIfDirective(child, context)
            for j = 1, #expanded do
                result[#result + 1] = expanded[j]
            end

        elseif child.kind == DomNodeKind.ForDirective then
            -- Expand the @for directive
            local expanded = evaluateForDirective(child, context)
            for j = 1, #expanded do
                result[#result + 1] = expanded[j]
            end

        elseif child.kind == DomNodeKind.Element then
            -- Recursively evaluate this element's children
            local evaluatedKids = evaluateChildren(child.children, context, child)
            child:SetChildren(evaluatedKids)
            result[#result + 1] = child

        else
            -- Text, Output — pass through
            result[#result + 1] = child
        end
    end

    return result
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

--- Evaluate all directives in a DOM tree, starting from the given root.
--- Expands @if and @for directives in-place, replacing directive DomNodes
--- with their concrete expansions based on the evaluation context.
---
--- This should be called after the DOM tree is built but before layout/render.
--- @param root AnglesUI.DomNode The root of the DOM tree
--- @param context table<string, any> The evaluation scope (user-provided data + signals)
function DirectiveEvaluator.Evaluate(root, context)
    if not root.children or #root.children == 0 then
        return
    end

    local evaluated = evaluateChildren(root.children, context, root)
    root:SetChildren(evaluated)
end

return DirectiveEvaluator
