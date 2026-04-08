local Node = require("scripts.Nox.AnglesUI.Lexer.Nodes.Node")

---@class ContentProjectionNode : Node Represents an `<mw-content>` slot that projects content from the parent component's children.
---@field select string|nil Optional CSS-style tag name selector restricting which projected children fill this slot.
local ContentProjectionNode = setmetatable({}, { __index = Node })
ContentProjectionNode.__index = ContentProjectionNode

---@param select string|nil The tag name to filter projected children by, or nil to accept all children.
---@return ContentProjectionNode
function ContentProjectionNode.new(select)
  local self = Node.new(Node.TYPE_CONTENT_PROJECTION)
  setmetatable(self, ContentProjectionNode)
  self.select = select or nil
  return self
end

return ContentProjectionNode
