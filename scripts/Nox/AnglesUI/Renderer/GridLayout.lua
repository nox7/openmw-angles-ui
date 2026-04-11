--- AnglesUI Grid Layout Engine.
--- Implements CSS Grid layout for mw-grid containers.
--- Handles grid-template-columns/rows, fr units, repeat(), auto,
--- grid placement (column/row start/end, span), gaps, and content alignment.

local LayoutUtils = require("scripts.Nox.AnglesUI.Renderer.LayoutUtils")

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

--- @class AnglesUI.GridLayout
local GridLayout = {}

--- @type fun(node: AnglesUI.DomNode, availableWidth: number, availableHeight: number)
local boxModelLayout

--- Inject the BoxModel.Layout function to avoid circular requires.
--- @param layoutFn fun(node: AnglesUI.DomNode, availableWidth: number, availableHeight: number)
function GridLayout.SetBoxModelLayout(layoutFn)
    boxModelLayout = layoutFn
end

---------------------------------------------------------------------------
-- Grid item placement data
---------------------------------------------------------------------------

--- @class AnglesUI._GridPlacement
--- @field node AnglesUI.DomNode
--- @field colStart integer 1-based column start line
--- @field colEnd integer 1-based column end line
--- @field rowStart integer 1-based row start line
--- @field rowEnd integer 1-based row end line

---------------------------------------------------------------------------
-- Grid layout
---------------------------------------------------------------------------

