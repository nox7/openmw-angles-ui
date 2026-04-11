--- AnglesUI Test Suite — Signal
--- Tests for the reactive Signal primitive: creation, read, write,
--- subscribe, peek, batch, computed, and effect.

package.path = "scripts/Nox/AnglesUI/?.lua;scripts/Nox/AnglesUI/Tests/?.lua;" .. package.path

local lu = require("luaunit")
local Signal = require("Signal")

---------------------------------------------------------------------------
-- TestSignalNew — Construction
---------------------------------------------------------------------------
TestSignalNew = {}

function TestSignalNew:testNewReturnsTable()
    local s = Signal.New(10)
    lu.assertIsTable(s)
end

function TestSignalNew:testNewStoresInitialValue()
    local s = Signal.New(42)
    lu.assertEquals(s(), 42)
end

function TestSignalNew:testNewNilInitialValue()
    local s = Signal.New(nil)
    lu.assertIsNil(s())
end

function TestSignalNew:testNewStringValue()
    local s = Signal.New("hello")
    lu.assertEquals(s(), "hello")
end

function TestSignalNew:testNewBooleanValue()
    local s = Signal.New(true)
    lu.assertEquals(s(), true)
end

function TestSignalNew:testNewTableValue()
    local t = { a = 1 }
    local s = Signal.New(t)
    lu.assertIs(s(), t)
end

---------------------------------------------------------------------------
-- TestSignalReadWrite — __call read and :Set() write
---------------------------------------------------------------------------
TestSignalReadWrite = {}

function TestSignalReadWrite:testCallReadsValue()
    local s = Signal.New(5)
    lu.assertEquals(s(), 5)
end

function TestSignalReadWrite:testSetChangesValue()
    local s = Signal.New(1)
    s:Set(2)
    lu.assertEquals(s(), 2)
end

function TestSignalReadWrite:testSetToNil()
    local s = Signal.New(10)
    s:Set(nil)
    lu.assertIsNil(s())
end

function TestSignalReadWrite:testSetSameValueNoOp()
    local callCount = 0
    local s = Signal.New(5)
    s:Subscribe(function() callCount = callCount + 1 end)
    s:Set(5)
    lu.assertEquals(callCount, 0)
end

function TestSignalReadWrite:testMultipleSets()
    local s = Signal.New(0)
    s:Set(1)
    s:Set(2)
    s:Set(3)
    lu.assertEquals(s(), 3)
end

---------------------------------------------------------------------------
-- TestSignalSubscribe — Subscribe / unsubscribe
---------------------------------------------------------------------------
TestSignalSubscribe = {}

function TestSignalSubscribe:testSubscribeFiresOnChange()
    local s = Signal.New(0)
    local received = nil
    s:Subscribe(function(newVal) received = newVal end)
    s:Set(42)
    lu.assertEquals(received, 42)
end

function TestSignalSubscribe:testSubscribeReceivesOldValue()
    local s = Signal.New(10)
    local oldReceived = nil
    s:Subscribe(function(newVal, oldVal) oldReceived = oldVal end)
    s:Set(20)
    lu.assertEquals(oldReceived, 10)
end

function TestSignalSubscribe:testMultipleSubscribers()
    local s = Signal.New(0)
    local a, b = 0, 0
    s:Subscribe(function(v) a = v end)
    s:Subscribe(function(v) b = v end)
    s:Set(7)
    lu.assertEquals(a, 7)
    lu.assertEquals(b, 7)
end

