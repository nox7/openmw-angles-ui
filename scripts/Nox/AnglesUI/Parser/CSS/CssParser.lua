--- AnglesUI CSS Parser.
--- Consumes the token stream from CssLexer and builds a CSS AST.
--- Handles rule sets, declarations, nested rules, @media and @container
--- at-rules, and CSS variable declarations.

local CssNodes = require("scripts.Nox.AnglesUI.Parser.CSS.CssNodes")
local CssLexer = require("scripts.Nox.AnglesUI.Parser.CSS.CssLexer")

local CssNodeType = CssNodes.CssNodeType
local TT          = CssLexer.TokenType

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

--- @class AnglesUI.CssParser
local CssParser = {}

---------------------------------------------------------------------------
-- Internal parser state
---------------------------------------------------------------------------

--- @class AnglesUI._CssParserState
--- @field tokens AnglesUI.CssToken[]
--- @field source string Original CSS source for raw text extraction
--- @field pos integer Current index into the token list

--- @param state AnglesUI._CssParserState
--- @return AnglesUI.CssToken
local function current(state)
    return state.tokens[state.pos]
end

--- @param state AnglesUI._CssParserState
local function advance(state)
    state.pos = state.pos + 1
end

--- @param state AnglesUI._CssParserState
--- @return boolean
local function isEnd(state)
    local t = state.tokens[state.pos]
    return t == nil or t.type == TT.EOF
end

--- Skip whitespace tokens.
--- @param state AnglesUI._CssParserState
local function skipWs(state)
    while not isEnd(state) and current(state).type == TT.WHITESPACE do
        advance(state)
    end
end

--- Extract the raw source text for a range of token indices.
--- @param state AnglesUI._CssParserState
--- @param startIdx integer First token index (inclusive)
--- @param endIdx integer Last token index (inclusive)
--- @return string
local function rawText(state, startIdx, endIdx)
    if startIdx > endIdx then return "" end
    local first = state.tokens[startIdx]
    local last  = state.tokens[endIdx]
    if not first or not last then return "" end
    return state.source:sub(first.startPos, last.endPos)
end

--- Trim trailing whitespace tokens from a range and return the adjusted end index.
--- @param state AnglesUI._CssParserState
--- @param startIdx integer
--- @param endIdx integer
--- @return integer trimmedEnd
local function trimTrailingWs(state, startIdx, endIdx)
    while endIdx >= startIdx and state.tokens[endIdx].type == TT.WHITESPACE do
        endIdx = endIdx - 1
    end
    return endIdx
end

--- Trim leading whitespace tokens from a range and return the adjusted start index.
--- @param state AnglesUI._CssParserState
--- @param startIdx integer
--- @param endIdx integer
--- @return integer trimmedStart
local function trimLeadingWs(state, startIdx, endIdx)
    while startIdx <= endIdx and state.tokens[startIdx].type == TT.WHITESPACE do
        startIdx = startIdx + 1
    end
    return startIdx
end

---------------------------------------------------------------------------
-- Lookahead heuristic: declaration vs nested rule
---------------------------------------------------------------------------

--- Scan forward from the current position to determine whether the next
--- construct inside a block is a declaration (property: value;) or a
--- nested rule (selector { ... }).
---
--- Heuristic: if we encounter `{` at depth 0 before `;` or `}`, it is a
--- nested rule. Otherwise it is a declaration.
--- @param state AnglesUI._CssParserState
--- @return boolean isNested True if this is a nested rule
local function isNestedRuleLookahead(state)
    local idx        = state.pos
    local braceDepth = 0
    local parenDepth = 0
    local count      = #state.tokens

    while idx <= count do
        local t  = state.tokens[idx]
        local tt = t.type

        if tt ~= TT.WHITESPACE then
            if tt == TT.LBRACE then
                if braceDepth == 0 and parenDepth == 0 then return true end
                braceDepth = braceDepth + 1
            elseif tt == TT.RBRACE then
                if braceDepth == 0 then return false end
                braceDepth = braceDepth - 1
            elseif tt == TT.LPAREN or tt == TT.FUNCTION_TOKEN then
                parenDepth = parenDepth + 1
            elseif tt == TT.RPAREN then
                if parenDepth > 0 then parenDepth = parenDepth - 1 end
            elseif tt == TT.SEMICOLON and braceDepth == 0 and parenDepth == 0 then
                return false
            elseif tt == TT.EOF then
                return false
            end
        end

        idx = idx + 1
    end

    return false
