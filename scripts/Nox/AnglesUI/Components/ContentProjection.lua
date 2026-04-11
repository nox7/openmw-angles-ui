--- AnglesUI Content Projection.
--- Implements Angular-style content projection via <mw-content> elements.
---
--- When a user component is used in a parent template, the children
--- placed inside the user component tag become "projected content".
--- The component's own template uses <mw-content> to mark where that
--- content should be inserted.
---
--- <mw-content select=".selector"> projects only matching children.
--- <mw-content> (no select) projects any remaining un-projected children.
--- Non-select mw-content elements are processed last.

local HtmlNodes = require("scripts.Nox.AnglesUI.Parser.HTML.HtmlNodes")
local CssSelectorEngine = require("scripts.Nox.AnglesUI.Parser.CSS.CssSelectorEngine")

local NodeType = HtmlNodes.NodeType

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

--- @class AnglesUI.ContentProjection
local ContentProjection = {}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

--- Get the "select" attribute value from an mw-content element node.
--- @param node AnglesUI.ElementNode
--- @return string? selector The CSS selector string, or nil if no select attr
local function getSelectAttr(node)
    if not node.attributes then return nil end
    for _, attr in ipairs(node.attributes) do
        if attr.name == "select" then
            return attr.value
        end
    end
    return nil
end

--- Check if an HTML element node matches a simple CSS selector string.
--- Uses the selector engine for matching.
--- @param node AnglesUI.BaseNode
--- @param selectorText string
--- @return boolean
local function matchesSelector(node, selectorText)
    if node.type ~= NodeType.Element then return false end
    --- @cast node AnglesUI.ElementNode

    local selectors = CssSelectorEngine.Parse(selectorText)
    for _, selector in ipairs(selectors) do
        if CssSelectorEngine.Match(selector, node, nil, nil) then
            return true
        end
    end
    return false
end

