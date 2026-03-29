local Node = {}
Node.__index = Node

Node.TYPE_TEXT = "Text"
Node.TYPE_COMPONENT = "Component"
Node.TYPE_ENGINE_COMPONENT = "EngineComponent"
Node.TYPE_USER_COMPONENT = "UserComponent"
Node.TYPE_IF_DIRECTIVE = "IfDirective"
Node.TYPE_FOR_DIRECTIVE = "ForDirective"
Node.TYPE_OUTPUT = "Output"

function Node.new(nodeType)
  local self = setmetatable({}, Node)
  self.type = nodeType
  self.children = {}
  return self
end

function Node:addChild(childNode)
  table.insert(self.children, childNode)
end

return Node
