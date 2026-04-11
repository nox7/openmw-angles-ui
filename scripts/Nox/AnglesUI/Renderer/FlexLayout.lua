--- AnglesUI Flex Layout Engine.
--- Implements CSS Flexbox layout for mw-flex containers.
--- Handles flex-direction, justify-content, align-items, gap,
--- flex-grow, flex-shrink, and flex-basis.

local LayoutUtils = require("scripts.Nox.AnglesUI.Renderer.LayoutUtils")

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

--- @class AnglesUI.FlexLayout
local FlexLayout = {}

--- @type fun(node: AnglesUI.DomNode, availableWidth: number, availableHeight: number)
local boxModelLayout

--- Inject the BoxModel.Layout function to avoid circular requires.
--- @param layoutFn fun(node: AnglesUI.DomNode, availableWidth: number, availableHeight: number)
function FlexLayout.SetBoxModelLayout(layoutFn)
    boxModelLayout = layoutFn
end

---------------------------------------------------------------------------
-- Flex layout
---------------------------------------------------------------------------

--- Perform flex layout on a mw-flex node's children.
--- The node's layoutData padding/margin/border must already be resolved.
--- @param node AnglesUI.DomNode
--- @param availableWidth number Content area width
--- @param availableHeight number Content area height
function FlexLayout.Layout(node, availableWidth, availableHeight)
    local styles = node.computedStyles

    -- Flex properties
    local direction    = LayoutUtils.GetStyle(styles, "flex-direction")
    local justifyContent = LayoutUtils.GetStyle(styles, "justify-content")
    local alignItems   = LayoutUtils.GetStyle(styles, "align-items")

    -- Gap
    local gapValue = styles["gap"]
    local gap = LayoutUtils.ResolveLength(gapValue,
        (direction == "row" or direction == "row-reverse") and availableWidth or availableHeight)

    -- Determine main/cross axis
    local isRow = (direction == "row" or direction == "row-reverse")
    local isReversed = (direction == "row-reverse" or direction == "column-reverse")

    local mainSize  = isRow and availableWidth or availableHeight
    local crossSize = isRow and availableHeight or availableWidth

    -- Collect flow children (skip absolute-positioned)
    --- @type AnglesUI.DomNode[]
    local flexItems = {}
    for _, child in ipairs(node.children) do
        if child.kind == "Element" then
            -- Pre-layout to get natural sizes and box model
            boxModelLayout(child, availableWidth, availableHeight)
            local cld = child.layoutData
            if not cld.isAbsolute then
                flexItems[#flexItems + 1] = child
            end
        end
    end

    if #flexItems == 0 then return end

    -- Resolve flex properties per item
    --- @type number[]
    local flexGrows = {}
    --- @type number[]
    local flexShrinks = {}
    --- @type number[]
    local flexBases = {}
    --- @type number[]
    local mainSizes = {}
    --- @type number[]
    local crossSizes = {}

    for i, item in ipairs(flexItems) do
        local itemStyles = item.computedStyles
        local cld = item.layoutData

        flexGrows[i]   = LayoutUtils.ParseNumber(LayoutUtils.GetStyle(itemStyles, "flex-grow"))
        flexShrinks[i] = LayoutUtils.ParseNumber(LayoutUtils.GetStyle(itemStyles, "flex-shrink"))

        -- Flex basis
        local basisVal = LayoutUtils.GetStyle(itemStyles, "flex-basis")
        local basis
        if basisVal == "auto" then
            basis = isRow and (cld.width + cld.marginLeft + cld.marginRight)
                          or (cld.height + cld.marginTop + cld.marginBottom)
        else
            basis = LayoutUtils.ResolveLength(basisVal, mainSize)
            -- Add margins to basis
            if isRow then
                basis = basis + cld.marginLeft + cld.marginRight
            else
                basis = basis + cld.marginTop + cld.marginBottom
            end
        end

        flexBases[i] = basis
        mainSizes[i] = basis
        crossSizes[i] = isRow and (cld.height + cld.marginTop + cld.marginBottom)
                                or (cld.width + cld.marginLeft + cld.marginRight)
    end

    -- Total gap space
    local totalGap = gap * math.max(0, #flexItems - 1)

    -- Calculate used main-axis space
    local usedMain = totalGap
    for i = 1, #flexItems do
        usedMain = usedMain + flexBases[i]
    end

    -- Distribute remaining space (grow) or reclaim overflow (shrink)
    local freeSpace = mainSize - usedMain

    if freeSpace > 0 then
        -- Grow
        local totalGrow = 0
        for i = 1, #flexItems do
            totalGrow = totalGrow + flexGrows[i]
        end
        if totalGrow > 0 then
            for i = 1, #flexItems do
                mainSizes[i] = flexBases[i] + freeSpace * (flexGrows[i] / totalGrow)
            end
        end
    elseif freeSpace < 0 then
        -- Shrink
        local totalShrink = 0
        for i = 1, #flexItems do
            totalShrink = totalShrink + (flexShrinks[i] * flexBases[i])
        end
        if totalShrink > 0 then
            for i = 1, #flexItems do
                local ratio = (flexShrinks[i] * flexBases[i]) / totalShrink
                mainSizes[i] = math.max(0, flexBases[i] + freeSpace * ratio)
            end
        end
    end

    -- Re-layout items with resolved main sizes to get correct cross sizes.
    -- We save the flex-resolved main size before re-layout because
    -- BoxModel.Layout respects explicit CSS width/height and would undo
    -- the flex grow/shrink distribution.
    for i, item in ipairs(flexItems) do
        local cld = item.layoutData
        local itemMainMargin, itemCrossMargin

        if isRow then
            itemMainMargin = cld.marginLeft + cld.marginRight
            itemCrossMargin = cld.marginTop + cld.marginBottom
        else
            itemMainMargin = cld.marginTop + cld.marginBottom
            itemCrossMargin = cld.marginLeft + cld.marginRight
        end

        local resolvedMain = mainSizes[i]
        local innerMain = math.max(0, resolvedMain - itemMainMargin)

        if isRow then
            boxModelLayout(item, innerMain, availableHeight)
        else
            boxModelLayout(item, availableWidth, innerMain)
        end

        -- After re-layout, force the main dimension to the flex-resolved
        -- size so that explicit CSS widths/heights don't undo grow/shrink.
        cld = item.layoutData
        if isRow then
            local hChrome = cld.borderLeft + cld.paddingLeft + cld.paddingRight + cld.borderRight
            cld.contentWidth = math.max(0, innerMain - hChrome)
            cld.width = cld.borderLeft + cld.paddingLeft + cld.contentWidth + cld.paddingRight + cld.borderRight
            mainSizes[i] = cld.width + cld.marginLeft + cld.marginRight
            crossSizes[i] = cld.height + cld.marginTop + cld.marginBottom
        else
            local vChrome = cld.borderTop + cld.paddingTop + cld.paddingBottom + cld.borderBottom
            cld.contentHeight = math.max(0, innerMain - vChrome)
            cld.height = cld.borderTop + cld.paddingTop + cld.contentHeight + cld.paddingBottom + cld.borderBottom
            mainSizes[i] = cld.height + cld.marginTop + cld.marginBottom
            crossSizes[i] = cld.width + cld.marginLeft + cld.marginRight
        end
    end

    -- Recalculate used main after re-layout
    usedMain = totalGap
    for i = 1, #flexItems do
        usedMain = usedMain + mainSizes[i]
    end
    freeSpace = mainSize - usedMain

    -- Justify content: calculate starting position and spacing
    local mainOffset = 0
    local itemSpacing = 0

    if justifyContent == "center" then
        mainOffset = freeSpace / 2
    elseif justifyContent == "end" then
        mainOffset = freeSpace
    elseif justifyContent == "space-between" then
        if #flexItems > 1 then
            itemSpacing = freeSpace / (#flexItems - 1)
        end
    elseif justifyContent == "space-around" then
        local spacer = freeSpace / #flexItems
        mainOffset = spacer / 2
        itemSpacing = spacer
    elseif justifyContent == "space-evenly" then
        local spacer = freeSpace / (#flexItems + 1)
        mainOffset = spacer
        itemSpacing = spacer
    end

    -- Position items
    local cursor = math.max(0, mainOffset)

    -- Build ordered list (reversed if necessary)
    local order = {}
    if isReversed then
        for i = #flexItems, 1, -1 do
            order[#order + 1] = i
        end
    else
        for i = 1, #flexItems do
            order[#order + 1] = i
        end
    end

    for idx, i in ipairs(order) do
        local item = flexItems[i]
        local cld = item.layoutData

        -- Main axis position
        local mainPos = cursor

        -- Cross axis alignment
        local crossPos = 0
        local itemCrossSize = crossSizes[i]

        if isRow then
            local itemCrossMargin = cld.marginTop + cld.marginBottom
            local itemBoxCross = cld.height

            if alignItems == "center" then
                crossPos = (crossSize - itemCrossSize) / 2 + cld.marginTop
            elseif alignItems == "end" then
                crossPos = crossSize - itemCrossSize + cld.marginTop
            elseif alignItems == "stretch" then
                -- Stretch cross size if no explicit dimension
                if not item.computedStyles["height"] or item.computedStyles["height"] == "auto" then
                    cld.contentHeight = math.max(0, crossSize - itemCrossMargin - cld.borderTop - cld.paddingTop - cld.paddingBottom - cld.borderBottom)
                    cld.height = cld.borderTop + cld.paddingTop + cld.contentHeight + cld.paddingBottom + cld.borderBottom
                end
                crossPos = cld.marginTop
            else -- start
                crossPos = cld.marginTop
            end

            cld.x = mainPos + cld.marginLeft
            cld.y = crossPos
        else
            local itemCrossMargin = cld.marginLeft + cld.marginRight
            local itemBoxCross = cld.width

            if alignItems == "center" then
                crossPos = (crossSize - itemCrossSize) / 2 + cld.marginLeft
            elseif alignItems == "end" then
                crossPos = crossSize - itemCrossSize + cld.marginLeft
            elseif alignItems == "stretch" then
                if not item.computedStyles["width"] or item.computedStyles["width"] == "auto" then
                    cld.contentWidth = math.max(0, crossSize - itemCrossMargin - cld.borderLeft - cld.paddingLeft - cld.paddingRight - cld.borderRight)
                    cld.width = cld.borderLeft + cld.paddingLeft + cld.contentWidth + cld.paddingRight + cld.borderRight
                end
                crossPos = cld.marginLeft
            else -- start
                crossPos = cld.marginLeft
            end

            cld.x = crossPos
            cld.y = mainPos + cld.marginTop
        end

        -- Advance cursor
        cursor = cursor + mainSizes[i] + gap
        if idx < #order then
            cursor = cursor + itemSpacing
        end
    end
end

return FlexLayout
