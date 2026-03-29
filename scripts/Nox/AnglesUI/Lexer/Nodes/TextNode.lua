local Node = require("scripts.Nox.AnglesUI.Lexer.Nodes.Node")

local TextNode = setmetatable({}, { __index = Node })
TextNode.__index = TextNode

function TextNode.new(text)
  local self = Node.new(Node.TYPE_TEXT)
  setmetatable(self, TextNode)
  self.text = text or ""
  return self
end

return TextNode
