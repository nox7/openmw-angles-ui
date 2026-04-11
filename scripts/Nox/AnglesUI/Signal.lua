--- AnglesUI Signal — Reactive primitive for the AnglesUI framework.
--- Signals hold a value that can be read by calling the signal as a function,
--- written via :Set(), and observed via :Subscribe(). Subscriptions are the
--- mechanism that drives re-evaluation and re-render of signal-dependent areas.

---@class AnglesUI.Signal
---@field private _value any The current value held by the signal
---@field private _subscribers table<integer, fun(newValue: any, oldValue: any)> Registered change callbacks
---@field private _nextId integer Auto-incrementing subscriber id counter
local Signal = {}
Signal.__index = Signal

---------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------

--- Create a new reactive signal with an initial value.
---@param initialValue any The starting value of the signal
---@return AnglesUI.Signal signal A callable signal instance
---@nodiscard
function Signal.New(initialValue)
    local self = setmetatable({}, Signal)
    self._value = initialValue
    self._subscribers = {}
    self._nextId = 1
    return self
end

---------------------------------------------------------------------------
-- Reading (calling the signal as a function)
---------------------------------------------------------------------------

--- Calling a signal as a function returns its current value.
---@return any value The current value of the signal
function Signal:__call()
    return self._value
end

---------------------------------------------------------------------------
-- Writing
---------------------------------------------------------------------------

--- Set the signal to a new value. If the value has changed, all subscribers
--- are notified synchronously in subscription order.
---@param newValue any The new value to store
function Signal:Set(newValue)
    local oldValue = self._value
    if oldValue == newValue then
        return
    end
    self._value = newValue
    self:_notify(newValue, oldValue)
end

---------------------------------------------------------------------------
-- Subscribing
---------------------------------------------------------------------------

--- Register a callback that fires whenever the signal's value changes.
--- The callback receives `(newValue, oldValue)`.
---@param callback fun(newValue: any, oldValue: any) The listener function
---@return fun() unsubscribe Call this function to remove the subscription
---@nodiscard
function Signal:Subscribe(callback)
    local id = self._nextId
    self._nextId = id + 1
    self._subscribers[id] = callback

    -- Return an unsubscribe handle
    return function()
        self._subscribers[id] = nil
    end
end

---------------------------------------------------------------------------
-- Peek — read without triggering any future tracking (useful for one-off reads)
---------------------------------------------------------------------------

--- Read the current value without any side-effects. Identical to calling the
--- signal today, but semantically explicit for code that should *not*
--- register a dependency once automatic dependency tracking is added.
---@return any value The current value of the signal
function Signal:Peek()
    return self._value
end

---------------------------------------------------------------------------
-- Batch updates
---------------------------------------------------------------------------

--- @type boolean
local _batchActive = false

--- @type fun()[]
local _batchQueue = {}

--- Execute `fn` and defer all subscriber notifications until it returns.
--- Nested batches are collapsed — only the outermost batch flushes.
---@param fn fun() The function that performs one or more Set() calls
function Signal.Batch(fn)
    if _batchActive then
        -- Already inside a batch; just run
        fn()
        return
    end

    _batchActive = true
    _batchQueue = {}

    local ok, err = pcall(fn)

    _batchActive = false

    -- Flush queued notifications
    for i = 1, #_batchQueue do
        _batchQueue[i]()
    end
    _batchQueue = {}

    if not ok then
        error(err, 2)
    end
end

---------------------------------------------------------------------------
-- Internal
---------------------------------------------------------------------------

--- Notify all current subscribers of a value change.
--- During a Batch, notifications are deferred.
---@private
---@param newValue any
---@param oldValue any
function Signal:_notify(newValue, oldValue)
    if _batchActive then
        -- Capture the signal and the snapshot of values for deferred delivery
        local sig = self
        local nv, ov = newValue, oldValue
        _batchQueue[#_batchQueue + 1] = function()
            sig:_flush(nv, ov)
        end
        return
    end
    self:_flush(newValue, oldValue)
end

--- Immediately deliver change to all subscribers with a stable snapshot of
--- the subscriber table (so that unsubscribing inside a callback is safe).
---@private
---@param newValue any
---@param oldValue any
function Signal:_flush(newValue, oldValue)
    -- Snapshot ids so removals during iteration are safe
    local ids = {}
    for id in pairs(self._subscribers) do
        ids[#ids + 1] = id
    end
    table.sort(ids) -- deliver in subscription order

    for i = 1, #ids do
        local cb = self._subscribers[ids[i]]
        if cb then
            cb(newValue, oldValue)
        end
    end
end

---------------------------------------------------------------------------
-- Computed (derived) signals
---------------------------------------------------------------------------

--- Create a read-only signal whose value is automatically derived from other
--- signals. `computeFn` is called immediately and whenever any dependency
--- signals change. Dependencies must be passed explicitly.
---@param computeFn fun(): any A function that computes the derived value
---@param dependencies AnglesUI.Signal[] Array of signals this computed depends on
---@return AnglesUI.Signal computed A read-only signal (calling :Set() will error)
---@nodiscard
function Signal.Computed(computeFn, dependencies)
    local computed = Signal.New(computeFn())

    -- Override Set to be read-only
    function computed:Set()
        error("Cannot call :Set() on a computed signal", 2)
    end

    -- Subscribe to each dependency
    for i = 1, #dependencies do
        dependencies[i]:Subscribe(function()
            local newVal = computeFn()
            -- Use the raw internal path to bypass the read-only guard
            local old = computed._value
            if old ~= newVal then
                computed._value = newVal
                computed:_notify(newVal, old)
            end
        end)
    end

    return computed
end

---------------------------------------------------------------------------
-- Effect — run a side-effect whenever any of the given signals change
---------------------------------------------------------------------------

--- Register a side-effect that runs immediately and re-runs whenever any of
--- the `dependencies` change. Returns an unsubscribe-all handle.
---@param effectFn fun() The side-effect to execute
---@param dependencies AnglesUI.Signal[] Signals to watch
---@return fun() dispose Call to stop the effect
function Signal.Effect(effectFn, dependencies)
    -- Run immediately
    effectFn()

    local unsubs = {}
    for i = 1, #dependencies do
        unsubs[i] = dependencies[i]:Subscribe(function()
            effectFn()
        end)
    end

    return function()
        for i = 1, #unsubs do
            unsubs[i]()
        end
    end
end

return Signal
