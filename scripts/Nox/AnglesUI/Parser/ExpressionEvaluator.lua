--- AnglesUI Expression Evaluator.
--- Evaluates JS-like expressions used in Angular-style bindings, directive
--- conditions, output directives ({{ }}), and event handlers.
---
--- Supported expression features:
---   - Identifiers and property access (dot notation): `item.Name`, `Items().Armor`
---   - Function calls: `SomeFunc()`, `Items().Filter(x)`
---   - String literals: `'hello'`, `"world"`
---   - Number literals: `42`, `3.14`, `-5`
---   - Boolean literals: `true`, `false`
---   - Nil literal: `nil`, `null`
---   - Comparison: `===`, `!==`, `==`, `!=`, `>`, `<`, `>=`, `<=`
---   - Logical: `&&`, `||`, `!`
---   - Ternary: `condition ? trueExpr : falseExpr`
---   - Parenthesised grouping: `(expr)`
---   - Arithmetic: `+`, `-`, `*`, `/`, `%`
---   - Concatenation via `+` on strings (JS-style)
---   - Special placeholders: `$event1`, `$event2`, `$index`

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

--- @class AnglesUI.ExpressionEvaluator
local ExpressionEvaluator = {}

---------------------------------------------------------------------------
-- Token types for the expression mini-lexer
---------------------------------------------------------------------------

--- @enum AnglesUI.ExprTokenType
local ETT = {
    NUMBER   = "NUMBER",
    STRING   = "STRING",
    BOOL     = "BOOL",
    NIL      = "NIL",
    IDENT    = "IDENT",
    DOT      = "DOT",
    LPAREN   = "LPAREN",
    RPAREN   = "RPAREN",
    LBRACKET = "LBRACKET",
    RBRACKET = "RBRACKET",
    COMMA    = "COMMA",
    PLUS     = "PLUS",
    MINUS    = "MINUS",
    STAR     = "STAR",
    SLASH    = "SLASH",
    PERCENT  = "PERCENT",
    BANG     = "BANG",
    AND      = "AND",     -- &&
    OR       = "OR",      -- ||
    EQ       = "EQ",      -- === or ==
    NEQ      = "NEQ",     -- !== or !=
    GT       = "GT",
    GTE      = "GTE",
    LT       = "LT",
    LTE      = "LTE",
    QUESTION = "QUESTION",
    COLON    = "COLON",
    EOF      = "EOF",
}

--- @class AnglesUI.ExprToken
--- @field type AnglesUI.ExprTokenType
--- @field value any

---------------------------------------------------------------------------
-- Expression lexer
---------------------------------------------------------------------------