--- Perform grid layout on a mw-grid node's children.
--- @param node AnglesUI.DomNode
--- @param availableWidth number Content area width
--- @param availableHeight number Content area height
function GridLayout.Layout(node, availableWidth, availableHeight)
    local styles = node.computedStyles

    -- Parse grid template definitions
    local colTemplate = LayoutUtils.ParseGridTemplate(styles["grid-template-columns"])
    local rowTemplate = LayoutUtils.ParseGridTemplate(styles["grid-template-rows"])

    -- Parse gaps
    local colGap, rowGap = GridLayout._ResolveGaps(styles, availableWidth, availableHeight)

    -- Alignment
    local justifyContent = LayoutUtils.GetStyle(styles, "justify-content")
    local alignContent   = LayoutUtils.GetStyle(styles, "align-content")

    -- Collect flow children
    --- @type AnglesUI.DomNode[]
    local gridItems = {}
    for _, child in ipairs(node.children) do
        if child.kind == "Element" then
            boxModelLayout(child, availableWidth, availableHeight)
            local cld = child.layoutData
            if not cld.isAbsolute then
                gridItems[#gridItems + 1] = child
            end
        end
    end

    if #gridItems == 0 then return end

    -- Determine grid dimensions
    local numCols = math.max(#colTemplate, 1)
    local numRows = math.max(#rowTemplate, 1)

    -- Place items into the grid
    local placements = GridLayout._PlaceItems(gridItems, numCols, numRows, styles)

    -- Expand grid if placements exceed template
    for _, p in ipairs(placements) do
        if p.colEnd - 1 > numCols then numCols = p.colEnd - 1 end
        if p.rowEnd - 1 > numRows then numRows = p.rowEnd - 1 end
    end

    -- Ensure templates have enough entries (fill with auto)
    while #colTemplate < numCols do
        colTemplate[#colTemplate + 1] = { type = "auto", value = 0 }
    end
    while #rowTemplate < numRows do
        rowTemplate[#rowTemplate + 1] = { type = "auto", value = 0 }
    end

    -- Measure auto-sized tracks (max content size of items in that track)
    local colAutoSizes = GridLayout._MeasureAutoTrackSizes(placements, numCols, "col", true)
    local rowAutoSizes = GridLayout._MeasureAutoTrackSizes(placements, numRows, "row", false)

    -- Resolve track sizes
    local totalColGap = colGap * math.max(0, numCols - 1)
    local totalRowGap = rowGap * math.max(0, numRows - 1)

    local colSizes = LayoutUtils.ResolveGridTracks(colTemplate, availableWidth - totalColGap, colAutoSizes)
    local rowSizes = LayoutUtils.ResolveGridTracks(rowTemplate, availableHeight - totalRowGap, rowAutoSizes)

    -- Re-layout items with their cell sizes for accurate sizing
    for _, p in ipairs(placements) do
        local cellW = GridLayout._SpanSize(colSizes, p.colStart, p.colEnd, colGap)
        local cellH = GridLayout._SpanSize(rowSizes, p.rowStart, p.rowEnd, rowGap)

        local item = p.node
        local cld = item.layoutData or {}
        local itemW = math.max(0, cellW - cld.marginLeft - cld.marginRight)
        local itemH = math.max(0, cellH - cld.marginTop - cld.marginBottom)

        boxModelLayout(item, itemW, itemH)
    end

    -- Calculate track start positions
    local colStarts = GridLayout._TrackStarts(colSizes, colGap)
    local rowStarts = GridLayout._TrackStarts(rowSizes, rowGap)

    -- Total grid content size
    local gridContentW = GridLayout._TotalSize(colSizes, colGap)
    local gridContentH = GridLayout._TotalSize(rowSizes, rowGap)

    -- Alignment offsets
    local offsetX = GridLayout._AlignOffset(justifyContent, availableWidth, gridContentW, numCols, colSizes, colGap)
    local offsetY = GridLayout._AlignOffset(alignContent, availableHeight, gridContentH, numRows, rowSizes, rowGap)

    -- Position items
    for _, p in ipairs(placements) do
        local item = p.node
        local cld = item.layoutData

        local cellX = colStarts[p.colStart] + offsetX
        local cellY = rowStarts[p.rowStart] + offsetY

        cld.x = cellX + cld.marginLeft
        cld.y = cellY + cld.marginTop
    end
end

---------------------------------------------------------------------------
-- Gap resolution
---------------------------------------------------------------------------

--- Resolve grid gaps from styles.
---@private
--- @param styles table<string, string>
--- @param refW number
--- @param refH number
--- @return number colGap, number rowGap
function GridLayout._ResolveGaps(styles, refW, refH)
    local colGap, rowGap

    -- Shorthand gap
    local gapVal = styles["gap"]
    if gapVal then
        local parts = {}
        for p in gapVal:gmatch("%S+") do parts[#parts + 1] = p end
        if #parts == 1 then
            colGap = LayoutUtils.ResolveLength(parts[1], refW)
            rowGap = LayoutUtils.ResolveLength(parts[1], refH)
        elseif #parts >= 2 then
            rowGap = LayoutUtils.ResolveLength(parts[1], refH)
            colGap = LayoutUtils.ResolveLength(parts[2], refW)
        end
    end

    -- Individual overrides
    if styles["grid-column-gap"] then
        colGap = LayoutUtils.ResolveLength(styles["grid-column-gap"], refW)
    end
    if styles["grid-row-gap"] then
        rowGap = LayoutUtils.ResolveLength(styles["grid-row-gap"], refH)
    end

    return colGap or 0, rowGap or 0
end

---------------------------------------------------------------------------
-- Item placement
---------------------------------------------------------------------------

--- Place grid items into cells using explicit placement or auto-placement.
--- @param items AnglesUI.DomNode[]
---@private
--- @param numCols integer
--- @param numRows integer
--- @param parentStyles table<string, string>
--- @return AnglesUI._GridPlacement[]
function GridLayout._PlaceItems(items, numCols, numRows, parentStyles)
    --- @type AnglesUI._GridPlacement[]
    local placements = {}

    -- Occupancy grid for auto-placement
    --- @type boolean[][]
    local occupied = {}
    for r = 1, numRows + #items do
        occupied[r] = {}
    end

    --- Check if cell (r, c) is occupied.
    local function isOccupied(r, c)
        return occupied[r] and occupied[r][c]
    end

    --- Mark cells as occupied.
    local function markOccupied(rStart, rEnd, cStart, cEnd)
        for r = rStart, rEnd - 1 do
            if not occupied[r] then occupied[r] = {} end
            for c = cStart, cEnd - 1 do
                occupied[r][c] = true
            end
        end
    end

    -- First pass: place explicitly positioned items
    for _, item in ipairs(items) do
        local itemStyles = item.computedStyles

        -- Resolve column placement
        local colStartVal = itemStyles["grid-column-start"]
        local colEndVal   = itemStyles["grid-column-end"]
        if itemStyles["grid-column"] then
            local s, e = LayoutUtils.ParseGridLineShorthand(itemStyles["grid-column"])
            colStartVal = s
            colEndVal = e
        end

        -- Resolve row placement
        local rowStartVal = itemStyles["grid-row-start"]
        local rowEndVal   = itemStyles["grid-row-end"]
        if itemStyles["grid-row"] then
            local s, e = LayoutUtils.ParseGridLineShorthand(itemStyles["grid-row"])
            rowStartVal = s
            rowEndVal = e
        end

        local colStart, colSpan = LayoutUtils.ParseGridLine(colStartVal)
        local colEnd, colEndSpan = LayoutUtils.ParseGridLine(colEndVal)
        local rowStart, rowSpan = LayoutUtils.ParseGridLine(rowStartVal)
        local rowEnd, rowEndSpan = LayoutUtils.ParseGridLine(rowEndVal)

        -- Calculate actual column start/end
        local cs, ce
        if colStart then
            cs = colStart
            if colEnd then
                ce = colEnd
            elseif colEndSpan then
                ce = cs + colEndSpan
            else
                ce = cs + (colSpan or 1)
            end
        elseif colSpan then
            -- Span without start — will be auto-placed
            cs = nil
            ce = nil
        else
            cs = nil
            ce = nil
        end

        -- Calculate actual row start/end
        local rs, re
        if rowStart then
            rs = rowStart
            if rowEnd then
                re = rowEnd
            elseif rowEndSpan then
                re = rs + rowEndSpan
            else
                re = rs + (rowSpan or 1)
            end
        elseif rowSpan then
            rs = nil
            re = nil
        else
            rs = nil
            re = nil
        end

        local spanW = (colSpan or colEndSpan or (cs and ce and (ce - cs)) or 1)
        local spanH = (rowSpan or rowEndSpan or (rs and re and (re - rs)) or 1)

        placements[#placements + 1] = {
            node = item,
            colStart = cs,
            colEnd = cs and (cs + spanW) or nil,
            rowStart = rs,
            rowEnd = rs and (rs + spanH) or nil,
            _spanW = spanW,
            _spanH = spanH,
        }
    end

    -- Mark explicitly placed items
    for _, p in ipairs(placements) do
        if p.colStart and p.rowStart then
            markOccupied(p.rowStart, p.rowEnd, p.colStart, p.colEnd)
        end
    end

    -- Second pass: auto-place items without explicit positions
    local autoRow = 1
    local autoCol = 1

    for _, p in ipairs(placements) do
        if not p.colStart or not p.rowStart then
            local spanW = p._spanW or 1
            local spanH = p._spanH or 1

            -- Find next available position
            local placed = false
            while not placed do
                if autoCol + spanW - 1 > numCols then
                    autoCol = 1
                    autoRow = autoRow + 1
                    -- Expand occupied grid if needed
                    if not occupied[autoRow] then
                        occupied[autoRow] = {}
                    end
                end

                -- Check if the span fits
                local fits = true
                for r = autoRow, autoRow + spanH - 1 do
                    for c = autoCol, autoCol + spanW - 1 do
                        if isOccupied(r, c) then
                            fits = false
                            break
                        end
                    end
                    if not fits then break end
                end

                if fits then
                    p.colStart = autoCol
                    p.colEnd = autoCol + spanW
                    p.rowStart = autoRow
                    p.rowEnd = autoRow + spanH
                    markOccupied(p.rowStart, p.rowEnd, p.colStart, p.colEnd)
                    autoCol = autoCol + spanW
                    placed = true
                else
                    autoCol = autoCol + 1
                end
            end
        end
    end

    -- Clean up temporary fields
    for _, p in ipairs(placements) do
        p._spanW = nil
        p._spanH = nil
    end

    return placements
end

---------------------------------------------------------------------------
-- Auto track sizing
---------------------------------------------------------------------------

--- Measure content sizes for auto-sized tracks.
--- @param placements AnglesUI._GridPlacement[]
---@private
--- @param trackCount integer
--- @param axis "col"|"row"
--- @param isWidth boolean
--- @return number[]
function GridLayout._MeasureAutoTrackSizes(placements, trackCount, axis, isWidth)
    local sizes = {}
    for i = 1, trackCount do sizes[i] = 0 end

    for _, p in ipairs(placements) do
        local start = axis == "col" and p.colStart or p.rowStart
        local finish = axis == "col" and p.colEnd or p.rowEnd
        local span = finish - start

        if span == 1 then
            local cld = p.node.layoutData
            local size
            if isWidth then
                size = (cld.width or 0) + (cld.marginLeft or 0) + (cld.marginRight or 0)
            else
                size = (cld.height or 0) + (cld.marginTop or 0) + (cld.marginBottom or 0)
            end
            if size > sizes[start] then
                sizes[start] = size
            end
        end
    end

    return sizes
end

---------------------------------------------------------------------------
-- Track helpers
---------------------------------------------------------------------------

--- Calculate the total size of a span (tracks + inner gaps).
--- @param trackSizes number[]
---@private
--- @param startLine integer 1-based start line
--- @param endLine integer 1-based end line
--- @param gap number
--- @return number
function GridLayout._SpanSize(trackSizes, startLine, endLine, gap)
    local total = 0
    for i = startLine, endLine - 1 do
        total = total + (trackSizes[i] or 0)
    end
    -- Add inner gaps
    local spanCount = endLine - startLine
    if spanCount > 1 then
        total = total + gap * (spanCount - 1)
    end
    return total
end

--- Calculate starting positions for each track.
---@private
--- @param trackSizes number[]
--- @param gap number
--- @return number[] starts 1-based index → pixel start position
function GridLayout._TrackStarts(trackSizes, gap)
    local starts = {}
    local pos = 0
    for i = 1, #trackSizes do
        starts[i] = pos
        pos = pos + trackSizes[i] + gap
    end
    return starts
end

--- Calculate total size of all tracks + gaps.
---@private
--- @param trackSizes number[]
--- @param gap number
--- @return number
function GridLayout._TotalSize(trackSizes, gap)
    local total = 0
    for _, s in ipairs(trackSizes) do
        total = total + s
    end
    if #trackSizes > 1 then
        total = total + gap * (#trackSizes - 1)
    end
    return total
end

---------------------------------------------------------------------------
-- Content alignment
---------------------------------------------------------------------------

--- Calculate alignment offset for justify-content / align-content.
--- @param alignment string
--- @param available number
--- @param used number
---@private
--- @param trackCount integer
--- @param trackSizes number[]
--- @param gap number
--- @return number offset
function GridLayout._AlignOffset(alignment, available, used, trackCount, trackSizes, gap)
    local free = available - used
    if free <= 0 then return 0 end

    if alignment == "center" then
        return free / 2
    elseif alignment == "end" then
        return free
    end
    -- start, space-between, space-around, space-evenly handled by gap distribution
    -- For simplicity in grid, we handle only start/center/end offset here
    return 0
end

return GridLayout
