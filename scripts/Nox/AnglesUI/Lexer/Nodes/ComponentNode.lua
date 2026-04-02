local Node = require("scripts.Nox.AnglesUI.Lexer.Nodes.Node")

---@class ComponentNode : Node Represents an HTML-like component element with a tag name, attributes, and children.
---@field tagName string The element tag name (e.g. "mw-flex", "test-grid").
---@field attributes table<string, any> Map of lowercase attribute name to its raw or evaluated value.
---@field selfClosing boolean Whether the element was written with a self-closing `/>` tag.
local ComponentNode = setmetatable({}, { __index = Node })
ComponentNode.__index = ComponentNode

---@param tagName string The element tag name.
---@param attributes table<string, any>|nil Initial attribute map (defaults to empty).
---@param selfClosing boolean|nil Whether the tag is self-closing (defaults to false).
---@return ComponentNode
function ComponentNode.new(tagName, attributes, selfClosing)
  local self = Node.new(Node.TYPE_COMPONENT)
  setmetatable(self, ComponentNode)
  self.tagName = tagName or ""
  self.attributes = attributes or {}
  self.selfClosing = selfClosing or false
  return self
end

---@param name string Attribute name.
---@param value any Attribute value to store.
function ComponentNode:setAttribute(name, value)
  self.attributes[name] = value
end

---@param name string Attribute name.
---@return any The stored attribute value, or nil if not present.
function ComponentNode:getAttribute(name)
  return self.attributes[name]
end

return ComponentNode
