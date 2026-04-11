--- AnglesUI Scroll Canvas Layout & Widget Generation.
--- Implements the mw-scroll-canvas element: a scrollable viewport with
--- horizontal and vertical scrollbars featuring arrow buttons and a
--- draggable thumb. All scrollbar interaction (arrow click, thumb drag)
--- is handled through OpenMW UI events.
---
--- This module produces two things:
---   1) Layout data for the scroll canvas box model (viewport + scrollbars)
---   2) A scrollbar descriptor table consumed by the transpiler to generate
---      the OpenMW widget tree for scroll bars.

local LayoutUtils = require("scripts.Nox.AnglesUI.Renderer.LayoutUtils")

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------

local SCROLL_THUMB_TEXTURE = "textures/omw_menu_scroll_center_v.dds"
local ARROW_UP_TEXTURE     = "textures/omw_menu_scroll_up.dds"
local ARROW_DOWN_TEXTURE   = "textures/omw_menu_scroll_down.dds"
local ARROW_LEFT_TEXTURE   = "textures/omw_menu_scroll_left.dds"
local ARROW_RIGHT_TEXTURE  = "textures/omw_menu_scroll_right.dds"

--- Pixels scrolled per arrow click per frame.
local SCROLL_INCREMENT = 20

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

--- @class AnglesUI.ScrollCanvas
local ScrollCanvas = {}

--- @type fun(node: AnglesUI.DomNode, availableWidth: number, availableHeight: number)
local boxModelLayout

--- Inject the BoxModel.Layout function to avoid circular requires.
--- @param layoutFn fun(node: AnglesUI.DomNode, availableWidth: number, availableHeight: number)
function ScrollCanvas.SetBoxModelLayout(layoutFn)
    boxModelLayout = layoutFn
end

---------------------------------------------------------------------------
-- Scroll state
---------------------------------------------------------------------------

--- @class AnglesUI.ScrollState
--- @field scrollX number Current horizontal scroll offset (pixels)
--- @field scrollY number Current vertical scroll offset (pixels)
--- @field contentWidth number Total content width (may exceed viewport)
--- @field contentHeight number Total content height (may exceed viewport)
--- @field viewportWidth number Visible viewport width
--- @field viewportHeight number Visible viewport height
--- @field scrollbarWidth number Width of scrollbar in pixels
--- @field needsHScroll boolean Whether horizontal scrollbar is needed
--- @field needsVScroll boolean Whether vertical scrollbar is needed

--- Create a new scroll state.
--- @return AnglesUI.ScrollState
function ScrollCanvas.NewScrollState()
    return {
        scrollX = 0,
        scrollY = 0,
        contentWidth = 0,
        contentHeight = 0,
        viewportWidth = 0,
        viewportHeight = 0,
        scrollbarWidth = 13,
        needsHScroll = false,
        needsVScroll = false,
    }
end

---------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------

--- Perform scroll canvas layout. Lays out children in a free-form area,
--- measures their total bounds, then configures the viewport and scrollbars.
--- @param node AnglesUI.DomNode
--- @param availableWidth number
--- @param availableHeight number
function ScrollCanvas.Layout(node, availableWidth, availableHeight)
    local styles = node.computedStyles
    local ld = node.layoutData

    -- Scrollbar width
    local sbWidth = LayoutUtils.ResolveLength(
        LayoutUtils.GetStyle(styles, "scrollbar-width"),
        availableWidth
    )
    if sbWidth <= 0 then sbWidth = 13 end

    -- First pass: lay out children with unlimited space to find content bounds
    local LARGE = 100000
    for _, child in ipairs(node.children) do
        if child.kind == "Element" then
            boxModelLayout(child, LARGE, LARGE)
        end
    end

    -- Measure total content bounds
    local maxRight = 0
    local maxBottom = 0
    for _, child in ipairs(node.children) do
        local cld = child.layoutData
        if cld and not cld.isAbsolute then
            local r = (cld.x or 0) + (cld.width or 0) + (cld.marginRight or 0)
            local b = (cld.y or 0) + (cld.height or 0) + (cld.marginBottom or 0)
            if r > maxRight then maxRight = r end
            if b > maxBottom then maxBottom = b end
        end
    end

    -- Determine if scrollbars are needed
    local needsV = maxBottom > availableHeight
    local needsH = maxRight > availableWidth

    -- Adjust viewport for scrollbar sizes
    local viewW = availableWidth  - (needsV and sbWidth or 0)
    local viewH = availableHeight - (needsH and sbWidth or 0)

    -- Re-check after adjustment
    if not needsV and maxBottom > viewH then
        needsV = true
        viewW = availableWidth - sbWidth
    end
    if not needsH and maxRight > viewW then
        needsH = true
        viewH = availableHeight - sbWidth
    end

    viewW = math.max(0, viewW)
    viewH = math.max(0, viewH)

    -- Re-layout children with viewport dimensions for percentage-based sizes
    for _, child in ipairs(node.children) do
        if child.kind == "Element" then
            boxModelLayout(child, viewW, viewH)
        end
    end

    -- Re-measure content bounds after proper layout
    maxRight = 0
    maxBottom = 0
    for _, child in ipairs(node.children) do
        local cld = child.layoutData
        if cld and not cld.isAbsolute then
            local r = (cld.x or 0) + (cld.width or 0) + (cld.marginRight or 0)
            local b = (cld.y or 0) + (cld.height or 0) + (cld.marginBottom or 0)
            if r > maxRight then maxRight = r end
            if b > maxBottom then maxBottom = b end
        end
    end

    -- Flow-position children vertically within the viewport
    local offsetY = 0
    for _, child in ipairs(node.children) do
        if child.kind == "Element" then
            local cld = child.layoutData
            if cld and not cld.isAbsolute then
                cld.x = cld.marginLeft or 0
                cld.y = offsetY + (cld.marginTop or 0)
                offsetY = cld.y + (cld.height or 0) + (cld.marginBottom or 0)
            end
        end
    end

    -- Store scroll state on the node's layoutData for the transpiler
    local scrollState = ScrollCanvas.NewScrollState()
    scrollState.contentWidth  = math.max(maxRight, viewW)
    scrollState.contentHeight = math.max(maxBottom, viewH)
    scrollState.viewportWidth = viewW
    scrollState.viewportHeight = viewH
    scrollState.scrollbarWidth = sbWidth
    scrollState.needsHScroll = needsH
    scrollState.needsVScroll = needsV

    ld.scrollState = scrollState
    ld.contentWidth = viewW
    ld.contentHeight = viewH
