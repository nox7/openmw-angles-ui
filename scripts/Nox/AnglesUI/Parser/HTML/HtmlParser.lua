--- AnglesUI HTML Parser.
--- Consumes the flat token stream produced by HtmlLexer and constructs an
--- abstract syntax tree using the node types defined in HtmlNodes.

local HtmlNodes = require("scripts.Nox.AnglesUI.Parser.HTML.HtmlNodes")
local HtmlLexer = require("scripts.Nox.AnglesUI.Parser.HTML.HtmlLexer")

local NodeType      = HtmlNodes.NodeType
local AttributeType = HtmlNodes.AttributeType
local TokenType     = HtmlLexer.TokenType

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

--- @class AnglesUI.HtmlParser
local HtmlParser = {}

---------------------------------------------------------------------------
-- Internal parser state
---------------------------------------------------------------------------

--- @class AnglesUI._ParserState
--- @field tokens AnglesUI.HtmlToken[]
--- @field pos integer Current index into the token list
--- @field source string Original source (for error messages)

--- @param tokens AnglesUI.HtmlToken[]
--- @param source? string
--- @return AnglesUI._ParserState
local function createState(tokens, source)
    return {
        tokens = tokens,
        pos    = 1,
        source = source or "",
    }
end

--- @param state AnglesUI._ParserState
--- @return AnglesUI.HtmlToken
local function current(state)
    return state.tokens[state.pos]
end

--- @param state AnglesUI._ParserState
local function advance(state)
    state.pos = state.pos + 1
end

--- @param state AnglesUI._ParserState
--- @return boolean
local function isEnd(state)
    local t = state.tokens[state.pos]
    return t == nil or t.type == TokenType.EOF
end

--- Assign parent references to a list of child nodes.
--- @param children AnglesUI.BaseNode[]
--- @param parent AnglesUI.BaseNode
local function setParent(children, parent)
    for _, child in ipairs(children) do
        child.parent = parent
    end
end

---------------------------------------------------------------------------
-- Forward declarations for mutual recursion
---------------------------------------------------------------------------

--- @type fun(state: AnglesUI._ParserState, stopCondition?: fun(token: AnglesUI.HtmlToken): boolean): AnglesUI.BaseNode[]
local parseChildren

--- @type fun(state: AnglesUI._ParserState): AnglesUI.ElementNode
local parseElement

---------------------------------------------------------------------------
-- Directive parsing helpers
---------------------------------------------------------------------------

--- Parse a block of children inside a { } directive block.
--- Expects BLOCK_OPEN to have already been consumed by the caller.
--- Reads children until BLOCK_CLOSE and consumes it.
--- @param state AnglesUI._ParserState
--- @return AnglesUI.BaseNode[]
local function parseDirectiveBlock(state)
    local children = parseChildren(state, function(t)
        return t.type == TokenType.BLOCK_CLOSE
    end)

    -- Consume BLOCK_CLOSE
    if not isEnd(state) and current(state).type == TokenType.BLOCK_CLOSE then
        advance(state)
    end

    return children
end

---------------------------------------------------------------------------
-- Element parsing
---------------------------------------------------------------------------