--- Find all <mw-content> elements in a component's template AST.
--- Separates them into "select" slots and "default" slots.
--- @param templateChildren AnglesUI.BaseNode[]
--- @return AnglesUI.ElementNode[] selectSlots mw-content nodes with a select attribute
--- @return AnglesUI.ElementNode[] defaultSlots mw-content nodes without select
local function findContentSlots(templateChildren)
    local selectSlots = {}
    local defaultSlots = {}

    local function walk(children)
        for _, child in ipairs(children) do
            if child.type == NodeType.Element then
                --- @cast child AnglesUI.ElementNode
                if child.tag == "mw-content" then
                    local selectAttr = getSelectAttr(child)
                    if selectAttr and #selectAttr > 0 then
                        selectSlots[#selectSlots + 1] = child
                    else
                        defaultSlots[#defaultSlots + 1] = child
                    end
                else
                    -- Continue searching inside non-mw-content elements
                    walk(child.children)
                end
            elseif child.type == NodeType.IfDirective then
                --- @cast child AnglesUI.IfDirectiveNode
                walk(child.children)
                for _, branch in ipairs(child.elseIfBranches or {}) do
                    walk(branch.children)
                end
                if child.elseBranch then
                    walk(child.elseBranch.children)
                end
            elseif child.type == NodeType.ForDirective then
                --- @cast child AnglesUI.ForDirectiveNode
                walk(child.children)
            end
        end
    end

    walk(templateChildren)
    return selectSlots, defaultSlots
end

---------------------------------------------------------------------------
-- Core projection
---------------------------------------------------------------------------

--- Perform content projection on a user component's template AST.
--- Replaces <mw-content> nodes with the appropriate projected children
--- from the usage site.
---
--- @param templateChildren AnglesUI.BaseNode[] The component's own template children
--- @param projectedChildren AnglesUI.BaseNode[] The children from the usage site (what's between <custom-tag>...</custom-tag>)
--- @return AnglesUI.BaseNode[] result The template with mw-content replaced by projected content
---@nodiscard
function ContentProjection.Project(templateChildren, projectedChildren)
    if not projectedChildren or #projectedChildren == 0 then
        -- No projected content — just strip mw-content nodes
        return ContentProjection._stripContentNodes(templateChildren)
    end

    -- Phase 1: process select slots (they get priority)
    local selectSlots, defaultSlots = findContentSlots(templateChildren)

    -- Track which projected children have been claimed by a select slot
    local claimed = {}

    -- Build a mapping: mw-content node → replacement children
    --- @type table<AnglesUI.ElementNode, AnglesUI.BaseNode[]>
    local replacements = {}

    -- Process select slots first
    for _, slot in ipairs(selectSlots) do
        local selector = getSelectAttr(slot)
        if selector then
            local matched = {}
            for i, child in ipairs(projectedChildren) do
                if not claimed[i] and matchesSelector(child, selector) then
                    matched[#matched + 1] = child
                    claimed[i] = true
                end
            end
            replacements[slot] = matched
        end
    end

    -- Process default slots last — get all unclaimed children
    local unclaimed = {}
    for i, child in ipairs(projectedChildren) do
        if not claimed[i] then
            unclaimed[#unclaimed + 1] = child
        end
    end

    for _, slot in ipairs(defaultSlots) do
        replacements[slot] = unclaimed
        -- After the first default slot consumes the unclaimed, subsequent
        -- default slots get nothing (unclaimed is shared reference but this
        -- matches browser behavior where only one default slot gets content)
        unclaimed = {}
    end

    -- Phase 2: rebuild the template tree with replacements applied
    return ContentProjection._replaceContentNodes(templateChildren, replacements)
end

---------------------------------------------------------------------------
-- Tree rewriting
---------------------------------------------------------------------------

--- Replace mw-content nodes in a children list with their projected content.
---@private
--- @param children AnglesUI.BaseNode[]
--- @param replacements table<AnglesUI.ElementNode, AnglesUI.BaseNode[]>
--- @return AnglesUI.BaseNode[]
function ContentProjection._replaceContentNodes(children, replacements)
    local result = {}

    for _, child in ipairs(children) do
        if child.type == NodeType.Element then
            --- @cast child AnglesUI.ElementNode
            if child.tag == "mw-content" then
                -- Replace with projected content
                local replacement = replacements[child]
                if replacement then
                    for _, projChild in ipairs(replacement) do
                        result[#result + 1] = projChild
                    end
                end
                -- If no replacement, the mw-content is simply removed
            else
                -- Recursively process children of non-mw-content elements
                local newChildren = ContentProjection._replaceContentNodes(child.children, replacements)
                child.children = newChildren
                -- Re-parent
                for _, c in ipairs(newChildren) do
                    c.parent = child
                end
                result[#result + 1] = child
            end
        elseif child.type == NodeType.IfDirective then
            --- @cast child AnglesUI.IfDirectiveNode
            child.children = ContentProjection._replaceContentNodes(child.children, replacements)
            for _, branch in ipairs(child.elseIfBranches or {}) do
                branch.children = ContentProjection._replaceContentNodes(branch.children, replacements)
            end
            if child.elseBranch then
                child.elseBranch.children = ContentProjection._replaceContentNodes(child.elseBranch.children, replacements)
            end
            result[#result + 1] = child
        elseif child.type == NodeType.ForDirective then
            --- @cast child AnglesUI.ForDirectiveNode
            child.children = ContentProjection._replaceContentNodes(child.children, replacements)
            result[#result + 1] = child
        else
            result[#result + 1] = child
        end
    end

    return result
end

--- Strip all mw-content nodes from a template (used when no projected content exists).
---@private
--- @param children AnglesUI.BaseNode[]
--- @return AnglesUI.BaseNode[]
function ContentProjection._stripContentNodes(children)
    local result = {}

    for _, child in ipairs(children) do
        if child.type == NodeType.Element then
            --- @cast child AnglesUI.ElementNode
            if child.tag ~= "mw-content" then
                child.children = ContentProjection._stripContentNodes(child.children)
                result[#result + 1] = child
            end
        elseif child.type == NodeType.IfDirective then
            --- @cast child AnglesUI.IfDirectiveNode
            child.children = ContentProjection._stripContentNodes(child.children)
            for _, branch in ipairs(child.elseIfBranches or {}) do
                branch.children = ContentProjection._stripContentNodes(branch.children)
            end
            if child.elseBranch then
                child.elseBranch.children = ContentProjection._stripContentNodes(child.elseBranch.children)
            end
            result[#result + 1] = child
        elseif child.type == NodeType.ForDirective then
            --- @cast child AnglesUI.ForDirectiveNode
            child.children = ContentProjection._stripContentNodes(child.children)
            result[#result + 1] = child
        else
            result[#result + 1] = child
        end
    end

    return result
end

return ContentProjection
