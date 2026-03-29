local Node = require("scripts.Nox.AnglesUI.Lexer.Nodes.Node")
local ComponentNode = require("scripts.Nox.AnglesUI.Lexer.Nodes.ComponentNode")

local UserComponentNode = setmetatable({}, { __index = ComponentNode })
UserComponentNode.__index = UserComponentNode

function UserComponentNode.new(tagName, attributes, selfClosing, templateContent)
  local self = ComponentNode.new(tagName, attributes, selfClosing)
  setmetatable(self, UserComponentNode)
  self.type = Node.TYPE_USER_COMPONENT
  self.templateContent = templateContent or ""
  return self
end

return UserComponentNode
