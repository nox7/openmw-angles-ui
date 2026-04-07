local AcceptedEngineTagNames = require("scripts.Nox.AnglesUI.AcceptedEngineTagNames")
local SupportedElementProperties = require("scripts.Nox.AnglesUI.SupportedElementProperties")
local Lexer = require("scripts.Nox.AnglesUI.Lexer.Lexer")
local Evaluator = require("scripts.Nox.AnglesUI.Evaluator.Evaluator")
local Context = require("scripts.Nox.AnglesUI.Evaluator.Context")
local CSSParser = require("scripts.Nox.AnglesUI.CSSParser.CSSParser")
local UI = require("openmw.ui");
local Util = require('openmw.util')
local Core = require("openmw.core")
local MWUI = require('openmw.interfaces').MWUI
local Node = require("scripts.Nox.AnglesUI.Lexer.Nodes.Node")
local TableUtils = require("scripts.Nox.Utils.TableUtils")
local VFS = require('openmw.vfs')
local async = require('openmw.async')
local UserComponent = require("scripts.Nox.AnglesUI.Renderer.UserComponent")
local Signal = require("scripts.Nox.AnglesUI.Signals.Signal")
local TextUtility = require("scripts.Nox.AnglesUI.Utilities.TextUtility")

-- The user's menu transparency setting from the Settings::gui().mTransparencyAlpha value
local menuTransparencyAlphaValue = UI._getMenuTransparency()

-- Fallback height used for mw-text children inside a scroll canvas that have no
-- explicit size set (autoSize means OpenMW computes the real size at render time,
-- so we estimate using this value when calculating scroll content bounds).
local defaultTextSize = 16

-- Mapping from CSS property names to our lowercased HTML attribute names
local CSS_PROPERTY_TO_ATTRIBUTE = {
  ["padding"]             = "padding",
  ["color"]               = "textcolor",
  ["font-size"]           = "textsize",
  ["background"]          = "background",
  ["grid-template-columns"] = "gridtemplatecolumns",
  ["grid-template-rows"]  = "gridtemplaterows",
  ["grid-column"]         = "gridcolumn",
  ["grid-row"]            = "gridrow",
  ["flex-grow"]           = "grow",
  ["width"]               = "width",
  ["height"]              = "height",
  ["gap"]                 = "gap",
  ["flex-direction"]      = "direction",
  ["container-type"]      = "containertype",
  ["container-name"]      = "containername",
  ["scrollbar-width"]     = "scrollbarsize",
  ["opacity"]             = "alpha",
  ["visibility"]          = "visibility",
  ["text-align"]          = "textalign",
  ["vertical-align"]      = "verticalalign",
  ["aspect-ratio"]        = "aspectratio",
  ["align-items"]         = "alignitems",
  ["justify-content"]     = "justifycontent",
  ["left"]                = "left",
  ["top"]                 = "top",
  ["right"]               = "right",
  ["bottom"]              = "bottom",
}

-- Maps the lowercased JS-style property name from a [style.X] binding to the
-- internal attribute key used throughout the renderer.  Camelcase is collapsed
-- to lowercase before the lookup (e.g. "flexGrow" -> "flexgrow").
local STYLE_BINDING_TO_ATTRIBUTE = {
  ["height"]              = "height",
  ["width"]               = "width",
  ["padding"]             = "padding",
  ["gap"]                 = "gap",
  ["rowgap"]              = "rowgap",
  ["columngap"]           = "columngap",
  ["color"]               = "textcolor",
  ["textcolor"]           = "textcolor",
  ["fontsize"]            = "textsize",
  ["textsize"]            = "textsize",
  ["background"]          = "background",
  ["flexgrow"]            = "grow",
  ["grow"]                = "grow",
  ["flexdirection"]       = "direction",
  ["direction"]           = "direction",
  ["gridtemplatecolumns"] = "gridtemplatecolumns",
  ["gridtemplaterows"]    = "gridtemplaterows",
  ["gridcolumn"]          = "gridcolumn",
  ["gridrow"]             = "gridrow",
  ["gridcolumnspan"]      = "gridcolumnspan",
  ["gridrowspan"]         = "gridrowspan",
  ["containertype"]       = "containertype",
  ["containername"]       = "containername",
  ["visible"]             = "visible",
  ["anchorx"]             = "anchorx",
  ["anchory"]             = "anchory",
  ["x"]                   = "x",
  ["y"]                   = "y",
  ["multiline"]           = "multiline",
  ["wordwrap"]            = "wordwrap",
  ["textshadow"]          = "textshadow",
  ["tileh"]               = "tileh",
  ["tilev"]               = "tilev",
  ["scrollbarsize"]       = "scrollbarsize",
  ["scrollstep"]          = "scrollstep",
  ["opacity"]             = "alpha",
  ["alpha"]               = "alpha",
  ["visibility"]          = "visibility",
  ["textalign"]           = "textalign",
  ["verticalalign"]       = "verticalalign",
  ["aspectratio"]         = "aspectratio",
  ["alignitems"]          = "alignitems",
  ["justifycontent"]      = "justifycontent",
  ["left"]                = "left",
  ["top"]                 = "top",
  ["right"]               = "right",
  ["bottom"]              = "bottom",
}

-- HTML attributes that are structural, behavioral, or content-related and
-- are therefore still accepted as plain HTML attributes (not [style.X]).
local NON_STYLE_ATTRIBUTES = {
  ["id"]        = true,
  ["class"]     = true,
  ["name"]      = true,
  ["layer"]     = true,
  ["resizable"] = true,
  ["dragger"]   = true,
  ["resource"]  = true,  -- mw-image texture path
  ["src"]       = true,
  ["path"]      = true,
  ["text"]        = true,  -- mw-text-edit initial content
  ["placeholder"] = true,  -- mw-text-edit placeholder text
  ["autosize"]    = true,  -- mw-text / mw-text-edit autoSize toggle
  ["scrollbarsize"] = true,  -- mw-scroll-canvas scrollbar strip width
  ["scrollstep"]    = true,  -- mw-scroll-canvas pixels scrolled per arrow click
  ["edgemargin"]    = true,  -- mw-root resize edge hit-test width in pixels
}

---@class Renderer Compiles an HTML+CSS template into a live OpenMW UI element tree.
-- Owns the full pipeline: CSS parsing, layout-tree building, flex/grid arrangement,
-- scroll-canvas construction, signal subscriptions, and incremental re-rendering.
---@field source string Raw HTML template source string.
---@field userComponents table<string, UserComponent> Map of selector to UserComponent for resolving custom element tags.
---@field cssSource string|nil Raw CSS source paired with the template.
---@field cssModel {rules: table[], mediaQueries: table[], containerQueryRules: table[]} Parsed CSS model.
---@field activeRules table[] Flat list of CSS rules active for the current screen width.
---@field activeContainerQueryRules table[] Flat list of container query rules active for the current screen width.
---@field rootLayout table|nil The live OpenMW Layout table for mw-root (mutated in-place on re-renders).
---@field rootElement table|nil The OpenMW UI element from UI.create(); call :update() to push layout changes.
---@field evaluatedRootNode Node|nil The most recently evaluated root AST node used as the source for re-renders.
local Renderer = {}
Renderer.__index = Renderer

-- Returns true if the tag name is an accepted engine tag
---@param tagName any Must be a string starting with "mw-" or listed in AcceptedEngineTagNames.
---@return boolean True when the tag is a recognised AnglesUI engine element.
Renderer.IsValidEngineTag = function(tagName)
  if (type(tagName) ~= "string") then
    return false
  end

  if (string.sub(tagName, 1, 3) == "mw-") then
    return true
  end

  for _, acceptedTag in pairs(AcceptedEngineTagNames) do
    if (acceptedTag == tagName) then
      return true
    end
  end

  return false
end

-- Creates a render from a virtual file path
-- userComponents is expected to be a table where keys are selectors
-- and values are file paths. They will get loaded into actual source code later.
---@param vfsPath string VFS-relative path to the HTML template file.
---@param userComponents table<string, string> Map of selector to VFS file path; entries are replaced in-place with UserComponent instances.
---@return Renderer
function Renderer.FromFile(vfsPath, userComponents)
  local file = VFS.open(vfsPath)
  if (file == nil) then
    error("Could not find file at path: " .. vfsPath)
  end

  local source = file:read("*a")
  file:close()

  local cssSource = nil
  local cssPath = string.gsub(vfsPath, "%.%w+$", ".css")
  if (cssPath ~= vfsPath) then
    local cssFile = VFS.open(cssPath)
    if (cssFile ~= nil) then
      cssSource = cssFile:read("*a")
      cssFile:close()
    end
  end

  -- Now, we'll iterate the userComponents (key/value pairs) and load the files
  -- With each, we'll create a new set of UserComponent objects and pass them to the new renderer
  for selector, componentPath in pairs(userComponents) do
    local componentFile = VFS.open(componentPath)
    if (componentFile == nil) then
      error("Could not find user component file at path: " .. componentPath .. " for selector: " .. selector)
    end

    local componentSource = componentFile:read("*a")
    componentFile:close()

    local componentCssSource = nil
    local componentCssPath = string.gsub(componentPath, "%.%w+$", ".css")
    if (componentCssPath ~= componentPath) then
      local componentCssFile = VFS.open(componentCssPath)
      if (componentCssFile ~= nil) then
        componentCssSource = componentCssFile:read("*a")
        componentCssFile:close()
      end
    end
    userComponents[selector] = UserComponent.New(selector, componentSource, componentCssSource)
  end

  return Renderer.New(source, userComponents, cssSource)
end

---@param source string The raw HTML template source string.
---@param userComponents table<string, UserComponent>|nil Map of selector to loaded UserComponent instances.
---@param cssSource string|nil The raw CSS source to pair with the template.
---@return Renderer
function Renderer.New(source, userComponents, cssSource)
  local self = setmetatable({}, Renderer)
  self.source = source
  self.userComponents = userComponents or {}
  self.cssSource = cssSource
  self.cssModel = CSSParser.New():Parse(cssSource)
  return self
end

---@param value any A number or a string containing a numeric literal.
---@param propertyName string Displayed in the error message on conversion failure.
---@return number|nil The numeric value, or nil when value is nil.
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

---@param value any A boolean or the strings "true"/"false".
---@param propertyName string Displayed in the error message on conversion failure.
---@return boolean|nil The boolean value, or nil when value is nil.
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

---@param value any A string: "start", "center", or "end".
---@param propertyName string Displayed in the error message on conversion failure.
---@return userdata|nil The UI.ALIGNMENT value, or nil when value is nil.
function Renderer:ToTextAlignH(value, propertyName)
  if (value == nil) then return nil end
  local s = tostring(value)
  if (s == "start") then return UI.ALIGNMENT.Start end
  if (s == "center") then return UI.ALIGNMENT.Center end
  if (s == "end") then return UI.ALIGNMENT.End end
  error("Invalid text-align value for property '" .. propertyName .. "': must be 'start', 'center', or 'end'.")
end

---@param value any A string: "top", "middle", or "bottom".
---@param propertyName string Displayed in the error message on conversion failure.
---@return userdata|nil The UI.ALIGNMENT value, or nil when value is nil.
function Renderer:ToTextAlignV(value, propertyName)
  if (value == nil) then return nil end
  local s = tostring(value)
  if (s == "top") then return UI.ALIGNMENT.Start end
  if (s == "middle") then return UI.ALIGNMENT.Center end
  if (s == "bottom") then return UI.ALIGNMENT.End end
  error("Invalid vertical-align value for property '" .. propertyName .. "': must be 'top', 'middle', or 'bottom'.")
end

---@param value any A positive number or a "W / H" division expression string (e.g. "16 / 9").
---@param propertyName string Used in error messages on parse failure.
---@return number|nil The aspect ratio (width ÷ height), or nil when value is nil.
function Renderer:ParseAspectRatio(value, propertyName)
  if (value == nil) then return nil end

  if (type(value) == "number") then
    if (value <= 0) then
      error("Invalid aspect-ratio value for property '" .. propertyName .. "': must be a positive number.")
    end
    return value
  end

  if (type(value) == "string") then
    local n = tonumber(value)
    if (n ~= nil) then
      if (n <= 0) then
        error("Invalid aspect-ratio value for property '" .. propertyName .. "': must be a positive number.")
      end
      return n
    end

    local a, b = string.match(value, "^%s*([%d%.]+)%s*/%s*([%d%.]+)%s*$")
    if (a ~= nil and b ~= nil) then
      local na, nb = tonumber(a), tonumber(b)
      if (na ~= nil and nb ~= nil and nb > 0) then
        return na / nb
      end
    end
  end

  error("Invalid aspect-ratio value for property '" .. propertyName .. "': expected a positive number or 'W / H' expression, got '" .. tostring(value) .. "'.")
end

---@param layout table The OpenMW Layout table to receive children.
---@param childLayouts table[] Child Layout tables to append.
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

---@param layout table The outer Layout table.
---@param childLayouts table[] Children to place inside the padded inner container.
---@param parsedPadding {Top: number, Right: number, Bottom: number, Left: number} Pixel padding values.
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

---@param absoluteSize number|nil Pixel size component (from `size.x` or `size.y`).
---@param relativeSize number|nil Fractional component 0–1 (from `relativeSize.x` or `relativeSize.y`).
---@param parentAxisSize number|nil Parent's pixel size along this axis.
---@return number|nil Resolved pixel size, or nil when information is insufficient.
function Renderer:ResolveAxisSize(absoluteSize, relativeSize, parentAxisSize)
  if (relativeSize ~= nil and parentAxisSize ~= nil) then
    return (absoluteSize or 0) + (relativeSize * parentAxisSize)
  end

  if (absoluteSize ~= nil) then
    return absoluteSize
  end

  return nil
end

---@param layout table An OpenMW Layout table with optional `props.size` and `props.relativeSize`.
---@param parentPixelSize {x: number|nil, y: number|nil}|nil The parent's resolved pixel size.
---@return {x: number|nil, y: number|nil} Resolved pixel size; axes may be nil when unresolvable.
function Renderer:ResolveLayoutPixelSize(layout, parentPixelSize)
  local props = layout.props or {}
  local size = props.size
  local relativeSize = props.relativeSize

  local parentWidth = parentPixelSize and parentPixelSize.x or nil
  local parentHeight = parentPixelSize and parentPixelSize.y or nil

  local resolvedWidth = self:ResolveAxisSize(
    size and size.x or nil,
    relativeSize and relativeSize.x or nil,
    parentWidth
  )

  local resolvedHeight = self:ResolveAxisSize(
    size and size.y or nil,
    relativeSize and relativeSize.y or nil,
    parentHeight
  )

  return {
    x = resolvedWidth,
    y = resolvedHeight,
  }
end

---@param parentPixelSize {x: number|nil, y: number|nil}|nil The outer pixel size of the container.
---@param padding {Top: number, Right: number, Bottom: number, Left: number} Padding to subtract from each axis.
---@return {x: number|nil, y: number|nil}|nil Inner pixel size after subtracting padding, or nil when parentPixelSize is nil.
function Renderer:ResolvePaddedPixelSize(parentPixelSize, padding)
  if (parentPixelSize == nil) then
    return nil
  end

  return {
    x = parentPixelSize.x ~= nil and (parentPixelSize.x - (padding.Left + padding.Right)) or nil,
    y = parentPixelSize.y ~= nil and (parentPixelSize.y - (padding.Top + padding.Bottom)) or nil,
  }
end

---@return {x: number, y: number} Current OpenMW screen dimensions in pixels.
function Renderer:ResolveRootParentPixelSize()
  local screenSize = UI.screenSize()
  return {
    x = screenSize.x,
    y = screenSize.y,
  }
end

