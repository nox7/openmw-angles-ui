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

-- The user's menu transparency setting from the Settings::gui().mTransparencyAlpha value
local menuTransparencyAlphaValue = UI._getMenuTransparency()

-- Mapping from CSS property names to our lowercased HTML attribute names
local CSS_PROPERTY_TO_ATTRIBUTE = {
  ["padding"]              = "padding",
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
  ["text"]      = true,  -- mw-text-edit initial content
}

---@class Renderer Class responsible for rendering a single OpenMW UiElement from HTMl and CSS source code.
---@field public string source
---@field public table<string, UserComponent> userComponents The key is the selector and the value is an instance of UserComponent
---@field public string cssSource
---@field public table cssModel The parsed CSS model from cssSource, including rules and media queries.
local Renderer = {}
Renderer.__index = Renderer

-- Returns true if the tag name is an accepted engine tag
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

function Renderer.New(source, userComponents, cssSource)
  local self = setmetatable({}, Renderer)
  self.source = source
  self.userComponents = userComponents or {}
  self.cssSource = cssSource
  self.cssModel = CSSParser.New():Parse(cssSource)
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

function Renderer:ResolveAxisSize(absoluteSize, relativeSize, parentAxisSize)
  if (relativeSize ~= nil and parentAxisSize ~= nil) then
    return (absoluteSize or 0) + (relativeSize * parentAxisSize)
  end

  if (absoluteSize ~= nil) then
    return absoluteSize
  end

  return nil
end

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

function Renderer:ResolvePaddedPixelSize(parentPixelSize, padding)
  if (parentPixelSize == nil) then
    return nil
  end

  return {
    x = parentPixelSize.x ~= nil and (parentPixelSize.x - (padding.Left + padding.Right)) or nil,
    y = parentPixelSize.y ~= nil and (parentPixelSize.y - (padding.Top + padding.Bottom)) or nil,
  }
end

function Renderer:ResolveRootParentPixelSize()
  local screenSize = UI.screenSize()
  return {
    x = screenSize.x,
    y = screenSize.y,
  }
end

function Renderer:ArrangeFlexChildren(childLayouts, direction, gap, containerPixelSize)
  local childCount = #childLayouts
  if (childCount == 0) then
    return childLayouts
  end

  local resolvedDirection = direction or "column"
  local resolvedGap = gap or 0
  local isRow = resolvedDirection == "row"

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

    if (size ~= nil and relativeSize == nil) then
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

  local currentMainOffset = 0

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

    if (not hasRelativePosition and not hasPosition) then
      if (isRow) then
        child.props.position = Util.vector2(currentMainOffset, 0)
      else
        child.props.position = Util.vector2(0, currentMainOffset)
      end
    end

    currentMainOffset = currentMainOffset + majorSize + resolvedGap

    -- After grow is resolved, rebuild any nested custom layouts (grid or flex)
    -- using the child's now-resolved pixel dimensions.
    local needsRebuild = (child.__anglesCustomGrid ~= nil or child.__anglesNestedFlexes ~= nil)
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
    end

    child.__anglesFlexGrow = nil
  end

  return childLayouts
end

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

  local arrangedChildren = self:ArrangeFlexChildren(childLayouts, meta.direction, meta.gap, innerPixelSize)

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
-- userContext must be a flat table where every value is a Signal.
-- This returns the OpenMW Lua UI root element after it is called.
function Renderer:Render(userContext)
  -- Enforce the contract: only Signal instances are accepted as context values.
  for key, value in pairs(userContext or {}) do
    if (not Signal.IsSignal(value)) then
      error("Renderer:Render() context values must be Signal instances. '" .. tostring(key) .. "' is not a Signal.")
    end
  end

  -- Tear down subscriptions left over from any previous Render() call.
  self:_disposeSignalEffects()

  -- Subscribe to every context signal so that any Set() call triggers a full re-render.
  self._signalContext       = userContext or {}
  self._signalsDirty        = false
  self._signalUnsubscribers = {}
  for _, signal in pairs(self._signalContext) do
    local unsubscribe = signal:Subscribe(function()
      self._signalsDirty = true
      self:Rerender()
    end)
    table.insert(self._signalUnsubscribers, unsubscribe)
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
function Renderer:_disposeSignalEffects()
  if (self._signalUnsubscribers ~= nil) then
    for _, unsubscribe in ipairs(self._signalUnsubscribers) do
      unsubscribe()
    end
    self._signalUnsubscribers = nil
  end
