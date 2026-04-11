--- AnglesUI Runtime Initialization.
--- Provides a single entry point to execute all runtime evaluation passes
--- on a DOM tree in the correct order:
---   1. Directive evaluation (@if, @for) — expands/collapses nodes
---   2. Output directive resolution ({{ expr }}) — evaluates to text
---   3. Attribute binding — resolves [prop], [style.x], [attr.x]
---   4. Event binding — collects (event)="handler()" callbacks
---
--- The RuntimeInit module does NOT perform layout or transpilation.
--- It prepares the DOM tree so that the layout engine and transpiler
--- can work with fully resolved, concrete nodes.

local DirectiveEvaluator = require("scripts.Nox.AnglesUI.Runtime.DirectiveEvaluator")
local OutputDirective    = require("scripts.Nox.AnglesUI.Runtime.OutputDirective")
local AttributeBinding   = require("scripts.Nox.AnglesUI.Runtime.AttributeBinding")
local EventBinding       = require("scripts.Nox.AnglesUI.Runtime.EventBinding")
local DomNode            = require("scripts.Nox.AnglesUI.DOM.DomNode")

local DomNodeKind = DomNode.DomNodeKind

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

--- @class AnglesUI.RuntimeInit
local RuntimeInit = {}

---------------------------------------------------------------------------
-- Full runtime evaluation pass
---------------------------------------------------------------------------

--- Execute all runtime passes on a DOM tree in the correct order.
--- After this call, the DOM tree contains only concrete nodes with
--- resolved attribute values, style bindings, and collected event maps.
---
--- @param root AnglesUI.DomNode The root of the DOM tree
--- @param context table<string, any> The evaluation scope (user data + signals)
--- @return table<AnglesUI.DomNode, table<string, fun(event1: any, layout: any)>> eventMaps
---         A mapping from each DomNode to its merged event callback map.
function RuntimeInit.Evaluate(root, context)
    -- 1. Expand directives (@if, @for)
    DirectiveEvaluator.Evaluate(root, context)

    -- 2. Resolve output directives ({{ expression }})
    OutputDirective.ResolveTree(root, context)

    -- 3. Apply attribute and style bindings, collect event maps
    --- @type table<AnglesUI.DomNode, table<string, fun(event1: any, layout: any)>>
    local eventMaps = {}

    root:Walk(function(node)
        if node.kind == DomNodeKind.Element then
            -- Apply style bindings into computedStyles
            AttributeBinding.ApplyStyleBindings(node, context)

            -- Apply attr bindings into node metadata
            AttributeBinding.ApplyAttrBindings(node, context)

            -- Build event callback map
            local cbMap = EventBinding.BuildCallbackMap(node, context)
            if next(cbMap) then
                eventMaps[node] = cbMap
            end
        end
        return false -- continue walking
    end)

    return eventMaps
end

---------------------------------------------------------------------------
-- Re-exports for convenience
---------------------------------------------------------------------------

RuntimeInit.DirectiveEvaluator = DirectiveEvaluator
RuntimeInit.OutputDirective    = OutputDirective
RuntimeInit.AttributeBinding   = AttributeBinding
RuntimeInit.EventBinding       = EventBinding

return RuntimeInit