---@param childLayouts table[] Layout tables to arrange; props are mutated in-place.
---@param direction string|nil "row" or "column" (default "column").
---@param gap number|nil Pixel gap between adjacent children (default 0).
---@param containerPixelSize {x: number|nil, y: number|nil}|nil Available container space for flex-grow distribution.
---@param options {alignItems: string|nil, justifyContent: string|nil}|nil Alignment options. alignItems: "start"|"center"|"end"|"stretch". justifyContent: "start"|"center"|"end"|"stretch".
---@return table[] The same `childLayouts` with positions, sizes, and relative sizes resolved.
function Renderer:ArrangeFlexChildren(childLayouts, direction, gap, containerPixelSize, options)
  local childCount = #childLayouts
  if (childCount == 0) then
    return childLayouts
  end

  local resolvedDirection = direction or "column"
  local resolvedGap = gap or 0
  local isRow = resolvedDirection == "row"

  local alignItems    = options and options.alignItems    or nil
  local justifyContent = options and options.justifyContent or nil

  local containerMainSize = nil
  local containerCrossSize = nil
  if (containerPixelSize ~= nil) then
    containerMainSize = isRow and containerPixelSize.x or containerPixelSize.y
    containerCrossSize = isRow and containerPixelSize.y or containerPixelSize.x
  end

  local totalGrow = 0
  local totalFixedMainSize = math.max(0, (childCount - 1) * resolvedGap)

  for _, child in ipairs(childLayouts) do
    child.props = child.props or {}

    local size = child.props.size
    local relativeSize = child.props.relativeSize
    local mainSize = nil

    if (size ~= nil) then
      mainSize = isRow and size.x or size.y
      if (mainSize ~= nil and mainSize > 0) then
        totalFixedMainSize = totalFixedMainSize + mainSize
      else
        mainSize = nil
      end
    end

    local grow = child.__anglesFlexGrow or 0
    if (grow > 0) then
      totalGrow = totalGrow + grow
    end

    -- For justify-content: stretch, implicitly grant grow=1 to children that
    -- have no explicit main-axis size and no existing grow weight so the
    -- remaining space is distributed evenly among them.
    if (justifyContent == "stretch" and mainSize == nil and grow == 0) then
      child.__anglesFlexGrow = 1
      totalGrow = totalGrow + 1
    end

    -- Auto-stretch on the cross axis when alignItems is nil or "stretch".
    -- When any other explicit alignItems is provided, children keep their own cross-axis size.
    if ((alignItems == nil or alignItems == "stretch") and size ~= nil and relativeSize == nil) then
      if (isRow and size.y == 0) then
        child.props.relativeSize = Util.vector2(0, 1)
      elseif ((not isRow) and size.x == 0) then
        child.props.relativeSize = Util.vector2(1, 0)
      end
    end
  end

  local remainingMainSize = nil
  if (containerMainSize ~= nil) then
    remainingMainSize = containerMainSize - totalFixedMainSize
    if (remainingMainSize < 0) then
      remainingMainSize = 0
    end
  end

  -- Compute main-axis starting offset for justify-content.
  -- When grow children are present they fill remaining space so the effective
  -- total content size equals containerMainSize and the offset is always 0.
  local currentMainOffset = 0
  -- "stretch" distributes remaining space via implicit grow (handled above); skip offset.
  if (justifyContent ~= nil and justifyContent ~= "start" and justifyContent ~= "stretch" and containerMainSize ~= nil) then
    local totalContentMainSize = totalFixedMainSize
    if (totalGrow > 0) then
      totalContentMainSize = containerMainSize
    end
    local leftover = containerMainSize - totalContentMainSize
    if (leftover > 0) then
      if (justifyContent == "end") then
        currentMainOffset = leftover
      elseif (justifyContent == "center") then
        currentMainOffset = math.floor(leftover / 2)
      end
    end
  end

  for _, child in ipairs(childLayouts) do
    child.props = child.props or {}

    local hasPosition = child.props.position ~= nil
    local hasRelativePosition = child.props.relativePosition ~= nil
    local size = child.props.size

    local majorSize = 0
    if (size ~= nil) then
      majorSize = isRow and (size.x or 0) or (size.y or 0)
    end

    local grow = child.__anglesFlexGrow or 0
    if (grow > 0 and remainingMainSize ~= nil and totalGrow > 0) then
      local grownSize = (remainingMainSize * grow) / totalGrow
      local existingRelSize = child.props.relativeSize
      if (size == nil) then
        if (isRow) then
          child.props.size = Util.vector2(grownSize, 0)
          -- Clear main-axis relative size to prevent defaultRelativeSize double-counting
          child.props.relativeSize = Util.vector2(0, existingRelSize and existingRelSize.y or 1)
        else
          child.props.size = Util.vector2(0, grownSize)
          child.props.relativeSize = Util.vector2(existingRelSize and existingRelSize.x or 1, 0)
        end
      else
        if (isRow) then
          child.props.size = Util.vector2((size.x or 0) + grownSize, size.y or 0)
          if (existingRelSize ~= nil) then
            child.props.relativeSize = Util.vector2(0, existingRelSize.y or 0)
          end
        else
          child.props.size = Util.vector2(size.x or 0, (size.y or 0) + grownSize)
          if (existingRelSize ~= nil) then
            child.props.relativeSize = Util.vector2(existingRelSize.x or 0, 0)
          end
        end
      end

      majorSize = majorSize + grownSize
    end

    -- Compute cross-axis offset for align-items.
    -- "stretch" is handled above (relativeSize set to fill cross axis); skip offset.
    local crossOffset = 0
    if (alignItems ~= nil and alignItems ~= "start" and alignItems ~= "stretch" and containerCrossSize ~= nil) then
      local childCrossSize = 0
      local cs  = child.props.size
      local crs = child.props.relativeSize
      if (isRow) then
        if (cs ~= nil and (cs.y or 0) ~= 0) then
          childCrossSize = cs.y
        elseif (crs ~= nil and (crs.y or 0) ~= 0) then
          childCrossSize = (crs.y or 0) * containerCrossSize
        end
      else
        if (cs ~= nil and (cs.x or 0) ~= 0) then
          childCrossSize = cs.x
        elseif (crs ~= nil and (crs.x or 0) ~= 0) then
          childCrossSize = (crs.x or 0) * containerCrossSize
        end
      end
      local remaining = containerCrossSize - childCrossSize
      if (remaining > 0) then
        if (alignItems == "end") then
          crossOffset = remaining
        elseif (alignItems == "center") then
          crossOffset = math.floor(remaining / 2)
        end
      end
    end

    if (not hasRelativePosition and not hasPosition) then
      if (isRow) then
        child.props.position = Util.vector2(currentMainOffset, crossOffset)
      else
        child.props.position = Util.vector2(crossOffset, currentMainOffset)
      end
    end

    currentMainOffset = currentMainOffset + majorSize + resolvedGap

    -- After grow is resolved, rebuild any nested custom layouts (grid, flex, or scroll canvas)
    -- using the child's now-resolved pixel dimensions.
    local needsRebuild = (child.__anglesCustomGrid ~= nil or child.__anglesNestedFlexes ~= nil or child.__anglesNestedScrollCanvases ~= nil or child.__anglesCustomScrollCanvas ~= nil)
    if (needsRebuild) then
      local childSize = child.props.size
      local childRelSize = child.props.relativeSize
      local effectiveWidth = nil
      local effectiveHeight = nil

      if (isRow) then
        effectiveWidth = childSize and childSize.x or nil
        if (childRelSize ~= nil and containerCrossSize ~= nil) then
          effectiveHeight = (childSize and childSize.y or 0) + ((childRelSize.y or 0) * containerCrossSize)
        elseif (childSize ~= nil) then
          effectiveHeight = childSize.y
        end
      else
        effectiveHeight = childSize and childSize.y or nil
        if (childRelSize ~= nil and containerCrossSize ~= nil) then
          effectiveWidth = (childSize and childSize.x or 0) + ((childRelSize.x or 0) * containerCrossSize)
        elseif (childSize ~= nil) then
          effectiveWidth = childSize.x
        end
      end

      local childPixelSize = { x = effectiveWidth, y = effectiveHeight }

      if (child.__anglesCustomGrid ~= nil) then
        local gridInnerPixelSize = self:ResolvePaddedPixelSize(childPixelSize, child.__anglesCustomGrid.meta.padding)
        self:RebuildCustomGridLayout(child, gridInnerPixelSize)
      end

      if (child.__anglesNestedFlexes ~= nil) then
        for _, nestedFlex in ipairs(child.__anglesNestedFlexes) do
          if (nestedFlex.__anglesCustomFlex ~= nil) then
            local nestedInnerSize = self:ResolvePaddedPixelSize(childPixelSize, nestedFlex.__anglesCustomFlex.meta.padding)
            self:RebuildCustomFlexLayout(nestedFlex, nestedInnerSize)
          end
        end
      end

      -- Rebuild scroll canvases that are direct grow children of this flex.
      if (child.__anglesCustomScrollCanvas ~= nil) then
        self:RebuildScrollCanvas(child, childPixelSize)
      end

      -- Rebuild scroll canvases that are nested deeper (e.g. inside mw-window or a
      -- padding-container wrapper).  Each entry carries the total horizontal/vertical
      -- padding accumulated from intermediate padding containers so we can subtract it
      -- from childPixelSize to arrive at the correct canvas pixel size.
      if (child.__anglesNestedScrollCanvases ~= nil) then
        for _, entry in ipairs(child.__anglesNestedScrollCanvases) do
          local scrollCanvas = entry.scrollCanvas
          if (scrollCanvas ~= nil and scrollCanvas.__anglesCustomScrollCanvas ~= nil) then
            local effectiveSize = {
              x = childPixelSize.x ~= nil and math.max(0, childPixelSize.x - (entry.padX or 0)) or nil,
              y = childPixelSize.y ~= nil and math.max(0, childPixelSize.y - (entry.padY or 0)) or nil,
            }
            self:RebuildScrollCanvas(scrollCanvas, effectiveSize)
          end
        end
      end
    end

    child.__anglesFlexGrow = nil
  end

  return childLayouts
end

---@param layout table The outer Layout table for the mw-flex element.
---@param childLayouts table[] Children to arrange inside the flex container.
---@param meta {type: string, direction: string, gap: number, padding: table} Flex metadata.
---@param innerPixelSize {x: number|nil, y: number|nil}|nil Available inner pixel area after the container's own padding.
function Renderer:ApplyCustomFlexContainer(layout, childLayouts, meta, innerPixelSize)
  -- Snapshot each child's original props before ArrangeFlexChildren modifies them.
  -- RebuildCustomFlexLayout needs these to restore a clean slate before re-running.
  local originalChildProps = {}
  for i, child in ipairs(childLayouts) do
    child.props = child.props or {}
    originalChildProps[i] = {
      size             = child.props.size,
      relativeSize     = child.props.relativeSize,
      position         = child.props.position,
      relativePosition = child.props.relativePosition,
      flexGrow         = child.__anglesFlexGrow,
    }
  end

  local arrangedChildren = self:ArrangeFlexChildren(childLayouts, meta.direction, meta.gap, innerPixelSize, {
    alignItems    = meta.alignItems,
    justifyContent = meta.justifyContent,
  })

  local paddedContainer = {
    props = {
      relativeSize = Util.vector2(1, 1),
      size = Util.vector2(-(meta.padding.Left + meta.padding.Right), -(meta.padding.Top + meta.padding.Bottom)),
      position = Util.vector2(meta.padding.Left, meta.padding.Top),
    },
    content = UI.content(arrangedChildren)
  }

  self:AppendChildren(layout, { paddedContainer })

  -- Store rebuild state so an ancestor's ArrangeFlexChildren can re-run this flex's
  -- internal layout if the ancestor's grow changes this element's actual pixel size.
  layout.__anglesCustomFlex = {
    meta               = meta,
    childLayouts       = childLayouts,
    originalChildProps = originalChildProps,
    paddedContainer    = paddedContainer,
  }
end

-- Build the flat list of CSS rules that are active for the current screen width.
-- Base rules come first; matching media-query rules are appended (higher cascade order).
---@return table[] Active CSS rules in cascade order (user-component rules, then main-stylesheet, then media-query overrides).
function Renderer:ResolveActiveRules()
  local cssModel = self.cssModel
  if (cssModel == nil) then return {} end

  local activeRules = {}
  local screenWidth = UI.screenSize().x

  -- User component CSS rules come first (lower cascade order than the main stylesheet).
  -- This lets main-stylesheet rules override user component rules at equal specificity.
  for _, userComponent in pairs(self.userComponents) do
    if (type(userComponent) == "table" and userComponent.cssModel ~= nil) then
      for _, rule in ipairs(userComponent.cssModel.rules or {}) do
        table.insert(activeRules, rule)
      end
      for _, mediaQuery in ipairs(userComponent.cssModel.mediaQueries or {}) do
        local matches = false
        if (mediaQuery.type == "max-width") then
          matches = screenWidth <= mediaQuery.value
        elseif (mediaQuery.type == "min-width") then
          matches = screenWidth >= mediaQuery.value
        end
        if (matches) then
          for _, rule in ipairs(mediaQuery.rules or {}) do
            table.insert(activeRules, rule)
          end
        end
      end
    end
  end

  -- Main stylesheet rules.
  for _, rule in ipairs(cssModel.rules or {}) do
    table.insert(activeRules, rule)
  end

  for _, mediaQuery in ipairs(cssModel.mediaQueries or {}) do
    local matches = false
    if (mediaQuery.type == "max-width") then
      matches = screenWidth <= mediaQuery.value
    elseif (mediaQuery.type == "min-width") then
      matches = screenWidth >= mediaQuery.value
    end

    if (matches) then
      for _, rule in ipairs(mediaQuery.rules or {}) do
        table.insert(activeRules, rule)
      end
    end
  end

  return activeRules
end

-- Build the flat list of active container query rules, including those from matching media queries.
---@return table[] Active container query rules in cascade order.
function Renderer:ResolveActiveContainerQueryRules()
  local cssModel = self.cssModel
  if (cssModel == nil) then return {} end

  local activeRules = {}
  local screenWidth = UI.screenSize().x

  -- User component container query rules come first.
  for _, userComponent in pairs(self.userComponents) do
    if (type(userComponent) == "table" and userComponent.cssModel ~= nil) then
      for _, cqRule in ipairs(userComponent.cssModel.containerQueryRules or {}) do
        table.insert(activeRules, cqRule)
      end
      for _, mediaQuery in ipairs(userComponent.cssModel.mediaQueries or {}) do
        local matches = false
        if (mediaQuery.type == "max-width") then
          matches = screenWidth <= mediaQuery.value
        elseif (mediaQuery.type == "min-width") then
          matches = screenWidth >= mediaQuery.value
        end
        if (matches) then
          for _, cqRule in ipairs(mediaQuery.containerQueryRules or {}) do
            table.insert(activeRules, cqRule)
          end
        end
      end
    end
  end

  -- Main stylesheet container query rules.
  for _, cqRule in ipairs(cssModel.containerQueryRules or {}) do
    table.insert(activeRules, cqRule)
  end

  for _, mediaQuery in ipairs(cssModel.mediaQueries or {}) do
    local matches = false
    if (mediaQuery.type == "max-width") then
      matches = screenWidth <= mediaQuery.value
    elseif (mediaQuery.type == "min-width") then
      matches = screenWidth >= mediaQuery.value
    end

    if (matches) then
      for _, cqRule in ipairs(mediaQuery.containerQueryRules or {}) do
        table.insert(activeRules, cqRule)
      end
    end
  end

  return activeRules
end

