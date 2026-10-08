local State = require("state")
local Config = require("config")
local Solve = require("solve")

local Move = {}

local function to_list(t1)
    local t2 = {}
    for k, v in pairs(t1) do
        if v then table.insert(t2, k) end
    end
    return t2
end

function Move.move_room(room, exits)
    local med = State.get()
    if med.commands.move[1] ~= "l" then
        med.commands.move[0] = med.commands.move[1]
        med.sequence[0] = med.sequence[1]
    else
        exits = med.sequence[1].exits or exits
    end
    table.remove(med.commands.move, 1)
    table.remove(med.sequence, 1)
    local direction = med.commands.move[0]
    local current_room, current_exits, presumed_room = room, exits, med.sequence[1] or {}
    local previous_room, previous_exits = med.sequence[0] or {}, med.sequence[0] and med.sequence[0].exits or false
    previous_room, current_room = Solve.verify_room(previous_room, previous_exits, direction, current_room, presumed_room, current_exits)
    med.sequence[0], med.sequence[1] = previous_room, current_room
    local absolute_current = #current_room == 1 and current_room[1] or false
    if absolute_current and med.rooms[absolute_current] and not med.rooms[absolute_current].visited then
        med.rooms[absolute_current].visited = true
    end
    Move.set_follow_delay(previous_room, med.commands.move[0])
    med.look_room, med.scry_room = false, false
    State.reset_thyngs(current_room)
    Move.construct_seq()
    Move.request_redraw()
end

function Move.look_room(room, exits)
    local med = State.get()
    med.commands.look[0] = med.commands.look[1]
    table.remove(med.commands.look, 1)
    local direction, look_direction = med.commands.move[0], med.commands.look[0]
    local current_room, current_exits = med.sequence[1] or {}, med.sequence[1] and med.sequence[1].exits or false
    local previous_room, previous_exits = med.sequence[0], med.sequence[0] and med.sequence[0].exits or false
    local look_room, look_exits = room, exits
    local presumed_room, presumed_look = med.sequence[1] or {}, Move.get_presumed_look(current_room, look_direction)
    current_room, look_room = Solve.verify_room(current_room, current_exits, look_direction, look_room, presumed_look, look_exits)
    previous_room, current_room = Solve.verify_room(previous_room, previous_exits, direction, current_room, presumed_room, current_exits)
    med.sequence[0], med.sequence[1] = previous_room, current_room
    local absolute_look = #look_room == 1 and look_room[1] or false
    if absolute_look and not med.rooms[absolute_look].visited then
        med.rooms[absolute_look].visited = true
    end
    med.look_room, med.scry_room = look_room, false
    State.reset_thyngs(look_room)
    Move.construct_seq()
    Move.request_redraw()
end

function Move.scry_room(room, exits)
    local med = State.get()
    local scry_room = Solve.get_scry_room(room, exits)
    med.look_room, med.scry_room = false, scry_room
    State.reset_thyngs(scry_room)
    Move.request_redraw()
end

function Move.get_presumed_look(room, dir)
    local med = State.get()
    local presumed_look = {}
    for _, r in ipairs(room) do
        if not med.rooms[r] then goto continue end
        local predictable = false
        if med.rooms[r].exits and med.rooms[r].exits[dir] and med.rooms[r].exits[dir].room then
            table.insert(presumed_look, med.rooms[r].exits[dir].room)
            predictable = true
        end
        if not predictable then
            for k, v in pairs(med.rooms[r].exit_rooms) do
                if not med.rooms[r].normalized[v] then
                    table.insert(presumed_look, k)
                end
            end
        end
        ::continue::
    end
    return presumed_look
end

