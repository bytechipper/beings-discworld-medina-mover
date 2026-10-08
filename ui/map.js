const TITLE_HEIGHT = 16;
const COMPASS_ORDER = { n: 1, ne: 2, e: 3, se: 4, s: 5, sw: 6, w: 7, nw: 8 };
const DIR_OFFSETS = {
    n:  { x: 0, y: -1 }, ne: { x: 1, y: -1 }, e:  { x: 1, y: 0 },
    se: { x: 1, y: 1 },  s:  { x: 0, y: 1 },  sw: { x: -1, y: 1 },
    w:  { x: -1, y: 0 }, nw: { x: -1, y: -1 }
};

let state = null;
let canvas = null;
let ctx = null;
let dimensions = null;
let coordinates = {};
let arrowImages = {};
let arrowSet = "default";
let isDragging = false;
let isResizing = false;
let dragStart = { x: 0, y: 0 };
let resizeStart = { w: 0, h: 0 };
let hoveredExit = null;
let contextMenu = null;

function getComputedColor(varName, fallback) {
    const el = document.documentElement;
    const val = getComputedStyle(el).getPropertyValue(varName).trim();
    return val || fallback;
}

function hexToRgba(hex, alpha) {
    if (!hex || hex.length < 4) return `rgba(0,0,0,${alpha || 1})`;
    hex = hex.replace("#", "");
    if (hex.length === 3) hex = hex[0]+hex[0]+hex[1]+hex[1]+hex[2]+hex[2];
    const r = parseInt(hex.substr(0, 2), 16);
    const g = parseInt(hex.substr(2, 2), 16);
    const b = parseInt(hex.substr(4, 2), 16);
    return `rgba(${r},${g},${b},${alpha || 1})`;
}

function computeDimensions(windowSize) {
    const w = windowSize || 300;
    const buffer = { x: w * 0.05, y: w * 0.05 };
    const map = { x: w - buffer.x * 2, y: w - buffer.y * 2 };
    const block = { x: map.x / 6, y: map.y / 6 };
    const room = { x: block.x * 0.5, y: block.y * 0.5 };
    const exit = { x: (block.x - room.x) / 2, y: (block.y - room.y) / 2 };
    return { window: { x: w, y: w }, buffer, map, block, room, exit };
}

function computeCoordinates(rooms, dim, roomCharSize) {
    const coords = { rooms: {}, titleText: {}, exitText: {} };
    coords.titleText.y1 = ((roomCharSize * 1.1) - roomCharSize) / 2;
    coords.exitText.y1 = dim.buffer.y + dim.block.y * 5.5;

    for (const [letter, room] of Object.entries(rooms)) {
        const loc = room.location;
        const roomCenter = {
            x: dim.buffer.x + (loc.x * dim.block.x) - (dim.block.x / 2),
            y: dim.buffer.y + (loc.y * dim.block.y)
        };

        const outer = {
            x1: roomCenter.x - (dim.room.x / 2),
            y1: roomCenter.y - (dim.room.y / 2),
            x2: roomCenter.x + (dim.room.x / 2),
            y2: roomCenter.y + (dim.room.y / 2)
        };

        const inner = {
            x1: roomCenter.x - ((dim.room.x * 0.75) / 2),
            y1: roomCenter.y - ((dim.room.y * 0.75) / 2),
            x2: roomCenter.x + ((dim.room.x * 0.75) / 2),
            y2: roomCenter.y + ((dim.room.y * 0.75) / 2)
        };

        const exitCoords = {};
        if (room.normalized) {
            for (const [dir, mapped] of Object.entries(room.normalized)) {
                const off = DIR_OFFSETS[dir];
                if (!off) continue;
                const ec = {
                    x: roomCenter.x + ((dim.room.x + dim.exit.x) / 2) * off.x,
                    y: roomCenter.y + ((dim.room.y + dim.exit.y) / 2) * -off.y
                };
                exitCoords[dir] = {
                    x1: ec.x - dim.exit.x / 2,
                    y1: ec.y - dim.exit.y / 2,
                    x2: ec.x + dim.exit.x / 2,
                    y2: ec.y + dim.exit.y / 2
                };
            }
        }

        const letterWidth = ctx.measureText(letter).width;
        const letterCoords = {
            x1: roomCenter.x - (dim.room.x / 2) + (dim.room.x - letterWidth) / 2,
            y1: roomCenter.y - (dim.room.y / 2) + (dim.room.y - roomCharSize) / 2
        };

        coords.rooms[letter] = { room: { outer, inner }, exit: exitCoords, letter: letterCoords };
    }
    return coords;
}

