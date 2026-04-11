--- AnglesUI Resizable Attribute Implementation.
--- Implements the `Resizable="true"` attribute on mw-root: when the user
--- clicks within the EdgeMargin threshold of the root element and drags,
--- the root element resizes accordingly.
---
--- Detects 8 resize zones: top, bottom, left, right, and 4 corners.
--- Each zone triggers a different resize behaviour (horizontal, vertical, or both).

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

--- @class AnglesUI.Resizable
local Resizable = {}

---------------------------------------------------------------------------
-- Types
---------------------------------------------------------------------------

--- @alias AnglesUI.ResizeZone "none"|"top"|"bottom"|"left"|"right"|"top-left"|"top-right"|"bottom-left"|"bottom-right"

--- @class AnglesUI.ResizeState
--- @field isResizing boolean
--- @field zone AnglesUI.ResizeZone
--- @field startMouseX number
--- @field startMouseY number
--- @field startWidth number
--- @field startHeight number
--- @field startX number
--- @field startY number

---------------------------------------------------------------------------
-- Zone detection
---------------------------------------------------------------------------

--- Determine the resize zone based on mouse offset within the root element.
--- @param offsetX number Mouse X relative to the root element
--- @param offsetY number Mouse Y relative to the root element
--- @param width number Root element width
--- @param height number Root element height
--- @param edgeMargin number Edge margin in pixels
--- @return AnglesUI.ResizeZone
local function detectZone(offsetX, offsetY, width, height, edgeMargin)
    local isTop    = offsetY <= edgeMargin
    local isBottom = offsetY >= (height - edgeMargin)
    local isLeft   = offsetX <= edgeMargin
    local isRight  = offsetX >= (width - edgeMargin)

    if isTop and isLeft then return "top-left" end
    if isTop and isRight then return "top-right" end
    if isBottom and isLeft then return "bottom-left" end
    if isBottom and isRight then return "bottom-right" end
    if isTop then return "top" end
    if isBottom then return "bottom" end
    if isLeft then return "left" end
    if isRight then return "right" end

    return "none"
end

---------------------------------------------------------------------------
-- Build resize callbacks
---------------------------------------------------------------------------

--- Build event callbacks that implement resizing on the root element.
--- @param rootNode AnglesUI.DomNode The mw-root DomNode
--- @param edgeMargin number Edge margin in pixels for resize detection
--- @param rootElement table|nil Reference to the OpenMW UI element (set after creation)
--- @param util table The OpenMW util library
--- @return table<string, fun(event1: any, layout: any)> callbacks
function Resizable.BuildCallbacks(rootNode, edgeMargin, rootElement, util)
    --- @type AnglesUI.ResizeState
    local resizeState = {
        isResizing = false,
        zone = "none",
        startMouseX = 0,
        startMouseY = 0,
        startWidth = 0,
        startHeight = 0,
        startX = 0,
        startY = 0,
    }

    local callbacks = {}

    callbacks.mousePress = function(mouseEvent, layout)
        if not mouseEvent or mouseEvent.button ~= 1 then return end

        local ld = rootNode.layoutData
        local zone = detectZone(
            mouseEvent.offset.x, mouseEvent.offset.y,
            ld.width or 0, ld.height or 0,
            edgeMargin
        )

        if zone ~= "none" then
            resizeState.isResizing = true
            resizeState.zone = zone
            resizeState.startMouseX = mouseEvent.position.x
            resizeState.startMouseY = mouseEvent.position.y
            resizeState.startWidth = ld.width or 0
            resizeState.startHeight = ld.height or 0
            resizeState.startX = ld.x or 0
            resizeState.startY = ld.y or 0
        end
    end

    callbacks.mouseMove = function(mouseEvent, layout)
        if not resizeState.isResizing then return end
        if not mouseEvent then return end

        local deltaX = mouseEvent.position.x - resizeState.startMouseX
        local deltaY = mouseEvent.position.y - resizeState.startMouseY
        local zone = resizeState.zone

        local newX = resizeState.startX
        local newY = resizeState.startY
        local newW = resizeState.startWidth
        local newH = resizeState.startHeight

        -- Horizontal resize
        if zone == "right" or zone == "top-right" or zone == "bottom-right" then
            newW = math.max(edgeMargin * 2, resizeState.startWidth + deltaX)
        elseif zone == "left" or zone == "top-left" or zone == "bottom-left" then
            local maxDelta = resizeState.startWidth - edgeMargin * 2
            local clampedDelta = math.min(deltaX, maxDelta)
            newX = resizeState.startX + clampedDelta
            newW = resizeState.startWidth - clampedDelta
        end

        -- Vertical resize
        if zone == "bottom" or zone == "bottom-left" or zone == "bottom-right" then
            newH = math.max(edgeMargin * 2, resizeState.startHeight + deltaY)
        elseif zone == "top" or zone == "top-left" or zone == "top-right" then
            local maxDelta = resizeState.startHeight - edgeMargin * 2
            local clampedDelta = math.min(deltaY, maxDelta)
            newY = resizeState.startY + clampedDelta
            newH = resizeState.startHeight - clampedDelta
        end

        -- Update root layout data
        local ld = rootNode.layoutData
        ld.x = newX
        ld.y = newY
        ld.width = newW
        ld.height = newH

        -- Update the OpenMW element
        if rootElement and rootElement.layout then
            rootElement.layout.props.position = util.vector2(newX, newY)
            rootElement.layout.props.size = util.vector2(newW, newH)
            rootElement:update()
        end
    end

    callbacks.mouseRelease = function(mouseEvent, layout)
        resizeState.isResizing = false
        resizeState.zone = "none"
    end

    return callbacks
end

--- Check if a DomNode has Resizable="true".
--- @param node AnglesUI.DomNode
--- @return boolean
function Resizable.IsResizable(node)
    local attr = node.attributes["Resizable"]
    return attr ~= nil and attr.value == "true"
end

--- Get the EdgeMargin value from a DomNode.
--- @param node AnglesUI.DomNode
--- @return number edgeMargin in pixels
function Resizable.GetEdgeMargin(node)
    local attr = node.attributes["EdgeMargin"]
    if not attr or not attr.value then
        error("AnglesUI: Resizable='true' requires an EdgeMargin attribute on <mw-root>", 0)
    end
    local px = attr.value:match("^(%d+)px$")
    if px then return tonumber(px) end
    local num = tonumber(attr.value)
    if num then return num end
    error("AnglesUI: EdgeMargin must be a pixel value (e.g. '10px'), got: " .. tostring(attr.value), 0)
end

return Resizable