function Move.construct_seq()
    local med = State.get()
    while med.sequence[2] do
        table.remove(med.sequence, 2)
    end
    for _, direction in ipairs(med.commands.move) do
        table.insert(med.sequence, to_list(Move.get_seq(med.sequence[#med.sequence], direction)))
    end
end

function Move.get_seq(start_room, direction)
    local med = State.get()
    local function get_adj(r)
        local t = {}
        if not med.rooms[r] then return t end
        t[r] = true
        for k, v in pairs(med.rooms[r].exit_rooms) do
            if not med.rooms[r].normalized[v] then
                t[k] = true
            end
        end
        return t
    end

    local end_room = {}
    if direction and direction:match("l") then
        end_room = start_room
    else
        for _, r in ipairs(start_room) do
            if med.rooms[r] and med.rooms[r].exits and med.rooms[r].exits[direction]
                and med.rooms[r].exits[direction].room then
                end_room[med.rooms[r].exits[direction].room] = true
            elseif med.rooms[r] and med.rooms[r].exits and not med.rooms[r].exits[direction]
                and not (r == "R" and direction == "se") and not (r == "A" and direction == "nw") then
                end_room[r] = true
            elseif not (r == "R" and direction == "se") and not (r == "A" and direction == "nw") then
                for k, _ in pairs(get_adj(r)) do
                    end_room[k] = true
                end
            end
        end
    end
    return end_room
end

function Move.exit_string_to_set(str)
    local t = {}
    if str:match(" north[%s%.,]") then t.n = true end
    if str:match(" northeast[%s%.,]") then t.ne = true end
    if str:match(" east[%s%.,]") then t.e = true end
    if str:match(" southeast[%s%.,]") then t.se = true end
    if str:match(" south[%s%.,]") then t.s = true end
    if str:match(" southwest[%s%.,]") then t.sw = true end
    if str:match(" west[%s%.,]") then t.w = true end
    if str:match(" northwest[%s%.,]") then t.nw = true end
    return t
end

function Move.exit_string_to_list(str)
    local t = {}
    if str:match(" north[%s%.,]") then table.insert(t, "n") end
    if str:match(" northeast[%s%.,]") then table.insert(t, "ne") end
    if str:match(" east[%s%.,]") then table.insert(t, "e") end
    if str:match(" southeast[%s%.,]") then table.insert(t, "se") end
    if str:match(" south[%s%.,]") then table.insert(t, "s") end
    if str:match(" southwest[%s%.,]") then table.insert(t, "sw") end
    if str:match(" west[%s%.,]") then table.insert(t, "w") end
    if str:match(" northwest[%s%.,]") then table.insert(t, "nw") end
    return t
end

function Move.format_direction(long_direction)
    local direction = string.lower(long_direction)
    direction = direction:gsub("north", "n")
    direction = direction:gsub("east", "e")
    direction = direction:gsub("south", "s")
    direction = direction:gsub("west", "w")
    direction = direction:gsub("look", "l")
    return direction
end

function Move.order_exits(t1)
    local t2 = {}
    for k, _ in pairs(t1) do
        if Config.COMPASS_ORDER[k] then
            table.insert(t2, k)
        end
    end
    table.sort(t2, function(a, b) return Config.COMPASS_ORDER[a] < Config.COMPASS_ORDER[b] end)
    local i = 0
    return function()
        i = i + 1
        if t2[i] then return t2[i], t1[t2[i]] end
    end
end

Move._redraw_callback = nil

function Move.set_redraw_callback(fn)
    Move._redraw_callback = fn
end

function Move.request_redraw()
    if Move._redraw_callback then
        Move._redraw_callback()
    end
end

Move._follow_delay_callback = nil

function Move.set_follow_delay_callback(fn)
    Move._follow_delay_callback = fn
end

function Move.set_follow_delay(previous_room, direction)
    if not (previous_room and direction) then return end
    local med = State.get()
    local rooms = ""
    local boss, heavies, thugs = 0, 0, 0
    for _, r in ipairs(previous_room) do
        if not med.rooms[r] then goto continue2 end
        boss = med.rooms[r].thyngs.mobs.boss
        heavies = med.rooms[r].thyngs.mobs.heavies
        thugs = med.rooms[r].thyngs.mobs.thugs
        if boss + thugs + heavies > 0 then
            rooms = rooms .. r
        end
        ::continue2::
    end
    if #rooms > 0 then
        local name = false
        for _, v in ipairs({ rooms, direction, boss, heavies, thugs }) do
            name = name and name .. "_" .. tostring(v) or rooms
        end
        if Move._follow_delay_callback then
            Move._follow_delay_callback(name, Config.FOLLOW_DELAY_MS)
        end
    end
end

return Move
