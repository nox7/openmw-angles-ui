--- AnglesUI CSS Cascade.
--- Resolves CSS rules against a DOM tree, producing computed styles per node.
--- Handles:
---   - Selector matching (via CssSelectorEngine)
---   - Specificity-based rule ordering
---   - Source order tie-breaking
---   - Nested rule expansion
---   - var() resolution (via CssVariableResolver)
---   - Container-type / container-name detection

local CssSelectorEngine   = require("scripts.Nox.AnglesUI.Parser.CSS.CssSelectorEngine")
local CssVariableResolver  = require("scripts.Nox.AnglesUI.Parser.CSS.CssVariableResolver")

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

--- @class AnglesUI.CssCascade
local CssCascade = {}

--- Forward declaration
local matchSelectorOnDomNode

---------------------------------------------------------------------------
-- Internal: flatten a stylesheet into a linear list of resolved rules.
-- Each flattened entry has: resolvedSelector (string), declarations[],
-- parsedSelectors (from engine), sourceOrder (integer).
---------------------------------------------------------------------------

--- @class AnglesUI._FlatRule
--- @field resolvedSelector string
--- @field parsedSelectors AnglesUI.Selector[]
--- @field declarations AnglesUI.CssDeclaration[]
--- @field sourceOrder integer
--- @field atRuleCondition string? For media/container rules, the unparsed prelude
--- @field atRuleName string? "media" or "container"
--- @field componentTag string? Tag name of the owning component, used for :host matching

--- Flatten rules recursively, expanding nested selectors.
--- @param rules (AnglesUI.CssRule | AnglesUI.CssAtRule)[]
--- @param parentSelector string? The parent selector text for nesting
--- @param output AnglesUI._FlatRule[]
--- @param counter table A table with a single field `n` for source order
--- @param atRuleName string?
--- @param atRulePrelude string?
local function flattenRules(rules, parentSelector, output, counter, atRuleName, atRulePrelude)
    for _, rule in ipairs(rules) do
        if rule.type == "Rule" then
            --- @cast rule AnglesUI.CssRule
            local resolvedSel = rule.selectorText
            if parentSelector and #parentSelector > 0 then
                resolvedSel = CssSelectorEngine.ResolveNested(parentSelector, rule.selectorText)
            end

            counter.n = counter.n + 1

            -- Add the rule's own declarations
            if #rule.declarations > 0 then
                output[#output + 1] = {
                    resolvedSelector = resolvedSel,
                    parsedSelectors  = CssSelectorEngine.Parse(resolvedSel),
                    declarations     = rule.declarations,
                    sourceOrder      = counter.n,
                    atRuleName       = atRuleName,
                    atRuleCondition  = atRulePrelude,
                }
            end

            -- Recurse into nested rules
            if rule.nestedRules and #rule.nestedRules > 0 then
                flattenRules(rule.nestedRules, resolvedSel, output, counter, atRuleName, atRulePrelude)
            end

        elseif rule.type == "AtRule" then
            --- @cast rule AnglesUI.CssAtRule
            if rule.name == "media" or rule.name == "container" then
                -- Recurse with at-rule context
                flattenRules(rule.rules, parentSelector, output, counter, rule.name, rule.prelude)
            end
            -- Other at-rules are ignored for now
        end
    end
end

--- Flatten a stylesheet into a sorted list of flat rules.
--- @param stylesheet AnglesUI.CssStylesheet
--- @return AnglesUI._FlatRule[]
---@nodiscard
function CssCascade.FlattenStylesheet(stylesheet)
    local output = {}
    local counter = { n = 0 }
    flattenRules(stylesheet.rules, nil, output, counter, nil, nil)
    return output
end

---------------------------------------------------------------------------
-- Matching & sorting
---------------------------------------------------------------------------

