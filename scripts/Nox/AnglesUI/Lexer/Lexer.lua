local Node = require("scripts.Nox.AnglesUI.Lexer.Nodes.Node")
local TextNode = require("scripts.Nox.AnglesUI.Lexer.Nodes.TextNode")
local ComponentNode = require("scripts.Nox.AnglesUI.Lexer.Nodes.ComponentNode")
local EngineComponentNode = require("scripts.Nox.AnglesUI.Lexer.Nodes.EngineComponentNode")
local UserComponentNode = require("scripts.Nox.AnglesUI.Lexer.Nodes.UserComponentNode")
local IfDirectiveNode = require("scripts.Nox.AnglesUI.Lexer.Nodes.IfDirectiveNode")
local ForDirectiveNode = require("scripts.Nox.AnglesUI.Lexer.Nodes.ForDirectiveNode")
local OutputDirectiveNode = require("scripts.Nox.AnglesUI.Lexer.Nodes.OutputDirectiveNode")

---@class Lexer Tokenises an Angular-style HTML template string into an AST of Node objects.
---@field source string The raw template source string being parsed.
---@field pos integer Current 1-based read position within the source.
---@field length integer Total character length of the source string.
---@field userComponents table<string, UserComponent> Registered user components looked up when an unknown tag is encountered.
local Lexer = {}
Lexer.__index = Lexer

local VOID_ELEMENTS = {}

---@param source string The raw HTML-like template source string.
---@param userComponents table<string, UserComponent>|nil Map of selector to UserComponent for resolving custom tags.
---@return Lexer
function Lexer.new(source, userComponents)
  local self = setmetatable({}, Lexer)
  self.source = source
  self.pos = 1
  self.length = #source
  self.userComponents = userComponents or {}
  return self
end

-- Utility: return current character without advancing
---@param offset integer|nil Character offset from the current position (default 0).
---@return string|nil The character at the offset position, or nil when past EOF.
function Lexer:peek(offset)
  local idx = self.pos + (offset or 0)
  if idx > self.length then
    return nil
  end
  return string.sub(self.source, idx, idx)
end

-- Utility: return substring from current position
---@param len integer Number of characters to peek ahead.
---@return string|nil The next `len` characters, or nil if fewer than `len` remain.
function Lexer:peekString(len)
  if self.pos + len - 1 > self.length then
    return nil
  end
  return string.sub(self.source, self.pos, self.pos + len - 1)
end

-- Utility: advance position by n characters
---@param n integer|nil Number of characters to advance (default 1).
function Lexer:advance(n)
  self.pos = self.pos + (n or 1)
end

-- Utility: check if we have reached the end of the source
---@return boolean True when the read position is past the last character.
function Lexer:isEOF()
  return self.pos > self.length
end

-- Utility: skip whitespace characters
function Lexer:skipWhitespace()
  while not self:isEOF() do
    local ch = self:peek()
    if ch == " " or ch == "\t" or ch == "\n" or ch == "\r" then
      self:advance()
    else
      break
    end
  end
end

-- Utility: read until a target string is found (does not consume the target)
---@param target string The string to stop before.
---@return string All characters consumed before the target (or all remaining if not found).
function Lexer:readUntil(target)
  local startPos = self.pos
  local targetLen = #target
  while not self:isEOF() do
    if self:peekString(targetLen) == target then
      return string.sub(self.source, startPos, self.pos - 1)
    end
    self:advance()
  end
  return string.sub(self.source, startPos, self.pos - 1)
end

-- Utility: read a balanced brace block starting at the opening '{'
-- Returns the content inside the braces (not including the braces themselves)
---@return string|nil The inner content of the balanced `{ }` block, or nil if no opening brace is at the current position.
function Lexer:readBraceBlock()
  if self:peek() ~= "{" then
    return nil
  end
  self:advance() -- skip opening '{'
  local depth = 1
  local startPos = self.pos
  while not self:isEOF() and depth > 0 do
    local ch = self:peek()
    if ch == "{" then
      depth = depth + 1
    elseif ch == "}" then
      depth = depth - 1
    end
    if depth > 0 then
      self:advance()
    end
  end
  local content = string.sub(self.source, startPos, self.pos - 1)
  if self:peek() == "}" then
    self:advance() -- skip closing '}'
  end
  return content
