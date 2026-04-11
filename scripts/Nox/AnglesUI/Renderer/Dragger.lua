--- AnglesUI Dragger Attribute Implementation.
--- Implements the `Dragger="true"` attribute: when a user drags the element
--- that has this attribute, the root mw-root element moves with the cursor.
---
--- Works by registering mousePress / mouseMove / mouseRelease events on the
--- dragger element that track drag state and update the root element's position.

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

--- @class AnglesUI.Dragger
local Dragger = {}

---------------------------------------------------------------------------
-- Types
---------------------------------------------------------------------------

--- @class AnglesUI.DragState
--- @field isDragging boolean
--- @field startMouseX number
--- @field startMouseY number
--- @field startRootX number
--- @field startRootY number

---------------------------------------------------------------------------
-- Build drag callbacks
---------------------------------------------------------------------------

--- Build event callbacks that implement dragging for a node.
--- When the user presses and drags this node, the root element moves.
--- @param draggerNode AnglesUI.DomNode The node with Dragger="true"
--- @param rootNode AnglesUI.DomNode The mw-root DomNode
--- @param rootElement table|nil Reference to the OpenMW UI element (set after creation)
--- @param util table The OpenMW util library
--- @return table<string, fun(event1: any, layout: any)> callbacks
function Dragger.BuildCallbacks(draggerNode, rootNode, rootElement, util)
    --- @type AnglesUI.DragState
    local dragState = {
        isDragging = false,
        startMouseX = 0,
        startMouseY = 0,
        startRootX = 0,
        startRootY = 0,
    }

    local callbacks = {}

    callbacks.mousePress = function(mouseEvent, layout)
        if mouseEvent and mouseEvent.button == 1 then
            dragState.isDragging = true
            dragState.startMouseX = mouseEvent.position.x
            dragState.startMouseY = mouseEvent.position.y

            -- Get current root position from its layout data
            local rootLd = rootNode.layoutData
            dragState.startRootX = rootLd.x or 0
            dragState.startRootY = rootLd.y or 0
        end
    end

    callbacks.mouseMove = function(mouseEvent, layout)
        if not dragState.isDragging then return end
        if not mouseEvent then return end

        local deltaX = mouseEvent.position.x - dragState.startMouseX
        local deltaY = mouseEvent.position.y - dragState.startMouseY

        local newX = dragState.startRootX + deltaX
        local newY = dragState.startRootY + deltaY

        -- Update root layout data
        rootNode.layoutData.x = newX
        rootNode.layoutData.y = newY

        -- Update the OpenMW element if available
        if rootElement and rootElement.layout then
            rootElement.layout.props.position = util.vector2(newX, newY)
            rootElement:update()
        end
    end

    callbacks.mouseRelease = function(mouseEvent, layout)
        dragState.isDragging = false
    end

    return callbacks
end

--- Check if a DomNode has the Dragger attribute set to "true".
--- @param node AnglesUI.DomNode
--- @return boolean
---@nodiscard
function Dragger.HasDragger(node)
    local attr = node.attributes["Dragger"]
    return attr ~= nil and attr.value == "true"
end

return Dragger