--- Match flat rules against a single DOM element and return matched entries
--- sorted by specificity (ascending, so last wins).
--- @param flatRules AnglesUI._FlatRule[]
--- @param domNode AnglesUI.DomNode
--- @param hoverSet table<any, boolean>?
--- @param hostElement AnglesUI.DomNode?
--- @param mediaEvaluator fun(prelude: string): boolean?
--- @param containerEvaluator fun(prelude: string, node: AnglesUI.DomNode): boolean?
--- @return AnglesUI.MatchedRule[]
---@nodiscard
function CssCascade.MatchRules(flatRules, domNode, hoverSet, hostElement, mediaEvaluator, containerEvaluator)
    --- @type AnglesUI.MatchedRule[]
    local matched = {}

    -- The selector engine operates on the html node shape (tag, attributes, parent)
    -- Our DomNode caches these, but the selector engine expects the HtmlNodes interface.
    -- We create a thin adapter so the engine can use our DomNode directly.
    -- The selector engine checks: .tag, .attributes (list), .parent, .children, .type
    -- Our DomNode has: .tag, .htmlNode.attributes, .parent, .children, .kind
    -- We'll match against the htmlNode since the selector engine already works with it,
    -- but we need parent references to follow the DomNode tree.

    for _, flatRule in ipairs(flatRules) do
        -- Check at-rule conditions
        local skip = false
        if flatRule.atRuleName == "media" then
            if mediaEvaluator and not mediaEvaluator(flatRule.atRuleCondition) then
                skip = true
            end
        elseif flatRule.atRuleName == "container" then
            if containerEvaluator and not containerEvaluator(flatRule.atRuleCondition, domNode) then
                skip = true
            end
        end

        if not skip then
        -- Determine effective host element for :host matching.
        -- When a rule belongs to a specific component (componentTag is set):
        --   * If the current node IS the component host, use it directly.
        --   * Otherwise walk up the DOM parent chain to find the nearest ancestor
        --     whose tag matches the component tag. This allows nested selectors such
        --     as `:host > mw-window` or `:host > mw-window mw-text` to resolve `:host`
        --     correctly even when matching an interior descendant of the component.
        local effectiveHost = hostElement
        if flatRule.componentTag then
            if domNode.tag == flatRule.componentTag then
                effectiveHost = domNode
            else
                local ancestor = domNode.parent
                while ancestor do
                    if ancestor.tag == flatRule.componentTag then
                        effectiveHost = ancestor
                        break
                    end
                    ancestor = ancestor.parent
                end
            end
        end

        -- Try each parsed selector
        for _, selector in ipairs(flatRule.parsedSelectors) do
            if matchSelectorOnDomNode(selector, domNode, hoverSet, effectiveHost) then
                local a, b, c = CssSelectorEngine.Specificity(selector)
                matched[#matched + 1] = {
                    rule = flatRule, -- We store the flat rule rather than original CssRule
                    selector = selector,
                    specificity = { a, b, c },
                    order = flatRule.sourceOrder,
                }
                break -- One matching selector per rule is enough
            end
        end
        end -- if not skip

    end

    -- Sort by specificity (ascending), then source order
    table.sort(matched, function(a, b)
        local sa, sb = a.specificity, b.specificity
        if sa[1] ~= sb[1] then return sa[1] < sb[1] end
        if sa[2] ~= sb[2] then return sa[2] < sb[2] end
        if sa[3] ~= sb[3] then return sa[3] < sb[3] end
        return a.order < b.order
    end)

    return matched
end

---------------------------------------------------------------------------
-- DomNode ↔ Selector Engine bridge
---------------------------------------------------------------------------

--- The selector engine's Match function expects elements with .tag,
--- .attributes (array), .parent, .children, .type == "Element" interface.
--- DomNode almost matches but parent is a DomNode, not an HtmlNode.
--- We create lightweight proxy tables that the selector engine can traverse.

--- @type table<AnglesUI.DomNode, table> Cache of proxy objects
local proxyCache = setmetatable({}, { __mode = "k" })

