---@class Effect Runs a side-effect function and automatically re-runs it whenever a Signal read during its last execution changes.
---@field ActiveEffect Effect|nil The currently executing Effect instance used for automatic dependency tracking (module-level).
---@field _runFn fun() The effect body to execute.
---@field _dependencies table<Signal, fun()> Map of each tracked Signal to its corresponding unsubscribe function.
---@field _isRunning boolean True while the effect body is actively executing.
---@field _pendingRun boolean True when a dependency changed mid-execution; causes an immediate re-run after completion.
---@field _isDisposed boolean True after Dispose() has been called; prevents further execution.
local Effect = {}
Effect.ActiveEffect = nil
Effect.__index = Effect

---@param runFn fun() The effect body. Executed immediately on creation and re-executed whenever a tracked Signal changes.
---@return Effect
function Effect.New(runFn)
	if (type(runFn) ~= "function") then
		error("Effect expects a function.")
	end

	local self = setmetatable({}, Effect)
	self._runFn = runFn
	self._dependencies = {}
	self._isRunning = false
	self._pendingRun = false
	self._isDisposed = false
	self:Run()
	return self
end

---@param signal Signal The signal to register as a dependency; the effect will re-run when this signal's value changes.
function Effect:_track(signal)
	if (self._dependencies[signal] ~= nil) then
		return
	end

	local unsubscribe = signal:Subscribe(function()
		self:_scheduleRun()
	end)

	self._dependencies[signal] = unsubscribe
end

--- Unsubscribes from all currently tracked signals and clears the dependency map.
function Effect:_clearDependencies()
	for signal, unsubscribe in pairs(self._dependencies) do
		unsubscribe()
		self._dependencies[signal] = nil
	end
end

--- Schedules a re-run immediately if the effect is idle, or marks a pending re-run if it is currently executing.
function Effect:_scheduleRun()
	if (self._isDisposed) then
		return
	end

	if (self._isRunning) then
		self._pendingRun = true
		return
	end

	self:Run()
end

-- Runs the effect and re-collects dependencies by tracking signal reads.
function Effect:Run()
	if (self._isDisposed) then
		return
	end

	repeat
		self._pendingRun = false
		self._isRunning = true
		self:_clearDependencies()

		local previousEffect = Effect.ActiveEffect
		Effect.ActiveEffect = self
		local ok = pcall(self._runFn)
		Effect.ActiveEffect = previousEffect
		self._isRunning = false

		if (not ok) then
			error("Error occurred while running effect.")
		end
	until (not self._pendingRun)
end

--- Permanently stops the effect and unsubscribes from all dependencies. Safe to call multiple times.
function Effect:Dispose()
	if (self._isDisposed) then
		return
	end

	self._isDisposed = true
	self:_clearDependencies()
end

return Effect