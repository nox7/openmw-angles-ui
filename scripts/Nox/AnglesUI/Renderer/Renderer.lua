--- AnglesUI Renderer.
--- The main entry point for the AnglesUI framework. Orchestrates the full
--- pipeline: parse HTML/CSS → build DOM → expand components → cascade CSS →
--- evaluate directives/bindings → layout → transpile → create OpenMW UI.
---
--- Public API:
---   Renderer.FromFile(filePath, userComponents) → renderer instance
---   renderer:Render(context) → creates/updates the OpenMW UI element

local VFS = require("openmw.vfs")
local UI  = require("openmw.ui")
local Util = require("openmw.util")
local Async = require("openmw.async")

-- Parsers
local HtmlLexer  = require("scripts.Nox.AnglesUI.Parser.HTML.HtmlLexer")
local HtmlParser = require("scripts.Nox.AnglesUI.Parser.HTML.HtmlParser")
local HtmlNodes  = require("scripts.Nox.AnglesUI.Parser.HTML.HtmlNodes")
local CssLexer   = require("scripts.Nox.AnglesUI.Parser.CSS.CssLexer")
local CssParser  = require("scripts.Nox.AnglesUI.Parser.CSS.CssParser")

-- CSS utilities
local CssVariableResolver = require("scripts.Nox.AnglesUI.Parser.CSS.CssVariableResolver")

-- DOM
local DomNode        = require("scripts.Nox.AnglesUI.DOM.DomNode")
local DomTreeBuilder = require("scripts.Nox.AnglesUI.DOM.DomTreeBuilder")
local CssCascade     = require("scripts.Nox.AnglesUI.DOM.CssCascade")
local MediaQueryEvaluator    = require("scripts.Nox.AnglesUI.DOM.MediaQueryEvaluator")
local ContainerQueryEvaluator = require("scripts.Nox.AnglesUI.DOM.ContainerQueryEvaluator")
local HoverTracker   = require("scripts.Nox.AnglesUI.DOM.HoverTracker")

-- Components
local ComponentRegistry        = require("scripts.Nox.AnglesUI.Components.ComponentRegistry")
local ContentProjection        = require("scripts.Nox.AnglesUI.Components.ContentProjection")
local CssScoping               = require("scripts.Nox.AnglesUI.Components.CssScoping")
local SpecialComponentRegistry = require("scripts.Nox.AnglesUI.Components.SpecialComponentRegistry")

-- Runtime
local RuntimeInit = require("scripts.Nox.AnglesUI.Runtime.RuntimeInit")
local EventBinding = require("scripts.Nox.AnglesUI.Runtime.EventBinding")

-- Renderer
local LayoutInit  = require("scripts.Nox.AnglesUI.Renderer.LayoutInit")
local BoxModel    = require("scripts.Nox.AnglesUI.Renderer.BoxModel")
local Transpiler  = require("scripts.Nox.AnglesUI.Renderer.Transpiler")
local Dragger     = require("scripts.Nox.AnglesUI.Renderer.Dragger")
local Resizable   = require("scripts.Nox.AnglesUI.Renderer.Resizable")
local Reactivity  = require("scripts.Nox.AnglesUI.Renderer.Reactivity")

local NodeType    = HtmlNodes.NodeType
local DomNodeKind = DomNode.DomNodeKind

---------------------------------------------------------------------------
-- Initialise layout wiring + transpiler (once)
---------------------------------------------------------------------------

LayoutInit.Init()
Transpiler.Init(UI, Util, Async)

---------------------------------------------------------------------------
-- VFS Helpers
---------------------------------------------------------------------------

--- Read a file from the OpenMW virtual file system.
--- @param path string
--- @return string? contents
local function readVfsFile(path)
    if not VFS.fileExists(path) then return nil end
    local handle, err = VFS.open(path)
    if not handle then return nil end
    local contents = handle:read("*all")
    return contents
end

--- Check if a VFS file exists.
--- @param path string
--- @return boolean
local function vfsFileExists(path)
    return VFS.fileExists(path)
end

---------------------------------------------------------------------------
-- Parse helpers
---------------------------------------------------------------------------

--- Parse an HTML source string into an AST.
--- @param source string
--- @return AnglesUI.BaseNode[]
local function parseHtml(source)
    local tokens = HtmlLexer.Tokenize(source)
    return HtmlParser.Parse(tokens)
end

