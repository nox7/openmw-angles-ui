--- AnglesUI DOM Node.
--- Unified DOM tree node that bridges the HTML AST and CSS AST together.
--- Each DomNode wraps an HTML AST node and carries resolved CSS styles,
--- parent/child/sibling references, and metadata needed for rendering
--- optimisation (dirty flags, container status, hover tracking).

local HtmlNodes = require("scripts.Nox.AnglesUI.Parser.HTML.HtmlNodes")

---------------------------------------------------------------------------
-- Enums
---------------------------------------------------------------------------

--- @enum AnglesUI.DomNodeKind
local DomNodeKind = {
    Element       = "Element",
    Text          = "Text",
    Output        = "Output",
    IfDirective   = "IfDirective",
    ForDirective  = "ForDirective",
}

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

--- @class AnglesUI.DomNode
--- @field kind AnglesUI.DomNodeKind
--- @field tag string? Tag name for element nodes
--- @field htmlNode AnglesUI.BaseNode The underlying HTML AST node
--- @field parent AnglesUI.DomNode?
--- @field children AnglesUI.DomNode[]
--- @field nextSibling AnglesUI.DomNode?
--- @field prevSibling AnglesUI.DomNode?
--- @field depth integer Depth in the tree (root = 0)
--- @field computedStyles table<string, string> CSS property→value after cascade
--- @field matchedRules AnglesUI.MatchedRule[] All CSS rules that matched this node, sorted by specificity
--- @field isContainer boolean Whether this element has container-type: size
--- @field containerName string? Container name for @container queries
--- @field isHovered boolean Whether this node currently has focus/hover
--- @field hoverCount integer Counter for descendant focusGain/focusLoss tracking
--- @field isDirty boolean Whether this node needs re-render
--- @field isEngine boolean Whether tag starts with "mw-"
--- @field isUserComponent boolean Whether this is a user component
--- @field hostElement AnglesUI.DomNode? The host element for user components (for :host)
--- @field scopeId string? Unique scope identifier for CSS scoping
--- @field logicalParent AnglesUI.DomNode? Override parent used for CSS selector matching (set on projected content so selectors pierce component wrappers)
--- @field attributes table<string, AnglesUI.Attribute> Quick attribute lookup by name
--- @field id string? Cached id attribute value
--- @field classes table<string, boolean> Cached class set
--- @field layoutData table Renderer-specific layout data (position, size, etc.)
local DomNode = {}
DomNode.__index = DomNode

--- @class AnglesUI.MatchedRule
--- @field rule AnglesUI.CssRule The CSS rule
--- @field selector AnglesUI.Selector The specific selector that matched
--- @field specificity integer[] {a, b, c}
--- @field order integer Source order for tie-breaking

---------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------

--- Create a DomNode from an HTML AST element node.
--- @param htmlNode AnglesUI.ElementNode
--- @param parent AnglesUI.DomNode?
--- @param depth integer?
--- @return AnglesUI.DomNode
---@nodiscard
function DomNode.FromElement(htmlNode, parent, depth)
    local node = setmetatable({}, DomNode)
    node.kind = DomNodeKind.Element
    node.tag = htmlNode.tag
    node.htmlNode = htmlNode
    node.parent = parent
    node.children = {}
    node.nextSibling = nil
    node.prevSibling = nil
    node.depth = depth or 0
    node.computedStyles = {}
    node.matchedRules = {}
    node.isContainer = false
    node.containerName = nil
    node.isHovered = false
    node.hoverCount = 0
    node.isDirty = true
    node.isEngine = htmlNode.isEngine or false
    node.isUserComponent = htmlNode.isUserComponent or false
    node.hostElement = nil
    node.scopeId = nil
    node.logicalParent = nil
    node.layoutData = {}

    -- Cache attributes
    node.attributes = {}
    node.id = nil
    node.classes = {}
    if htmlNode.attributes then
        for _, attr in ipairs(htmlNode.attributes) do
            node.attributes[attr.name] = attr
            if attr.name == "id" and attr.value then
                node.id = attr.value
            end
            if attr.name == "class" and attr.value then
                for cls in attr.value:gmatch("%S+") do
                    node.classes[cls] = true
                end
            end
        end
    end

    return node
end

