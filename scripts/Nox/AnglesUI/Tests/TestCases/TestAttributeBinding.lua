--- AnglesUI Test Suite — Attribute Binding
--- Tests for resolving static, binding, style-binding, and attr-binding
--- attributes against an evaluation context.

package.path = "?.lua;scripts/Nox/AnglesUI/?.lua;scripts/Nox/AnglesUI/Tests/?.lua;scripts/Nox/AnglesUI/Runtime/?.lua;scripts/Nox/AnglesUI/Parser/?.lua;scripts/Nox/AnglesUI/Parser/HTML/?.lua;scripts/Nox/AnglesUI/DOM/?.lua;scripts/Nox/AnglesUI/Parser/CSS/?.lua;" .. package.path

local lu = require("luaunit")
local HtmlNodes        = require("HtmlNodes")
local DomNode          = require("DomNode")
local AttributeBinding = require("AttributeBinding")

local AttributeType = HtmlNodes.AttributeType

--- Helper: create element DomNode with specific attributes.
local function makeEl(tag, rawAttrs)
    local html = HtmlNodes.CreateElement(tag, 0, 0)
    if rawAttrs then
        for _, a in ipairs(rawAttrs) do
            html.attributes[#html.attributes + 1] = a
        end
    end
    return DomNode.FromElement(html, nil, 0)
end

--- Shorthand for attribute creation.
local function attr(aType, name, value, property)
    return HtmlNodes.CreateAttribute(aType, name, value, property)
end

---------------------------------------------------------------------------
-- TestResolveOne
---------------------------------------------------------------------------
TestResolveOne = {}

function TestResolveOne:testStaticAttribute()
    local a = attr("Static", "Layer", "Windows")
    local name, val = AttributeBinding.ResolveOne(a, {})
    lu.assertEquals(name, "Layer")
    lu.assertEquals(val, "Windows")
end

function TestResolveOne:testBindingTrue()
    local a = attr("Binding", "Resource", "path", nil)
    a.value = "'textures/icon.dds'"
    local name, val = AttributeBinding.ResolveOne(a, {})
    lu.assertEquals(name, "Resource")
    lu.assertEquals(val, "textures/icon.dds")
end

function TestResolveOne:testBindingNilReturnsNil()
    local a = attr("Binding", "Resource", "x", nil)
    local name, val = AttributeBinding.ResolveOne(a, {})
    lu.assertNil(name)
    lu.assertNil(val)
end

function TestResolveOne:testBindingFalseReturnsNil()
    local a = attr("Binding", "Visible", "false", nil)
    local name, val = AttributeBinding.ResolveOne(a, {})
    lu.assertNil(name)
end

function TestResolveOne:testStyleBinding()
    local a = attr("StyleBinding", "style", "'200px'", "width")
    local name, val = AttributeBinding.ResolveOne(a, {})
    lu.assertEquals(name, "width")
    lu.assertEquals(val, "200px")
end

function TestResolveOne:testStyleBindingFalse()
    local a = attr("StyleBinding", "style", "false", "width")
    local name, val = AttributeBinding.ResolveOne(a, {})
    lu.assertNil(name)
end

function TestResolveOne:testAttrBinding()
    local a = attr("AttrBinding", "attr", "'main'", "id")
    local name, val = AttributeBinding.ResolveOne(a, {})
    lu.assertEquals(name, "id")
    lu.assertEquals(val, "main")
end

function TestResolveOne:testAttrBindingNil()
    local a = attr("AttrBinding", "attr", "nil", "id")
    local name, val = AttributeBinding.ResolveOne(a, {})
    lu.assertNil(name)
end

function TestResolveOne:testEventReturnsNil()
    local a = attr("Event", "click", "DoStuff()")
    local name, val = AttributeBinding.ResolveOne(a, {})
    lu.assertNil(name)
end

---------------------------------------------------------------------------
-- TestResolveAll
---------------------------------------------------------------------------
TestResolveAll = {}

function TestResolveAll:testSegregatesTypes()
    local node = makeEl("mw-text", {
        attr("Static", "Layer", "Windows"),
        attr("StyleBinding", "style", "'red'", "color"),
        attr("AttrBinding", "attr", "'title'", "id"),
    })
    local result = AttributeBinding.ResolveAll(node, {})
    lu.assertEquals(result.props["Layer"], "Windows")
    lu.assertEquals(result.styles["color"], "red")
    lu.assertEquals(result.attrs["id"], "title")
end

function TestResolveAll:testSkipsEvents()
    local node = makeEl("mw-text", {
        attr("Event", "click", "DoStuff()"),
    })
    local result = AttributeBinding.ResolveAll(node, {})
    lu.assertEquals(next(result.props), nil)
    lu.assertEquals(next(result.styles), nil)
    lu.assertEquals(next(result.attrs), nil)
end

function TestResolveAll:testOmitsNilBindings()
    local node = makeEl("mw-text", {
        attr("Binding", "Resource", "nil"),
    })
    local result = AttributeBinding.ResolveAll(node, {})
    lu.assertNil(result.props["Resource"])
end

function TestResolveAll:testBindingWithContext()
    local node = makeEl("mw-text", {
        attr("Binding", "Resource", "icon"),
    })
    local result = AttributeBinding.ResolveAll(node, { icon = "textures/a.dds" })
    lu.assertEquals(result.props["Resource"], "textures/a.dds")
end

---------------------------------------------------------------------------
-- TestApplyStyleBindings
---------------------------------------------------------------------------
TestApplyStyleBindings = {}

function TestApplyStyleBindings:testOverridesComputedStyle()
    local node = makeEl("mw-text", {
        attr("StyleBinding", "style", "'20px'", "font-size"),
    })
    node.computedStyles["font-size"] = "16px"
    AttributeBinding.ApplyStyleBindings(node, {})
    lu.assertEquals(node.computedStyles["font-size"], "20px")
end

function TestApplyStyleBindings:testRemovesOnFalse()
    local node = makeEl("mw-text", {
        attr("StyleBinding", "style", "false", "color"),
    })
    node.computedStyles["color"] = "red"
    AttributeBinding.ApplyStyleBindings(node, {})
    lu.assertNil(node.computedStyles["color"])
end

---------------------------------------------------------------------------
-- TestApplyAttrBindings
---------------------------------------------------------------------------
TestApplyAttrBindings = {}

function TestApplyAttrBindings:testSetsId()
    local node = makeEl("mw-text", {
        attr("AttrBinding", "attr", "'header'", "id"),
    })
    AttributeBinding.ApplyAttrBindings(node, {})
    lu.assertEquals(node.id, "header")
end

function TestApplyAttrBindings:testMergesClasses()
    local node = makeEl("mw-flex", {
        attr("Static", "class", "base"),
        attr("AttrBinding", "attr", "'extra bonus'", "class"),
    })
    AttributeBinding.ApplyAttrBindings(node, {})
    lu.assertTrue(node.classes["extra"])
    lu.assertTrue(node.classes["bonus"])
end

function TestApplyAttrBindings:testClearsIdOnFalse()
    local node = makeEl("mw-text", {
        attr("AttrBinding", "attr", "false", "id"),
    })
    node.id = "old"
    AttributeBinding.ApplyAttrBindings(node, {})
    lu.assertNil(node.id)
end

function TestApplyAttrBindings:testGenericAttrStored()
    local node = makeEl("mw-text", {
        attr("AttrBinding", "attr", "'yes'", "Dragger"),
    })
    AttributeBinding.ApplyAttrBindings(node, {})
    lu.assertNotNil(node.attributes["Dragger"])
    lu.assertEquals(node.attributes["Dragger"].value, "yes")
end

---------------------------------------------------------------------------
-- Run
---------------------------------------------------------------------------
lu.run()
