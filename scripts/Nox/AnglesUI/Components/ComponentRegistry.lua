--- AnglesUI Component Registry.
--- Manages the registration and lookup of user-defined components and
--- their associated HTML/CSS file paths. When a tag is encountered in the
--- HTML that is not an engine component (mw-*), this registry is consulted.
---
--- Each registered component stores:
---   - tagName: The custom element tag name (e.g. "nox-custom-component")
---   - htmlPath: VFS path to the component's HTML file
---   - cssPath: VFS path to the associated CSS file (auto-discovered or nil)
---   - htmlAst: Parsed HTML AST (cached after first parse)
---   - cssAst: Parsed CSS AST (cached after first parse)
---   - scopeId: Unique identifier for CSS scoping

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

--- @class AnglesUI.ComponentDefinition
--- @field tagName string
--- @field htmlPath string
--- @field cssPath string?
--- @field htmlAst AnglesUI.BaseNode[]?
--- @field cssAst AnglesUI.CssStylesheet?
--- @field scopeId string

--- @class AnglesUI.ComponentRegistry
--- @field private _components table<string, AnglesUI.ComponentDefinition>
--- @field private _scopeCounter integer
local ComponentRegistry = {}
ComponentRegistry.__index = ComponentRegistry

---------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------

--- Create a new component registry.
--- @return AnglesUI.ComponentRegistry
function ComponentRegistry.New()
    local self = setmetatable({}, ComponentRegistry)
    self._components = {}
    self._scopeCounter = 0
    return self
end

---------------------------------------------------------------------------
-- Registration
---------------------------------------------------------------------------

--- Register a user component by tag name and HTML file path.
--- The CSS path is auto-discovered by replacing the .html extension with .css.
--- @param tagName string The custom element tag (e.g. "nox-inventory-slot")
--- @param htmlPath string VFS path to the component's HTML file
function ComponentRegistry:Register(tagName, htmlPath)
    local lowerTag = tagName:lower()

    -- Validate: must not start with "mw-"
    if lowerTag:sub(1, 3) == "mw-" then
        error("ComponentRegistry: Cannot register '" .. tagName .. "' — tag names starting with 'mw-' are reserved for engine components.")
    end

    self._scopeCounter = self._scopeCounter + 1

    --- @type AnglesUI.ComponentDefinition
    local def = {
        tagName = lowerTag,
        htmlPath = htmlPath,
        cssPath = nil,
        htmlAst = nil,
        cssAst = nil,
        scopeId = "scope_" .. self._scopeCounter,
    }

    -- Auto-discover CSS file: same directory and base name, .css extension
    local cssPath = htmlPath:gsub("%.html$", ".css")
    if cssPath ~= htmlPath then
        def.cssPath = cssPath
    end

    self._components[lowerTag] = def
end

--- Register multiple components from a table { tagName = htmlPath, ... }.
--- @param components table<string, string>
function ComponentRegistry:RegisterAll(components)
    for tagName, htmlPath in pairs(components) do
        self:Register(tagName, htmlPath)
    end
end

---------------------------------------------------------------------------
-- Lookup
---------------------------------------------------------------------------

--- Check if a tag name is a registered user component.
--- @param tagName string
--- @return boolean
function ComponentRegistry:IsRegistered(tagName)
    return self._components[tagName:lower()] ~= nil
end

--- Get the component definition for a tag name.
--- @param tagName string
--- @return AnglesUI.ComponentDefinition?
function ComponentRegistry:Get(tagName)
    return self._components[tagName:lower()]
end

--- Get all registered component definitions.
--- @return table<string, AnglesUI.ComponentDefinition>
function ComponentRegistry:GetAll()
    return self._components
end

---------------------------------------------------------------------------
-- Parsing (deferred — requires file loading)
---------------------------------------------------------------------------

--- Parse and cache the HTML AST for a component if not already done.
--- Requires a parser function because the registry doesn't depend on the parser directly.
--- @param tagName string
--- @param parseHtmlFunc fun(source: string): AnglesUI.BaseNode[] Parser function
--- @param readFileFunc fun(path: string): string? VFS file reader
--- @return AnglesUI.BaseNode[]?
function ComponentRegistry:GetOrParseHtml(tagName, parseHtmlFunc, readFileFunc)
    local def = self:Get(tagName)
    if not def then return nil end

    if def.htmlAst then return def.htmlAst end

    local source = readFileFunc(def.htmlPath)
    if not source then
        error("ComponentRegistry: Cannot read HTML file for component '" .. tagName .. "': " .. def.htmlPath)
    end

    def.htmlAst = parseHtmlFunc(source)
    return def.htmlAst
end

--- Parse and cache the CSS AST for a component if not already done.
--- @param tagName string
--- @param parseCssFunc fun(source: string): AnglesUI.CssStylesheet Parser function
--- @param readFileFunc fun(path: string): string? VFS file reader
--- @param fileExistsFunc fun(path: string): boolean VFS file existence check
--- @return AnglesUI.CssStylesheet?
function ComponentRegistry:GetOrParseCss(tagName, parseCssFunc, readFileFunc, fileExistsFunc)
    local def = self:Get(tagName)
    if not def then return nil end

    if def.cssAst then return def.cssAst end
    if not def.cssPath then return nil end

    if not fileExistsFunc(def.cssPath) then
        return nil -- CSS is optional
    end

    local source = readFileFunc(def.cssPath)
    if not source then return nil end

    def.cssAst = parseCssFunc(source)
    return def.cssAst
end

--- Get the scope ID for a component (used for CSS scoping).
--- @param tagName string
--- @return string?
function ComponentRegistry:GetScopeId(tagName)
    local def = self:Get(tagName)
    return def and def.scopeId or nil
end

return ComponentRegistry
