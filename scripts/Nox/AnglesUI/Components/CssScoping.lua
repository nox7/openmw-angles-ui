--- AnglesUI CSS Scoping.
--- Implements CSS isolation for user components.
---
--- Rules:
---   1. A component's CSS only applies to elements originally defined
---      in that component's template (not projected content from parents).
---   2. A parent's CSS can reach into descendant component elements.
---   3. Component CSS cannot leak upward to parent elements.
---   4. :host in a component's CSS targets the component's host element.
---
--- Implementation approach: Each component gets a unique scopeId.
--- When building the DOM, we tag each DomNode with the scopeId of the
--- component that owns it. During cascade, we filter CSS rules so that
--- a component's rules only match nodes sharing the same scopeId.

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

--- @class AnglesUI.CssScoping
local CssScoping = {}

---------------------------------------------------------------------------
-- Scope assignment
---------------------------------------------------------------------------

--- Assign a scopeId to all DomNodes in a subtree.
--- This is called when a component's template DOM is created.
--- @param rootNode AnglesUI.DomNode The root of the component's template subtree
--- @param scopeId string The unique scope identifier
function CssScoping.AssignScope(rootNode, scopeId)
    rootNode:Walk(function(node)
        -- Only assign scope to nodes that don't already have one
        -- (projected content keeps its original scope)
        if not node.scopeId then
            node.scopeId = scopeId
        end
        return false
    end)
end

--- Assign a scopeId to a single node without walking children.
--- @param node AnglesUI.DomNode
--- @param scopeId string
function CssScoping.AssignScopeToNode(node, scopeId)
    if not node.scopeId then
        node.scopeId = scopeId
    end
end

---------------------------------------------------------------------------
-- Scope-aware rule filtering
---------------------------------------------------------------------------

--- Filter flat CSS rules for a given DOM node, respecting scope boundaries.
--- Returns only the rules that should apply to this node based on scoping.
---
--- @param flatRules AnglesUI._FlatRule[] All flattened rules
--- @param domNode AnglesUI.DomNode The target node
--- @param ruleScopeMap table<AnglesUI._FlatRule, string?> Mapping of rule → scopeId (nil = global/parent scope)
--- @return AnglesUI._FlatRule[] filtered Rules that can apply to this node
function CssScoping.FilterRulesForNode(flatRules, domNode, ruleScopeMap)
    local filtered = {}
    local nodeScope = domNode.scopeId

    for _, rule in ipairs(flatRules) do
        local ruleScope = ruleScopeMap[rule]

        if not ruleScope then
            -- Global / parent scope rules can apply to any node
            filtered[#filtered + 1] = rule
        elseif ruleScope == nodeScope then
            -- Component-scoped rule matches the node's scope
            filtered[#filtered + 1] = rule
        end
        -- If ruleScope ~= nodeScope and ruleScope is not nil,
        -- the rule belongs to a different component and should NOT apply
    end

    return filtered
end

---------------------------------------------------------------------------
-- Rule scope mapping
---------------------------------------------------------------------------

--- Create a rule-to-scope mapping for a set of flat rules.
--- @param flatRules AnglesUI._FlatRule[]
--- @param scopeId string? The scope these rules belong to (nil = global)
--- @return table<AnglesUI._FlatRule, string?>
function CssScoping.CreateRuleScopeMap(flatRules, scopeId)
    local map = {}
    for _, rule in ipairs(flatRules) do
        map[rule] = scopeId
    end
    return map
end

--- Merge multiple rule scope maps into one.
--- @param ... table<AnglesUI._FlatRule, string?>
--- @return table<AnglesUI._FlatRule, string?>
function CssScoping.MergeRuleScopeMaps(...)
    local merged = {}
    for i = 1, select("#", ...) do
        local map = select(i, ...)
        if map then
            for rule, scope in pairs(map) do
                merged[rule] = scope
            end
        end
    end
    return merged
end

return CssScoping
