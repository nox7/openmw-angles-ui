local Node = require("scripts.Nox.AnglesUI.Lexer.Nodes.Node")

---@class TextNode : Node Represents a raw text segment in the template (no bindings or directives).
---@field text string The literal text content of this node.
local TextNode = setmetatable({}, { __index = Node })
TextNode.__index = TextNode

---@param text string The literal text content.
---@return TextNode
function TextNode.new(text)
  local self = Node.new(Node.TYPE_TEXT)
  setmetatable(self, TextNode)
  self.text = text or ""
  return self
end

return TextNode
