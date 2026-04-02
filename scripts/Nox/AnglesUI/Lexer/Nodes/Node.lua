---@class Node Base AST node produced by the Lexer. All concrete node types extend this.
---@field type string Node type identifier — one of the Node.TYPE_* string constants.
---@field children Node[] Ordered list of child nodes attached to this node.
local Node = {}
Node.__index = Node

---@type string Constant identifying a raw text node.
Node.TYPE_TEXT = "Text"
---@type string Constant identifying a generic component element node.
Node.TYPE_COMPONENT = "Component"
---@type string Constant identifying an engine-owned element (tag starts with "mw-").
Node.TYPE_ENGINE_COMPONENT = "EngineComponent"
---@type string Constant identifying a user-registered component element.
Node.TYPE_USER_COMPONENT = "UserComponent"
---@type string Constant identifying an `@if` directive node.
Node.TYPE_IF_DIRECTIVE = "IfDirective"
---@type string Constant identifying an `@for` directive node.
Node.TYPE_FOR_DIRECTIVE = "ForDirective"
---@type string Constant identifying an `{{ expr }}` output binding node.
Node.TYPE_OUTPUT = "Output"

---@param nodeType string One of the Node.TYPE_* string constants.
---@return Node
function Node.new(nodeType)
  local self = setmetatable({}, Node)
  self.type = nodeType
  self.children = {}
  return self
end

---@param childNode Node The child node to append.
function Node:addChild(childNode)
  table.insert(self.children, childNode)
end

return Node
