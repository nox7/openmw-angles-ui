--- AnglesUI DOM Tree Builder.
--- Converts an HTML AST (from HtmlParser) into a linked DomNode tree with
--- full parent/child/sibling references and cached attribute data.

local HtmlNodes = require("scripts.Nox.AnglesUI.Parser.HTML.HtmlNodes")
local DomNode   = require("scripts.Nox.AnglesUI.DOM.DomNode")

local NodeType = HtmlNodes.NodeType

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

--- @class AnglesUI.DomTreeBuilder
local DomTreeBuilder = {}

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------

--- Map from htmlNode table → DomNode, used to resolve _logicalHostNode references.
--- Populated during Build(), reset each call.
--- @type table<any, AnglesUI.DomNode>
local htmlNodeToDomNode = {}

--- Forward declaration for mutual recursion.
--- @type fun(htmlChildren: AnglesUI.BaseNode[], parentDom: AnglesUI.DomNode)
local buildChildren

--- Build a DomNode from a single HTML AST node.
--- @param htmlNode AnglesUI.BaseNode
--- @param parentDom AnglesUI.DomNode?
--- @param depth integer
--- @return AnglesUI.DomNode
local function buildNode(htmlNode, parentDom, depth)
    local domNode

    if htmlNode.type == NodeType.Element then
        --- @cast htmlNode AnglesUI.ElementNode
        domNode = DomNode.FromElement(htmlNode, parentDom, depth)
        -- Register in lookup map so _logicalHostNode can be resolved
        htmlNodeToDomNode[htmlNode] = domNode
        -- Set logicalParent if this node was annotated as projected content
        if htmlNode._logicalHostNode then
            local hostDom = htmlNodeToDomNode[htmlNode._logicalHostNode]
            if hostDom then
                domNode.logicalParent = hostDom
            end
        end
        buildChildren(htmlNode.children, domNode)

    elseif htmlNode.type == NodeType.Text then
        --- @cast htmlNode AnglesUI.TextNode
        domNode = DomNode.FromText(htmlNode, parentDom, depth)

    elseif htmlNode.type == NodeType.Output then
        --- @cast htmlNode AnglesUI.OutputDirectiveNode
        domNode = DomNode.FromOutput(htmlNode, parentDom, depth)

    elseif htmlNode.type == NodeType.IfDirective then
        --- @cast htmlNode AnglesUI.IfDirectiveNode
        domNode = DomNode.FromIfDirective(htmlNode, parentDom, depth)
        -- Build children of the if-block body
        buildChildren(htmlNode.children, domNode)

        -- Also build children of else-if and else branches,
        -- stored on the htmlNode for later directive evaluation.
        -- We don't attach them as children of the @if DomNode —
        -- directive evaluation will pick the active branch at runtime.

    elseif htmlNode.type == NodeType.ForDirective then
        --- @cast htmlNode AnglesUI.ForDirectiveNode
        domNode = DomNode.FromForDirective(htmlNode, parentDom, depth)
        -- Template children are stored on the htmlNode for per-iteration
        -- cloning during directive evaluation.
        buildChildren(htmlNode.children, domNode)

    else
        -- ElseIfDirective / ElseDirective nodes are handled through
        -- the IfDirective's elseIfBranches / elseBranch — they shouldn't
        -- appear at the top level, but if they do, wrap as generic.
        domNode = DomNode.FromText(
            { type = NodeType.Text, content = "", parent = nil, line = 0, column = 0 },
            parentDom,
            depth
        )
    end

    return domNode
end

--- Build DomNode children from a list of HTML AST nodes and append to parent.
--- @param htmlChildren AnglesUI.BaseNode[]
--- @param parentDom AnglesUI.DomNode
buildChildren = function(htmlChildren, parentDom)
    if not htmlChildren then return end

    for _, htmlChild in ipairs(htmlChildren) do
        local childDom = buildNode(htmlChild, parentDom, parentDom.depth + 1)
        parentDom:AppendChild(childDom)
    end
end

--- Build a complete DOM tree from an HTML AST root (array of root-level nodes).
--- @param htmlAst AnglesUI.BaseNode[] Root-level parsed HTML nodes
--- @return AnglesUI.DomNode root The root DomNode (a virtual document node wrapping everything)
---@nodiscard
function DomTreeBuilder.Build(htmlAst)
    -- Reset the htmlNode→DomNode lookup for this build pass
    htmlNodeToDomNode = {}

    -- Create a virtual document root node
    local rootHtml = HtmlNodes.CreateElement("__document__", 0, 0)
    local root = DomNode.FromElement(rootHtml, nil, 0)
    root.isEngine = false
    root.isUserComponent = false

    buildChildren(htmlAst, root)

    -- If there's exactly one child and it's an element, it's the actual root.
    -- We still keep the document wrapper for consistency.
    return root
end

--- Build a DOM tree from a single HTML AST element node (not an array).
--- Useful for user component sub-trees.
--- @param htmlNode AnglesUI.ElementNode
--- @param parentDom AnglesUI.DomNode?
--- @return AnglesUI.DomNode
---@nodiscard
function DomTreeBuilder.BuildFromElement(htmlNode, parentDom)
    local depth = parentDom and (parentDom.depth + 1) or 0
    local domNode = buildNode(htmlNode, parentDom, depth)
    return domNode
end

return DomTreeBuilder
