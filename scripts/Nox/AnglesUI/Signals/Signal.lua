local Effect = require("scripts.Nox.AnglesUI.Signals.Effect");

-- Signals are a clone of Angular-style signals for reactions in the UI.
local Signal = {}
Signal.__index = Signal

-- Returns true when value is a Signal instance (checks metatable identity).
function Signal.IsSignal(value)
	return type(value) == "table" and getmetatable(value) == Signal
end

-- Creates a new signal with an initial value.
function Signal.New(initialValue)
	local self = setmetatable({}, Signal)
	self._value = initialValue
	self._listeners = {}
	self._nextListenerId = 0
	return self
end

-- Calling a signal instance returns its current value (Angular-style read).
function Signal:__call()
	return self:Get()
end

-- Gets the current value and tracks reads when called inside an Effect.
function Signal:Get()
	if (Effect.ActiveEffect ~= nil) then
		Effect.ActiveEffect:_track(self)
	end

	return self._value
end

-- Gets the current value without tracking dependencies.
function Signal:Peek()
	return self._value
end

-- Sets the value and notifies listeners when the value changed.
-- Returns true when updated, false when no change happened.
function Signal:Set(newValue)
	local oldValue = self._value
	if (oldValue == newValue) then
		return false
	end

	self._value = newValue
	self:_notify(newValue, oldValue)
	return true
end

-- Convenience update helper: signal:Update(function(current) return next end)
function Signal:Update(updater)
	if (type(updater) ~= "function") then
		error("Signal:Update expects a function.")
	end

	return self:Set(updater(self._value))
end

-- Subscribes to changes.
-- Listener signature: function(newValue, oldValue, signal)
-- Returns an unsubscribe function.
function Signal:Subscribe(listener, fireImmediately)
	if (type(listener) ~= "function") then
		error("Signal:Subscribe expects a function listener.")
	end

	self._nextListenerId = self._nextListenerId + 1
	local listenerId = self._nextListenerId
	self._listeners[listenerId] = listener

	if (fireImmediately == true) then
		listener(self._value, self._value, self)
	end

	return function()
		self:Unsubscribe(listenerId)
	end
end

function Signal:Unsubscribe(listenerId)
	self._listeners[listenerId] = nil
end

function Signal:_notify(newValue, oldValue)
	-- Snapshot listeners so unsubscribe/subscribe during notification is safe.
	local snapshot = {}
	for listenerId, listener in pairs(self._listeners) do
		snapshot[listenerId] = listener
	end

	for listenerId, listener in pairs(snapshot) do
		if (self._listeners[listenerId] == listener) then
			listener(newValue, oldValue, self)
		end
	end
end

-- Creates an auto-tracked effect and returns an unsubscribe/dispose function.
-- Any signal read inside runFn (e.g. count()) becomes a dependency.
function Signal.Effect(runFn)
	local effect = Effect.New(runFn)
	return function()
		effect:Dispose()
	end
end

return Signal
