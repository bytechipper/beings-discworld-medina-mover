local State = require("state")
local Config = require("config")
local Move = require("move")
local Solve = require("solve")
local Mobs = require("mobs")
local Toggle = require("toggle")

local Triggers = {}

local TITLE_PATTERN = "%[somewhere in an alleyway%]"
local SCRY_PATTERNS = {
    "The crystal ball changes to show a vision of the area where .* is",
    "The image in the crystal ball fades, but quickly returns showing a new area",
    "You see a vision in the .*",
    "You look through the .* door",
    "You look through the .* fur",
    "You see a vision in the silver mirror",
    "You see",
    "You focus past the .* baton, and visualise the place you remembered%.%.%.?",
    "You briefly see a vision%.?%.?%.?",
}
local SCRY_PATTERN = table.concat(SCRY_PATTERNS, "|")

local EXITS_PATTERN = "There are (%w+) obvious exits:"
local MOB_ENTER_PATTERN = nil
local MOB_EXIT_PATTERN = nil

local line_buffer = {}
local MAX_BUFFER_LINES = 8

local function trim(s)
    return s:match("^%s*(.-)%s*$")
end

local function get_brief_exits(str)
    local t = {}
    str = str .. ","
    for dir in str:gmatch("(.-),") do
        if dir:match("^[nsew][ew]?$") then
            table.insert(t, dir)
        end
    end
    return t
end

local function list_to_set(t1)
    local t2 = {}
    for _, v in ipairs(t1) do t2[v] = true end
    return t2
end

local function process_room_lines(lines)
    local med = State.get()
    if not med or not med.is_in_medina then return false end

    local title_match = false
    local scry_match = false
    local look_match = false
    local first_line = lines[1] or ""

    if first_line:match(TITLE_PATTERN) then
        title_match = true
    elseif first_line:match(SCRY_PATTERN) then
        scry_match = true
    else
        look_match = true
    end

    local exits_str = ""
    local thyngs_str = ""
    local room_description = ""
    local is_dark = false

    for _, line in ipairs(lines) do
        local exit_match = line:match(EXITS_PATTERN)
        if exit_match then
            exits_str = line
        end
        if line:match("here%.$") or line:match("here%.?$") then
            if not line:match("obvious exits") and not line:match("dark here") then
                thyngs_str = line
            end
        end
        if line:match("It's dark here, isn't it%?") then
            is_dark = true
        end
        if not line:match(TITLE_PATTERN) and not line:match(SCRY_PATTERN)
            and not line:match(EXITS_PATTERN) and not line:match("dark here")
            and not line:match("^It is") and not line:match("^The %(water|land%) is lit") then
            if room_description == "" then
                room_description = line
            end
        end
    end

    local exits = Move.exit_string_to_set(exits_str)
    local exit_list = Move.exit_string_to_list(exits_str)

    if title_match then
        local room = nil
        if room_description ~= "" then
            for i, desc in ipairs(Config.ROOM_DESCRIPTIONS) do
                if room_description:match(desc:sub(1, 40)) then
                    local letter = string.char(i + 64)
                    if letter == "H" then
                        room = { "H", "N" }
                    else
                        room = { letter }
                    end
                    break
                end
            end
        end
        if not room then
            room = Solve.get_room(med.sequence[1], exit_list)
        end
        if thyngs_str ~= "" then
            Mobs.get_mobs(thyngs_str, 1, med.sequence[1])
        else
            Move.move_room(room, exits)
        end
        return true
    elseif look_match then
        local room = nil
        if room_description ~= "" then
            for i, desc in ipairs(Config.ROOM_DESCRIPTIONS) do
                if room_description:match(desc:sub(1, 40)) then
                    local letter = string.char(i + 64)
                    if letter == "H" then
                        room = { "H", "N" }
                    else
                        room = { letter }
                    end
                    break
                end
            end
        end
        if not room then
            room = Solve.get_room(med.sequence[1], exit_list)
        end
        if thyngs_str ~= "" then
            Mobs.get_mobs(thyngs_str, 1, med.look_room)
        else
            Move.look_room(room, exits)
        end
        return true
    elseif scry_match then
        local room = Solve.get_room(med.sequence[1], exit_list)
        if thyngs_str ~= "" then
            Mobs.get_mobs(thyngs_str, 1, med.scry_room)
        else
            Move.scry_room(room, exits)
        end
        return true
    end

    return false
