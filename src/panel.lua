local State = require("state")
local Config = require("config")
local Bfs = require("bfs")
local Move = require("move")
local Toggle = require("toggle")

local Panel = {}

local panel_handle = nil
local redraw_pending = false
local REDRAW_DEBOUNCE_MS = 16

Panel._visible = false

function Panel.init()
    panel_handle = mud.panel("map")

    panel_handle:on_message("ready", function(data)
        mud.delay(100, function()
            Panel._push_state()
        end)
    end)

    panel_handle:on_message("room_click", function(data)
        local med = State.get()
        if data.room and med.rooms[data.room] then
            local current_room = med.sequence[1]
            if current_room and #current_room == 1 then
                Bfs.shortest_path(current_room[1], data.room, false)
            end
        end
    end)

    panel_handle:on_message("exit_click", function(data)
        if data.direction then
            mud.send("l " .. data.direction)
        end
    end)

    panel_handle:on_message("room_right_click", function(data)
        if data.room then
            mud.send("l")
        end
    end)

    panel_handle:on_message("menu_action", function(data)
        if data.action == "help" then
            Panel._show_help()
        elseif data.action == "reset" then
            State.reset_rooms()
            Move.request_redraw()
            if State.get().is_in_medina then mud.send("l") end
        elseif data.action == "reset_room" and data.room then
            State.reset_room(data.room)
            Move.request_redraw()
            local med = State.get()
            local current_room = med.sequence[1]
            if current_room and #current_room == 1 and current_room[1] == data.room then
                mud.send("l")
            end
        end
    end)

    Move.set_redraw_callback(Panel.request_redraw)

    Move.set_follow_delay_callback(function(name, delay_ms)
        mud.delay(delay_ms, function()
            local rooms, direction, boss, heavies, thugs = name:match("^(%w*)_(%w+)_(%d+)_(%d+)_(%d+)$")
            if rooms and direction and boss and heavies and thugs then
                local mobs = {
                    boss = tonumber(boss),
                    heavies = tonumber(heavies),
                    thugs = tonumber(thugs),
                }
                local distance = mobs.thugs
                local med = State.get()
                local current_room_set = {}
                for _, v in ipairs(med.sequence[1] or {}) do
                    current_room_set[v] = true
                end
                rooms:gsub(".", function(start_room)
                    local has_player = false
                    for k, _ in pairs(med.rooms[start_room].thyngs.players) do
                        if k then has_player = true end
                    end
                    if not (has_player and current_room_set[start_room]) then
                        local end_room = start_room
                        local rooms_moved = 0
                        local impeding = false
                        while
                            med.rooms[end_room].exits and
                            med.rooms[end_room].exits[direction] and
                            med.rooms[end_room].exits[direction].room and
                            rooms_moved < distance
                        do
                            end_room = med.rooms[end_room].exits[direction].room
                            rooms_moved = rooms_moved + 1
                            if current_room_set[end_room] then
                                impeding = true
                                break
                            end
                        end
                        for k, v in pairs(mobs) do
                            local p = med.rooms[start_room].thyngs.mobs[k]
                            local n = v
                            if p - n < 0 then n = p end
                            med.rooms[start_room].thyngs.mobs[k] = p - n
                            if not impeding then
                                local p2 = med.rooms[end_room].thyngs.mobs[k]
                                med.rooms[end_room].thyngs.mobs[k] = p2 + v
                            end
                        end
                        if med.is_in_medina then
                            Move.request_redraw()
                        end
                    end
                end)
            end
        end)
    end)

    Toggle.set_visible_callback(function(visible)
        Panel._visible = visible
    end)
end

function Panel.request_redraw()
    if redraw_pending then return end
    redraw_pending = true
    mud.delay(REDRAW_DEBOUNCE_MS, function()
        redraw_pending = false
        Panel._push_state()
    end)
end

function Panel._push_state()
    if not panel_handle then return end
    local med = State.get()
    if not med then return end

    local rooms_data = {}
    for letter, room in pairs(med.rooms) do
        rooms_data[letter] = {
            location = room.location,
            exit_rooms = room.exit_rooms,
            normalized = room.normalized or {},
            solved = room.solved and true or false,
            visited = room.visited or false,
            exits = room.exits,
            thyngs = room.thyngs,
        }
    end

    local current_room = {}
    if med.sequence[1] then
        if type(med.sequence[1]) == "table" then
            current_room = med.sequence[1]
        end
    end

    local trajectory_room = {}
    if med.sequence[#med.sequence] and #med.sequence[#med.sequence] > 0 then
        trajectory_room = med.sequence[#med.sequence]
    end

    local state = {
        rooms = rooms_data,
        current_room = current_room,
        look_room = med.look_room or {},
        scry_room = med.scry_room or {},
        trajectory_room = trajectory_room,
        herd_path = med.herd_path or {},
        is_in_medina = med.is_in_medina,
        window_size = med.window_size or Config.DEFAULT_WINDOW_SIZE,
        arrow_set = storage.get("arrow_set") or settings.get("arrow_set") or "default",
    }

    panel_handle:post("state", state)
end

function Panel._show_help()
    mud.note("[medina] Being's Discworld Medina Mover v" .. Config.VERSION, { fg = "cyan", bold = true })
    mud.note("  /medina help     - Show this help", { fg = "white" })
    mud.note("  /medina arrow [default|rainbow] - Change arrow set", { fg = "white" })
    mud.note("  /medina reset    - Reset entire map", { fg = "white" })
    mud.note("  /medina reset room - Reset current room", { fg = "white" })
    mud.note("  /medina reset room <letter> - Reset specific room", { fg = "white" })
    mud.note("  /medina sync     - Accept map data from another player", { fg = "white" })
    mud.note("  /medina sync <player> - Send map data to player", { fg = "white" })
    mud.note("  /medina table    - Debug: show internal state", { fg = "white" })
    mud.note("Click a room on the map to auto-walk there.", { fg = "#aaaaaa" })
    mud.note("Right-click the title bar for options.", { fg = "#aaaaaa" })
end

return Panel
