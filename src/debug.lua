local State = require("state")

local Debug = {}

function Debug.print_error(msg)
    mud.note("[medina] " .. msg, { fg = "orange" })
end

function Debug.print_table(t, indent)
    indent = indent or 0
    local prefix = string.rep("  ", indent)
    if type(t) ~= "table" then
        mud.note(prefix .. tostring(t), { fg = "white" })
        return
    end
    for k, v in pairs(t) do
        if type(v) == "table" then
            mud.note(prefix .. tostring(k) .. " = {", { fg = "cyan" })
            Debug.print_table(v, indent + 1)
            mud.note(prefix .. "}", { fg = "cyan" })
        else
            mud.note(prefix .. tostring(k) .. " = " .. tostring(v), { fg = "white" })
        end
    end
end

function Debug.show_state(room)
    local med = State.get()
    room = room and string.upper(room) or nil
    if room and room:match("^[A-R]$") then
        mud.note("[medina] Room " .. room .. ":", { fg = "cyan" })
        Debug.print_table(med.rooms[room])
    else
        mud.note("[medina] Players:", { fg = "cyan" })
        Debug.print_table(med.players)
        mud.note("[medina] Rooms:", { fg = "cyan" })
        Debug.print_table(med.rooms)
        mud.note("[medina] Commands.move:", { fg = "cyan" })
        Debug.print_table(med.commands.move)
        mud.note("[medina] Sequence:", { fg = "cyan" })
        Debug.print_table(med.sequence)
        mud.note("[medina] Commands.look:", { fg = "cyan" })
        Debug.print_table(med.commands.look)
    end
end

return Debug
