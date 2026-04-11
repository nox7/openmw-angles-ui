--- AnglesUI HTML Lexer / Tokenizer.
--- Scans Angular-style HTML template source into a flat token stream
--- consumed by the HtmlParser. Handles tags, attributes, bindings, events,
--- directives (@if, @for, @else), output expressions ({{ }}), and text.

---------------------------------------------------------------------------
-- Token types
---------------------------------------------------------------------------

--- @enum AnglesUI.HtmlTokenType
local TokenType = {
    TAG_OPEN      = "TAG_OPEN",      -- value = tag name
    TAG_CLOSE     = "TAG_CLOSE",     -- value = tag name
    TAG_END       = "TAG_END",       -- >
    SELF_CLOSE    = "SELF_CLOSE",    -- />
    ATTRIBUTE     = "ATTRIBUTE",     -- value = name, extra = raw value | nil
    BINDING       = "BINDING",       -- value = propName, extra = expression
    STYLE_BINDING = "STYLE_BINDING", -- value = cssProp, extra = expression
    ATTR_BINDING  = "ATTR_BINDING",  -- value = attrProp, extra = expression
    EVENT         = "EVENT",         -- value = eventName, extra = expression
    TEXT          = "TEXT",          -- value = text content
    OUTPUT        = "OUTPUT",        -- value = expression
    IF_START      = "IF_START",      -- value = condition expression
    ELSE_IF_START = "ELSE_IF_START", -- value = condition expression
    ELSE_START    = "ELSE_START",    -- no value
    FOR_START     = "FOR_START",     -- value = iterator, extra = iterable expr
    BLOCK_OPEN    = "BLOCK_OPEN",    -- {
    BLOCK_CLOSE   = "BLOCK_CLOSE",   -- }
    EOF           = "EOF",
}

---------------------------------------------------------------------------
-- Token class
---------------------------------------------------------------------------

--- @class AnglesUI.HtmlToken
--- @field type AnglesUI.HtmlTokenType
--- @field value string
--- @field extra string?
--- @field line integer
--- @field column integer

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

--- @class AnglesUI.HtmlLexer
--- @field TokenType AnglesUI.HtmlTokenType
local HtmlLexer = {
    TokenType = TokenType,
}

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

