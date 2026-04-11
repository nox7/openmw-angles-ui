--- AnglesUI HTML AST Node definitions.
--- Provides node type enums, attribute type enums, and factory functions
--- for constructing the HTML abstract syntax tree.

---------------------------------------------------------------------------
-- Enums
---------------------------------------------------------------------------

--- @enum AnglesUI.NodeType
local NodeType = {
    Element = "Element",
    Text = "Text",
    Output = "Output",
    IfDirective = "IfDirective",
    ForDirective = "ForDirective",
    ElseIfDirective = "ElseIfDirective",
    ElseDirective = "ElseDirective",
}

--- @enum AnglesUI.AttributeType
local AttributeType = {
    Static = "Static",
    Binding = "Binding",
    StyleBinding = "StyleBinding",
    AttrBinding = "AttrBinding",
    Event = "Event",
}

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

--- @class AnglesUI.HtmlNodes
--- @field NodeType AnglesUI.NodeType
--- @field AttributeType AnglesUI.AttributeType
local HtmlNodes = {
    NodeType = NodeType,
    AttributeType = AttributeType,
}

---------------------------------------------------------------------------
-- Node type definitions (for documentation / type checking)
---------------------------------------------------------------------------

--- @class AnglesUI.Attribute
--- @field type AnglesUI.AttributeType
--- @field name string The attribute / binding / event name
--- @field value string The raw value string or expression
--- @field property string? For style/attr bindings, the sub-property name

--- @class AnglesUI.BaseNode
--- @field type AnglesUI.NodeType
--- @field parent AnglesUI.BaseNode?
--- @field line integer Source line number
--- @field column integer Source column number

--- @class AnglesUI.ElementNode : AnglesUI.BaseNode
--- @field tag string
--- @field attributes AnglesUI.Attribute[]
--- @field children AnglesUI.BaseNode[]
--- @field selfClosing boolean
--- @field isEngine boolean True if tag starts with "mw-"
--- @field isUserComponent boolean True if not an engine component

--- @class AnglesUI.TextNode : AnglesUI.BaseNode
--- @field content string

--- @class AnglesUI.OutputDirectiveNode : AnglesUI.BaseNode
--- @field expression string The raw expression inside {{ }}

--- @class AnglesUI.IfDirectiveNode : AnglesUI.BaseNode
--- @field condition string The raw condition expression
--- @field children AnglesUI.BaseNode[] Children when condition is true
--- @field elseIfBranches AnglesUI.ElseIfDirectiveNode[] Chained @else if branches
--- @field elseBranch AnglesUI.ElseDirectiveNode? The @else branch

--- @class AnglesUI.ElseIfDirectiveNode : AnglesUI.BaseNode
--- @field condition string
--- @field children AnglesUI.BaseNode[]

--- @class AnglesUI.ElseDirectiveNode : AnglesUI.BaseNode
--- @field children AnglesUI.BaseNode[]

--- @class AnglesUI.ForDirectiveNode : AnglesUI.BaseNode
--- @field iteratorName string The loop variable name (e.g. "item")
--- @field iterableExpression string The iterable expression (e.g. "Items().Armor")
--- @field children AnglesUI.BaseNode[] Children inside the loop body

---------------------------------------------------------------------------
-- Factory functions
---------------------------------------------------------------------------

--- Create an element node.
--- @param tag string The tag name
--- @param line? integer Source line
--- @param column? integer Source column
--- @return AnglesUI.ElementNode
---@nodiscard
function HtmlNodes.CreateElement(tag, line, column)
    return {
        type = NodeType.Element,
        tag = tag,
        attributes = {},
        children = {},
        selfClosing = false,
        isEngine = tag:sub(1, 3) == "mw-",
        isUserComponent = tag:sub(1, 3) ~= "mw-",
        parent = nil,
        line = line or 0,
        column = column or 0,
    }
end

--- Create a text node.
--- @param content string The text content
--- @param line? integer Source line
--- @param column? integer Source column
--- @return AnglesUI.TextNode
---@nodiscard
function HtmlNodes.CreateText(content, line, column)
    return {
        type = NodeType.Text,
        content = content,
        parent = nil,
        line = line or 0,
        column = column or 0,
    }
end

--- Create an output directive node ({{ expression }}).
--- @param expression string The expression inside the mustaches
--- @param line? integer Source line
--- @param column? integer Source column
--- @return AnglesUI.OutputDirectiveNode
---@nodiscard
function HtmlNodes.CreateOutput(expression, line, column)
    return {
        type = NodeType.Output,
        expression = expression,
        parent = nil,
        line = line or 0,
        column = column or 0,
    }
end

--- Create an @if directive node.
--- @param condition string The condition expression
--- @param line? integer Source line
--- @param column? integer Source column
--- @return AnglesUI.IfDirectiveNode
---@nodiscard
function HtmlNodes.CreateIfDirective(condition, line, column)
    return {
        type = NodeType.IfDirective,
        condition = condition,
        children = {},
        elseIfBranches = {},
        elseBranch = nil,
        parent = nil,
        line = line or 0,
        column = column or 0,
    }
end

--- Create an @else if directive node.
--- @param condition string The condition expression
--- @param line? integer Source line
--- @param column? integer Source column
--- @return AnglesUI.ElseIfDirectiveNode
---@nodiscard
function HtmlNodes.CreateElseIfDirective(condition, line, column)
    return {
        type = NodeType.ElseIfDirective,
        condition = condition,
        children = {},
        parent = nil,
        line = line or 0,
        column = column or 0,
    }
