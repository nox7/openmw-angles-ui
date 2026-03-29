local Effect = {}
Effect.ActiveEffect = nil
Effect.__index = Effect

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

function Effect:_track(signal)
	if (self._dependencies[signal] ~= nil) then
		return
	end

	local unsubscribe = signal:Subscribe(function()
		self:_scheduleRun()
	end)

	self._dependencies[signal] = unsubscribe
end

function Effect:_clearDependencies()
	for signal, unsubscribe in pairs(self._dependencies) do
		unsubscribe()
		self._dependencies[signal] = nil
	end
end

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

function Effect:Dispose()
	if (self._isDisposed) then
		return
	end

	self._isDisposed = true
	self:_clearDependencies()
end

return Effect