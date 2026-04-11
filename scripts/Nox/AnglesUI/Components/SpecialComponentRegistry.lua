--- AnglesUI Special Component Registry.
--- Manages the built-in "special" engine components (mw-window, mw-hr, etc.)
--- that expand into predefined HTML/CSS templates stored as real files.
---
--- To add a new special component:
---   1. Create ComponentName.html and ComponentName.css in SpecialComponents/
---   2. Register the tag name and base path in SPECIAL_COMPONENTS below
---
--- Using real .html/.css files means editors provide syntax highlighting,
--- linting, and autocompletion for the component templates.

local VFS = require("openmw.vfs")

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

--- @class AnglesUI.SpecialComponentEntry
--- @field htmlPath string VFS path to the .html template
--- @field cssPath string VFS path to the .css stylesheet

--- @class AnglesUI.SpecialComponentRegistry
local SpecialComponentRegistry = {}

--- Base VFS directory for special component files.
local BASE_DIR = "scripts/Nox/AnglesUI/Components/SpecialComponents/"

--- Built-in special components: tag name → file paths.
--- @type table<string, AnglesUI.SpecialComponentEntry>
local SPECIAL_COMPONENTS = {
    ["mw-window"] = {
        htmlPath = BASE_DIR .. "MwWindow.html",
        cssPath  = BASE_DIR .. "MwWindow.css",
    },
    ["mw-hr"] = {
        htmlPath = BASE_DIR .. "MwHr.html",
        cssPath  = BASE_DIR .. "MwHr.css",
    },
}

--- Cache for file contents so we only read from VFS once per component.
--- @type table<string, string>
local fileCache = {}

--- Cache for parsed ASTs so we only parse once per component.
--- @type table<string, { htmlAst: AnglesUI.BaseNode[]?, cssAst: AnglesUI.CssStylesheet? }>
local parsedCache = {}

---------------------------------------------------------------------------
-- Internal: VFS file reading with caching
---------------------------------------------------------------------------

--- Read a file from VFS with caching.
--- @param path string VFS path
--- @return string? contents
local function readFile(path)
    if fileCache[path] then return fileCache[path] end

    if not VFS.fileExists(path) then return nil end

    local handle, err = VFS.open(path)
    if not handle then
        error("SpecialComponentRegistry: Cannot read '" .. path .. "': " .. (err or "unknown error"))
    end

    local contents = handle:read("*all")
    fileCache[path] = contents
    return contents
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

--- Check if a tag name is a special engine component.
--- @param tagName string
--- @return boolean
function SpecialComponentRegistry.IsSpecial(tagName)
    return SPECIAL_COMPONENTS[tagName:lower()] ~= nil
end

--- Get the raw HTML template string for a special component.
--- @param tagName string
--- @return string?
function SpecialComponentRegistry.GetHtml(tagName)
    local entry = SPECIAL_COMPONENTS[tagName:lower()]
    if not entry then return nil end
    return readFile(entry.htmlPath)
end

--- Get the raw CSS string for a special component.
--- @param tagName string
--- @return string?
function SpecialComponentRegistry.GetCss(tagName)
    local entry = SPECIAL_COMPONENTS[tagName:lower()]
    if not entry then return nil end
    return readFile(entry.cssPath)
end

--- Get or parse the HTML AST for a special component.
--- Requires a parser function to avoid circular dependencies.
--- @param tagName string
--- @param parseHtmlFunc fun(source: string): AnglesUI.BaseNode[]
--- @return AnglesUI.BaseNode[]?
function SpecialComponentRegistry.GetOrParseHtml(tagName, parseHtmlFunc)
    local lower = tagName:lower()
    if not SPECIAL_COMPONENTS[lower] then return nil end

    if not parsedCache[lower] then
        parsedCache[lower] = {}
    end

    if not parsedCache[lower].htmlAst then
        local source = SpecialComponentRegistry.GetHtml(lower)
        if not source then return nil end
        parsedCache[lower].htmlAst = parseHtmlFunc(source)
    end

    return parsedCache[lower].htmlAst
end

--- Get or parse the CSS AST for a special component.
--- @param tagName string
--- @param parseCssFunc fun(source: string): AnglesUI.CssStylesheet
--- @return AnglesUI.CssStylesheet?
function SpecialComponentRegistry.GetOrParseCss(tagName, parseCssFunc)
    local lower = tagName:lower()
    if not SPECIAL_COMPONENTS[lower] then return nil end

    if not parsedCache[lower] then
        parsedCache[lower] = {}
    end

    if not parsedCache[lower].cssAst then
        local source = SpecialComponentRegistry.GetCss(lower)
        if not source or #source == 0 then return nil end
        parsedCache[lower].cssAst = parseCssFunc(source)
    end

    return parsedCache[lower].cssAst
end

--- Get all registered special component tag names.
--- @return string[]
function SpecialComponentRegistry.GetAllTags()
    local tags = {}
    for tag, _ in pairs(SPECIAL_COMPONENTS) do
        tags[#tags + 1] = tag
    end
    return tags
end

--- Clear all caches (useful for testing/reloading).
function SpecialComponentRegistry.ClearCache()
    fileCache = {}
    parsedCache = {}
end

return SpecialComponentRegistry