function TestSignalSubscribe:testSubscribersFireInOrder()
    local s = Signal.New(0)
    local order = {}
    s:Subscribe(function() order[#order + 1] = "first" end)
    s:Subscribe(function() order[#order + 1] = "second" end)
    s:Subscribe(function() order[#order + 1] = "third" end)
    s:Set(1)
    lu.assertEquals(order, { "first", "second", "third" })
end

function TestSignalSubscribe:testUnsubscribeStopsNotifications()
    local s = Signal.New(0)
    local count = 0
    local unsub = s:Subscribe(function() count = count + 1 end)
    s:Set(1)
    lu.assertEquals(count, 1)

    unsub()
    s:Set(2)
    lu.assertEquals(count, 1) -- not incremented
end

function TestSignalSubscribe:testUnsubscribeInsideCallback()
    local s = Signal.New(0)
    local count = 0
    local unsub
    unsub = s:Subscribe(function()
        count = count + 1
        unsub()
    end)
    s:Set(1)
    lu.assertEquals(count, 1)

    s:Set(2)
    lu.assertEquals(count, 1) -- callback removed itself
end

function TestSignalSubscribe:testSubscribeReturnsFunction()
    local s = Signal.New(0)
    local unsub = s:Subscribe(function() end)
    lu.assertIsFunction(unsub)
end

---------------------------------------------------------------------------
-- TestSignalPeek
---------------------------------------------------------------------------
TestSignalPeek = {}

function TestSignalPeek:testPeekReturnsCurrentValue()
    local s = Signal.New(99)
    lu.assertEquals(s:Peek(), 99)
end

function TestSignalPeek:testPeekReflectsSetChanges()
    local s = Signal.New(1)
    s:Set(2)
    lu.assertEquals(s:Peek(), 2)
end

function TestSignalPeek:testPeekMatchesCall()
    local s = Signal.New("abc")
    lu.assertEquals(s:Peek(), s())
end

---------------------------------------------------------------------------
-- TestSignalBatch
---------------------------------------------------------------------------
TestSignalBatch = {}

function TestSignalBatch:testBatchDefersNotifications()
    local s = Signal.New(0)
    local notifications = {}
    s:Subscribe(function(v) notifications[#notifications + 1] = v end)

    Signal.Batch(function()
        s:Set(1)
        s:Set(2)
        s:Set(3)
        -- During batch, subscribers should NOT have been called yet
        lu.assertEquals(#notifications, 0)
    end)

    -- After batch, all deferred notifications fire
    lu.assertTrue(#notifications > 0)
end

function TestSignalBatch:testBatchValueAvailableImmediately()
    local s = Signal.New(0)
    Signal.Batch(function()
        s:Set(10)
        lu.assertEquals(s(), 10) -- value is updated immediately
    end)
end

function TestSignalBatch:testNestedBatchesCollapse()
    local s = Signal.New(0)
    local count = 0
    s:Subscribe(function() count = count + 1 end)

    Signal.Batch(function()
        Signal.Batch(function()
            s:Set(1)
        end)
        -- Inner batch should not have flushed
        lu.assertEquals(count, 0)
    end)

    -- Only outermost batch flushes
    lu.assertTrue(count > 0)
end

function TestSignalBatch:testBatchPropagatesError()
    lu.assertErrorMsgContains("test error", function()
        Signal.Batch(function()
            error("test error")
        end)
    end)
end

function TestSignalBatch:testBatchFlushesEvenOnError()
    local s = Signal.New(0)
    local notified = false
    s:Subscribe(function() notified = true end)

    pcall(function()
        Signal.Batch(function()
            s:Set(1)
            error("boom")
        end)
    end)

    -- Notifications should still have been flushed after the error
    lu.assertTrue(notified)
end

---------------------------------------------------------------------------
-- TestSignalComputed
---------------------------------------------------------------------------
TestSignalComputed = {}

function TestSignalComputed:testComputedInitialValue()
    local a = Signal.New(3)
    local b = Signal.New(4)
    local sum = Signal.Computed(function() return a() + b() end, { a, b })
    lu.assertEquals(sum(), 7)
end

function TestSignalComputed:testComputedUpdatesOnDependencyChange()
    local a = Signal.New(2)
    local b = Signal.New(5)
    local product = Signal.Computed(function() return a() * b() end, { a, b })
    lu.assertEquals(product(), 10)

    a:Set(3)
    lu.assertEquals(product(), 15)

    b:Set(10)
    lu.assertEquals(product(), 30)
end

function TestSignalComputed:testComputedSetErrors()
    local a = Signal.New(1)
    local c = Signal.Computed(function() return a() end, { a })
    lu.assertErrorMsgContains("computed signal", c.Set, c, 99)
end

function TestSignalComputed:testComputedSubscribable()
    local a = Signal.New(1)
    local c = Signal.Computed(function() return a() * 2 end, { a })

    local received = nil
    c:Subscribe(function(v) received = v end)
    a:Set(5)
    lu.assertEquals(received, 10)
end

function TestSignalComputed:testComputedSameValueNoNotify()
    local a = Signal.New(5)
    local c = Signal.Computed(function() return a() > 0 end, { a })
    lu.assertEquals(c(), true)

    local count = 0
    c:Subscribe(function() count = count + 1 end)

    a:Set(10) -- still > 0, computed value unchanged (true)
    lu.assertEquals(count, 0)
end

---------------------------------------------------------------------------
-- TestSignalEffect
---------------------------------------------------------------------------
TestSignalEffect = {}

function TestSignalEffect:testEffectRunsImmediately()
    local ran = false
    local a = Signal.New(1)
    Signal.Effect(function() ran = true end, { a })
    lu.assertTrue(ran)
end

function TestSignalEffect:testEffectRerunsOnChange()
    local a = Signal.New(0)
    local count = 0
    Signal.Effect(function() count = count + 1 end, { a })
    lu.assertEquals(count, 1) -- initial run

    a:Set(1)
    lu.assertEquals(count, 2)

    a:Set(2)
    lu.assertEquals(count, 3)
end

function TestSignalEffect:testEffectMultipleDependencies()
    local a = Signal.New(0)
    local b = Signal.New(0)
    local count = 0
    Signal.Effect(function() count = count + 1 end, { a, b })
    lu.assertEquals(count, 1)

    a:Set(1)
    lu.assertEquals(count, 2)

    b:Set(1)
    lu.assertEquals(count, 3)
end

function TestSignalEffect:testEffectDisposeStopsRerunning()
    local a = Signal.New(0)
    local count = 0
    local dispose = Signal.Effect(function() count = count + 1 end, { a })
    lu.assertEquals(count, 1)

    dispose()
    a:Set(1)
    lu.assertEquals(count, 1) -- not incremented after dispose
end

function TestSignalEffect:testEffectReturnsFunction()
    local a = Signal.New(0)
    local dispose = Signal.Effect(function() end, { a })
    lu.assertIsFunction(dispose)
end

os.exit(lu.run())
