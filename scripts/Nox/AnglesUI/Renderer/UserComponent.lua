local CSSParser = require("scripts.Nox.AnglesUI.CSSParser.CSSParser")

---@class UserComponent Represents a registered user component for use in the renderer.
---@field public string selector
---@field public string htmlSource
---@field public string cssSource
local UserComponent = {}
UserComponent.__index = UserComponent

function UserComponent.New(selector, htmlSource, cssSource)
  local self = setmetatable({}, UserComponent)
  self.selector = selector
  self.htmlSource = htmlSource
  self.cssSource = cssSource
  self.cssModel = CSSParser.New():Parse(cssSource)
  return self
end

return UserComponent