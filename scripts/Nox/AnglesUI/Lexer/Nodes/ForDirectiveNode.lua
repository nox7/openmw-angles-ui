local Node = require("scripts.Nox.AnglesUI.Lexer.Nodes.Node")

---@class ForDirectiveNode : Node Represents an `@for (item in items)` loop directive.
---@field iteratorVariable string The loop variable name bound on each iteration (e.g. "guard").
---@field iterableExpression string The expression string that yields the collection to iterate (e.g. "Guards").
local ForDirectiveNode = setmetatable({}, { __index = Node })
ForDirectiveNode.__index = ForDirectiveNode

---@param iteratorVariable string Name of the loop variable bound on each iteration.
---@param iterableExpression string Expression string for the collection to iterate.
---@return ForDirectiveNode
function ForDirectiveNode.new(iteratorVariable, iterableExpression)
  local self = Node.new(Node.TYPE_FOR_DIRECTIVE)
  setmetatable(self, ForDirectiveNode)
  self.iteratorVariable = iteratorVariable or ""
  self.iterableExpression = iterableExpression or ""
  return self
end

return ForDirectiveNode
