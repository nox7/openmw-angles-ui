local Node = require("scripts.Nox.AnglesUI.Lexer.Nodes.Node")

---@class HostElementNode : Node Represents an `<mw-host>` wrapper that receives event bindings from the parent component's instantiation tag.
-- Children are the component's actual template content; they are rendered inside
-- the mw-widget host wrapper that the Evaluator produces for this node.
local HostElementNode = setmetatable({}, { __index = Node })
HostElementNode.__index = HostElementNode

---@return HostElementNode
function HostElementNode.new()
  local self = Node.new(Node.TYPE_HOST_ELEMENT)
  setmetatable(self, HostElementNode)
  return self
end

return HostElementNode
