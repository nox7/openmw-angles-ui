--- AnglesUI DOM → OpenMW Lua UI Transpiler.
--- Converts the fully laid-out, resolved DOM tree into the nested table
--- structure expected by OpenMW's `UI.create()`.
---
--- The transpiler produces:
---   { layer, props, content, events, name }
--- …where `content` is `UI.content({…})` with nested layouts for children,
--- including synthesized widgets for borders, background images, scrollbars,
--- and text content.
---
--- This module does NOT call `UI.create()` itself — it builds the table
--- structure. The Renderer orchestrates creation and updates.

local LayoutUtils  = require("scripts.Nox.AnglesUI.Renderer.LayoutUtils")
local ScrollCanvas = require("scripts.Nox.AnglesUI.Renderer.ScrollCanvas")
local DomNode      = require("scripts.Nox.AnglesUI.DOM.DomNode")

local DomNodeKind = DomNode.DomNodeKind

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

--- @class AnglesUI.Transpiler
local Transpiler = {}

---------------------------------------------------------------------------
-- OpenMW library references (injected at init)
---------------------------------------------------------------------------

--- @type table OpenMW UI library
local UI

--- @type table OpenMW Util library
local Util

--- @type table OpenMW Async library
local Async

--- Shared reference to the live OpenMW element; set per Transpile call so that
--- scroll-canvas event callbacks (created during transpilation) can call
--- element:update() even though the element doesn't exist yet at that point.
--- @type { element: table }|nil
local currentElementRef

--- The layer name of the current mw-root, stored per Transpile call so that
--- scroll-canvas thumb-drag capture overlays can be created on the correct layer.
--- @type string
local currentLayerName = "Windows"

--- Shared reference to the Renderer's _scrollOffsets table so that applyScroll()
--- closures can persist the current scroll position across re-renders.
--- Keyed by scroll canvas node id (string) → { x: number, y: number }.
--- @type table<string, { x: number, y: number }>
local currentScrollOffsets = {}

--- Callback provided by the Renderer so that scroll updates can trigger a
--- lightweight re-render, replacing el.layout and calling el:update().
--- Needed because el:update() alone does not cascade into nested UI.content() trees.
--- @type (fun(): nil)|nil
local currentRerenderFn = nil

--- Inject OpenMW library references. Called once during renderer init.
--- @param ui table require("openmw.ui")
--- @param util table require("openmw.util")
--- @param async table require("openmw.async")
function Transpiler.Init(ui, util, async)
    UI    = ui
    Util  = util
    Async = async
end

---------------------------------------------------------------------------
-- Forward declarations
---------------------------------------------------------------------------

--- @type fun(node: AnglesUI.DomNode, eventMaps: table, context: table, hoverTracker: any): table
local transpileNode

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