end

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

  local childParentPixelSize = layoutPixelSize
  if (meta ~= nil and (meta.type == "custom-flex" or meta.type == "padding-container" or meta.type == "custom-grid")) then
    childParentPixelSize = self:ResolvePaddedPixelSize(layoutPixelSize, meta.padding)
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

  -- Attach drag-to-move events when Dragger="true" is set on this element.
  -- Any element can be a drag handle; the events always move the mw-root position.
  local draggerAttr = normalizedProperties["dragger"]
  if (draggerAttr ~= nil and self:ToBoolean(draggerAttr, "Dragger") == true) then
    local draggerEvents = self:BuildDraggerEvents()
    if (layout.events == nil) then
      layout.events = draggerEvents
    else
      for k, v in pairs(draggerEvents) do
        layout.events[k] = v
      end
    end
  end

  local childLayouts = {}

  local childAncestors = {}
  for _, ancestor in ipairs(ancestors) do
    table.insert(childAncestors, ancestor)
  end
  table.insert(childAncestors, node)

  if (#node.children > 0) then
    for _, childNode in pairs(node.children) do
      if (childNode.type == Node.TYPE_ENGINE_COMPONENT) then
        table.insert(childLayouts, self:BuildLayoutTree(childNode, childParentPixelSize, childAncestors, childContainerContext))
      end
    end
  end

  if (meta ~= nil and meta.type == "custom-flex") then
    self:ApplyCustomFlexContainer(layout, childLayouts, meta, childParentPixelSize)
  elseif (meta ~= nil and meta.type == "custom-grid") then
    self:ApplyCustomGridContainer(layout, childLayouts, meta, childParentPixelSize)
  elseif (meta ~= nil and meta.type == "padding-container") then
    self:ApplyPaddingContainer(layout, childLayouts, meta.padding)
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
    end
  end

  return layout
end

function Renderer:ApplyCommonWidgetProperties(allProperties, options)
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

  self:MarkConsumed(consumed, {
    "width", "height", "relativewidth", "relativeheight", "x", "y", "relativex", "relativey", "anchorx", "anchory", "visible"
  })

  local requireSize = options ~= nil and options.requireSize == true
  local defaultRelativeSize = options ~= nil and options.defaultRelativeSize == true

  if (requireSize and (width == nil or height == nil) and (relativeWidth == nil or relativeHeight == nil)) then
    error("Element must have either Width/Height or RelativeWidth/RelativeHeight attributes.")
  end

  if (defaultRelativeSize and width == nil and height == nil and relativeWidth == nil and relativeHeight == nil) then
    relativeWidth = 1
    relativeHeight = 1
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

  if (visible ~= nil) then
    props.visible = visible
  end

  return props, consumed
end

-- Builds the mousePress/mouseMove event table that implements edge/corner resizing for mw-root.
-- Returns an events table suitable for assignment directly to a layout's "events" field.
function Renderer:BuildResizeEvents()
  local resizeState = {
    isDragging   = false,
    dragEdge     = nil,
    lastMousePos = nil,
  }

  local rendererRef = self
  local edgeMargin  = 8
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
    mousePress = async:callback(function(e, l)
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
    end),

    mouseMove = async:callback(function(e, l)
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

      if (rendererRef.rootElement ~= nil) then
        rendererRef:Rerender()
      end
    end),
  }
end

