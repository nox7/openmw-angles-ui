local CSSParser = {}
CSSParser.__index = CSSParser

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

  local specificity = (id ~= nil and 100 or 0) + (#classes * 10) + (tag ~= nil and 1 or 0)

  return { tag = tag, classes = classes, id = id, specificity = specificity }
end

-- Parse a compound selector string (e.g. "mw-flex > mw-widget.my-class") into its parts and combinators.
-- Returns: { parts = { {tag, classes, id, specificity}, ... }, combinators = { ">"|" "|"~"|"+ ", ... }, specificity = N }
-- For simple selectors (no combinators), parts has one element and combinators is empty.
function CSSParser.ParseSelectorParts(selectorStr)
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
    return { parts = {}, combinators = {}, specificity = 0 }
  end

  local totalSpecificity = 0
  for _, part in ipairs(parts) do
    totalSpecificity = totalSpecificity + part.specificity
  end

  return { parts = parts, combinators = combinators, specificity = totalSpecificity }
end

-- Returns true if a simple selector part matches a given node.
function CSSParser.SimplePartMatchesNode(part, node)
  if (part.tag == nil and part.id == nil and #part.classes == 0) then
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

  return true
end

-- Returns true if a parsed compound selector matches a given node with its ancestor chain.
-- parsedSelector: result of ParseSelectorParts ({ parts, combinators, specificity })
-- node: the node being matched
-- ancestors: ordered list of ancestor nodes from root to immediate parent (optional)
function CSSParser.SelectorMatchesNode(parsedSelector, node, ancestors)
  if (#parsedSelector.parts == 0) then
    return false
  end

  ancestors = ancestors or {}

  if (not CSSParser.SimplePartMatchesNode(parsedSelector.parts[#parsedSelector.parts], node)) then
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

    if (combinator == ">") then
      if (ancestorIndex < 1) then
        return false
      end
      if (not CSSParser.SimplePartMatchesNode(part, ancestors[ancestorIndex])) then
        return false
      end
      ancestorIndex = ancestorIndex - 1
    elseif (combinator == " ") then
      local found = false
      while (ancestorIndex >= 1) do
        if (CSSParser.SimplePartMatchesNode(part, ancestors[ancestorIndex])) then
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

function CSSParser:peek(offset)
  local idx = self.pos + (offset or 0)
  if (idx > self.length) then return nil end
  return string.sub(self.source, idx, idx)
end

function CSSParser:peekString(len)
  if (self.pos + len - 1 > self.length) then return nil end
  return string.sub(self.source, self.pos, self.pos + len - 1)
end

function CSSParser:advance(n)
  self.pos = self.pos + (n or 1)
end

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

function CSSParser:trim(str)
  return (string.match(str, "^%s*(.-)%s*$") or str)
end

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

  -- No & present — implicit descendant: return as-is
  return trimmed
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
      local rule, nestedRules, inlineCQs = self:ParseRule()
      if (rule ~= nil) then
        table.insert(stylesheet.rules, rule)
      end
      for _, nr in ipairs(nestedRules or {}) do
        table.insert(stylesheet.rules, nr)
      end
      for _, cq in ipairs(inlineCQs or {}) do
        table.insert(stylesheet.containerQueryRules, cq)
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
    local rule, nestedRules, inlineCQs = self:ParseRule()
    if (rule ~= nil) then
      table.insert(mediaRules, rule)
    end
    for _, nr in ipairs(nestedRules or {}) do
      table.insert(mediaRules, nr)
    end
    for _, cq in ipairs(inlineCQs or {}) do
      table.insert(mediaContainerQueryRules, cq)
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
-- Returns: rule (or nil), nestedRules (list of rules expanded from nested blocks), containerQueryRules
function CSSParser:ParseRule()
  self:skipWhitespaceAndComments()
  if (self:isEOF() or self:peek() == "}") then return nil, {}, {} end

  local selectorsRaw = self:readUntil("{")
  if (self:peek() ~= "{") then return nil, {}, {} end
  self:advance() -- skip '{'

  local selectors = self:ParseSelectorList(selectorsRaw)
  local declarations = {}
  local nestedRules = {}
  local containerQueryRules = {}

  while not self:isEOF() do
    self:skipWhitespaceAndComments()
    if (self:peek() == "}") then
      self:advance()
      break
    end

    if (self:peek() == "@") then
      local inlineCQs = self:ParseInlineContainerAtRule(selectors)
      for _, cq in ipairs(inlineCQs) do
        table.insert(containerQueryRules, cq)
      end
    elseif (self:IsNestedRuleStart()) then
      local nestedRule = self:ParseNestedRule(selectors)
      if (nestedRule ~= nil) then
        table.insert(nestedRules, nestedRule)
      end
    else
      local decl = self:ParseDeclaration()
      if (decl ~= nil) then
        declarations[decl.property] = decl.value
      end
    end
  end

  if (#selectors == 0) then return nil, nestedRules, containerQueryRules end
  return { selectors = selectors, declarations = declarations }, nestedRules, containerQueryRules
end

-- Parse a nested rule block (e.g. "& > mw-widget { ... }") inside a parent rule.
-- Expands `&` references using parentSelectors and returns a flat rule.
function CSSParser:ParseNestedRule(parentSelectors)
  local selectorRaw = self:readUntil("{")
  if (self:peek() ~= "{") then return nil end
  self:advance() -- skip '{'

  local declarations = {}

  while not self:isEOF() do
    self:skipWhitespaceAndComments()
    if (self:peek() == "}") then
      self:advance()
      break
    end

    -- Skip any further nesting (we only expand one level deep)
    if (self:IsNestedRuleStart()) then
      local skipRaw = self:readUntil("{")
      if (self:peek() == "{") then
        self:skipBlock()
      end
    else
      local decl = self:ParseDeclaration()
      if (decl ~= nil) then
        declarations[decl.property] = decl.value
      end
    end
  end

  local expandedSelectors = {}
  for _, nestedSel in ipairs(self:ParseSelectorList(selectorRaw)) do
    for _, parentSel in ipairs(parentSelectors) do
      local expanded = self:ExpandNestedSelector(parentSel, nestedSel)
      if (expanded ~= nil and expanded ~= "") then
        table.insert(expandedSelectors, expanded)
      end
    end
  end

  if (#expandedSelectors == 0) then return nil end
  return { selectors = expandedSelectors, declarations = declarations }
end

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
function CSSParser:ParseTopLevelContainerAtRule(stylesheet)
  self:skipWhitespaceAndComments()

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
        selectors    = rule.selectors,
        condition    = condition,
        declarations = rule.declarations,
      })
    end
    for _, nr in ipairs(nestedRules or {}) do
      table.insert(stylesheet.containerQueryRules, {
        selectors    = nr.selectors,
        condition    = condition,
        declarations = nr.declarations,
      })
    end
  end
end

-- Parses an inline @container (cond) { declarations } block nested inside a CSS rule.
-- Returns a list of { selectors, condition, declarations } entries (may be empty).
function CSSParser:ParseInlineContainerAtRule(parentSelectors)
  self:advance() -- skip '@'
  local keyword = self:readIdentifier()

  if (keyword ~= "container") then
    self:skipWhitespaceAndComments()
    if (self:peek() == "{") then
      self:skipBlock()
    else
      self:readUntil(";")
      if (self:peek() == ";") then self:advance() end
    end
    return {}
  end

  self:skipWhitespaceAndComments()
  if (self:peek() ~= "(") then
    self:skipWhitespaceAndComments()
    if (self:peek() == "{") then self:skipBlock() end
    return {}
  end

  self:advance() -- skip '('
  local conditionContent = self:readUntil(")")
  if (self:peek() == ")") then self:advance() end
  conditionContent = self:trim(conditionContent)

  local condition = CSSParser.ParseContainerCondition(conditionContent)
  if (condition == nil) then
    self:skipWhitespaceAndComments()
    if (self:peek() == "{") then self:skipBlock() end
    return {}
  end

  self:skipWhitespaceAndComments()
  if (self:peek() ~= "{") then return {} end
  self:advance() -- skip '{'

  local declarations = {}
  while not self:isEOF() do
    self:skipWhitespaceAndComments()
    if (self:peek() == "}") then
      self:advance()
      break
    end
    if (self:peek() == "@") then
      -- Skip unknown nested at-rules
      self:advance()
      self:readUntil("{")
      if (self:peek() == "{") then self:skipBlock() end
    elseif (self:IsNestedRuleStart()) then
      -- Skip nested selector blocks
      self:readUntil("{")
      if (self:peek() == "{") then self:skipBlock() end
    else
      local decl = self:ParseDeclaration()
      if (decl ~= nil) then
        declarations[decl.property] = decl.value
      end
    end
  end

  if (next(declarations) == nil) then return {} end

  return {
    {
      selectors    = parentSelectors,
      condition    = condition,
      declarations = declarations,
    }
  }
end

-- Parses a container condition string such as "width <= 300" or "max-width: 500".
-- Returns { property, operator, value } or nil if the condition is not recognised.
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

-- Applies matching container query rules to a node given its ancestor chain and the nearest
-- container's pixel size.  Returns a flat { cssPropertyName = value } table.
function CSSParser.ApplyContainerRulesToNode(containerQueryRules, node, ancestors, containerPixelSize)
  if (containerPixelSize == nil) then return {} end

  local declMap = {}

  for ruleIndex, cqRule in ipairs(containerQueryRules) do
    if (CSSParser.EvaluateContainerCondition(cqRule.condition, containerPixelSize)) then
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