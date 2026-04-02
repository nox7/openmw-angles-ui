---@class Context Hierarchical variable scope used during template evaluation. Lookups walk up the parent chain.
---@field variables table<string, any> Variables defined at this scope level.
---@field parent Context|nil The enclosing parent context, or nil for the root scope.
local Context = {}
Context.__index = Context

---@param variables table<string, any>|nil Variables to populate in this scope.
---@param parent Context|nil Optional parent context to walk when a name is not found locally.
---@return Context
function Context.new(variables, parent)
  local self = setmetatable({}, Context)
  self.variables = variables or {}
  self.parent = parent or nil
  return self
end

-- Get a variable value, walking up the parent chain if not found locally
---@param name string Variable name to look up.
---@return any The value, or nil if not found in any scope.
function Context:get(name)
  if self.variables[name] ~= nil then
    return self.variables[name]
  end
  if self.parent then
    return self.parent:get(name)
  end
  return nil
end

-- Set a variable in the current scope
---@param name string Variable name.
---@param value any Value to assign.
function Context:set(name, value)
  self.variables[name] = value
end

-- Create a child context that inherits from this one
---@param variables table<string, any>|nil Variables to pre-populate in the child scope.
---@return Context A new Context whose parent is this context.
function Context:createChild(variables)
  return Context.new(variables or {}, self)
end

return Context