--- Create a DomNode from an HTML AST text node.
--- @param htmlNode AnglesUI.TextNode
--- @param parent AnglesUI.DomNode?
--- @param depth integer?
--- @return AnglesUI.DomNode
---@nodiscard
function DomNode.FromText(htmlNode, parent, depth)
    local node = setmetatable({}, DomNode)
    node.kind = DomNodeKind.Text
    node.tag = nil
    node.htmlNode = htmlNode
    node.parent = parent
    node.children = {}
    node.nextSibling = nil
    node.prevSibling = nil
    node.depth = depth or 0
    node.computedStyles = {}
    node.matchedRules = {}
    node.isContainer = false
    node.containerName = nil
    node.isHovered = false
    node.hoverCount = 0
    node.isDirty = true
    node.isEngine = false
    node.isUserComponent = false
    node.hostElement = nil
    node.scopeId = nil
    node.attributes = {}
    node.id = nil
    node.classes = {}
    node.layoutData = {}
    return node
end

--- Create a DomNode from an output directive node.
--- @param htmlNode AnglesUI.OutputDirectiveNode
--- @param parent AnglesUI.DomNode?
--- @param depth integer?
--- @return AnglesUI.DomNode
---@nodiscard
function DomNode.FromOutput(htmlNode, parent, depth)
    local node = setmetatable({}, DomNode)
    node.kind = DomNodeKind.Output
    node.tag = nil
    node.htmlNode = htmlNode
    node.parent = parent
    node.children = {}
    node.nextSibling = nil
    node.prevSibling = nil
    node.depth = depth or 0
    node.computedStyles = {}
    node.matchedRules = {}
    node.isContainer = false
    node.containerName = nil
    node.isHovered = false
    node.hoverCount = 0
    node.isDirty = true
    node.isEngine = false
    node.isUserComponent = false
    node.hostElement = nil
    node.scopeId = nil
    node.attributes = {}
    node.id = nil
    node.classes = {}
    node.layoutData = {}
    return node
end

--- Create a DomNode from an @if directive.
--- @param htmlNode AnglesUI.IfDirectiveNode
--- @param parent AnglesUI.DomNode?
--- @param depth integer?
--- @return AnglesUI.DomNode
---@nodiscard
function DomNode.FromIfDirective(htmlNode, parent, depth)
    local node = setmetatable({}, DomNode)
    node.kind = DomNodeKind.IfDirective
    node.tag = nil
    node.htmlNode = htmlNode
    node.parent = parent
    node.children = {}
    node.nextSibling = nil
    node.prevSibling = nil
    node.depth = depth or 0
    node.computedStyles = {}
    node.matchedRules = {}
    node.isContainer = false
    node.containerName = nil
    node.isHovered = false
    node.hoverCount = 0
    node.isDirty = true
    node.isEngine = false
    node.isUserComponent = false
    node.hostElement = nil
    node.scopeId = nil
    node.attributes = {}
    node.id = nil
    node.classes = {}
    node.layoutData = {}
    return node
end

--- Create a DomNode from a @for directive.
--- @param htmlNode AnglesUI.ForDirectiveNode
--- @param parent AnglesUI.DomNode?
--- @param depth integer?
--- @return AnglesUI.DomNode
---@nodiscard
function DomNode.FromForDirective(htmlNode, parent, depth)
    local node = setmetatable({}, DomNode)
    node.kind = DomNodeKind.ForDirective
    node.tag = nil
    node.htmlNode = htmlNode
    node.parent = parent
    node.children = {}
    node.nextSibling = nil
    node.prevSibling = nil
    node.depth = depth or 0
    node.computedStyles = {}
    node.matchedRules = {}
    node.isContainer = false
    node.containerName = nil
    node.isHovered = false
    node.hoverCount = 0
    node.isDirty = true
    node.isEngine = false
    node.isUserComponent = false
    node.hostElement = nil
    node.scopeId = nil
    node.attributes = {}
    node.id = nil
    node.classes = {}
    node.layoutData = {}
    return node
end

---------------------------------------------------------------------------
-- Child management
---------------------------------------------------------------------------

--- Append a child to this node, maintaining sibling links.
--- @param child AnglesUI.DomNode
function DomNode:AppendChild(child)
    child.parent = self
    child.depth = self.depth + 1

    local count = #self.children
    if count > 0 then
        local prevChild = self.children[count]
        prevChild.nextSibling = child
        child.prevSibling = prevChild
    else
        child.prevSibling = nil
    end
    child.nextSibling = nil

    self.children[count + 1] = child
