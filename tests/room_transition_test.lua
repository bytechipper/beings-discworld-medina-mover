return function(State, Solve)
    State.reset_rooms()
    local med = State.get()
    local observed = {e=true, ne=true, nw=true, se=true}
    med.rooms.E.exits = {s={room=false, exits=false}}
    med.rooms.E.normalized.n = "s"
    med.rooms.E.solved = 123
    med.rooms.E.visited = true
    med.rooms.E.thyngs.mobs.thugs = 4
    local start, finish = Solve.verify_room({"F"}, false, "s", {"E"}, {"E"}, observed)
    assert(start[1] == "F" and finish[1] == "E", "room candidates must remain letters")
    assert(finish.exits == observed)
    assert(med.rooms.E.exits.s == nil and med.rooms.E.exits.ne)
    assert(med.rooms.E.normalized.n == false and med.rooms.E.solved == false)
    assert(med.rooms.E.visited and med.rooms.E.thyngs.mobs.thugs == 4)

    -- A changed destination invalidates the source mapping as well.
    med.rooms.F.normalized.n = "sw"
    med.rooms.F.solved = 123
    start, finish = Solve.verify_room({"F"}, {s=true}, "s", {"E"}, {"G"}, observed)
    assert(start[1] == "F" and finish[1] == "E")
    assert(med.rooms.F.normalized.n == false)
    assert(med.rooms.F.exits.s.room == "E")
    for _, room in ipairs({"A", "R"}) do State.reset_room_exits(room) end
    assert(med.rooms.A.normalized.nw == "nw" and med.rooms.R.normalized.se == "se")
end