--- Build an OpenMW props table from a DomNode's layout data and computed styles.
--- @param node AnglesUI.DomNode
--- @return table props
local function buildProps(node)
    local ld = node.layoutData
    local styles = node.computedStyles
    local props = {}

    -- Position and size
    props.position = Util.vector2(ld.x or 0, ld.y or 0)
    props.size = Util.vector2(ld.width or 0, ld.height or 0)

    -- Visibility
    local visibility = LayoutUtils.GetStyle(styles, "visibility")
    if visibility == "hidden" then
        props.visible = false
    end

    -- Opacity
    local opacity = tonumber(LayoutUtils.GetStyle(styles, "opacity"))
    if opacity and opacity < 1 then
        props.alpha = opacity
    end

    -- propagateEvents defaults to true in OpenMW; only set if node explicitly disables
    -- (We don't have a CSS/attr for this yet, but the infrastructure is here)

    return props
end

--- Build props for an image widget.
--- @param path string Texture path in VFS
--- @param x number
--- @param y number
--- @param w number
--- @param h number
--- @param tileH boolean
--- @param tileV boolean
--- @param alpha number|nil
--- @param colorR number|nil
--- @param colorG number|nil
--- @param colorB number|nil
--- @return table layout
local function buildImageLayout(path, x, y, w, h, tileH, tileV, alpha, colorR, colorG, colorB)
    local props = {
        position = Util.vector2(x, y),
        size     = Util.vector2(w, h),
        resource = UI.texture({ path = path }),
        tileH    = tileH or false,
        tileV    = tileV or false,
    }
    if alpha and alpha < 1 then
        props.alpha = alpha
    end
    if colorR then
        props.color = Util.color.rgb(colorR, colorG, colorB)
    end

    return {
        type  = UI.TYPE.Image,
        props = props,
    }
end

---------------------------------------------------------------------------
-- Border rendering
---------------------------------------------------------------------------

--- Build border widget layouts for a DomNode.
--- Borders are 8 separate image widgets placed around the content.
--- @param node AnglesUI.DomNode
--- @return table[] borderLayouts
local function buildBorderLayouts(node)
    local styles = node.computedStyles
    local ld = node.layoutData
    local layouts = {}
    local outerW = ld.width or 0
    local outerH = ld.height or 0

    local BORDER_SIDES = {
        { prop = "border-top-left-corner",     pos = "corner-tl" },
        { prop = "border-top",                 pos = "top" },
        { prop = "border-top-right-corner",    pos = "corner-tr" },
        { prop = "border-right",               pos = "right" },
        { prop = "border-bottom-right-corner", pos = "corner-br" },
        { prop = "border-bottom",              pos = "bottom" },
        { prop = "border-bottom-left-corner",  pos = "corner-bl" },
        { prop = "border-left",                pos = "left" },
    }

    local bTop    = ld.borderTop or 0
    local bRight  = ld.borderRight or 0
    local bBottom = ld.borderBottom or 0
    local bLeft   = ld.borderLeft or 0

    for _, side in ipairs(BORDER_SIDES) do
        local size, path, tH, tV = LayoutUtils.ParseBorderValue(styles[side.prop])
        if size and path then
            local x, y, w, h = 0, 0, 0, 0

            if side.pos == "corner-tl" then
                x, y = 0, 0
                w, h = bLeft, bTop
            elseif side.pos == "top" then
                x, y = bLeft, 0
                w, h = outerW - bLeft - bRight, bTop
            elseif side.pos == "corner-tr" then
                x, y = outerW - bRight, 0
                w, h = bRight, bTop
            elseif side.pos == "right" then
                x, y = outerW - bRight, bTop
                w, h = bRight, outerH - bTop - bBottom
            elseif side.pos == "corner-br" then
                x, y = outerW - bRight, outerH - bBottom
                w, h = bRight, bBottom
            elseif side.pos == "bottom" then
                x, y = bLeft, outerH - bBottom
                w, h = outerW - bLeft - bRight, bBottom
            elseif side.pos == "corner-bl" then
                x, y = 0, outerH - bBottom
                w, h = bLeft, bBottom
            elseif side.pos == "left" then
                x, y = 0, bTop
                w, h = bLeft, outerH - bTop - bBottom
            end

            if w > 0 and h > 0 then
                layouts[#layouts + 1] = buildImageLayout(path, x, y, w, h, tH, tV)
            end
        end
    end

    return layouts
end

---------------------------------------------------------------------------
-- Background image rendering
---------------------------------------------------------------------------

--- Build a background image widget layout for a DomNode.
--- @param node AnglesUI.DomNode
--- @return table|nil layout
local function buildBackgroundImageLayout(node)
    local styles = node.computedStyles
    local ld = node.layoutData

    local bgPath = LayoutUtils.ParseBackgroundImage(styles["background-image"])
    if not bgPath then return nil end

    local tileH, tileV = LayoutUtils.ParseBackgroundRepeat(
        LayoutUtils.GetStyle(styles, "background-repeat")
    )
    local bgOpacity = tonumber(LayoutUtils.GetStyle(styles, "background-image-opacity")) or 1

    -- Background fills the entire outer box
    local bTop    = ld.borderTop or 0
    local bRight  = ld.borderRight or 0
    local bBottom = ld.borderBottom or 0
    local bLeft   = ld.borderLeft or 0

    local bgX = bLeft
    local bgY = bTop
    local bgW = (ld.width or 0) - bLeft - bRight
    local bgH = (ld.height or 0) - bTop - bBottom

    if bgW <= 0 or bgH <= 0 then return nil end

    return buildImageLayout(bgPath, bgX, bgY, bgW, bgH, tileH, tileV, bgOpacity)
end

---------------------------------------------------------------------------
-- Text rendering
---------------------------------------------------------------------------

--- Build an OpenMW Text layout from an mw-text or mw-text-edit DomNode.
--- @param node AnglesUI.DomNode
--- @param collectedText string
--- @return table layout
local function buildTextLayout(node, collectedText)
    local styles = node.computedStyles
    local ld = node.layoutData
    local isTextEdit = (node.tag == "mw-text-edit")

    local fontSize = LayoutUtils.ParseNumber(LayoutUtils.GetStyle(styles, "font-size"))
    if fontSize <= 0 then fontSize = 16 end

    local r, g, b = LayoutUtils.ParseColor(styles["color"])

    local props = {
        position = Util.vector2(0, 0),
        size     = Util.vector2(ld.contentWidth or 0, ld.contentHeight or 0),
        text     = collectedText,
        textSize = fontSize,
    }

    if r then
        props.textColor = Util.color.rgb(r, g, b)
    end

    -- Text alignment
    local textAlignH = LayoutUtils.MapTextAlignH(styles["text-align"])
    local textAlignV = LayoutUtils.MapVerticalAlign(styles["vertical-align"])

    if textAlignH ~= "Start" then
        props.textAlignH = UI.ALIGNMENT[textAlignH]
    end
    if textAlignV ~= "Start" then
        props.textAlignV = UI.ALIGNMENT[textAlignV]
    end

    -- Multiline / wordwrap / autosize from attributes
    if node.attributes then
        if node.attributes["MultiLine"] and node.attributes["MultiLine"].value == "true" then
            props.multiline = true
        end
        if node.attributes["WordWrap"] and node.attributes["WordWrap"].value == "true" then
            props.wordWrap = true
        end
        if node.attributes["AutoSize"] and node.attributes["AutoSize"].value == "true" then
            props.autoSize = true
        end
        if isTextEdit and node.attributes["ReadOnly"] and node.attributes["ReadOnly"].value == "true" then
            props.readOnly = true
        end
    end

    return {
        type  = isTextEdit and UI.TYPE.TextEdit or UI.TYPE.Text,
        props = props,
    }
end

---------------------------------------------------------------------------
-- Image element rendering
---------------------------------------------------------------------------

--- Build an OpenMW Image layout from an mw-image DomNode.
--- @param node AnglesUI.DomNode
--- @return table layout
local function buildImageElementLayout(node)
    local styles = node.computedStyles
    local ld = node.layoutData

    -- Resource path from attribute
    local resourcePath = nil
    if node.attributes["Resource"] then
        resourcePath = node.attributes["Resource"].value
    end
    if not resourcePath then
        error("mw-image requires a Resource attribute", 0)
    end

    local props = {
        position = Util.vector2(0, 0),
        size     = Util.vector2(ld.contentWidth or 0, ld.contentHeight or 0),
        resource = UI.texture({ path = resourcePath }),
    }

    -- TileH / TileV attributes
    if node.attributes["TileH"] and node.attributes["TileH"].value == "true" then
        props.tileH = true
    end
    if node.attributes["TileV"] and node.attributes["TileV"].value == "true" then
        props.tileV = true
    end

    -- background-color on mw-image tints the image
    local r, g, b = LayoutUtils.ParseColor(styles["background-color"])
    if r then
        props.color = Util.color.rgb(r, g, b)
    end

    return {
        type  = UI.TYPE.Image,
        props = props,
    }
end

---------------------------------------------------------------------------
-- Scroll canvas rendering
---------------------------------------------------------------------------

--- Build scrollbar widget layouts for a scroll canvas node, wiring all
--- interactive events (arrow click-to-scroll, thumb drag).
---
--- offsetX/offsetY are the border+padding insets of the scroll canvas element;
--- all scrollbar widgets must be offset by these so they align with the viewport.
--- scrollContentProps is the mutable props table of the scroll-content widget so
--- that scroll events can update its position and call element:update().
---
--- @param node AnglesUI.DomNode
--- @param scrollState AnglesUI.ScrollState
--- @param context table
--- @param offsetX number Border+padding left inset of the scroll canvas
--- @param offsetY number Border+padding top inset of the scroll canvas
--- @param scrollContentProps table Mutable props of the scroll-content widget
--- @return table[] layouts
local function buildScrollbarLayouts(node, scrollState, context, offsetX, offsetY, scrollContentProps)
    offsetX = offsetX or 0
    offsetY = offsetY or 0

    local descriptors = ScrollCanvas.BuildScrollbarDescriptors(
        scrollState,
        node.layoutData.width or 0,
        node.layoutData.height or 0
    )
    local layouts = {}
    local INCREMENT = ScrollCanvas.SCROLL_INCREMENT

    for _, desc in ipairs(descriptors) do
        local isVertical = desc.orientation == "vertical"
        local arrowSize  = desc.arrowSize
        local trackLen   = (isVertical and desc.trackHeight or desc.trackWidth) - 2 * arrowSize

        -- Helpers for axis-independent access to scrollState fields.
        local function getScrollOff()
            return isVertical and scrollState.scrollY or scrollState.scrollX
        end
        local function setScrollOff(v)
            if isVertical then scrollState.scrollY = v else scrollState.scrollX = v end
        end
        local function getViewSize()
            return isVertical and scrollState.viewportHeight or scrollState.viewportWidth
        end
        local function getContentSize()
            return isVertical and scrollState.contentHeight or scrollState.contentWidth
        end

        -- Build the mutable props for this thumb.
        local initThumbSize, initThumbPos = ScrollCanvas.CalculateThumb(
            getViewSize(), getContentSize(), getScrollOff(), trackLen
        )
        local thumbX, thumbY, thumbW, thumbH
        if isVertical then
            thumbX = offsetX + desc.trackX
            thumbY = offsetY + desc.trackY + arrowSize + initThumbPos
            thumbW = desc.scrollbarWidth
            thumbH = initThumbSize
        else
            thumbX = offsetX + desc.trackX + arrowSize + initThumbPos
            thumbY = offsetY + desc.trackY
            thumbW = initThumbSize
            thumbH = desc.scrollbarWidth
        end
        local thumbProps = {
            position = Util.vector2(thumbX, thumbY),
            size     = Util.vector2(thumbW, thumbH),
            resource = UI.texture({ path = desc.thumbTexture }),
            tileH    = not isVertical,
            tileV    = isVertical,
        }

        --- Apply the current scrollState to all mutable layout tables and refresh the UI.
        local function applyScroll()
            -- Clamp first
            setScrollOff(ScrollCanvas.ClampScroll(getScrollOff(), getViewSize(), getContentSize()))
            -- Update scroll-content position
            if scrollContentProps then
                scrollContentProps.position = Util.vector2(-scrollState.scrollX, -scrollState.scrollY)
            end
            -- Recalculate and update this thumb
            local tSize, tPos = ScrollCanvas.CalculateThumb(
                getViewSize(), getContentSize(), getScrollOff(), trackLen
            )
            if isVertical then
                thumbProps.position = Util.vector2(offsetX + desc.trackX, offsetY + desc.trackY + arrowSize + tPos)
                thumbProps.size     = Util.vector2(desc.scrollbarWidth, tSize)
            else
                thumbProps.position = Util.vector2(offsetX + desc.trackX + arrowSize + tPos, offsetY + desc.trackY)
                thumbProps.size     = Util.vector2(tSize, desc.scrollbarWidth)
            end
            -- Persist scroll position so re-renders don't reset it
            if node.id and node.id ~= "" then
                if not currentScrollOffsets[node.id] then
                    currentScrollOffsets[node.id] = { x = 0, y = 0 }
                end
                currentScrollOffsets[node.id].x = scrollState.scrollX
                currentScrollOffsets[node.id].y = scrollState.scrollY
            end
            -- Re-render to pick up nested widget prop changes (el:update() alone
            -- does not cascade into UI.content() subtrees for scroll content).
            if currentRerenderFn then
                currentRerenderFn()
            else
                local el = currentElementRef and currentElementRef.element
                if el then el:update() end
            end
        end

        -- Drag state for the thumb.
        -- isDragging, dragStartMouse, dragStartScroll, capScrollRange, capThumbRange
        -- are shared between the thumb's own events and the capture overlay so that
        -- whichever widget receives the mouseMove (OpenMW delivers them to the widget
        -- that received mousePress — implicit capture) handles the drag correctly.
        local captureOverlay  = nil
        local isDragging      = false
        local dragStartMouse  = 0
        local dragStartScroll = 0
        local capScrollRange  = 0
        local capThumbRange   = 0

        local function onDragMove(moveEvent)
            if not isDragging then return end
            if capThumbRange <= 0 or capScrollRange <= 0 then return end
            local curPos    = isVertical and moveEvent.position.y or moveEvent.position.x
            local delta     = curPos - dragStartMouse
            local newScroll = dragStartScroll + (delta / capThumbRange * capScrollRange)
            setScrollOff(newScroll)
            applyScroll()
        end

        local function onDragRelease()
            isDragging = false
            if captureOverlay then
                captureOverlay:destroy()
                captureOverlay = nil
            end
        end

        -- Arrow start button
        layouts[#layouts + 1] = {
            type  = UI.TYPE.Image,
            props = {
                position = Util.vector2(offsetX + desc.trackX, offsetY + desc.trackY),
                size     = Util.vector2(
                    isVertical and desc.scrollbarWidth or arrowSize,
                    isVertical and arrowSize or desc.scrollbarWidth
                ),
                resource = UI.texture({ path = desc.arrowStartTexture }),
                tileH    = false,
                tileV    = false,
            },
            events = {
                mousePress = Async:callback(function()
                    setScrollOff(getScrollOff() - INCREMENT)
                    applyScroll()
                end),
            },
        }

        -- Arrow end button
        local endX = isVertical and desc.trackX or (desc.trackX + desc.trackWidth - arrowSize)
        local endY = isVertical and (desc.trackY + desc.trackHeight - arrowSize) or desc.trackY
        layouts[#layouts + 1] = {
            type  = UI.TYPE.Image,
            props = {
                position = Util.vector2(offsetX + endX, offsetY + endY),
                size     = Util.vector2(
                    isVertical and desc.scrollbarWidth or arrowSize,
                    isVertical and arrowSize or desc.scrollbarWidth
                ),
                resource = UI.texture({ path = desc.arrowEndTexture }),
                tileH    = false,
                tileV    = false,
            },
            events = {
                mousePress = Async:callback(function()
                    setScrollOff(getScrollOff() + INCREMENT)
                    applyScroll()
                end),
            },
        }

        -- Thumb
        layouts[#layouts + 1] = {
            type   = UI.TYPE.Image,
            props  = thumbProps,
            events = {
                mousePress = Async:callback(function(mouseEvent)
                    isDragging      = true
                    dragStartMouse  = isVertical and mouseEvent.position.y or mouseEvent.position.x
                    dragStartScroll = getScrollOff()
                    -- Snapshot sizes (won't change mid-drag)
                    local capViewSize    = getViewSize()
                    local capContentSize = getContentSize()
                    capScrollRange = capContentSize - capViewSize
                    capThumbRange  = trackLen - (isVertical and thumbProps.size.y or thumbProps.size.x)
                    -- Full-screen overlay catches cursor-leaves-thumb movement,
                    -- same pattern as Dragger/Resizable.
                    captureOverlay = UI.create({
                        layer = currentLayerName,
                        props = {
                            position = Util.vector2(0, 0),
                            size     = Util.vector2(9999, 9999),
                            alpha    = 0,
                        },
                        events = {
                            mouseMove    = Async:callback(function(me) onDragMove(me) end),
                            mouseRelease = Async:callback(function() onDragRelease() end),
                        },
                    })
                end),
                -- OpenMW implicit-captures mouseMove to the widget that received
                -- mousePress, so we must handle drag here as the primary path.
                mouseMove    = Async:callback(function(me) onDragMove(me) end),
                mouseRelease = Async:callback(function() onDragRelease() end),
            },
        }
    end

    return layouts
end

---------------------------------------------------------------------------
-- Event wiring
---------------------------------------------------------------------------

--- Wrap event callbacks with async:callback() for OpenMW.
--- @param callbackMap table<string, fun(event1: any, layout: any)>|nil
--- @return table<string, any>|nil events
local function wrapEvents(callbackMap)
    if not callbackMap or not next(callbackMap) then
        return nil
    end

    local events = {}
    for eventName, callback in pairs(callbackMap) do
        events[eventName] = Async:callback(callback)
    end
    return events
end

---------------------------------------------------------------------------
-- Hover tracking event injection
---------------------------------------------------------------------------

--- Build focusGain/focusLoss callbacks for hover tracking on a DomNode.
--- @param node AnglesUI.DomNode
--- @param hoverTracker AnglesUI.HoverTracker|nil
--- @return table<string, fun(event1: any, layout: any)>|nil
local function buildHoverCallbacks(node, hoverTracker)
    if not hoverTracker then return nil end

    return {
        focusGain = function(_, _)
            hoverTracker:OnFocusGain(node)
        end,
        focusLoss = function(_, _)
            hoverTracker:OnFocusLoss(node)
        end,
    }
end

---------------------------------------------------------------------------
-- Collect text from an element's children
---------------------------------------------------------------------------

--- Collect all text from a text element's children (text + resolved output).
--- @param node AnglesUI.DomNode
--- @return string
local function collectText(node)
    local parts = {}
    for _, child in ipairs(node.children) do
        if child.kind == DomNodeKind.Text and child.htmlNode and child.htmlNode.content then
            parts[#parts + 1] = child.htmlNode.content
        elseif child.kind == DomNodeKind.Output then
            parts[#parts + 1] = child.resolvedText or ""
        end
    end
    return table.concat(parts)
end

---------------------------------------------------------------------------
-- Content area wrapper
---------------------------------------------------------------------------

--- Build a content-area wrapper widget that offsets children by border+padding.
--- @param node AnglesUI.DomNode
--- @param childLayouts table[]
--- @return table layout
local function buildContentWrapper(node, childLayouts)
    local ld = node.layoutData
    local offsetX = (ld.borderLeft or 0) + (ld.paddingLeft or 0)
    local offsetY = (ld.borderTop or 0) + (ld.paddingTop or 0)

    return {
        props = {
            position = Util.vector2(offsetX, offsetY),
            size     = Util.vector2(ld.contentWidth or 0, ld.contentHeight or 0),
        },
        content = UI.content(childLayouts),
    }
end

---------------------------------------------------------------------------
-- Core transpilation
---------------------------------------------------------------------------

--- Transpile a single DomNode into an OpenMW UI layout table.
--- @param node AnglesUI.DomNode
--- @param eventMaps table<AnglesUI.DomNode, table>
--- @param context table
--- @param hoverTracker AnglesUI.HoverTracker|nil
--- @return table layout
transpileNode = function(node, eventMaps, context, hoverTracker)
    -- Text nodes in non-text-element parents (rare but possible)
    if node.kind == DomNodeKind.Text then
        return {
            type = UI.TYPE.Text,
            props = {
                text = node.htmlNode.content or "",
                textSize = 16,
            },
        }
    end

    -- Output directive node (should be inside mw-text, but handle standalone)
    if node.kind == DomNodeKind.Output then
        return {
            type = UI.TYPE.Text,
            props = {
                text = node.resolvedText or "",
                textSize = 16,
            },
        }
    end

    -- Element nodes
    if node.kind ~= DomNodeKind.Element then
        return {}
    end

    local tag = node.tag
    local ld = node.layoutData
    local styles = node.computedStyles

    -- Build the base props
    local props = buildProps(node)

    -- Map id to name
    if node.id then
        props.name = node.id
    end

    -- Determine OpenMW UI type
    local uiType = nil
    local isText  = (tag == "mw-text" or tag == "mw-text-edit")
    local isImage = (tag == "mw-image")
    local isScrollCanvas = (tag == "mw-scroll-canvas")

    -- Build the content layouts array
    local contentLayouts = {}

    -- 1) Background image (behind everything)
    local bgLayout = buildBackgroundImageLayout(node)
    if bgLayout then
        contentLayouts[#contentLayouts + 1] = bgLayout
    end

    -- 2) Borders
    local borderLayouts = buildBorderLayouts(node)
    for _, bl in ipairs(borderLayouts) do
        contentLayouts[#contentLayouts + 1] = bl
    end

    -- 3) Main content
    if isText then
        -- Text element: single text widget inside content area
        local text = collectText(node)
        local textLayout = buildTextLayout(node, text)
        -- Position text inside the content area (after border+padding offset)
        contentLayouts[#contentLayouts + 1] = buildContentWrapper(node, { textLayout })

    elseif isImage then
        -- Image element: single image widget inside content area
        local imgLayout = buildImageElementLayout(node)
        contentLayouts[#contentLayouts + 1] = buildContentWrapper(node, { imgLayout })

    elseif isScrollCanvas then
        -- Scroll canvas: viewport clip + scrollbars
        local scrollState = ld.scrollState
        if scrollState then
            -- Viewport container with clip
            local viewportChildren = {}
            for _, child in ipairs(node.children) do
                if child.kind == DomNodeKind.Element then
                    viewportChildren[#viewportChildren + 1] = transpileNode(
                        child, eventMaps, context, hoverTracker
                    )
                end
            end

            -- Mutable props table for the scroll-content widget.
            -- buildScrollbarLayouts captures a reference to this table so that
            -- scroll events can update `position` without rebuilding the widget tree.
            local scrollContentProps = {
                position = Util.vector2(-(scrollState.scrollX or 0), -(scrollState.scrollY or 0)),
                size     = Util.vector2(scrollState.contentWidth, scrollState.contentHeight),
            }
            local scrollContent = {
                props   = scrollContentProps,
                content = UI.content(viewportChildren),
            }

            -- Viewport with clipping (size = viewport dimensions)
            local offsetX = (ld.borderLeft or 0) + (ld.paddingLeft or 0)
            local offsetY = (ld.borderTop or 0) + (ld.paddingTop or 0)
            local viewport = {
                props = {
                    position = Util.vector2(offsetX, offsetY),
                    size     = Util.vector2(scrollState.viewportWidth, scrollState.viewportHeight),
                },
                content = UI.content({ scrollContent }),
            }
            contentLayouts[#contentLayouts + 1] = viewport

            -- Scrollbars — must be offset by the same border+padding as the viewport.
            -- Pass scrollContentProps so event handlers can mutate the scroll position.
            local sbLayouts = buildScrollbarLayouts(node, scrollState, context, offsetX, offsetY, scrollContentProps)
            for _, sbl in ipairs(sbLayouts) do
                contentLayouts[#contentLayouts + 1] = sbl
            end
        end

    else
        -- Generic container: recursively transpile children
        local childLayouts = {}
        for _, child in ipairs(node.children) do
            if child.kind == DomNodeKind.Element then
                childLayouts[#childLayouts + 1] = transpileNode(
                    child, eventMaps, context, hoverTracker
                )
            elseif child.kind == DomNodeKind.Text or child.kind == DomNodeKind.Output then
                -- Standalone text/output in a generic container
                local textContent = ""
                if child.kind == DomNodeKind.Text then
                    textContent = child.htmlNode.content or ""
                elseif child.kind == DomNodeKind.Output then
                    textContent = child.resolvedText or ""
                end
                -- Skip whitespace-only text nodes (matches browser block-flow behaviour)
                local isWsOnly = (textContent:match("^%s*$") ~= nil)
                if #textContent > 0 and not isWsOnly then
                    local cld = child.layoutData or {}
                    childLayouts[#childLayouts + 1] = {
                        type = UI.TYPE.Text,
                        props = {
                            position = Util.vector2(cld.x or 0, cld.y or 0),
                            text = textContent,
                            textSize = 16,
                        },
                    }
                end
            end
        end

        if #childLayouts > 0 then
            contentLayouts[#contentLayouts + 1] = buildContentWrapper(node, childLayouts)
        end
    end

    -- Build events: user events + hover tracking
    local eventCallbacks = eventMaps[node]
    local hoverCbs = buildHoverCallbacks(node, hoverTracker)

    if hoverCbs then
        local EventBinding = require("scripts.Nox.AnglesUI.Runtime.EventBinding")
        eventCallbacks = EventBinding.MergeCallbackMaps(eventCallbacks or {}, hoverCbs)
    end

    local events = wrapEvents(eventCallbacks)

    -- Assemble the layout
    local layout = {
        props = props,
    }
    if uiType then
        layout.type = uiType
    end
    if events then
        layout.events = events
    end
    if node.id then
        layout.name = node.id
    end
    if #contentLayouts > 0 then
        layout.content = UI.content(contentLayouts)
    end

    return layout
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

--- Transpile a full DOM tree into an OpenMW UI.create() compatible table.
--- The root is expected to be the __document__ wrapper containing an mw-root
--- element as its first child.
--- @param root AnglesUI.DomNode The DOM tree root (__document__ node)
--- @param eventMaps table<AnglesUI.DomNode, table> Event callback maps from RuntimeInit
--- @param context table The evaluation scope
--- @param hoverTracker AnglesUI.HoverTracker|nil
--- @param elementRef { element: table }|nil Shared live-element reference (for scroll canvas events)
--- @param scrollOffsets table<string, { x: number, y: number }>|nil Persistent scroll offsets from the Renderer
--- @param rerenderFn (fun(): nil)|nil Called by applyScroll to force a full layout+render refresh
--- @return table createArg The table to pass to UI.create()
---@nodiscard
function Transpiler.Transpile(root, eventMaps, context, hoverTracker, elementRef, scrollOffsets, rerenderFn)
    currentElementRef    = elementRef or nil
    currentScrollOffsets = scrollOffsets or {}
    currentRerenderFn    = rerenderFn or nil
    -- Find the mw-root element
    local mwRoot = nil
    for _, child in ipairs(root.children) do
        if child.kind == DomNodeKind.Element and child.tag == "mw-root" then
            mwRoot = child
            break
        end
    end

    if not mwRoot then
        error("AnglesUI: Root HTML must have <mw-root> as its first element", 0)
    end

    -- Get layer from mw-root
    local layerAttr = mwRoot.attributes["Layer"]
    if not layerAttr or not layerAttr.value then
        error("AnglesUI: <mw-root> requires a 'Layer' attribute", 0)
    end
    local layer = layerAttr.value
    currentLayerName = layer

    -- Transpile the mw-root and its contents
    local rootLayout = transpileNode(mwRoot, eventMaps, context, hoverTracker)

    -- Build the UI.create() argument
    local createArg = {
        layer   = layer,
        props   = rootLayout.props,
        content = rootLayout.content,
        events  = rootLayout.events,
    }

    if mwRoot.id then
        createArg.name = mwRoot.id
    end

    return createArg
end

return Transpiler