-- Builds the mousePress/mouseMove event table that moves the mw-root when dragged.
-- Attach to any element via the Dragger="true" attribute.
function Renderer:BuildDraggerEvents()
  local dragState = {
    isDragging   = false,
    lastMousePos = nil,
  }

  local rendererRef = self

  return {
    mousePress = async:callback(function(e, l)
      if (e.button ~= 1) then return end
      dragState.isDragging   = true
      dragState.lastMousePos = e.position
    end),

    mouseMove = async:callback(function(e, l)
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

      if (rendererRef.rootElement ~= nil) then
        rendererRef.rootElement:update()
      end
    end),
  }
end

-- Gets the engine UI element that corresponds to a tag name.
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

    local props, consumed = self:ApplyCommonWidgetProperties(allProperties, { requireSize = true })
    local resizable = self:ToBoolean(allProperties["resizable"], "Resizable")
    self:MarkConsumed(consumed, { "name", "layer", "resizable" })

    local events = nil
    if (resizable == true) then
      events = self:BuildResizeEvents()
    end

    return {
      layer = layer,
      name = name,
      props = props,
      events = events,
      userData = self:BuildUserData(allProperties, consumed),
    }, nil
  elseif (tagName == "mw-window") then
    local consumed = {}
    self:MarkConsumed(consumed, { "name", "background", "dragger" })

    local background = allProperties["background"]
    local includeBackground = background == nil or string.lower(tostring(background)) ~= "none"

    local windowContent = {}
    if (includeBackground) then
      table.insert(windowContent, {
        type = UI.TYPE.Image,
        props = {
          resource = UI.texture({
            path = "black"
          }),
          alpha = menuTransparencyAlphaValue,
          relativeSize = Util.vector2(1, 1)
        }
      })
    end
    table.insert(windowContent, {
      template = MWUI.templates.bordersThick,
      props = {
        relativeSize = Util.vector2(1, 1),
      },
    })

    return {
      name = name,
      props = {
        relativeSize = Util.vector2(1, 1),
      },
      content = UI.content(windowContent),
      userData = self:BuildUserData(allProperties, consumed),
    }, nil
  elseif (tagName == "mw-flex") then
    local props, consumed = self:ApplyCommonWidgetProperties(allProperties, { defaultRelativeSize = true })
    local parsedPadding = allProperties["parsedpadding"] or {
      Top = 0,
      Right = 0,
      Bottom = 0,
      Left = 0,
    }

    self:MarkConsumed(consumed, { "name", "padding", "parsedpadding", "direction", "gap" })

    return {
      name = name,
      props = props,
      userData = self:BuildUserData(allProperties, consumed),
    }, {
      type = "custom-flex",
      direction = allProperties["direction"] or "column",
      gap = self:ToNumber(allProperties["gap"], "Gap") or 0,
      padding = parsedPadding,
    }
  elseif (tagName == "mw-grid") then
    local props, consumed = self:ApplyCommonWidgetProperties(allProperties, { defaultRelativeSize = true })
    local parsedPadding = allProperties["parsedpadding"] or {
      Top = 0,
      Right = 0,
      Bottom = 0,
      Left = 0,
    }

    self:MarkConsumed(consumed, {
      "name", "padding", "parsedpadding", "gap", "rowgap", "columngap", "gridtemplaterows", "gridtemplatecolumns"
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
    }
  elseif (tagName == "mw-text") then
    local props, consumed = self:ApplyCommonWidgetProperties(allProperties, nil)

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

    for _, childNode in pairs(node.children) do
      if (childNode.type == Node.TYPE_TEXT) then
        textNodesText = textNodesText .. childNode.text
      else
        error("Only text nodes are allowed in mw-text elements. Encountered a node of type: " .. childNode.type)
      end
    end

    props.text = textNodesText
    if (props.autoSize == nil) then
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
    local props, consumed = self:ApplyCommonWidgetProperties(allProperties, nil)

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
    local props, consumed = self:ApplyCommonWidgetProperties(allProperties, nil)

    if (allProperties["text"] ~= nil) then
      props.text = tostring(allProperties["text"])
      consumed["text"] = true
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

    self:MarkConsumed(consumed, { "name" })

    return {
      name = name,
      type = UI.TYPE.TextEdit,
      props = props,
      userData = self:BuildUserData(allProperties, consumed),
    }, nil
  elseif (tagName == "mw-hr") then
    local consumed = {}
    self:MarkConsumed(consumed, { "name", "dragger" })
    return {
      name = name,
      template = MWUI.templates.horizontalLine,
      props = {
        size = Util.vector2(10, 20),
        tileV = true,
        tileH = false,
      },
      userData = self:BuildUserData(allProperties, consumed),
    }, nil
  elseif (tagName == "mw-widget") then
    local props, consumed = self:ApplyCommonWidgetProperties(allProperties, nil)
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

  if (node.tagName == "mw-flex" or node.tagName == "mw-widget" or node.tagName == "mw-grid") then
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

function Renderer:MarkConsumed(consumed, keys)
  for _, key in ipairs(keys) do
    consumed[string.lower(key)] = true
  end
end

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

function Renderer:ParseGridTracks(trackDefinition)
  local tracks = {}

  if (trackDefinition == nil) then
    return tracks
  end

  local definition = tostring(trackDefinition):match("^%s*(.-)%s*$")
  local count = tonumber(definition)
  if (count ~= nil and math.floor(count) == count and count > 0 and not string.find(definition, "%s")) then
    for _ = 1, count do
      table.insert(tracks, { kind = "fr", value = 1 })
    end
    return tracks
  end

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

function Renderer:EnsureGridCell(occupancy, row, col)
  if (occupancy[row] == nil) then
    occupancy[row] = {}
  end

  if (occupancy[row][col] == nil) then
    occupancy[row][col] = false
  end
end

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

function Renderer:MarkGridArea(occupancy, row, col, rowSpan, colSpan)
  for r = row, row + rowSpan - 1 do
    for c = col, col + colSpan - 1 do
      self:EnsureGridCell(occupancy, r, c)
      occupancy[r][c] = true
    end
  end
end

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

  -- Phase 4: Apply geometry to each child
  for i, child in ipairs(childLayouts) do
    local p = placements[i]

    local width = 0
    for c = p.column, p.column + p.columnSpan - 1 do
      width = width + (columnSizes[c] or 0)
      if (c < p.column + p.columnSpan - 1) then
        width = width + columnGap
      end
    end

    local height = 0
    for r = p.row, p.row + p.rowSpan - 1 do
      height = height + (rowSizes[r] or 0)
      if (r < p.row + p.rowSpan - 1) then
        height = height + rowGap
      end
    end

    child.props.position = Util.vector2(columnStarts[p.column] or 0, rowStarts[p.row] or 0)
    child.props.relativePosition = nil
    child.props.relativeSize = nil
    child.props.size = Util.vector2(width, height)

    child.__anglesGridColumn = nil
    child.__anglesGridRow = nil
    child.__anglesGridColumnSpan = nil
    child.__anglesGridRowSpan = nil
  end

  return childLayouts
end

function Renderer:RebuildCustomGridLayout(layout, innerPixelSize)
  local state = layout.__anglesCustomGrid
  if (state == nil) then
    return
  end

  -- Restore original placement metadata before each arrangement so spans are re-read
  for i, child in ipairs(state.childLayouts) do
    local original = state.originalChildMeta[i]
    child.__anglesGridColumn = original.gridColumn
    child.__anglesGridRow = original.gridRow
    child.__anglesGridColumnSpan = original.gridColumnSpan
    child.__anglesGridRowSpan = original.gridRowSpan
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
    state.childLayouts, state.meta.direction, state.meta.gap, innerPixelSize
  )

  state.paddedContainer.content = UI.content(arrangedChildren)
end

function Renderer:ApplyCustomGridContainer(layout, childLayouts, meta, innerPixelSize)
  -- Snapshot original placement metadata so RebuildCustomGridLayout can restore it
  local originalChildMeta = {}
  for i, child in ipairs(childLayouts) do
    originalChildMeta[i] = {
      gridColumn = child.__anglesGridColumn,
      gridRow = child.__anglesGridRow,
      gridColumnSpan = child.__anglesGridColumnSpan,
      gridRowSpan = child.__anglesGridRowSpan,
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