end

function Triggers.register_all()
    local handle

    handle = mud.trigger("^\\[somewhere in an alleyway\\]", function(m)
        line_buffer = { m.text }
    end, { name = "medina_title_line", priority = 200 })
    Toggle.register_trigger_handle("title_line", handle)

    handle = mud.trigger("^The (?:crystal ball|image in the crystal ball|You see a vision|You look through the|You focus past the|You briefly see)", function(m)
        line_buffer = { m.text }
    end, { name = "medina_scry_line", priority = 200 })
    Toggle.register_trigger_handle("scry_line", handle)

    handle = mud.trigger(".+", function(m)
        if #line_buffer > 0 and #line_buffer < MAX_BUFFER_LINES then
            local med = State.get()
            if med and med.is_in_medina then
                table.insert(line_buffer, m.text)
                if m.text:match("obvious exits:") or m.text:match("here%.$") or m.text:match("^%s*$") then
                    process_room_lines(line_buffer)
                    line_buffer = {}
                end
            end
        end
    end, { name = "medina_room_line", priority = 150 })
    Toggle.register_trigger_handle("room_line", handle)

    handle = mud.trigger("^Removed queue%.$", function(m)
        local med = State.get()
        if not med then return end
        while med.commands.look[med.commands.look.count + 1] do
            table.remove(med.commands.look, med.commands.look.count + 1)
        end
        while med.commands.move[med.commands.move.count + 1] do
            table.remove(med.commands.move, med.commands.move.count + 1)
        end
        while med.sequence[med.commands.move.count + 2] do
            table.remove(med.sequence, med.commands.move.count + 2)
        end
        Move.request_redraw()
    end, { name = "medina_remove_queue", priority = 100 })
    Toggle.register_trigger_handle("remove_queue", handle)

    handle = mud.trigger("^(?:That doesn't work\\.|What\\?|Try something else\\.)$", function(m)
        local med = State.get()
        if not med then return end
        if #med.commands.move > 0 then
            table.remove(med.commands.move, 1)
        end
        if #med.sequence > 1 then
            table.remove(med.sequence, 2)
        end
        Move.construct_seq()
        Move.request_redraw()
    end, { name = "medina_command_fail", priority = 100 })
    Toggle.register_trigger_handle("command_fail", handle)

    handle = mud.trigger("^You follow .* (north|northeast|east|southeast|south|southwest|west|northwest)\\.$", function(m)
        local med = State.get()
        if not med then return end
        med.commands.move.count = (med.commands.move.count or 0) + 1
        local direction = Move.format_direction(m[1])
        table.insert(med.commands.move, 1, direction)
        Move.construct_seq()
        med.herd_path = {}
        for _, r in ipairs(med.sequence[#med.sequence] or {}) do
            med.herd_path[r] = direction
        end
        Move.request_redraw()
    end, { name = "medina_you_follow", priority = 100 })
    Toggle.register_trigger_handle("you_follow", handle)

    handle = mud.trigger("^.+ \\[((?:n|s|e|w|ne|nw|se|sw)(?:,(?:n|s|e|w|ne|nw|se|sw))*)\\]\\.$", function(m)
        local med = State.get()
        if not med or not med.is_in_medina then return end
        local exits = get_brief_exits(m[1])
        local room = Solve.get_room(med.sequence[1], exits)
        if not room or #room == 0 then return end
        Move.move_room(room, list_to_set(exits))
    end, { name = "medina_brief_room", priority = 100 })
    Toggle.register_trigger_handle("brief_room", handle)

    local Sync = require("sync")
    local sync_pattern = "^(\\w+) .*tells you: .*\\[=\\{>>>.*\\/zMMv(\\d+\\.\\d+(?:\\.\\d+)?)\\/.*>>>$"
    handle = mud.trigger(sync_pattern, function(m)
        local sender = m[1] or "unknown"
        local version = m[2] or "5.0"
        local text = m.text
        local sync = text:match("={>>>(.+)/zMMv")
        if sync then
            Sync.handle_incoming_sync(sync, version, sender)
        end
    end, { name = "medina_receive_sync", priority = 100, flags = "i" })
    Toggle.register_trigger_handle("receive_sync", handle)
end

return Triggers
