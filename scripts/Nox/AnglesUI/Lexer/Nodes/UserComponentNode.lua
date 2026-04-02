local Node = require("scripts.Nox.AnglesUI.Lexer.Nodes.Node")
local ComponentNode = require("scripts.Nox.AnglesUI.Lexer.Nodes.ComponentNode")

---@class UserComponentNode : ComponentNode Represents a user-registered component element. Its template is parsed and inlined during evaluation.
---@field templateContent string The raw HTML template source for this component.
local UserComponentNode = setmetatable({}, { __index = ComponentNode })
UserComponentNode.__index = UserComponentNode

---@param tagName string The custom element tag name (e.g. "test-grid").
---@param attributes table<string, any>|nil Attribute map from the HTML element.
---@param selfClosing boolean|nil Whether the element is self-closing.
---@param templateContent string|nil The raw HTML source of this component's template.
---@return UserComponentNode
function UserComponentNode.new(tagName, attributes, selfClosing, templateContent)
  local self = ComponentNode.new(tagName, attributes, selfClosing)
  setmetatable(self, UserComponentNode)
  self.type = Node.TYPE_USER_COMPONENT
  self.templateContent = templateContent or ""
  return self
end

return UserComponentNode
