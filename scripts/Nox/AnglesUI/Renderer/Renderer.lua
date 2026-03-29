local AcceptedEngineTagNames = require("scripts.Nox.AnglesUI.AcceptedEngineTagNames")
local Lexer = require("scripts.Nox.AnglesUI.Lexer.Lexer")
local Evaluator = require("scripts.Nox.AnglesUI.Evaluator.Evaluator")
local Context = require("scripts.Nox.AnglesUI.Evaluator.Context")
local UI = require("openmw.ui");
local Util = require('openmw.util')
local MWUI = require('openmw.interfaces').MWUI
local Node = require("scripts.Nox.AnglesUI.Lexer.Nodes.Node")
local TableUtils = require("scripts.Nox.Utils.TableUtils")

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
        return {
          type = UI.TYPE.Flex,
        }
      elseif (tagName == "mw-padding") then
        return {
          template = MWUI.templates.padding,
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
            textSize = node:getAttribute("textSize") or 24,
            textColor = (r and g and b) and Util.color.rgb(r, g, b) or Util.color.rgb(0,1,0),
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

return Renderer