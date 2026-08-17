--!strict
const _timer = require("@self/tmr")

const cooldown = {}
cooldown.__index = cooldown

export type CooldownService = typeof(setmetatable({} :: {
    _cooldown: number,
    _timer: _timer.Timer?,
    _Binds: { [string]: (...any) -> ...any },
}, cooldown))

function cooldown.new(Cooldown: number): CooldownService
    const this = setmetatable({}, cooldown)
    this._cooldown = Cooldown
    this._timer = nil
    this._Binds = {}
    return this
end

function cooldown.Ready(this: CooldownService): boolean
    if not this._timer then
        return true
    end
    return this._timer:IsFinished()
end

-- Alias for Ready
cooldown.CanUse = cooldown.Ready

-- Binds a callback function to a specific tag
function cooldown.Bind(this: CooldownService, Tag: string, fn: (...any) -> ...any): CooldownService
    assert(Tag, "Cannot bind without Tag!")
    if typeof(fn) == "function" then
        this._Binds[Tag] = fn
    end
    return this
end

-- Unbinds a callback by tag
function cooldown.Unbind(this: CooldownService, Tag: string): CooldownService
    this._Binds[Tag] = nil
    return this
end

-- Retrieves a bound function (Returns a no-op function to prevent nil errors)
function cooldown.GetBindFunction(this: CooldownService, Tag: string): (...any) -> ...any
    return this._Binds[Tag] or function() end
end

-- Manually fires a specific bound tag with custom arguments
function cooldown.FireBind(this: CooldownService, Tag: string, ...: any): any
    const fn = this._Binds[Tag]
    if fn then
        return fn(...)
    end
    return nil
end

-- Fires all registered binds
function cooldown.FireAllBinds(this: CooldownService, ...: any)
    for _, fn in this._Binds do
        task.spawn(fn, ...)
    end
    return this
end

-- Clears all active binds
function cooldown.ClearBinds(this: CooldownService): CooldownService
    table.clear(this._Binds)
    return this
end

-- Internal helper to lazily create and bind the internal timer
const function _getOrCreateTimer(this: CooldownService): _timer.Timer
    const currentTimer = this._timer
    if currentTimer then
        return currentTimer
    end

    -- Assign to a const variable so Luau knows it isn't nil
    const newTimer = _timer.new(this._cooldown, false)
    newTimer:OnFinish(function(...)
        this:FireBind("OnReady", ...)
    end)

    this._timer = newTimer
    return newTimer
end

-- FORCE use regardless of whether it's on cooldown or not
function cooldown.ForceUse(this: CooldownService, ...: any): CooldownService
    const tmr = _getOrCreateTimer(this)
    tmr:Start()
    this:FireBind("OnUse", ...)
    return this
end

function cooldown.SetCooldown(this: CooldownService, NewCooldown: number): CooldownService
    if not NewCooldown then return this end
    this._cooldown = NewCooldown
    if this._timer then
        this._timer._duration = NewCooldown
    end
    return this
end

function cooldown.Use(this: CooldownService, ...: any): boolean
    if not this:CanUse() then 
        this:FireBind("OnFail", ...)
        return false 
    end
    
    this:ForceUse(...)
    return true
end

function cooldown.Remaining(this: CooldownService): number
    if not this._timer then
        return 0
    end
    return this._timer:Remaining()
end

function cooldown.Destroy(this: CooldownService)
    if this._timer and typeof(this._timer.Destroy) == "function" then
        this._timer:Destroy()
    end
    this:ClearBinds()
end


--group
const GroupS = {}
GroupS.__index = GroupS

export type group = typeof(setmetatable({} :: {
    GroupTable: { [string]: CooldownService },
}, GroupS))

function GroupS.UseAll(this: group, ...: any)
    for _, cooldownService in this.GroupTable do
        cooldownService:ForceUse(...)
    end
end

function GroupS.CanUseAll(this: group): boolean
    for _, cooldownService in this.GroupTable do
        if not cooldownService:CanUse() then
            return false
        end
    end
    return true
end

function GroupS.Get(this: group, name: string): CooldownService?
    return this.GroupTable[name]
end

-- Binds a function to a specific member of the group
function GroupS.Bind(this: group, name: string, tag: string, fn: (...any) -> ...any): group
    const cd = this.GroupTable[name]
    if cd then
        cd:Bind(tag, fn)
    end
    return this
end

-- Binds a tag callback across ALL group items
function GroupS.BindAll(this: group, tag: string, fn: (...any) -> ...any): group
    for _, cd in this.GroupTable do
        cd:Bind(tag, fn)
    end
    return this
end

function cooldown.CreateGroup(Group: { [string]: number }): group
    const _gTable = {}
    for Name, cooldownV in Group do
        _gTable[Name] = cooldown.new(cooldownV)
    end

    const this: group = setmetatable({
        GroupTable = _gTable,
    }, GroupS)

    return this
end

return cooldown