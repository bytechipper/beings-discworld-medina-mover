local State = require("state")
local Config = require("config")
local Move = require("move")

local Sync = {}

function Sync.get_sync()
    local med = State.get()
    local text, time, n = "", 0, 0
    local ex = { n = 1, ne = 2, e = 3, se = 4, s = 5, sw = 6, w = 7, nw = 8 }
    local A, R = 65, 82
    for i = A, R do
        local room = string.char(i)
        for static, temp in Move.order_exits(med.rooms[room].normalized) do
            if not (room == "A" and static == "nw" or room == "R" and static == "se") then
                text = text .. tostring(ex[temp] or "0")
            end
        end
        if med.rooms[room].solved then
            time = time + med.rooms[room].solved
            n = n + 1
        end
    end
    time = tostring(n == 0 and 0 or math.floor(time / n))
    text = time .. text
    local version = Config.VERSION
    local signature = "/zMMv" .. version .. "/"
    local based = Sync._convert_base(text, 10, 94)
    local hilt = "cxxxxx][={>>>"
    local blade = "_>>>"
    local sync_sword = hilt .. based .. signature .. blade
    return sync_sword
end

function Sync.handle_incoming_sync(sync, version, sender)
    local med = State.get()
    if #sync < 40 then
        sync = Sync._convert_base(sync, 94, 10)
        local total_rooms = 56
        local n = #sync - total_rooms
        if 0 < n and n <= 10 then
            local time, mapdata = string.match(sync, "^(" .. string.rep(".", n) .. ")(%d*)$")
            time = tonumber(time)
            if time and #mapdata == total_rooms then
                local ex = { "n", "ne", "e", "se", "s", "sw", "w", "nw" }
                ex[0] = false
                local unpacked, solved = {}, 0
                local A, R, idx = 65, 82, 1
                for i = A, R do
                    local room = string.char(i)
                    local prevent_duplicate_exits = {}
                    for static, temp in Move.order_exits(med.rooms[room].normalized) do
                        if not (room == "A" and static == "nw" or room == "R" and static == "se") then
                            unpacked[room] = unpacked[room] or { solved = true }
                            local m = tonumber(mapdata:sub(idx, idx))
                            if ex[m] ~= nil then
                                if not prevent_duplicate_exits[ex[m]] then
                                    if m > 0 then
                                        prevent_duplicate_exits[ex[m]] = true
                                    end
                                    unpacked[room][static] = ex[m]
                                    if not unpacked[room][static] then
                                        unpacked[room].solved = false
                                    end
                                else
                                    mud.note("[medina] Sync error: duplicate exits", { fg = "red" })
                                    return false
                                end
                                idx = idx + 1
                            else
                                mud.note("[medina] Sync error: incorrect format", { fg = "red" })
                                return false
                            end
                        end
                    end
                    if unpacked[room] and unpacked[room].solved then
                        solved = solved + 1
                    end
                end
                local percent = (math.floor((solved / 18) * 10000 + 0.5) / 100)
                med.sync = { data = unpacked, is_valid = true, time = time }
                Sync._show_sync_result(percent, time, version, sender)
                return true
            end
        end
    end
    mud.note("[medina] Invalid sync data from " .. (sender or "unknown"), { fg = "red" })
    return false
end

function Sync.accept_sync()
    local med = State.get()
    if med.sync.is_valid then
        local received = med.sync
        State.reset_rooms()
        med = State.get()
        med.sync = received
        for room, v in pairs(received.data) do
            if v.solved then
                for static, _ in Move.order_exits(v) do
                    if not (room == "A" and static == "nw" or room == "R" and static == "se") then
                        local temp = v[static]
                        med.rooms[room].normalized[static] = temp
                        med.rooms[room].solved = med.sync.time
                        if temp then
                            med.rooms[room].exits =
                                med.rooms[room].exits or
                                (room == "A" and { nw = { exits = false, room = false } } or
                                room == "R" and { se = { exits = false, room = false } } or {})
                            med.rooms[room].exits[temp] = { exits = false, room = false }
                            for adj_room, dir in pairs(med.rooms[room].exit_rooms) do
                                if static == dir then
                                    med.rooms[room].exits[temp].room = adj_room
                                end
                            end
                        end
                    end
                end
                med.rooms[room].solved = med.sync.time
            end
        end
        Move.request_redraw()
    else
        mud.note("[medina] No sync data available", { fg = "red" })
    end
end

function Sync._show_sync_result(percent, time, version, sender)
    local elapsed = os.time() - time
    local time_str = string.format("%02d:%02d:%02d", math.floor(elapsed / 3600), math.floor(elapsed / 60) % 60, elapsed % 60)
    mud.note(
        mud.span(sender, { fg = "lightgray" }),
        mud.span(" has sent you medina map data: ", { fg = "#aaaaaa" }),
        mud.span("[" .. percent .. "%] ", { fg = "orange" }),
        mud.span("(" .. time_str .. ")", { fg = "#aaaaaa" })
    )
    mud.note(
        mud.span("Type ", { fg = "#aaaaaa" }),
        mud.span("'medina sync'", { fg = "orange", send = "medina sync" }),
        mud.span(" to update!", { fg = "#aaaaaa" })
    )
    mud.note(mud.span("(This will override your current map.)", { fg = "#aaaaaa" }))
end

function Sync._convert_base(s, b1, b2)
    -- Long division over digit arrays preserves the 57-66 digit map payload.
    -- A Lua number cannot represent it exactly (or safely hold it as an integer).
    local digits = {}
    for i = 1, #s do
        local value = b1 == 94 and (s:byte(i) - 33) or tonumber(s:sub(i, i))
        if not value or value < 0 or value >= b1 then return "" end
        digits[#digits + 1] = value
    end
    local result = {}
    repeat
        local quotient, remainder = {}, 0
        for _, digit in ipairs(digits) do
            local value = remainder * b1 + digit
            local q = math.floor(value / b2)
            remainder = value % b2
            if #quotient > 0 or q > 0 then quotient[#quotient + 1] = q end
        end
        local char = b2 == 94 and string.char(remainder + 33) or tostring(remainder)
        table.insert(result, 1, char)
        digits = quotient
    until #digits == 0
    local converted = table.concat(result)
    if b2 == 10 then converted = string.rep("0", math.max(0, 57 - #converted)) .. converted end
    return converted
end

return Sync
