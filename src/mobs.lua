local State = require("state")
local Config = require("config")
local Move = require("move")

local Mobs = {}

local VERBIAGE_PATTERN = "(?:is|are) (?:standing|sitting|lying|hovering|resting|sleeping|waiting|leaning|crouching|kneeling|pacing|wandering|running|walking|fighting|brawling|battling|wrestling|grappling|struggling|hiding|lurking|patrolling|guarding|resting|browsing|shopping|selling|buying|trading|eating|drinking|cooking|fishing|hunting|mining|chopping|digging|building|repairing|crafting|sewing|weaving|spinning|painting|drawing|writing|reading|studying|practicing|training|meditating|praying|worshipping|singing|dancing|playing|performing|entertaining|juggling|tumbling|acrobatics|here\\.?)"

function Mobs.get_mobs(thyngs_text, sign, room)
    local med = State.get()
    local text = string.lower(thyngs_text)
    local direction = nil

    text = text:gsub(VERBIAGE_PATTERN, "")

    local population = { mobs = { thugs = 0, heavies = 0, boss = 0 }, players = {} }
    local is_players = false
    local thyngs = ", " .. text:gsub(" and ", ", ")

    for thyng in thyngs:gmatch("([^,]+)") do
        thyng = thyng:match("^%s*(.-)%s*$")
        if thyng and #thyng > 0 then
            if med.players[thyng] then
                local player = thyng
                local p_colour = med.players[thyng]
                player = player:gsub("^([a-z']+) .*$", "%1")
                population.players[player] = p_colour
                is_players = true
            else
                local mob, n = Mobs._get_quantity(thyng)
                mob = Mobs._format_mobs(mob, n)
                if population.mobs[mob] ~= nil then
                    population.mobs[mob] = population.mobs[mob] + n
                end
            end
        end
    end

    local target_room = room or med.sequence[1] or {}

    for player, colour in pairs(population.players) do
        for r, _ in pairs(med.rooms) do
            med.rooms[r].thyngs.players[player] = nil
        end
        if sign > 0 then
            for _, r in ipairs(target_room) do
                if med.rooms[r] then
                    med.rooms[r].thyngs.players[player] = colour
                end
            end
        end
    end

    for mob, count in pairs(population.mobs) do
        if count > 0 then
            if mob == "boss" then
                local previous_boss_room = {}
                for r, _ in pairs(med.rooms) do
                    if med.rooms[r].thyngs.mobs.boss > 0 then
                        previous_boss_room[r] = true
                    end
                    med.rooms[r].thyngs.mobs.boss = 0
                end
                for _, r in ipairs(target_room) do
                    if med.rooms[r] then
                        previous_boss_room[r] = nil
                        med.rooms[r].thyngs.mobs.boss = sign > 0 and 1 or 0
                    end
                end
                for r, _ in pairs(previous_boss_room) do
                    if med.rooms[r] then
                        med.rooms[r].thyngs.mobs = { thugs = 0, heavies = 0, boss = 0 }
                    end
                end
            else
                for _, r in ipairs(target_room) do
                    if med.rooms[r] then
                        if sign > 0 then
                            med.rooms[r].thyngs.mobs[mob] = med.rooms[r].thyngs.mobs[mob] + count
                        else
                            local p = med.rooms[r].thyngs.mobs[mob]
                            med.rooms[r].thyngs.mobs[mob] = math.max(0, p - count)
                        end
                    end
                end
            end
        end
    end

    Move.request_redraw()
end

function Mobs._get_quantity(mob)
    mob = mob:gsub("^an? ", "the ")
    local n = ""
    if mob:match("^(%w+) (.*)") then
        n, mob = mob:match("^(%w+) (.*)")
    end
    n = Config.NUMBER_WORDS[n] or 1
    return mob, n
end

function Mobs._format_mobs(mob, n)
    if n == 1 then
        mob = mob:gsub("y$", "ies"):gsub("([^s])$", "%1s")
    end
    mob = mob:gsub("triad ", "")
    return mob
end

return Mobs
