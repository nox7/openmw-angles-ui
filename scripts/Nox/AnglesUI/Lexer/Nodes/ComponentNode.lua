local Node = require("scripts.Nox.AnglesUI.Lexer.Nodes.Node")

local ComponentNode = setmetatable({}, { __index = Node })
ComponentNode.__index = ComponentNode

function ComponentNode.new(tagName, attributes, selfClosing)
  local self = Node.new(Node.TYPE_COMPONENT)
  setmetatable(self, ComponentNode)
  self.tagName = tagName or ""
  self.attributes = attributes or {}
  self.selfClosing = selfClosing or false
  return self
end

function ComponentNode:setAttribute(name, value)
  self.attributes[name] = value
end

function ComponentNode:getAttribute(name)
  return self.attributes[name]
end

return ComponentNode