function loadArrowImages(arrowSet, dim, callback) {
    const dirs = ["n", "ne", "e", "se", "s", "sw", "w", "nw"];
    let loaded = 0;
    arrowImages = {};

    for (const dir of dirs) {
        const img = new Image();
        img.onload = function() {
            arrowImages[dir] = img;
            loaded++;
            if (loaded === dirs.length && callback) callback();
        };
        img.onerror = function() {
            loaded++;
            if (loaded === dirs.length && callback) callback();
        };
        img.src = `../assets/arrows-${arrowSet}/${dir}.png`;
    }
}

function drawRect(x1, y1, x2, y2, fillColor, strokeColor, lineWidth) {
    if (fillColor) {
        ctx.fillStyle = fillColor;
        ctx.fillRect(x1, y1, x2 - x1, y2 - y1);
    }
    if (strokeColor) {
        ctx.strokeStyle = strokeColor;
        ctx.lineWidth = lineWidth || 1;
        ctx.strokeRect(x1, y1, x2 - x1, y2 - y1);
    }
}

function drawText(text, x, y, color, font, align) {
    ctx.fillStyle = color || "#ffffff";
    ctx.font = font || "10px monospace";
    ctx.textAlign = align || "center";
    ctx.textBaseline = "middle";
    ctx.fillText(text, x, y);
}

function drawImage(img, x1, y1, x2, y2) {
    if (!img) return;
    const w = x2 - x1;
    const h = y2 - y1;
    if (w <= 0 || h <= 0) return;
    ctx.drawImage(img, x1, y1, w, h);
}

function getColors() {
    return {
        windowBorder: getComputedColor("--mallard-border", "#3a3a5c"),
        windowBg: getComputedColor("--mallard-bg", "#1a1a2e"),
        transparency: "transparent",
        titlebarFill1: getComputedColor("--mallard-bg-elevated", "#252540"),
        titlebarFill2: getComputedColor("--mallard-bg", "#1a1a2e"),
        titlebarText: getComputedColor("--mallard-fg", "#e0e0e0"),
        roomBg: getComputedColor("--mallard-bg-elevated", "#252540"),
        roomBorder: getComputedColor("--mallard-accent", "#4a9eff"),
        roomBorderUnsolved: "#ff4444",
        roomTextVisited: getComputedColor("--mallard-fg-muted", "#888888"),
        roomTextUnvisited: "#6688cc",
        exitBg: getComputedColor("--mallard-bg-elevated", "#252540"),
        exitBorder: getComputedColor("--mallard-accent", "#4a9eff"),
        exitBorderUnsolved: "#ff4444",
        exitLineEntrance: getComputedColor("--mallard-fg-subtle", "#555555"),
        roomInnerFillYou: "#ffff00",
        roomInnerFillLook: "#ffffff",
        roomInnerFillScry: "#ffffff",
        roomBorderLook: "#ffffff",
        roomBorderScry: "#aaaaaa",
        roomBorderTrajectory: "#ffff00",
        roomBorderExitSet: "#6688cc",
        roomInnerFillBoss: "#ff69b4",
        roomInnerFillXP: ["#1a1a1a", "#0d330d", "#1a4d1a", "#266626", "#339933", "#40cc40", "#66ff66", "#80ff80", "#99ff99", "#ccffcc"],
        roomTextPlayer: "#ffffff",
        roomTextXP: ["#666666", "#555555", "#444444", "#333333"],
        pathText: getComputedColor("--mallard-fg-muted", "#888888"),
        exitTextBracket: getComputedColor("--mallard-fg-subtle", "#555555"),
        exitTextComma: getComputedColor("--mallard-fg-subtle", "#555555"),
        exitTextHalfSolved: "#ccaa44",
    };
}

