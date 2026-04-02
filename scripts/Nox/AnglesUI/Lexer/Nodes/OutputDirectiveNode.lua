local Node = require("scripts.Nox.AnglesUI.Lexer.Nodes.Node")

---@class OutputDirectiveNode : Node Represents an `{{ expression }}` text-interpolation binding.
---@field expression string The full expression string (or combined ternary representation).
---@field isTernary boolean True when the node was constructed from a `cond ? a : b` ternary.
---@field ternaryCondition string|nil The condition arm; populated only when isTernary is true.
---@field ternaryTrueExpression string|nil The true-result arm; populated only when isTernary is true.
---@field ternaryFalseExpression string|nil The false-result arm; populated only when isTernary is true.
local OutputDirectiveNode = setmetatable({}, { __index = Node })
OutputDirectiveNode.__index = OutputDirectiveNode

---@param expression string The template expression to evaluate and render as text.
---@return OutputDirectiveNode
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

---@param condition string The condition expression.
---@param trueExpression string Expression to evaluate when the condition is truthy.
---@param falseExpression string Expression to evaluate when the condition is falsy.
---@return OutputDirectiveNode
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