end

--- Create an @else directive node.
--- @param line? integer Source line
--- @param column? integer Source column
--- @return AnglesUI.ElseDirectiveNode
---@nodiscard
function HtmlNodes.CreateElseDirective(line, column)
    return {
        type = NodeType.ElseDirective,
        children = {},
        parent = nil,
        line = line or 0,
        column = column or 0,
    }
end

--- Create a @for directive node.
--- @param iteratorName string The variable name
--- @param iterableExpression string The iterable expression
--- @param line? integer Source line
--- @param column? integer Source column
--- @return AnglesUI.ForDirectiveNode
---@nodiscard
function HtmlNodes.CreateForDirective(iteratorName, iterableExpression, line, column)
    return {
        type = NodeType.ForDirective,
        iteratorName = iteratorName,
        iterableExpression = iterableExpression,
        children = {},
        parent = nil,
        line = line or 0,
        column = column or 0,
    }
end

--- Create an attribute record.
--- @param attrType AnglesUI.AttributeType
--- @param name string
--- @param value? string
--- @param property? string Sub-property for style/attr bindings
--- @return AnglesUI.Attribute
---@nodiscard
function HtmlNodes.CreateAttribute(attrType, name, value, property)
    return {
        type = attrType,
        name = name,
        value = value or "",
        property = property,
    }
end

---------------------------------------------------------------------------
-- Deep copy
---------------------------------------------------------------------------

--- Deep-copy a single HTML AST node, producing a fully independent tree.
--- Required to prevent template mutation when a cached template is reused
--- across multiple component expansions via ContentProjection.
--- @param node AnglesUI.BaseNode
--- @return AnglesUI.BaseNode
---@nodiscard
function HtmlNodes.DeepCopyNode(node)
    if node.type == NodeType.Element then
        --- @cast node AnglesUI.ElementNode
        local copy = HtmlNodes.CreateElement(node.tag, node.line, node.column)
        copy.selfClosing = node.selfClosing
        copy.isEngine = node.isEngine
        copy.isUserComponent = node.isUserComponent
        -- Shallow-copy attributes (Attribute tables are value-like; never mutated in place)
        copy.attributes = {}
        for _, attr in ipairs(node.attributes) do
            copy.attributes[#copy.attributes + 1] = attr
        end
        -- Recursively deep-copy children
        for _, child in ipairs(node.children) do
            local childCopy = HtmlNodes.DeepCopyNode(child)
            childCopy.parent = copy
            copy.children[#copy.children + 1] = childCopy
        end
        return copy

    elseif node.type == NodeType.Text then
        --- @cast node AnglesUI.TextNode
        return HtmlNodes.CreateText(node.content, node.line, node.column)

    elseif node.type == NodeType.Output then
        --- @cast node AnglesUI.OutputDirectiveNode
        return HtmlNodes.CreateOutput(node.expression, node.line, node.column)

    elseif node.type == NodeType.IfDirective then
        --- @cast node AnglesUI.IfDirectiveNode
        local copy = HtmlNodes.CreateIfDirective(node.condition, node.line, node.column)
        for _, child in ipairs(node.children) do
            local childCopy = HtmlNodes.DeepCopyNode(child)
            childCopy.parent = copy
            copy.children[#copy.children + 1] = childCopy
        end
        copy.elseIfBranches = {}
        for _, branch in ipairs(node.elseIfBranches or {}) do
            local branchCopy = HtmlNodes.CreateElseIfDirective(branch.condition, branch.line, branch.column)
            for _, child in ipairs(branch.children or {}) do
                local childCopy = HtmlNodes.DeepCopyNode(child)
                childCopy.parent = branchCopy
                branchCopy.children[#branchCopy.children + 1] = childCopy
            end
            copy.elseIfBranches[#copy.elseIfBranches + 1] = branchCopy
        end
        if node.elseBranch then
            local elseCopy = HtmlNodes.CreateElseDirective(node.elseBranch.line, node.elseBranch.column)
            for _, child in ipairs(node.elseBranch.children or {}) do
                local childCopy = HtmlNodes.DeepCopyNode(child)
                childCopy.parent = elseCopy
                elseCopy.children[#elseCopy.children + 1] = childCopy
            end
            copy.elseBranch = elseCopy
        end
        return copy

    elseif node.type == NodeType.ForDirective then
        --- @cast node AnglesUI.ForDirectiveNode
        local copy = HtmlNodes.CreateForDirective(node.iteratorName, node.iterableExpression, node.line, node.column)
        for _, child in ipairs(node.children) do
            local childCopy = HtmlNodes.DeepCopyNode(child)
            childCopy.parent = copy
            copy.children[#copy.children + 1] = childCopy
        end
        return copy

    else
        -- ElseIf/Else directives at top-level (unusual) — copy generically
        --- @cast node AnglesUI.ElseDirectiveNode
        return HtmlNodes.CreateElseDirective(node.line, node.column)
    end
end

--- Deep-copy a list of HTML AST nodes.
--- @param nodes AnglesUI.BaseNode[]
--- @return AnglesUI.BaseNode[]
---@nodiscard
function HtmlNodes.DeepCopyAst(nodes)
    local result = {}
    for _, node in ipairs(nodes) do
        result[#result + 1] = HtmlNodes.DeepCopyNode(node)
    end
    return result
end

return HtmlNodes