end

-- Utility: read a balanced parentheses expression starting at '('
-- Returns the content inside the parens (not including the parens themselves)
---@return string|nil The inner content of the balanced `( )` group, or nil if no opening paren is at the current position.
function Lexer:readParenExpression()
  if self:peek() ~= "(" then
    return nil
  end
  self:advance() -- skip opening '('
  local depth = 1
  local startPos = self.pos
  while not self:isEOF() and depth > 0 do
    local ch = self:peek()
    if ch == "(" then
      depth = depth + 1
    elseif ch == ")" then
      depth = depth - 1
    end
    if depth > 0 then
      self:advance()
    end
  end
  local content = string.sub(self.source, startPos, self.pos - 1)
  if self:peek() == ")" then
    self:advance() -- skip closing ')'
  end
  return content
end

-- Parse the full source into a list of AST root nodes
---@return Node The root AST Node whose children are the top-level parsed nodes.
function Lexer:parse()
  local rootNode = Node.new("Root")
  self:parseChildren(rootNode)
  return rootNode
end

-- Parse children into the given parent node until EOF or a stopping condition
---@param parentNode Node The parent node to which parsed children are appended.
---@param stopCondition (fun(): boolean)|nil Optional predicate; parsing stops immediately when it returns true.
function Lexer:parseChildren(parentNode, stopCondition)
  while not self:isEOF() do
    if stopCondition and stopCondition() then
      break
    end

    -- Check for output expression {{ ... }}
    if self:peekString(2) == "{{" then
      local node = self:parseOutputDirective()
      if node then
        parentNode:addChild(node)
      end
    -- Check for directive @if or @for
    elseif self:peek() == "@" then
      local node = self:parseDirective()
      if node then
        parentNode:addChild(node)
      end
    -- Check for HTML comment
    elseif self:peekString(4) == "<!--" then
      self:parseComment()
    -- Check for closing HTML tag (signals end of parent component)
    elseif self:peekString(2) == "</" then
      break
    -- Check for opening HTML tag
    elseif self:peek() == "<" then
      local node = self:parseComponent()
      if node then
        parentNode:addChild(node)
      end
    -- Otherwise, consume text
    else
      local node = self:parseText()
      if node then
        parentNode:addChild(node)
      end
    end
  end
end

-- Parse plain text until we hit a special token
---@return TextNode|nil A TextNode for the consumed text, or nil when no text characters were available.
function Lexer:parseText()
  local startPos = self.pos
  while not self:isEOF() do
    local ch = self:peek()
    -- Stop at anything that might be a special construct
    if ch == "<" or ch == "@" then
      break
    end
    if self:peekString(2) == "{{" then
      break
    end
    self:advance()
  end

  local text = string.sub(self.source, startPos, self.pos - 1)
  if text == "" then
    return nil
  end
  return TextNode.new(text)
end

-- Parse {{ expression }}
---@return OutputDirectiveNode The output directive node for the parsed expression.
function Lexer:parseOutputDirective()
  self:advance(2) -- skip '{{'
  local content = self:readUntil("}}")
  if self:peekString(2) == "}}" then
    self:advance(2) -- skip '}}'
  end

  local expression = self:trim(content)

  -- Check if the expression contains a ternary (condition ? trueExpr : falseExpr)
  local ternaryCondition, ternaryTrue, ternaryFalse = self:parseTernaryExpression(expression)
  if ternaryCondition then
    return OutputDirectiveNode.newTernary(ternaryCondition, ternaryTrue, ternaryFalse)
  end

  return OutputDirectiveNode.new(expression)
