local Node = require("scripts.Nox.AnglesUI.Lexer.Nodes.Node")

---@class IfDirectiveNode : Node Represents an `@if / @else if / @else` conditional directive.
---@field conditionExpression string The condition expression string of the primary `@if` branch.
---@field elseIfBranches {conditionExpression: string, children: Node[]}[] Ordered list of `@else if` branches.
---@field elseBranch Node[]|nil Children of the `@else` fallback branch, or nil when absent.
local IfDirectiveNode = setmetatable({}, { __index = Node })
IfDirectiveNode.__index = IfDirectiveNode

---@param conditionExpression string The boolean condition expression for the `@if` branch.
---@return IfDirectiveNode
function IfDirectiveNode.new(conditionExpression)
  local self = Node.new(Node.TYPE_IF_DIRECTIVE)
  setmetatable(self, IfDirectiveNode)
  self.conditionExpression = conditionExpression or ""
  self.elseIfBranches = {}
  self.elseBranch = nil
  return self
end

---@param conditionExpression string The condition expression for this `@else if` branch.
---@param children Node[]|nil The child nodes to render when this branch matches.
function IfDirectiveNode:addElseIfBranch(conditionExpression, children)
  table.insert(self.elseIfBranches, {
    conditionExpression = conditionExpression,
    children = children or {},
  })
end

---@param children Node[]|nil The child nodes to render in the `@else` fallback branch.
function IfDirectiveNode:setElseBranch(children)
  self.elseBranch = children or {}
end

return IfDirectiveNode