end

--- Remove a child from this node.
--- @param child AnglesUI.DomNode
function DomNode:RemoveChild(child)
    for i, c in ipairs(self.children) do
        if c == child then
            -- Fix sibling links
            if child.prevSibling then
                child.prevSibling.nextSibling = child.nextSibling
            end
            if child.nextSibling then
                child.nextSibling.prevSibling = child.prevSibling
            end
            child.parent = nil
            child.prevSibling = nil
            child.nextSibling = nil
            table.remove(self.children, i)
            return
        end
    end
end

--- Replace all children with a new set, re-linking siblings.
--- @param newChildren AnglesUI.DomNode[]
function DomNode:SetChildren(newChildren)
    -- Clear old links
    for _, c in ipairs(self.children) do
        c.parent = nil
        c.prevSibling = nil
        c.nextSibling = nil
    end

    self.children = {}
    for _, child in ipairs(newChildren) do
        self:AppendChild(child)
    end
end

---------------------------------------------------------------------------
-- Traversal helpers
---------------------------------------------------------------------------

--- Get all ancestor DomNodes from this node to the root (exclusive).
--- @return AnglesUI.DomNode[]
function DomNode:GetAncestors()
    local result = {}
    local current = self.parent
    while current do
        result[#result + 1] = current
        current = current.parent
    end
    return result
end

--- Get all descendant DomNodes in depth-first order.
--- @return AnglesUI.DomNode[]
function DomNode:GetDescendants()
    local result = {}
    local function walk(node)
        for _, child in ipairs(node.children) do
            result[#result + 1] = child
            walk(child)
        end
    end
    walk(self)
    return result
end

--- Get all element descendants (kind == Element) in depth-first order.
--- @return AnglesUI.DomNode[]
function DomNode:GetElementDescendants()
    local result = {}
    local function walk(node)
        for _, child in ipairs(node.children) do
            if child.kind == DomNodeKind.Element then
                result[#result + 1] = child
            end
            walk(child)
        end
    end
    walk(self)
    return result
end

--- Walk the tree depth-first, calling visitor(node) for each node.
--- If visitor returns true, stop traversal.
--- @param visitor fun(node: AnglesUI.DomNode): boolean?
function DomNode:Walk(visitor)
    if visitor(self) then return true end
    for _, child in ipairs(self.children) do
        if child:Walk(visitor) then return true end
    end
    return false
end

--- Find the nearest ancestor (inclusive) that is a container.
--- @return AnglesUI.DomNode?
function DomNode:FindNearestContainer()
    local current = self.parent
    while current do
        if current.isContainer then
            return current
        end
        current = current.parent
    end
    return nil
end

--- Find the nearest named container ancestor.
--- @param name string
--- @return AnglesUI.DomNode?
function DomNode:FindNamedContainer(name)
    local current = self.parent
    while current do
        if current.isContainer and current.containerName == name then
            return current
        end
        current = current.parent
    end
    return nil
end

--- Find the nearest positioned ancestor (position ~= "static").
--- @return AnglesUI.DomNode?
function DomNode:FindPositionedAncestor()
    local current = self.parent
    while current do
        local pos = current.computedStyles["position"]
        if pos and pos ~= "static" then
            return current
        end
        current = current.parent
    end
    return nil
end

---------------------------------------------------------------------------
-- Dirty marking
---------------------------------------------------------------------------

--- Mark this node and all its ancestors as dirty (needing re-render).
function DomNode:MarkDirty()
    self.isDirty = true
    local current = self.parent
    while current do
        if current.isDirty then break end -- Already dirty up the chain
        current.isDirty = true
        current = current.parent
    end
end

--- Clear dirty flag on this node only.
function DomNode:ClearDirty()
    self.isDirty = false
end

--- Clear dirty flag on this node and all descendants.
function DomNode:ClearDirtyRecursive()
    self.isDirty = false
    for _, child in ipairs(self.children) do
        child:ClearDirtyRecursive()
    end
end

---------------------------------------------------------------------------
-- Export
---------------------------------------------------------------------------

DomNode.DomNodeKind = DomNodeKind

return DomNode
