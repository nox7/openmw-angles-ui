local Node = require("scripts.Nox.AnglesUI.Lexer.Nodes.Node")
local TextNode = require("scripts.Nox.AnglesUI.Lexer.Nodes.TextNode")
local ComponentNode = require("scripts.Nox.AnglesUI.Lexer.Nodes.ComponentNode")
local EngineComponentNode = require("scripts.Nox.AnglesUI.Lexer.Nodes.EngineComponentNode")
local ExpressionEvaluator = require("scripts.Nox.AnglesUI.Evaluator.ExpressionEvaluator")
local Lexer = require("scripts.Nox.AnglesUI.Lexer.Lexer")

---@class Evaluator Walks a Lexer-produced AST and returns a fully resolved tree with bindings, directives, and user components expanded.
---@field expressionEvaluator ExpressionEvaluator Used to evaluate attribute bindings and directive conditions.
---@field userComponents table<string, UserComponent> Map of selector to UserComponent for resolving custom element nodes.
local Evaluator = {}
Evaluator.__index = Evaluator

---@param userComponents table<string, UserComponent>|nil Map of selector names to registered UserComponent instances.
---@return Evaluator
function Evaluator.new(userComponents)
  local self = setmetatable({}, Evaluator)
  self.expressionEvaluator = ExpressionEvaluator.new()
  self.userComponents = userComponents or {}
  return self
end

-- Evaluate an AST against a context, returning a new tree of resolved nodes
---@param astRoot Node The root node of the AST produced by the Lexer.
---@param context Context The variable scope supplying signal values and functions.
---@return Node A new root Node whose children are fully resolved and ready for the Renderer.
function Evaluator:evaluate(astRoot, context)
  local resultRoot = Node.new("Root")
  self:evaluateChildren(astRoot.children, context, resultRoot)
  return resultRoot
end

-- Evaluate a list of child nodes and add resolved nodes to the parent
---@param children Node[] The child nodes to evaluate.
---@param context Context Current variable scope.
---@param parentNode Node Parent node to which resolved children are appended.
function Evaluator:evaluateChildren(children, context, parentNode)
  for _, child in ipairs(children) do
    local resolvedNodes = self:evaluateNode(child, context)
    for _, resolved in ipairs(resolvedNodes) do
      parentNode:addChild(resolved)
    end
  end
end

-- Evaluate a single node, returning a list of resolved nodes
-- (a list because for-loops expand into multiple nodes)
---@param node Node The node to evaluate.
---@param context Context Current variable scope.
---@return Node[] Zero or more resolved nodes. `@for` directives may return more than one.
function Evaluator:evaluateNode(node, context)
  if node.type == Node.TYPE_TEXT then
    return { TextNode.new(node.text) }
  elseif node.type == Node.TYPE_OUTPUT then
    return self:evaluateOutputNode(node, context)
  elseif node.type == Node.TYPE_ENGINE_COMPONENT then
    return self:evaluateEngineComponentNode(node, context)
  elseif node.type == Node.TYPE_USER_COMPONENT then
    return self:evaluateUserComponentNode(node, context)
  elseif node.type == Node.TYPE_COMPONENT then
    return self:evaluateEngineComponentNode(node, context)
  elseif node.type == Node.TYPE_IF_DIRECTIVE then
    return self:evaluateIfNode(node, context)
  elseif node.type == Node.TYPE_FOR_DIRECTIVE then
    return self:evaluateForNode(node, context)
  end

  return {}
end

-- Evaluate an OutputDirectiveNode: resolve the expression to a text value
---@param node OutputDirectiveNode The output directive node containing expression data.
---@param context Context Current variable scope.
---@return TextNode[] A single-element list containing a TextNode with the resolved string.
function Evaluator:evaluateOutputNode(node, context)
  local result
  if node.isTernary then
    local condVal = self.expressionEvaluator:evaluateCondition(node.ternaryCondition, context)
    if condVal then
      result = self.expressionEvaluator:evaluateToString(node.ternaryTrueExpression, context)
    else
      result = self.expressionEvaluator:evaluateToString(node.ternaryFalseExpression, context)
    end
  else
    result = self.expressionEvaluator:evaluateToString(node.expression, context)
  end

  return { TextNode.new(result) }
end

