local State = require("state")
local Config = require("config")

local Solve = {}

function Solve.solve_exit(start_room, direction, end_room)
    if not (start_room and direction and end_room) then return end
    local med = State.get()
    if not (med.rooms[start_room].exits and med.rooms[start_room].exit_rooms[end_room]) then return end
    if med.rooms[start_room].exits[direction] then
        local normalized = med.rooms[start_room].exit_rooms[end_room]
        med.rooms[start_room].exits[direction].room = end_room
        med.rooms[start_room].normalized[normalized] = direction
    end
    Solve.solve_final_count_matches(start_room)
    Solve.solve_final_exit(start_room)
end

function Solve.solve_final_count_matches(room)
    local med = State.get()
    local function get_count(t)
        local c = 0
        for _, _ in pairs(t) do c = c + 1 end
        return c
    end
    local function to_list(t1)
        local t2 = {}
        for k, v in pairs(t1) do
            if v then table.insert(t2, k) end
        end
        return t2
    end
    local function get_possible_rooms(room, exit_count)
        local t = {}
        if not med.exit_counts[room] or not med.exit_counts[room].adj_room_exit_count[exit_count] then
            return { rooms = t, directions = {} }
        end
        for _, v in pairs(med.exit_counts[room].adj_room_exit_count[exit_count].rooms) do
            t[v] = true
        end
        return { rooms = t, directions = {} }
    end

    if med.rooms[room].exits and not med.rooms[room].solved then
        local exit_set = {}
        for dir, v in pairs(med.rooms[room].exits) do
            if v.room then
                if not med.exit_counts[v.room] then goto continue2 end
                local exit_count = med.exit_counts[v.room].adj_room_count
                exit_set[exit_count] = exit_set[exit_count] or get_possible_rooms(room, exit_count)
                exit_set[exit_count].rooms[v.room] = false
            elseif v.exits then
                local exit_count = get_count(v.exits)
                exit_set[exit_count] = exit_set[exit_count] or get_possible_rooms(room, exit_count)
                table.insert(exit_set[exit_count].directions, dir)
            end
            ::continue2::
        end
        for exit_count, v in pairs(exit_set) do
            local rooms = to_list(v.rooms)
            local final_room = #rooms == 1 and rooms[1] or false
            local final_direction = #v.directions == 1 and v.directions[1] or false
            if final_room and final_direction then
                med.rooms[room].exits[final_direction].room = final_room
                med.rooms[room].normalized[med.rooms[room].exit_rooms[final_room]] = final_direction
            end
        end
    end
end

function Solve.solve_final_exit(start_room)
    local med = State.get()
    local count, final_exit = 0, ""
    if med.rooms[start_room].exits then
        for dir, v in pairs(med.rooms[start_room].exits) do
            if not v.room and not (start_room == "R" and dir == "se") and not (start_room == "A" and dir == "nw") then
                final_exit = dir
                count = count + 1
                if count > 1 then break end
            end
        end
        if count == 1 then
            local final_room = ""
            for end_room, dir in pairs(med.rooms[start_room].exit_rooms) do
                if not med.rooms[start_room].normalized[dir] then
                    med.rooms[start_room].normalized[dir] = final_exit
                    final_room = end_room
                    break
                end
            end
            med.rooms[start_room].exits[final_exit].room = final_room
            med.rooms[start_room].solved = os.time()
        elseif not med.rooms[start_room].solved and count == 0 then
            med.rooms[start_room].solved = os.time()
        end
    end
end

function Solve.get_room(start_room, end_exits)
    local med = State.get()
    local function to_list(t1)
        local t2 = {}
        for k, v in pairs(t1) do
            if v then table.insert(t2, k) end
        end
        return t2
    end
    local exit_count, possible_rooms = #end_exits, {}
    if exit_count == 6 then
        return { "I" }
    elseif exit_count == 5 then
        return { "E" }
    elseif start_room then
        for _, r in ipairs(start_room) do
            if med.exit_counts[r] and med.exit_counts[r].adj_room_exit_count[exit_count] then
                for _, room in pairs(med.exit_counts[r].adj_room_exit_count[exit_count].rooms) do
                    possible_rooms[room] = true
                end
            end
        end
        return to_list(possible_rooms)
    elseif exit_count == 4 then
        return { "A" }
    elseif exit_count == 2 then
        return { "R" }
    else
        return {}
    end
end

function Solve.get_scry_room(room, exits)
    local med = State.get()
    local scry_room = {}
    for i, v in ipairs(exits) do
        exits[v] = true
    end
    for i, r in ipairs(room) do
        if not med.rooms[r] then goto continue end
        local is_match = r
        if med.rooms[r].exits then
            for k, v in pairs(med.rooms[r].exits) do
                if not exits[k] then
                    is_match = false
                    break
                end
            end
        end
        if is_match then
            table.insert(scry_room, is_match)
        end
        ::continue::
    end
    if #scry_room == 0 then
        for i, r in ipairs(room) do
            table.insert(scry_room, r)
        end
    end
    return scry_room
end

function Solve.get_dark_scry_room(exits)
    local med = State.get()
    local exit_count = 0
    local scry_room = {}
    for _ in pairs(exits) do
        exit_count = exit_count + 1
    end
    for k, v in pairs(med.exit_counts) do
        if v.adj_room_count == exit_count then
            table.insert(scry_room, k)
        end
    end
    return scry_room
end

