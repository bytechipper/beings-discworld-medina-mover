local Config = require("config")

local State = {}

local function get_med()
    return _G._medina_med
end

local function set_med(m)
    _G._medina_med = m
end

function State.init()
    local med = get_med()
    if not med or type(med) ~= "table" or not med.rooms then
        med = storage.get("med")
    end
    if not med or type(med) ~= "table" or not med.rooms then
        med = { rooms = {} }
        for letter, graph_data in pairs(Config.ROOM_GRAPH) do
            med.rooms[letter] = {
                exit_rooms = graph_data.exit_rooms,
                location = graph_data.location,
                normalized = {},
                exits = false,
                solved = false,
                visited = false,
                thyngs = { mobs = { thugs = 0, heavies = 0, boss = 0 }, players = {} },
            }
        end
        for letter, _ in pairs(med.rooms) do
            for _, dir in pairs(med.rooms[letter].exit_rooms) do
                med.rooms[letter].normalized[dir] = false
            end
            med.rooms[letter].solved = false
            med.rooms[letter].exits = false
        end
        med.rooms.A.normalized.nw = "nw"
        med.rooms.R.normalized.se = "se"
    else
        for letter, graph_data in pairs(Config.ROOM_GRAPH) do
            if not med.rooms[letter] then
                med.rooms[letter] = {
                    exit_rooms = graph_data.exit_rooms,
                    location = graph_data.location,
                    normalized = {},
                    exits = false,
                    solved = false,
                    visited = false,
                    thyngs = { mobs = { thugs = 0, heavies = 0, boss = 0 }, players = {} },
                }
            end
        end
        for room, data in pairs(med.rooms) do
            data.thyngs = data.thyngs or { mobs = { thugs = 0, heavies = 0, boss = 0 }, players = {} }
            data.normalized = data.normalized or {}
            local graph = Config.ROOM_GRAPH[room]
            if graph then
                data.exit_rooms = data.exit_rooms or graph.exit_rooms
                data.location = data.location or graph.location
            end
        end
    end
    med.exit_counts = State.get_exit_counts(med.rooms)
    med.players = med.players or {}
    med.sync = med.sync or { received = false, data = {}, is_valid = false }
    med.look_room = false
    med.scry_room = false
    med.herd_path = med.herd_path or {}
    med.sequence = med.sequence or {}
    med.commands = med.commands or { move = { count = 0 }, look = { count = 0 } }
    med.is_in_medina = med.is_in_medina or false
    set_med(med)
end

function State.save()
    storage.set("med", get_med())
end

function State.get()
    local med = get_med()
    if not med then
        State.init()
        med = get_med()
    end
    return med
end

function State.reset_rooms()
    local med = { rooms = {} }
    for letter, graph_data in pairs(Config.ROOM_GRAPH) do
        med.rooms[letter] = {
            exit_rooms = graph_data.exit_rooms,
            location = graph_data.location,
            normalized = {},
            exits = false,
            solved = false,
            visited = false,
            thyngs = { mobs = { thugs = 0, heavies = 0, boss = 0 }, players = {} },
        }
    end
    for letter, _ in pairs(med.rooms) do
        for _, dir in pairs(med.rooms[letter].exit_rooms) do
            med.rooms[letter].normalized[dir] = false
        end
        med.rooms[letter].solved = false
        med.rooms[letter].exits = false
    end
    med.rooms.A.normalized.nw = "nw"
    med.rooms.R.normalized.se = "se"
    med.exit_counts = State.get_exit_counts(med.rooms)
    med.players = med.players or {}
    med.sync = med.sync or { received = false, data = {}, is_valid = false }
    med.look_room = false
    med.scry_room = false
    med.herd_path = med.herd_path or {}
    med.sequence = med.sequence or {}
    med.commands = med.commands or { move = { count = 0 }, look = { count = 0 } }
    med.is_in_medina = false
    set_med(med)
end

function State.reset_room_exits(room)
    local med = get_med()
    for _, dir in pairs(med.rooms[room].exit_rooms) do
        med.rooms[room].normalized[dir] = false
    end
    med.rooms[room].solved = false
    med.rooms[room].exits = false
    if room == "A" then med.rooms.A.normalized.nw = "nw" end
    if room == "R" then med.rooms.R.normalized.se = "se" end
end

function State.reset_room(room)
    local med = get_med()
    State.reset_room_exits(room)
    med.rooms[room].visited = false
    med.rooms[room].thyngs = { mobs = { thugs = 0, heavies = 0, boss = 0 }, players = {} }
end

function State.reset_thyngs(room_or_rooms)
    local med = get_med()
    if not med then return end
    if type(room_or_rooms) == "table" then
        for _, r in ipairs(room_or_rooms) do
            if med.rooms[r] then
                med.rooms[r].thyngs = { mobs = { thugs = 0, heavies = 0, boss = 0 }, players = {} }
            end
        end
    elseif room_or_rooms and med.rooms[room_or_rooms] then
        med.rooms[room_or_rooms].thyngs = { mobs = { thugs = 0, heavies = 0, boss = 0 }, players = {} }
    end
end

function State.depopulate()
    local med = get_med()
    for r, _ in pairs(med.rooms) do
        med.rooms[r].thyngs = { mobs = { thugs = 0, heavies = 0, boss = 0 }, players = {} }
    end
end

function State.unvisit()
    local med = get_med()
    for r, _ in pairs(med.rooms) do
        med.rooms[r].visited = false
    end
end

function State.get_exit_counts(rooms)
    local function get_exit_count(room)
        local count = 0
        for _, _ in pairs(rooms[room].exit_rooms) do count = count + 1 end
        if room == "A" or room == "R" then count = count + 1 end
        return count
    end

    local exit_counts = {}
    for room, v in pairs(rooms) do
        exit_counts[room] = { adj_room_exit_count = {} }
        local adj_room_count = 0
        for adj_room, _ in pairs(v.exit_rooms) do
            local n = get_exit_count(adj_room)
            exit_counts[room].adj_room_exit_count[n] = exit_counts[room].adj_room_exit_count[n] or {
                number_of_rooms = 0,
                rooms = {},
            }
            exit_counts[room].adj_room_exit_count[n].number_of_rooms =
                exit_counts[room].adj_room_exit_count[n].number_of_rooms + 1
            table.insert(exit_counts[room].adj_room_exit_count[n].rooms, adj_room)
            adj_room_count = adj_room_count + 1
        end
        if room == "A" or room == "R" then adj_room_count = adj_room_count + 1 end
        exit_counts[room].adj_room_count = adj_room_count
    end
    return exit_counts
end

return State
