--- AnglesUI Box Model Layout Engine.
--- Walks the DOM tree and computes layout data (position, size, padding,
--- margin, border widths) for every element node. Delegates to FlexLayout
--- and GridLayout for container-specific child distribution.
---
--- Layout data is stored on each DomNode's `layoutData` table with:
---   x, y            — position relative to parent content area
---   width, height   — outer box size (content + padding + border)
---   contentWidth, contentHeight — inner content area
---   paddingTop/Right/Bottom/Left
---   marginTop/Right/Bottom/Left
---   borderTop/Right/Bottom/Left (pixel widths from parsed border props)

local LayoutUtils  = require("scripts.Nox.AnglesUI.Renderer.LayoutUtils")
local TextMeasure  = require("scripts.Nox.AnglesUI.TextMeasure")

---------------------------------------------------------------------------
-- Forward declarations for layout delegates (set via SetDelegates)
---------------------------------------------------------------------------

--- @type fun(node: AnglesUI.DomNode, availableWidth: number, availableHeight: number)
local flexLayoutFunc

--- @type fun(node: AnglesUI.DomNode, availableWidth: number, availableHeight: number)
local gridLayoutFunc

--- @type fun(node: AnglesUI.DomNode, availableWidth: number, availableHeight: number)
local scrollCanvasLayoutFunc

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

--- @class AnglesUI.BoxModel
local BoxModel = {}

--- Inject layout delegate functions to avoid circular requires.
--- Called once during renderer initialisation.
--- @param flexFn fun(node: AnglesUI.DomNode, availableWidth: number, availableHeight: number)
--- @param gridFn fun(node: AnglesUI.DomNode, availableWidth: number, availableHeight: number)
--- @param scrollFn? fun(node: AnglesUI.DomNode, availableWidth: number, availableHeight: number)
function BoxModel.SetDelegates(flexFn, gridFn, scrollFn)
    flexLayoutFunc = flexFn
    gridLayoutFunc = gridFn
    scrollCanvasLayoutFunc = scrollFn
end

---------------------------------------------------------------------------
-- Layout Data Initialisation
---------------------------------------------------------------------------

--- @class AnglesUI.LayoutData
--- @field x number Position X relative to parent content area
--- @field y number Position Y relative to parent content area
--- @field width number Outer box width (border + padding + content)
--- @field height number Outer box height (border + padding + content)
--- @field contentWidth number Inner content area width
--- @field contentHeight number Inner content area height
--- @field paddingTop number
--- @field paddingRight number
--- @field paddingBottom number
--- @field paddingLeft number
--- @field marginTop number
--- @field marginRight number
--- @field marginBottom number
--- @field marginLeft number
--- @field borderTop number
--- @field borderRight number
--- @field borderBottom number
--- @field borderLeft number
--- @field isAbsolute boolean Whether position is "absolute"
--- @field isRelative boolean Whether position is "relative"

--- Initialise layoutData to zero/defaults.
--- @param node AnglesUI.DomNode
local function initLayoutData(node)
    local ld = node.layoutData
    ld.x = 0
    ld.y = 0
    ld.width = 0
    ld.height = 0
    ld.contentWidth = 0
    ld.contentHeight = 0
    ld.paddingTop = 0
    ld.paddingRight = 0
    ld.paddingBottom = 0
    ld.paddingLeft = 0
    ld.marginTop = 0
    ld.marginRight = 0
    ld.marginBottom = 0
    ld.marginLeft = 0
    ld.borderTop = 0
    ld.borderRight = 0
    ld.borderBottom = 0
    ld.borderLeft = 0
    ld.isAbsolute = false
    ld.isRelative = false
end

---------------------------------------------------------------------------
-- Intrinsic / content sizing helpers
---------------------------------------------------------------------------

--- Estimate the intrinsic size of a text node based on parent styles.
--- @param node AnglesUI.DomNode
--- @param parentStyles table<string, string>
--- @param maxWidth number|nil
--- @return number width, number height
local function measureTextNode(node, parentStyles, maxWidth)
    local text = ""
    if node.htmlNode and node.htmlNode.content then
        text = node.htmlNode.content
    end
    if #text == 0 then return 0, 0 end

    local fontSize = LayoutUtils.ParseNumber(LayoutUtils.GetStyle(parentStyles, "font-size"))
    if fontSize <= 0 then fontSize = 16 end

    local multiline = false
    local wordWrap = false
    -- Check parent attributes for MultiLine/WordWrap
    if node.parent and node.parent.attributes then
        local mlAttr = node.parent.attributes["MultiLine"]
        if mlAttr and mlAttr.value == "true" then multiline = true end
        local wwAttr = node.parent.attributes["WordWrap"]
        if wwAttr and wwAttr.value == "true" then wordWrap = true end
    end

    if multiline and maxWidth then
        local w, h = TextMeasure.MeasureBounds(text, fontSize, maxWidth, wordWrap)
        return w, h
    else
        local w = TextMeasure.MeasureWidth(text, fontSize)
        local h = TextMeasure.MeasureLineHeight(fontSize)
        return w, h
    end
