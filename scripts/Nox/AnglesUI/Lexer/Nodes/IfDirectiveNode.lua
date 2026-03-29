local Node = require("scripts.Nox.AnglesUI.Lexer.Nodes.Node")

local IfDirectiveNode = setmetatable({}, { __index = Node })
IfDirectiveNode.__index = IfDirectiveNode

function IfDirectiveNode.new(conditionExpression)
  local self = Node.new(Node.TYPE_IF_DIRECTIVE)
  setmetatable(self, IfDirectiveNode)
  self.conditionExpression = conditionExpression or ""
  self.elseIfBranches = {}
  self.elseBranch = nil
  return self
end

function IfDirectiveNode:addElseIfBranch(conditionExpression, children)
  table.insert(self.elseIfBranches, {
    conditionExpression = conditionExpression,
    children = children or {},
  })
end

function IfDirectiveNode:setElseBranch(children)
  self.elseBranch = children or {}
end

return IfDirectiveNode