--- Parse a single element starting at a TAG_OPEN token.
--- Reads attributes, then children (for non-self-closing tags) until the
--- matching TAG_CLOSE.
--- @param state AnglesUI._ParserState
--- @return AnglesUI.ElementNode
parseElement = function(state)
    local tok  = current(state)
    local node = HtmlNodes.CreateElement(tok.value, tok.line, tok.column)
    advance(state) -- consume TAG_OPEN

    -- Read attributes / bindings / events until TAG_END or SELF_CLOSE
    while not isEnd(state) do
        local t = current(state)

        if t.type == TokenType.TAG_END then
            advance(state)
            break
        end

        if t.type == TokenType.SELF_CLOSE then
            node.selfClosing = true
            advance(state)
            return node
        end

        -- Map token types to attribute types
        local attr = nil
        if t.type == TokenType.ATTRIBUTE then
            attr = HtmlNodes.CreateAttribute(AttributeType.Static, t.value, t.extra)
        elseif t.type == TokenType.BINDING then
            attr = HtmlNodes.CreateAttribute(AttributeType.Binding, t.value, t.extra)
        elseif t.type == TokenType.STYLE_BINDING then
            attr = HtmlNodes.CreateAttribute(AttributeType.StyleBinding, "style", t.extra, t.value)
        elseif t.type == TokenType.ATTR_BINDING then
            attr = HtmlNodes.CreateAttribute(AttributeType.AttrBinding, "attr", t.extra, t.value)
        elseif t.type == TokenType.EVENT then
            attr = HtmlNodes.CreateAttribute(AttributeType.Event, t.value, t.extra)
        end

        if attr then
            node.attributes[#node.attributes + 1] = attr
        end
        advance(state)
    end

    -- Not self-closing → parse children until TAG_CLOSE for this tag
    if not node.selfClosing then
        node.children = parseChildren(state, function(t)
            return t.type == TokenType.TAG_CLOSE and t.value == node.tag
        end)

        -- Consume the TAG_CLOSE
        if not isEnd(state) and current(state).type == TokenType.TAG_CLOSE then
            advance(state)
        end

        -- Assign parent references
        setParent(node.children, node)
    end

    return node
end

---------------------------------------------------------------------------
-- Main children parser
---------------------------------------------------------------------------

--- Parse child nodes until a stop condition is met or EOF is reached.
--- @param state AnglesUI._ParserState
--- @param stopCondition? fun(token: AnglesUI.HtmlToken): boolean
--- @return AnglesUI.BaseNode[]
parseChildren = function(state, stopCondition)
    local children = {}

    while not isEnd(state) do
        local tok = current(state)

        -- Check stop condition
        if stopCondition and stopCondition(tok) then
            break
        end

        -- Text node
        if tok.type == TokenType.TEXT then
            children[#children + 1] = HtmlNodes.CreateText(tok.value, tok.line, tok.column)
            advance(state)

        -- Output directive {{ expr }}
        elseif tok.type == TokenType.OUTPUT then
            children[#children + 1] = HtmlNodes.CreateOutput(tok.value, tok.line, tok.column)
            advance(state)

        -- @if directive
        elseif tok.type == TokenType.IF_START then
            local ifNode = HtmlNodes.CreateIfDirective(tok.value, tok.line, tok.column)
            advance(state) -- consume IF_START

            -- Consume BLOCK_OPEN
            if not isEnd(state) and current(state).type == TokenType.BLOCK_OPEN then
                advance(state)
            end

            ifNode.children = parseDirectiveBlock(state)
            setParent(ifNode.children, ifNode)

            -- Check for chained @else if / @else
            while not isEnd(state) do
                -- Skip whitespace-only text between } and @else
                local peeked = current(state)
                if peeked.type == TokenType.TEXT and peeked.value:match("^%s*$") then
                    local nextIdx = state.pos + 1
                    if nextIdx <= #state.tokens then
                        local nextTok = state.tokens[nextIdx]
                        if nextTok.type == TokenType.ELSE_IF_START or nextTok.type == TokenType.ELSE_START then
                            advance(state) -- consume whitespace text
                        else
                            break
                        end
                    else
                        break
                    end
                end

                local ct = current(state)

                if ct.type == TokenType.ELSE_IF_START then
                    local elseIfNode = HtmlNodes.CreateElseIfDirective(ct.value, ct.line, ct.column)
                    advance(state)
                    if not isEnd(state) and current(state).type == TokenType.BLOCK_OPEN then
                        advance(state)
                    end
                    elseIfNode.children = parseDirectiveBlock(state)
                    setParent(elseIfNode.children, elseIfNode)
                    ifNode.elseIfBranches[#ifNode.elseIfBranches + 1] = elseIfNode

                elseif ct.type == TokenType.ELSE_START then
                    local elseNode = HtmlNodes.CreateElseDirective(ct.line, ct.column)
                    advance(state)
                    if not isEnd(state) and current(state).type == TokenType.BLOCK_OPEN then
                        advance(state)
                    end
                    elseNode.children = parseDirectiveBlock(state)
                    setParent(elseNode.children, elseNode)
                    ifNode.elseBranch = elseNode
                    break -- @else is always the last branch
                else
                    break
                end
            end

            children[#children + 1] = ifNode

        -- @for directive
        elseif tok.type == TokenType.FOR_START then
            local forNode = HtmlNodes.CreateForDirective(
                tok.value, tok.extra or "", tok.line, tok.column
            )
            advance(state) -- consume FOR_START

            if not isEnd(state) and current(state).type == TokenType.BLOCK_OPEN then
                advance(state)
            end

            forNode.children = parseDirectiveBlock(state)
            setParent(forNode.children, forNode)
            children[#children + 1] = forNode

        -- Opening tag → element
        elseif tok.type == TokenType.TAG_OPEN then
            children[#children + 1] = parseElement(state)

        -- Anything else (orphan BLOCK_CLOSE, etc.) — skip to avoid infinite loop
        else
            advance(state)
        end
    end

    return children
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

--- Parse HTML template source into an AST.
--- @param source string The raw Angular-style HTML template
--- @return AnglesUI.BaseNode[] roots The root-level nodes
---@nodiscard
function HtmlParser.Parse(source)
    local tokens = HtmlLexer.Tokenize(source)
    local state  = createState(tokens, source)
    return parseChildren(state)
end

--- Parse from a pre-tokenized stream (useful for testing / alternate flows).
--- @param tokens AnglesUI.HtmlToken[]
--- @return AnglesUI.BaseNode[] roots
---@nodiscard
function HtmlParser.ParseTokens(tokens)
    local state = createState(tokens)
    return parseChildren(state)
end

return HtmlParser
