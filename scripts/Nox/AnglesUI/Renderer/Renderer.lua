local AcceptedEngineTagNames = require("scripts.Nox.AnglesUI.AcceptedEngineTagNames")
local Lexer = require("scripts.Nox.AnglesUI.Lexer.Lexer")
local Evaluator = require("scripts.Nox.AnglesUI.Evaluator.Evaluator")
local Context = require("scripts.Nox.AnglesUI.Evaluator.Context")
local UI = require("openmw.ui");
local Util = require('openmw.util')
local Core = require("openmw.core")
local MWUI = require('openmw.interfaces').MWUI
local Node = require("scripts.Nox.AnglesUI.Lexer.Nodes.Node")
local TableUtils = require("scripts.Nox.Utils.TableUtils")

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

function Renderer.new(source, userComponents)
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

  if (#rootNode.children > 0) then
    local firstNode = rootNode.children[1]
    if (firstNode.type == Node.TYPE_ENGINE_COMPONENT) then
      if (firstNode.tagName == "mw-root") then
        local uiElement = self:RenderChildren(firstNode, nil)
        uiElement:update()
        print("Rendered " .. tostring(uiElement))
        TableUtils.PrintTable(uiElement.layout)
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
      if (tagName == "mw-root") then
        return {
          layer = node:getAttribute("layer"),
          props = {
            size = Util.vector2(800, 400),
            relativePosition = Util.vector2(0.5, 0),
            anchor = Util.vector2(0,0),
          }
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

        return {
          type = UI.TYPE.Flex,
          props = {
            relativeSize = Util.vector2(1,1),
            size = Util.vector2(0,0) - Util.vector2(parsedPadding.Left + parsedPadding.Right, parsedPadding.Top + parsedPadding.Bottom),
            position = Util.vector2(parsedPadding.Left, parsedPadding.Top)
          }
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