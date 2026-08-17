# CooldownService

A lightweight, strictly typed Luau cooldown management module built on top of timer state handling. Supports event binding, lifecycle hooks, and multi-cooldown group management.

---

## Features

* **Lazy Timer Initialization**: Internal timers are allocated only when a cooldown is triggered for the first time.
* **Lifecycle Hooks**: Bind callbacks to automatic events (`OnUse`, `OnFail`, `OnReady`).
* **Group Management**: Batch-control multiple cooldowns simultaneously with shared or targeted bindings.
* **Strictly Typed**: Fully compatible with Luau's `--!strict` mode.

---

## Quick Start

```luau
local CooldownService = require(path.to.CooldownService)

-- Create a 5-second cooldown
local fireball = CooldownService.new(5)

-- Bind callbacks to lifecycle events
fireball:Bind("OnUse", function(spellName)
    print("Cast " .. spellName .. "!")
end)

fireball:Bind("OnFail", function()
    print("Fireball is still on cooldown! Seconds left:", fireball:Remaining())
end)

fireball:Bind("OnReady", function()
    print("Fireball is ready to use again!")
end)

-- Attempt to use
fireball:Use("Fireball") -- Output: Cast Fireball!
fireball:Use("Fireball") -- Output: Fireball is still on cooldown!

```

---

## Lifecycle Event Tags

The service fires specific default tags during usage:

| Tag | Fired When | Passed Arguments |
| --- | --- | --- |
| `"OnUse"` | Called via `:Use()` (when ready) or `:ForceUse()` | Arguments passed into `:Use(...)` or `:ForceUse(...)` |
| `"OnFail"` | Called via `:Use()` while the cooldown is still active | Arguments passed into `:Use(...)` |
| `"OnReady"` | The timer successfully reaches 0 seconds | Arguments returned by internal timer completion |

---

## API Reference

### Constructor

#### `CooldownService.new(duration: number): CooldownService`

Creates a new cooldown instance with the specified duration in seconds.

---

### Cooldown Methods

#### `:Use(...: any): boolean`

Attempts to trigger the cooldown. If ready, starts the timer, fires `"OnUse"`, and returns `true`. If active, fires `"OnFail"` and returns `false`.

#### `:ForceUse(...: any): CooldownService`

Triggers the cooldown immediately, bypassing readiness checks, and fires `"OnUse"`.

#### `:Ready(): boolean` / `:CanUse(): boolean`

Returns `true` if the cooldown is not active or has finished.

#### `:Remaining(): number`

Returns the remaining time in seconds. Returns `0` if ready.

#### `:SetCooldown(newDuration: number): CooldownService`

Updates the total cooldown duration.

#### `:Bind(tag: string, fn: (...any) -> ...any): CooldownService`

Binds a callback function to a specified tag name.

#### `:Unbind(tag: string): CooldownService`

Removes the callback for the specified tag.

#### `:FireBind(tag: string, ...: any): any`

Manually invokes the callback bound to `tag`.

#### `:FireAllBinds(...: any): CooldownService`

Spawns all bound callbacks asynchronously using `task.spawn`.

#### `:ClearBinds(): CooldownService`

Removes all registered tag bindings.

#### `:Destroy()`

Cleans up internal timers and unbinds all events.

---

## Group Management

Group multiple cooldowns together to manage ability kits, inventory items, or system states.

```luau
local CooldownService = require(path.to.CooldownService)

-- Create a group
local abilities = CooldownService.CreateGroup({
    Dash = 2,
    Fireball = 5,
    Ultimate = 30,
})

-- Bind an event across all abilities in the group
abilities:BindAll("OnFail", function()
    print("Ability is on cooldown!")
end)

-- Check if every ability in the group is ready
if abilities:CanUseAll() then
    abilities:UseAll()
end

-- Retrieve an individual cooldown from the group
local dash = abilities:Get("Dash")
if dash then
    dash:Use()
end

```

### Group Methods

#### `CooldownService.CreateGroup(groupTable: {[string]: number}): group`

Creates a managed group of named cooldowns.

#### `group:CanUseAll(): boolean`

Returns `true` if **every** cooldown in the group is ready.

#### `group:UseAll(...: any)`

Forces every cooldown in the group onto cooldown simultaneously.

#### `group:Get(name: string): CooldownService?`

Returns the specific `CooldownService` instance by name.

#### `group:Bind(name: string, tag: string, fn: function): group`

Binds a callback to a specific named cooldown inside the group.

#### `group:BindAll(tag: string, fn: function): group`

Binds a callback to the specified tag across **all** cooldowns in the group.