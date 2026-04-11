--- AnglesUI Attribute Binding Runtime.
--- Resolves attribute bindings on DomNodes:
---   - `[prop]="expr"` — standard property binding
---   - `[style.x]="expr"` — style binding (nil/false → omit)
---   - `[attr.x]="expr"` — attribute binding (nil/false → omit)
--- Static attributes are also resolved and cached.

local ExpressionEvaluator = require("scripts.Nox.AnglesUI.Parser.ExpressionEvaluator")
local HtmlNodes           = require("scripts.Nox.AnglesUI.Parser.HTML.HtmlNodes")

local AttributeType = HtmlNodes.AttributeType

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

--- @class AnglesUI.AttributeBinding
local AttributeBinding = {}

---------------------------------------------------------------------------
-- Resolve a single attribute
---------------------------------------------------------------------------

--- Evaluate a single attribute against the given context.
--- Returns the resolved name and value, or nil if the binding evaluates
--- to nil/false (indicating the attribute should not be applied).
--- @param attr AnglesUI.Attribute
--- @param context table<string, any>
--- @return string? resolvedName
--- @return any resolvedValue
function AttributeBinding.ResolveOne(attr, context)
    if attr.type == AttributeType.Static then
        return attr.name, attr.value

    elseif attr.type == AttributeType.Binding then
        -- [prop]="expr"
        local value = ExpressionEvaluator.Evaluate(attr.value, context)
        if value == nil or value == false then
            return nil, nil
        end
        return attr.name, value

    elseif attr.type == AttributeType.StyleBinding then
        -- [style.cssProperty]="expr"
        local value = ExpressionEvaluator.Evaluate(attr.value, context)
        if value == nil or value == false then
            return nil, nil
        end
        return attr.property, value

    elseif attr.type == AttributeType.AttrBinding then
        -- [attr.attrName]="expr"
        local value = ExpressionEvaluator.Evaluate(attr.value, context)
        if value == nil or value == false then
            return nil, nil
        end
        return attr.property, value

    end
    -- Event bindings are handled separately
    return nil, nil
end

---------------------------------------------------------------------------
-- Resolve all bindings on a DomNode
---------------------------------------------------------------------------

--- @class AnglesUI.ResolvedAttributes
--- @field props table<string, any>  Standard property bindings + static attrs
--- @field styles table<string, string>  Style bindings (cssProperty → value)
--- @field attrs table<string, any>  Attribute bindings

--- Resolve all attribute bindings on a DomNode for the given context.
--- Static attributes are included in props. Style and attr bindings are
--- segregated into their own tables.
--- @param domNode AnglesUI.DomNode
--- @param context table<string, any>
--- @return AnglesUI.ResolvedAttributes
function AttributeBinding.ResolveAll(domNode, context)
    --- @type AnglesUI.ResolvedAttributes
    local result = {
        props = {},
        styles = {},
        attrs = {},
    }

    local htmlNode = domNode.htmlNode
    if not htmlNode or not htmlNode.attributes then
        return result
    end

    --- @type AnglesUI.Attribute[]
    local attributes = htmlNode.attributes

    for i = 1, #attributes do
        local attr = attributes[i]

        if attr.type == AttributeType.Event then
            -- Handled by EventBinding module
        elseif attr.type == AttributeType.StyleBinding then
            local name, value = AttributeBinding.ResolveOne(attr, context)
            if name then
                result.styles[name] = tostring(value)
            end
        elseif attr.type == AttributeType.AttrBinding then
            local name, value = AttributeBinding.ResolveOne(attr, context)
            if name then
                result.attrs[name] = value
            end
        else
            -- Static or standard Binding → props
            local name, value = AttributeBinding.ResolveOne(attr, context)
            if name then
                result.props[name] = value
            end
        end
    end

    return result
end

---------------------------------------------------------------------------
-- Apply style bindings into computed styles
---------------------------------------------------------------------------

--- Merge style bindings into a node's computedStyles table.
--- Style bindings override cascade-computed styles.
--- @param domNode AnglesUI.DomNode
--- @param context table<string, any>
function AttributeBinding.ApplyStyleBindings(domNode, context)
    local htmlNode = domNode.htmlNode
    if not htmlNode or not htmlNode.attributes then
        return
    end

    --- @type AnglesUI.Attribute[]
    local attributes = htmlNode.attributes

    for i = 1, #attributes do
        local attr = attributes[i]
        if attr.type == AttributeType.StyleBinding then
            local value = ExpressionEvaluator.Evaluate(attr.value, context)
            if value ~= nil and value ~= false then
                domNode.computedStyles[attr.property] = tostring(value)
            else
                -- Remove the style if binding is nil/false
                domNode.computedStyles[attr.property] = nil
            end
        end
    end
end

---------------------------------------------------------------------------
-- Apply attribute bindings into node attributes
---------------------------------------------------------------------------

--- Merge attribute bindings into a node's cached id / classes / attributes.
--- @param domNode AnglesUI.DomNode
--- @param context table<string, any>
function AttributeBinding.ApplyAttrBindings(domNode, context)
    local htmlNode = domNode.htmlNode
    if not htmlNode or not htmlNode.attributes then
        return
    end

    --- @type AnglesUI.Attribute[]
    local attributes = htmlNode.attributes

    for i = 1, #attributes do
        local attr = attributes[i]
        if attr.type == AttributeType.AttrBinding then
            local value = ExpressionEvaluator.Evaluate(attr.value, context)
            if value ~= nil and value ~= false then
                local propName = attr.property
                if propName == "id" then
                    domNode.id = tostring(value)
                elseif propName == "class" then
                    -- Merge additional classes
                    for cls in tostring(value):gmatch("%S+") do
                        domNode.classes[cls] = true
                    end
                else
                    -- Store as generic attribute
                    domNode.attributes[propName] = {
                        type = AttributeType.Static,
                        name = propName,
                        value = tostring(value),
                    }
                end
            else
                local propName = attr.property
                if propName == "id" then
                    domNode.id = nil
                elseif propName == "class" then
                    -- Can't selectively remove; binding false clears bound classes
                end
            end
        end
    end
end

return AttributeBinding
