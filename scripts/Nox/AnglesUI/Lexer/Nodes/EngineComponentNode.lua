local Node = require("scripts.Nox.AnglesUI.Lexer.Nodes.Node")
local ComponentNode = require("scripts.Nox.AnglesUI.Lexer.Nodes.ComponentNode")

local EngineComponentNode = setmetatable({}, { __index = ComponentNode })
EngineComponentNode.__index = EngineComponentNode

function EngineComponentNode.new(tagName, attributes, selfClosing)
  local self = ComponentNode.new(tagName, attributes, selfClosing)
  setmetatable(self, EngineComponentNode)
  self.type = Node.TYPE_ENGINE_COMPONENT
  return self
end

return EngineComponentNode
