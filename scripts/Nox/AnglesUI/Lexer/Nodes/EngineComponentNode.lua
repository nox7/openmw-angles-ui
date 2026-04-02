local Node = require("scripts.Nox.AnglesUI.Lexer.Nodes.Node")
local ComponentNode = require("scripts.Nox.AnglesUI.Lexer.Nodes.ComponentNode")

---@class EngineComponentNode : ComponentNode Engine-owned element whose tag name starts with "mw-" (e.g. mw-flex, mw-text).
local EngineComponentNode = setmetatable({}, { __index = ComponentNode })
EngineComponentNode.__index = EngineComponentNode

---@param tagName string The "mw-" prefixed tag name.
---@param attributes table<string, any>|nil Attribute map.
---@param selfClosing boolean|nil Whether the tag is self-closing.
---@return EngineComponentNode
function EngineComponentNode.new(tagName, attributes, selfClosing)
  local self = ComponentNode.new(tagName, attributes, selfClosing)
  setmetatable(self, EngineComponentNode)
  self.type = Node.TYPE_ENGINE_COMPONENT
  return self
end

return EngineComponentNode
