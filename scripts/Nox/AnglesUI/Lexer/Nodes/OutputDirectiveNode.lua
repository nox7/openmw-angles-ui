local Node = require("scripts.Nox.AnglesUI.Lexer.Nodes.Node")

local OutputDirectiveNode = setmetatable({}, { __index = Node })
OutputDirectiveNode.__index = OutputDirectiveNode

function OutputDirectiveNode.new(expression)
  local self = Node.new(Node.TYPE_OUTPUT)
  setmetatable(self, OutputDirectiveNode)
  self.expression = expression or ""
  self.isTernary = false
  self.ternaryCondition = nil
  self.ternaryTrueExpression = nil
  self.ternaryFalseExpression = nil
  return self
end

function OutputDirectiveNode.newTernary(condition, trueExpression, falseExpression)
  local self = Node.new(Node.TYPE_OUTPUT)
  setmetatable(self, OutputDirectiveNode)
  self.expression = condition .. " ? " .. trueExpression .. " : " .. falseExpression
  self.isTernary = true
  self.ternaryCondition = condition
  self.ternaryTrueExpression = trueExpression
  self.ternaryFalseExpression = falseExpression
  return self
end

return OutputDirectiveNode
