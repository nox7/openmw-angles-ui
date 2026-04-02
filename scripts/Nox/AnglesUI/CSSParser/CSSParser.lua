---@class CSSParser Parses a CSS source string into a structured stylesheet model and provides CSS cascade and selector-matching utilities.
local CSSParser = {}
CSSParser.__index = CSSParser

-- Module-level parsed-selector cache.  Populated on the first parse of each
-- unique selector string; keyed by the raw string.  CSS files are static so
-- the cache never needs to be invalidated.
local _parsedSelectorCache = {}

---@return CSSParser
function CSSParser.New()
  local self = setmetatable({}, CSSParser)
  return self
end

-- ─── Public API ──────────────────────────────────────────────────────────────

-- Parse a CSS source string.
-- Returns:
--   {
--     rules        = { { selectors={...}, declarations={prop=val} }, ... }
--     mediaQueries = { { type="max-width"|"min-width", value=N, rules={...} }, ... }
--   }
---@param cssSource string|nil The raw CSS source text to parse.
---@return {rules: table[], mediaQueries: table[], containerQueryRules: table[]} The parsed stylesheet model.
function CSSParser:Parse(cssSource)
  if (cssSource == nil or cssSource == "") then
    return { rules = {}, mediaQueries = {}, containerQueryRules = {} }
  end

  self.source = cssSource
  self.pos = 1
  self.length = #cssSource

  local stylesheet = { rules = {}, mediaQueries = {}, containerQueryRules = {} }
  self:ParseStylesheet(stylesheet)
  return stylesheet
end

