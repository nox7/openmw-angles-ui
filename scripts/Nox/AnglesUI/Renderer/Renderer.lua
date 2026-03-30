local AcceptedEngineTagNames = require("scripts.Nox.AnglesUI.AcceptedEngineTagNames")
local SupportedElementProperties = require("scripts.Nox.AnglesUI.SupportedElementProperties")
local Lexer = require("scripts.Nox.AnglesUI.Lexer.Lexer")
local Evaluator = require("scripts.Nox.AnglesUI.Evaluator.Evaluator")
local Context = require("scripts.Nox.AnglesUI.Evaluator.Context")
local UI = require("openmw.ui");
local Util = require('openmw.util')
local Core = require("openmw.core")
local MWUI = require('openmw.interfaces').MWUI
local Node = require("scripts.Nox.AnglesUI.Lexer.Nodes.Node")
local TableUtils = require("scripts.Nox.Utils.TableUtils")
local VFS = require('openmw.vfs')

-- The user's menu transparency setting from the Settings::gui().mTransparencyAlpha value
local menuTransparencyAlphaValue = UI._getMenuTransparency()

local Renderer = {}
Renderer.__index = Renderer

-- Returns true if the tag name is an accepted engine tag
Renderer.IsValidEngineTag = function(tagName)
  for _, acceptedTag in pairs(AcceptedEngineTagNames) do
    if (acceptedTag == tagName) then
      return true
    end
  end

  return false
end

-- Creates a render from a virtual file path
function Renderer.FromFile(vfsPath, userComponents)
  local file = VFS.open(vfsPath)
  if (file == nil) then
    error("Could not find file at path: " .. vfsPath)
  end

  local source = file:read("*a")
  file:close()
  return Renderer.New(source, userComponents)
end

function Renderer.New(source, userComponents)
  local self = setmetatable({}, Renderer)
  self.source = source
  self.userComponents = userComponents or {}
  return self
end

function Renderer:ToNumber(value, propertyName)
  if (value == nil) then
    return nil
  end

  if (type(value) == "number") then
    return value
  end

  if (type(value) == "string") then
    local parsed = tonumber(value)
    if (parsed ~= nil) then
      return parsed
    end
  end

  error("Invalid number value for property '" .. propertyName .. "': " .. tostring(value))
end

function Renderer:ToBoolean(value, propertyName)
  if (value == nil) then
    return nil
  end

  if (type(value) == "boolean") then
    return value
  end

  if (type(value) == "string") then
    if (value == "true") then
      return true
    end

    if (value == "false") then
      return false
    end
  end

  error("Invalid boolean value for property '" .. propertyName .. "': " .. tostring(value))
end

