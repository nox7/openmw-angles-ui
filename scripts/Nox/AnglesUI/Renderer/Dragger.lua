--- AnglesUI Dragger Attribute Implementation.
--- Implements the `Dragger="true"` attribute: when a user drags the element
--- that has this attribute, the root mw-root element moves with the cursor.
---
--- Works by registering mousePress / mouseMove / mouseRelease events on the
--- dragger element that track drag state and update the root element's position.
---
--- Uses a full-screen transparent drag-capture overlay created on mousePress and
--- destroyed on mouseRelease so that mouseMove events continue to fire even when
--- the cursor leaves the dragger element boundary during the drag.

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
---
--- A full-screen transparent drag-capture overlay is created on mousePress
--- and destroyed on mouseRelease so that mouseMove events keep firing even
--- when the cursor leaves the dragger element boundary.
---
--- @param draggerNode AnglesUI.DomNode The node with Dragger="true"
--- @param rootNode AnglesUI.DomNode The mw-root DomNode
--- @param rootElement table Shared reference table; .element is set to the live OpenMW UI element after UI.create()
--- @param util table The OpenMW util library
--- @param ui table The OpenMW ui library (for creating the drag-capture overlay)
--- @param async table The OpenMW async library (for wrapping overlay event callbacks)
--- @param layerName string The layer the root element lives on (used for the overlay)
--- @param onUpdate fun(x:number,y:number)|nil Called on every drag move (persists position override)
--- @return table<string, fun(event1: any, layout: any)> callbacks
function Dragger.BuildCallbacks(draggerNode, rootNode, rootElement, util, ui, async, layerName, onUpdate)
    --- @type AnglesUI.DragState
    local dragState = {
        isDragging = false,
        startMouseX = 0,
        startMouseY = 0,
        startRootX = 0,
        startRootY = 0,
    }

    --- Full-screen overlay element active during a drag; nil otherwise.
    local captureOverlay = nil

    ---------------------------------------------------------------------------
    -- Shared move/release logic
    ---------------------------------------------------------------------------

    local function applyDrag(mouseEvent)
        if not dragState.isDragging then return end
        if not mouseEvent then return end

        local deltaX = mouseEvent.position.x - dragState.startMouseX
        local deltaY = mouseEvent.position.y - dragState.startMouseY

        local newX = dragState.startRootX + deltaX
        local newY = dragState.startRootY + deltaY

        -- Update root layout data
        rootNode.layoutData.x = newX
        rootNode.layoutData.y = newY

        -- Persist override so subsequent re-renders use the correct position
        if onUpdate then
            onUpdate(newX, newY)
        end

        local el = rootElement.element
        if el then
            el.layout.props.position = util.vector2(newX, newY)
            el:update()
        end
    end

    local function endDrag()
        dragState.isDragging = false
        if captureOverlay then
            captureOverlay:destroy()
            captureOverlay = nil
        end
    end

    ---------------------------------------------------------------------------
    -- Callbacks registered on the dragger node
    ---------------------------------------------------------------------------

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

            -- Create a full-screen transparent overlay to capture mouse events
            -- during the drag even when the cursor leaves the dragger element bounds.
            if ui and async and layerName then
                captureOverlay = ui.create({
                    layer = layerName,
                    props = {
                        position = util.vector2(0, 0),
                        -- Large enough to cover any screen resolution.
                        size = util.vector2(9999, 9999),
                        alpha = 0,
                    },
                    events = {
                        mouseMove    = async:callback(function(e, _) applyDrag(e) end),
                        mouseRelease = async:callback(function(_, _) endDrag() end),
                    },
                })
            end
        end
    end

    -- These fire when the cursor stays within the dragger element boundary.
    -- The overlay handles the out-of-bounds case.
    callbacks.mouseMove = function(mouseEvent, layout)
        applyDrag(mouseEvent)
    end

    callbacks.mouseRelease = function(mouseEvent, layout)
        endDrag()
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

