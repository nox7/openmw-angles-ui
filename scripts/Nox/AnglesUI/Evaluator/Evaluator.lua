local Node = require("scripts.Nox.AnglesUI.Lexer.Nodes.Node")
local TextNode = require("scripts.Nox.AnglesUI.Lexer.Nodes.TextNode")
local ComponentNode = require("scripts.Nox.AnglesUI.Lexer.Nodes.ComponentNode")
local EngineComponentNode = require("scripts.Nox.AnglesUI.Lexer.Nodes.EngineComponentNode")
local ExpressionEvaluator = require("scripts.Nox.AnglesUI.Evaluator.ExpressionEvaluator")
local Lexer = require("scripts.Nox.AnglesUI.Lexer.Lexer")
local CSSParser = require("scripts.Nox.AnglesUI.CSSParser.CSSParser")

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
  -- Each entry is { children = <raw AST children>, context = <parent Context> }.
  -- Pushed when entering a user component, popped on exit.  Allows nested
  -- user components to each have their own independent projected-content scope.
  self._projectedContentStack = {}
  -- Each entry is a table of resolved event attributes ({ ["event:X"] = fn, ... })
  -- pushed when entering a user component that has event bindings on its call-site tag.
  -- <mw-host> pulls from the top of this stack to receive those bindings.
  self._hostEventsStack = {}
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
  elseif node.type == Node.TYPE_CONTENT_PROJECTION then
    return self:evaluateContentProjectionNode(node)
  elseif node.type == Node.TYPE_HOST_ELEMENT then
    return self:evaluateHostElementNode(node, context)
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

-- Split a raw argument list string (content between the outermost parentheses) into
-- individual argument strings, respecting nested parens and quotes.
---@param argStr string The raw argument list string.
---@return string[] Trimmed individual argument strings.
local function splitArgs(argStr)
  local args = {}
  local depth = 0
  local inSingle = false
  local inDouble = false
  local start = 1
  local i = 1
  local len = #argStr
  while i <= len do
    local ch = string.sub(argStr, i, i)
    if ch == "'" and not inDouble then
      inSingle = not inSingle
    elseif ch == '"' and not inSingle then
      inDouble = not inDouble
    elseif not inSingle and not inDouble then
      if ch == "(" then depth = depth + 1
      elseif ch == ")" then depth = depth - 1
      elseif ch == "," and depth == 0 then
        local token = string.match(string.sub(argStr, start, i - 1), "^%s*(.-)%s*$")
        table.insert(args, token)
        start = i + 1
      end
    end
    i = i + 1
  end
  local last = string.match(string.sub(argStr, start), "^%s*(.-)%s*$")
  if last ~= "" then table.insert(args, last) end
  return args
end