--- Tokenize an expression string.
--- @param source string
--- @return AnglesUI.ExprToken[]
local function tokenize(source)
    local tokens = {}
    local pos = 1
    local len = #source

    local function peek(offset)
        local p = pos + (offset or 0)
        if p > len then return nil end
        return source:sub(p, p)
    end

    local function advance(count)
        pos = pos + (count or 1)
    end

    local function isDigit(ch)
        return ch and ch:match("%d") ~= nil
    end

    local function isIdentStart(ch)
        return ch and ch:match("[a-zA-Z_$]") ~= nil
    end

    local function isIdentChar(ch)
        return ch and ch:match("[a-zA-Z0-9_$]") ~= nil
    end

    while pos <= len do
        local ch = peek()

        -- Skip whitespace
        if ch == " " or ch == "\t" or ch == "\n" or ch == "\r" then
            advance()

        -- String literal
        elseif ch == "'" or ch == '"' then
            local quote = ch
            advance()
            local start = pos
            while pos <= len and peek() ~= quote do
                if peek() == "\\" then advance() end
                advance()
            end
            local value = source:sub(start, pos - 1)
            advance() -- skip closing quote
            tokens[#tokens + 1] = { type = ETT.STRING, value = value }

        -- Number
        elseif isDigit(ch) or (ch == "." and isDigit(peek(1))) then
            local start = pos
            while pos <= len and isDigit(peek()) do advance() end
            if pos <= len and peek() == "." and isDigit(peek(1)) then
                advance()
                while pos <= len and isDigit(peek()) do advance() end
            end
            tokens[#tokens + 1] = { type = ETT.NUMBER, value = tonumber(source:sub(start, pos - 1)) }

        -- Identifiers and keywords
        elseif isIdentStart(ch) then
            local start = pos
            while pos <= len and isIdentChar(peek()) do advance() end
            local word = source:sub(start, pos - 1)

            if word == "true" then
                tokens[#tokens + 1] = { type = ETT.BOOL, value = true }
            elseif word == "false" then
                tokens[#tokens + 1] = { type = ETT.BOOL, value = false }
            elseif word == "nil" or word == "null" or word == "undefined" then
                tokens[#tokens + 1] = { type = ETT.NIL, value = nil }
            else
                tokens[#tokens + 1] = { type = ETT.IDENT, value = word }
            end

        -- Two-char operators
        elseif ch == "=" and peek(1) == "=" then
            if peek(2) == "=" then
                advance(3) -- ===
            else
                advance(2) -- ==
            end
            tokens[#tokens + 1] = { type = ETT.EQ, value = "==" }

        elseif ch == "!" and peek(1) == "=" then
            if peek(2) == "=" then
                advance(3) -- !==
            else
                advance(2) -- !=
            end
            tokens[#tokens + 1] = { type = ETT.NEQ, value = "!=" }

        elseif ch == "&" and peek(1) == "&" then
            advance(2)
            tokens[#tokens + 1] = { type = ETT.AND, value = "&&" }

        elseif ch == "|" and peek(1) == "|" then
            advance(2)
            tokens[#tokens + 1] = { type = ETT.OR, value = "||" }

        elseif ch == ">" and peek(1) == "=" then
            advance(2)
            tokens[#tokens + 1] = { type = ETT.GTE, value = ">=" }

        elseif ch == "<" and peek(1) == "=" then
            advance(2)
            tokens[#tokens + 1] = { type = ETT.LTE, value = "<=" }

        -- Single-char operators & punctuation
        elseif ch == ">" then advance(); tokens[#tokens + 1] = { type = ETT.GT, value = ">" }
        elseif ch == "<" then advance(); tokens[#tokens + 1] = { type = ETT.LT, value = "<" }
        elseif ch == "!" then advance(); tokens[#tokens + 1] = { type = ETT.BANG, value = "!" }
        elseif ch == "+" then advance(); tokens[#tokens + 1] = { type = ETT.PLUS, value = "+" }
        elseif ch == "-" then advance(); tokens[#tokens + 1] = { type = ETT.MINUS, value = "-" }
        elseif ch == "*" then advance(); tokens[#tokens + 1] = { type = ETT.STAR, value = "*" }
        elseif ch == "/" then advance(); tokens[#tokens + 1] = { type = ETT.SLASH, value = "/" }
        elseif ch == "%" then advance(); tokens[#tokens + 1] = { type = ETT.PERCENT, value = "%" }
        elseif ch == "." then advance(); tokens[#tokens + 1] = { type = ETT.DOT, value = "." }
        elseif ch == "(" then advance(); tokens[#tokens + 1] = { type = ETT.LPAREN, value = "(" }
        elseif ch == ")" then advance(); tokens[#tokens + 1] = { type = ETT.RPAREN, value = ")" }
        elseif ch == "[" then advance(); tokens[#tokens + 1] = { type = ETT.LBRACKET, value = "[" }
        elseif ch == "]" then advance(); tokens[#tokens + 1] = { type = ETT.RBRACKET, value = "]" }
        elseif ch == "," then advance(); tokens[#tokens + 1] = { type = ETT.COMMA, value = "," }
        elseif ch == "?" then advance(); tokens[#tokens + 1] = { type = ETT.QUESTION, value = "?" }
        elseif ch == ":" then advance(); tokens[#tokens + 1] = { type = ETT.COLON, value = ":" }

        else
            advance() -- skip unknown
        end
    end

    tokens[#tokens + 1] = { type = ETT.EOF, value = nil }
    return tokens
end

---------------------------------------------------------------------------
-- Recursive descent expression parser / evaluator
---------------------------------------------------------------------------

--- @class AnglesUI._ExprState
--- @field tokens AnglesUI.ExprToken[]
--- @field pos integer
--- @field context table<string, any>

--- @param state AnglesUI._ExprState
--- @return AnglesUI.ExprToken
local function current(state)
    return state.tokens[state.pos]
end

--- @param state AnglesUI._ExprState
local function advance(state)
    state.pos = state.pos + 1
end

--- @param state AnglesUI._ExprState
--- @return boolean
local function isEnd(state)
    return current(state).type == ETT.EOF
end

--- @param state AnglesUI._ExprState
--- @param tokenType AnglesUI.ExprTokenType
--- @return boolean
local function check(state, tokenType)
    return current(state).type == tokenType
end

--- @param state AnglesUI._ExprState
--- @param tokenType AnglesUI.ExprTokenType
--- @return AnglesUI.ExprToken?
local function consume(state, tokenType)
    if current(state).type == tokenType then
        local tok = current(state)
        advance(state)
        return tok
    end
    return nil
end

---------------------------------------------------------------------------
-- Grammar (precedence low→high):
--   ternary     → logicalOr ('?' ternary ':' ternary)?
--   logicalOr   → logicalAnd ('||' logicalAnd)*
--   logicalAnd  → equality ('&&' equality)*
--   equality    → comparison (('==' | '!=') comparison)*
--   comparison  → addition (('>' | '>=' | '<' | '<=') addition)*
--   addition    → multiply (('+' | '-') multiply)*
--   multiply    → unary (('*' | '/' | '%') unary)*
--   unary       → ('!' | '-') unary | postfix
--   postfix     → primary (('.' IDENT | '(' args ')' | '[' expr ']')*)
--   primary     → NUMBER | STRING | BOOL | NIL | IDENT | '(' ternary ')'
---------------------------------------------------------------------------

--- Forward declarations
--- @type fun(state: AnglesUI._ExprState): any
local parseTernary

--- @param state AnglesUI._ExprState
--- @return any
local function parsePrimary(state)
    local tok = current(state)

    if tok.type == ETT.NUMBER then
        advance(state)
        return tok.value
    end

    if tok.type == ETT.STRING then
        advance(state)
        return tok.value
    end

    if tok.type == ETT.BOOL then
        advance(state)
        return tok.value
    end

    if tok.type == ETT.NIL then
        advance(state)
        return nil
    end

    if tok.type == ETT.IDENT then
        local name = tok.value
        advance(state)
        -- Look up in context
        local value = state.context[name]
        return value
    end

    if tok.type == ETT.LPAREN then
        advance(state) -- skip (
        local value = parseTernary(state)
        consume(state, ETT.RPAREN)
        return value
    end

    -- Unexpected token — return nil
    advance(state)
    return nil
end

--- Parse postfix operations: property access, function calls, bracket access.
--- @param state AnglesUI._ExprState
--- @return any
local function parsePostfix(state)
    local value = parsePrimary(state)

    while not isEnd(state) do
        -- Property access: .name
        if check(state, ETT.DOT) then
            advance(state) -- skip .
            local propTok = current(state)
            if propTok.type == ETT.IDENT then
                advance(state)
                if value ~= nil and type(value) == "table" then
                    value = value[propTok.value]
                else
                    value = nil
                end
            else
                value = nil
            end

        -- Function call: (args)
        elseif check(state, ETT.LPAREN) then
            advance(state) -- skip (
            local args = {}
            if not check(state, ETT.RPAREN) then
                args[#args + 1] = parseTernary(state)
                while consume(state, ETT.COMMA) do
                    args[#args + 1] = parseTernary(state)
                end
            end
            consume(state, ETT.RPAREN)

            if type(value) == "function" then
                value = value(table.unpack(args))
            else
                value = nil
            end

        -- Bracket access: [expr]
        elseif check(state, ETT.LBRACKET) then
            advance(state) -- skip [
            local key = parseTernary(state)
            consume(state, ETT.RBRACKET)
            if value ~= nil and type(value) == "table" and key ~= nil then
                value = value[key]
            else
                value = nil
            end

        else
            break
        end
    end

    return value
end

--- Parse unary: ! and negation -
--- @param state AnglesUI._ExprState
--- @return any
local function parseUnary(state)
    if check(state, ETT.BANG) then
        advance(state)
        local value = parseUnary(state)
        return not value
    end

    if check(state, ETT.MINUS) then
        -- Could be unary minus — check if previous token suggests this is unary
        advance(state)
        local value = parseUnary(state)
        return -(tonumber(value) or 0)
    end

    return parsePostfix(state)
end

--- Parse multiplication/division/modulo.
--- @param state AnglesUI._ExprState
--- @return any
local function parseMultiply(state)
    local left = parseUnary(state)

    while not isEnd(state) do
        if check(state, ETT.STAR) then
            advance(state)
            local right = parseUnary(state)
            left = (tonumber(left) or 0) * (tonumber(right) or 0)
        elseif check(state, ETT.SLASH) then
            advance(state)
            local right = parseUnary(state)
            local rNum = tonumber(right) or 0
            left = rNum ~= 0 and ((tonumber(left) or 0) / rNum) or 0
        elseif check(state, ETT.PERCENT) then
            advance(state)
            local right = parseUnary(state)
            local rNum = tonumber(right) or 0
            left = rNum ~= 0 and ((tonumber(left) or 0) % rNum) or 0
        else
            break
        end
    end

    return left
end

--- Parse addition/subtraction (and string concatenation via +).
--- @param state AnglesUI._ExprState
--- @return any
local function parseAddition(state)
    local left = parseMultiply(state)

    while not isEnd(state) do
        if check(state, ETT.PLUS) then
            advance(state)
            local right = parseMultiply(state)
            -- JS-style: if either is string, concatenate
            if type(left) == "string" or type(right) == "string" then
                left = tostring(left or "") .. tostring(right or "")
            else
                left = (tonumber(left) or 0) + (tonumber(right) or 0)
            end
        elseif check(state, ETT.MINUS) then
            advance(state)
            local right = parseMultiply(state)
            left = (tonumber(left) or 0) - (tonumber(right) or 0)
        else
            break
        end
    end

    return left
end

--- Parse comparison operators.
--- @param state AnglesUI._ExprState
--- @return any
local function parseComparison(state)
    local left = parseAddition(state)

    while not isEnd(state) do
        if check(state, ETT.GT) then
            advance(state)
            local right = parseAddition(state)
            left = (tonumber(left) or 0) > (tonumber(right) or 0)
        elseif check(state, ETT.GTE) then
            advance(state)
            local right = parseAddition(state)
            left = (tonumber(left) or 0) >= (tonumber(right) or 0)
        elseif check(state, ETT.LT) then
            advance(state)
            local right = parseAddition(state)
            left = (tonumber(left) or 0) < (tonumber(right) or 0)
        elseif check(state, ETT.LTE) then
            advance(state)
            local right = parseAddition(state)
            left = (tonumber(left) or 0) <= (tonumber(right) or 0)
        else
            break
        end
    end

    return left
end

--- Parse equality operators.
--- @param state AnglesUI._ExprState
--- @return any
local function parseEquality(state)
    local left = parseComparison(state)

    while not isEnd(state) do
        if check(state, ETT.EQ) then
            advance(state)
            local right = parseComparison(state)
            left = (left == right)
        elseif check(state, ETT.NEQ) then
            advance(state)
            local right = parseComparison(state)
            left = (left ~= right)
        else
            break
        end
    end

    return left
end

--- Parse logical AND.
--- @param state AnglesUI._ExprState
--- @return any
local function parseLogicalAnd(state)
    local left = parseEquality(state)

    while not isEnd(state) and check(state, ETT.AND) do
        advance(state)
        local right = parseEquality(state)
        -- JS-style short-circuit
        if not left then
            left = left -- stays falsy
        else
            left = right
        end
    end

    return left
end

--- Parse logical OR.
--- @param state AnglesUI._ExprState
--- @return any
local function parseLogicalOr(state)
    local left = parseLogicalAnd(state)

    while not isEnd(state) and check(state, ETT.OR) do
        advance(state)
        local right = parseLogicalAnd(state)
        -- JS-style short-circuit
        if left then
            -- left is truthy, keep it
        else
            left = right
        end
    end

    return left
end

--- Parse ternary: expr ? trueExpr : falseExpr
--- @param state AnglesUI._ExprState
--- @return any
parseTernary = function(state)
    local condition = parseLogicalOr(state)

    if not isEnd(state) and check(state, ETT.QUESTION) then
        advance(state) -- skip ?
        local trueVal = parseTernary(state)
        consume(state, ETT.COLON)
        local falseVal = parseTernary(state)

        if condition then
            return trueVal
        else
            return falseVal
        end
    end

    return condition
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

--- Evaluate an expression string within a given context.
---
--- The context is a table where keys are variable names accessible in the
--- expression. Values can be any Lua type — signals (callable tables),
--- functions, strings, numbers, booleans, or nested tables.
---
--- @param expression string The expression to evaluate
--- @param context table<string, any> Variables available in the expression
--- @return any result The evaluated result
function ExpressionEvaluator.Evaluate(expression, context)
    if not expression or #expression == 0 then
        return nil
    end

    local tokens = tokenize(expression)
    --- @type AnglesUI._ExprState
    local state = {
        tokens  = tokens,
        pos     = 1,
        context = context or {},
    }

    return parseTernary(state)
end

--- Create a deferred evaluator — a function that will evaluate the expression
--- when called. Useful for event handlers where we don't want to evaluate
--- immediately but want the expression pre-tokenized.
---
--- @param expression string The expression to defer
--- @return fun(context: table<string, any>): any evaluator
function ExpressionEvaluator.Defer(expression)
    local tokens = tokenize(expression)

    return function(context)
        --- @type AnglesUI._ExprState
        local state = {
            tokens  = tokens,
            pos     = 1,
            context = context or {},
        }
        return parseTernary(state)
    end
end

return ExpressionEvaluator
