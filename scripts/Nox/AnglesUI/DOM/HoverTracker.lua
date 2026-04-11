--- AnglesUI Hover Tracker.
--- Tracks which DOM nodes are currently "hovered" using OpenMW's
--- focusGain / focusLoss events.
---
--- Key gotcha in OpenMW: focusGain/focusLoss fire on mouse-over, and a
--- widget is only considered in focus when *that exact widget* is focused.
--- Events propagate up from children. A parent with :hover should be valid
--- if *any* of its descendants have focusGain.
---
--- Solution: maintain a counter (`hoverCount`) per node. When a leaf gains
--- focus, increment its own counter and all ancestors. On focusLoss, decrement.
--- A node is "hovered" when its hoverCount > 0.

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

--- @class AnglesUI.HoverTracker
--- @field private _hoverSet table<AnglesUI.DomNode, boolean> Set of currently-hovered nodes
local HoverTracker = {}
HoverTracker.__index = HoverTracker

---------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------

--- Create a new hover tracker.
--- @return AnglesUI.HoverTracker
function HoverTracker.New()
    local self = setmetatable({}, HoverTracker)
    self._hoverSet = {}
    return self
end

---------------------------------------------------------------------------
-- Focus event handlers
---------------------------------------------------------------------------

--- Call when a DOM node receives focusGain from OpenMW.
--- Increments the hover counter on this node and all its ancestors.
--- @param domNode AnglesUI.DomNode
function HoverTracker:OnFocusGain(domNode)
    domNode.hoverCount = domNode.hoverCount + 1
    domNode.isHovered = true
    self._hoverSet[domNode] = true

    -- Propagate up to ancestors
    local parent = domNode.parent
    while parent do
        parent.hoverCount = parent.hoverCount + 1
        if parent.hoverCount > 0 then
            parent.isHovered = true
            self._hoverSet[parent] = true
        end
        parent = parent.parent
    end
end

--- Call when a DOM node receives focusLoss from OpenMW.
--- Decrements the hover counter on this node and all its ancestors.
--- @param domNode AnglesUI.DomNode
function HoverTracker:OnFocusLoss(domNode)
    domNode.hoverCount = domNode.hoverCount - 1
    if domNode.hoverCount < 0 then
        domNode.hoverCount = 0
    end

    if domNode.hoverCount == 0 then
        domNode.isHovered = false
        self._hoverSet[domNode] = nil
    end

    -- Propagate up to ancestors
    local parent = domNode.parent
    while parent do
        parent.hoverCount = parent.hoverCount - 1
        if parent.hoverCount < 0 then
            parent.hoverCount = 0
        end
        if parent.hoverCount == 0 then
            parent.isHovered = false
            self._hoverSet[parent] = nil
        end
        parent = parent.parent
    end
end

---------------------------------------------------------------------------
-- Query
---------------------------------------------------------------------------

--- Check if a specific DOM node is currently hovered.
--- @param domNode AnglesUI.DomNode
--- @return boolean
function HoverTracker:IsHovered(domNode)
    return domNode.hoverCount > 0
end

--- Get the full hover set (table of DomNode → true for all hovered nodes).
--- Suitable for passing to CssSelectorEngine / CssCascade.
--- @return table<AnglesUI.DomNode, boolean>
function HoverTracker:GetHoverSet()
    return self._hoverSet
end

--- Reset all hover state (e.g. when UI is hidden).
function HoverTracker:Reset()
    for node, _ in pairs(self._hoverSet) do
        node.hoverCount = 0
        node.isHovered = false
    end
    self._hoverSet = {}
end

--- Get the list of DOM nodes whose hover state changed and may need
--- CSS re-evaluation. After calling, the dirty list is cleared.
--- Note: In practice, the cascade should re-run for hovered nodes and
--- their subtrees after any hover change. The caller is responsible for
--- deciding granularity.
--- @return AnglesUI.DomNode[] changedNodes Nodes whose hover state just changed
function HoverTracker:GetDirtyNodes()
    local dirty = {}
    for node, _ in pairs(self._hoverSet) do
        if node.isDirty then
            dirty[#dirty + 1] = node
        end
    end
    return dirty
end

return HoverTracker