--- Parse a CSS source string into a stylesheet AST.
--- @param source string
--- @return AnglesUI.CssStylesheet
local function parseCss(source)
    local tokens = CssLexer.Tokenize(source)
    return CssParser.Parse(tokens, source)
end

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

--- @class AnglesUI.Renderer
--- @field private _htmlPath string
--- @field private _htmlAst AnglesUI.BaseNode[]
--- @field private _cssAst AnglesUI.CssStylesheet|nil
--- @field private _registry AnglesUI.ComponentRegistry
--- @field private _hoverTracker AnglesUI.HoverTracker
--- @field private _element table|nil The OpenMW UI element
--- @field private _context table|nil The last-used evaluation context
--- @field private _reactivityHandle AnglesUI.ReactivityHandle|nil
--- @field private _variableResolver AnglesUI.CssVariableResolver
local Renderer = {}
Renderer.__index = Renderer

---------------------------------------------------------------------------
-- FromFile
---------------------------------------------------------------------------

--- Create a new Renderer from an HTML file in the OpenMW VFS.
--- @param filePath string VFS path to the root HTML file (e.g. "scripts/Nox/UI/Main.html")
--- @param userComponents table<string, string>|nil Tag name → VFS HTML path for user components
--- @return AnglesUI.Renderer
function Renderer.FromFile(filePath, userComponents)
    local self = setmetatable({}, Renderer)

    -- Read and parse the root HTML
    local source = readVfsFile(filePath)
    if not source then
        error("AnglesUI.Renderer: Cannot read HTML file: " .. filePath, 2)
    end
    self._htmlPath = filePath
    self._htmlAst = parseHtml(source)

    -- Validate: first element must be mw-root
    local firstElement = nil
    for _, node in ipairs(self._htmlAst) do
        if node.type == NodeType.Element then
            firstElement = node
            break
        end
    end
    if not firstElement or firstElement.tag ~= "mw-root" then
        error("AnglesUI.Renderer: Root HTML file must have <mw-root> as its first element: " .. filePath, 2)
    end

    -- Auto-discover CSS
    local cssPath = filePath:gsub("%.html$", ".css")
    if cssPath ~= filePath and vfsFileExists(cssPath) then
        local cssSource = readVfsFile(cssPath)
        if cssSource then
            self._cssAst = parseCss(cssSource)
        end
    end

    -- Register user components
    self._registry = ComponentRegistry.New()
    if userComponents then
        self._registry:RegisterAll(userComponents)
    end

    -- Initialise sub-systems
    self._hoverTracker = HoverTracker.New()
    self._variableResolver = CssVariableResolver.New()
    self._element = nil
    self._context = nil
    self._reactivityHandle = nil

    return self
end

---------------------------------------------------------------------------
-- Component expansion
---------------------------------------------------------------------------

--- Recursively expand user components and special components in the HTML AST.
--- Modifies the AST in-place, replacing component tags with their templates
--- and performing content projection.
--- @param nodes AnglesUI.BaseNode[]
--- @param parentScopeId string|nil
local function expandComponents(nodes, registry, parentScopeId)
    for i, node in ipairs(nodes) do
        if node.type == NodeType.Element then

        --- @cast node AnglesUI.ElementNode
        local tag = node.tag

        -- Special engine components (mw-window, mw-hr)
        if SpecialComponentRegistry.IsSpecial(tag) then
            local templateAst = SpecialComponentRegistry.GetOrParseHtml(tag, parseHtml)
            if templateAst and #templateAst > 0 then
                -- The special component template replaces the content
                local projected = node.children or {}
                local templateRoot = templateAst[1]

                if templateRoot.type == NodeType.Element then
                    --- @cast templateRoot AnglesUI.ElementNode
                    -- Deep-clone the template
                    local cloned = HtmlNodes.CreateElement(templateRoot.tag, templateRoot.line, templateRoot.column)
                    cloned.attributes = templateRoot.attributes
                    cloned.selfClosing = templateRoot.selfClosing
                    cloned.isEngine = templateRoot.isEngine
                    cloned.isUserComponent = templateRoot.isUserComponent

                    -- Project content
                    if templateRoot.children and #templateRoot.children > 0 then
                        cloned.children = ContentProjection.Project(templateRoot.children, projected)
                    else
                        cloned.children = projected
                    end

                    -- Replace the original node's children
                    node.children = { cloned }
                end
            end
        -- User components
        elseif registry:IsRegistered(tag) then
            local templateAst = registry:GetOrParseHtml(tag, parseHtml, readVfsFile)
            if templateAst and #templateAst > 0 then
                local projected = node.children or {}
                local templateRoot = templateAst[1]

                if templateRoot.type == NodeType.Element then
                    --- @cast templateRoot AnglesUI.ElementNode
                    local cloned = HtmlNodes.CreateElement(templateRoot.tag, templateRoot.line, templateRoot.column)
                    cloned.attributes = templateRoot.attributes
                    cloned.selfClosing = templateRoot.selfClosing
                    cloned.isEngine = templateRoot.isEngine
                    cloned.isUserComponent = templateRoot.isUserComponent

                    if templateRoot.children and #templateRoot.children > 0 then
                        cloned.children = ContentProjection.Project(templateRoot.children, projected)
                    else
                        cloned.children = projected
                    end

                    node.children = { cloned }
                end
            end
        end

        -- Recurse into children
        if node.children then
            expandComponents(node.children, registry, parentScopeId)
        end

        end -- if node.type == NodeType.Element
    end
