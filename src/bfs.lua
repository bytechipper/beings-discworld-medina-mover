local State = require("state")
local Move = require("move")

local Bfs = {}

function Bfs.shortest_path(start_node, end_node, is_look)
    local med = State.get()

    local function deepcopy(orig)
        if type(orig) ~= "table" then return orig end
        local copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        return copy
    end

    if not start_node then return false end
    local g = deepcopy(med.rooms)
    local queue, visited, current = {}, {}, ""
    queue[1] = start_node
    visited[start_node] = true
    g[start_node].parent = false
    local solved = false

    while #queue > 0 do
        current = queue[1]
        table.remove(queue, 1)
        if current == end_node then
            solved = true
            break
        end
        if g[current] and g[current].exit_rooms then
            for k, v in pairs(g[current].exit_rooms) do
                if not visited[k] then
                    if g[current].normalized and g[current].normalized[v] then
                        visited[k] = true
                        table.insert(queue, k)
                        g[k].parent = current
                    end
                end
            end
        end
    end

    if solved then
        local path = {}
        local source_node = g[end_node].parent
        while source_node do
            table.insert(path, 1, source_node)
            source_node = g[source_node].parent
        end
        table.insert(path, end_node)
        table.remove(path, 1)

        current = start_node
        for i, v in ipairs(path) do
            local direction = g[current].exit_rooms[v]
            if i == #path and is_look then
                Move.look_room({ v }, false)
            else
                Move.move_room({ v }, false)
            end
            current = v
        end
    else
        mud.note("[medina] No path found. Unlock more exits!", { fg = "red" })
    end

    return solved
end

return Bfs