--- Create a proxy that looks like an HtmlNode/ElementNode for the selector engine.
--- @param domNode AnglesUI.DomNode
--- @return table proxy
local function getProxy(domNode)
    if proxyCache[domNode] then return proxyCache[domNode] end

    local proxy = {
        type = "Element",
        tag = domNode.tag,
        attributes = domNode.htmlNode and domNode.htmlNode.attributes or {},
        children = {}, -- lazily populated
    }

    -- Lazy parent resolution via metatable
    setmetatable(proxy, {
        __index = function(t, key)
            if key == "parent" then
                -- Use logicalParent when set (projected content pierces component wrappers)
                local cssParent = domNode.logicalParent or domNode.parent
                if cssParent then
                    return getProxy(cssParent)
                end
                return nil
            elseif key == "children" then
                -- Build children proxies on demand
                local kids = {}
                for _, child in ipairs(domNode.children) do
                    if child.kind == "Element" then
                        kids[#kids + 1] = getProxy(child)
                    end
                end
                rawset(t, "children", kids)
                return kids
            end
            return rawget(t, key)
        end,
    })

    proxyCache[domNode] = proxy
    return proxy
end

--- Match a parsed selector against a DomNode through the proxy bridge.
---@private
--- @param selector AnglesUI.Selector
--- @param domNode AnglesUI.DomNode
--- @param hoverSet table<any, boolean>?
--- @param hostElement AnglesUI.DomNode?
--- @return boolean
function matchSelectorOnDomNode(selector, domNode, hoverSet, hostElement)
    if domNode.kind ~= "Element" then return false end

    -- Build hover set that maps proxies if hover is based on DomNodes
    local proxyHoverSet = nil
    if hoverSet then
        proxyHoverSet = {}
        for node, v in pairs(hoverSet) do
            if type(node) == "table" and node.kind then
                proxyHoverSet[getProxy(node)] = v
            else
                proxyHoverSet[node] = v
            end
        end
    end

    local proxyHost = nil
    if hostElement then
        proxyHost = getProxy(hostElement)
    end

    return CssSelectorEngine.Match(selector, getProxy(domNode), proxyHoverSet, proxyHost)
end

---------------------------------------------------------------------------
-- Computed styles
---------------------------------------------------------------------------

--- Apply matched rules to produce computed styles for a single DOM node.
--- The matched rules should already be sorted ascending by specificity.
--- Later entries override earlier ones (cascade).
--- @param matchedRules AnglesUI.MatchedRule[]
--- @param variableResolver AnglesUI.CssVariableResolver?
--- @return table<string, string> computedStyles
---@nodiscard
function CssCascade.ComputeStyles(matchedRules, variableResolver)
    local styles = {}

    for _, matched in ipairs(matchedRules) do
        local flatRule = matched.rule
        for _, decl in ipairs(flatRule.declarations) do
            -- Skip custom property declarations (they're variables, not styles)
            if decl.property:sub(1, 2) ~= "--" then
                local value = decl.value
                if variableResolver then
                    value = variableResolver:Resolve(value)
                end
                styles[decl.property] = value
            end
        end
    end

    return styles
end

--- Full cascade: match all flat rules against every element in a DOM tree,
--- compute styles, and assign them to each node.
--- @param root AnglesUI.DomNode The DOM tree root
--- @param flatRules AnglesUI._FlatRule[] Flattened stylesheet rules
--- @param variableResolver AnglesUI.CssVariableResolver?
--- @param hoverSet table<any, boolean>?
--- @param hostElement AnglesUI.DomNode?
--- @param mediaEvaluator fun(prelude: string): boolean?
--- @param containerEvaluator fun(prelude: string, node: AnglesUI.DomNode): boolean?
function CssCascade.ApplyToTree(root, flatRules, variableResolver, hoverSet, hostElement, mediaEvaluator, containerEvaluator)
    -- Clear proxy cache for this pass
    proxyCache = setmetatable({}, { __mode = "k" })

    root:Walk(function(node)
        if node.kind ~= "Element" then return false end

        -- Collect variables from matched rules for this node's scope
        local scopedResolver = variableResolver
        local matched = CssCascade.MatchRules(flatRules, node, hoverSet, hostElement, mediaEvaluator, containerEvaluator)
        node.matchedRules = matched
        node.computedStyles = CssCascade.ComputeStyles(matched, scopedResolver)

        -- Detect container status
        local containerType = node.computedStyles["container-type"]
        node.isContainer = (containerType == "size")
        node.containerName = node.computedStyles["container-name"]
        if node.containerName and #node.containerName == 0 then
            node.containerName = nil
        end

        return false -- continue walking
    end)
end

--- Second-pass cascade: re-evaluate only @container rules and merge any
--- matching declarations over already-computed styles.
---
--- Must be called AFTER `BoxModel.LayoutTree` so that `layoutData` is
--- populated and the ContainerQueryEvaluator can read real pixel dimensions.
---
--- @param root AnglesUI.DomNode The DOM tree root
--- @param containerFlatRules AnglesUI._FlatRule[] Only the @container flat rules
--- @param variableResolver AnglesUI.CssVariableResolver?
--- @param hoverSet table<any, boolean>?
--- @param hostElement AnglesUI.DomNode?
--- @param containerEvaluator fun(prelude: string, node: AnglesUI.DomNode): boolean?
function CssCascade.ApplyContainerRules(root, containerFlatRules, variableResolver, hoverSet, hostElement, containerEvaluator)
    if not containerFlatRules or #containerFlatRules == 0 then return end

    root:Walk(function(node)
        if node.kind ~= "Element" then return false end

        local matched = CssCascade.MatchRules(
            containerFlatRules, node, hoverSet, hostElement,
            nil, -- no media evaluator needed — these are container rules only
            containerEvaluator
        )
        if #matched > 0 then
            -- Merge container rule styles over existing computed styles (higher
            -- specificity wins the same way as in the normal cascade).
            local containerStyles = CssCascade.ComputeStyles(matched, variableResolver)
            for prop, val in pairs(containerStyles) do
                node.computedStyles[prop] = val
            end
        end

        return false -- continue walking
    end)
end

return CssCascade