end

-- Try to parse a ternary expression: condition ? trueExpr : falseExpr
-- Returns nil if not a ternary
---@param expression string The expression string to test for ternary form.
---@return string|nil condition, string|nil trueExpr, string|nil falseExpr Three values on success; all nil when not a ternary.
function Lexer:parseTernaryExpression(expression)
  -- Find the '?' that is not inside quotes or nested parens
  local questionPos = self:findOperatorPosition(expression, "?")
  if not questionPos then
    return nil
  end

  local condition = self:trim(string.sub(expression, 1, questionPos - 1))
  local remainder = string.sub(expression, questionPos + 1)

  -- Find the ':' separator in the remainder
  local colonPos = self:findOperatorPosition(remainder, ":")
  if not colonPos then
    return nil
  end

  local trueExpr = self:trim(string.sub(remainder, 1, colonPos - 1))
  local falseExpr = self:trim(string.sub(remainder, colonPos + 1))

  if condition == "" or trueExpr == "" or falseExpr == "" then
    return nil
  end

  return condition, trueExpr, falseExpr
end

-- Find position of an operator character, skipping quoted strings and nested parens
---@param str string The string to search within.
---@param operator string The single-character operator to locate.
---@return integer|nil The 1-based position of the operator at the top level, or nil if not found.
function Lexer:findOperatorPosition(str, operator)
  local i = 1
  local len = #str
  local parenDepth = 0
  local inSingleQuote = false
  local inDoubleQuote = false

  while i <= len do
    local ch = string.sub(str, i, i)

    if ch == "'" and not inDoubleQuote then
      inSingleQuote = not inSingleQuote
    elseif ch == '"' and not inSingleQuote then
      inDoubleQuote = not inDoubleQuote
    elseif not inSingleQuote and not inDoubleQuote then
      if ch == "(" then
        parenDepth = parenDepth + 1
      elseif ch == ")" then
        parenDepth = parenDepth - 1
      elseif ch == operator and parenDepth == 0 then
        return i
      end
    end

    i = i + 1
  end

  return nil
end

-- Parse @if or @for directives
---@return Node An IfDirectiveNode or ForDirectiveNode on success, or a fallback TextNode for unknown directives.
function Lexer:parseDirective()
  self:advance() -- skip '@'

  -- Read the directive keyword
  local keyword = self:readIdentifier()

  if keyword == "if" then
    return self:parseIfDirective()
  elseif keyword == "for" then
    return self:parseForDirective()
  end

  -- Unknown directive - treat as text
  return TextNode.new("@" .. keyword)
end

-- Parse @if (condition) { ... } with optional @else if and @else
---@return Node An IfDirectiveNode on success, or a fallback TextNode when the syntax is malformed.
function Lexer:parseIfDirective()
  self:skipWhitespace()

  local conditionExpr = self:readParenExpression()
  if not conditionExpr then
    return TextNode.new("@if")
  end
  conditionExpr = self:trim(conditionExpr)

  self:skipWhitespace()

  local bodyContent = self:readBraceBlock()
  if not bodyContent then
    return TextNode.new("@if(" .. conditionExpr .. ")")
  end

  local node = IfDirectiveNode.new(conditionExpr)

  -- Parse the body of the @if block
  local bodyLexer = Lexer.new(bodyContent, self.userComponents)
  bodyLexer:parseChildren(node)

  -- Check for @else if / @else chains
  self:parseElseChain(node)

  return node
end