-- Evaluate an EngineComponentNode: resolve square-bracket attribute bindings
---@param node EngineComponentNode The engine component with raw attribute expressions.
---@param context Context Current variable scope.
---@return EngineComponentNode[] A single-element list with the node's attributes fully resolved.
function Evaluator:evaluateEngineComponentNode(node, context)
  local resolvedAttributes = {}
  local dynamicClasses = {}  -- accumulated from [class.X] bindings

  for attrName, attrValue in pairs(node.attributes) do
    local bindingName = string.match(attrName, "^%[(.+)%]$")
    if bindingName then
      -- [class.X] binding: append the class name only when the expression is truthy.
      local className = string.match(bindingName, "^class%.(.+)$")
      if className then
        local condVal = self.expressionEvaluator:evaluate(attrValue, context)
        if condVal ~= nil and condVal ~= false then
          table.insert(dynamicClasses, className)
        end
      else
        -- Regular evaluated binding (e.g. [style.height], [Width]).
        local resolvedValue = self.expressionEvaluator:evaluate(attrValue, context)
        if resolvedValue ~= nil then
          resolvedAttributes[bindingName] = resolvedValue
        end
      end
    else
      -- Event binding: (eventName)="FuncName" or (eventName)="FuncName($arg1, $arg2)"
      -- $arg1 and $arg2 are always provided when the event fires; the notation in the template
      -- is purely documentary.  Only the function identifier is resolved here.
      local eventName = string.match(attrName, "^%((.+)%)$")
      if eventName then
        local funcExpr = attrValue and string.match(attrValue, "^([%w_%.]+)") or nil
        if funcExpr ~= nil then
          local resolvedFunc = self.expressionEvaluator:evaluate(funcExpr, context)
          if resolvedFunc ~= nil then
            resolvedAttributes["event:" .. eventName] = resolvedFunc
          end
        end
      else
        -- Static attribute, pass through as-is.
        resolvedAttributes[attrName] = attrValue
      end
    end
  end

  -- Merge dynamic class bindings with any static class attribute.
  if (#dynamicClasses > 0) then
    local existingClass = resolvedAttributes["class"] or ""
    local parts = {}
    for cls in string.gmatch(existingClass, "%S+") do
      table.insert(parts, cls)
    end
    for _, cls in ipairs(dynamicClasses) do
      table.insert(parts, cls)
    end
    resolvedAttributes["class"] = table.concat(parts, " ")
  end

  local resolvedNode = EngineComponentNode.new(node.tagName, resolvedAttributes, node.selfClosing)

  -- Evaluate children
  self:evaluateChildren(node.children, context, resolvedNode)

  return { resolvedNode }
end

-- Evaluate a UserComponentNode: parse its template and evaluate with parent context
---@param node UserComponentNode The user component node whose template needs to be expanded.
---@param context Context Current variable scope passed into the component template.
---@return Node[] The resolved children produced by evaluating the component's template.
function Evaluator:evaluateUserComponentNode(node, context)
  local templateContent = node.templateContent
  if not templateContent or templateContent == "" then
    return {}
  end

  -- Parse the user component template
  local innerLexer = Lexer.new(templateContent, self.userComponents)
  local innerAst = innerLexer:parse()

  -- Evaluate the parsed template with the parent context
  local innerResult = self:evaluate(innerAst, context)

  return innerResult.children
end

-- Evaluate an IfDirectiveNode: pick the matching branch
---@param node IfDirectiveNode The if directive with condition and branch data.
---@param context Context Current variable scope.
---@return Node[] The resolved children of whichever branch matched, or an empty list when none matched.
function Evaluator:evaluateIfNode(node, context)
  -- Check the main condition
  if self.expressionEvaluator:evaluateCondition(node.conditionExpression, context) then
    local results = {}
    for _, child in ipairs(node.children) do
      local resolved = self:evaluateNode(child, context)
      for _, r in ipairs(resolved) do
        table.insert(results, r)
      end
    end
    return results
  end

  -- Check else-if branches
  for _, branch in ipairs(node.elseIfBranches) do
    if self.expressionEvaluator:evaluateCondition(branch.conditionExpression, context) then
      local results = {}
      for _, child in ipairs(branch.children) do
        local resolved = self:evaluateNode(child, context)
        for _, r in ipairs(resolved) do
          table.insert(results, r)
        end
      end
      return results
    end
  end

  -- Check else branch
  if node.elseBranch then
    local results = {}
    for _, child in ipairs(node.elseBranch) do
      local resolved = self:evaluateNode(child, context)
      for _, r in ipairs(resolved) do
        table.insert(results, r)
      end
    end
    return results
  end

  -- No branch matched
  return {}
end

-- Evaluate a ForDirectiveNode: iterate array and duplicate children per iteration
---@param node ForDirectiveNode The for directive with iterator variable and iterable expression.
---@param context Context Current variable scope; a child scope is created for each iteration, binding the iterator variable and `$index`.
---@return Node[] The concatenated resolved children across all loop iterations.
function Evaluator:evaluateForNode(node, context)
  local iterable = self.expressionEvaluator:evaluate(node.iterableExpression, context)

  if type(iterable) ~= "table" then
    return {}
  end

  local results = {}

  for index, item in ipairs(iterable) do
    -- Create a child context with the iterator variable bound to the current item
    local childContext = context:createChild({
      [node.iteratorVariable] = item,
      ["$index"] = index,
    })

    -- Evaluate all children in the for-body with this iteration's context
    for _, child in ipairs(node.children) do
      local resolved = self:evaluateNode(child, childContext)
      for _, r in ipairs(resolved) do
        table.insert(results, r)
      end
    end
  end

  return results
end

return Evaluator
