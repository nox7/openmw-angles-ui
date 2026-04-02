local CSSParser = require("scripts.Nox.AnglesUI.CSSParser.CSSParser")

---@class UserComponent Represents a registered user component for use in the renderer.
---@field public string selector
---@field public string htmlSource
---@field public string cssSource
local UserComponent = {}
UserComponent.__index = UserComponent

---@param selector string The CSS-selector-like tag name this component is registered under (e.g. "test-grid").
---@param htmlSource string The raw HTML template source for the component.
---@param cssSource string|nil Optional CSS source associated with the component's template.
---@return UserComponent
function UserComponent.New(selector, htmlSource, cssSource)
  local self = setmetatable({}, UserComponent)
  self.selector = selector
  self.htmlSource = htmlSource
  self.cssSource = cssSource
  self.cssModel = CSSParser.New():Parse(cssSource)
  return self
end

return UserComponent