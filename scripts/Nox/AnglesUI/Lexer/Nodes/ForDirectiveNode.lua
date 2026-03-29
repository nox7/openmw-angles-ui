local Node = require("scripts.Nox.AnglesUI.Lexer.Nodes.Node")

local ForDirectiveNode = setmetatable({}, { __index = Node })
ForDirectiveNode.__index = ForDirectiveNode

function ForDirectiveNode.new(iteratorVariable, iterableExpression)
  local self = Node.new(Node.TYPE_FOR_DIRECTIVE)
  setmetatable(self, ForDirectiveNode)
  self.iteratorVariable = iteratorVariable or ""
  self.iterableExpression = iterableExpression or ""
  return self
end

return ForDirectiveNode