function drawBaseLayer(state, dim, coords, colors) {
    drawRect(0, 0, dim.window.x, dim.window.y, colors.windowBg, colors.windowBorder, 1);

    ctx.setLineDash([2, 2]);
    ctx.strokeStyle = colors.exitLineEntrance;
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(0, dim.block.y / 2);
    ctx.lineTo(dim.buffer.x, dim.buffer.y + (dim.block.y / 2));
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo((dim.block.x * 6) + dim.buffer.x, (dim.block.y * 5.5) + dim.buffer.y);
    ctx.lineTo(dim.window.x, dim.window.y - (dim.block.y / 2));
    ctx.stroke();
    ctx.setLineDash([]);

    const grad = ctx.createLinearGradient(0, 0, 0, TITLE_HEIGHT);
    grad.addColorStop(0, colors.titlebarFill1);
    grad.addColorStop(1, colors.titlebarFill2);
    drawRect(0, 0, dim.window.x, TITLE_HEIGHT, grad, colors.windowBorder, 1);

    drawText("Medina", dim.window.x / 2, TITLE_HEIGHT / 2, colors.titlebarText, "bold 11px sans-serif", "center");

    for (const [letter, roomCoord] of Object.entries(coords.rooms)) {
        const roomData = state.rooms[letter];
        if (!roomData) continue;

        const borderColor = roomData.solved ? colors.roomBorder : colors.roomBorderUnsolved;
        const r = roomCoord.room.outer;
        drawRect(r.x1, r.y1, r.x2, r.y2, colors.roomBg, borderColor, 1);

        if (roomData.normalized) {
            for (const [dir, mapped] of Object.entries(roomData.normalized)) {
                const ec = roomCoord.exit[dir];
                if (!ec) continue;
                const ebc = mapped ? colors.exitBorder : colors.exitBorderUnsolved;
                const ebg = mapped ? colors.exitBg : colors.exitBg;
                drawRect(ec.x1, ec.y1, ec.x2, ec.y2, ebg, ebc, 1);
                if (mapped && arrowImages[dir]) {
                    drawImage(arrowImages[dir], ec.x1 + 2, ec.y1 + 2, ec.x2 - 2, ec.y2 - 2);
                }
            }
        }
    }
}