end

--- Check if a tag is a flex container.
--- @param tag string|nil
--- @return boolean
local function isFlexContainer(tag)
    return tag == "mw-flex"
end

--- Check if a tag is a grid container.
--- @param tag string|nil
--- @return boolean
local function isGridContainer(tag)
    return tag == "mw-grid"
end

--- Check if a tag is a text element.
--- @param tag string|nil
--- @return boolean
local function isTextElement(tag)
    return tag == "mw-text" or tag == "mw-text-edit"
end

--- Check if a tag is an image element.
--- @param tag string|nil
--- @return boolean
local function isImageElement(tag)
    return tag == "mw-image"
end

--- Check if a tag is the scroll canvas.
--- @param tag string|nil
--- @return boolean
local function isScrollCanvas(tag)
    return tag == "mw-scroll-canvas"
end

---------------------------------------------------------------------------
-- Core layout: resolve a single node's box model
---------------------------------------------------------------------------

--- Resolve the box model for a single element node.
--- After this call, the node's layoutData contains resolved padding, margin,
--- border, content size, and outer size. Child layout is delegated.
--- @param node AnglesUI.DomNode
--- @param availableWidth number Available content width from parent
--- @param availableHeight number Available content height from parent
function BoxModel.Layout(node, availableWidth, availableHeight)
    if node.kind ~= "Element" then return end

    initLayoutData(node)

    local styles = node.computedStyles
    local ld = node.layoutData

    -- Position mode
    local posMode = LayoutUtils.GetStyle(styles, "position")
    ld.isAbsolute = (posMode == "absolute")
    ld.isRelative = (posMode == "relative")

    -- Resolve padding
    ld.paddingTop, ld.paddingRight, ld.paddingBottom, ld.paddingLeft =
        LayoutUtils.ResolvePadding(styles, availableWidth, availableHeight)

    -- Resolve margin
    ld.marginTop, ld.marginRight, ld.marginBottom, ld.marginLeft =
        LayoutUtils.ResolveMargin(styles, availableWidth, availableHeight)

    -- Resolve borders
    ld.borderTop, ld.borderRight, ld.borderBottom, ld.borderLeft =
        LayoutUtils.ResolveBorderWidths(styles)

    -- Horizontal and vertical "chrome" (border + padding)
    local hChrome = ld.borderLeft + ld.paddingLeft + ld.paddingRight + ld.borderRight
    local vChrome = ld.borderTop + ld.paddingTop + ld.paddingBottom + ld.borderBottom

    -- Resolve explicit width/height
    local explicitWidth  = LayoutUtils.ResolveLengthOrNil(styles["width"],  availableWidth)
    local explicitHeight = LayoutUtils.ResolveLengthOrNil(styles["height"], availableHeight)

    -- Content area available for children
    local contentAvailW = explicitWidth  and math.max(0, explicitWidth  - hChrome) or math.max(0, availableWidth  - hChrome)
    local contentAvailH = explicitHeight and math.max(0, explicitHeight - vChrome) or math.max(0, availableHeight - vChrome)

    -- Layout children based on container type
    local tag = node.tag

    if isFlexContainer(tag) and flexLayoutFunc then
        flexLayoutFunc(node, contentAvailW, contentAvailH)
    elseif isGridContainer(tag) and gridLayoutFunc then
        gridLayoutFunc(node, contentAvailW, contentAvailH)
    elseif isScrollCanvas(tag) and scrollCanvasLayoutFunc then
        scrollCanvasLayoutFunc(node, contentAvailW, contentAvailH)
    elseif isTextElement(tag) then
        -- Text elements: size from text content
        BoxModel._LayoutTextElement(node, contentAvailW, contentAvailH)
    elseif isImageElement(tag) then
        -- Image elements: use explicit size or available space
        BoxModel._LayoutImageElement(node, contentAvailW, contentAvailH)
    else
        -- Generic block / typeless: flow children vertically
        BoxModel._LayoutBlockChildren(node, contentAvailW, contentAvailH)
    end

    -- After children are laid out, compute content size from children if not explicit
    local childBounds = BoxModel._MeasureChildBounds(node)

    -- Content dimensions: explicit overrides child-computed
    ld.contentWidth  = explicitWidth  and math.max(0, explicitWidth  - hChrome) or childBounds.width
    ld.contentHeight = explicitHeight and math.max(0, explicitHeight - vChrome) or childBounds.height

    -- Apply aspect ratio
    local aspectRatio = LayoutUtils.ParseAspectRatio(styles["aspect-ratio"])
    if aspectRatio then
        if explicitWidth and not explicitHeight then
            ld.contentHeight = ld.contentWidth / aspectRatio
        elseif explicitHeight and not explicitWidth then
            ld.contentWidth = ld.contentHeight * aspectRatio
        end
    end

    -- Outer box size
    ld.width  = ld.borderLeft + ld.paddingLeft + ld.contentWidth  + ld.paddingRight  + ld.borderRight
    ld.height = ld.borderTop  + ld.paddingTop  + ld.contentHeight + ld.paddingBottom + ld.borderBottom