--- Tokenize an Angular-style HTML template string.
--- @param source string The raw template source
--- @return AnglesUI.HtmlToken[] tokens
---@nodiscard
function HtmlLexer.Tokenize(source)
    -- Scanner state -------------------------------------------------------
    local pos    = 1
    local line   = 1
    local column = 1
    local len    = #source
    local tokens = {}

    -- Helpers -------------------------------------------------------------

    --- Peek at a character at an offset from the current position.
    --- @param offset? integer Defaults to 0
    --- @return string? ch Single character or nil if past end
    local function peek(offset)
        local p = pos + (offset or 0)
        if p < 1 or p > len then return nil end
        return source:sub(p, p)
    end

    --- Peek at a substring of `count` characters from the current position.
    --- @param count integer
    --- @return string? str
    local function peekStr(count)
        if pos + count - 1 > len then return nil end
        return source:sub(pos, pos + count - 1)
    end

    --- Advance the scanner by `count` characters, tracking line/column.
    --- @param count? integer Defaults to 1
    local function advance(count)
        for _ = 1, (count or 1) do
            if pos <= len then
                if source:sub(pos, pos) == "\n" then
                    line   = line + 1
                    column = 1
                else
                    column = column + 1
                end
                pos = pos + 1
            end
        end
    end

    --- Emit a token into the token list.
    --- @param tokenType AnglesUI.HtmlTokenType
    --- @param value? string
    --- @param extra? string
    --- @param tokenLine? integer
    --- @param tokenCol? integer
    local function emit(tokenType, value, extra, tokenLine, tokenCol)
        tokens[#tokens + 1] = {
            type   = tokenType,
            value  = value or "",
            extra  = extra,
            line   = tokenLine or line,
            column = tokenCol or column,
        }
    end

    local function isEnd()
        return pos > len
    end

    local function skipWhitespace()
        while not isEnd() do
            local ch = peek()
            if ch == " " or ch == "\t" or ch == "\n" or ch == "\r" then
                advance()
            else
                break
            end
        end
    end

    --- @param ch string?
    --- @return boolean
    local function isAlpha(ch)
        if not ch then return false end
        return ch:match("[a-zA-Z_]") ~= nil
    end

    --- @param ch string?
    --- @return boolean
    local function isTagNameChar(ch)
        if not ch then return false end
        return ch:match("[a-zA-Z0-9_%-]") ~= nil
    end

    --- Read a contiguous tag/attribute identifier (letters, digits, hyphens, underscores).
    --- @return string
    local function readIdentifier()
        local start = pos
        while not isEnd() and isTagNameChar(peek()) do
            advance()
        end
        return source:sub(start, pos - 1)
    end

    --- Read a quoted string. Current position must be at the opening quote.
    --- Returns the content between the quotes.
    --- @return string
    local function readQuotedString()
        local quote = peek()
        advance() -- skip opening quote
        local start = pos
        while not isEnd() and peek() ~= quote do
            advance()
        end
        local value = source:sub(start, pos - 1)
        if not isEnd() then advance() end -- skip closing quote
        return value
    end

    --- Read a balanced parenthesised expression. Position must be just AFTER
    --- the opening '('. Reads until the matching ')' respecting nesting.
    --- @return string expression Trimmed expression text
    local function readParenExpression()
        local depth = 1
        local start = pos
        while not isEnd() and depth > 0 do
            local ch = peek()
            if ch == "(" then
                depth = depth + 1
            elseif ch == ")" then
                depth = depth - 1
            end
            if depth > 0 then advance() end
        end
        local expr = source:sub(start, pos - 1)
        if not isEnd() then advance() end -- skip closing )
        return expr:match("^%s*(.-)%s*$") -- trim
    end

    ---------------------------------------------------------------------------
    -- Tag scanning (inside an opening tag after the tag name)
    ---------------------------------------------------------------------------

    local function scanTag()
        while not isEnd() do
            skipWhitespace()
            if isEnd() then break end

            local ch = peek()

            -- End of opening tag: >
            if ch == ">" then
                emit(TokenType.TAG_END, ">")
                advance()
                return
            end

            -- Self-closing: />
            if ch == "/" and peek(1) == ">" then
                emit(TokenType.SELF_CLOSE, "/>")
                advance(2)
                return
            end

            -- Binding: [name]="expr"  |  [style.prop]="expr"  |  [attr.prop]="expr"
            if ch == "[" then
                advance() -- skip [
                local nameStart = pos
                while not isEnd() and peek() ~= "]" do
                    advance()
                end
                local name = source:sub(nameStart, pos - 1)
                if not isEnd() then advance() end -- skip ]

                -- Determine binding kind
                local tokType = TokenType.BINDING
                local bindName = name
                local bindProp = nil

                if name:sub(1, 6) == "style." then
                    tokType  = TokenType.STYLE_BINDING
                    bindProp = name:sub(7)
                    bindName = "style"
                elseif name:sub(1, 5) == "attr." then
                    tokType  = TokenType.ATTR_BINDING
                    bindProp = name:sub(6)
                    bindName = "attr"
                end

                -- Read ="expression"
                skipWhitespace()
                local expr = ""
                if not isEnd() and peek() == "=" then
                    advance() -- skip =
                    skipWhitespace()
                    if not isEnd() and (peek() == '"' or peek() == "'") then
                        expr = readQuotedString()
                    end
                end

                if tokType == TokenType.STYLE_BINDING then
                    emit(TokenType.STYLE_BINDING, bindProp, expr)
                elseif tokType == TokenType.ATTR_BINDING then
                    emit(TokenType.ATTR_BINDING, bindProp, expr)
                else
                    emit(TokenType.BINDING, bindName, expr)
                end

            -- Event binding: (eventName)="expr"
            elseif ch == "(" then
                advance() -- skip (
                local nameStart = pos
                while not isEnd() and peek() ~= ")" do
                    advance()
                end
                local evtName = source:sub(nameStart, pos - 1)
                if not isEnd() then advance() end -- skip )

                skipWhitespace()
                local expr = ""
                if not isEnd() and peek() == "=" then
                    advance()
                    skipWhitespace()
                    if not isEnd() and (peek() == '"' or peek() == "'") then
                        expr = readQuotedString()
                    end
                end

                emit(TokenType.EVENT, evtName, expr)

            -- Regular attribute: name="value" or boolean attribute name
            elseif isAlpha(ch) then
                local attrName = readIdentifier()
                skipWhitespace()
                local attrValue = nil
                if not isEnd() and peek() == "=" then
                    advance() -- skip =
                    skipWhitespace()
                    if not isEnd() and (peek() == '"' or peek() == "'") then
                        attrValue = readQuotedString()
                    end
                end
                emit(TokenType.ATTRIBUTE, attrName, attrValue)

            else
                -- Unknown character inside tag — skip
                advance()
            end
        end
    end

    ---------------------------------------------------------------------------
    -- Content scanning (between tags / directive blocks)
    ---------------------------------------------------------------------------

    local function scanContent()
        local textBuf  = ""
        local textLine = line
        local textCol  = column

        local function flushText()
            if #textBuf > 0 then
                tokens[#tokens + 1] = {
                    type   = TokenType.TEXT,
                    value  = textBuf,
                    line   = textLine,
                    column = textCol,
                }
                textBuf = ""
            end
            textLine = line
            textCol  = column
        end

        while not isEnd() do repeat -- repeat/until true simulates continue via break

            -- HTML comment: <!-- ... -->
            if peekStr(4) == "<!--" then
                flushText()
                advance(4)
                while not isEnd() and peekStr(3) ~= "-->" do
                    advance()
                end
                if not isEnd() then advance(3) end
                textLine = line
                textCol  = column
                break
            end

            -- Close tag: </tagName>
            if peekStr(2) == "</" then
                flushText()
                advance(2)
                skipWhitespace()
                local tagName = readIdentifier()
                skipWhitespace()
                if not isEnd() and peek() == ">" then advance() end
                emit(TokenType.TAG_CLOSE, tagName)
                textLine = line
                textCol  = column
                break
            end

            -- Open tag: <tagName
            if peek() == "<" and isAlpha(peek(1)) then
                flushText()
                local tagLine = line
                local tagCol  = column
                advance() -- skip <
                local tagName = readIdentifier()
                emit(TokenType.TAG_OPEN, tagName, nil, tagLine, tagCol)
                scanTag()
                textLine = line
                textCol  = column
                break
            end

            -- Output directive: {{ expression }}
            if peekStr(2) == "{{" then
                flushText()
                local startLine = line
                local startCol  = column
                advance(2) -- skip {{
                local exprStart = pos
                while not isEnd() and peekStr(2) ~= "}}" do
                    advance()
                end
                local expr = source:sub(exprStart, pos - 1)
                if not isEnd() then advance(2) end -- skip }}
                expr = expr:match("^%s*(.-)%s*$")
                emit(TokenType.OUTPUT, expr, nil, startLine, startCol)
                textLine = line
                textCol  = column
                break
            end

            -- @else if (condition) {
            if peekStr(8) == "@else if" then
                local after = peek(8)
                if after and (after == " " or after == "(") then
                    flushText()
                    local startLine = line
                    local startCol  = column
                    advance(8) -- skip @else if
                    skipWhitespace()
                    if not isEnd() and peek() == "(" then
                        advance()
                        local condition = readParenExpression()
                        emit(TokenType.ELSE_IF_START, condition, nil, startLine, startCol)
                    end
                    skipWhitespace()
                    if not isEnd() and peek() == "{" then
                        emit(TokenType.BLOCK_OPEN, "{")
                        advance()
                    end
                    textLine = line
                    textCol  = column
                    break
                end
            end

            -- @else {
            if peekStr(5) == "@else" then
                local after = peek(5)
                if after and (after == " " or after == "{") then
                    -- Make sure it's not @else if (handled above)
                    local rest = source:sub(pos + 5):match("^%s*(%S*)")
                    if rest ~= "if" then
                        flushText()
                        local startLine = line
                        local startCol  = column
                        advance(5) -- skip @else
                        emit(TokenType.ELSE_START, "", nil, startLine, startCol)
                        skipWhitespace()
                        if not isEnd() and peek() == "{" then
                            emit(TokenType.BLOCK_OPEN, "{")
                            advance()
                        end
                        textLine = line
                        textCol  = column
                        break
                    end
                end
            end

            -- @if (condition) {
            if peekStr(3) == "@if" then
                local after = peek(3)
                if after and (after == " " or after == "(" or after == "\t" or after == "\n") then
                    flushText()
                    local startLine = line
                    local startCol  = column
                    advance(3) -- skip @if
                    skipWhitespace()
                    if not isEnd() and peek() == "(" then
                        advance()
                        local condition = readParenExpression()
                        emit(TokenType.IF_START, condition, nil, startLine, startCol)
                    end
                    skipWhitespace()
                    if not isEnd() and peek() == "{" then
                        emit(TokenType.BLOCK_OPEN, "{")
                        advance()
                    end
                    textLine = line
                    textCol  = column
                    break
                end
            end

            -- @for (item in expr) {
            if peekStr(4) == "@for" then
                local after = peek(4)
                if after and (after == " " or after == "(" or after == "\t" or after == "\n") then
                    flushText()
                    local startLine = line
                    local startCol  = column
                    advance(4) -- skip @for
                    skipWhitespace()
                    if not isEnd() and peek() == "(" then
                        advance()
                        local fullExpr = readParenExpression()
                        local iterator, iterable = fullExpr:match("^(%S+)%s+in%s+(.+)$")
                        if not iterator then
                            iterator = fullExpr
                            iterable = ""
                        end
                        iterator = iterator:match("^%s*(.-)%s*$")
                        iterable = iterable:match("^%s*(.-)%s*$")
                        emit(TokenType.FOR_START, iterator, iterable, startLine, startCol)
                    end
                    skipWhitespace()
                    if not isEnd() and peek() == "{" then
                        emit(TokenType.BLOCK_OPEN, "{")
                        advance()
                    end
                    textLine = line
                    textCol  = column
                    break
                end
            end

            -- Directive block close: }
            if peek() == "}" then
                flushText()
                emit(TokenType.BLOCK_CLOSE, "}")
                advance()
                textLine = line
                textCol  = column
                break
            end

            -- Regular text character
            if #textBuf == 0 then
                textLine = line
                textCol  = column
            end
            textBuf = textBuf .. peek()
            advance()

        until true end

        flushText()
    end

    ---------------------------------------------------------------------------
    -- Run
    ---------------------------------------------------------------------------

    scanContent()
    emit(TokenType.EOF, "")
    return tokens
end

return HtmlLexer
