-- Mallard 0.27.0 loads sibling modules without caching. Share one instance
-- per VM so panel callbacks, commands, and lifecycle handlers see the same state.
local host_require = require
local modules = {}
require = function(name)
    if modules[name] == nil then modules[name] = host_require(name) end
    return modules[name]
end

local Config = require("config")
local State = require("state")
local Solve = require("solve")
local Move = require("move")
local Toggle = require("toggle")
local Mobs = require("mobs")
local Bfs = require("bfs")
local Sync = require("sync")
local Triggers = require("triggers")
local Panel = require("panel")
local Debug = require("debug")

State.init()
Panel.init()
Triggers.register_all()
Panel.request_redraw()

gmcp.on("Room.Info", function(pkg, data)
    log.info("[medina] Room.Info identifier=" .. tostring(data.identifier))
    if data.identifier == "BPMedina" then
        Toggle.enter()
    else
        Toggle.exit()
    end
end)

world.on("connect", function()
    log.info("[medina] world connected, sending look to detect location")
    mud.delay(500, function()
        mud.send("look")
    end)
end)

world.on("line", function(line)
    local med = State.get()
    if med and not med.is_in_medina and line.text:match("%[somewhere in an alleyway%]") then
        log.info("[medina] detected alleyway title while not in Medina, entering")
        Toggle.enter()
    end
end)

world.on("disconnect", function()
    State.save()
end)

mud.command("medina", function(m)
    local args = m.args or ""
    if args == "" or args == "help" then
        Panel._show_help()
        return
    end

    local sub, rest = args:match("^(%S+)%s*(.*)$")
    if not sub then sub = args end

    if sub == "reset" then
        local reset_args = rest:lower()
        local room_letter = reset_args:match("^room%s+([a-r])$")
            or reset_args:match("^r%s+([a-r])$")
        local current_room_requested = reset_args == "room" or reset_args == "r"
        if room_letter then
            room_letter = string.upper(room_letter)
            State.reset_room(room_letter)
            Move.request_redraw()
            local med = State.get()
            local current_room = med.sequence[1]
            if current_room and #current_room == 1 and current_room[1] == room_letter then
                mud.send("l")
            end
        elseif current_room_requested then
            local med = State.get()
            local current_room = med.sequence[1]
            if current_room and #current_room == 1 then
                State.reset_room(current_room[1])
                Move.request_redraw()
                mud.send("l")
            end
        elseif reset_args == "" then
            State.reset_rooms()
            Move.request_redraw()
            local med = State.get()
            if med.is_in_medina then mud.send("l") end
        else
            mud.note("[medina] Usage: /medina reset [room [A-R]]", { fg = "yellow" })
        end
    elseif sub == "sync" then
        local player = rest:match("^%s*(%w+)%s*$")
        if player then
            mud.send("tell " .. player .. " " .. Sync.get_sync())
        else
            Sync.accept_sync()
        end
    elseif sub == "arrow" then
        local set = rest:match("^%s*(%w+)%s*$")
        if set and (set == "default" or set == "rainbow") then
            storage.set("arrow_set", set)
            mud.note("[medina] Arrow set changed to " .. set, { fg = "green" })
            Move.request_redraw()
        else
            mud.note("[medina] Usage: /medina arrow [default|rainbow]", { fg = "yellow" })
        end
    elseif sub == "table" or sub == "t" then
        local room = rest:match("^%s*([A-Ra-r])%s*$")
        Debug.show_state(room)
    elseif sub == "window" then
        local action = rest:match("^(%w+)")
        if action == "open" then
            Move.request_redraw()
        elseif action == "exit" or action == "x" then
            Panel._visible = false
        elseif action == "center" then
            Move.request_redraw()
        end
    else
        Panel._show_help()
    end
end, {
    description = "Being's Discworld Medina Mover mapper",
    usage = "/medina [help|arrow|reset|sync|table|window]",
})

mud.on_send("^(n|s|e|w|u|d|north|south|east|west|up|down|nw|ne|se|sw|northwest|northeast|southeast|southwest)$", function(m)
    local med = State.get()
    if not med then return end
    if not med.is_in_medina then return end
    local dir = m[1]
    if #dir <= 2 then
        if dir == "u" or dir == "d" then
            -- skip up/down
        else
            dir = Move.format_direction(dir)
        end
    else
        dir = Move.format_direction(dir)
    end
    if dir ~= "u" and dir ~= "d" then
        med.commands.move.count = (med.commands.move.count or 0) + 1
        local to_send = dir
        local trajectory_room = #med.sequence > 0 and #med.sequence[#med.sequence] == 1 and med.sequence[#med.sequence][1] or false
        if trajectory_room and med.rooms[trajectory_room] and med.rooms[trajectory_room].normalized[dir] then
            to_send = med.rooms[trajectory_room].normalized[dir]
        end
        local possible_rooms = Move.get_seq(med.sequence[#med.sequence] or {}, dir)
        local function to_list(t1)
            local t2 = {}
            for k, v in pairs(t1) do
                if v then table.insert(t2, k) end
            end
            return t2
        end
        med.herd_path = {}
        for _, r in ipairs(med.sequence[#med.sequence] or {}) do
            med.herd_path[r] = to_send
        end
        table.insert(med.sequence, to_list(possible_rooms))
        table.insert(med.commands.move, to_send)
    end
end, { name = "medina_movement_observer", priority = 200 })

mud.on_send("^l$", function(m)
    local med = State.get()
    if not med.is_in_medina then return end
    med.commands.look.count = (med.commands.look.count or 0) + 1
    local trajectory_room = #med.sequence > 0 and #med.sequence[#med.sequence] == 1 and med.sequence[#med.sequence][1] or false
    local to_send = "l"
    if trajectory_room and med.rooms[trajectory_room] and med.rooms[trajectory_room].solved then
        to_send = med.rooms[trajectory_room].normalized["l"] or "l"
    end
    table.insert(med.commands.look, to_send)
end, { name = "medina_look_observer", priority = 200 })

mud.on_send("^look$", function(m)
    local med = State.get()
    if not med.is_in_medina then return end
    med.commands.look.count = (med.commands.look.count or 0) + 1
    table.insert(med.commands.look, "l")
end, { name = "medina_look_full_observer", priority = 200 })

mud.on_send("^(n|s|e|w|u|d|north|south|east|west|up|down|nw|ne|se|sw|northwest|northeast|southeast|southwest)$", function(m)
    local med = State.get()
    if not med.is_in_medina then return end
    Move.request_redraw()
end, { name = "medina_redraw_observer", priority = 50 })
