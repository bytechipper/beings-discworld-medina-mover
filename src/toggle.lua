local State = require("state")
local Config = require("config")

local Toggle = {}

Toggle._trigger_handles = {}
Toggle._leave_timers = {}
Toggle._set_visible_callback = nil
Toggle._enable_triggers_callback = nil

function Toggle.set_visible_callback(fn)
    Toggle._set_visible_callback = fn
end

function Toggle.set_enable_triggers_callback(fn)
    Toggle._enable_triggers_callback = fn
end

function Toggle.register_trigger_handle(name, handle)
    Toggle._trigger_handles[name] = handle
end

function Toggle.enable_triggers(enabled)
    for _, handle in pairs(Toggle._trigger_handles) do
        if handle then
            if enabled then
                handle:enable()
            else
                handle:disable()
            end
        end
    end
end

function Toggle.enter()
    local med = State.get()
    if not med then return end
    if not med.is_in_medina then
        med.is_in_medina = true
        med.commands = { move = { count = 0 }, look = { count = 0 } }
        med.sequence = {}
        Toggle.enable_triggers(true)
        for _, timer in pairs(Toggle._leave_timers) do
            if timer then timer:remove() end
        end
        Toggle._leave_timers = {}
        if Toggle._set_visible_callback then
            Toggle._set_visible_callback(true)
        end
    end
end

function Toggle.exit()
    local med = State.get()
    if not med then return end
    if med.is_in_medina then
        med.is_in_medina = false
        local previous_room = med.sequence[1] or false
        med.sequence = {}
        med.sequence[0] = previous_room
        Toggle.enable_triggers(false)
        Toggle._leave_timers.unvisit = mud.delay(Config.EXIT_LEAVE_DELAY_MS, function()
            State.unvisit()
        end)
        Toggle._leave_timers.depopulate = mud.delay(Config.EXIT_LEAVE_DELAY_MS, function()
            State.depopulate()
        end)
    end
    if Toggle._set_visible_callback then
        Toggle._set_visible_callback(false)
    end
end

return Toggle
