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
local LayoutInit    = require("scripts.Nox.AnglesUI.Renderer.LayoutInit")
local BoxModel      = require("scripts.Nox.AnglesUI.Renderer.BoxModel")
local ScrollCanvas  = require("scripts.Nox.AnglesUI.Renderer.ScrollCanvas")
local Transpiler    = require("scripts.Nox.AnglesUI.Renderer.Transpiler")
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
    if contents == nil then return nil end
    return tostring(contents)
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
    return HtmlParser.Parse(source)
end

--- Parse a CSS source string into a stylesheet AST.
--- @param source string
--- @return AnglesUI.CssStylesheet
local function parseCss(source)
    return CssParser.Parse(source)
end

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

--- @class AnglesUI.Renderer
--- @field private _htmlPath string
--- @field private _htmlAst AnglesUI.BaseNode[] Pristine copy of the parsed HTML AST; never mutated.
--- @field private _cssAst AnglesUI.CssStylesheet|nil
--- @field private _registry AnglesUI.ComponentRegistry
--- @field private _hoverTracker AnglesUI.HoverTracker
--- @field private _element table|nil The OpenMW UI element
--- @field private _context table|nil The last-used evaluation context
--- @field private _reactivityHandle AnglesUI.ReactivityHandle|nil
--- @field private _variableResolver AnglesUI.CssVariableResolver
--- @field private _scrollOffsets table<string, {x:number,y:number}> Persisted scroll positions keyed by scroll canvas ID.
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
    -- Keep a pristine copy of the parsed AST so that runPipeline can produce
    -- a fresh working copy each time without accumulating mutations from
    -- component expansion or content projection.
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
    --- Shared mutable reference passed to Dragger/Resizable callbacks so they can
    --- reach the live OpenMW element even though the callbacks are built before
    --- UI.create() is called. Populated in Render() after UI.create().
    self._elementRef = {}
    --- Persisted position/size override applied after CSS cascade so that
    --- resize and drag operations survive full re-renders (signal-triggered
    --- or post-resize). Format: {x, y, w, h} — any field may be nil.
    self._rootOverride = nil
    --- Persisted scroll offsets for each mw-scroll-canvas, keyed by the node's
    --- id attribute. Re-injected into scrollState after each layout pass so that
    --- signal-triggered re-renders do not reset scroll positions.
    self._scrollOffsets = {}

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
                -- The special component template replaces the content.
                -- Deep-copy the template root so ContentProjection never mutates the cache.
                local templateRoot = HtmlNodes.DeepCopyNode(templateAst[1])
                local projected = node.children or {}

                if templateRoot.type == NodeType.Element then
                    --- @cast templateRoot AnglesUI.ElementNode
                    if templateRoot.tag == "mw-content" then
                        -- Template root is mw-content: host element IS the container.
                        -- Project the caller's children directly into the host element.
                        node.children = projected
                        for _, projChild in ipairs(projected) do
                            if projChild.type == NodeType.Element then
                                projChild._logicalHostNode = node
                            end
                        end
                    else
                        -- Template root is a wrapper element: use the deep copy directly.
                        local cloned = templateRoot

                        -- Project content
                        if cloned.children and #cloned.children > 0 then
                            cloned.children = ContentProjection.Project(cloned.children, projected)
                        else
                            cloned.children = projected
                        end

                        -- Annotate only the originally-projected caller children so DomTreeBuilder
                        -- can set logicalParent. Template-internal elements keep their natural
                        -- parent chain and should NOT be annotated.
                        for _, projChild in ipairs(projected) do
                            if projChild.type == NodeType.Element then
                                projChild._logicalHostNode = node
                            end
                        end

                        -- Replace the original node's children
                        node.children = { cloned }
                    end
                end
            end
        -- User components
        elseif registry:IsRegistered(tag) then
            local templateAst = registry:GetOrParseHtml(tag, parseHtml, readVfsFile)
            if templateAst and #templateAst > 0 then
                -- Deep-copy the template root so ContentProjection never mutates the cache.
                local templateRoot = HtmlNodes.DeepCopyNode(templateAst[1])
                local projected = node.children or {}

                if templateRoot.type == NodeType.Element then
                    --- @cast templateRoot AnglesUI.ElementNode
                    if templateRoot.tag == "mw-content" then
                        -- Template root is mw-content: project directly into host.
                        node.children = projected
                        for _, projChild in ipairs(projected) do
                            if projChild.type == NodeType.Element then
                                projChild._logicalHostNode = node
                            end
                        end
                    else
                        -- Use the deep-copied template root as the cloned wrapper.
                        local cloned = templateRoot

                        if cloned.children and #cloned.children > 0 then
                            cloned.children = ContentProjection.Project(cloned.children, projected)
                        else
                            cloned.children = projected
                        end

                        -- Annotate only originally-projected caller children (not template elements)
                        for _, projChild in ipairs(projected) do
                            if projChild.type == NodeType.Element then
                                projChild._logicalHostNode = node
                            end
                        end

                        node.children = { cloned }
                    end
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
                    r.componentTag = tag  -- tag flat rules so :host can be resolved
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
                r.componentTag = tagName  -- tag flat rules so :host can be resolved
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
    -- 1. Fresh working copy of the HTML AST so component expansion and content
    --    projection never mutate the pristine source.  Without this, a re-render
    --    (e.g. after resize or signal update) would try to expand already-expanded
    --    nodes and projected content would be lost on the second pass.
    local workAst = HtmlNodes.DeepCopyAst(self._htmlAst)
    expandComponents(workAst, self._registry, nil)

    -- 2. Build DOM tree from the working AST
    local root = DomTreeBuilder.Build(workAst)

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

    -- 5. CSS Cascade — two-pass to handle @container queries correctly.
    --
    -- Container queries must be evaluated AFTER layout so the evaluator can
    -- read real pixel dimensions from layoutData.  We therefore:
    --   Pass 1: cascade all non-@container rules → nodes get width/height,
    --           container-type/name, and all other non-container styles.
    --   Layout: BoxModel.LayoutTree fills layoutData for every node.
    --   Pass 2: cascade only @container rules and merge over computed styles.
    --   (A second layout pass then applies the changed styles.)
    local allFlatRules = collectFlatRules(self)
    local hoverSet = self._hoverTracker:GetHoverSet()
    local mediaEval = MediaQueryEvaluator.New(screenW, screenH):CreateEvaluatorFunc()
    local containerEval = ContainerQueryEvaluator.CreateEvaluatorFunc()

    -- Split rules into non-container and container buckets
    local nonContainerRules = {}
    local containerRules    = {}
    for _, r in ipairs(allFlatRules) do
        if r.atRuleName == "container" then
            containerRules[#containerRules + 1] = r
        else
            nonContainerRules[#nonContainerRules + 1] = r
        end
    end

    -- Collect CSS variables from root CSS
    if self._cssAst then
        self._variableResolver:CollectFromStylesheet(self._cssAst)
    end

    -- Pass 1: all rules except @container
    CssCascade.ApplyToTree(root, nonContainerRules, self._variableResolver, hoverSet, nil, mediaEval, nil)

    -- Apply any persisted resize/drag override to mw-root's computed styles so
    -- that the layout pass uses the user-adjusted dimensions rather than the
    -- CSS-defined ones. This must happen AFTER the cascade (which would reset
    -- them) but BEFORE the layout pass (step 8).
    if self._rootOverride then
        local ovr = self._rootOverride
        if ovr.w then mwRoot.computedStyles["width"]  = math.floor(ovr.w) .. "px" end
        if ovr.h then mwRoot.computedStyles["height"] = math.floor(ovr.h) .. "px" end
        if ovr.x or ovr.y then
            mwRoot.computedStyles["position"] = "absolute"
            if ovr.x then mwRoot.computedStyles["left"] = math.floor(ovr.x) .. "px" end
            if ovr.y then mwRoot.computedStyles["top"]  = math.floor(ovr.y) .. "px" end
        end
    end

    -- First layout pass — gives every node real dimensions in layoutData.
    -- Container query evaluation in Pass 2 reads these.
    BoxModel.LayoutTree(root, screenW, screenH)

    -- Pass 2: @container rules only — now layoutData is populated so the
    -- ContainerQueryEvaluator can read actual pixel widths/heights.
    if #containerRules > 0 then
        CssCascade.ApplyContainerRules(root, containerRules, self._variableResolver, hoverSet, nil, containerEval)

        -- Second layout pass to apply any style changes from container rules.
        BoxModel.LayoutTree(root, screenW, screenH)
    end

    -- Inject persisted scroll offsets into each mw-scroll-canvas node
    -- AFTER the final layout pass (which recreates scrollState from scratch).
    -- This ensures signal-triggered re-renders and resize re-renders do not
    -- snap scroll positions back to zero.
    root:Walk(function(domNode)
        if domNode.kind == DomNodeKind.Element
            and domNode.tag == "mw-scroll-canvas"
            and domNode.id then
            local saved = self._scrollOffsets[domNode.id]
            if saved and domNode.layoutData and domNode.layoutData.scrollState then
                local ss = domNode.layoutData.scrollState
                ss.scrollX = ScrollCanvas.ClampScroll(saved.x or 0, ss.viewportWidth, ss.contentWidth)
                ss.scrollY = ScrollCanvas.ClampScroll(saved.y or 0, ss.viewportHeight, ss.contentHeight)
            end
        end
        return false
    end)

    -- 6. Runtime evaluation (directives, bindings, events)
    local eventMaps = RuntimeInit.Evaluate(root, context)

    -- 7. Handle Dragger and Resizable on mw-root
    -- Use self._elementRef so it can be populated with the live OpenMW element
    -- after UI.create() in Render().
    local elementRef = self._elementRef

    -- Callbacks that persist position/size overrides across re-renders and
    -- trigger a full re-layout when a resize drag completes.
    local function onDragUpdate(newX, newY)
        local ovr = self._rootOverride or {}
        ovr.x = newX
        ovr.y = newY
        self._rootOverride = ovr
    end

    local function onResizeUpdate(newX, newY, newW, newH)
        self._rootOverride = { x = newX, y = newY, w = newW, h = newH }
    end

    local function onResizeComplete()
        -- Re-run the full pipeline so all children re-layout to the new root size.
        if self._element then
            self:_Rerender()
        end
    end

    -- Check all descendants for Dragger
    mwRoot:Walk(function(node)
        if node.kind == DomNodeKind.Element and Dragger.HasDragger(node) then
            local dragCbs = Dragger.BuildCallbacks(node, mwRoot, elementRef, Util, UI, Async, layerName, onDragUpdate)
            local existing = eventMaps[node] or {}
            eventMaps[node] = EventBinding.MergeCallbackMaps(existing, dragCbs)
        end
        return false
    end)

    -- Resizable on mw-root
    if Resizable.IsResizable(mwRoot) then
        local edgeMargin = Resizable.GetEdgeMargin(mwRoot)
        local resizeCbs = Resizable.BuildCallbacks(mwRoot, edgeMargin, elementRef, Util, UI, Async, layerName, onResizeUpdate, onResizeComplete)
        local existing = eventMaps[mwRoot] or {}
        eventMaps[mwRoot] = EventBinding.MergeCallbackMaps(existing, resizeCbs)
    end

    -- 8. Transpile to OpenMW UI format
    local rerenderFn = function() self:_Rerender() end
    local createArg = Transpiler.Transpile(root, eventMaps, context, self._hoverTracker, self._elementRef, self._scrollOffsets, rerenderFn)

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

    -- Populate the shared element reference so Dragger/Resizable callbacks can
    -- reach the live OpenMW element. Must happen after UI.create().
    self._elementRef.element = self._element

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
