local timer = {}
timer.__index = timer

export type Timer = typeof(setmetatable({} :: {
    _duration: number,
    _startTime: number,
    _isPaused: boolean,
    _pauseStartTime: number?,
    _accumulatedPauseTime: number,
    _hasFinished: boolean,
    _taskThread: thread?,
    _Binds: { [string]: (...any) -> ...any },
}, timer))

--[=[
    @class timer
    @param duration The duration of the timer in seconds
    @param autoStart Optional boolean to automatically start the timer (defaults to true)
]=]
function timer.new(duration: number, autoStart: boolean?): Timer
    local this = setmetatable({
        _duration = duration,
        _startTime = os.clock(),
        _isPaused = false,
        _pauseStartTime = nil,
        _accumulatedPauseTime = 0,
        _hasFinished = false,
        _taskThread = nil,
        _Binds = {} :: { [string]: (...any) -> ...any },
    }, timer)

    if autoStart ~= false then
        this:Start()
    end

    return this
end




--[=[
@class timer
@param tag, an identifer for the timer
@param fn, the function that is binded to the timer
]=]
function timer.Bind(this: Timer, Tag: string, fn: (...any) -> ...any): Timer
    assert(Tag, "Cannot bind without Tag!")
    if typeof(fn) == "function" then
        this._Binds[Tag] = fn
    end
    return this
end


--[=[
    @class timer
    @param Tag, which function to unbind.
]=]
function timer.Unbind(this: Timer, Tag: string): Timer
    this._Binds[Tag] = nil
    return this
end


--[=[
    @class timer
    @param Tag, the tag which is linked to the function
    @returns the binded function by tag or function() end if not found
]=]
function timer.GetBindFunction(this: Timer, Tag: string): (...any) -> ...any
    return this._Binds[Tag] or function() end
end

function timer.FireBind(this: Timer, Tag: string, ...: any): any
    local fn = this._Binds[Tag]
    if fn then
        return fn(...)
    end
    return nil
end

function timer.FireAllBinds(this: Timer, ...: any)
    for _, fn in this._Binds do
        task.spawn(fn, ...)
    end
end

function timer.ClearBinds(this: Timer): Timer
    table.clear(this._Binds)
    return this
end

-- Convenience helper for binding specifically to the "OnFinish" event
function timer.OnFinish(this: Timer, fn: (...any) -> ...any): Timer
    return this:Bind("OnFinish", fn)
end

-- ====================
-- CONTROL & STATE METHODS
-- ====================

function timer.Start(this: Timer): Timer
    this:CancelThread()

    this._startTime = os.clock()
    this._accumulatedPauseTime = 0
    this._isPaused = false
    this._hasFinished = false

    -- Schedule task.delay to automatically fire completion callbacks
    this._taskThread = task.delay(this._duration, function()
        this._hasFinished = true
        this:FireBind("OnFinish", this._duration)
        this:FireBind("OnStep", 1.0)
    end)

    return this
end

--[=[
]=]
function timer.Remaining(this: Timer): number
    if this._hasFinished then
        return 0
    end

    local now = if this._isPaused and this._pauseStartTime 
        then this._pauseStartTime 
        else os.clock()

    local elapsed = (now - this._startTime) - this._accumulatedPauseTime
    return math.max(0, this._duration - elapsed)
end

function timer.IsFinished(this: Timer): boolean
    return this._hasFinished or this:Remaining() <= 0
end

function timer.Pause(this: Timer): Timer
    if this._isPaused or this._hasFinished then return this end

    this._isPaused = true
    this._pauseStartTime = os.clock()
    this:CancelThread()
    this:FireBind("OnPause")

    return this
end

function timer.Resume(this: Timer): Timer
    if not this._isPaused or not this._pauseStartTime then return this end

    local pauseDuration = os.clock() - this._pauseStartTime
    this._accumulatedPauseTime += pauseDuration
    this._isPaused = false
    this._pauseStartTime = nil

    local remaining = this:Remaining()
    if remaining > 0 then
        this._taskThread = task.delay(remaining, function()
            this._hasFinished = true
            this:FireBind("OnFinish", this._duration)
        end)
        this:FireBind("OnResume")
    else
        this._hasFinished = true
        this:FireBind("OnFinish", this._duration)
    end

    return this
end

function timer.Reset(this: Timer): Timer
    return this:Start()
end

function timer.CancelThread(this: Timer)
    if this._taskThread then
        task.cancel(this._taskThread)
        this._taskThread = nil
    end
end

function timer.Destroy(this: Timer)
    this:CancelThread()
    this:ClearBinds()
end

return timer