function drawDynamicLayer(state, dim, coords, colors) {
    const currentRoom = state.current_room || [];
    const lookRoom = state.look_room || [];
    const scryRoom = state.scry_room || [];
    const trajectoryRoom = state.trajectory_room || [];
    const herdPath = state.herd_path || {};

    function drawLook(rooms, fillColor, borderColor) {
        if (!rooms || rooms.length === 0) return;
        for (const r of rooms) {
            const rc = coords.rooms[r];
            if (!rc) continue;
            const outer = rc.room.outer;
            drawRect(outer.x1, outer.y1, outer.x2, outer.y2, fillColor, borderColor, 1);
        }
    }

    function drawThyng(rooms, fillColor) {
        if (!rooms || rooms.length === 0) return;
        const isUncertain = rooms.length > 1;
        for (const r of rooms) {
            const rc = coords.rooms[r];
            if (!rc) continue;
            const inner = rc.room.inner;
            drawRect(inner.x1, inner.y1, inner.x2, inner.y2, fillColor, fillColor, 1);
        }
    }

    function drawBorder(rooms, borderColor) {
        if (!rooms || rooms.length === 0) return;
        for (const r of rooms) {
            const rc = coords.rooms[r];
            if (!rc) continue;
            const outer = rc.room.outer;
            drawRect(outer.x1, outer.y1, outer.x2, outer.y2, null, borderColor, 1);
        }
    }

    function drawPopulation() {
        for (const [letter, room] of Object.entries(state.rooms)) {
            const rc = coords.rooms[letter];
            if (!rc) continue;

            let playerRoom = false;
            let roomColor = null;

            if (room.thyngs && room.thyngs.players) {
                for (const [p, c] of Object.entries(room.thyngs.players)) {
                    playerRoom = true;
                    roomColor = c;
                    break;
                }
            }

            if (!roomColor && room.thyngs && room.thyngs.mobs && room.thyngs.mobs.boss > 0) {
                roomColor = colors.roomInnerFillBoss;
            }

            if (!roomColor && room.thyngs && room.thyngs.mobs) {
                const xp = (room.thyngs.mobs.thugs || 0) + 2 * (room.thyngs.mobs.heavies || 0);
                if (xp > 0) {
                    const idx = Math.min(xp, colors.roomInnerFillXP.length - 1);
                    roomColor = colors.roomInnerFillXP[idx];
                }
            }

            if (roomColor) {
                drawThyng([letter], roomColor);
            }
        }
    }

    function drawHerdPath() {
        for (const [startRoom, dir] of Object.entries(herdPath)) {
            let herdRoom = startRoom;
            let breakAt = 100;
            while (state.rooms[herdRoom] && state.rooms[herdRoom].exits &&
                   state.rooms[herdRoom].exits[dir] && state.rooms[herdRoom].exits[dir].room) {
                const previousRoom = herdRoom;
                herdRoom = state.rooms[herdRoom].exits[dir].room;
                if (!herdRoom) break;
                const rc = coords.rooms[herdRoom];
                if (rc) {
                    drawBorder([herdRoom], colors.roomBorderExitSet);
                }
                breakAt--;
                if (breakAt <= 0) break;
            }
        }
    }

    drawLook(lookRoom, colors.roomInnerFillLook, colors.roomBorderLook);
    drawLook(scryRoom, colors.roomInnerFillScry, colors.roomBorderScry);
    drawPopulation();
    drawThyng(currentRoom, colors.roomInnerFillYou);
    drawHerdPath();
    drawBorder(trajectoryRoom, colors.roomBorderTrajectory);
}

function drawExitText(state, dim, coords, colors) {
    if (!state.current_room || state.current_room.length === 0) return;

    const isAbsolute = state.current_room.length === 1;
    const currentLetter = isAbsolute ? state.current_room[0] : null;

    const directions = ["n", "ne", "e", "se", "s", "sw", "w", "nw"];
    const unsolvedExits = [];

    if (currentLetter && state.rooms[currentLetter] && state.rooms[currentLetter].exits) {
        for (const dir of directions) {
            if (currentLetter === "A" && dir === "nw") continue;
            if (currentLetter === "R" && dir === "se") continue;
            const exitData = state.rooms[currentLetter].exits[dir];
            if (!exitData || !exitData.room) {
                unsolvedExits.push(dir);
            }
        }
    }

    if (unsolvedExits.length === 0) return;

    let text = "[" + unsolvedExits.join(", ") + "]";
    const textWidth = ctx.measureText(text).width;
    const x1 = (dim.window.x - textWidth) / 2;
    const y1 = coords.exitText.y1;
    const y2 = y1 + (dim.block ? dim.block.x * 0.15 : 10);

    let xPos = x1;
    ctx.fillStyle = colors.exitTextBracket;
    ctx.font = `${Math.max(9, dim.exit.x * 0.6)}px monospace`;
    ctx.textBaseline = "middle";

    ctx.fillText("[", xPos, (y1 + y2) / 2);
    xPos += ctx.measureText("[").width;

    for (let i = 0; i < unsolvedExits.length; i++) {
        const dir = unsolvedExits[i];
        const isHalfSolved = currentLetter && state.rooms[currentLetter].exits &&
            state.rooms[currentLetter].exits[dir] && state.rooms[currentLetter].exits[dir].exits;
        const color = isHalfSolved ? colors.exitTextHalfSolved : colors.roomBorderUnsolved;

        ctx.fillStyle = color;
        ctx.fillText(dir, xPos, (y1 + y2) / 2);
        xPos += ctx.measureText(dir).width;

        if (i < unsolvedExits.length - 1) {
            ctx.fillStyle = colors.exitTextComma;
            ctx.fillText(", ", xPos, (y1 + y2) / 2);
            xPos += ctx.measureText(", ").width;
        }
    }

    ctx.fillStyle = colors.exitTextBracket;
    ctx.fillText("]", xPos, (y1 + y2) / 2);
}