-- Return a table of lowercased attribute name -> value pairs derived from
-- any CSS rules in self.activeRules that match this node.
-- containerContext = { pixelSize = {x,y}|nil, named = { [name]={x,y} } } or nil.
---@param node Node The node to match CSS selectors against.
---@param ancestors Node[] Ordered ancestor chain from root to immediate parent.
---@param containerContext {pixelSize: {x:number,y:number}|nil, named: table<string,{x:number,y:number}>}|nil Container size context.
---@return table<string, any> Internal attribute name to winning CSS-declared value.
function Renderer:GetCSSAttributesForNode(node, ancestors, containerContext)
  local attrs = {}

  if (self.activeRules ~= nil and #self.activeRules > 0) then
    local cssDecls = CSSParser.ApplyRulesToNode(self.activeRules, node, ancestors)
    for cssProperty, value in pairs(cssDecls) do
      local attrName = CSS_PROPERTY_TO_ATTRIBUTE[cssProperty]
      if (attrName ~= nil) then
        attrs[attrName] = value
      end
    end
  end

  if (containerContext ~= nil
    and self.activeContainerQueryRules ~= nil
    and #self.activeContainerQueryRules > 0) then
    local cqDecls = CSSParser.ApplyContainerRulesToNode(
      self.activeContainerQueryRules, node, ancestors, containerContext
    )
    for cssProperty, value in pairs(cqDecls) do
      local attrName = CSS_PROPERTY_TO_ATTRIBUTE[cssProperty]
      if (attrName ~= nil) then
        attrs[attrName] = value
      end
    end
  end

  return attrs
end

-- Renders the provided source code and components onto the screen.
-- userContext must be a flat table where every value is a Signal or a plain function.
-- This returns the OpenMW Lua UI root element after it is called.
---@param userContext table<string, Signal|fun(...): any> Flat map of context variables; every value must be a Signal or a plain function.
---@return table The OpenMW UI element (return value of UI.create()) for the rendered root.
function Renderer:Render(userContext)
  -- Enforce the contract: context values must be Signal instances or plain functions.
  for key, value in pairs(userContext or {}) do
    if (not Signal.IsSignal(value) and type(value) ~= "function") then
      error("Renderer:Render() context values must be Signal instances or functions. '" .. tostring(key) .. "' is neither.")
    end
  end

  -- Tear down subscriptions left over from any previous Render() call.
  self:_disposeSignalEffects()

  -- Subscribe to every context signal so that any Set() call triggers a full re-render.
  -- Plain functions in the context are passed through as-is and are not subscribed.
  self._signalContext       = userContext or {}
  self._signalsDirty        = false
  self._signalUnsubscribers = {}
  for _, signal in pairs(self._signalContext) do
    if (Signal.IsSignal(signal)) then
      local unsubscribe = signal:Subscribe(function()
        self._signalsDirty = true
        self:Rerender()
      end)
      table.insert(self._signalUnsubscribers, unsubscribe)
    end
  end

  local lexer = Lexer.new(self.source, self.userComponents)
  local ast   = lexer:parse()
  self._ast   = ast  -- stored so Rerender() can re-evaluate against fresh signal values

  local evaluator = Evaluator.new(self.userComponents)
  local context   = Context.new(userContext)
  local rootNode  = evaluator:evaluate(ast, context)

  self.activeRules              = self:ResolveActiveRules()
  self.activeContainerQueryRules = self:ResolveActiveContainerQueryRules()
  self._cachedScreenWidth        = UI.screenSize().x

  if (#rootNode.children > 0) then
    local firstNode = rootNode.children[1]
    if (firstNode.type == Node.TYPE_ENGINE_COMPONENT) then
      if (firstNode.tagName == "mw-root") then
        self.evaluatedRootNode = firstNode
        local rootParentPixelSize = self:ResolveRootParentPixelSize()
        self._scrollCanvasIdCounter = 0
        self._scrollStates = {}
        local rootLayout = self:BuildLayoutTree(firstNode, rootParentPixelSize)
        self.rootLayout = rootLayout
        local uiElement = UI.create(rootLayout)
        self.rootElement = uiElement
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

-- Rebuilds the layout tree from the stored evaluated root node and updates the live UI element.
-- Re-resolves CSS rules so media queries and container queries reflect the current state.
-- Any explicit size/position applied to the root (e.g. from resizing) is preserved and used
-- when computing child layouts so container queries see the correct container dimensions.
-- When signals are registered, the template is also re-evaluated so bindings reflect the
-- latest signal values before the layout is rebuilt.
---@return nil Mutates rootLayout in-place and calls rootElement:update().
function Renderer:Rerender()
  if (self.evaluatedRootNode == nil or self.rootElement == nil or self.rootLayout == nil) then
    return
  end

  -- Re-evaluate the AST only when a signal has actually changed value.
  -- During resize/drag the signals are unchanged, so this block is skipped.
  if (self._ast ~= nil and self._signalsDirty) then
    self._signalsDirty = false
    local evaluator  = Evaluator.new(self.userComponents)
    local context    = Context.new(self._signalContext or {})
    local freshRoot  = evaluator:evaluate(self._ast, context)
    if (#freshRoot.children > 0) then
      local firstNode = freshRoot.children[1]
      if (firstNode.type == Node.TYPE_ENGINE_COMPONENT and firstNode.tagName == "mw-root") then
        self.evaluatedRootNode = firstNode
      end
    end
  end

  -- Snapshot explicit size/position set on the root layout (e.g. by a resize drag).
  -- These are stored temporarily so BuildLayoutTree can apply them before resolving
  -- child pixel sizes, ensuring container queries fire against the real current size.
  self._rootSizeOverride     = self.rootLayout.props and self.rootLayout.props.size     or nil
  self._rootPositionOverride = self.rootLayout.props and self.rootLayout.props.position or nil

  -- Active rules only change when the game screen is resized (media queries).
  -- Resizing the mw-root panel does not change the screen size, so skip the
  -- rebuild in the common case.
  local currentScreenWidth = UI.screenSize().x
  if (self._cachedScreenWidth ~= currentScreenWidth) then
    self.activeRules              = self:ResolveActiveRules()
    self.activeContainerQueryRules = self:ResolveActiveContainerQueryRules()
    self._cachedScreenWidth = currentScreenWidth
  end

  local rootParentPixelSize = self:ResolveRootParentPixelSize()
  self._scrollCanvasIdCounter = 0
  local newRootLayout = self:BuildLayoutTree(self.evaluatedRootNode, rootParentPixelSize)



  self._rootSizeOverride     = nil
  self._rootPositionOverride = nil

  -- Patch the live root layout table in-place.
  -- UI.create() already holds a reference to self.rootLayout, so we mutate it
  -- rather than replace it so that OpenMW picks up the changes on update().
  self.rootLayout.props    = newRootLayout.props
  self.rootLayout.content  = newRootLayout.content
  self.rootLayout.userData = newRootLayout.userData

  self.rootElement:update()
end

-- Snaps the mw-root back inside the screen if any edge has drifted outside.
-- Safe to call at any time; does nothing and skips the update() call when the
-- window is already fully on-screen.
---@return nil
function Renderer:SnapToScreen()
  if (self.rootLayout == nil or self.rootLayout.props == nil or self.rootElement == nil) then
    return
  end

  local screenSize = UI.screenSize()

  -- Resolve current pixel position.
  local curX = 0
  local curY = 0
  if (self.rootLayout.props.position ~= nil) then
    curX = self.rootLayout.props.position.x
    curY = self.rootLayout.props.position.y
  elseif (self.rootLayout.props.relativePosition ~= nil) then
    curX = self.rootLayout.props.relativePosition.x * screenSize.x
    curY = self.rootLayout.props.relativePosition.y * screenSize.y
  end

  -- Resolve current pixel size.
  local rootW = 0
  local rootH = 0
  if (self.rootLayout.props.size ~= nil) then
    rootW = self.rootLayout.props.size.x
    rootH = self.rootLayout.props.size.y
  elseif (self.rootLayout.props.relativeSize ~= nil) then
    rootW = self.rootLayout.props.relativeSize.x * screenSize.x
    rootH = self.rootLayout.props.relativeSize.y * screenSize.y
  end

  local newX = math.max(0, math.min(curX, screenSize.x - rootW))
  local newY = math.max(0, math.min(curY, screenSize.y - rootH))

  if (newX == curX and newY == curY) then
    return
  end

  self.rootLayout.props.position         = Util.vector2(newX, newY)
  self.rootLayout.props.relativePosition = nil

  self.rootElement:update()
end

-- Unsubscribes all signal listeners registered by the last Render() call.
---@return nil
function Renderer:_disposeSignalEffects()
  if (self._signalUnsubscribers ~= nil) then
    for _, unsubscribe in ipairs(self._signalUnsubscribers) do
      unsubscribe()
    end
    self._signalUnsubscribers = nil
  end
end

---@param node Node The evaluated AST node to convert into an OpenMW Layout.
---@param parentPixelSize {x: number|nil, y: number|nil}|nil The parent's resolved pixel size for resolving relative dimensions.
---@param ancestors Node[]|nil Ordered ancestor chain from root to this node's parent for CSS matching.
---@param containerContext {pixelSize: {x:number,y:number}|nil, named: table<string,{x:number,y:number}>}|nil Container query size context.
---@return table The OpenMW Layout table with props, content, and events fully populated.
function Renderer:BuildLayoutTree(node, parentPixelSize, ancestors, containerContext)
ancestors = ancestors or {}
local layout, meta = self:GetEngineUIElement(node, ancestors, containerContext)
local normalizedProperties = self:ParseAcceptedProperties(node, ancestors, containerContext)

-- During Rerender(), restore the explicit size/position applied to the root
-- (e.g. from a resize drag) so child pixel sizes and container queries compute
-- against the actual current dimensions rather than the template defaults.
-- The root node is identified by being the first call (containerContext == nil).
if (containerContext == nil and self._rootSizeOverride ~= nil) then
  layout.props.size         = self._rootSizeOverride
  layout.props.relativeSize = nil
  if (self._rootPositionOverride ~= nil) then
    layout.props.position         = self._rootPositionOverride
    layout.props.relativePosition = nil
  end
end

  local growAttribute = normalizedProperties["grow"]
  if (growAttribute ~= nil) then
    layout.__anglesFlexGrow = self:ToNumber(growAttribute, "Grow")
  end

  local gridColumn = normalizedProperties["gridcolumn"]
  if (gridColumn ~= nil) then
    layout.__anglesGridColumn = self:ToNumber(gridColumn, "GridColumn")
  end

  local gridRow = normalizedProperties["gridrow"]
  if (gridRow ~= nil) then
    layout.__anglesGridRow = self:ToNumber(gridRow, "GridRow")
  end

  local gridColumnSpan = normalizedProperties["gridcolumnspan"]
  if (gridColumnSpan ~= nil) then
    layout.__anglesGridColumnSpan = self:ToNumber(gridColumnSpan, "GridColumnSpan")
  end

  local gridRowSpan = normalizedProperties["gridrowspan"]
  if (gridRowSpan ~= nil) then
    layout.__anglesGridRowSpan = self:ToNumber(gridRowSpan, "GridRowSpan")
  end

  local layoutPixelSize = self:ResolveLayoutPixelSize(layout, parentPixelSize)

  -- Aspect-ratio post-resolution: when aspect-ratio was paired with a relative
  -- dimension in ApplyCommonWidgetProperties the constraint was deferred until the
  -- parent pixel size became known here.  Now that we have resolved pixel extents,
  -- apply the ratio and rewrite layout.props so downstream layout logic (flex,
  -- grid, scroll-canvas) sees the fully-constrained size.
  local aspectRatioAttr = normalizedProperties["aspectratio"]
  if (aspectRatioAttr ~= nil) then
    local ratio = self:ParseAspectRatio(aspectRatioAttr, "AspectRatio")
    local rW = layoutPixelSize.x
    local rH = layoutPixelSize.y
    local hasW = (rW ~= nil and rW > 0)
    local hasH = (rH ~= nil and rH > 0)
    if (hasW and not hasH) then
      rH = rW / ratio
      -- Contain: if the derived height would exceed the parent's available height,
      -- pivot and derive from the height constraint instead, keeping the ratio.
      if (parentPixelSize ~= nil and parentPixelSize.y ~= nil and rH > parentPixelSize.y) then
        rH = parentPixelSize.y
        rW = rH * ratio
      end
      layout.props.size = Util.vector2(rW, rH)
      layout.props.relativeSize = nil
      layoutPixelSize = { x = rW, y = rH }
    elseif (hasH and not hasW) then
      rW = rH * ratio
      -- Contain: if the derived width would exceed the parent's available width,
      -- pivot and derive from the width constraint instead, keeping the ratio.
      if (parentPixelSize ~= nil and parentPixelSize.x ~= nil and rW > parentPixelSize.x) then
        rW = parentPixelSize.x
        rH = rW / ratio
      end
      layout.props.size = Util.vector2(rW, rH)
      layout.props.relativeSize = nil
      layoutPixelSize = { x = rW, y = rH }
    end
  end

  -- Resolve left/top/right/bottom CSS position properties.
  -- These override any position already set by ApplyCommonWidgetProperties (X/Y).
  -- Percentages are resolved against parentPixelSize; right/bottom also use
  -- the element's own resolved pixel size.
  -- Skipped once the user has manually dragged or resized the root (position
  -- is then owned by the drag/resize handlers and must not be clobbered).
  if (not self._userPositionOverridden) then do
    local parentW = parentPixelSize and parentPixelSize.x or nil
    local parentH = parentPixelSize and parentPixelSize.y or nil
    local leftPx,   leftRel   = self:ParseNumericOrPercent(normalizedProperties["left"],   "Left")
    local topPx,    topRel    = self:ParseNumericOrPercent(normalizedProperties["top"],    "Top")
    local rightPx,  rightRel  = self:ParseNumericOrPercent(normalizedProperties["right"],  "Right")
    local bottomPx, bottomRel = self:ParseNumericOrPercent(normalizedProperties["bottom"], "Bottom")

    local function resolveAxis(px, rel, parentSize)
      if px ~= nil then return px end
      if rel ~= nil and parentSize ~= nil then return rel * parentSize end
      return nil
    end

    local resolvedLeft   = resolveAxis(leftPx,   leftRel,   parentW)
    local resolvedTop    = resolveAxis(topPx,    topRel,    parentH)
    local resolvedRight  = resolveAxis(rightPx,  rightRel,  parentW)
    local resolvedBottom = resolveAxis(bottomPx, bottomRel, parentH)

    -- left takes precedence over right; top takes precedence over bottom.
    local posX = nil
    if resolvedLeft ~= nil then
      posX = resolvedLeft
    elseif resolvedRight ~= nil and parentW ~= nil then
      local elemW = (layoutPixelSize and layoutPixelSize.x) or 0
      posX = parentW - elemW - resolvedRight
    end

    local posY = nil
    if resolvedTop ~= nil then
      posY = resolvedTop
    elseif resolvedBottom ~= nil and parentH ~= nil then
      local elemH = (layoutPixelSize and layoutPixelSize.y) or 0
      posY = parentH - elemH - resolvedBottom
    end

    if posX ~= nil or posY ~= nil then
      local existingPos = layout.props.position
      local existingX = existingPos and existingPos.x or 0
      local existingY = existingPos and existingPos.y or 0
      layout.props.position = Util.vector2(
        posX ~= nil and posX or existingX,
        posY ~= nil and posY or existingY
      )
      layout.props.relativePosition = nil
    end
  end end

  local childParentPixelSize = layoutPixelSize
  if (meta ~= nil and (meta.type == "custom-flex" or meta.type == "padding-container" or meta.type == "custom-grid")) then
    childParentPixelSize = self:ResolvePaddedPixelSize(layoutPixelSize, meta.padding)
  elseif (meta ~= nil and meta.type == "custom-scroll-canvas") then
    local sbSize = meta.scrollBarSize
    local vpW = layoutPixelSize.x ~= nil and math.max(0, layoutPixelSize.x - sbSize) or nil
    local vpH = layoutPixelSize.y ~= nil and math.max(0, layoutPixelSize.y - sbSize) or nil
    local innerW = vpW ~= nil and math.max(0, vpW - meta.padding.Left - meta.padding.Right) or nil
    local innerH = vpH ~= nil and math.max(0, vpH - meta.padding.Top - meta.padding.Bottom) or nil
    -- Main axis is unconstrained so content can overflow; cross axis is bounded.
    if (meta.direction == "row") then
      childParentPixelSize = { x = nil, y = innerH }
    else
      childParentPixelSize = { x = innerW, y = nil }
    end
  end

  -- Build the child container context.
  -- The root call has containerContext == nil; mw-root becomes the default unnamed container.
  -- container-type updates the nearest unnamed container pixel size.
  -- container-name registers this element under a name for targeted @container NAME queries.
  local childContainerContext = containerContext or { pixelSize = nil, named = {} }
  if (containerContext == nil or normalizedProperties["containertype"] ~= nil) then
    childContainerContext = {
      pixelSize = layoutPixelSize,
      named     = childContainerContext.named,
    }
  end

  local containerNameAttr = normalizedProperties["containername"]
  if (containerNameAttr ~= nil) then
    local newNamed = {}
    for k, v in pairs(childContainerContext.named) do
      newNamed[k] = v
    end
    -- Only register as a named container when the pixel size is meaningful (> 0).
    -- A zero width comes from relativeSize.x = 0, which is the placeholder produced when
    -- no explicit width was set and flex-grow will determine the real size later.
    -- Registering with size 0 would cause width < N queries to fire spuriously.
    if (layoutPixelSize.x ~= nil and layoutPixelSize.x > 0) then
      newNamed[tostring(containerNameAttr)] = layoutPixelSize
    end
    childContainerContext = {
      pixelSize = childContainerContext.pixelSize,
      named     = newNamed,
    }
  end

  -- Self-aware container query re-evaluation.
  -- After building childContainerContext this element's own named container entry is present
  -- (when the size was resolvable above).  Re-evaluate CSS using that context so that
  -- @container NAME queries targeting THIS element's own name can fire and update the meta
  -- (e.g. grid-template-columns) before children are laid out.
  local selfContainerKey = containerNameAttr ~= nil and tostring(containerNameAttr) or nil
  if (selfContainerKey ~= nil and childContainerContext.named[selfContainerKey] ~= nil and meta ~= nil) then
    local selfAwareProps = self:ParseAcceptedProperties(node, ancestors, childContainerContext)
    if (meta.type == "custom-grid") then
      if (selfAwareProps["gridtemplatecolumns"] ~= nil) then
        meta.templateColumns = selfAwareProps["gridtemplatecolumns"]
      end
      if (selfAwareProps["gridtemplaterows"] ~= nil) then
        meta.templateRows = selfAwareProps["gridtemplaterows"]
      end
      if (selfAwareProps["gap"] ~= nil) then
        meta.gap = selfAwareProps["gap"]
      end
    elseif (meta.type == "custom-flex") then
      if (selfAwareProps["direction"] ~= nil) then
        meta.direction = selfAwareProps["direction"]
      end
      if (selfAwareProps["gap"] ~= nil) then
        meta.gap = self:ToNumber(selfAwareProps["gap"], "Gap") or 0
      end
    end
  end

  -- Collect system event functions: __pendingSystemEvents set by GetEngineUIElement (e.g. resize
  -- funcs on mw-root) plus dragger funcs for elements marked as drag handles.
  local systemEventFuncs = layout.__pendingSystemEvents or {}
  layout.__pendingSystemEvents = nil
  local draggerAttr = normalizedProperties["dragger"]
  if (draggerAttr ~= nil and self:ToBoolean(draggerAttr, "Dragger") == true) then
    for k, v in pairs(self:BuildDraggerFuncs()) do
      systemEventFuncs[k] = v
    end
  end
  -- Collect user-defined event bindings from the evaluated node's attributes (event:X prefix).
  local userEventFuncs = {}
  for attrName, attrValue in pairs(node.attributes or {}) do
    local eventName = string.match(attrName, "^event:(.+)$")
    if (eventName ~= nil and attrValue ~= nil) then
      userEventFuncs[eventName] = attrValue
    end
  end
  -- Build and register the final events table, chaining handlers where both system and user
  -- define the same event (system fires first, then user).
  local finalEvents = self:BuildEventTable(systemEventFuncs, userEventFuncs)
  if (finalEvents ~= nil) then
    layout.events = finalEvents
  end

  local childLayouts = {}

  local childAncestors = {}
  for _, ancestor in ipairs(ancestors) do
    table.insert(childAncestors, ancestor)
  end
  table.insert(childAncestors, node)

  if (#node.children > 0) then
    -- For grid containers, pre-compute each direct child's cell pixel size so that
    -- relative dimensions (e.g. width: 100%) inside grid children resolve against
    -- the actual cell, not the full grid inner area.  The self-aware container
    -- query re-evaluation above may have already updated meta.templateColumns, so
    -- this must run after that block.
    local gridChildCellSizes = nil
    if (meta ~= nil and meta.type == "custom-grid") then
      local preChildMetas = {}
      for _, childNode in pairs(node.children) do
        if (childNode.type == Node.TYPE_ENGINE_COMPONENT) then
          local childProps = self:ParseAcceptedProperties(childNode, childAncestors, childContainerContext)
          table.insert(preChildMetas, {
            gridColumn     = self:ToNumber(childProps["gridcolumn"],     "GridColumn"),
            gridRow        = self:ToNumber(childProps["gridrow"],        "GridRow"),
            gridColumnSpan = self:ToNumber(childProps["gridcolumnspan"], "GridColumnSpan"),
            gridRowSpan    = self:ToNumber(childProps["gridrowspan"],    "GridRowSpan"),
          })
        end
      end
      if (#preChildMetas > 0) then
        gridChildCellSizes = self:PrecomputeGridCellSizes(preChildMetas, meta, childParentPixelSize)
      end
    end

    local gridChildIdx = 0
    for _, childNode in pairs(node.children) do
      if (childNode.type == Node.TYPE_ENGINE_COMPONENT) then
        local effectiveParentPixelSize = childParentPixelSize
        if (gridChildCellSizes ~= nil) then
          gridChildIdx = gridChildIdx + 1
          local cellSize = gridChildCellSizes[gridChildIdx]
          if (cellSize ~= nil) then
            effectiveParentPixelSize = cellSize
          end
        end
        table.insert(childLayouts, self:BuildLayoutTree(childNode, effectiveParentPixelSize, childAncestors, childContainerContext))
      end
    end
  end

  if (meta ~= nil and meta.type == "custom-flex") then
    self:ApplyCustomFlexContainer(layout, childLayouts, meta, childParentPixelSize)
  elseif (meta ~= nil and meta.type == "custom-grid") then
    self:ApplyCustomGridContainer(layout, childLayouts, meta, childParentPixelSize)
  elseif (meta ~= nil and meta.type == "custom-scroll-canvas") then
    self:ApplyScrollCanvasContainer(layout, childLayouts, meta, layoutPixelSize)
  elseif (meta ~= nil and meta.type == "padding-container") then
    self:ApplyPaddingContainer(layout, childLayouts, meta.padding)
    -- Propagate scroll canvas tracking through the padding container, accumulating
    -- the horizontal/vertical padding so RebuildScrollCanvas can subtract it from
    -- the grow-resolved childPixelSize to get the true canvas pixel size.
    local padX = meta.padding.Left + meta.padding.Right
    local padY = meta.padding.Top + meta.padding.Bottom
    for _, childLayout in ipairs(childLayouts) do
      if (childLayout.__anglesCustomScrollCanvas ~= nil) then
        if (layout.__anglesNestedScrollCanvases == nil) then
          layout.__anglesNestedScrollCanvases = {}
        end
        table.insert(layout.__anglesNestedScrollCanvases, { scrollCanvas = childLayout, padX = padX, padY = padY })
      end
      if (childLayout.__anglesNestedScrollCanvases ~= nil) then
        if (layout.__anglesNestedScrollCanvases == nil) then
          layout.__anglesNestedScrollCanvases = {}
        end
        for _, entry in ipairs(childLayout.__anglesNestedScrollCanvases) do
          table.insert(layout.__anglesNestedScrollCanvases, {
            scrollCanvas = entry.scrollCanvas,
            padX         = entry.padX + padX,
            padY         = entry.padY + padY,
          })
        end
      end
    end
  else
    self:AppendChildren(layout, childLayouts)
    -- Track any immediate flex children so an ancestor ArrangeFlexChildren can
    -- call RebuildCustomFlexLayout on them when this wrapper's grow-resolved
    -- size differs from the build-time estimate.
    for _, childLayout in ipairs(childLayouts) do
      if (childLayout.__anglesCustomFlex ~= nil) then
        if (layout.__anglesNestedFlexes == nil) then
          layout.__anglesNestedFlexes = {}
        end
        table.insert(layout.__anglesNestedFlexes, childLayout)
      end
      -- Bubble scroll canvas tracking up so an ancestor flex can rebuild after grow resolution.
      if (childLayout.__anglesCustomScrollCanvas ~= nil) then
        if (layout.__anglesNestedScrollCanvases == nil) then
          layout.__anglesNestedScrollCanvases = {}
        end
        table.insert(layout.__anglesNestedScrollCanvases, { scrollCanvas = childLayout, padX = 0, padY = 0 })
      end
      if (childLayout.__anglesNestedScrollCanvases ~= nil) then
        if (layout.__anglesNestedScrollCanvases == nil) then
          layout.__anglesNestedScrollCanvases = {}
        end
        for _, entry in ipairs(childLayout.__anglesNestedScrollCanvases) do
          table.insert(layout.__anglesNestedScrollCanvases, entry)
        end
      end
    end
  end

  return layout
end

---@param allProperties table<string, any> Normalised attribute map from ParseAcceptedProperties.
---@param options {requireSize: boolean|nil, defaultRelativeSize: boolean|nil}|nil Parsing options.
---@param tagName string|nil The HTML tag name of the element being processed, shown in error messages.
---@return table props, table consumed The populated `props` table and a map of consumed attribute keys.
function Renderer:ApplyCommonWidgetProperties(allProperties, options, tagName)
  local props = {}
  local consumed = {}

  self:MarkConsumed(consumed, { "name", "layer", "padding", "parsedpadding", "direction", "gap", "grow", "containertype", "containername", "dragger" })

  local width, widthRelativeFromWidth = self:ParseNumericOrPercent(allProperties["width"], "Width")
  local height, heightRelativeFromHeight = self:ParseNumericOrPercent(allProperties["height"], "Height")
  local xPos, xRelativeFromX = self:ParseNumericOrPercent(allProperties["x"], "X")
  local yPos, yRelativeFromY = self:ParseNumericOrPercent(allProperties["y"], "Y")

  local relativeWidth = self:ToNumber(allProperties["relativewidth"], "RelativeWidth")
  local relativeHeight = self:ToNumber(allProperties["relativeheight"], "RelativeHeight")
  local relativeX = self:ToNumber(allProperties["relativex"], "RelativeX")
  local relativeY = self:ToNumber(allProperties["relativey"], "RelativeY")

  if (widthRelativeFromWidth ~= nil) then
    relativeWidth = widthRelativeFromWidth
    width = nil
  end

  if (heightRelativeFromHeight ~= nil) then
    relativeHeight = heightRelativeFromHeight
    height = nil
  end

  if (xRelativeFromX ~= nil) then
    relativeX = xRelativeFromX
    xPos = nil
  end

  if (yRelativeFromY ~= nil) then
    relativeY = yRelativeFromY
    yPos = nil
  end

  local anchorX = self:ToNumber(allProperties["anchorx"], "AnchorX")
  local anchorY = self:ToNumber(allProperties["anchory"], "AnchorY")
  local visible = self:ToBoolean(allProperties["visible"], "Visible")
  local alpha   = self:ToNumber(allProperties["alpha"], "Alpha")
  local aspectRatio = self:ParseAspectRatio(allProperties["aspectratio"], "AspectRatio")

  local visibilityRaw = allProperties["visibility"]
  local visibilityBool = nil
  if (visibilityRaw ~= nil) then
    if (visibilityRaw == "visible") then
      visibilityBool = true
    elseif (visibilityRaw == "hidden") then
      visibilityBool = false
    else
      error("[" .. (tagName or "?") .. "] Invalid CSS visibility value '" .. tostring(visibilityRaw) .. "': must be 'visible' or 'hidden'.")
    end
  end

  self:MarkConsumed(consumed, {
    "width", "height", "relativewidth", "relativeheight", "x", "y", "relativex", "relativey", "anchorx", "anchory", "visible", "alpha", "visibility", "aspectratio", "left", "top", "right", "bottom"
  })

  local requireSize = options ~= nil and options.requireSize == true
  local defaultRelativeSize = options ~= nil and options.defaultRelativeSize == true

  if (requireSize and (width == nil or height == nil) and (relativeWidth == nil or relativeHeight == nil)) then
    error("[" .. (tagName or "?") .. "] Element must have either Width/Height or RelativeWidth/RelativeHeight attributes.")
  end

  local hasExplicitWidth  = (width ~= nil or relativeWidth ~= nil)
  local hasExplicitHeight = (height ~= nil or relativeHeight ~= nil)

  if (defaultRelativeSize and width == nil and height == nil and relativeWidth == nil and relativeHeight == nil) then
    relativeWidth = 1
    relativeHeight = 1
  end

  if (aspectRatio ~= nil) then
    if (hasExplicitWidth and not hasExplicitHeight) then
      if (width ~= nil) then
        -- pixel width known at build time → derive pixel height immediately
        height = width / aspectRatio
      end
      -- relative-only width → deferred to BuildLayoutTree once parent px size is known
    elseif (hasExplicitHeight and not hasExplicitWidth) then
      if (height ~= nil) then
        -- pixel height known at build time → derive pixel width immediately
        width = height * aspectRatio
      end
      -- relative-only height → deferred to BuildLayoutTree
    end
  end

  if (width ~= nil or height ~= nil) then
    props.size = Util.vector2(width or 0, height or 0)
  end

  if (relativeWidth ~= nil or relativeHeight ~= nil) then
    props.relativeSize = Util.vector2(relativeWidth or 0, relativeHeight or 0)
  end

  if (xPos ~= nil or yPos ~= nil) then
    props.position = Util.vector2(xPos or 0, yPos or 0)
  end

  if (relativeX ~= nil or relativeY ~= nil) then
    props.relativePosition = Util.vector2(relativeX or 0, relativeY or 0)
  end

  if (anchorX ~= nil and anchorY ~= nil) then
    props.anchor = Util.vector2(anchorX, anchorY)
  end

  if (visibilityBool ~= nil) then
    props.visible = visibilityBool
  end

  if (visible ~= nil) then
    props.visible = visible
  end

  if (alpha ~= nil) then
    props.alpha = alpha
  end

  return props, consumed
end

-- Builds the mousePress/mouseMove resize handler functions for mw-root.
-- Returns plain Lua functions (not async:callback wrapped).
-- See BuildEventTable for the final wrapping step.
---@param edgeMargin number|nil Pixel distance from each window edge that activates a resize drag; defaults to 8.
---@return {mousePress: fun(e:table,l:table), mouseMove: fun(e:table,l:table)} Plain handler functions for edge-drag resizing.
function Renderer:BuildResizeFuncs(edgeMargin)
  local resizeState = {
    isDragging   = false,
    dragEdge     = nil,
    lastMousePos = nil,
  }

  local rendererRef = self
  local edgeMargin  = edgeMargin or 8
  local minSize     = 50

  local function getElementBounds(l)
    local elemX = 0
    local elemY = 0

    if (l.props.position ~= nil) then
      elemX = l.props.position.x
      elemY = l.props.position.y
    elseif (l.props.relativePosition ~= nil) then
      local screenSize = UI.screenSize()
      elemX = l.props.relativePosition.x * screenSize.x
      elemY = l.props.relativePosition.y * screenSize.y
    end

    local elemW = 0
    local elemH = 0

    if (l.props.size ~= nil) then
      elemW = l.props.size.x
      elemH = l.props.size.y
    elseif (l.props.relativeSize ~= nil) then
      local screenSize = UI.screenSize()
      elemW = l.props.relativeSize.x * screenSize.x
      elemH = l.props.relativeSize.y * screenSize.y
    end

    return elemX, elemY, elemW, elemH
  end

  return {
    mousePress = function(e, l)
      if (e.button ~= 1) then return end

      local elemX, elemY, elemW, elemH = getElementBounds(l)
      local mx = e.position.x
      local my = e.position.y

      local onLeft   = mx >= elemX and mx <= elemX + edgeMargin
      local onRight  = mx >= elemX + elemW - edgeMargin and mx <= elemX + elemW
      local onTop    = my >= elemY and my <= elemY + edgeMargin
      local onBottom = my >= elemY + elemH - edgeMargin and my <= elemY + elemH

      local edge = nil
      if (onTop and onLeft) then
        edge = "top-left"
      elseif (onTop and onRight) then
        edge = "top-right"
      elseif (onBottom and onLeft) then
        edge = "bottom-left"
      elseif (onBottom and onRight) then
        edge = "bottom-right"
      elseif (onLeft) then
        edge = "left"
      elseif (onRight) then
        edge = "right"
      elseif (onTop) then
        edge = "top"
      elseif (onBottom) then
        edge = "bottom"
      end

      if (edge ~= nil) then
        resizeState.isDragging   = true
        resizeState.dragEdge     = edge
        resizeState.lastMousePos = e.position
      else
        resizeState.isDragging   = false
        resizeState.dragEdge     = nil
        resizeState.lastMousePos = nil
      end
    end,

    mouseMove = function(e, l)
      if (not resizeState.isDragging) then return end

      -- Stop resizing if the left button is no longer held
      if (e.button ~= 1) then
        resizeState.isDragging   = false
        resizeState.dragEdge     = nil
        resizeState.lastMousePos = nil
        return
      end

      local last = resizeState.lastMousePos
      if (last == nil) then return end

      local dx = e.position.x - last.x
      local dy = e.position.y - last.y
      resizeState.lastMousePos = e.position

      local screenSize = UI.screenSize()

      -- Resolve current pixel position
      local curX = 0
      local curY = 0
      if (l.props.position ~= nil) then
        curX = l.props.position.x
        curY = l.props.position.y
      elseif (l.props.relativePosition ~= nil) then
        curX = l.props.relativePosition.x * screenSize.x
        curY = l.props.relativePosition.y * screenSize.y
      end

      -- Resolve current pixel size (required; bail out if not determinable)
      local curW = 0
      local curH = 0
      if (l.props.size ~= nil) then
        curW = l.props.size.x
        curH = l.props.size.y
      elseif (l.props.relativeSize ~= nil) then
        curW = l.props.relativeSize.x * screenSize.x
        curH = l.props.relativeSize.y * screenSize.y
      else
        return
      end

      local edge = resizeState.dragEdge
      local newW = curW
      local newH = curH
      local newX = curX
      local newY = curY

      -- Horizontal axis
      if (edge == "right" or edge == "bottom-right" or edge == "top-right") then
        newW = math.max(minSize, newW + dx)
      elseif (edge == "left" or edge == "bottom-left" or edge == "top-left") then
        local adjusted = math.max(minSize, newW - dx)
        newX = newX + (newW - adjusted)
        newW = adjusted
      end

      -- Vertical axis
      if (edge == "bottom" or edge == "bottom-right" or edge == "bottom-left") then
        newH = math.max(minSize, newH + dy)
      elseif (edge == "top" or edge == "top-right" or edge == "top-left") then
        local adjusted = math.max(minSize, newH - dy)
        newY = newY + (newH - adjusted)
        newH = adjusted
      end

      -- Switch element to absolute pixel size/position once resizing begins
      l.props.size         = Util.vector2(newW, newH)
      l.props.relativeSize = nil
      l.props.position     = Util.vector2(newX, newY)
      l.props.relativePosition = nil

      -- Suppress CSS left/top/right/bottom position overrides after the user
      -- has manually repositioned or resized the root.
      rendererRef._userPositionOverridden = true

      if (rendererRef.rootElement ~= nil) then
        rendererRef:Rerender()
      end
    end,
  }
end

-- Builds the mousePress/mouseMove drag handler functions.
-- Returns plain Lua functions (not async:callback wrapped).
-- See BuildEventTable for the final wrapping step.
---@return {mousePress: fun(e:table,l:table), mouseMove: fun(e:table,l:table)} Plain handler functions for drag-to-move.
function Renderer:BuildDraggerFuncs()
  local dragState = {
    isDragging   = false,
    lastMousePos = nil,
  }

  local rendererRef = self

  return {
    mousePress = function(e, l)
      if (e.button ~= 1) then return end
      dragState.isDragging   = true
      dragState.lastMousePos = e.position
    end,

    mouseMove = function(e, l)
      if (not dragState.isDragging) then return end

      if (e.button ~= 1) then
        dragState.isDragging   = false
        dragState.lastMousePos = nil
        return
      end

      local last = dragState.lastMousePos
      if (last == nil) then return end

      local dx = e.position.x - last.x
      local dy = e.position.y - last.y
      dragState.lastMousePos = e.position

      local rootLayout = rendererRef.rootLayout
      if (rootLayout == nil or rootLayout.props == nil) then return end

      local screenSize = UI.screenSize()

      local curX = 0
      local curY = 0
      if (rootLayout.props.position ~= nil) then
        curX = rootLayout.props.position.x
        curY = rootLayout.props.position.y
      elseif (rootLayout.props.relativePosition ~= nil) then
        curX = rootLayout.props.relativePosition.x * screenSize.x
        curY = rootLayout.props.relativePosition.y * screenSize.y
      end

      -- Resolve the root's current pixel size for clamping.
      local rootW = 0
      local rootH = 0
      if (rootLayout.props.size ~= nil) then
        rootW = rootLayout.props.size.x
        rootH = rootLayout.props.size.y
      elseif (rootLayout.props.relativeSize ~= nil) then
        rootW = rootLayout.props.relativeSize.x * screenSize.x
        rootH = rootLayout.props.relativeSize.y * screenSize.y
      end

      -- Clamp so the root cannot be dragged outside the screen.
      local newX = math.max(0, math.min(curX + dx, screenSize.x - rootW))
      local newY = math.max(0, math.min(curY + dy, screenSize.y - rootH))

      rootLayout.props.position         = Util.vector2(newX, newY)
      rootLayout.props.relativePosition = nil

      -- Suppress CSS left/top/right/bottom position overrides after the user
      -- has manually dragged the root.
      rendererRef._userPositionOverridden = true

      if (rendererRef.rootElement ~= nil) then
        rendererRef.rootElement:update()
      end
    end,
  }
end

-- Builds the focusGain / focusLoss / textInput handler functions that implement
-- placeholder behaviour for mw-text-edit elements.
-- Returns plain Lua functions (not async:callback wrapped).
-- See BuildEventTable for the final wrapping step.
---@param placeholder string The placeholder text shown when the field is empty and unfocused.
---@param initialText string|nil The initial user-supplied text (from the "Text" attribute), or nil for an empty field.
---@return {focusGain: fun(e,l), focusLoss: fun(e,l), textInput: fun(e,l)} Plain handler functions for placeholder behaviour.
function Renderer:BuildPlaceholderFuncs(placeholder, initialText)
  local state = {
    placeholder          = placeholder,
    userText             = initialText or "",
    isShowingPlaceholder = (initialText == nil or initialText == ""),
    isFocused            = false
  }

  local rendererRef = self

  return {
    ---@param e nil
    focusGain = function(e, l)
      state.isFocused = true
      if state.isShowingPlaceholder then
        state.isShowingPlaceholder = false
        l.props.text = state.userText
        if rendererRef.rootElement ~= nil then
          rendererRef.rootElement:update()
        end
      end
    end,
    focusLoss = function(e, l)
      state.isFocused = false
      if (string.len(state.userText) == 0) then
        state.isShowingPlaceholder = true
        l.props.text = state.placeholder
        if rendererRef.rootElement ~= nil then
          rendererRef.rootElement:update()
        end
      end
    end,
    ---@param e string The new text after the user input.
    textChanged = function(e, l)
      if (string.len(e) == 0) then
        state.userText = ""
      else
        state.userText = e
        state.isShowingPlaceholder = false
        l.props.text = e
      end
    end
  }
end

-- Builds the final layout.events table from system and user event function tables.
-- Both tables map event name strings to plain Lua functions.
-- When both define the same event name, the system handler fires first then the user handler.
-- Every handler is wrapped in async:callback for OpenMW compatibility.
---@param systemFuncs table<string, fun(e:table,l:table)>|nil System-generated event handlers (resize, drag, scroll).
---@param userFuncs table<string, fun(e:table,l:table)>|nil User-defined event handlers from template `(event)=` bindings.
---@return table<string, userdata>|nil Map of event name to async:callback-wrapped handler, or nil when no events are defined.
function Renderer:BuildEventTable(systemFuncs, userFuncs)
  local allNames = {}
  for k in pairs(systemFuncs or {}) do allNames[k] = true end
  for k in pairs(userFuncs or {}) do allNames[k] = true end

  if (next(allNames) == nil) then return nil end

  local events = {}
  for eventName in pairs(allNames) do
    local sf = (systemFuncs or {})[eventName]
    local uf = (userFuncs or {})[eventName]
    if (sf ~= nil and uf ~= nil) then
      local s, u = sf, uf
      events[eventName] = async:callback(function(e, l) s(e, l); u(e, l) return true end)
    elseif (sf ~= nil) then
      local s = sf
      events[eventName] = async:callback(function(e, l) s(e, l) return true end)
    else
      local u = uf
      events[eventName] = async:callback(function(e, l) u(e, l) return true end)
    end
  end

  return events
end

-- Gets the engine UI element that corresponds to a tag name.
---@param node Node The evaluated engine component node to translate into an OpenMW Layout.
---@param ancestors Node[] Ordered ancestor chain for CSS selector matching.
---@param containerContext table|nil Current container query context.
---@return table layout, table|nil meta The base OpenMW Layout table and an optional meta descriptor (custom-flex, custom-grid, custom-scroll-canvas, or padding-container).
function Renderer:GetEngineUIElement(node, ancestors, containerContext)
if (node.type ~= Node.TYPE_ENGINE_COMPONENT) then
  error("Cannot render node of type " .. node.type)
end

local tagName = node.tagName
if (not Renderer.IsValidEngineTag(tagName)) then
  error(tagName .. " is not a valid engine tag.")
end

local allProperties = self:ParseAcceptedProperties(node, ancestors, containerContext)
  local name = allProperties["name"]

  if (tagName == "mw-root") then
    local layer = allProperties["layer"]
    if (layer == nil) then
      error("mw-root elements must have a 'Layer' attribute.")
    end

    local props, consumed = self:ApplyCommonWidgetProperties(allProperties, { requireSize = true }, tagName)
    local resizable     = self:ToBoolean(allProperties["resizable"], "Resizable")
    local edgeMarginRaw = allProperties["edgemargin"]
    if (type(edgeMarginRaw) == "string") then
      edgeMarginRaw = string.gsub(edgeMarginRaw, "(%d+%.?%d*)px", "%1")
    end
    local edgeMargin = self:ToNumber(edgeMarginRaw, "EdgeMargin")
    self:MarkConsumed(consumed, { "name", "layer", "resizable", "edgemargin" })

    local resizeFuncs = nil
    if (resizable == true) then
      resizeFuncs = self:BuildResizeFuncs(edgeMargin)
    end

    return {
      layer = layer,
      name = name,
      props = props,
      __pendingSystemEvents = resizeFuncs,
      userData = self:BuildUserData(allProperties, consumed),
    }, nil
  elseif (tagName == "mw-window") then
    local props, consumed = self:ApplyCommonWidgetProperties(allProperties, { defaultRelativeSize = true }, tagName)
    self:MarkConsumed(consumed, { "background", "padding", "parsedpadding" })

    local background = allProperties["background"]
    -- alpha was already resolved by ApplyCommonWidgetProperties; nil means "no override".
    local alpha = props.alpha
    local includeBackground = background == nil or string.lower(tostring(background)) ~= "none"

    local windowContent = {}
    if (includeBackground) then
      table.insert(windowContent, {
        type = UI.TYPE.Image,
        props = {
          resource = UI.texture({
            path = "black"
          }),
          alpha = alpha and alpha + menuTransparencyAlphaValue or menuTransparencyAlphaValue,
          relativeSize = Util.vector2(1, 1)
        }
      })
    end
    table.insert(windowContent, {
      template = MWUI.templates.bordersThick,
      props = {
        relativeSize = Util.vector2(1, 1),
        alpha = alpha or 1,
      },
    })

    local parsedPadding = allProperties["parsedpadding"]
    local meta = nil
    if (parsedPadding ~= nil) then
      meta = {
        type    = "padding-container",
        padding = parsedPadding,
      }
    end

    return {
      name = name,
      props = props,
      content = UI.content(windowContent),
      userData = self:BuildUserData(allProperties, consumed),
    }, meta
  elseif (tagName == "mw-flex") then
    local props, consumed = self:ApplyCommonWidgetProperties(allProperties, { defaultRelativeSize = true }, tagName)
    local parsedPadding = allProperties["parsedpadding"] or {
      Top = 0,
      Right = 0,
      Bottom = 0,
      Left = 0,
    }

    self:MarkConsumed(consumed, { "name", "padding", "parsedpadding", "direction", "gap", "alignitems", "justifycontent" })

    return {
      name = name,
      props = props,
      userData = self:BuildUserData(allProperties, consumed),
    }, {
      type = "custom-flex",
      direction = allProperties["direction"] or "column",
      gap = self:ToNumber(allProperties["gap"], "Gap") or 0,
      padding = parsedPadding,
      alignItems = allProperties["alignitems"],
      justifyContent = allProperties["justifycontent"],
    }
  elseif (tagName == "mw-grid") then
    local props, consumed = self:ApplyCommonWidgetProperties(allProperties, { defaultRelativeSize = true }, tagName)
    local parsedPadding = allProperties["parsedpadding"] or {
      Top = 0,
      Right = 0,
      Bottom = 0,
      Left = 0,
    }

    self:MarkConsumed(consumed, {
      "name", "padding", "parsedpadding", "gap", "rowgap", "columngap", "gridtemplaterows", "gridtemplatecolumns", "alignitems", "justifycontent"
    })

    return {
      name = name,
      props = props,
      userData = self:BuildUserData(allProperties, consumed),
    }, {
      type = "custom-grid",
      padding = parsedPadding,
      templateRows = allProperties["gridtemplaterows"],
      templateColumns = allProperties["gridtemplatecolumns"],
      gap = allProperties["gap"],
      rowGap = allProperties["rowgap"],
      columnGap = allProperties["columngap"],
      alignItems = allProperties["alignitems"],
      justifyContent = allProperties["justifycontent"],
    }
  elseif (tagName == "mw-text") then
    local props, consumed = self:ApplyCommonWidgetProperties(allProperties, nil, tagName)

    local textNodesText = ""
    local textColorAttribute = allProperties["textcolor"]

    if (textColorAttribute ~= nil) then
      local r, g, b = string.match(tostring(textColorAttribute), "rgb%(([%d%.]+),([%d%.]+),([%d%.]+)%)")
      if (r ~= nil and g ~= nil and b ~= nil) then
        props.textColor = Util.color.rgb(tonumber(r), tonumber(g), tonumber(b))
      end
      consumed["textcolor"] = true
    end

    if (allProperties["textsize"] ~= nil) then
      props.textSize = self:ToNumber(allProperties["textsize"], "TextSize")
      consumed["textsize"] = true
    end

    if (allProperties["multiline"] ~= nil) then
      props.multiline = self:ToBoolean(allProperties["multiline"], "Multiline")
      consumed["multiline"] = true
    end

    if (allProperties["wordwrap"] ~= nil) then
      props.wordWrap = self:ToBoolean(allProperties["wordwrap"], "WordWrap")
      consumed["wordwrap"] = true
    end

    if (allProperties["textshadow"] ~= nil) then
      props.textShadow = self:ToBoolean(allProperties["textshadow"], "TextShadow")
      consumed["textshadow"] = true
    end

    if (allProperties["textalign"] ~= nil) then
      props.textAlignH = self:ToTextAlignH(allProperties["textalign"], "TextAlign")
      consumed["textalign"] = true
    end

    if (allProperties["verticalalign"] ~= nil) then
      props.textAlignV = self:ToTextAlignV(allProperties["verticalalign"], "VerticalAlign")
      consumed["verticalalign"] = true
    end

    for _, childNode in pairs(node.children) do
      if (childNode.type == Node.TYPE_TEXT) then
        textNodesText = textNodesText .. childNode.text
      else
        error("Only text nodes are allowed in mw-text elements. Encountered a node of type: " .. childNode.type)
      end
    end

    props.text = textNodesText

    if (allProperties["autosize"] ~= nil) then
      props.autoSize = self:ToBoolean(allProperties["autosize"], "AutoSize")
      consumed["autosize"] = true
    elseif (props.autoSize == nil) then
      props.autoSize = true
    end

    self:MarkConsumed(consumed, { "name" })

    return {
      name = name,
      type = UI.TYPE.Text,
      template = MWUI.templates.textNormal,
      props = props,
      userData = self:BuildUserData(allProperties, consumed),
    }, nil
  elseif (tagName == "mw-image") then
    local props, consumed = self:ApplyCommonWidgetProperties(allProperties, nil, tagName)

    local resourcePath = allProperties["resource"] or allProperties["src"] or allProperties["path"]
    if (resourcePath ~= nil) then
      props.resource = UI.texture({ path = tostring(resourcePath) })
      consumed["resource"] = true
      consumed["src"] = true
      consumed["path"] = true
    end

    if (allProperties["tileh"] ~= nil) then
      props.tileH = self:ToBoolean(allProperties["tileh"], "TileH")
      consumed["tileh"] = true
    end

    if (allProperties["tilev"] ~= nil) then
      props.tileV = self:ToBoolean(allProperties["tilev"], "TileV")
      consumed["tilev"] = true
    end

    self:MarkConsumed(consumed, { "name" })

    return {
      name = name,
      type = UI.TYPE.Image,
      props = props,
      userData = self:BuildUserData(allProperties, consumed),
    }, nil
  elseif (tagName == "mw-text-edit") then
    local props, consumed = self:ApplyCommonWidgetProperties(allProperties, nil, tagName)

    local placeholder = allProperties["placeholder"]
    if (placeholder ~= nil) then
      consumed["placeholder"] = true
    end

    local initialText = nil
    if (allProperties["text"] ~= nil) then
      initialText = tostring(allProperties["text"])
      props.text = initialText
      consumed["text"] = true
    end

    -- When a placeholder is defined and no initial text is present, display the
    -- placeholder as the initial text so the field looks populated while unfocused.
    if (placeholder ~= nil and (initialText == nil or initialText == "")) then
      props.text = tostring(placeholder)
    end

    if (allProperties["textsize"] ~= nil) then
      props.textSize = self:ToNumber(allProperties["textsize"], "TextSize")
      consumed["textsize"] = true
    end

    if (allProperties["multiline"] ~= nil) then
      props.multiline = self:ToBoolean(allProperties["multiline"], "Multiline")
      consumed["multiline"] = true
    end

    if (allProperties["wordwrap"] ~= nil) then
      props.wordWrap = self:ToBoolean(allProperties["wordwrap"], "WordWrap")
      consumed["wordwrap"] = true
    end

    if (allProperties["textalign"] ~= nil) then
      props.textAlignH = self:ToTextAlignH(allProperties["textalign"], "TextAlign")
      consumed["textalign"] = true
    end

    if (allProperties["verticalalign"] ~= nil) then
      props.textAlignV = self:ToTextAlignV(allProperties["verticalalign"], "VerticalAlign")
      consumed["verticalalign"] = true
    end

    if (allProperties["autosize"] ~= nil) then
      props.autoSize = self:ToBoolean(allProperties["autosize"], "AutoSize")
      consumed["autosize"] = true
    end

    self:MarkConsumed(consumed, { "name" })

    local placeholderFuncs = nil
    if (placeholder ~= nil) then
      placeholderFuncs = self:BuildPlaceholderFuncs(tostring(placeholder), initialText)
    end

    return {
      name = name,
      type = UI.TYPE.TextEdit,
      template = MWUI.templates.textEditBox,
      props = props,
      __pendingSystemEvents = placeholderFuncs,
      userData = self:BuildUserData(allProperties, consumed),
    }, nil
  elseif (tagName == "mw-hr") then
    local consumed = {}
    self:MarkConsumed(consumed, { "name", "dragger" })
    return {
      name = name,
      template = MWUI.templates.horizontalLine,
      userData = self:BuildUserData(allProperties, consumed),
    }, nil
  elseif (tagName == "mw-scroll-canvas") then
    local props, consumed = self:ApplyCommonWidgetProperties(allProperties, { requireSize = true }, tagName)
    local parsedPadding = allProperties["parsedpadding"] or {
      Top = 0,
      Right = 0,
      Bottom = 0,
      Left = 0,
    }

    local sbSize    = self:ToNumber(allProperties["scrollbarsize"], "ScrollBarSize") or 16
    local scrollStep = self:ToNumber(allProperties["scrollstep"], "ScrollStep") or 30

    -- Assign a stable ID so scroll offsets survive Rerender() calls.
    -- Named elements use their name; anonymous elements use a per-render counter.
    self._scrollCanvasIdCounter = (self._scrollCanvasIdCounter or 0) + 1
    local scrollId = name ~= nil and tostring(name) or ("__scroll_" .. self._scrollCanvasIdCounter)

    if (self._scrollStates == nil) then
      self._scrollStates = {}
    end
    local state = self._scrollStates[scrollId]
    if (state == nil) then
      state = { x = 0, y = 0 }
      self._scrollStates[scrollId] = state
    end

    local rendererRef = self

    -- updateScrollVisuals: directly mutates layout references stored in `state`
    -- and triggers a lightweight update().  Captured by the drag handlers on
    -- the outer widget AND by the scrollbar button handlers built later in
    -- ApplyScrollCanvasContainer; both sets share the same persistent state table
    -- so they always operate on the current layout after any Rerender().
    if (state.updateScrollVisuals == nil) then
      local function updateScrollVisuals()
        if (state.contentLayout ~= nil) then
          local pad = state.padding or { Left = 0, Top = 0 }
          state.contentLayout.props.position = Util.vector2(
            -state.x + pad.Left,
            -state.y + pad.Top
          )
        end
        if (state.vThumbLayout ~= nil and (state.maxY or 0) > 0) then
          local vRatio = state.y / state.maxY
          local thumbY = vRatio * ((state.trackH or 0) - (state.vThumbH or 0))
          state.vThumbLayout.props.position = Util.vector2(0, thumbY)
        end
        if (state.hThumbLayout ~= nil and (state.maxX or 0) > 0) then
          local hRatio = state.x / state.maxX
          local thumbX = hRatio * ((state.trackW or 0) - (state.hThumbW or 0))
          state.hThumbLayout.props.position = Util.vector2(thumbX, 0)
        end
        if (rendererRef.rootElement ~= nil) then
          rendererRef.rootElement:update()
        end
      end
      state.updateScrollVisuals = updateScrollVisuals
    end

    self:MarkConsumed(consumed, {
      "name", "padding", "parsedpadding", "direction", "gap", "scrollbarsize", "scrollstep"
    })

    return {
      name  = name,
      props = props,
      userData = self:BuildUserData(allProperties, consumed),
      -- Register drag-continuation and drag-release on the outer widget so the
      -- thumb tracks the cursor even when the pointer moves outside the thumb.
      __pendingSystemEvents = {
        mouseMove = function(e, l)
          if (state.vDragging and state.vLastMouse ~= nil) then
            if (e.button ~= 1) then
              state.vDragging  = false
              state.vLastMouse = nil
            else
              local dy = e.position.y - state.vLastMouse.y
              state.vLastMouse = e.position
              local scrollable = (state.trackH or 0) - (state.vThumbH or 0)
              if (scrollable > 0 and (state.maxY or 0) > 0) then
                local delta = (dy / scrollable) * state.maxY
                state.y = math.max(0, math.min(state.maxY, state.y + delta))
                state.updateScrollVisuals()
              end
            end
          end
          if (state.hDragging and state.hLastMouse ~= nil) then
            if (e.button ~= 1) then
              state.hDragging  = false
              state.hLastMouse = nil
            else
              local dx = e.position.x - state.hLastMouse.x
              state.hLastMouse = e.position
              local scrollable = (state.trackW or 0) - (state.hThumbW or 0)
              if (scrollable > 0 and (state.maxX or 0) > 0) then
                local delta = (dx / scrollable) * state.maxX
                state.x = math.max(0, math.min(state.maxX, state.x + delta))
                state.updateScrollVisuals()
              end
            end
          end
        end,
        mouseRelease = function(e, l)
          if (e.button == 1) then
            state.vDragging  = false
            state.hDragging  = false
            state.vLastMouse = nil
            state.hLastMouse = nil
          end
        end,
      },
    }, {
      type          = "custom-scroll-canvas",
      state         = state,
      padding       = parsedPadding,
      direction     = allProperties["direction"] or "column",
      gap           = self:ToNumber(allProperties["gap"], "Gap") or 0,
      scrollBarSize = sbSize,
      scrollStep    = scrollStep,
      scrollId      = scrollId,
    }
  elseif (tagName == "mw-widget") then
    local props, consumed = self:ApplyCommonWidgetProperties(allProperties, nil, tagName)
    local parsedPadding = allProperties["parsedpadding"]

    self:MarkConsumed(consumed, { "name", "padding", "parsedpadding" })

    if (parsedPadding ~= nil) then
      return {
        name = name,
        props = props,
        userData = self:BuildUserData(allProperties, consumed),
      }, {
        type = "padding-container",
        padding = parsedPadding,
      }
    end

    return {
      name = name,
      props = props,
      userData = self:BuildUserData(allProperties, consumed),
    }, nil
  end
end

-- Builds the resolved property table for a node.
-- Sources, in ascending priority order:
--   1. CSS rules (via GetCSSAttributesForNode)
--   2. [style.X]="expr" evaluated bindings  (style properties only)
--   3. Whitelisted non-style HTML attributes (layer, name, dragger, resource, …)
-- Direct style-named HTML attributes (e.g. Height="24") are intentionally
-- ignored – styling belongs in CSS or [style.X] bindings.
---@param node Node The evaluated node whose attributes and matching CSS rules are combined.
---@param ancestors Node[] Ordered ancestor chain for CSS matching.
---@param containerContext table|nil Current container query context.
---@return table<string, any> Merged property map (CSS < [style.X] bindings < structural HTML attributes).
function Renderer:ParseAcceptedProperties(node, ancestors, containerContext)
  local properties = self:GetCSSAttributesForNode(node, ancestors, containerContext)

  for attributeName, attributeValue in pairs(node.attributes or {}) do
    local lowerName = string.lower(attributeName)

    -- [style.X] evaluated bindings: map JS camelCase property to internal name.
    -- A nil or false value means the binding is inactive; fall back to the CSS value.
    local styleProp = string.match(lowerName, "^style%.(.+)$")
    if (styleProp ~= nil) then
      local internalName = STYLE_BINDING_TO_ATTRIBUTE[styleProp]
      if (internalName ~= nil and attributeValue ~= nil and attributeValue ~= false) then
        if (type(attributeValue) == "string") then
          attributeValue = string.gsub(attributeValue, "(%d+%.?%d*)px", "%1")
        end
        properties[internalName] = attributeValue
      end
    elseif (NON_STYLE_ATTRIBUTES[lowerName]) then
      -- Structural / behavioral / content attributes pass through as-is.
      properties[lowerName] = attributeValue
    end
    -- All other direct HTML style attributes are silently ignored.
  end

  -- Resolve CSS grid-column / grid-row shorthand values that include a span.
  --   "1 / span 2"  → gridcolumn = 1,  gridcolumnspan = 2
  --   "1 / 3"       → gridcolumn = 1,  gridcolumnspan = 2  (endLine - startLine)
  --   "1"           → gridcolumn = 1   (span defaults to 1 in ArrangeGridChildren)
  local gridLinePairs = {
    { "gridcolumn", "gridcolumnspan" },
    { "gridrow",    "gridrowspan"    },
  }
  for _, pair in ipairs(gridLinePairs) do
    local colKey, spanKey = pair[1], pair[2]
    local val = properties[colKey]
    if (type(val) == "string") then
      local startCol, span = string.match(val, "^%s*(%d+)%s*/%s*span%s+(%d+)%s*$")
      if (startCol ~= nil) then
        properties[colKey] = startCol
        if (properties[spanKey] == nil) then
          properties[spanKey] = span
        end
      else
        local startLine, endLine = string.match(val, "^%s*(%d+)%s*/%s*(%d+)%s*$")
        if (startLine ~= nil) then
          local s = tonumber(startLine)
          local e = tonumber(endLine)
          if (s ~= nil and e ~= nil and e > s) then
            properties[colKey] = tostring(s)
            if (properties[spanKey] == nil) then
              properties[spanKey] = tostring(e - s)
            end
          end
        end
      end
    end
  end

  if (node.tagName == "mw-flex" or node.tagName == "mw-widget" or node.tagName == "mw-grid" or node.tagName == "mw-scroll-canvas" or node.tagName == "mw-window") then
    local padding = properties["padding"]
    if (padding ~= nil) then
      properties["parsedpadding"] = self:ParsePadding(padding)
    end
  end

  return properties
end

-- Parses a string that can contain between 1 and 4 numbers
-- Parses it in CSS-format
-- Always return a table with keys "Top, Right, Bottom, Left"
---@param paddingString string CSS-style padding shorthand (1–4 space-separated whole-number values).
---@return {Top: number, Right: number, Bottom: number, Left: number}
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

---@param value any A number or a string such as "200" or "50%".
---@param propertyName string Used in error messages on parse failure.
---@return number|nil pixelValue, number|nil relativeValue Exactly one of the two return values will be non-nil.
function Renderer:ParseNumericOrPercent(value, propertyName)
  if (value == nil) then
    return nil, nil
  end

  if (type(value) == "number") then
    return value, nil
  end

  if (type(value) == "string") then
    local trimmed = value:match("^%s*(.-)%s*$")
    local percent = string.match(trimmed, "^([%+%-]?%d+%.?%d*)%%$")
    if (percent ~= nil) then
      return nil, tonumber(percent) / 100
    end

    local number = tonumber(trimmed)
    if (number ~= nil) then
      return number, nil
    end
  end

  error("Invalid number or percent value for property '" .. propertyName .. "': " .. tostring(value))
end

---@param consumed table<string, boolean> The consumed-keys map to update.
---@param keys string[] Attribute key strings to mark as consumed (stored lowercased).
function Renderer:MarkConsumed(consumed, keys)
  for _, key in ipairs(keys) do
    consumed[string.lower(key)] = true
  end
end

---@param allProperties table<string, any> The full resolved property map for the element.
---@param consumedKeys table<string, boolean> Keys already applied to Layout props that should be excluded.
---@return table|nil A table of leftover properties for the Layout's `userData` field, or nil when empty.
function Renderer:BuildUserData(allProperties, consumedKeys)
  local userData = nil

  for key, value in pairs(allProperties) do
    if (not consumedKeys[key]) then
      if (userData == nil) then
        userData = {}
      end

      userData[key] = value
    end
  end

  return userData
end

---@param value any A single number or a string with one or two whitespace-separated numeric tokens.
---@param fallback number|nil Value to use when `value` is nil (default 0).
---@return number rowGap, number columnGap Two gap values; single-value input yields equal row and column gaps.
function Renderer:ParseSpacingPair(value, fallback)
  if (value == nil) then
    return fallback or 0, fallback or 0
  end

  if (type(value) == "number") then
    return value, value
  end

  local raw = tostring(value)
  local tokens = {}
  for token in string.gmatch(raw, "%S+") do
    table.insert(tokens, token)
  end

  if (#tokens == 0) then
    local defaultValue = fallback or 0
    return defaultValue, defaultValue
  end

  if (#tokens == 1) then
    local v = self:ToNumber(tokens[1], "Gap")
    return v, v
  end

  return self:ToNumber(tokens[1], "RowGap"), self:ToNumber(tokens[2], "ColumnGap")
end

---@param trackDefinition any CSS-style track template string (e.g. "1fr 2fr", "100 50%", "repeat(3, 1fr)") or nil.
---@return {kind: string, value: number}[] Ordered track descriptors where `kind` is "fr", "px", "percent", or "auto".
function Renderer:ParseGridTracks(trackDefinition)
  local tracks = {}

  if (trackDefinition == nil) then
    return tracks
  end

  local definition = tostring(trackDefinition):match("^%s*(.-)%s*$")

  -- Expand repeat() calls before tokenising.
  -- Supports: repeat(3, 1fr)  repeat(5, 100px)  repeat(2, 50%)  repeat(4, auto)
  -- Multiple repeat() calls in the same string are all expanded.
  definition = definition:gsub("repeat%(%s*(%d+)%s*,%s*(.-)%s*%)", function(countStr, trackStr)
    local count = tonumber(countStr)
    if (count == nil or count < 1) then
      error("Invalid repeat() count: '" .. countStr .. "'")
    end
    local expanded = {}
    for _ = 1, count do
      table.insert(expanded, trackStr)
    end
    return table.concat(expanded, " ")
  end)

  for token in string.gmatch(definition, "%S+") do
    local trimmed = token:match("^%s*(.-)%s*$")
    local fr = string.match(trimmed, "^([%+%-]?%d+%.?%d*)fr$")
    local pct = string.match(trimmed, "^([%+%-]?%d+%.?%d*)%%$")

    if (fr ~= nil) then
      table.insert(tracks, { kind = "fr", value = tonumber(fr) })
    elseif (pct ~= nil) then
      table.insert(tracks, { kind = "percent", value = tonumber(pct) / 100 })
    else
      local px = tonumber(trimmed)
      if (px ~= nil) then
        table.insert(tracks, { kind = "px", value = px })
      elseif (trimmed == "auto") then
        table.insert(tracks, { kind = "auto", value = 0 })
      end
    end
  end

  return tracks
end

---@param tracks {kind: string, value: number}[] Parsed track descriptors from ParseGridTracks.
---@param containerAxisSize number|nil Available pixel space along this axis; required for fr and percent tracks.
---@param gapSize number|nil Pixel gap between tracks; subtracted before distributing fr units.
---@return number[] Resolved pixel size for each track in the same order as `tracks`.
function Renderer:ResolveGridTrackSizes(tracks, containerAxisSize, gapSize)
  if (#tracks == 0) then
    return {}
  end

  local resolvedGap = gapSize or 0
  local sizes = {}
  local totalFixed = 0
  local totalFr = 0

  for i, track in ipairs(tracks) do
    if (track.kind == "px") then
      sizes[i] = track.value
      totalFixed = totalFixed + track.value
    elseif (track.kind == "percent") then
      local value = containerAxisSize ~= nil and (containerAxisSize * track.value) or 0
      sizes[i] = value
      totalFixed = totalFixed + value
    elseif (track.kind == "fr") then
      sizes[i] = 0
      totalFr = totalFr + track.value
    else
      sizes[i] = 0
    end
  end

  if (totalFr > 0 and containerAxisSize ~= nil) then
    -- Subtract gap space between tracks before distributing fr units
    local totalGapSpace = (#tracks - 1) * resolvedGap
    local remaining = containerAxisSize - totalFixed - totalGapSpace
    if (remaining < 0) then
      remaining = 0
    end

    local unit = remaining / totalFr
    for i, track in ipairs(tracks) do
      if (track.kind == "fr") then
        sizes[i] = unit * track.value
      end
    end
  end

  return sizes
end

---@param trackSizes number[] Resolved pixel size for each track.
---@param gap number Pixel gap inserted between adjacent tracks.
---@return number[] 1-based array of pixel start offsets for each track.
function Renderer:BuildGridStarts(trackSizes, gap)
  local starts = {}
  local cursor = 0

  for i, size in ipairs(trackSizes) do
    starts[i] = cursor
    cursor = cursor + size
    if (i < #trackSizes) then
      cursor = cursor + gap
    end
  end

  return starts
end

---@param occupancy table<integer, table<integer, boolean>> 2D occupancy grid (row → column → occupied).
---@param row integer 1-based row index.
---@param col integer 1-based column index.
function Renderer:EnsureGridCell(occupancy, row, col)
  if (occupancy[row] == nil) then
    occupancy[row] = {}
  end

  if (occupancy[row][col] == nil) then
    occupancy[row][col] = false
  end
end

---@param occupancy table<integer, table<integer, boolean>> The 2D occupancy grid.
---@param row integer Top-left row of the area to test (1-based).
---@param col integer Top-left column of the area to test (1-based).
---@param rowSpan integer Number of rows the area spans.
---@param colSpan integer Number of columns the area spans.
---@return boolean True when every cell in the area is unoccupied.
function Renderer:IsGridAreaFree(occupancy, row, col, rowSpan, colSpan)
  for r = row, row + rowSpan - 1 do
    for c = col, col + colSpan - 1 do
      self:EnsureGridCell(occupancy, r, c)
      if (occupancy[r][c]) then
        return false
      end
    end
  end

  return true
end

---@param occupancy table<integer, table<integer, boolean>> The 2D occupancy grid.
---@param row integer Top-left row of the area (1-based).
---@param col integer Top-left column (1-based).
---@param rowSpan integer Number of rows to mark.
---@param colSpan integer Number of columns to mark.
function Renderer:MarkGridArea(occupancy, row, col, rowSpan, colSpan)
  for r = row, row + rowSpan - 1 do
    for c = col, col + colSpan - 1 do
      self:EnsureGridCell(occupancy, r, c)
      occupancy[r][c] = true
    end
  end
end

---@param preChildMetas {gridColumn: number|nil, gridRow: number|nil, gridColumnSpan: number|nil, gridRowSpan: number|nil}[] Lightweight placement metadata for each direct engine-component child (derived from a ParseAcceptedProperties pre-pass).
---@param meta table Grid metadata (templateColumns, templateRows, gap, rowGap, columnGap).
---@param innerPixelSize {x: number|nil, y: number|nil}|nil Inner pixel area of the grid container.
---@return {x: number, y: number}[] Per-child cell pixel sizes in the same order as `preChildMetas`.
function Renderer:PrecomputeGridCellSizes(preChildMetas, meta, innerPixelSize)
  local rowGap, columnGap = self:ParseSpacingPair(meta.gap, 0)
  if (meta.rowGap ~= nil) then
    rowGap = self:ToNumber(meta.rowGap, "RowGap")
  end
  if (meta.columnGap ~= nil) then
    columnGap = self:ToNumber(meta.columnGap, "ColumnGap")
  end

  local columnTracks = self:ParseGridTracks(meta.templateColumns)
  if (#columnTracks == 0) then
    columnTracks = { { kind = "fr", value = 1 } }
  end
  local numColumns = #columnTracks

  local containerWidth  = innerPixelSize and innerPixelSize.x or nil
  local containerHeight = innerPixelSize and innerPixelSize.y or nil

  -- Phase 1: placement (mirrors ArrangeGridChildren)
  local placements = {}
  local occupancy  = {}
  local autoRow    = 1
  local autoColumn = 1
  local maxUsedRow = 0

  for i, childMeta in ipairs(preChildMetas) do
    local columnSpan = math.max(1, childMeta.gridColumnSpan or 1)
    local rowSpan    = math.max(1, childMeta.gridRowSpan    or 1)
    if (columnSpan > numColumns) then columnSpan = numColumns end

    local placedRow    = childMeta.gridRow
    local placedColumn = childMeta.gridColumn

    if (placedRow ~= nil and placedColumn ~= nil) then
      self:MarkGridArea(occupancy, placedRow, placedColumn, rowSpan, columnSpan)
    else
      local found = false
      for r = autoRow, autoRow + #preChildMetas + numColumns do
        local colStart = (r == autoRow) and autoColumn or 1
        for c = colStart, numColumns do
          if (c + columnSpan - 1 <= numColumns and self:IsGridAreaFree(occupancy, r, c, rowSpan, columnSpan)) then
            placedRow    = r
            placedColumn = c
            autoRow      = r
            autoColumn   = c + columnSpan
            if (autoColumn > numColumns) then
              autoColumn = 1
              autoRow    = autoRow + 1
            end
            found = true
            break
          end
        end
        if (found) then break end
      end
      if (not found) then
        placedRow    = autoRow
        placedColumn = 1
      end
      self:MarkGridArea(occupancy, placedRow, placedColumn, rowSpan, columnSpan)
    end

    local bottomRow = (placedRow or 1) + rowSpan - 1
    if (bottomRow > maxUsedRow) then maxUsedRow = bottomRow end

    placements[i] = {
      row        = placedRow or 1,
      column     = placedColumn or 1,
      rowSpan    = rowSpan,
      columnSpan = columnSpan,
    }
  end

  -- Phase 2: build implicit row tracks
  local rowTracks = self:ParseGridTracks(meta.templateRows)
  while (#rowTracks < maxUsedRow) do
    table.insert(rowTracks, { kind = "fr", value = 1 })
  end

  -- Phase 3: resolve track pixel sizes
  local columnSizes = self:ResolveGridTrackSizes(columnTracks, containerWidth,  columnGap)
  local rowSizes    = self:ResolveGridTrackSizes(rowTracks,    containerHeight, rowGap)

  -- Phase 4: sum cell pixel sizes per child
  local cellSizes = {}
  for i, p in ipairs(placements) do
    local w = 0
    for c = p.column, p.column + p.columnSpan - 1 do
      w = w + (columnSizes[c] or 0)
      if (c < p.column + p.columnSpan - 1) then w = w + columnGap end
    end
    local h = 0
    for r = p.row, p.row + p.rowSpan - 1 do
      h = h + (rowSizes[r] or 0)
      if (r < p.row + p.rowSpan - 1) then h = h + rowGap end
    end
    cellSizes[i] = { x = w, y = h }
  end

  return cellSizes
end

---@param childLayouts table[] Child Layout tables to place in the grid.
---@param meta {type: string, padding: table, templateRows: any, templateColumns: any, gap: any, rowGap: any, columnGap: any, alignItems: string|nil, justifyContent: string|nil} Grid metadata. alignItems/justifyContent accept "start"|"center"|"end"|"stretch".
---@param innerPixelSize {x: number|nil, y: number|nil}|nil Inner pixel area of the grid container.
---@return table[] The same `childLayouts` with `props.position` set to grid-computed values (child sizes are preserved or resolved from relativeSize relative to cell).
function Renderer:ArrangeGridChildren(childLayouts, meta, innerPixelSize)
  local rowGap, columnGap = self:ParseSpacingPair(meta.gap, 0)
  if (meta.rowGap ~= nil) then
    rowGap = self:ToNumber(meta.rowGap, "RowGap")
  end
  if (meta.columnGap ~= nil) then
    columnGap = self:ToNumber(meta.columnGap, "ColumnGap")
  end

  local columnTracks = self:ParseGridTracks(meta.templateColumns)
  if (#columnTracks == 0) then
    columnTracks = { { kind = "fr", value = 1 } }
  end
  local numColumns = #columnTracks

  local containerWidth = innerPixelSize and innerPixelSize.x or nil
  local containerHeight = innerPixelSize and innerPixelSize.y or nil

  -- Phase 1: Placement pass - determine row/col for every child without computing sizes
  local placements = {}
  local occupancy = {}
  local autoRow = 1
  local autoColumn = 1
  local maxUsedRow = 0

  for i, child in ipairs(childLayouts) do
    child.props = child.props or {}

    local requestedColumn = child.__anglesGridColumn
    local requestedRow = child.__anglesGridRow
    local columnSpan = math.max(1, child.__anglesGridColumnSpan or 1)
    local rowSpan = math.max(1, child.__anglesGridRowSpan or 1)

    if (columnSpan > numColumns) then
      columnSpan = numColumns
    end

    local placedRow = requestedRow
    local placedColumn = requestedColumn

    if (placedRow ~= nil and placedColumn ~= nil) then
      self:MarkGridArea(occupancy, placedRow, placedColumn, rowSpan, columnSpan)
    else
      local found = false
      local searchRow = autoRow

      for r = searchRow, searchRow + #childLayouts + numColumns do
        local colStart = (r == searchRow) and autoColumn or 1
        for c = colStart, numColumns do
          if (c + columnSpan - 1 <= numColumns and self:IsGridAreaFree(occupancy, r, c, rowSpan, columnSpan)) then
            placedRow = r
            placedColumn = c
            autoRow = r
            autoColumn = c + columnSpan
            if (autoColumn > numColumns) then
              autoColumn = 1
              autoRow = autoRow + 1
            end
            found = true
            break
          end
        end
        if (found) then
          break
        end
      end

      if (not found) then
        placedRow = autoRow
        placedColumn = 1
      end

      self:MarkGridArea(occupancy, placedRow, placedColumn, rowSpan, columnSpan)
    end

    local bottomRow = (placedRow or 1) + rowSpan - 1
    if (bottomRow > maxUsedRow) then
      maxUsedRow = bottomRow
    end

    placements[i] = {
      row = placedRow or 1,
      column = placedColumn or 1,
      rowSpan = rowSpan,
      columnSpan = columnSpan,
    }
  end

  -- Phase 2: Build row tracks - add implicit 1fr rows until we cover all used rows
  local rowTracks = self:ParseGridTracks(meta.templateRows)
  while (#rowTracks < maxUsedRow) do
    table.insert(rowTracks, { kind = "fr", value = 1 })
  end

  -- Phase 3: Compute track sizes, accounting for gaps in fr distribution
  local columnSizes = self:ResolveGridTrackSizes(columnTracks, containerWidth, columnGap)
  local rowSizes = self:ResolveGridTrackSizes(rowTracks, containerHeight, rowGap)

  local columnStarts = self:BuildGridStarts(columnSizes, columnGap)
  local rowStarts = self:BuildGridStarts(rowSizes, rowGap)

  -- Phase 4: Apply geometry to each child.
  -- justify-content: start/center/end shifts the entire column track group within the container.
  --                  stretch forces each child's width to fill its cell width.
  -- align-items:     start/center/end positions each child vertically within its row cell.
  --                  stretch forces each child's height to fill its cell height.
  -- Children keep their own size otherwise; relativeSize is resolved against the cell.
  local justifyContent = meta.justifyContent or "start"
  local alignItems     = meta.alignItems     or "start"

  -- Compute the column-group horizontal offset for justify-content (not used for stretch).
  local justifyContentOffsetX = 0
  if (justifyContent ~= "start" and justifyContent ~= "stretch" and containerWidth ~= nil) then
    local totalColumnsWidth = 0
    for _, sz in ipairs(columnSizes) do
      totalColumnsWidth = totalColumnsWidth + sz
    end
    if (#columnSizes > 1) then
      totalColumnsWidth = totalColumnsWidth + (#columnSizes - 1) * columnGap
    end
    local available = containerWidth - totalColumnsWidth
    if (available > 0) then
      if (justifyContent == "center") then
        justifyContentOffsetX = math.floor(available / 2)
      elseif (justifyContent == "end") then
        justifyContentOffsetX = available
      end
    end
  end

  for i, child in ipairs(childLayouts) do
    local p = placements[i]

    -- Compute cell pixel bounds (position of top-left corner + span extents).
    local cellX = (columnStarts[p.column] or 0) + justifyContentOffsetX
    local cellY = rowStarts[p.row] or 0

    local cellW = 0
    for c = p.column, p.column + p.columnSpan - 1 do
      cellW = cellW + (columnSizes[c] or 0)
      if (c < p.column + p.columnSpan - 1) then
        cellW = cellW + columnGap
      end
    end

    local cellH = 0
    for r = p.row, p.row + p.rowSpan - 1 do
      cellH = cellH + (rowSizes[r] or 0)
      if (r < p.row + p.rowSpan - 1) then
        cellH = cellH + rowGap
      end
    end

    -- Resolve the child's effective pixel size.
    -- If the child has a relativeSize, evaluate it against the cell dimensions and
    -- convert to an absolute size so OpenMW doesn't resolve it against the padded
    -- container (which is the wrong parent for per-cell percentages).
    child.props = child.props or {}
    local childAbsSize = child.props.size
    local childRelSize = child.props.relativeSize

    local childW = 0
    local childH = 0

    if (childRelSize ~= nil) then
      local baseW = childAbsSize and (childAbsSize.x or 0) or 0
      local baseH = childAbsSize and (childAbsSize.y or 0) or 0
      childW = (childRelSize.x or 0) * cellW + baseW
      childH = (childRelSize.y or 0) * cellH + baseH
      child.props.size     = Util.vector2(childW, childH)
      child.props.relativeSize = nil
    elseif (childAbsSize ~= nil) then
      childW = childAbsSize.x or 0
      childH = childAbsSize.y or 0
    end

    -- Apply stretch: override child dimensions to fill the full cell on the relevant axis.
    if (justifyContent == "stretch") then
      childW = cellW
    end
    if (alignItems == "stretch") then
      childH = cellH
    end
    if (justifyContent == "stretch" or alignItems == "stretch") then
      child.props.size     = Util.vector2(childW, childH)
      child.props.relativeSize = nil
    end

    -- Compute vertical alignment offset within the row cell (align-items).
    local offsetY = 0
    local availY = cellH - childH
    if (availY > 0) then
      if (alignItems == "center") then
        offsetY = math.floor(availY / 2)
      elseif (alignItems == "end") then
        offsetY = availY
      end
    end

    child.props.position         = Util.vector2(cellX, cellY + offsetY)
    child.props.relativePosition = nil

    child.__anglesGridColumn     = nil
    child.__anglesGridRow        = nil
    child.__anglesGridColumnSpan = nil
    child.__anglesGridRowSpan    = nil
  end

  return childLayouts
end

---@param layout table The Layout table that owns an `__anglesCustomGrid` state block.
---@param innerPixelSize {x: number|nil, y: number|nil}|nil New inner pixel size for the grid.
function Renderer:RebuildCustomGridLayout(layout, innerPixelSize)
  local state = layout.__anglesCustomGrid
  if (state == nil) then
    return
  end

  -- Restore original placement metadata before each arrangement so spans are re-read
  for i, child in ipairs(state.childLayouts) do
    local original = state.originalChildMeta[i]
    child.__anglesGridColumn     = original.gridColumn
    child.__anglesGridRow        = original.gridRow
    child.__anglesGridColumnSpan = original.gridColumnSpan
    child.__anglesGridRowSpan    = original.gridRowSpan
    -- Restore size/relativeSize so ArrangeGridChildren re-resolves from scratch.
    child.props              = child.props or {}
    child.props.size         = original.size
    child.props.relativeSize = original.relativeSize
    child.props.position     = original.position
    child.props.relativePosition = original.relativePosition
  end

  local arrangedChildren = self:ArrangeGridChildren(state.childLayouts, state.meta, innerPixelSize)

  local padding = state.meta.padding
  local paddedContainer = {
    props = {
      relativeSize = Util.vector2(1, 1),
      size = Util.vector2(-(padding.Left + padding.Right), -(padding.Top + padding.Bottom)),
      position = Util.vector2(padding.Left, padding.Top),
    },
    content = UI.content(arrangedChildren)
  }

  layout.content = UI.content({ paddedContainer })
end

-- Re-runs ArrangeFlexChildren for a flex layout using a new inner pixel size.
-- Called when an ancestor's grow resolution reveals the element's actual size
-- differs from the build-time estimate.
---@param layout table The Layout table that owns an `__anglesCustomFlex` state block.
---@param innerPixelSize {x: number|nil, y: number|nil}|nil New inner pixel size for the flex container.
function Renderer:RebuildCustomFlexLayout(layout, innerPixelSize)
  local state = layout.__anglesCustomFlex
  if (state == nil) then return end

  -- Restore each child's original pre-arrangement props so ArrangeFlexChildren
  -- gets a clean slate (correct sizes, nil positions, grow values intact).
  for i, child in ipairs(state.childLayouts) do
    local original = state.originalChildProps[i]
    if (original ~= nil) then
      child.props              = child.props or {}
      child.props.size         = original.size
      child.props.relativeSize = original.relativeSize
      child.props.position     = original.position
      child.props.relativePosition = original.relativePosition
      child.__anglesFlexGrow   = original.flexGrow
    end
  end

  local arrangedChildren = self:ArrangeFlexChildren(
    state.childLayouts, state.meta.direction, state.meta.gap, innerPixelSize,
    { alignItems = state.meta.alignItems, justifyContent = state.meta.justifyContent }
  )

  state.paddedContainer.content = UI.content(arrangedChildren)
end

---@param outerLayout table The Layout table for the mw-scroll-canvas element.
---@param childLayouts table[] The scrollable content children.
---@param meta {type: string, state: table, padding: table, direction: string, gap: number, scrollBarSize: number, scrollStep: number, scrollId: string} Scroll canvas metadata.
---@param canvasPixelSize {x: number|nil, y: number|nil}|nil Resolved pixel size of the scroll canvas widget.
function Renderer:ApplyScrollCanvasContainer(outerLayout, childLayouts, meta, canvasPixelSize)
  local state     = meta.state
  local padding   = meta.padding
  local sbSize    = meta.scrollBarSize
  local gap       = meta.gap
  local direction = meta.direction
  local isRow     = direction == "row"

  local canvasW = canvasPixelSize and canvasPixelSize.x or 0
  local canvasH = canvasPixelSize and canvasPixelSize.y or 0

  -- The viewport occupies the canvas minus one scrollbar strip on each edge.
  local viewportW = math.max(0, canvasW - sbSize)
  local viewportH = math.max(0, canvasH - sbSize)

  -- Inner area inside the content padding.
  local innerW = math.max(0, viewportW - padding.Left - padding.Right)
  local innerH = math.max(0, viewportH - padding.Top - padding.Bottom)

  -- Snapshot each child's original props before ArrangeFlexChildren modifies them.
  -- RebuildScrollCanvas uses these to restore a clean slate before re-running.
  local originalChildProps = {}
  for i, child in ipairs(childLayouts) do
    child.props = child.props or {}
    originalChildProps[i] = {
      size             = child.props.size,
      relativeSize     = child.props.relativeSize,
      position         = child.props.position,
      relativePosition = child.props.relativePosition,
      flexGrow         = child.__anglesFlexGrow,
    }
  end

  -- For mw-text children that rely on autoSize (no explicit height defined), inject
  -- a height estimate so ArrangeFlexChildren can stack them correctly and the content
  -- bounds computation reflects their contribution to the scrollable area.
  -- The snapshot above preserves the original nil size; RebuildScrollCanvas restores
  -- it before the next pass so this estimate is re-applied cleanly each time.
  for _, child in ipairs(childLayouts) do
    if (child.type == UI.TYPE.Text) then
      local sz = child.props.size
      local rz = child.props.relativeSize
      local hasExplicitHeight = (sz ~= nil and sz.y ~= nil and sz.y > 0)
        or (rz ~= nil and rz.y ~= nil and rz.y > 0)
      if (not hasExplicitHeight) then
        local estimatedH = (child.props.textSize or defaultTextSize)
        local existingW  = sz and sz.x or 0
        child.props.size = Util.vector2(existingW, estimatedH)
      end
    end
  end

  -- Arrange children along the scroll direction.
  -- Main axis is unconstrained (nil) so content can extend beyond the viewport;
  -- the cross axis is bounded by the inner viewport dimension.
  local arrangeSize = isRow and { x = nil, y = innerH } or { x = innerW, y = nil }
  local arrangedChildren = self:ArrangeFlexChildren(childLayouts, direction, gap, arrangeSize)

  -- Compute total content extent from the arranged children's pixel bounds.
  -- For text elements the estimated height from above is still in props.size.y,
  -- so the extent calculation correctly accounts for their contribution.
  local contentW = innerW
  local contentH = innerH
  for _, child in ipairs(arrangedChildren) do
    local p = child.props
    if (p ~= nil) then
      local px = (p.position and p.position.x) or 0
      local py = (p.position and p.position.y) or 0
      local sw = (p.size and p.size.x) or 0
      local sh = (p.size and p.size.y) or 0
      -- For text children use estimated dimensions when no explicit size is set.
      if (child.type == UI.TYPE.Text) then
        if (sh == 0) then
          sh = child.props.textSize or defaultTextSize
        end
        if (sw == 0) then
          sw = TextUtility.EstimateTextWidth(child.props.text, child.props.textSize)
        end
      end
      contentW = math.max(contentW, px + sw)
      contentH = math.max(contentH, py + sh)
    end
  end

  -- Update persistent scroll state with the current layout dimensions.
  local maxScrollX = math.max(0, contentW - innerW)
  local maxScrollY = math.max(0, contentH - innerH)
  state.x       = math.min(state.x, maxScrollX)
  state.y       = math.min(state.y, maxScrollY)
  state.maxX    = maxScrollX
  state.maxY    = maxScrollY
  state.padding = padding

  -- Track geometry: arrow buttons occupy sbSize at each end of the track, with a
  -- 2-pixel gap on each side separating each arrow from the thumb track.
  local arrowGap = 2
  local vTrackH  = math.max(0, viewportH - 2 * sbSize - 2 * arrowGap)
  local hTrackW  = math.max(0, viewportW - 2 * sbSize - 2 * arrowGap)
  local minThumb = math.max(sbSize, 16)
  local vThumbH  = maxScrollY > 0 and math.max(minThumb, (innerH / contentH) * vTrackH) or vTrackH
  local hThumbW  = maxScrollX > 0 and math.max(minThumb, (innerW / contentW) * hTrackW) or hTrackW

  state.trackH  = vTrackH
  state.trackW  = hTrackW
  state.vThumbH = vThumbH
  state.hThumbW = hThumbW

  -- Initial thumb offsets based on current scroll position.
  local vThumbY = maxScrollY > 0 and ((state.y / maxScrollY) * (vTrackH - vThumbH)) or 0
  local hThumbX = maxScrollX > 0 and ((state.x / maxScrollX) * (hTrackW - hThumbW)) or 0

  -- Create scrollbar interaction callbacks once and cache them on state.
  -- They capture only the persistent state table and the constant scrollStep,
  -- so the same async:callback objects are safely reused across every rerender.
  if (state.cachedCallbacks == nil) then
    local scrollStep = meta.scrollStep
    state.cachedCallbacks = {
      vThumbPress = async:callback(function(e, l)
        if (e.button ~= 1) then return true end
        state.vDragging  = true
        state.vLastMouse = e.position
        return true
      end),
      vThumbClick = async:callback(function(e, l) end),
      vTrackClick = async:callback(function(e, l)
        if (state.maxY <= 0) then return true end
        local trackSize = state.trackH > 0 and state.trackH or 1
        local ratio = math.max(0, math.min(1, e.offset.y / trackSize))
        state.y = ratio * state.maxY
        state.updateScrollVisuals()
        return true
      end),
      vUpClick = async:callback(function(e, l)
        state.y = math.max(0, state.y - scrollStep)
        state.updateScrollVisuals()
        return true
      end),
      vDownClick = async:callback(function(e, l)
        state.y = math.min(state.maxY, state.y + scrollStep)
        state.updateScrollVisuals()
        return true
      end),
      hThumbPress = async:callback(function(e, l)
        if (e.button ~= 1) then return true end
        state.hDragging  = true
        state.hLastMouse = e.position
        return true
      end),
      hThumbClick = async:callback(function(e, l) end),
      hTrackClick = async:callback(function(e, l)
        if (state.maxX <= 0) then return true end
        local trackSize = state.trackW > 0 and state.trackW or 1
        local ratio = math.max(0, math.min(1, e.offset.x / trackSize))
        state.x = ratio * state.maxX
        state.updateScrollVisuals()
        return true
      end),
      hLeftClick = async:callback(function(e, l)
        state.x = math.max(0, state.x - scrollStep)
        state.updateScrollVisuals()
        return true
      end),
      hRightClick = async:callback(function(e, l)
        state.x = math.min(state.maxX, state.x + scrollStep)
        state.updateScrollVisuals()
        return true
      end),
    }
  end
  local cb = state.cachedCallbacks

  -- ── Content & viewport ─────────────────────────────────────────────────────

  local contentLayout = {
    props = {
      size     = Util.vector2(contentW, contentH),
      position = Util.vector2(-state.x + padding.Left, -state.y + padding.Top),
    },
    content = UI.content(arrangedChildren),
  }
  state.contentLayout = contentLayout

  local viewportLayout = {
    props = {
      size     = Util.vector2(viewportW, viewportH),
      position = Util.vector2(0, 0),
    },
    content = UI.content({ contentLayout }),
  }

  -- ── Vertical scrollbar (right edge) ────────────────────────────────────────

  local vThumbLayout = {
    type = UI.TYPE.Image,
    props = {
      resource = UI.texture({ path = "textures/omw_menu_scroll_center_v.dds" }),
      tileV    = true,
      size     = Util.vector2(sbSize, vThumbH),
      position = Util.vector2(0, vThumbY),
    },
    events = {
      mousePress = cb.vThumbPress,
      mouseClick = cb.vThumbClick,
    },
  }
  state.vThumbLayout = vThumbLayout

  local vTrackLayout = {
    template = MWUI.templates.borders,
    props = {
      size     = Util.vector2(sbSize, vTrackH),
      position = Util.vector2(0, sbSize + arrowGap),
    },
    events = {
      mouseClick = cb.vTrackClick,
    },
    content = UI.content({ vThumbLayout }),
  }

  local vUpArrow = {
    template = MWUI.templates.borders,
    props = {
      size     = Util.vector2(sbSize, sbSize),
      position = Util.vector2(0, 0),
    },
    content = UI.content({
      {
        type  = UI.TYPE.Image,
        props = {
          resource     = UI.texture({ path = "textures/omw_menu_scroll_up.dds" }),
          relativeSize = Util.vector2(1, 1),
        },
      },
    }),
    events = {
      mouseClick = cb.vUpClick,
    },
  }

  local vDownArrow = {
    template = MWUI.templates.borders,
    props = {
      size     = Util.vector2(sbSize, sbSize),
      position = Util.vector2(0, sbSize + arrowGap + vTrackH + arrowGap),
    },
    content = UI.content({
      {
        type  = UI.TYPE.Image,
        props = {
          resource     = UI.texture({ path = "textures/omw_menu_scroll_down.dds" }),
          relativeSize = Util.vector2(1, 1),
        },
      },
    }),
    events = {
      mouseClick = cb.vDownClick,
    },
  }

  local vScrollbar = {
    props = {
      size     = Util.vector2(sbSize, viewportH),
      position = Util.vector2(viewportW, 0),
    },
    content = UI.content({ vUpArrow, vTrackLayout, vDownArrow }),
  }

  -- ── Horizontal scrollbar (bottom edge) ─────────────────────────────────────

  local hThumbLayout = {
    type = UI.TYPE.Image,
    props = {
      resource = UI.texture({ path = "textures/omw_menu_scroll_center_v.dds" }),
      tileH    = true,
      size     = Util.vector2(hThumbW, sbSize),
      position = Util.vector2(hThumbX, 0),
    },
    events = {
      mousePress = cb.hThumbPress,
      mouseClick = cb.hThumbClick,
    },
  }
  state.hThumbLayout = hThumbLayout

  local hTrackLayout = {
    template = MWUI.templates.borders,
    props = {
      size     = Util.vector2(hTrackW, sbSize),
      position = Util.vector2(sbSize + arrowGap, 0),
    },
    events = {
      mouseClick = cb.hTrackClick,
    },
    content = UI.content({ hThumbLayout }),
  }

  local hLeftArrow = {
    template = MWUI.templates.borders,
    props = {
      size     = Util.vector2(sbSize, sbSize),
      position = Util.vector2(0, 0),
    },
    content = UI.content({
      {
        type  = UI.TYPE.Image,
        props = {
          resource     = UI.texture({ path = "textures/omw_menu_scroll_left.dds" }),
          relativeSize = Util.vector2(1, 1),
        },
      },
    }),
    events = {
      mouseClick = cb.hLeftClick,
    },
  }

  local hRightArrow = {
    template = MWUI.templates.borders,
    props = {
      size     = Util.vector2(sbSize, sbSize),
      position = Util.vector2(sbSize + arrowGap + hTrackW + arrowGap, 0),
    },
    content = UI.content({
      {
        type  = UI.TYPE.Image,
        props = {
          resource     = UI.texture({ path = "textures/omw_menu_scroll_right.dds" }),
          relativeSize = Util.vector2(1, 1),
        },
      },
    }),
    events = {
      mouseClick = cb.hRightClick,
    },
  }

  local hScrollbar = {
    props = {
      size     = Util.vector2(viewportW, sbSize),
      position = Util.vector2(0, viewportH),
    },
    content = UI.content({ hLeftArrow, hTrackLayout, hRightArrow }),
  }

  -- Small corner filler where the two scrollbar strips overlap.
  local corner = {
    props = {
      size     = Util.vector2(sbSize, sbSize),
      position = Util.vector2(viewportW, viewportH),
    },
  }

  -- Store rebuild state so an ancestor flex can call RebuildScrollCanvas after grow
  -- resolution gives this element its true pixel dimensions.
  outerLayout.__anglesCustomScrollCanvas = {
    meta               = meta,
    childLayouts       = childLayouts,
    originalChildProps = originalChildProps,
  }

  outerLayout.content = UI.content({ viewportLayout, vScrollbar, hScrollbar, corner })
end

-- Re-runs ApplyScrollCanvasContainer for a scroll canvas layout using a new canvas pixel size.
-- Called when an ancestor's grow resolution reveals the element's actual size.
---@param layout table The Layout table that owns an `__anglesCustomScrollCanvas` state block.
---@param canvasPixelSize {x: number|nil, y: number|nil}|nil New resolved pixel size for the scroll canvas.
function Renderer:RebuildScrollCanvas(layout, canvasPixelSize)
  local state = layout.__anglesCustomScrollCanvas
  if (state == nil) then return end

  -- Restore each child's original pre-arrangement props so ApplyScrollCanvasContainer
  -- gets a clean slate (correct sizes, nil positions, grow values intact).
  for i, child in ipairs(state.childLayouts) do
    local original = state.originalChildProps[i]
    if (original ~= nil) then
      child.props              = child.props or {}
      child.props.size         = original.size
      child.props.relativeSize = original.relativeSize
      child.props.position     = original.position
      child.props.relativePosition = original.relativePosition
      child.__anglesFlexGrow   = original.flexGrow
    end
  end

  self:ApplyScrollCanvasContainer(layout, state.childLayouts, state.meta, canvasPixelSize)
end

---@param layout table The outer Layout table for the mw-grid element.
---@param childLayouts table[] Children to place in the grid.
---@param meta table Grid metadata (padding, templateRows, templateColumns, gap, rowGap, columnGap).
---@param innerPixelSize {x: number|nil, y: number|nil}|nil Available inner pixel area of the grid.
function Renderer:ApplyCustomGridContainer(layout, childLayouts, meta, innerPixelSize)
  -- Snapshot original placement metadata AND child props so RebuildCustomGridLayout
  -- can restore a clean slate before each re-arrangement pass.
  -- ArrangeGridChildren resolves relativeSize into absolute size, so without this
  -- snapshot subsequent rebuilds would lose the original relative dimensions.
  local originalChildMeta = {}
  for i, child in ipairs(childLayouts) do
    child.props = child.props or {}
    originalChildMeta[i] = {
      gridColumn     = child.__anglesGridColumn,
      gridRow        = child.__anglesGridRow,
      gridColumnSpan = child.__anglesGridColumnSpan,
      gridRowSpan    = child.__anglesGridRowSpan,
      size           = child.props.size,
      relativeSize   = child.props.relativeSize,
      position       = child.props.position,
      relativePosition = child.props.relativePosition,
    }
  end

  layout.__anglesCustomGrid = {
    meta = meta,
    childLayouts = childLayouts,
    originalChildMeta = originalChildMeta,
  }

  self:RebuildCustomGridLayout(layout, innerPixelSize)
end

return Renderer