-- Parse optional @else if (...) { ... } and @else { ... } chains
---@param ifNode IfDirectiveNode The if node to attach else-if branches and the optional else branch to.
function Lexer:parseElseChain(ifNode)
  while not self:isEOF() do
    local savedPos = self.pos
    self:skipWhitespace()

    -- Check for @else
    if self:peekString(5) ~= "@else" then
      self.pos = savedPos
      break
    end
    self:advance(5) -- skip '@else'
    self:skipWhitespace()

    -- Check if this is @else if
    if self:peekString(2) == "if" then
      local afterIf = self:peek(2)
      if afterIf == " " or afterIf == "(" or afterIf == "\t" then
        self:advance(2) -- skip 'if'
        self:skipWhitespace()

        local conditionExpr = self:readParenExpression()
        if not conditionExpr then
          self.pos = savedPos
          break
        end
        conditionExpr = self:trim(conditionExpr)

        self:skipWhitespace()

        local bodyContent = self:readBraceBlock()
        if not bodyContent then
          self.pos = savedPos
          break
        end

        -- Parse else-if body into child nodes
        local elseIfChildren = {}
        local tempNode = Node.new("Temp")
        local bodyLexer = Lexer.new(bodyContent, self.userComponents)
        bodyLexer:parseChildren(tempNode)
        elseIfChildren = tempNode.children

        ifNode:addElseIfBranch(conditionExpr, elseIfChildren)
      else
        self.pos = savedPos
        break
      end
    else
      -- Plain @else { ... }
      self:skipWhitespace()
      local bodyContent = self:readBraceBlock()
      if not bodyContent then
        self.pos = savedPos
        break
      end

      local tempNode = Node.new("Temp")
      local bodyLexer = Lexer.new(bodyContent, self.userComponents)
      bodyLexer:parseChildren(tempNode)
      ifNode:setElseBranch(tempNode.children)
      break
    end
  end
end

-- Parse @for (item in list) { ... }
---@return Node A ForDirectiveNode on success, or a fallback TextNode when the syntax is malformed.
function Lexer:parseForDirective()
  self:skipWhitespace()

  local loopExpr = self:readParenExpression()
  if not loopExpr then
    return TextNode.new("@for")
  end
  loopExpr = self:trim(loopExpr)

  -- Parse "item in list" from the loop expression
  local iteratorVar, iterableExpr = string.match(loopExpr, "^(%S+)%s+in%s+(.+)$")
  if not iteratorVar then
    return TextNode.new("@for(" .. loopExpr .. ")")
  end

  self:skipWhitespace()

  local bodyContent = self:readBraceBlock()
  if not bodyContent then
    return TextNode.new("@for(" .. loopExpr .. ")")
  end

  local node = ForDirectiveNode.new(iteratorVar, self:trim(iterableExpr))

  -- Parse the body of the @for block
  local bodyLexer = Lexer.new(bodyContent, self.userComponents)
  bodyLexer:parseChildren(node)

  return node
end

-- Parse an HTML tag <tagName attr="value"> ... </tagName>
---@return Node An EngineComponentNode (mw- prefix), a UserComponentNode (registered selector), or a fallback TextNode.
function Lexer:parseComponent()
  self:advance() -- skip '<'

  -- Read the tag name
  local tagName = self:readIdentifier()
  if tagName == "" then
    return TextNode.new("<")
  end

  -- Parse attributes
  local attributes = {}
  local selfClosing = false

  self:skipWhitespace()

  while not self:isEOF() do
    local ch = self:peek()

    -- Self-closing tag />
    if ch == "/" and self:peek(1) == ">" then
      selfClosing = true
      self:advance(2) -- skip '/>'
      break
    end

    -- End of opening tag
    if ch == ">" then
      self:advance() -- skip '>'
      break
    end

    -- Parse attribute
    local attrName = self:readAttributeName()
    if attrName == "" then
      self:advance() -- skip unexpected character
      self:skipWhitespace()
    else
      self:skipWhitespace()
      local attrValue = nil
      if self:peek() == "=" then
        self:advance() -- skip '='
        self:skipWhitespace()
        attrValue = self:readAttributeValue()
      end
      -- Preserve original case for event bindings (e.g. (mousePress)) because OpenMW event
      -- names are camelCase and would break if lowercased.  All other attribute names are
      -- normalised to lowercase for case-insensitive CSS / property matching.
      local attrKey = (string.sub(attrName, 1, 1) == "(") and attrName or string.lower(attrName)
      attributes[attrKey] = attrValue
      self:skipWhitespace()
    end
  end

  -- Check if this is a void/self-closing element
  local isVoid = VOID_ELEMENTS[string.lower(tagName)] or false

  -- Create the appropriate node type based on the tag name
  local node
  local isMwPrefix = string.sub(tagName, 1, 3) == "mw-"
  if isMwPrefix then
    node = EngineComponentNode.new(tagName, attributes, selfClosing or isVoid)
  else
    local userComponent = self.userComponents[tagName]
    if (userComponent == nil) then
      error("<" .. tagName .. "> is not a recognized engine component (must start with 'mw-') nor a registered user component.")
    end
    node = UserComponentNode.new(tagName, attributes, selfClosing or isVoid, userComponent.htmlSource)
  end

  -- If not self-closing, parse children and closing tag
  if not selfClosing and not isVoid then
    self:parseChildren(node)

    -- Consume the closing tag </tagName>
    if self:peekString(2) == "</" then
      self:advance(2) -- skip '</'
      local closingTag = self:readIdentifier()
      self:skipWhitespace()
      if self:peek() == ">" then
        self:advance() -- skip '>'
      end
    end
  end

  return node