function drawRoomLetters(state, coords, colors) {
    for (const [letter, roomCoord] of Object.entries(coords.rooms)) {
        const roomData = state.rooms[letter];
        if (!roomData) continue;
        const color = roomData.visited ? colors.roomTextVisited : colors.roomTextUnvisited;
        const l = roomCoord.letter;
        drawText(letter, l.x1 + ctx.measureText(letter).width / 2, l.y1, color, "bold 10px monospace", "center");
    }
}

function render() {
    if (!canvas || !ctx || !state || !state.rooms) return;

    const windowSize = state.window_size || 300;
    canvas.width = windowSize;
    canvas.height = windowSize;

    dimensions = computeDimensions(windowSize);

    ctx.font = "bold 10px monospace";
    coordinates = computeCoordinates(state.rooms, dimensions, 10);

    const colors = getColors();

    ctx.clearRect(0, 0, canvas.width, canvas.height);

    drawBaseLayer(state, dimensions, coordinates, colors);
    drawDynamicLayer(state, dimensions, coordinates, colors);
    drawRoomLetters(state, coordinates, colors);
    drawExitText(state, dimensions, coordinates, colors);
}

function getRoomAtPosition(x, y) {
    if (!coordinates.rooms) return null;
    for (const [letter, coord] of Object.entries(coordinates.rooms)) {
        const r = coord.room.outer;
        if (x >= r.x1 && x <= r.x2 && y >= r.y1 && y <= r.y2) {
            return letter;
        }
    }
    return null;
}

function getExitAtPosition(x, y) {
    if (!coordinates.rooms || !state || !state.current_room) return null;
    const currentLetter = state.current_room.length === 1 ? state.current_room[0] : null;
    if (!currentLetter) return null;
    const coord = coordinates.rooms[currentLetter];
    if (!coord) return null;
    for (const [dir, ec] of Object.entries(coord.exit)) {
        if (x >= ec.x1 && x <= ec.x2 && y >= ec.y1 && y <= ec.y2) {
            return dir;
        }
    }
    return null;
}

function isTitlebar(y) {
    return y < TITLE_HEIGHT;
}

function isResizeCorner(x, y) {
    if (!dimensions) return false;
    const threshold = 12;
    return x > dimensions.window.x - threshold && y > dimensions.window.y - threshold;
}