end

---------------------------------------------------------------------------
-- Block (normal flow) layout for generic containers
---------------------------------------------------------------------------

--- Lay out children in normal block flow (vertical stacking).
--- Absolutely positioned children are skipped during flow.
---@private
--- @param node AnglesUI.DomNode
--- @param availableWidth number
--- @param availableHeight number
function BoxModel._LayoutBlockChildren(node, availableWidth, availableHeight)
    local offsetY = 0

    for _, child in ipairs(node.children) do
        if child.kind == "Element" then
            BoxModel.Layout(child, availableWidth, availableHeight)
            local cld = child.layoutData

            if not cld.isAbsolute then
                cld.x = cld.marginLeft
                cld.y = offsetY + cld.marginTop
                offsetY = cld.y + cld.height + cld.marginBottom
            end
        elseif child.kind == "Text" or child.kind == "Output" then
            -- Text/output nodes in generic containers — measure them
            child.layoutData = child.layoutData or {}
            initLayoutData(child)
            local parentStyles = node.computedStyles or {}
            local tw, th = measureTextNode(child, parentStyles, availableWidth)
            child.layoutData.width = tw
            child.layoutData.height = th
            child.layoutData.contentWidth = tw
            child.layoutData.contentHeight = th
            child.layoutData.x = 0
            child.layoutData.y = offsetY
            offsetY = offsetY + th
        end
    end
end

---------------------------------------------------------------------------
-- Text element layout
---------------------------------------------------------------------------