end

---------------------------------------------------------------------------
-- Collect CSS rules from all sources
---------------------------------------------------------------------------

--- Collect and flatten CSS rules from root CSS, special components, and user components.
--- @param self AnglesUI.Renderer
--- @return AnglesUI._FlatRule[]
local function collectFlatRules(self)
    local allRules = {}

    -- Root CSS
    if self._cssAst then
        local rootRules = CssCascade.FlattenStylesheet(self._cssAst)
        for _, r in ipairs(rootRules) do
            allRules[#allRules + 1] = r
        end
    end

    -- Special component CSS
    for _, tag in ipairs({ "mw-window", "mw-hr" }) do
        if SpecialComponentRegistry.IsSpecial(tag) then
            local cssAst = SpecialComponentRegistry.GetOrParseCss(tag, parseCss)
            if cssAst then
                local rules = CssCascade.FlattenStylesheet(cssAst)
                for _, r in ipairs(rules) do
                    allRules[#allRules + 1] = r
                end
            end
        end
    end

    -- User component CSS
    for tagName, _ in pairs(self._registry:GetAll()) do
        local cssAst = self._registry:GetOrParseCss(tagName, parseCss, readVfsFile, vfsFileExists)
        if cssAst then
            local rules = CssCascade.FlattenStylesheet(cssAst)
            for _, r in ipairs(rules) do
                allRules[#allRules + 1] = r
            end
        end
    end

    return allRules
end

---------------------------------------------------------------------------
-- Get screen size
---------------------------------------------------------------------------

--- Get the screen size from the layer.
--- @param layerName string
--- @return number width, number height
local function getScreenSize(layerName)
    local layerIdx = UI.layers.indexOf(layerName)
    if layerIdx then
        local size = UI.layers[layerIdx].size
        return size.x, size.y
    end
    -- Fallback
    return 1024, 768
end

---------------------------------------------------------------------------
-- Full pipeline
---------------------------------------------------------------------------

--- Run the full render pipeline: DOM build → component expand → CSS cascade →
--- runtime eval → layout → transpile.
--- @param self AnglesUI.Renderer
--- @param context table<string, any>
--- @return table createArg The UI.create() argument table
--- @return table<AnglesUI.DomNode, table> eventMaps
--- @return AnglesUI.DomNode root
--- @return AnglesUI.DomNode mwRoot
local function runPipeline(self, context)
    -- 1. Expand components in the HTML AST
    expandComponents(self._htmlAst, self._registry, nil)

    -- 2. Build DOM tree from HTML AST
    local root = DomTreeBuilder.Build(self._htmlAst)

    -- 3. Find mw-root for screen size lookup
    local mwRoot = nil
    for _, child in ipairs(root.children) do
        if child.kind == DomNodeKind.Element and child.tag == "mw-root" then
            mwRoot = child
            break
        end
    end
    if not mwRoot then
        error("AnglesUI.Renderer: No <mw-root> element found in DOM tree", 0)
    end

    -- 4. Get screen dimensions from the layer
    local layerAttr = mwRoot.attributes["Layer"]
    local layerName = layerAttr and layerAttr.value or "Windows"
    local screenW, screenH = getScreenSize(layerName)

    -- 5. CSS Cascade
    local flatRules = collectFlatRules(self)
    local hoverSet = self._hoverTracker:GetHoverSet()
    local mediaEval = MediaQueryEvaluator.New(screenW, screenH)
    local containerEval = ContainerQueryEvaluator.New()

    -- Collect CSS variables from root CSS
    if self._cssAst then
        self._variableResolver:CollectFromStylesheet(self._cssAst)
    end

    CssCascade.ApplyToTree(root, flatRules, self._variableResolver, hoverSet, nil, mediaEval, containerEval)

    -- 6. Runtime evaluation (directives, bindings, events)
    local eventMaps = RuntimeInit.Evaluate(root, context)

    -- 7. Handle Dragger and Resizable on mw-root
    local elementRef = { layout = nil }

    -- Check all descendants for Dragger
    mwRoot:Walk(function(node)
        if node.kind == DomNodeKind.Element and Dragger.HasDragger(node) then
            local dragCbs = Dragger.BuildCallbacks(node, mwRoot, elementRef, Util)
            local existing = eventMaps[node] or {}
            eventMaps[node] = EventBinding.MergeCallbackMaps(existing, dragCbs)
        end
        return false
    end)

    -- Resizable on mw-root
    if Resizable.IsResizable(mwRoot) then
        local edgeMargin = Resizable.GetEdgeMargin(mwRoot)
        local resizeCbs = Resizable.BuildCallbacks(mwRoot, edgeMargin, elementRef, Util)
        local existing = eventMaps[mwRoot] or {}
        eventMaps[mwRoot] = EventBinding.MergeCallbackMaps(existing, resizeCbs)
    end

    -- 8. Layout pass
    BoxModel.LayoutTree(root, screenW, screenH)

    -- 9. Transpile to OpenMW UI format
    local createArg = Transpiler.Transpile(root, eventMaps, context, self._hoverTracker)

    return createArg, eventMaps, root, mwRoot
end

---------------------------------------------------------------------------
-- Render
---------------------------------------------------------------------------

--- Render the UI. Creates the OpenMW UI element on first call; updates it
--- on subsequent calls. Automatically subscribes to signals in the context
--- for reactive re-rendering.
---
--- @param context table<string, any> A table of key-value pairs accessible
---   in the HTML template. Keys are variable names, values can be signals,
---   functions, strings, numbers, booleans, or tables.
function Renderer:Render(context)
    self._context = context

    -- Dispose previous signal subscriptions
    if self._reactivityHandle then
        self._reactivityHandle.dispose()
        self._reactivityHandle = nil
    end

    -- Run the full pipeline
    local createArg, eventMaps, root, mwRoot = runPipeline(self, context)

    -- Create or update the OpenMW element
    if self._element then
        -- Update existing element
        self._element.layout = createArg
        self._element:update()
    else
        -- First render: create the element
        self._element = UI.create(createArg)
    end

    -- Subscribe to signals for reactive re-render
    self._reactivityHandle = Reactivity.SubscribeBatched(context, function()
        self:_Rerender()
    end)
end

---------------------------------------------------------------------------
-- Re-render (signal-triggered)
---------------------------------------------------------------------------

--- Internal method: re-run the pipeline and update the OpenMW element.
--- Called when a signal in the context changes.
--- @private
function Renderer:_Rerender()
    if not self._context then return end
    if not self._element then return end

    -- Reset hover tracker — hover state will be re-established by events
    -- (We don't reset here since hover state persists across re-renders)

    local createArg = runPipeline(self, self._context)

    self._element.layout = createArg
    self._element:update()
end

---------------------------------------------------------------------------
-- Cleanup
---------------------------------------------------------------------------

--- Destroy the UI element and dispose all subscriptions.
function Renderer:Destroy()
    if self._reactivityHandle then
        self._reactivityHandle.dispose()
        self._reactivityHandle = nil
    end

    if self._element then
        self._element:destroy()
        self._element = nil
    end

    self._hoverTracker:Reset()
    self._context = nil
end

---------------------------------------------------------------------------
-- CSS Variable API
---------------------------------------------------------------------------

--- Set a CSS variable from Lua code (outside of CSS).
--- @param name string Variable name including -- prefix (e.g. "--primary-color")
--- @param value string The value
function Renderer:SetCssVariable(name, value)
    self._variableResolver:Set(name, value)
end

--- Get the current value of a CSS variable.
--- @param name string Variable name including -- prefix
--- @return string|nil
function Renderer:GetCssVariable(name)
    return self._variableResolver:Get(name)
end

return Renderer
