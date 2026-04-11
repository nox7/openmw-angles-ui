--- AnglesUI Layout Initialiser.
--- Wires up the circular dependencies between BoxModel, FlexLayout,
--- GridLayout, and ScrollCanvas by injecting delegate functions.
--- Require this module once during renderer startup.

local BoxModel     = require("scripts.Nox.AnglesUI.Renderer.BoxModel")
local FlexLayout   = require("scripts.Nox.AnglesUI.Renderer.FlexLayout")
local GridLayout   = require("scripts.Nox.AnglesUI.Renderer.GridLayout")
local ScrollCanvas = require("scripts.Nox.AnglesUI.Renderer.ScrollCanvas")

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

--- @class AnglesUI.LayoutInit
local LayoutInit = {}

--- @type boolean
local initialised = false

--- Initialise all layout module cross-references.
--- Safe to call multiple times; only runs once.
function LayoutInit.Init()
    if initialised then return end
    initialised = true

    -- FlexLayout and GridLayout need to call BoxModel.Layout for child sizing
    FlexLayout.SetBoxModelLayout(BoxModel.Layout)
    GridLayout.SetBoxModelLayout(BoxModel.Layout)
    ScrollCanvas.SetBoxModelLayout(BoxModel.Layout)

    -- BoxModel needs to delegate to FlexLayout, GridLayout, and ScrollCanvas
    BoxModel.SetDelegates(FlexLayout.Layout, GridLayout.Layout, ScrollCanvas.Layout)
end

--- Expose all layout modules for convenience.
LayoutInit.BoxModel     = BoxModel
LayoutInit.FlexLayout   = FlexLayout
LayoutInit.GridLayout   = GridLayout
LayoutInit.ScrollCanvas = ScrollCanvas

return LayoutInit