function initCanvas() {
    canvas = document.getElementById("map-canvas");
    ctx = canvas.getContext("2d");
    contextMenu = document.getElementById("context-menu");

    loadArrowImages(arrowSet, null, null);

    canvas.addEventListener("mousedown", function(e) {
        const rect = canvas.getBoundingClientRect();
        const x = e.clientX - rect.left;
        const y = e.clientY - rect.top;

        if (e.button === 2) {
            e.preventDefault();
            const room = getRoomAtPosition(x, y);
            if (room) {
                showContextMenu(e.clientX, e.clientY, room);
            } else if (isTitlebar(y)) {
                showTitleContextMenu(e.clientX, e.clientY);
            }
            return;
        }

        if (e.button === 0) {
            if (isResizeCorner(x, y)) {
                isResizing = true;
                resizeStart = { w: canvas.width, h: canvas.height };
                dragStart = { x: e.clientX, y: e.clientY };
                return;
            }

            if (isTitlebar(y)) {
                isDragging = true;
                dragStart = { x: e.clientX, y: e.clientY };
                return;
            }

            const exit = getExitAtPosition(x, y);
            if (exit) {
                window.panel.post("exit_click", { direction: exit });
                return;
            }

            const room = getRoomAtPosition(x, y);
            if (room) {
                window.panel.post("room_click", { room: room });
                return;
            }
        }
    });

    canvas.addEventListener("mousemove", function(e) {
        const rect = canvas.getBoundingClientRect();
        const x = e.clientX - rect.left;
        const y = e.clientY - rect.top;

        if (isResizing) {
            const dx = e.clientX - dragStart.x;
            const newSize = Math.max(300, Math.round(resizeStart.w + dx));
            if (newSize !== canvas.width) {
                canvas.width = newSize;
                canvas.height = newSize;
                dimensions = computeDimensions(newSize);
                ctx.font = "bold 10px monospace";
                coordinates = computeCoordinates(state.rooms, dimensions, 10);
                render();
            }
            return;
        }

        if (isTitlebar(y)) {
            canvas.style.cursor = "move";
        } else if (isResizeCorner(x, y)) {
            canvas.style.cursor = "se-resize";
        } else {
            const exit = getExitAtPosition(x, y);
            const room = getRoomAtPosition(x, y);
            if (exit) canvas.style.cursor = "pointer";
            else if (room) canvas.style.cursor = "pointer";
            else canvas.style.cursor = "default";
        }
    });

    canvas.addEventListener("mouseup", function(e) {
        if (isResizing) {
            isResizing = false;
            if (state) {
                state.window_size = canvas.width;
            }
            return;
        }
        if (isDragging) {
            isDragging = false;
            return;
        }
    });

    canvas.addEventListener("mouseleave", function() {
        isDragging = false;
        isResizing = false;
    });

    canvas.addEventListener("contextmenu", function(e) {
        e.preventDefault();
    });

    document.addEventListener("click", function(e) {
        if (contextMenu && !contextMenu.contains(e.target)) {
            contextMenu.classList.add("hidden");
        }
    });

    document.addEventListener("keydown", function(e) {
        if (e.key === "Escape" && contextMenu) {
            contextMenu.classList.add("hidden");
        }
    });

    window.panel.post("ready", {});
}

function showContextMenu(x, y, room) {
    if (!contextMenu) return;
    contextMenu.innerHTML = "";
    const items = [
        { label: "Look", action: "look_room", room: room },
        { label: "Reset Room", action: "reset_room", room: room },
        { label: "Path Here", action: "room_click", room: room },
    ];
    for (const item of items) {
        const div = document.createElement("div");
        div.className = "menu-item";
        div.textContent = item.label;
        div.addEventListener("click", function() {
            contextMenu.classList.add("hidden");
            if (item.action === "room_click") {
                window.panel.post("room_click", { room: item.room });
            } else if (item.action === "look_room") {
                const dirs = ["n", "ne", "e", "se", "s", "sw", "w", "nw"];
                for (const d of dirs) {
                    if (state.rooms[item.room] && state.rooms[item.room].exit_rooms) {
                        for (const [adj, staticDir] of Object.entries(state.rooms[item.room].exit_rooms)) {
                            if (adj === item.room) continue;
                        }
                    }
                }
            } else if (item.action === "reset_room") {
                window.panel.post("menu_action", { action: "reset_room", room: item.room });
            }
        });
        contextMenu.appendChild(div);
    }
    contextMenu.style.left = x + "px";
    contextMenu.style.top = y + "px";
    contextMenu.classList.remove("hidden");
}

function showTitleContextMenu(x, y) {
    if (!contextMenu) return;
    contextMenu.innerHTML = "";
    const items = [
        { label: "Help", action: "help" },
        { label: "Reset Map", action: "reset" },
        { label: "Reset Current Room", action: "reset_room" },
    ];
    for (const item of items) {
        const div = document.createElement("div");
        div.className = "menu-item";
        div.textContent = item.label;
        div.addEventListener("click", function() {
            contextMenu.classList.add("hidden");
            window.panel.post("menu_action", { action: item.action });
        });
        contextMenu.appendChild(div);
    }
    contextMenu.style.left = x + "px";
    contextMenu.style.top = y + "px";
    contextMenu.classList.remove("hidden");
}

window.panel.on("state", function(data) {
    const oldArrowSet = state ? state.arrow_set : null;
    state = data;

    if (data.arrow_set && data.arrow_set !== oldArrowSet) {
        arrowSet = data.arrow_set;
        loadArrowImages(arrowSet, null, function() { render(); });
    } else {
        render();
    }
});

document.addEventListener("DOMContentLoaded", initCanvas);