end

---------------------------------------------------------------------------
-- Scrollbar descriptor (consumed by transpiler)
---------------------------------------------------------------------------

--- @class AnglesUI.ScrollbarDescriptor
--- @field orientation "horizontal"|"vertical"
--- @field trackX number Position of the scrollbar track
--- @field trackY number
--- @field trackWidth number
--- @field trackHeight number
--- @field arrowSize number Size of arrow buttons (square)
--- @field thumbTexture string
--- @field arrowStartTexture string
--- @field arrowEndTexture string
--- @field scrollbarWidth number

--- Generate scrollbar descriptors for a scroll canvas node.
--- @param scrollState AnglesUI.ScrollState
--- @param boxWidth number The outer box width of the scroll canvas
--- @param boxHeight number The outer box height
--- @return AnglesUI.ScrollbarDescriptor[] descriptors
function ScrollCanvas.BuildScrollbarDescriptors(scrollState, boxWidth, boxHeight)
    local descriptors = {}
    local sbW = scrollState.scrollbarWidth

    if scrollState.needsVScroll then
        local trackX = scrollState.viewportWidth
        local trackY = 0
        local trackW = sbW
        local trackH = scrollState.viewportHeight

        descriptors[#descriptors + 1] = {
            orientation = "vertical",
            trackX = trackX,
            trackY = trackY,
            trackWidth = trackW,
            trackHeight = trackH,
            arrowSize = sbW,
            thumbTexture = SCROLL_THUMB_TEXTURE,
            arrowStartTexture = ARROW_UP_TEXTURE,
            arrowEndTexture = ARROW_DOWN_TEXTURE,
            scrollbarWidth = sbW,
        }
    end

    if scrollState.needsHScroll then
        local trackX = 0
        local trackY = scrollState.viewportHeight
        local trackW = scrollState.viewportWidth
        local trackH = sbW

        descriptors[#descriptors + 1] = {
            orientation = "horizontal",
            trackX = trackX,
            trackY = trackY,
            trackWidth = trackW,
            trackHeight = trackH,
            arrowSize = sbW,
            thumbTexture = SCROLL_THUMB_TEXTURE,
            arrowStartTexture = ARROW_LEFT_TEXTURE,
            arrowEndTexture = ARROW_RIGHT_TEXTURE,
            scrollbarWidth = sbW,
        }
    end

    return descriptors
end

---------------------------------------------------------------------------
-- Scroll math helpers
---------------------------------------------------------------------------

--- Calculate the thumb size and position for a scrollbar.
--- @param viewportSize number Size of visible area
--- @param contentSize number Size of total content
--- @param scrollOffset number Current scroll offset
--- @param trackLength number Length of the scrollbar track (minus arrows)
--- @return number thumbSize Size of the thumb in pixels
--- @return number thumbPosition Position of the thumb from the track start
function ScrollCanvas.CalculateThumb(viewportSize, contentSize, scrollOffset, trackLength)
    if contentSize <= viewportSize or contentSize <= 0 then
        return trackLength, 0
    end

    local ratio = viewportSize / contentSize
    local thumbSize = math.max(20, trackLength * ratio)
    local scrollableRange = contentSize - viewportSize
    local thumbRange = trackLength - thumbSize

    local thumbPos = 0
    if scrollableRange > 0 then
        thumbPos = (scrollOffset / scrollableRange) * thumbRange
    end

    return thumbSize, thumbPos
end

--- Clamp a scroll offset to valid bounds.
--- @param offset number
--- @param viewportSize number
--- @param contentSize number
--- @return number
function ScrollCanvas.ClampScroll(offset, viewportSize, contentSize)
    local maxScroll = math.max(0, contentSize - viewportSize)
    return math.max(0, math.min(offset, maxScroll))
end

--- @type number
ScrollCanvas.SCROLL_INCREMENT = SCROLL_INCREMENT

return ScrollCanvas
