local Context = {}
Context.__index = Context

function Context.new(variables, parent)
  local self = setmetatable({}, Context)
  self.variables = variables or {}
  self.parent = parent or nil
  return self
end

-- Get a variable value, walking up the parent chain if not found locally
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
function Context:set(name, value)
  self.variables[name] = value
end

-- Create a child context that inherits from this one
function Context:createChild(variables)
  return Context.new(variables or {}, self)
end

return Context
