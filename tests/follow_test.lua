return function(State, Move, follow, room_info)
    -- Ricecake Alley is outside the Medina. Following there must not queue moves.
    room_info("Room.Info", {identifier = "93590e02066662a6c460cc478f4ace9d95f70c35"})
    local med = State.get()
    local count = med.commands.move.count
    for _ = 1, 2 do
        follow({[1] = "northeast", text = "You follow GRiME TiME northeast."})
    end
    assert(med.commands.move.count == count, "outside follows changed Medina queue")

    -- Entering can precede the first parsed room description, leaving no base room.
    room_info("Room.Info", {identifier = "BPMedina"})
    med.sequence = {}
    med.commands.move = {count = 0}
    for _ = 1, 2 do follow({[1] = "northeast"}) end
    assert(med.commands.move.count == 2)
    assert(#med.sequence == 3 and #med.sequence[1] == 0)
    assert(next(Move.get_seq(nil, "ne")) == nil)

    -- Reconstruct normally once a room is known; look keeps set-shaped candidates.
    med.rooms.A.exits = {ne = {room = "B"}}
    med.sequence = {{"A"}}
    med.commands.move = {"ne", count = 1}
    Move.construct_seq()
    assert(med.sequence[2][1] == "B")
    assert(Move.get_seq({"A"}, "l").A == true)
end