function Renderer:AppendChildren(layout, childLayouts)
  if (#childLayouts <= 0) then
    return
  end

  if (layout.content == nil) then
    layout.content = UI.content(childLayouts)
  else
    for _, childLayout in pairs(childLayouts) do
      layout.content:add(childLayout)
    end
  end
end

function Renderer:ApplyPaddingContainer(layout, childLayouts, parsedPadding)
  if (#childLayouts <= 0) then
    return
  end

  local paddedContainer = {
    props = {
      relativeSize = Util.vector2(1, 1),
      size = Util.vector2(-(parsedPadding.Left + parsedPadding.Right), -(parsedPadding.Top + parsedPadding.Bottom)),
      position = Util.vector2(parsedPadding.Left, parsedPadding.Top),
    },
    content = UI.content(childLayouts)
  }

  self:AppendChildren(layout, { paddedContainer })
end

function Renderer:ArrangeFlexChildren(childLayouts, direction, gap)
  local childCount = #childLayouts
  if (childCount == 0) then
    return childLayouts
  end

  local resolvedDirection = direction or "column"
  local resolvedGap = gap or 0

  for i, child in ipairs(childLayouts) do
    child.props = child.props or {}

    local hasPosition = child.props.position ~= nil
    local hasRelativePosition = child.props.relativePosition ~= nil
    local hasSize = child.props.size ~= nil
    local hasRelativeSize = child.props.relativeSize ~= nil

    print(child.props.size)

    if (not hasRelativePosition and not hasPosition) then
      if (resolvedDirection == "row") then
        child.props.relativePosition = Util.vector2((i - 1) / childCount, 0)
      else
        child.props.relativePosition = Util.vector2(0, (i - 1) / childCount)
      end
    end

    if (not hasSize and not hasRelativeSize) then
      if (resolvedDirection == "row") then
        child.props.relativeSize = Util.vector2(1 / childCount, 1)
      else
        child.props.relativeSize = Util.vector2(1, 1 / childCount)
      end
    end

    if (resolvedGap > 0 and not hasPosition) then
      if (resolvedDirection == "row") then
        child.props.position = Util.vector2((i - 1) * resolvedGap, 0)
      else
        child.props.position = Util.vector2(0, (i - 1) * resolvedGap)
      end
    end
  end

  return childLayouts
end

function Renderer:ApplyCustomFlexContainer(layout, childLayouts, meta)
  local arrangedChildren = self:ArrangeFlexChildren(childLayouts, meta.direction, meta.gap)

  local paddedContainer = {
    props = {
      relativeSize = Util.vector2(1, 1),
      size = Util.vector2(-(meta.padding.Left + meta.padding.Right), -(meta.padding.Top + meta.padding.Bottom)),
      position = Util.vector2(meta.padding.Left, meta.padding.Top),
    },
    content = UI.content(arrangedChildren)
  }

  self:AppendChildren(layout, { paddedContainer })
end

-- Renders the provided source code and components onto the screen.
-- This returns the OpenMW Lua UI root element after it is called.
function Renderer:Render(userContext)
  local lexer = Lexer.new(self.source)
  local ast = lexer:parse()
  local evaluator = Evaluator.new()
  local context = Context.new(userContext)
  local rootNode = evaluator:evaluate(ast, context)

  -- TODO
  -- Run an Effect() on all userContexts that are signals, so that when they update we can destroy the uiElement and re-render
  -- a new one with updated values.

  if (#rootNode.children > 0) then
    local firstNode = rootNode.children[1]
    if (firstNode.type == Node.TYPE_ENGINE_COMPONENT) then
      if (firstNode.tagName == "mw-root") then
        local rootLayout = self:BuildLayoutTree(firstNode)
        local uiElement = UI.create(rootLayout)
        uiElement:update()
        return uiElement
      else
        error("The first component of a rendered template must be a mw-root element. You provided a " .. firstNode.tagName);
      end
    else
      error("The first component of a rendered template must be a mw-root element. You provided a " .. firstNode.type);
    end
  else
    error("Cannot render a blank template.")
  end
end

function Renderer:BuildLayoutTree(node)
  local layout, meta = self:GetEngineUIElement(node)
  local childLayouts = {}

  if (#node.children > 0) then
    for _, childNode in pairs(node.children) do
      if (childNode.type == Node.TYPE_ENGINE_COMPONENT) then
        table.insert(childLayouts, self:BuildLayoutTree(childNode))
      end
    end
  end

  if (meta ~= nil and meta.type == "custom-flex") then
    self:ApplyCustomFlexContainer(layout, childLayouts, meta)
  elseif (meta ~= nil and meta.type == "padding-container") then
    self:ApplyPaddingContainer(layout, childLayouts, meta.padding)
  else
    self:AppendChildren(layout, childLayouts)
  end

  return layout
end

function Renderer:ApplyCommonWidgetProperties(allProperties, options)
  local props = {}

  local width = self:ToNumber(allProperties["width"], "Width")
  local height = self:ToNumber(allProperties["height"], "Height")
  local relativeWidth = self:ToNumber(allProperties["relativewidth"], "RelativeWidth")
  local relativeHeight = self:ToNumber(allProperties["relativeheight"], "RelativeHeight")
  local relativeX = self:ToNumber(allProperties["relativex"], "RelativeX")
  local relativeY = self:ToNumber(allProperties["relativey"], "RelativeY")
  local xPos = self:ToNumber(allProperties["x"], "X")
  local yPos = self:ToNumber(allProperties["y"], "Y")
  local anchorX = self:ToNumber(allProperties["anchorx"], "AnchorX")
  local anchorY = self:ToNumber(allProperties["anchory"], "AnchorY")
  local visible = self:ToBoolean(allProperties["visible"], "Visible")

  local requireSize = options ~= nil and options.requireSize == true
  local defaultRelativeSize = options ~= nil and options.defaultRelativeSize == true

  if (requireSize and (width == nil or height == nil) and (relativeWidth == nil or relativeHeight == nil)) then
    error("Element must have either Width/Height or RelativeWidth/RelativeHeight attributes.")
  end

  if (defaultRelativeSize and (width == nil or height == nil) and (relativeWidth == nil or relativeHeight == nil)) then
    relativeWidth = 1
    relativeHeight = 1
  end

  if (width ~= nil and height ~= nil) then
    props.size = Util.vector2(width, height)
  end

  if (relativeWidth ~= nil and relativeHeight ~= nil) then
    props.relativeSize = Util.vector2(relativeWidth, relativeHeight)
  end

  if (xPos ~= nil and yPos ~= nil) then
    props.position = Util.vector2(xPos, yPos)
  end

  if (relativeX ~= nil and relativeY ~= nil) then
    props.relativePosition = Util.vector2(relativeX, relativeY)
  end

  if (anchorX ~= nil and anchorY ~= nil) then
    props.anchor = Util.vector2(anchorX, anchorY)
  end

  if (visible ~= nil) then
    props.visible = visible
  end

  return props
end

-- Gets the engine UI element that corresponds to a tag name.
function Renderer:GetEngineUIElement(node)
  if (node.type ~= Node.TYPE_ENGINE_COMPONENT) then
    error("Cannot render node of type " .. node.type)
  end

  local tagName = node.tagName
  if (not Renderer.IsValidEngineTag(tagName)) then
    error(tagName .. " is not a valid engine tag.")
  end

  local allProperties = self:ParseAcceptedProperties(node)
  local name = allProperties["name"]

  if (tagName == "mw-root") then
    local layer = allProperties["layer"]
    if (layer == nil) then
      error("mw-root elements must have a 'Layer' attribute.")
    end

    local props = self:ApplyCommonWidgetProperties(allProperties, { requireSize = true })

    return {
      layer = layer,
      name = name,
      props = props,
    }, nil
  elseif (tagName == "mw-window") then
    return {
      name = name,
      props = {
        relativeSize = Util.vector2(1, 1),
      },
      content = UI.content({
        {
          type = UI.TYPE.Image,
          props = {
            resource = UI.texture({
              path = "black"
            }),
            alpha = menuTransparencyAlphaValue,
            relativeSize = Util.vector2(1, 1)
          }
        },
        {
          template = MWUI.templates.bordersThick,
          props = {
            relativeSize = Util.vector2(1, 1),
          },
        },
      })
    }, nil
  elseif (tagName == "mw-flex") then
    local props = self:ApplyCommonWidgetProperties(allProperties, { defaultRelativeSize = true })
    local parsedPadding = allProperties["parsedpadding"] or {
      Top = 0,
      Right = 0,
      Bottom = 0,
      Left = 0,
    }

    return {
      name = name,
      props = props,
    }, {
      type = "custom-flex",
      direction = allProperties["direction"] or "column",
      gap = self:ToNumber(allProperties["gap"], "Gap") or 0,
      padding = parsedPadding,
    }
  elseif (tagName == "mw-text") then
    local props = {}

    local textNodesText = ""
    local textColorAttribute = node:getAttribute("textcolor")

    if (textColorAttribute ~= nil) then
      local r, g, b = string.match(textColorAttribute, "rgb%((%d+),(%d+),(%d+)%)")
      if (r ~= nil and g ~= nil and b ~= nil) then
        props.textColor = Util.color.rgb(tonumber(r), tonumber(g), tonumber(b))
      end
    end

    for _, childNode in pairs(node.children) do
      if (childNode.type == Node.TYPE_TEXT) then
        textNodesText = textNodesText .. childNode.text
      else
        error("Only text nodes are allowed in mw-text elements. Encountered a node of type: " .. childNode.type)
      end
    end

    props.text = textNodesText
    props.autoSize = true

    return {
      name = name,
      type = UI.TYPE.Text,
      template = MWUI.templates.textNormal,
      props = props
    }, nil
  elseif (tagName == "mw-hr") then
    return {
      name = name,
      template = MWUI.templates.horizontalLine,
      props = {}
    }, nil
  elseif (tagName == "mw-widget") then
    local props = self:ApplyCommonWidgetProperties(allProperties, nil)
    local parsedPadding = allProperties["parsedpadding"]

    if (parsedPadding ~= nil) then
      return {
        name = name,
        props = props,
      }, {
        type = "padding-container",
        padding = parsedPadding,
      }
    end

    return {
      name = name,
      props = props,
    }, nil
  end
end

-- Gets all accepted properties for the node element
-- If necessary, parses the properties in correct order so that
-- their integrity is maintained (e.g. padding needs to be parsed before we can calculate size and position)
function Renderer:ParseAcceptedProperties(node)
  local properties = {}

  local supported = SupportedElementProperties[node.tagName]
  if (supported ~= nil) then
    if (node.tagName == "mw-flex" or node.tagName == "mw-widget") then
      local padding = node:getAttribute("padding")
      if (padding ~= nil) then
        properties["padding"] = padding
        properties["parsedpadding"] = self:ParsePadding(padding)
      end
    end

    for _, propertyName in pairs(supported) do
      local loweredPropertyName = string.lower(propertyName)
      local attributeValue = node:getAttribute(loweredPropertyName)
      if (attributeValue ~= nil) then
        properties[loweredPropertyName] = attributeValue
      end
    end
  end

  return properties
end

-- Parses a string that can contain between 1 and 4 numbers
-- Parses it in CSS-format
-- Always return a table with keys "Top, Right, Bottom, Left"
function Renderer:ParsePadding(paddingString)
  if (type(paddingString) ~= "string") then
    error("Padding must be provided as a string.")
  end

  local trimmed = paddingString:match("^%s*(.-)%s*$")
  if (trimmed == "") then
    error("Padding string cannot be empty.")
  end

  local values = {}
  for token in string.gmatch(trimmed, "%S+") do
    if (not string.match(token, "^%d+$")) then
      error("Invalid padding value '" .. token .. "'. Padding must contain whole numbers only.")
    end

    table.insert(values, tonumber(token))
  end

  if (#values < 1 or #values > 4) then
    error("Padding must contain between 1 and 4 values.")
  end

  local top, right, bottom, left
  if (#values == 1) then
    top = values[1]
    right = values[1]
    bottom = values[1]
    left = values[1]
  elseif (#values == 2) then
    top = values[1]
    right = values[2]
    bottom = values[1]
    left = values[2]
  elseif (#values == 3) then
    top = values[1]
    right = values[2]
    bottom = values[3]
    left = values[2]
  else
    top = values[1]
    right = values[2]
    bottom = values[3]
    left = values[4]
  end

  return {
    Top = top,
    Right = right,
    Bottom = bottom,
    Left = left,
  }
end

return Renderer