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
        local uiElement = self:RenderChildren(firstNode, nil)
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

-- Renders child nodes. If there is a parentUIElement, then they will be added to that
-- parentUIElement.content property
function Renderer:RenderChildren(node, parentUIElement)
  local engineUIElement = self:GetEngineUIElement(node)
  local childUIElements = {}

  if (#node.children > 0) then
    for _, childNode in pairs(node.children) do
      if (childNode.type == Node.TYPE_ENGINE_COMPONENT) then
        table.insert(childUIElements, self:RenderChildren(childNode, engineUIElement))
      end
    end
  end

  if (node.tagName == "mw-root") then
    -- Create a UiElement
    engineUIElement.content = UI.content(childUIElements)
    local uiElement = UI.create(engineUIElement)
    return uiElement
  else
    if (engineUIElement.content == nil) then
      engineUIElement.content = UI.content(childUIElements)
    else
      for _, childUIElement in pairs(childUIElements) do
        engineUIElement.content:add(childUIElement)
      end
    end
    return engineUIElement
  end
end

-- Gets the engine UI element that corresponds to a tag name.
function Renderer:GetEngineUIElement(node)
  if (node.type == Node.TYPE_ENGINE_COMPONENT) then
    local tagName = node.tagName
    if (Renderer.IsValidEngineTag(tagName)) then
      local allProperties = self:ParseAcceptedProperties(node)
      if (tagName == "mw-root") then
        local layer = allProperties["layer"]
        local width = allProperties["width"]
        local height = allProperties["height"]
        local relativeWidth = allProperties["relativewidth"]
        local relativeHeight = allProperties["relativeheight"]
        local relativeX = allProperties["relativex"]
        local relativeY = allProperties["relativey"]
        local xPos = allProperties["x"]
        local yPos = allProperties["y"]
        
        if (layer == nil) then
          error("mw-root elements must have a 'Layer' attribute.")
        end

        if ( (width == nil or height == nil) and (relativeWidth == nil or relativeHeight == nil)) then
          error("mw-root elements must have 'Width' and 'Height' attributes or 'RelativeWidth' and 'RelativeHeight' attributes.")
        end

        local props = {}

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

        return {
          layer = layer,
          props = props
        }
      elseif (tagName == "mw-window") then
        return {
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
                relativeSize = Util.vector2(1,1),
              },
            },
          })
        }
      elseif (tagName == "mw-flex") then
        -- If there is padding, then parse it and apply it to the relativeSize, size, and position accordingly
        local padding = node:getAttribute("padding")
        local parsedPadding = self:ParsePadding(padding or "0")
        -- We check for parsedPadding and not padding
        local parsedPadding = allProperties["parsedpadding"]
        local relativeWidth = allProperties["relativewidth"]
        local relativeHeight = allProperties["relativeheight"]
        local width = allProperties["width"]
        local height = allProperties["height"]
        local relativeX = allProperties["relativex"]
        local relativeY = allProperties["relativey"]
        local xPos = allProperties["x"]
        local yPos = allProperties["y"]

        if ( (width == nil or height == nil) and (relativeWidth == nil or relativeHeight == nil)) then
          -- In this case, default-set the relativeWidth and relativeHeight to 1. Common users will assume
          -- that a flex element expands to fit its container from web standards.
          relativeWidth = 1;
          relativeHeight = 1;
        end

        local props = {}

        if (relativeWidth ~= nil and relativeHeight ~= nil) then
          props.relativeSize = Util.vector2(relativeWidth, relativeHeight)
        end

        if (width ~= nil and height ~= nil) then
          props.size = Util.vector2(width, height)
          if (parsedPadding ~= nil) then
            props.size = props.size - Util.vector2(parsedPadding.Left + parsedPadding.Right, parsedPadding.Top + parsedPadding.Bottom)
          end
        else
          if (parsedPadding ~= nil) then
            props.size = Util.vector2(-parsedPadding.Left - parsedPadding.Right, -parsedPadding.Top - parsedPadding.Bottom)
          end
        end

        if (relativeX ~= nil and relativeY ~= nil) then
          props.relativePosition = Util.vector2(relativeX, relativeY)
        end

        if (xPos ~= nil and yPos ~= nil) then
          props.position = Util.vector2(xPos, yPos)
          if (parsedPadding ~= nil) then
            props.position = props.position + Util.vector2(parsedPadding.Left, parsedPadding.Top)
          end
        else
          if (parsedPadding ~= nil) then
            props.position = Util.vector2(parsedPadding.Left, parsedPadding.Top)
          end
        end

        return {
          type = UI.TYPE.Flex,
          props = props
        }
      elseif (tagName == "mw-text") then
        local textNodesText = ""
        local r, g, b = nil, nil, nil
        local textColorAttribute = node:getAttribute("textColor")
        
        if (textColorAttribute ~= nil) then
          print(textColorAttribute)
          local r, g, b = string.match(textColorAttribute, "rgb%((%d+),(%d+),(%d+)%)")
        end

        for _, node in pairs(node.children) do
          if (node.type == Node.TYPE_TEXT) then
            textNodesText = textNodesText .. node.text
          else 
            error("Only text nodes are allowed in mw-text elements. Encountered a node of type: " .. node.type)
          end
        end

        print(r, g, b)

        return {
          type = UI.TYPE.Text,
          template = MWUI.templates.textNormal,
          props = {
            -- textSize = node:getAttribute("textSize") or 24,
            -- textColor = (r and g and b) and Util.color.rgb(r, g, b) or Util.color.rgb(0,1,0),
            text = textNodesText,
            relativeSize = Util.vector2(1, 1),
          }
        }
      end
    else
      error(tagName .. " is not a valid engine tag.")
    end
  else
    error("Cannot render node of type " .. node.type)
  end
end

-- Gets all accepted properties for the node element
-- If necessary, parses the properties in correct order so that
-- their integrity is maintained (e.g. padding needs to be parsed before we can calculate size and position)
function Renderer:ParseAcceptedProperties(node)
  local properties = {}
  if (node.tagName == "mw-root") then
    for _, propertyName in pairs(SupportedElementProperties["mw-root"]) do
      local loweredPropertyName = string.lower(propertyName)
      local attributeValue = node:getAttribute(loweredPropertyName)
      if (attributeValue ~= nil) then
        properties[loweredPropertyName] = attributeValue
      end
    end
  elseif (node.tagName == "mw-window") then

  elseif (node.tagName == "mw-flex") then
    -- We need to parse padding before we can calculate size and position, so we do that first
    local padding = node:getAttribute("padding")
    if (padding ~= nil) then
      properties["padding"] = padding
      local parsedPadding = self:ParsePadding(padding)
      properties["parsedpadding"] = parsedPadding
    end
    for _, propertyName in pairs(SupportedElementProperties["mw-flex"]) do
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