--- AnglesUI CSS Lexer / Tokenizer.
--- Scans CSS source into a flat token stream consumed by CssParser.
--- Handles identifiers, numbers, dimensions, strings, at-keywords,
--- hash selectors, functions, operators, and comments.

---------------------------------------------------------------------------
-- Token types
---------------------------------------------------------------------------

--- @enum AnglesUI.CssTokenType
local TokenType = {
    IDENT          = "IDENT",
    HASH           = "HASH",           -- #name (value = name without #)
    STRING         = "STRING",         -- "..." or '...' (value = content)
    NUMBER         = "NUMBER",         -- 42, 0.5, -3
    DIMENSION      = "DIMENSION",      -- 200px, 1fr, 16px
    PERCENTAGE     = "PERCENTAGE",     -- 50%
    FUNCTION_TOKEN = "FUNCTION",       -- name( (value = name)
    AT_KEYWORD     = "AT_KEYWORD",     -- @name (value = name)
    COLON          = "COLON",
    SEMICOLON      = "SEMICOLON",
    COMMA          = "COMMA",
    LBRACE         = "LBRACE",
    RBRACE         = "RBRACE",
    LPAREN         = "LPAREN",
    RPAREN         = "RPAREN",
    LBRACKET       = "LBRACKET",
    RBRACKET       = "RBRACKET",
    DOT            = "DOT",
    GREATER        = "GREATER",
    PLUS           = "PLUS",
    TILDE          = "TILDE",
    STAR           = "STAR",
    AMPERSAND      = "AMPERSAND",
    SLASH          = "SLASH",
    EQUALS         = "EQUALS",
    PIPE           = "PIPE",
    LESS           = "LESS",
    LESS_EQUAL     = "LESS_EQUAL",
    GREATER_EQUAL  = "GREATER_EQUAL",
    WHITESPACE     = "WHITESPACE",
    DELIM          = "DELIM",
    EOF            = "EOF",
}

---------------------------------------------------------------------------
-- Token class
---------------------------------------------------------------------------

--- @class AnglesUI.CssToken
--- @field type AnglesUI.CssTokenType
--- @field value string
--- @field startPos integer 1-based start position in source
--- @field endPos integer 1-based end position in source (inclusive)
--- @field line integer
--- @field column integer

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

--- @class AnglesUI.CssLexer
--- @field TokenType AnglesUI.CssTokenType
local CssLexer = {
    TokenType = TokenType,
}

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

--- Tokenize a CSS source string.
--- @param source string The raw CSS source
--- @return AnglesUI.CssToken[] tokens
function CssLexer.Tokenize(source)
    -- Scanner state -------------------------------------------------------
    local pos    = 1
    local line   = 1
    local column = 1
    local len    = #source
    local tokens = {}

    -- Helpers -------------------------------------------------------------

    local function peek(offset)
        local p = pos + (offset or 0)
        if p < 1 or p > len then return nil end
        return source:sub(p, p)
    end

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

    local function emit(tokenType, value, startP, endP)
        tokens[#tokens + 1] = {
            type     = tokenType,
            value    = value or "",
            startPos = startP,
            endPos   = endP,
            line     = line,
            column   = column,
        }
    end

    local function isEnd()
        return pos > len
    end

    local function isDigit(ch)
        return ch ~= nil and ch:match("%d") ~= nil
    end

    local function isIdentStart(ch)
        return ch ~= nil and ch:match("[a-zA-Z_]") ~= nil
    end

    local function isIdentChar(ch)
        return ch ~= nil and ch:match("[a-zA-Z0-9_%-]") ~= nil
    end

    local function isWhitespace(ch)
        return ch ~= nil and (ch == " " or ch == "\t" or ch == "\n" or ch == "\r")
    end

    --- Read an identifier from the current position.
    --- Assumes pos is at the first character of the ident.
    --- @return string
    local function readIdent()
        local start = pos
        while not isEnd() and isIdentChar(peek()) do
            advance()
        end
        return source:sub(start, pos - 1)
    end

    --- Check if the current position starts a number (with optional sign).
    --- The sign character should already have been validated by the caller.
    --- @param ch string Current character
    --- @return boolean
    local function isNumberStart(ch)
        if isDigit(ch) then return true end
        if ch == "." and isDigit(peek(1)) then return true end
        return false
    end

    --- Read a numeric token (number, dimension, or percentage).
    --- Starts from current pos. May begin with sign or digit or '.'.
    local function readNumericToken()
        local startP = pos
        local startLine = line
        local startCol  = column

        -- Optional sign
        if peek() == "-" or peek() == "+" then
            advance()
        end

        -- Integer part
        while not isEnd() and isDigit(peek()) do
            advance()
        end

        -- Decimal part
        if not isEnd() and peek() == "." and isDigit(peek(1)) then
            advance() -- skip .
            while not isEnd() and isDigit(peek()) do
                advance()
            end
        end

        local numText = source:sub(startP, pos - 1)

        -- Check for unit or %
        if not isEnd() and peek() == "%" then
            advance()
            local endP = pos - 1
            tokens[#tokens + 1] = {
                type = TokenType.PERCENTAGE, value = numText .. "%",
                startPos = startP, endPos = endP, line = startLine, column = startCol,
            }
        elseif not isEnd() and (isIdentStart(peek()) or peek() == "-") then
            local unitStart = pos
            -- Read unit identifier
            if peek() == "-" then advance() end
            while not isEnd() and isIdentChar(peek()) do
                advance()
            end
            local unit = source:sub(unitStart, pos - 1)
            local endP = pos - 1
            tokens[#tokens + 1] = {
                type = TokenType.DIMENSION, value = numText .. unit,
                startPos = startP, endPos = endP, line = startLine, column = startCol,
            }
        else
            local endP = pos - 1
            tokens[#tokens + 1] = {
                type = TokenType.NUMBER, value = numText,
                startPos = startP, endPos = endP, line = startLine, column = startCol,
            }
        end
    end

    --- Read an identifier-based token (IDENT or FUNCTION).
    local function readIdentToken()
        local startP    = pos
        local startLine = line
        local startCol  = column

        -- Handle leading - or --
        if peek() == "-" then
            advance()
            -- Could be -- (custom property) or -ident
        end

        -- Read rest of identifier
        while not isEnd() and isIdentChar(peek()) do
            advance()
        end

        local value = source:sub(startP, pos - 1)

        -- Check if followed by ( → function token
        if not isEnd() and peek() == "(" then
            local endP = pos -- includes the (
            advance() -- consume (
            tokens[#tokens + 1] = {
                type = TokenType.FUNCTION_TOKEN, value = value,
                startPos = startP, endPos = endP, line = startLine, column = startCol,
            }
        else
            local endP = pos - 1
            tokens[#tokens + 1] = {
                type = TokenType.IDENT, value = value,
                startPos = startP, endPos = endP, line = startLine, column = startCol,
            }
        end
    end

    --- Read a quoted string. Handles escape sequences.
    local function readStringToken()
        local startP    = pos
        local startLine = line
        local startCol  = column
        local quote     = peek()
        advance() -- skip opening quote

        local contentStart = pos
        while not isEnd() and peek() ~= quote do
            if peek() == "\\" then
                advance() -- skip escape
            end
            advance()
        end
        local content = source:sub(contentStart, pos - 1)
        if not isEnd() then advance() end -- skip closing quote
        local endP = pos - 1

        tokens[#tokens + 1] = {
            type = TokenType.STRING, value = content,
            startPos = startP, endPos = endP, line = startLine, column = startCol,
        }
    end

    --- Emit a simple single-character token.
    --- @param tokenType AnglesUI.CssTokenType
    --- @param value string
    local function emitSingle(tokenType, value)
        tokens[#tokens + 1] = {
            type = tokenType, value = value,
            startPos = pos, endPos = pos, line = line, column = column,
        }
        advance()
    end

    ---------------------------------------------------------------------------
    -- Main scanning loop
    ---------------------------------------------------------------------------

    while not isEnd() do
        local ch = peek()

        -- Whitespace
        if isWhitespace(ch) then
            local startP   = pos
            local startLine = line
            local startCol  = column
            while not isEnd() and isWhitespace(peek()) do
                advance()
            end
            tokens[#tokens + 1] = {
                type = TokenType.WHITESPACE, value = source:sub(startP, pos - 1),
                startPos = startP, endPos = pos - 1, line = startLine, column = startCol,
            }

        -- Comment: /* ... */
        elseif ch == "/" and peek(1) == "*" then
            advance(2) -- skip /*
            while not isEnd() do
                if peek() == "*" and peek(1) == "/" then
                    advance(2)
                    break
                end
                advance()
            end

        -- String
        elseif ch == '"' or ch == "'" then
            readStringToken()

        -- At-keyword: @name
        elseif ch == "@" then
            local startP    = pos
            local startLine = line
            local startCol  = column
            advance() -- skip @
            local name = readIdent()
            tokens[#tokens + 1] = {
                type = TokenType.AT_KEYWORD, value = name,
                startPos = startP, endPos = pos - 1, line = startLine, column = startCol,
            }

        -- Hash: #name
        elseif ch == "#" then
            local startP    = pos
            local startLine = line
            local startCol  = column
            advance() -- skip #
            local name = ""
            -- Hash names can start with digits in CSS (#123abc)
            while not isEnd() and (isIdentChar(peek()) or isDigit(peek())) do
                name = name .. peek()
                advance()
            end
            tokens[#tokens + 1] = {
                type = TokenType.HASH, value = name,
                startPos = startP, endPos = pos - 1, line = startLine, column = startCol,
            }

        -- Negative number or identifier starting with -
        elseif ch == "-" then
            local next = peek(1)
            if next and (isDigit(next) or (next == "." and isDigit(peek(2)))) then
                readNumericToken()
            elseif next and (isIdentStart(next) or next == "-") then
                readIdentToken()
            else
                emitSingle(TokenType.DELIM, "-")
            end

        -- Positive sign or number
        elseif ch == "+" then
            local next = peek(1)
            if next and (isDigit(next) or (next == "." and isDigit(peek(2)))) then
                readNumericToken()
            else
                emitSingle(TokenType.PLUS, "+")
            end

        -- Number starting with digit
        elseif isDigit(ch) then
            readNumericToken()

        -- Number starting with .  OR  dot selector
        elseif ch == "." then
            if isDigit(peek(1)) then
                readNumericToken()
            else
                emitSingle(TokenType.DOT, ".")
            end

        -- Identifier or function
        elseif isIdentStart(ch) then
            readIdentToken()

        -- Two-character operators
        elseif ch == ">" then
            if peek(1) == "=" then
                tokens[#tokens + 1] = {
                    type = TokenType.GREATER_EQUAL, value = ">=",
                    startPos = pos, endPos = pos + 1, line = line, column = column,
                }
                advance(2)
            else
                emitSingle(TokenType.GREATER, ">")
            end

        elseif ch == "<" then
            if peek(1) == "=" then
                tokens[#tokens + 1] = {
                    type = TokenType.LESS_EQUAL, value = "<=",
                    startPos = pos, endPos = pos + 1, line = line, column = column,
                }
                advance(2)
            else
                emitSingle(TokenType.LESS, "<")
            end

        -- Single-character tokens
        elseif ch == "{" then emitSingle(TokenType.LBRACE,    "{")
        elseif ch == "}" then emitSingle(TokenType.RBRACE,    "}")
        elseif ch == "(" then emitSingle(TokenType.LPAREN,    "(")
        elseif ch == ")" then emitSingle(TokenType.RPAREN,    ")")
        elseif ch == "[" then emitSingle(TokenType.LBRACKET,  "[")
        elseif ch == "]" then emitSingle(TokenType.RBRACKET,  "]")
        elseif ch == ":" then emitSingle(TokenType.COLON,     ":")
        elseif ch == ";" then emitSingle(TokenType.SEMICOLON, ";")
        elseif ch == "," then emitSingle(TokenType.COMMA,     ",")
        elseif ch == "*" then emitSingle(TokenType.STAR,      "*")
        elseif ch == "&" then emitSingle(TokenType.AMPERSAND, "&")
        elseif ch == "~" then emitSingle(TokenType.TILDE,     "~")
        elseif ch == "=" then emitSingle(TokenType.EQUALS,    "=")
        elseif ch == "|" then emitSingle(TokenType.PIPE,      "|")
        elseif ch == "/" then emitSingle(TokenType.SLASH,      "/")

        -- Any other character
        else
            emitSingle(TokenType.DELIM, ch)
        end
    end

    -- EOF
    tokens[#tokens + 1] = {
        type = TokenType.EOF, value = "",
        startPos = pos, endPos = pos, line = line, column = column,
    }

    return tokens
end

return CssLexer