-- Parse a simple (non-compound) selector string into { tag, classes, id, specificity }.
---@param selectorStr string A simple selector string (e.g. "mw-flex.my-class#my-id").
---@return {tag: string|nil, classes: string[], id: string|nil, pseudos: table[], specificity: integer}
function CSSParser.ParseSimpleSelectorPart(selectorStr)
  local tag = nil
  local classes = {}
  local id = nil

  local idPart = string.match(selectorStr, "#([%w_%-]+)")
  if (idPart ~= nil) then
    id = idPart
  end

  for classPart in string.gmatch(selectorStr, "%.([%w_%-]+)") do
    table.insert(classes, classPart)
  end

  local tagPart = string.match(selectorStr, "^([%w_%-]+)")
  if (tagPart ~= nil and tagPart ~= "") then
    tag = tagPart
  end

  -- Parse pseudo-selectors: :nth-child(n), :first-child, :not(selector)
  local pseudos = {}
  local i = 1
  while i <= #selectorStr do
    local colonPos = selectorStr:find(":", i, true)
    if (colonPos == nil) then break end
    local rest = selectorStr:sub(colonPos)
    local nthArg = rest:match("^:nth%-child%((.-)%)")
    if (nthArg ~= nil) then
      table.insert(pseudos, { type = "nth-child", value = nthArg })
      i = colonPos + 11 + #nthArg + 1   -- len(":nth-child(") + arg + len(")")
    elseif (rest:sub(1, 12) == ":first-child") then
      table.insert(pseudos, { type = "nth-child", value = "1" })
      i = colonPos + 12
    else
      local notArg = rest:match("^:not%((.-)%)")
      if (notArg ~= nil) then
        table.insert(pseudos, { type = "not", value = notArg })
        i = colonPos + 5 + #notArg + 1  -- len(":not(") + arg + len(")")
      else
        i = colonPos + 1
      end
    end
  end

  local specificity = (id ~= nil and 100 or 0) + (#classes * 10) + (tag ~= nil and 1 or 0) + (#pseudos * 10)

  return { tag = tag, classes = classes, id = id, pseudos = pseudos, specificity = specificity }
end

-- Parse a compound selector string (e.g. "mw-flex > mw-widget.my-class") into its parts and combinators.
-- Returns: { parts = { {tag, classes, id, specificity}, ... }, combinators = { ">"|" "|"~"|"+ ", ... }, specificity = N }
-- For simple selectors (no combinators), parts has one element and combinators is empty.
---@param selectorStr string The full compound selector string.
---@return {parts: table[], combinators: string[], specificity: integer}
function CSSParser.ParseSelectorParts(selectorStr)
  local cached = _parsedSelectorCache[selectorStr]
  if (cached ~= nil) then return cached end

  local parts = {}
  local combinators = {}
  local n = #selectorStr
  local i = 1
  local currentToken = ""
  local pendingCombinator = nil
  local lastWasSelector = false

  local function flushToken()
    local trimmed = currentToken:match("^%s*(.-)%s*$")
    if (trimmed ~= "") then
      if (lastWasSelector) then
        table.insert(combinators, pendingCombinator or " ")
        pendingCombinator = nil
      end
      table.insert(parts, CSSParser.ParseSimpleSelectorPart(trimmed))
      lastWasSelector = true
    end
    currentToken = ""
  end

  while (i <= n) do
    local ch = selectorStr:sub(i, i)
    if (ch == ">" or ch == "~" or ch == "+") then
      flushToken()
      pendingCombinator = ch
    elseif (ch == " " or ch == "\t" or ch == "\n" or ch == "\r") then
      flushToken()
      if (pendingCombinator == nil and lastWasSelector) then
        pendingCombinator = " "
      end
    else
      currentToken = currentToken .. ch
    end
    i = i + 1
  end
  flushToken()

  if (#parts == 0) then
    local result = { parts = {}, combinators = {}, specificity = 0 }
    _parsedSelectorCache[selectorStr] = result
    return result
  end

  local totalSpecificity = 0
  for _, part in ipairs(parts) do
    totalSpecificity = totalSpecificity + part.specificity
  end

  local result = { parts = parts, combinators = combinators, specificity = totalSpecificity }
  _parsedSelectorCache[selectorStr] = result
  return result
end

-- Evaluates an :nth-child argument string against a 1-based child position.
-- Supports integers, "odd", "even", and an+b expressions (e.g. "2n+1", "3n", "-n+3").
---@param arg string The :nth-child argument string (e.g. "2n+1", "odd", "3").
---@param position integer The 1-based index of the element among its element siblings.
---@return boolean True when the position satisfies the nth-child expression.
function CSSParser.EvaluateNthChildArg(arg, position)
  local trimmed = (arg or ""):match("^%s*(.-)%s*$")

  if (trimmed == "odd")  then return position % 2 == 1 end
  if (trimmed == "even") then return position % 2 == 0 end

  -- Pure integer
  local n = tonumber(trimmed)
  if (n ~= nil) then return position == math.floor(n) end

  -- "n" alone → matches every positive position
  if (trimmed == "n") then return position >= 1 end

  -- an+b or an-b  (e.g. "2n+1", "3n", "-n+3", "n+2")
  local aStr, sign, bStr = trimmed:match("^([%+%-]?%d*)n%s*([%+%-])%s*(%d+)$")
  if (aStr ~= nil) then
    local a = (aStr == "" or aStr == "+") and 1 or (aStr == "-" and -1 or tonumber(aStr) or 1)
    local b = tonumber(bStr) or 0
    if (sign == "-") then b = -b end
    if (a == 0) then return position == b end
    local diff = position - b
    return diff >= 0 and diff % a == 0
  end

  -- an (no b term, e.g. "3n")
  local aStr2 = trimmed:match("^([%+%-]?%d*)n$")
  if (aStr2 ~= nil) then
    local a = (aStr2 == "" or aStr2 == "+") and 1 or (aStr2 == "-" and -1 or tonumber(aStr2) or 1)
    if (a <= 0) then return false end
    return position >= 1 and position % a == 0
  end

  return false
end

-- Returns true if a simple selector part matches a given node.
---@param part {tag: string|nil, classes: string[], id: string|nil, pseudos: table[], specificity: integer} Parsed simple selector part.
---@param node Node The node to test.
---@param ancestors Node[]|nil Ordered ancestor chain from root to the immediate parent (required for pseudo-class evaluation).
---@return boolean True when the node satisfies all criteria in the selector part.
function CSSParser.SimplePartMatchesNode(part, node, ancestors)
  if (part.tag == nil and part.id == nil and #part.classes == 0 and #(part.pseudos or {}) == 0) then
    return false
  end

  if (part.tag ~= nil and node.tagName ~= part.tag) then
    return false
  end

  if (part.id ~= nil) then
    local nodeId = node.attributes and node.attributes["id"] or nil
    if (nodeId ~= part.id) then
      return false
    end
  end

  if (#part.classes > 0) then
    local nodeClassStr = (node.attributes and node.attributes["class"]) or ""
    local nodeClassSet = {}
    for cls in string.gmatch(nodeClassStr, "%S+") do
      nodeClassSet[cls] = true
    end
    for _, cls in ipairs(part.classes) do
      if (not nodeClassSet[cls]) then
        return false
      end
    end
  end

  -- Evaluate pseudo-selectors.
  for _, pseudo in ipairs(part.pseudos or {}) do
    if (pseudo.type == "nth-child") then
      local parent = (ancestors ~= nil) and ancestors[#ancestors] or nil
      if (parent == nil) then return false end
      -- Count the node's 1-based position among element siblings (nodes with a tagName).
      -- Text nodes do not have tagName and are excluded from the count.
      local pos = 0
      local found = false
      for _, sibling in ipairs(parent.children or {}) do
        if (sibling.tagName ~= nil) then
          pos = pos + 1
          if (sibling == node) then
            found = true
            break
          end
        end
      end
      if (not found or not CSSParser.EvaluateNthChildArg(pseudo.value, pos)) then
        return false
      end
    elseif (pseudo.type == "not") then
      local innerParsed = CSSParser.ParseSelectorParts(pseudo.value)
      if (CSSParser.SelectorMatchesNode(innerParsed, node, ancestors)) then
        return false
      end
    end
  end

  return true
end

-- Returns true if a parsed compound selector matches a given node with its ancestor chain.
-- parsedSelector: result of ParseSelectorParts ({ parts, combinators, specificity })
-- node: the node being matched
-- ancestors: ordered list of ancestor nodes from root to immediate parent (optional)
---@param parsedSelector {parts: table[], combinators: string[], specificity: integer} The parsed compound selector.
---@param node Node The node to test.
---@param ancestors Node[]|nil Ordered ancestor chain from root to the immediate parent.
---@return boolean True when the full compound selector matches the node.
function CSSParser.SelectorMatchesNode(parsedSelector, node, ancestors)
  if (#parsedSelector.parts == 0) then
    return false
  end

  ancestors = ancestors or {}

  if (not CSSParser.SimplePartMatchesNode(parsedSelector.parts[#parsedSelector.parts], node, ancestors)) then
    return false
  end

  if (#parsedSelector.parts == 1) then
    return true
  end

  local selectorPartIndex = #parsedSelector.parts - 1
  local ancestorIndex = #ancestors

  while (selectorPartIndex >= 1) do
    local combinator = parsedSelector.combinators[selectorPartIndex]
    local part = parsedSelector.parts[selectorPartIndex]
    local partHasPseudos = (part.pseudos ~= nil and #part.pseudos > 0)

    if (combinator == ">") then
      if (ancestorIndex < 1) then
        return false
      end
      local ancestorAncestors = nil
      if (partHasPseudos) then
        ancestorAncestors = {}
        for k = 1, ancestorIndex - 1 do
          ancestorAncestors[k] = ancestors[k]
        end
      end
      if (not CSSParser.SimplePartMatchesNode(part, ancestors[ancestorIndex], ancestorAncestors)) then
        return false
      end
      ancestorIndex = ancestorIndex - 1
    elseif (combinator == " ") then
      local found = false
      while (ancestorIndex >= 1) do
        local ancestorAncestors = nil
        if (partHasPseudos) then
          ancestorAncestors = {}
          for k = 1, ancestorIndex - 1 do
            ancestorAncestors[k] = ancestors[k]
          end
        end
        if (CSSParser.SimplePartMatchesNode(part, ancestors[ancestorIndex], ancestorAncestors)) then
          found = true
          ancestorIndex = ancestorIndex - 1
          break
        end
        ancestorIndex = ancestorIndex - 1
      end
      if (not found) then
        return false
      end
    else
      return false
    end

    selectorPartIndex = selectorPartIndex - 1
  end

  return true
end

-- Collect the winning CSS declarations that apply to a node from a list of rules.
-- Later rules and higher specificity win (standard CSS cascade).
-- Returns a flat table: { cssPropertyName = value, ... }
---@param rules table[] Parsed CSS rules from CSSParser:Parse().rules.
---@param node Node The node to match against each rule's selector list.
---@param ancestors Node[]|nil Ordered ancestor chain from root to the immediate parent.
---@return table<string, string> Map of CSS property name to the winning declared value.
function CSSParser.ApplyRulesToNode(rules, node, ancestors)
local declMap = {}

for ruleIndex, rule in ipairs(rules) do
  for _, selectorStr in ipairs(rule.selectors) do
    local parsedSel = CSSParser.ParseSelectorParts(selectorStr)
    if (CSSParser.SelectorMatchesNode(parsedSel, node, ancestors)) then
      for property, value in pairs(rule.declarations) do
        local existing = declMap[property]
        if (existing == nil
          or parsedSel.specificity > existing.specificity
          or (parsedSel.specificity == existing.specificity and ruleIndex >= existing.order)) then
          declMap[property] = { value = value, specificity = parsedSel.specificity, order = ruleIndex }
        end
      end
    end
  end
end

  local result = {}
  for property, entry in pairs(declMap) do
    result[property] = entry.value
  end
  return result
end

-- ─── Parser internals ────────────────────────────────────────────────────────

---@param offset integer|nil Character offset from the current position (default 0).
---@return string|nil
function CSSParser:peek(offset)
  local idx = self.pos + (offset or 0)
  if (idx > self.length) then return nil end
  return string.sub(self.source, idx, idx)
end

---@param len integer Number of characters to peek.
---@return string|nil
function CSSParser:peekString(len)
  if (self.pos + len - 1 > self.length) then return nil end
  return string.sub(self.source, self.pos, self.pos + len - 1)
end

---@param n integer|nil Characters to advance (default 1).
function CSSParser:advance(n)
  self.pos = self.pos + (n or 1)
end

---@return boolean True when the read position is past the end of the source.
function CSSParser:isEOF()
  return self.pos > self.length
end

function CSSParser:skipWhitespace()
  while not self:isEOF() do
    local ch = self:peek()
    if (ch == " " or ch == "\t" or ch == "\n" or ch == "\r") then
      self:advance()
    else
      break
    end
  end
end

function CSSParser:skipWhitespaceAndComments()
  local changed = true
  while changed do
    changed = false
    self:skipWhitespace()
    if (self:peekString(2) == "/*") then
      self:advance(2)
      while not self:isEOF() do
        if (self:peekString(2) == "*/") then
          self:advance(2)
          break
        end
        self:advance()
      end
      changed = true
    end
  end
end

---@param target string The string to stop before.
---@return string All characters consumed before the target (or all remaining if not found).
function CSSParser:readUntil(target)
  local startPos = self.pos
  local targetLen = #target
  while not self:isEOF() do
    if (self:peekString(targetLen) == target) then
      return string.sub(self.source, startPos, self.pos - 1)
    end
    self:advance()
  end
  return string.sub(self.source, startPos, self.pos - 1)
end

---@param str string
---@return string
function CSSParser:trim(str)
  return (string.match(str, "^%s*(.-)%s*$") or str)
end

---@return string The consumed identifier (letters, digits, underscores, hyphens).
function CSSParser:readIdentifier()
  local startPos = self.pos
  while not self:isEOF() do
    local ch = self:peek()
    if (string.match(ch, "[%w_%-]")) then
      self:advance()
    else
      break
    end
  end
  return string.sub(self.source, startPos, self.pos - 1)
end

function CSSParser:skipBlock()
  if (self:peek() ~= "{") then return end
  self:advance()
  local depth = 1
  while not self:isEOF() and depth > 0 do
    local ch = self:peek()
    if (ch == "{") then
      depth = depth + 1
    elseif (ch == "}") then
      depth = depth - 1
    end
    self:advance()
  end
end

-- Returns true if the current position looks like the start of a nested rule
-- (i.e. a `{` appears before any `:` or `;` or `}`).
-- Does not consume any input.
---@return boolean
function CSSParser:IsNestedRuleStart()
  local savedPos = self.pos

  if (self:peek() == "&") then
    self.pos = savedPos
    return true
  end

  while not self:isEOF() do
    local ch = self:peek()
    if (ch == "{") then
      self.pos = savedPos
      return true
    end
    if (ch == ":" or ch == ";" or ch == "}") then
      self.pos = savedPos
      return false
    end
    self:advance()
  end

  self.pos = savedPos
  return false
end

-- Expand a nested selector against its parent context.
-- Examples (parentSel = "#outer-flex"):
--   "& > mw-widget"  ->  "#outer-flex > mw-widget"
--   "& mw-widget"    ->  "#outer-flex mw-widget"
--   "&.my-class"     ->  "#outer-flex.my-class"
--   "&"              ->  "#outer-flex"
--   "mw-widget"      ->  "mw-widget"   (no &, treat as implicit descendant)
---@param parentSel string The fully expanded parent selector string.
---@param nestedSel string The raw nested selector (may contain `&` references).
---@return string The expanded selector with `&` substituted by the parent selector.
function CSSParser:ExpandNestedSelector(parentSel, nestedSel)
  local trimmed = self:trim(nestedSel)

  -- "&" alone → parent selector
  if (trimmed == "&") then
    return parentSel
  end

  -- "&.class" or "&.class1.class2" → append to parent
  local classAppend = string.match(trimmed, "^&([%.#][%S]*)$")
  if (classAppend ~= nil) then
    return parentSel .. classAppend
  end

  -- "& > X", "& ~ X", "& + X" → "parentSel > X" (preserve explicit combinator)
  local combinator, childPart = string.match(trimmed, "^&%s*([>~+])%s*(.+)$")
  if (combinator ~= nil and childPart ~= nil) then
    return parentSel .. " " .. combinator .. " " .. self:trim(childPart)
  end

  -- "& X" (descendant with whitespace) → "parentSel X"
  local descendantPart = string.match(trimmed, "^&%s+(.+)$")
  if (descendantPart ~= nil) then
    return parentSel .. " " .. self:trim(descendantPart)
  end

  -- No & present — implicit descendant combinator (CSS nesting spec).
  return parentSel .. " " .. trimmed
end

-- ─── Grammar rules ───────────────────────────────────────────────────────────

function CSSParser:ParseStylesheet(stylesheet)
  while not self:isEOF() do
    self:skipWhitespaceAndComments()
    if (self:isEOF()) then break end

    -- Stray closing brace (e.g. leftover from a nested rule the outer parser consumed).
    -- Consuming it prevents an infinite loop where ParseRule returns nil without advancing.
    if (self:peek() == "}") then
      self:advance()
    elseif (self:peek() == "@") then
      local mediaQuery = self:ParseAtRule(stylesheet)
      if (mediaQuery ~= nil) then
        table.insert(stylesheet.mediaQueries, mediaQuery)
      end
    else
      local rule, nestedRules = self:ParseRule()
      if (rule ~= nil) then
        table.insert(stylesheet.rules, rule)
      end
      for _, nr in ipairs(nestedRules or {}) do
        table.insert(stylesheet.rules, nr)
      end
    end
  end
end

function CSSParser:ParseAtRule(stylesheet)
  self:advance() -- skip '@'
  local keyword = self:readIdentifier()

  if (keyword ~= "media") then
    if (keyword == "container" and stylesheet ~= nil) then
      self:ParseTopLevelContainerAtRule(stylesheet)
    else
      self:skipWhitespaceAndComments()
      if (self:peek() == "{") then
        self:skipBlock()
      else
        self:readUntil(";")
        if (self:peek() == ";") then self:advance() end
      end
    end
    return nil
  end

  self:skipWhitespaceAndComments()

  if (self:peek() ~= "(") then
    self:skipWhitespaceAndComments()
    if (self:peek() == "{") then self:skipBlock() end
    return nil
  end

  self:advance() -- skip '('
  local conditionContent = self:readUntil(")")
  if (self:peek() == ")") then self:advance() end
  conditionContent = self:trim(conditionContent)

  local conditionType, conditionValue =
    string.match(conditionContent, "^(max%-width)%s*:%s*(%d+%.?%d*)%s*p?x?$")
  if (conditionType == nil) then
    conditionType, conditionValue =
      string.match(conditionContent, "^(min%-width)%s*:%s*(%d+%.?%d*)%s*p?x?$")
  end

  if (conditionType == nil) then
    self:skipWhitespaceAndComments()
    if (self:peek() == "{") then self:skipBlock() end
    return nil
  end

  self:skipWhitespaceAndComments()
  if (self:peek() ~= "{") then return nil end
  self:advance() -- skip '{'

  local mediaRules = {}
  local mediaContainerQueryRules = {}
  while not self:isEOF() do
    self:skipWhitespaceAndComments()
    if (self:peek() == "}") then
      self:advance()
      break
    end
    if (self:peek() == "@") then
      self:advance() -- skip '@'
      local innerKeyword = self:readIdentifier()
      if (innerKeyword == "container") then
        local tempSheet = { containerQueryRules = mediaContainerQueryRules }
        self:ParseTopLevelContainerAtRule(tempSheet)
      else
        self:skipWhitespaceAndComments()
        if (self:peek() == "{") then
          self:skipBlock()
        else
          self:readUntil(";")
          if (self:peek() == ";") then self:advance() end
        end
      end
    else
      local rule, nestedRules = self:ParseRule()
      if (rule ~= nil) then
        table.insert(mediaRules, rule)
      end
      for _, nr in ipairs(nestedRules or {}) do
        table.insert(mediaRules, nr)
      end
    end
  end

  return {
    type = conditionType,
    value = tonumber(conditionValue),
    rules = mediaRules,
    containerQueryRules = mediaContainerQueryRules,
  }
end

-- Parse a CSS rule block.
-- Returns: rule (or nil), nestedRules (list of rules expanded from nested blocks)
---@return table|nil, table[] The top-level rule table (or nil) and any rules from nested blocks.
function CSSParser:ParseRule()
  self:skipWhitespaceAndComments()
  if (self:isEOF() or self:peek() == "}") then return nil, {} end

  local selectorsRaw = self:readUntil("{")
  if (self:peek() ~= "{") then return nil, {} end
  self:advance() -- skip '{'

  local selectors = self:ParseSelectorList(selectorsRaw)
  local declarations = {}
  local nestedRules = {}

  while not self:isEOF() do
    self:skipWhitespaceAndComments()
    if (self:peek() == "}") then
      self:advance()
      break
    end

    if (self:IsNestedRuleStart()) then
      local nestedRule, deeperRules = self:ParseNestedRule(selectors)
      if (nestedRule ~= nil) then
        table.insert(nestedRules, nestedRule)
      end
      for _, dr in ipairs(deeperRules) do
        table.insert(nestedRules, dr)
      end
    else
      local decl = self:ParseDeclaration()
      if (decl ~= nil) then
        declarations[decl.property] = decl.value
      end
    end
  end

  if (#selectors == 0) then return nil, nestedRules end
  return { selectors = selectors, declarations = declarations }, nestedRules
end

-- Parse a nested rule block recursively.
-- Expands `&` references (and implicit descendants) using parentSelectors.
-- Returns: rule (or nil), deeperRules (list of rules from any further-nested blocks).
---@param parentSelectors string[] The expanded selectors of the containing rule used to resolve `&`.
---@return table|nil, table[] The expanded nested rule (or nil) and any rules from further-nested blocks.
function CSSParser:ParseNestedRule(parentSelectors)
  local selectorRaw = self:readUntil("{")
  if (self:peek() ~= "{") then return nil, {} end
  self:advance() -- skip '{'

  -- Compute expanded selectors BEFORE parsing the body so that any deeper
  -- nested rules inside this block can use them as their parent selectors.
  local expandedSelectors = {}
  for _, nestedSel in ipairs(self:ParseSelectorList(selectorRaw)) do
    for _, parentSel in ipairs(parentSelectors) do
      local expanded = self:ExpandNestedSelector(parentSel, nestedSel)
      if (expanded ~= nil and expanded ~= "") then
        table.insert(expandedSelectors, expanded)
      end
    end
  end

  local declarations = {}
  local deeperRules  = {}

  while not self:isEOF() do
    self:skipWhitespaceAndComments()
    if (self:peek() == "}") then
      self:advance()
      break
    end

    if (self:IsNestedRuleStart()) then
      if (#expandedSelectors > 0) then
        -- Recurse: the current expanded selectors become the parent for this deeper block.
        local deepRule, evenDeeperRules = self:ParseNestedRule(expandedSelectors)
        if (deepRule ~= nil) then
          table.insert(deeperRules, deepRule)
        end
        for _, dr in ipairs(evenDeeperRules) do
          table.insert(deeperRules, dr)
        end
      else
        -- No valid parent selectors; discard the unresolvable nested block.
        self:readUntil("{")
        if (self:peek() == "{") then
          self:skipBlock()
        end
      end
    else
      local decl = self:ParseDeclaration()
      if (decl ~= nil) then
        declarations[decl.property] = decl.value
      end
    end
  end

  if (#expandedSelectors == 0) then return nil, deeperRules end
  return { selectors = expandedSelectors, declarations = declarations }, deeperRules
end

---@param rawSelectors string A comma-separated list of selectors (raw, may contain whitespace).
---@return string[] A list of trimmed individual selector strings.
function CSSParser:ParseSelectorList(rawSelectors)
  local selectors = {}
  for part in string.gmatch(rawSelectors, "[^,]+") do
    local trimmed = self:trim(part)
    if (trimmed ~= "") then
      table.insert(selectors, trimmed)
    end
  end
  return selectors
end

---@return {property: string, value: string}|nil The parsed property/value pair, or nil on a parse failure.
function CSSParser:ParseDeclaration()
  self:skipWhitespaceAndComments()
  if (self:isEOF() or self:peek() == "}") then return nil end

  -- Read property name up to ':'
  local property = ""
  while not self:isEOF() do
    local ch = self:peek()
    if (ch == ":" or ch == ";" or ch == "}") then break end
    property = property .. ch
    self:advance()
  end
  property = self:trim(string.lower(property))

  if (self:peek() ~= ":") then
    if (self:peek() == ";") then self:advance() end
    return nil
  end
  self:advance() -- skip ':'

  -- Read value up to ';' or '}'
  local value = ""
  while not self:isEOF() do
    local ch = self:peek()
    if (ch == ";" or ch == "}") then break end
    value = value .. ch
    self:advance()
  end
  if (self:peek() == ";") then self:advance() end

  value = self:trim(value)
  value = string.gsub(value, "(%d+%.?%d*)px", "%1")
  if (property == "" or value == "") then return nil end

  return { property = property, value = value }
end

-- ─── Container query helpers ─────────────────────────────────────────────────

-- Parses a top-level @container (cond) { rules... } block and inserts entries into stylesheet.
---@param stylesheet {containerQueryRules: table[]} The stylesheet table to append container query rule entries to.
function CSSParser:ParseTopLevelContainerAtRule(stylesheet)
  self:skipWhitespaceAndComments()

  -- Check for an optional container name (an identifier before the condition parenthesis).
  -- e.g. @container sidebar (width < 300px) vs @container (width < 300px)
  local containerName = nil
  if (self:peek() ~= "(") then
    local name = self:readIdentifier()
    if (name ~= "") then
      containerName = name
    end
    self:skipWhitespaceAndComments()
  end

  if (self:peek() ~= "(") then
    if (self:peek() == "{") then self:skipBlock() end
    return
  end

  self:advance() -- skip '('
  local conditionContent = self:readUntil(")")
  if (self:peek() == ")") then self:advance() end
  conditionContent = self:trim(conditionContent)

  local condition = CSSParser.ParseContainerCondition(conditionContent)
  if (condition == nil) then
    self:skipWhitespaceAndComments()
    if (self:peek() == "{") then self:skipBlock() end
    return
  end

  self:skipWhitespaceAndComments()
  if (self:peek() ~= "{") then return end
  self:advance() -- skip '{'

  while not self:isEOF() do
    self:skipWhitespaceAndComments()
    if (self:peek() == "}") then
      self:advance()
      break
    end
    local rule, nestedRules = self:ParseRule()
    if (rule ~= nil) then
      table.insert(stylesheet.containerQueryRules, {
        selectors     = rule.selectors,
        condition     = condition,
        declarations  = rule.declarations,
        containerName = containerName,
      })
    end
    for _, nr in ipairs(nestedRules or {}) do
      table.insert(stylesheet.containerQueryRules, {
        selectors     = nr.selectors,
        condition     = condition,
        declarations  = nr.declarations,
        containerName = containerName,
      })
    end
  end
end

-- Parses a container condition string such as "width <= 300" or "max-width: 500".
-- Returns { property, operator, value } or nil if the condition is not recognised.
---@param conditionStr string The condition text from inside the `@container (...)` parentheses.
---@return {property: string, operator: string, value: number}|nil The parsed condition, or nil when unrecognised.
function CSSParser.ParseContainerCondition(conditionStr)
  local str = string.gsub(conditionStr, "(%d+%.?%d*)px", "%1")
  str = str:match("^%s*(.-)%s*$")

  local p, v

  -- Range syntax — check multi-char operators first to avoid partial matches on < / >
  p, v = string.match(str, "^([%w%-]+)%s*<=%s*(%d+%.?%d*)$")
  if (p ~= nil) then return { property = p, operator = "<=", value = tonumber(v) } end

  p, v = string.match(str, "^([%w%-]+)%s*>=%s*(%d+%.?%d*)$")
  if (p ~= nil) then return { property = p, operator = ">=", value = tonumber(v) } end

  p, v = string.match(str, "^([%w%-]+)%s*<%s*(%d+%.?%d*)$")
  if (p ~= nil) then return { property = p, operator = "<", value = tonumber(v) } end

  p, v = string.match(str, "^([%w%-]+)%s*>%s*(%d+%.?%d*)$")
  if (p ~= nil) then return { property = p, operator = ">", value = tonumber(v) } end

  p, v = string.match(str, "^([%w%-]+)%s*=%s*(%d+%.?%d*)$")
  if (p ~= nil) then return { property = p, operator = "=", value = tonumber(v) } end

  -- Colon syntax: "min-width: 300", "max-width: 300", "min-height: 300", "max-height: 300"
  v = string.match(str, "^min%-width%s*:%s*(%d+%.?%d*)$")
  if (v ~= nil) then return { property = "width",  operator = ">=", value = tonumber(v) } end

  v = string.match(str, "^max%-width%s*:%s*(%d+%.?%d*)$")
  if (v ~= nil) then return { property = "width",  operator = "<=", value = tonumber(v) } end

  v = string.match(str, "^min%-height%s*:%s*(%d+%.?%d*)$")
  if (v ~= nil) then return { property = "height", operator = ">=", value = tonumber(v) } end

  v = string.match(str, "^max%-height%s*:%s*(%d+%.?%d*)$")
  if (v ~= nil) then return { property = "height", operator = "<=", value = tonumber(v) } end

  return nil
end

-- Evaluates a container condition { property, operator, value } against a pixel size { x, y }.
-- Returns true when the condition is satisfied, false otherwise.
---@param condition {property: string, operator: string, value: number} The parsed container condition.
---@param containerPixelSize {x: number|nil, y: number|nil}|nil The current pixel size of the named or nearest container.
---@return boolean True when the container size satisfies the condition operator and value.
function CSSParser.EvaluateContainerCondition(condition, containerPixelSize)
  if (containerPixelSize == nil) then return false end

  local containerValue = nil
  if (condition.property == "width") then
    containerValue = containerPixelSize.x
  elseif (condition.property == "height") then
    containerValue = containerPixelSize.y
  else
    return false
  end

  if (containerValue == nil) then return false end

  local op  = condition.operator
  local val = condition.value

  if (op == "<=") then return containerValue <= val
  elseif (op == ">=") then return containerValue >= val
  elseif (op == "<")  then return containerValue <  val
  elseif (op == ">")  then return containerValue >  val
  elseif (op == "=")  then return containerValue == val
  end

  return false
end

-- Applies matching container query rules to a node given its ancestor chain and a containerContext.
-- containerContext = { pixelSize = {x,y}|nil, named = { [name] = {x,y}, ... } }
-- For unnamed @container rules (containerName == nil), containerContext.pixelSize is evaluated.
-- For named @container rules, containerContext.named[containerName] is evaluated.
-- Returns a flat { cssPropertyName = value } table.
---@param containerQueryRules table[] Container query rules from CSSParser:Parse().containerQueryRules.
---@param node Node The node to match selectors against.
---@param ancestors Node[]|nil Ordered ancestor chain from root to the immediate parent.
---@param containerContext {pixelSize: {x:number,y:number}|nil, named: table<string,{x:number,y:number}>}|nil Current container size context.
---@return table<string, string> Map of CSS property name to the winning declared value.
function CSSParser.ApplyContainerRulesToNode(containerQueryRules, node, ancestors, containerContext)
  if (containerContext == nil) then return {} end

  local declMap = {}

  for ruleIndex, cqRule in ipairs(containerQueryRules) do
    local containerPixelSize = nil
    if (cqRule.containerName ~= nil) then
      containerPixelSize = containerContext.named and containerContext.named[cqRule.containerName] or nil
    else
      containerPixelSize = containerContext.pixelSize
    end

    if (containerPixelSize ~= nil and CSSParser.EvaluateContainerCondition(cqRule.condition, containerPixelSize)) then
      for _, selectorStr in ipairs(cqRule.selectors) do
        local parsedSel = CSSParser.ParseSelectorParts(selectorStr)
        if (CSSParser.SelectorMatchesNode(parsedSel, node, ancestors)) then
          for property, value in pairs(cqRule.declarations) do
            local existing = declMap[property]
            if (existing == nil
              or parsedSel.specificity > existing.specificity
              or (parsedSel.specificity == existing.specificity and ruleIndex >= existing.order)) then
              declMap[property] = { value = value, specificity = parsedSel.specificity, order = ruleIndex }
            end
          end
        end
      end
    end
  end

  local result = {}
  for property, entry in pairs(declMap) do
    result[property] = entry.value
  end
  return result
end

return CSSParser