--- Layout an mw-text or mw-text-edit element.
---@private
--- @param node AnglesUI.DomNode
--- @param availableWidth number
--- @param availableHeight number
function BoxModel._LayoutTextElement(node, availableWidth, availableHeight)
    local ld = node.layoutData
    local styles = node.computedStyles
    local fontSize = LayoutUtils.ParseNumber(LayoutUtils.GetStyle(styles, "font-size"))
    if fontSize <= 0 then fontSize = 16 end

    -- Collect text from children (TextNodes and OutputDirectiveNodes)
    local text = BoxModel._CollectText(node)

    local autoSize = false
    local multiline = false
    local wordWrap = false

    if node.attributes then
        if node.attributes["AutoSize"] and node.attributes["AutoSize"].value == "true" then
            autoSize = true
        end
        if node.attributes["MultiLine"] and node.attributes["MultiLine"].value == "true" then
            multiline = true
        end
        if node.attributes["WordWrap"] and node.attributes["WordWrap"].value == "true" then
            wordWrap = true
        end
    end

    if autoSize or (#text == 0) then
        -- Let OpenMW auto-size; we estimate for layout purposes
        if multiline then
            local w, h = TextMeasure.MeasureBounds(text, fontSize, availableWidth, wordWrap)
            ld.contentWidth = w
            ld.contentHeight = h
        else
            ld.contentWidth = TextMeasure.MeasureWidth(text, fontSize)
            ld.contentHeight = TextMeasure.MeasureLineHeight(fontSize)
        end
    else
        -- Explicit size takes priority (handled by caller via explicitWidth/Height)
        -- Here we just estimate content for shrink-to-fit scenarios
        if multiline then
            local w, h = TextMeasure.MeasureBounds(text, fontSize, availableWidth, wordWrap)
            ld.contentWidth = w
            ld.contentHeight = h
        else
            ld.contentWidth = TextMeasure.MeasureWidth(text, fontSize)
            ld.contentHeight = TextMeasure.MeasureLineHeight(fontSize)
        end
    end
end

--- Collect all text content from a node's children (text + output nodes).
---@private
--- @param node AnglesUI.DomNode
--- @return string
function BoxModel._CollectText(node)
    local parts = {}
    for _, child in ipairs(node.children) do
        if child.kind == "Text" and child.htmlNode and child.htmlNode.content then
            parts[#parts + 1] = child.htmlNode.content
        elseif child.kind == "Output" then
            -- Output directives are evaluated at runtime; use placeholder for size estimation
            parts[#parts + 1] = "________"
        end
    end
    return table.concat(parts)
end

---------------------------------------------------------------------------
-- Image element layout
---------------------------------------------------------------------------

--- Layout an mw-image element.
--- Uses explicit size properties; falls back to available space.
---@private
--- @param node AnglesUI.DomNode
--- @param availableWidth number
--- @param availableHeight number
function BoxModel._LayoutImageElement(node, availableWidth, availableHeight)
    local ld = node.layoutData
    -- Images default to available space if no explicit size
    ld.contentWidth  = availableWidth
    ld.contentHeight = availableHeight
end

---------------------------------------------------------------------------
-- Child bounds measurement
---------------------------------------------------------------------------

--- @class AnglesUI._ChildBounds
--- @field width number
--- @field height number

--- Measure the bounding box of all children (non-absolute flow children).
---@private
--- @param node AnglesUI.DomNode
--- @return AnglesUI._ChildBounds
function BoxModel._MeasureChildBounds(node)
    local maxRight = 0
    local maxBottom = 0

    for _, child in ipairs(node.children) do
        local cld = child.layoutData
        if cld and not cld.isAbsolute then
            local right  = (cld.x or 0) + (cld.marginLeft or 0) + (cld.width or 0) + (cld.marginRight or 0)
            local bottom = (cld.y or 0) + (cld.marginTop or 0) + (cld.height or 0) + (cld.marginBottom or 0)

            -- Adjust: x/y already include marginLeft/Top from layout pass
            right  = (cld.x or 0) + (cld.width or 0) + (cld.marginRight or 0)
            bottom = (cld.y or 0) + (cld.height or 0) + (cld.marginBottom or 0)

            if right  > maxRight  then maxRight  = right  end
            if bottom > maxBottom then maxBottom = bottom end
        end
    end

    return { width = maxRight, height = maxBottom }
end

---------------------------------------------------------------------------
-- Full tree layout pass
---------------------------------------------------------------------------

--- Perform a complete layout pass on the entire DOM tree.
--- @param root AnglesUI.DomNode The DOM tree root
--- @param screenWidth number Screen/layer width in pixels
--- @param screenHeight number Screen/layer height in pixels
function BoxModel.LayoutTree(root, screenWidth, screenHeight)
    -- The root document wrapper sizes to the screen
    initLayoutData(root)
    root.layoutData.contentWidth = screenWidth
    root.layoutData.contentHeight = screenHeight
    root.layoutData.width = screenWidth
    root.layoutData.height = screenHeight

    -- Layout each child of the document root
    for _, child in ipairs(root.children) do
        if child.kind == "Element" then
            BoxModel.Layout(child, screenWidth, screenHeight)
        end
    end

    -- Positioning pass (absolute/relative) runs after all layout is complete
    BoxModel._ApplyPositioning(root)
end

---------------------------------------------------------------------------
-- Positioning pass
---------------------------------------------------------------------------

--- Apply absolute and relative positioning offsets after layout.
---@private
--- @param root AnglesUI.DomNode
function BoxModel._ApplyPositioning(root)
    root:Walk(function(node)
        if node.kind ~= "Element" then return false end

        local ld = node.layoutData
        local styles = node.computedStyles

        if ld.isAbsolute then
            -- Find the nearest positioned ancestor's content area
            local ref = node:FindPositionedAncestor()
            local refW, refH

            if ref then
                refW = ref.layoutData.contentWidth or 0
                refH = ref.layoutData.contentHeight or 0
            else
                -- Use root
                refW = root.layoutData.contentWidth or 0
                refH = root.layoutData.contentHeight or 0
            end

            local left   = LayoutUtils.ResolveLengthOrNil(styles["left"],   refW)
            local top    = LayoutUtils.ResolveLengthOrNil(styles["top"],    refH)
            local right  = LayoutUtils.ResolveLengthOrNil(styles["right"],  refW)
            local bottom = LayoutUtils.ResolveLengthOrNil(styles["bottom"], refH)

            if left then
                ld.x = left
            elseif right then
                ld.x = refW - ld.width - right
            end

            if top then
                ld.y = top
            elseif bottom then
                ld.y = refH - ld.height - bottom
            end

        elseif ld.isRelative then
            local refW = 0
            local refH = 0
            if node.parent then
                refW = node.parent.layoutData.contentWidth or 0
                refH = node.parent.layoutData.contentHeight or 0
            end

            local left   = LayoutUtils.ResolveLengthOrNil(styles["left"],   refW)
            local top    = LayoutUtils.ResolveLengthOrNil(styles["top"],    refH)
            local right  = LayoutUtils.ResolveLengthOrNil(styles["right"],  refW)
            local bottom = LayoutUtils.ResolveLengthOrNil(styles["bottom"], refH)

            local offsetX = 0
            local offsetY = 0

            if left then
                offsetX = left
            elseif right then
                offsetX = -right
            end

            if top then
                offsetY = top
            elseif bottom then
                offsetY = -bottom
            end

            ld.x = ld.x + offsetX
            ld.y = ld.y + offsetY
        end

        return false
    end)
end

return BoxModel