-- Resolve an event binding value to a { func, args } descriptor, with strict validation.
-- args is an ordered list of arg descriptors:
--   { type = "event1" }  →  replaced with OpenMW's first  callback arg (event object)
--   { type = "event2" }  →  replaced with OpenMW's second callback arg (layout object)
--   { type = "value", value = <any> } →  a pre-evaluated literal or context value
-- Errors when the value is not callable syntax or the function is not in context.
---@param attrValue string The raw attribute value string, e.g. "HandleClick" or "HandleClick('a', $event1)".
---@param eventName string The event name (used in error messages).
---@param tagName string The element tag name (used in error messages).
---@param context Context Current variable scope.
---@return {func: function, args: table[]} Descriptor for building the callback closure.
function Evaluator:ResolveEventBinding(attrValue, eventName, tagName, context)
  local funcExpr = attrValue and string.match(attrValue, "^([%w_%.]+)") or nil
  if funcExpr == nil then
    error(
      "Invalid event binding (" .. eventName .. ")=\"" .. tostring(attrValue) .. "\" on <" .. tagName .. ">. " ..
      "Event bindings must reference a callable: use MyFunction or MyFunction() syntax."
    )
  end

  local afterIdent = string.sub(attrValue, #funcExpr + 1)
  if afterIdent ~= "" and string.sub(afterIdent, 1, 1) ~= "(" then
    error(
      "Invalid event binding (" .. eventName .. ")=\"" .. tostring(attrValue) .. "\" on <" .. tagName .. ">. " ..
      "Event bindings must use callable syntax. Did you mean " .. funcExpr .. "()?"
    )
  end

  local resolvedFunc = self.expressionEvaluator:evaluate(funcExpr, context)
  if resolvedFunc == nil then
    error(
      "Event binding (" .. eventName .. ")=\"" .. tostring(attrValue) .. "\" on <" .. tagName .. ">: " ..
      "'" .. funcExpr .. "' was not found in the current render context."
    )
  end

  -- Parse the argument list, if present.
  local args = {}
  local parenContent = string.match(afterIdent, "^%((.*)%)$")
  if parenContent ~= nil then
    local rawArgs = splitArgs(parenContent)
    for _, rawArg in ipairs(rawArgs) do
      if rawArg == "$event1" then
        table.insert(args, { type = "event1" })
      elseif rawArg == "$event2" then
        table.insert(args, { type = "event2" })
      else
        -- Evaluate the argument expression against the current context now, at
        -- binding time.  Literals resolve to their value; context references are
        -- snapshotted.  Unknown identifiers yield nil (valid: callers may pass nil).
        local val = self.expressionEvaluator:evaluate(rawArg, context)
        table.insert(args, { type = "value", value = val })
      end
    end
  end
  -- No parentheses at all = bare "FuncName" shorthand → called with no args.

  return { func = resolvedFunc, args = args }
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
        local resolvedFunc = self:ResolveEventBinding(attrValue, eventName, node.tagName, context)
        resolvedAttributes["event:" .. eventName] = resolvedFunc
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

  -- Push the raw (unevaluated) children from the call-site together with the
  -- parent context.  <mw-content> slots inside this component will pull from
  -- this entry, filter by tag name, then evaluate in the parent context.
  table.insert(self._projectedContentStack, { children = node.children, context = context })

  -- Resolve event bindings from the call-site tag (e.g. (mousePress)="HandleClick")
  -- and push them onto the host-events stack so that <mw-host> can pick them up.
  local hostEvents = {}
  local hasAnyEventBindings = false
  for attrName, attrValue in pairs(node.attributes or {}) do
    local eventName = string.match(attrName, "^%((.+)%)$")
    if eventName then
      hasAnyEventBindings = true
      local resolvedFunc = self:ResolveEventBinding(attrValue, eventName, node.tagName, context)
      hostEvents["event:" .. eventName] = resolvedFunc
    end
  end
  hostEvents._hasEvents = hasAnyEventBindings
  table.insert(self._hostEventsStack, hostEvents)

  -- Parse the user component template
  local innerLexer = Lexer.new(templateContent, self.userComponents)
  local innerAst = innerLexer:parse()

  -- Evaluate the parsed template with the parent context
  local innerResult = self:evaluate(innerAst, context)

  table.remove(self._projectedContentStack)
  local poppedEntry = table.remove(self._hostEventsStack)

  -- Guard: if the call-site bound any events but the component template never
  -- consumed them via <mw-host>, the author made an error.
  -- Note: ResolveEventBinding already throws for invalid/unfound functions, so
  -- _hasEvents only reaches here when resolution succeeded.
  if poppedEntry ~= nil and not poppedEntry._consumed and poppedEntry._hasEvents then
        error(
          "Component <" .. node.tagName .. "> has event binding(s) on its call-site tag " ..
          "but its template contains no <mw-host> element to receive them. " ..
          "Add <mw-host>...</mw-host> to the component template as the event target."
        )
  end

  return innerResult.children
end

-- Evaluate a HostElementNode: produce a full-size mw-widget that carries event
-- bindings from the parent component's call-site tag, wrapping the mw-host children.
-- When placed outside a user component (nothing on the host-events stack) the wrapper
-- is still emitted so the template is structurally valid; it simply has no events.
---@param node HostElementNode The host element node.
---@param context Context Current variable scope.
---@return EngineComponentNode[] A single mw-widget EngineComponentNode carrying the host events.
function Evaluator:evaluateHostElementNode(node, context)
  local stackDepth = #self._hostEventsStack
  local hostEvents = (stackDepth > 0) and self._hostEventsStack[stackDepth] or {}

  -- Mark the stack entry as consumed so the post-evaluation guard in
  -- evaluateUserComponentNode knows mw-host was present in this template.
  if stackDepth > 0 then
    self._hostEventsStack[stackDepth]._consumed = true
  end

  -- Build the attribute map: only event bindings forwarded from the call-site tag.
  -- Sizing is intentionally left to CSS (e.g. "mw-host { flex-grow: 1; }") so that
  -- the tag name is preserved in the emitted node and CSS selectors match correctly.
  local attrs = {}
  for k, v in pairs(hostEvents) do
    if k ~= "_consumed" and k ~= "_hasEvents" then
      attrs[k] = v
    end
  end

  local hostNode = EngineComponentNode.new("mw-host", attrs, false)
  self:evaluateChildren(node.children, context, hostNode)
  return { hostNode }
end

-- Evaluate a ContentProjectionNode: replace this slot with projected parent children.
-- The optional `select` attribute is a CSS selector string (e.g. "mw-grid",
-- ".my-class", "#some-id", "mw-flex > mw-text").  Only call-site children whose
-- raw AST node satisfies the selector are projected.  When `select` is absent,
-- all projected children (including text nodes) are used.
-- Returns an empty list when called outside a user component context.
---@param node ContentProjectionNode The projection slot node.
---@return Node[] Evaluated projected nodes matching the slot filter.
function Evaluator:evaluateContentProjectionNode(node)
  local stackDepth = #self._projectedContentStack
  if stackDepth == 0 then
    return {}
  end

  local entry = self._projectedContentStack[stackDepth]
  local rawChildren = entry.children
  local parentContext = entry.context
  local selectFilter = node.select  -- nil = accept everything

  -- Parse the selector once; nil/empty means "accept all".
  local parsedSelector = nil
  if selectFilter ~= nil and selectFilter ~= "" then
    parsedSelector = CSSParser.ParseSelectorParts(selectFilter)
  end

  local results = {}
  for _, child in ipairs(rawChildren) do
    local matches
    if parsedSelector == nil then
      -- No filter — accept everything, including raw text nodes.
      matches = true
    elseif child.tagName == nil then
      -- Text / directive nodes have no tag name and cannot match an element selector.
      matches = false
    else
      -- Evaluate the CSS selector against the child node.
      -- We pass an empty ancestor list because the selector is matched against the
      -- projected node in isolation (its position relative to the call-site siblings
      -- is intentionally not considered — only per-node attributes matter here).
      matches = CSSParser.SelectorMatchesNode(parsedSelector, child, {})
    end

    if matches then
      local resolved = self:evaluateNode(child, parentContext)
      for _, r in ipairs(resolved) do
        table.insert(results, r)
      end
    end
  end
  return results
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