end

-- Parse and skip an HTML comment <!-- ... -->
function Lexer:parseComment()
  self:advance(4) -- skip '<!--'
  while not self:isEOF() do
    if self:peekString(3) == "-->" then
      self:advance(3) -- skip '-->'
      return
    end
    self:advance()
  end
end

-- Read an identifier (letters, digits, underscores, hyphens)
---@return string The consumed identifier; may be empty if the current character is not a valid identifier character.
function Lexer:readIdentifier()
  local startPos = self.pos
  while not self:isEOF() do
    local ch = self:peek()
    if string.match(ch, "[%w_%-]") then
      self:advance()
    else
      break
    end
  end
  return string.sub(self.source, startPos, self.pos - 1)
end

-- Read an attribute name (allows letters, digits, underscores, hyphens, dots, colons, and brackets)
---@return string The consumed attribute name string.
function Lexer:readAttributeName()
  local startPos = self.pos
  while not self:isEOF() do
    local ch = self:peek()
    if string.match(ch, "[%w_%-%.:%[%]%(%)]" ) then
      self:advance()
    else
      break
    end
  end
  return string.sub(self.source, startPos, self.pos - 1)
end

-- Read an attribute value (quoted or unquoted)
---@return string The parsed attribute value with any enclosing quote characters stripped.
function Lexer:readAttributeValue()
  local ch = self:peek()

  -- Double-quoted value
  if ch == '"' then
    self:advance() -- skip opening quote
    local startPos = self.pos
    while not self:isEOF() and self:peek() ~= '"' do
      self:advance()
    end
    local value = string.sub(self.source, startPos, self.pos - 1)
    if self:peek() == '"' then
      self:advance() -- skip closing quote
    end
    return value
  end

  -- Single-quoted value
  if ch == "'" then
    self:advance() -- skip opening quote
    local startPos = self.pos
    while not self:isEOF() and self:peek() ~= "'" do
      self:advance()
    end
    local value = string.sub(self.source, startPos, self.pos - 1)
    if self:peek() == "'" then
      self:advance() -- skip closing quote
    end
    return value
  end

  -- Unquoted value (read until whitespace or >)
  local startPos = self.pos
  while not self:isEOF() do
    local c = self:peek()
    if c == " " or c == "\t" or c == "\n" or c == "\r" or c == ">" or c == "/" then
      break
    end
    self:advance()
  end
  return string.sub(self.source, startPos, self.pos - 1)
end

-- Utility: trim whitespace from both ends of a string
---@param str string The string to trim.
---@return string The trimmed string.
function Lexer:trim(str)
  return string.match(str, "^%s*(.-)%s*$") or str
end

return Lexer
