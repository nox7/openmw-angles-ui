--- AnglesUI CSS Selector Engine.
--- Parses raw selector text into structured selector objects and provides
--- matching logic to test whether a DOM element satisfies a given selector.
---
--- Supported selector features:
---   - Tag selectors: `mw-text`, `mw-flex`
---   - Class selectors: `.my-class`
---   - ID selectors: `#my-id`
---   - Universal selector: `*`
---   - Combinators: descendant (space), child (`>`), adjacent sibling (`+`),
---     general sibling (`~`)
---   - Pseudo-selectors: `:hover`, `:host`, `:host(selector)`, `:not(selector)`
---   - Compound selectors: `mw-text.active:hover`
---   - Selector lists: `.a, .b` (comma-separated)
---   - Ampersand nesting reference: `&`

---------------------------------------------------------------------------
-- Types
---------------------------------------------------------------------------

--- @class AnglesUI.SimpleSelector
--- @field tag string? Tag name (nil = any)
--- @field id string? ID constraint
--- @field classes string[] Class constraints
--- @field pseudos AnglesUI.PseudoSelector[] Pseudo-selectors
--- @field isUniversal boolean True if the `*` selector
--- @field isAmpersand boolean True if the `&` nesting reference

--- @class AnglesUI.PseudoSelector
--- @field name string "hover", "host", "not"
--- @field argument AnglesUI.SimpleSelector[]? For :host(sel) and :not(sel), the inner selector

--- @class AnglesUI.SelectorSegment
--- @field combinator string? " " (descendant), ">" (child), "+" (adjacent), "~" (general). nil for the first segment.
--- @field simple AnglesUI.SimpleSelector

--- A full selector is a chain of segments. e.g. `mw-root > .foo .bar:hover`
--- becomes 3 segments: [{nil, mw-root}, {">", .foo}, {" ", .bar:hover}]
--- @alias AnglesUI.Selector AnglesUI.SelectorSegment[]

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

--- @class AnglesUI.CssSelectorEngine
local CssSelectorEngine = {}

---------------------------------------------------------------------------
-- Selector parsing
---------------------------------------------------------------------------

--- Trim whitespace from both ends of a string.
--- @param s string
--- @return string
local function trim(s)
    return s:match("^%s*(.-)%s*$")
end

