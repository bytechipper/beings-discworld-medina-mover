local Config = {}

Config.VERSION = "1.0.5"

Config.TITLE_HEIGHT = 16
Config.DEFAULT_WINDOW_SIZE = 300
Config.MIN_WINDOW_SIZE = 300
Config.RESIZE_THROTTLE_MS = 33
Config.FOLLOW_DELAY_MS = 5250
Config.EXIT_LEAVE_DELAY_MS = 3000

Config.DIRECTIONS = { n = true, ne = true, e = true, se = true, s = true, sw = true, w = true, nw = true }

Config.COMPASS_ORDER = { n = 1, ne = 2, e = 3, se = 4, s = 5, sw = 6, w = 7, nw = 8 }

Config.LONG_TO_SHORT = {
    north = "n", northeast = "ne", east = "e", southeast = "se",
    south = "s", southwest = "sw", west = "w", northwest = "nw",
    look = "l",
}

Config.SHORT_TO_LONG = {}
for long, short in pairs(Config.LONG_TO_SHORT) do
    Config.SHORT_TO_LONG[short] = long
end

Config.EXIT_COUNTS = {
    A = 4, B = 3, C = 2, D = 3, E = 5, F = 4, G = 2,
    H = 3, I = 6, J = 3, K = 2, L = 4, M = 4, N = 3,
    O = 2, P = 3, Q = 3, R = 2,
}

Config.ROOM_GRAPH = {
    A = { exit_rooms = { B = "e", E = "se", D = "s" }, location = { x = 1, y = 1 } },
    B = { exit_rooms = { C = "e", E = "s", A = "w" }, location = { x = 2, y = 1 } },
    C = { exit_rooms = { F = "s", B = "w" }, location = { x = 3, y = 1 } },
    D = { exit_rooms = { A = "n", E = "e", H = "se" }, location = { x = 1, y = 2 } },
    E = { exit_rooms = { B = "n", F = "e", I = "se", D = "w", A = "nw" }, location = { x = 2, y = 2 } },
    F = { exit_rooms = { C = "n", G = "e", I = "s", E = "w" }, location = { x = 3, y = 2 } },
    G = { exit_rooms = { K = "se", F = "w" }, location = { x = 4, y = 2 } },
    H = { exit_rooms = { I = "e", L = "se", D = "nw" }, location = { x = 2, y = 3 } },
    I = { exit_rooms = { F = "n", J = "e", M = "se", L = "s", H = "w", E = "nw" }, location = { x = 3, y = 3 } },
    J = { exit_rooms = { K = "e", N = "se", I = "w" }, location = { x = 4, y = 3 } },
    K = { exit_rooms = { J = "w", G = "nw" }, location = { x = 5, y = 3 } },
    L = { exit_rooms = { I = "n", M = "e", O = "s", H = "nw" }, location = { x = 3, y = 4 } },
    M = { exit_rooms = { N = "e", P = "s", L = "w", I = "nw" }, location = { x = 4, y = 4 } },
    N = { exit_rooms = { Q = "s", M = "w", J = "nw" }, location = { x = 5, y = 4 } },
    O = { exit_rooms = { L = "n", P = "e" }, location = { x = 3, y = 5 } },
    P = { exit_rooms = { M = "n", Q = "e", O = "w" }, location = { x = 4, y = 5 } },
    Q = { exit_rooms = { N = "n", R = "e", P = "w" }, location = { x = 5, y = 5 } },
    R = { exit_rooms = { Q = "w" }, location = { x = 6, y = 5 } },
}

Config.ROOM_DESCRIPTIONS = {
    "This is a small winding alleyway, and there are other alleys leading off it.  They are all small and winding too.  The walls are too high to see over, and buildings block your view in all directions.  A person could easily get lost in here unless they had a good memory, or a map.",
    "Standing in an alleyway, surrounded by buildings and other alleys, your head spins as you struggle to get your bearings.  You fail miserably.  Alleys lead in several directions.",
    "The alleyway gets very narrow here. There are other alleys leading off it.  They are all small and winding too.  The walls are too high to see over, and buildings block your view in all directions.  A person could easily get lost in here unless they had a good memory, or a map.",
    "This is a small winding alleyway with a T-junction.  All three possible exits look very similar and very alley-ly.  The alleys are narrow, winding and difficult to navigate safely without a map.",
    "You are standing in a small winding alleyway.  There are other alleys leading off it.  They are all small and winding too.  The walls are too high to see over, and buildings block your view in all directions.  A person could easily get lost in here unless they had a good memory, or a map.",
    "This is a cross alleyways.  Like a cross-roads, but with alleyways.  They go this way and that.  You can't work out which way is north and you wish you'd brought a compass.",
    "At least at this point in the maze your decision is simple.  Either go that way, or that way.  The alleyway simply bends here, and you can continue or go back.  It's entirely up to you.",
    "You are standing in a small winding alleyway.  There are other alleys leading off it.  They are all small and winding too.  The walls are too high to see over, and buildings block your view in all directions.  A person could easily get lost in here unless they had a good memory, or a map.",
    "In the heart of the Red Triangle maze, alleys lead in all directions, and you are unsure which way to turn.  Six alleys meet here, or possibly, depending on your point of view leave from here.  Either way, there are a lot of possible exits.",
    "Three alleyways merge here.  They all look the same, and all go in different directions.  Small buildings line the alleyways.  The exit ahead of you looks familiar, or does it\\?",
    "Isn't this the same place you were in 5 minutes ago\\?  Maybe not.  But perhaps it is, who knows\\?  The alleyway bends here and you have a choice of two identical exits.",
    "As an Empire the Aurient is complex and easy to get lost in.  This set of alleyways could easily be a metaphor for the whole of Agatea.  They are complex and, you've guessed it, easy to get lost in.",
    "You are standing in a small winding alleyway.  There are other alleys leading off it.  They are all small and winding too.  The walls are too high to see over, and buildings block your view in all directions.  A person could easily get lost in here unless they had a good memory, or a map.",
    "You are standing in a small winding alleyway.  There are other alleys leading off it.  They are all small and winding too.  The walls are too high to see over, and buildings block your view in all directions.  A person could easily get lost in here unless they had a good memory, or a map.",
    "You are standing in a small winding alleyway.  There are other alleys leading off it.  They are all small and winding too.  The alley leads north and south.  Or is it east and west\\?  You are completely unsure.",
    "The alleys twist and turn, until you eventually arrive here.  Here is nowhere special, just another junction within the maze of alleys in the Red Triangle.",
    "This is a small winding alleyway, dark and with other alleys leading off it.  They are all small and winding too.  The walls are too high to see over, and buildings block your view in all directions.  A person could easily get lost in here unless they had a good memory, or a map.",
}

Config.NUMBER_WORDS = {
    the = 1, two = 2, three = 3, four = 4, five = 5, six = 6, seven = 7,
    eight = 8, nine = 9, ten = 10, eleven = 11, twelve = 12, thirteen = 13,
    fourteen = 14, fifteen = 15, sixteen = 16, seventeen = 17, eighteen = 18,
    nineteen = 19, twenty = 20, many = 21,
}

return Config
