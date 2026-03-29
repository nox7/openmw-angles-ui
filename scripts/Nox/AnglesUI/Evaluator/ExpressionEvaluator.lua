local ExpressionEvaluator = {}
ExpressionEvaluator.__index = ExpressionEvaluator

function ExpressionEvaluator.new()
  local self = setmetatable({}, ExpressionEvaluator)
  return self
end

-- Trim whitespace from both ends of a string
local function trim(str)
  return string.match(str, "^%s*(.-)%s*$") or str
end

-- Find position of an operator string at the top level (outside quotes and parens)
local function findTopLevelOperator(str, operator)
  local i = 1
  local len = #str
  local opLen = #operator
  local parenDepth = 0
  local inSingleQuote = false
  local inDoubleQuote = false

  while i <= len do
    local ch = string.sub(str, i, i)

    if ch == "\\" and (inSingleQuote or inDoubleQuote) then
      i = i + 2
    elseif ch == "'" and not inDoubleQuote then
      inSingleQuote = not inSingleQuote
      i = i + 1
    elseif ch == '"' and not inSingleQuote then
      inDoubleQuote = not inDoubleQuote
      i = i + 1
    elseif not inSingleQuote and not inDoubleQuote then
      if ch == "(" then
        parenDepth = parenDepth + 1
        i = i + 1
      elseif ch == ")" then
        parenDepth = parenDepth - 1
        i = i + 1
      elseif parenDepth == 0 and string.sub(str, i, i + opLen - 1) == operator then
        return i
      else
        i = i + 1
      end
    else
      i = i + 1
    end
  end

  return nil
end

-- Evaluate an expression string against a context
function ExpressionEvaluator:evaluate(expression, context)
  expression = trim(expression)

  -- Try || (logical OR) - lowest precedence
  local orPos = findTopLevelOperator(expression, "||")
  if orPos then
    local left = trim(string.sub(expression, 1, orPos - 1))
    local right = trim(string.sub(expression, orPos + 2))
    local leftVal = self:evaluate(left, context)
    if leftVal then
      return leftVal
    end
    return self:evaluate(right, context)
  end

  -- Try && (logical AND)
  local andPos = findTopLevelOperator(expression, "&&")
  if andPos then
    local left = trim(string.sub(expression, 1, andPos - 1))
    local right = trim(string.sub(expression, andPos + 2))
    local leftVal = self:evaluate(left, context)
    if not leftVal then
      return false
    end
    return self:evaluate(right, context)
  end

  -- Try == (equality)
  local eqPos = findTopLevelOperator(expression, "==")
  if eqPos then
    local left = trim(string.sub(expression, 1, eqPos - 1))
    local right = trim(string.sub(expression, eqPos + 2))
    local leftVal = self:evaluate(left, context)
    local rightVal = self:evaluate(right, context)
    return leftVal == rightVal
  end

  -- Try != (inequality)
  local neqPos = findTopLevelOperator(expression, "!=")
  if neqPos then
    local left = trim(string.sub(expression, 1, neqPos - 1))
    local right = trim(string.sub(expression, neqPos + 2))
    local leftVal = self:evaluate(left, context)
    local rightVal = self:evaluate(right, context)
    return leftVal ~= rightVal
  end

  -- Try ternary: condition ? trueExpr : falseExpr
  local questionPos = findTopLevelOperator(expression, "?")
  if questionPos then
    local condition = trim(string.sub(expression, 1, questionPos - 1))
    local remainder = string.sub(expression, questionPos + 1)
    local colonPos = findTopLevelOperator(remainder, ":")
    if colonPos then
      local trueExpr = trim(string.sub(remainder, 1, colonPos - 1))
      local falseExpr = trim(string.sub(remainder, colonPos + 1))
      local condVal = self:evaluate(condition, context)
      if condVal then
        return self:evaluate(trueExpr, context)
      else
        return self:evaluate(falseExpr, context)
      end
    end
  end

  -- Try logical NOT: !expression
  if string.sub(expression, 1, 1) == "!" then
    local inner = trim(string.sub(expression, 2))
    local val = self:evaluate(inner, context)
    return not val
  end

  -- Parenthesized expression
  if string.sub(expression, 1, 1) == "(" and string.sub(expression, -1) == ")" then
    local inner = trim(string.sub(expression, 2, -2))
    return self:evaluate(inner, context)
  end

  -- String literal (double-quoted)
  if string.sub(expression, 1, 1) == '"' and string.sub(expression, -1) == '"' then
    return string.sub(expression, 2, -2)
  end

  -- String literal (single-quoted)
  if string.sub(expression, 1, 1) == "'" and string.sub(expression, -1) == "'" then
    return string.sub(expression, 2, -2)
  end

  -- Numeric literal
  local num = tonumber(expression)
  if num then
    return num
  end

  -- Boolean literals
  if expression == "true" then
    return true
  end
  if expression == "false" then
    return false
  end

  -- Nil literal
  if expression == "nil" then
    return nil
  end

  -- Dot-access variable reference (e.g., "item.name")
  local dotPos = string.find(expression, "%.")
  if dotPos then
    local rootName = string.sub(expression, 1, dotPos - 1)
    local remainder = string.sub(expression, dotPos + 1)
    local value = context:get(rootName)
    -- Walk dot-separated path
    for segment in string.gmatch(remainder, "[^%.]+") do
      if type(value) == "table" then
        value = value[segment]
      else
        return nil
      end
    end
    return value
  end

  -- Simple variable reference
  return context:get(expression)
end

-- Evaluate an expression and return the result as a string for display
function ExpressionEvaluator:evaluateToString(expression, context)
  local result = self:evaluate(expression, context)
  if result == nil then
    return ""
  end
  return tostring(result)
end

-- Evaluate a condition expression and return a boolean
function ExpressionEvaluator:evaluateCondition(expression, context)
  local result = self:evaluate(expression, context)
  if result then
    return true
  end
  return false
end

return ExpressionEvaluator