--- Parse a simple (compound) selector string like `mw-text.active#id:hover`.
--- @param text string
--- @return AnglesUI.SimpleSelector
local function parseSimpleSelector(text)
    --- @type AnglesUI.SimpleSelector
    local sel = {
        tag = nil,
        id = nil,
        classes = {},
        pseudos = {},
        isUniversal = false,
        isAmpersand = false,
    }

    local pos = 1
    local len = #text

    -- Helper: read an identifier starting at pos
    local function readIdent()
        local start = pos
        while pos <= len do
            local ch = text:sub(pos, pos)
            if ch:match("[a-zA-Z0-9_%-]") then
                pos = pos + 1
            else
                break
            end
        end
        return text:sub(start, pos - 1)
    end

    -- Helper: read balanced parentheses content
    local function readParenContent()
        if pos > len or text:sub(pos, pos) ~= "(" then return "" end
        pos = pos + 1 -- skip (
        local depth = 1
        local start = pos
        while pos <= len and depth > 0 do
            local ch = text:sub(pos, pos)
            if ch == "(" then
                depth = depth + 1
            elseif ch == ")" then
                depth = depth - 1
            end
            if depth > 0 then pos = pos + 1 end
        end
        local content = text:sub(start, pos - 1)
        if pos <= len then pos = pos + 1 end -- skip )
        return content
    end

    while pos <= len do
        local ch = text:sub(pos, pos)

        if ch == "*" then
            sel.isUniversal = true
            pos = pos + 1

        elseif ch == "&" then
            sel.isAmpersand = true
            pos = pos + 1

        elseif ch == "." then
            pos = pos + 1
            local cls = readIdent()
            if #cls > 0 then
                sel.classes[#sel.classes + 1] = cls
            end

        elseif ch == "#" then
            pos = pos + 1
            sel.id = readIdent()

        elseif ch == ":" then
            pos = pos + 1
            local pseudoName = readIdent()

            if pos <= len and text:sub(pos, pos) == "(" then
                local argText = readParenContent()
                argText = trim(argText)

                --- @type AnglesUI.PseudoSelector
                local pseudo = {
                    name = pseudoName,
                    argument = nil,
                }

                if #argText > 0 then
                    pseudo.argument = { parseSimpleSelector(argText) }
                end

                sel.pseudos[#sel.pseudos + 1] = pseudo
            else
                sel.pseudos[#sel.pseudos + 1] = {
                    name = pseudoName,
                    argument = nil,
                }
            end

        elseif ch:match("[a-zA-Z_]") then
            sel.tag = readIdent()

        else
            -- Unknown character, skip
            pos = pos + 1
        end
    end

    return sel
end

--- Split a selector string on commas into individual selector strings.
--- @param selectorText string
--- @return string[]
local function splitOnCommas(selectorText)
    local parts = {}
    local depth = 0
    local current = ""

    for i = 1, #selectorText do
        local ch = selectorText:sub(i, i)
        if ch == "(" then
            depth = depth + 1
            current = current .. ch
        elseif ch == ")" then
            depth = depth - 1
            current = current .. ch
        elseif ch == "," and depth == 0 then
            parts[#parts + 1] = trim(current)
            current = ""
        else
            current = current .. ch
        end
    end

    local trimmed = trim(current)
    if #trimmed > 0 then
        parts[#parts + 1] = trimmed
    end

    return parts
end

--- Tokenize a single selector string into segments with combinators.
--- e.g. "mw-root > .foo .bar" → [{nil, mw-root}, {">", .foo}, {" ", .bar}]
--- @param selectorStr string
--- @return AnglesUI.Selector
local function parseSingleSelector(selectorStr)
    --- @type AnglesUI.SelectorSegment[]
    local segments = {}
    local pos = 1
    local len = #selectorStr

    local function skipSpaces()
        while pos <= len and selectorStr:sub(pos, pos):match("%s") do
            pos = pos + 1
        end
    end

    --- Read a compound selector (everything until whitespace or combinator).
    --- @return string
    local function readCompound()
        local start = pos
        local depth = 0
        while pos <= len do
            local ch = selectorStr:sub(pos, pos)
            if ch == "(" then
                depth = depth + 1
            elseif ch == ")" then
                depth = depth - 1
            end
            if depth == 0 and (ch == " " or ch == "\t" or ch == "\n" or ch == ">" or ch == "+" or ch == "~") then
                break
            end
            pos = pos + 1
        end
        return selectorStr:sub(start, pos - 1)
    end

    skipSpaces()
    while pos <= len do
        -- Read the compound selector
        local compound = readCompound()
        if #compound > 0 then
            local combinator = nil
            if #segments > 0 then
                -- The combinator was determined before this compound
                combinator = segments._pendingCombinator or " "
            end
            segments._pendingCombinator = nil

            segments[#segments + 1] = {
                combinator = combinator,
                simple = parseSimpleSelector(compound),
            }
        end

        skipSpaces()
        if pos > len then break end

        -- Check for explicit combinator
        local ch = selectorStr:sub(pos, pos)
        if ch == ">" or ch == "+" or ch == "~" then
            segments._pendingCombinator = ch
            pos = pos + 1
            skipSpaces()
        else
            -- Implicit descendant combinator (space) — already skipped spaces
            segments._pendingCombinator = " "
        end
    end

    -- Clean up temp field
    segments._pendingCombinator = nil

    return segments
end

--- Parse a raw selector text (possibly comma-separated) into an array of
--- parsed selector chains.
--- @param selectorText string
--- @return AnglesUI.Selector[]
---@nodiscard
function CssSelectorEngine.Parse(selectorText)
    local parts = splitOnCommas(selectorText)
    local selectors = {}
    for i = 1, #parts do
        selectors[#selectors + 1] = parseSingleSelector(parts[i])
    end
    return selectors
end

---------------------------------------------------------------------------
-- Specificity calculation
---------------------------------------------------------------------------

--- Calculate CSS specificity for a single selector chain.
--- Returns {a, b, c} where:
---   a = number of ID selectors
---   b = number of class selectors, attribute selectors, and pseudo-classes
---   c = number of type (tag) selectors and pseudo-elements
--- @param selector AnglesUI.Selector
--- @return integer a
--- @return integer b
--- @return integer c
---@nodiscard
function CssSelectorEngine.Specificity(selector)
    local a, b, c = 0, 0, 0

    for _, segment in ipairs(selector) do
        local s = segment.simple
        if s.id then a = a + 1 end
        b = b + #s.classes
        if s.tag and not s.isUniversal then c = c + 1 end

        for _, pseudo in ipairs(s.pseudos) do
            if pseudo.name == "not" then
                -- :not() specificity = specificity of its argument
                if pseudo.argument then
                    for _, argSel in ipairs(pseudo.argument) do
                        if argSel.id then a = a + 1 end
                        b = b + #(argSel.classes or {})
                        if argSel.tag and not argSel.isUniversal then c = c + 1 end
                    end
                end
            elseif pseudo.name == "host" then
                -- :host itself contributes to pseudo-class count
                b = b + 1
                if pseudo.argument then
                    for _, argSel in ipairs(pseudo.argument) do
                        if argSel.id then a = a + 1 end
                        b = b + #(argSel.classes or {})
                        if argSel.tag and not argSel.isUniversal then c = c + 1 end
                    end
                end
            else
                -- :hover and other pseudo-classes
                b = b + 1
            end
        end
    end

    return a, b, c
end

--- Compare two specificity tuples. Returns true if (a1,b1,c1) > (a2,b2,c2).
--- @param a1 integer
--- @param b1 integer
--- @param c1 integer
--- @param a2 integer
--- @param b2 integer
--- @param c2 integer
--- @return boolean
---@nodiscard
function CssSelectorEngine.CompareSpecificity(a1, b1, c1, a2, b2, c2)
    if a1 ~= a2 then return a1 > a2 end
    if b1 ~= b2 then return b1 > b2 end
    return c1 > c2
end

---------------------------------------------------------------------------
-- Selector matching
---------------------------------------------------------------------------

--- Get an element's classes as a set (table with class names as keys).
--- Expects the element to have an `attributes` list (from HtmlNodes).
--- @param element AnglesUI.ElementNode
--- @return table<string, boolean>
local function getClassSet(element)
    local set = {}
    if not element.attributes then return set end
    for _, attr in ipairs(element.attributes) do
        if attr.name == "class" and attr.value then
            for cls in attr.value:gmatch("%S+") do
                set[cls] = true
            end
        end
    end
    return set
end

--- Get an element's ID.
--- @param element AnglesUI.ElementNode
--- @return string?
local function getId(element)
    if not element.attributes then return nil end
    for _, attr in ipairs(element.attributes) do
        if attr.name == "id" then
            return attr.value
        end
    end
    return nil
end

--- Check if a simple (compound) selector matches an element.
--- `hoverSet` is an optional table<element, boolean> indicating which
--- elements are currently hovered.
--- `hostElement` is the host element for :host matching (user components).
--- @param simple AnglesUI.SimpleSelector
--- @param element AnglesUI.ElementNode
--- @param hoverSet? table<any, boolean>
--- @param hostElement? AnglesUI.ElementNode
--- @return boolean
function CssSelectorEngine.MatchSimple(simple, element, hoverSet, hostElement)
    -- Tag check
    if simple.tag and simple.tag ~= element.tag then
        return false
    end

    -- ID check
    if simple.id then
        if getId(element) ~= simple.id then
            return false
        end
    end

    -- Classes check
    if #simple.classes > 0 then
        local classSet = getClassSet(element)
        for _, cls in ipairs(simple.classes) do
            if not classSet[cls] then
                return false
            end
        end
    end

    -- Pseudo-selectors
    for _, pseudo in ipairs(simple.pseudos) do
        if pseudo.name == "hover" then
            if not hoverSet or not hoverSet[element] then
                return false
            end
        elseif pseudo.name == "host" then
            -- :host matches only the host element
            if element ~= hostElement then
                return false
            end
            -- :host(selector) — must also match the inner selector
            if pseudo.argument then
                for _, argSel in ipairs(pseudo.argument) do
                    if not CssSelectorEngine.MatchSimple(argSel, element, hoverSet, hostElement) then
                        return false
                    end
                end
            end
        elseif pseudo.name == "not" then
            -- :not(selector) — must NOT match the inner selector
            if pseudo.argument then
                local anyMatch = false
                for _, argSel in ipairs(pseudo.argument) do
                    if CssSelectorEngine.MatchSimple(argSel, element, hoverSet, hostElement) then
                        anyMatch = true
                        break
                    end
                end
                if anyMatch then return false end
            end
        end
        -- Unknown pseudo-selectors are ignored (future-proofing)
    end

    return true
end

--- Check if a full selector chain matches an element.
--- Works right-to-left: the rightmost segment must match the target element,
--- then combinators are resolved by walking up the DOM tree.
--- @param selector AnglesUI.Selector
--- @param element AnglesUI.ElementNode
--- @param hoverSet? table<any, boolean>
--- @param hostElement? AnglesUI.ElementNode
--- @return boolean
function CssSelectorEngine.Match(selector, element, hoverSet, hostElement)
    if #selector == 0 then return false end

    -- The rightmost (last) segment must match the target element
    local lastSegment = selector[#selector]
    if not CssSelectorEngine.MatchSimple(lastSegment.simple, element, hoverSet, hostElement) then
        return false
    end

    -- Walk backwards through the selector chain
    local currentElement = element
    for i = #selector - 1, 1, -1 do
        local segment = selector[i]
        local combinator = selector[i + 1].combinator

        if combinator == ">" then
            -- Child combinator: parent must match
            local parent = currentElement.parent
            if not parent or parent.type ~= "Element" then return false end
            --- @cast parent AnglesUI.ElementNode
            if not CssSelectorEngine.MatchSimple(segment.simple, parent, hoverSet, hostElement) then
                return false
            end
            currentElement = parent

        elseif combinator == " " then
            -- Descendant combinator: any ancestor must match
            local ancestor = currentElement.parent
            local found = false
            while ancestor do
                if ancestor.type == "Element" then
                    --- @cast ancestor AnglesUI.ElementNode
                    if CssSelectorEngine.MatchSimple(segment.simple, ancestor, hoverSet, hostElement) then
                        currentElement = ancestor
                        found = true
                        break
                    end
                end
                ancestor = ancestor.parent
            end
            if not found then return false end

        elseif combinator == "+" then
            -- Adjacent sibling: the immediately preceding sibling must match
            local sibling = CssSelectorEngine._getPreviousSibling(currentElement)
            if not sibling or sibling.type ~= "Element" then return false end
            --- @cast sibling AnglesUI.ElementNode
            if not CssSelectorEngine.MatchSimple(segment.simple, sibling, hoverSet, hostElement) then
                return false
            end
            currentElement = sibling

        elseif combinator == "~" then
            -- General sibling: any preceding sibling must match
            local found = false
            local siblings = CssSelectorEngine._getPrecedingSiblings(currentElement)
            for _, sib in ipairs(siblings) do
                if sib.type == "Element" then
                    --- @cast sib AnglesUI.ElementNode
                    if CssSelectorEngine.MatchSimple(segment.simple, sib, hoverSet, hostElement) then
                        currentElement = sib
                        found = true
                        break
                    end
                end
            end
            if not found then return false end
        end
    end

    return true
end

--- Check if any selector in a list matches the element.
--- @param selectors AnglesUI.Selector[]
--- @param element AnglesUI.ElementNode
--- @param hoverSet? table<any, boolean>
--- @param hostElement? AnglesUI.ElementNode
--- @return boolean
function CssSelectorEngine.MatchAny(selectors, element, hoverSet, hostElement)
    for _, selector in ipairs(selectors) do
        if CssSelectorEngine.Match(selector, element, hoverSet, hostElement) then
            return true
        end
    end
    return false
end

---------------------------------------------------------------------------
-- Sibling helpers (require parent.children to be set)
---------------------------------------------------------------------------

--- Get the immediately preceding element sibling of a node.
---@private
--- @param element AnglesUI.BaseNode
--- @return AnglesUI.BaseNode?
function CssSelectorEngine._getPreviousSibling(element)
    local parent = element.parent
    if not parent then return nil end

    --- @type AnglesUI.BaseNode[]?
    local children = parent.children
    if not children then return nil end

    local prevElement = nil
    for _, child in ipairs(children) do
        if child == element then
            return prevElement
        end
        if child.type == "Element" then
            prevElement = child
        end
    end
    return nil
end

--- Get all preceding element siblings of a node (in document order).
---@private
--- @param element AnglesUI.BaseNode
--- @return AnglesUI.BaseNode[]
function CssSelectorEngine._getPrecedingSiblings(element)
    local parent = element.parent
    if not parent then return {} end

    --- @type AnglesUI.BaseNode[]?
    local children = parent.children
    if not children then return {} end

    local result = {}
    for _, child in ipairs(children) do
        if child == element then break end
        if child.type == "Element" then
            result[#result + 1] = child
        end
    end
    return result
end

---------------------------------------------------------------------------
-- Nested selector resolution
---------------------------------------------------------------------------

--- Resolve nested selectors by expanding `&` references and prepending parent
--- selectors. For example, if the parent is `mw-root` and the nested selector
--- is `& > .child`, the result is `mw-root > .child`.
--- If no `&` is present, the parent is prepended as a descendant combinator.
--- @param parentSelectorText string The parent rule's selector text
--- @param nestedSelectorText string The nested rule's selector text
--- @return string resolvedText The fully resolved selector text
function CssSelectorEngine.ResolveNested(parentSelectorText, nestedSelectorText)
    local trimmedNested = trim(nestedSelectorText)
    local trimmedParent = trim(parentSelectorText)

    if #trimmedParent == 0 then
        return trimmedNested
    end

    -- If & is present, replace it with the parent selector
    if trimmedNested:find("&", 1, true) then
        return trimmedNested:gsub("&", trimmedParent)
    end

    -- If the nested selector starts with a pseudo-class, append to parent
    if trimmedNested:sub(1, 1) == ":" then
        return trimmedParent .. trimmedNested
    end

    -- Otherwise, prepend parent as descendant
    return trimmedParent .. " " .. trimmedNested
end

return CssSelectorEngine