function Solve.verify_room(possible_start, start_exits, direction, possible_end, presumed_end, end_exits)
    local med = State.get()
    local function to_set(t1)
        local t2 = {}
        for _, v in ipairs(t1) do t2[v] = true end
        return t2
    end
    local function to_list(t1)
        local t2 = {}
        for k, _ in pairs(t1) do table.insert(t2, k) end
        return t2
    end
    local function get_count(t)
        local c = 0
        for _, _ in pairs(t) do c = c + 1 end
        return c
    end
    local function get_set_info(room, exit_count)
        local t = { directions = {}, rooms = {}, threshold = 0 }
        if med.exit_counts[room] and med.exit_counts[room].adj_room_exit_count[exit_count] then
            for _, r in ipairs(med.exit_counts[room].adj_room_exit_count[exit_count].rooms) do
                t.rooms[r] = {}
            end
            t.threshold = med.exit_counts[room].adj_room_exit_count[exit_count].number_of_rooms
        end
        return t
    end

    local start_room_set, end_room_set = {}, {}
    local presumed_end_set = presumed_end and to_set(presumed_end) or {}
    local possible_start_set = possible_start and to_set(possible_start) or {}

    if possible_end then
        for _, v in ipairs(possible_end) do
            if presumed_end_set[v] then
                table.insert(end_room_set, v)
            end
        end
    end

    local exit_change = false
    if #end_room_set == 0 then
        end_room_set = possible_end or {}
        exit_change = true
    end

    for _, v in ipairs(end_room_set) do
        if med.rooms[v] and med.rooms[v].exit_rooms then
            for k, _ in pairs(med.rooms[v].exit_rooms) do
                if possible_start_set[k] then
                    start_room_set[k] = true
                end
            end
        end
    end
    local start_room_list = to_list(start_room_set)

    if exit_change then
        for _, room in ipairs(start_room_list) do
            State.reset_room_exits(room)
            if start_exits then
                med.rooms[room].exits = {}
                for dir, _ in pairs(start_exits) do
                    med.rooms[room].exits[dir] = { room = false, exits = false }
                end
            end
        end
    end

    local absolute_end = #end_room_set == 1 and end_room_set[1] or false
    local absolute_start = #start_room_list == 1 and start_room_list[1] or false

    if absolute_start and start_exits then
        if not med.rooms[absolute_start].exits then
            med.rooms[absolute_start].exits = {}
            for dir, _ in pairs(start_exits) do
                med.rooms[absolute_start].exits[dir] = { room = false, exits = false }
            end
        end
        if med.rooms[absolute_start].exits[direction] ~= nil and end_exits then
            med.rooms[absolute_start].exits[direction].exits = {}
            start_exits[direction] = {}
            for dir, _ in pairs(end_exits) do
                start_exits[direction][dir] = true
                med.rooms[absolute_start].exits[direction].exits[dir] = true
            end
        end
        for i = #possible_end, 1, -1 do
            if not med.rooms[absolute_start].exit_rooms[possible_end[i]] then
                table.remove(possible_end, i)
            end
        end
        absolute_end = #end_room_set == 1 and end_room_set[1] or false

        if not absolute_end and med.rooms[absolute_start].exits and end_exits and direction then
            local exit_sets = {}
            for dir, v in pairs(med.rooms[absolute_start].exits) do
                if v.exits then
                    local ec = get_count(v.exits)
                    exit_sets[ec] = exit_sets[ec] or get_set_info(absolute_start, ec)
                    if v.room then
                        exit_sets[ec].rooms[v.room] = nil
                    else
                        table.insert(exit_sets[ec].directions, dir)
                    end
                    exit_sets[ec].threshold = exit_sets[ec].threshold - 1
                    if exit_sets[ec].threshold == 0 then
                        for r, _ in pairs(exit_sets[ec].rooms) do
                            if med.rooms[r] and med.rooms[r].exits then
                                local match = ""
                                for _, d in ipairs(exit_sets[ec].directions) do
                                    match = d
                                    for dd, _ in pairs(med.rooms[absolute_start].exits[d].exits) do
                                        if med.rooms[r].exits[dd] == nil then
                                            match = false
                                            break
                                        end
                                    end
                                    if match then
                                        table.insert(exit_sets[ec].rooms[r], match)
                                    end
                                end
                                if #exit_sets[ec].rooms[r] == 1 then
                                    Solve.solve_exit(absolute_start, exit_sets[ec].rooms[r][1], r)
                                    if med.rooms[absolute_start].exits[direction].room then
                                        end_room_set = {}
                                        table.insert(end_room_set, med.rooms[absolute_start].exits[direction].room)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    absolute_end = #end_room_set == 1 and end_room_set[1] or false
    if absolute_end and end_exits then
        if med.rooms[absolute_end].exits then
            exit_change = false
            for dir, _ in pairs(end_exits) do
                if not med.rooms[absolute_end].exits[dir] then
                    exit_change = true
                    break
                end
            end
            if exit_change then
                State.reset_room_exits(absolute_end)
                med.rooms[absolute_end].exits = {}
                for dir, _ in pairs(end_exits) do
                    med.rooms[absolute_end].exits[dir] = { room = false, exits = false }
                end
            end
        else
            med.rooms[absolute_end].exits = {}
            for dir, _ in pairs(end_exits) do
                med.rooms[absolute_end].exits[dir] = { room = false, exits = false }
            end
        end
    end

    if absolute_start and absolute_end then
        Solve.solve_exit(absolute_start, direction, absolute_end)
    end

    if absolute_end == "R" and not med.rooms.R.solved then
        Solve.solve_final_exit("R")
    end

    local result_start = to_list(start_room_set)
    local result_end = {}
    for _, room in ipairs(end_room_set) do table.insert(result_end, room) end
    result_start.exits = start_exits
    result_end.exits = end_exits
    return result_start, result_end
end

return Solve