end

---------------------------------------------------------------------------
-- Forward declarations for mutual recursion
---------------------------------------------------------------------------

--- @type fun(state: AnglesUI._CssParserState, rules: (AnglesUI.CssRule | AnglesUI.CssAtRule)[])
local parseRuleList

--- @type fun(state: AnglesUI._CssParserState, rule: AnglesUI.CssRule)
local parseBlock

---------------------------------------------------------------------------
-- Declaration parsing
---------------------------------------------------------------------------

--- Parse a single CSS declaration (property: value;).
--- @param state AnglesUI._CssParserState
--- @param rule AnglesUI.CssRule The owning rule to append the declaration to
local function parseDeclaration(state, rule)
    skipWs(state)
    if isEnd(state) or current(state).type == TT.RBRACE then return end

    -- Property name
    local propToken = current(state)
    if propToken.type ~= TT.IDENT then
        -- Unexpected token; skip to next ; or }
        while not isEnd(state) and current(state).type ~= TT.SEMICOLON and current(state).type ~= TT.RBRACE do
            advance(state)
        end
        if not isEnd(state) and current(state).type == TT.SEMICOLON then advance(state) end
        return
    end

    local property     = propToken.value
    local propertyLine = propToken.line
    local propertyCol  = propToken.column
    advance(state) -- consume property ident
    skipWs(state)

    -- Expect colon
    if not isEnd(state) and current(state).type == TT.COLON then
        advance(state) -- consume :
    end
    skipWs(state)

    -- Read value tokens until ; or } (at depth 0)
    local valueStart = state.pos
    local valueEnd   = state.pos - 1
    local depth      = 0

    while not isEnd(state) do
        local tt = current(state).type
        if (tt == TT.SEMICOLON or tt == TT.RBRACE) and depth == 0 then
            break
        end
        if tt == TT.LPAREN or tt == TT.FUNCTION_TOKEN then
            depth = depth + 1
        elseif tt == TT.RPAREN then
            if depth > 0 then depth = depth - 1 end
        end
        valueEnd = state.pos
        advance(state)
    end

    -- Extract raw value text
    local value = ""
    if valueEnd >= valueStart then
        local trimmedEnd   = trimTrailingWs(state, valueStart, valueEnd)
        local trimmedStart = trimLeadingWs(state, valueStart, trimmedEnd)
        if trimmedStart <= trimmedEnd then
            value = rawText(state, trimmedStart, trimmedEnd)
        end
    end

    rule.declarations[#rule.declarations + 1] =
        CssNodes.CreateDeclaration(property, value, propertyLine, propertyCol)

    -- Consume semicolon if present
    if not isEnd(state) and current(state).type == TT.SEMICOLON then
        advance(state)
    end
end

---------------------------------------------------------------------------
-- Rule parsing
---------------------------------------------------------------------------

--- Parse a nested rule inside a block (uses the same selector→block flow).
--- @param state AnglesUI._CssParserState
--- @param parentRule AnglesUI.CssRule
local function parseNestedRule(state, parentRule)
    skipWs(state)

    -- Read selector tokens until {
    local selStart = state.pos
    while not isEnd(state) and current(state).type ~= TT.LBRACE do
        advance(state)
    end

    local selEnd = trimTrailingWs(state, selStart, state.pos - 1)
    local selectorText = ""
    if selStart <= selEnd then
        selectorText = rawText(state, selStart, selEnd)
    end

    local selLine = state.tokens[selStart] and state.tokens[selStart].line or 0
    local selCol  = state.tokens[selStart] and state.tokens[selStart].column or 0
    local nestedRule = CssNodes.CreateRule(selectorText, selLine, selCol)
    nestedRule.parent = parentRule

    -- Consume { and parse block contents
    if not isEnd(state) and current(state).type == TT.LBRACE then
        advance(state)
        parseBlock(state, nestedRule)
        if not isEnd(state) and current(state).type == TT.RBRACE then
            advance(state)
        end
    end

    parentRule.nestedRules[#parentRule.nestedRules + 1] = nestedRule
end

--- Parse the contents of a rule block (declarations and nested rules).
--- Position should be just after the opening {.
--- @param state AnglesUI._CssParserState
--- @param rule AnglesUI.CssRule
parseBlock = function(state, rule)
    while not isEnd(state) do
        skipWs(state)
        if isEnd(state) then break end
        if current(state).type == TT.RBRACE then break end

        if isNestedRuleLookahead(state) then
            parseNestedRule(state, rule)
        else
            parseDeclaration(state, rule)
        end
    end
end

---------------------------------------------------------------------------
-- At-rule parsing
---------------------------------------------------------------------------

--- Parse an @media or @container at-rule.
--- @param state AnglesUI._CssParserState
--- @param rules (AnglesUI.CssRule | AnglesUI.CssAtRule)[]
local function parseAtRule(state, rules)
    local atToken = current(state)
    advance(state) -- consume AT_KEYWORD
    skipWs(state)

    -- Read prelude tokens until {
    local preludeStart = state.pos
    while not isEnd(state) and current(state).type ~= TT.LBRACE do
        advance(state)
    end

    local preludeEnd = trimTrailingWs(state, preludeStart, state.pos - 1)
    local prelude = ""
    if preludeStart <= preludeEnd then
        prelude = rawText(state, preludeStart, preludeEnd)
    end

    local atRule = CssNodes.CreateAtRule(atToken.value, prelude, atToken.line, atToken.column)

    -- Consume { and parse inner rules
    if not isEnd(state) and current(state).type == TT.LBRACE then
        advance(state)
        parseRuleList(state, atRule.rules)
        if not isEnd(state) and current(state).type == TT.RBRACE then
            advance(state)
        end
    end

    rules[#rules + 1] = atRule
end

---------------------------------------------------------------------------
-- Top-level rule parsing
---------------------------------------------------------------------------

--- Parse a top-level rule (selector { block }).
--- @param state AnglesUI._CssParserState
--- @param rules (AnglesUI.CssRule | AnglesUI.CssAtRule)[]
local function parseTopLevelRule(state, rules)
    skipWs(state)
    if isEnd(state) then return end

    -- Read selector tokens until {
    local selStart = state.pos
    while not isEnd(state) and current(state).type ~= TT.LBRACE do
        advance(state)
    end

    local selEnd = trimTrailingWs(state, selStart, state.pos - 1)
    local selectorText = ""
    if selStart <= selEnd then
        selectorText = rawText(state, selStart, selEnd)
    end

    local selLine = state.tokens[selStart] and state.tokens[selStart].line or 0
    local selCol  = state.tokens[selStart] and state.tokens[selStart].column or 0
    local rule = CssNodes.CreateRule(selectorText, selLine, selCol)

    -- Consume { and parse block
    if not isEnd(state) and current(state).type == TT.LBRACE then
        advance(state)
        parseBlock(state, rule)
        if not isEnd(state) and current(state).type == TT.RBRACE then
            advance(state)
        end
    end

    rules[#rules + 1] = rule
end

--- Parse a list of rules (used at top level and inside at-rule blocks).
--- @param state AnglesUI._CssParserState
--- @param rules (AnglesUI.CssRule | AnglesUI.CssAtRule)[]
parseRuleList = function(state, rules)
    while not isEnd(state) do
        skipWs(state)
        if isEnd(state) then break end
        if current(state).type == TT.RBRACE then break end

        if current(state).type == TT.AT_KEYWORD then
            parseAtRule(state, rules)
        else
            parseTopLevelRule(state, rules)
        end
    end
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

--- Parse CSS source into a stylesheet AST.
--- @param source string The raw CSS source
--- @return AnglesUI.CssStylesheet
---@nodiscard
function CssParser.Parse(source)
    local tokens = CssLexer.Tokenize(source)
    local state = {
        tokens = tokens,
        source = source,
        pos    = 1,
    }

    local stylesheet = CssNodes.CreateStylesheet()
    parseRuleList(state, stylesheet.rules)
    return stylesheet
end

--- Parse from pre-tokenized CSS (useful for testing).
--- @param tokens AnglesUI.CssToken[]
--- @param source string The original source for raw text extraction
--- @return AnglesUI.CssStylesheet
---@nodiscard
function CssParser.ParseTokens(tokens, source)
    local state = {
        tokens = tokens,
        source = source or "",
        pos    = 1,
    }

    local stylesheet = CssNodes.CreateStylesheet()
    parseRuleList(state, stylesheet.rules)
    return stylesheet
end

return CssParser
