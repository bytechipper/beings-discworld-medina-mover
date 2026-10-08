# Being's Discworld Medina Mover

Map and navigate the Red Triangle Medina maze, track occupants, and exchange map data with other players.

Requires Mallard 0.27.0 or later; targets Discworld. Install through the marketplace or import the `.mallardx` archive.

Use `/medina help` for commands. Click map rooms to walk, `/medina reset` clears the map, and `/medina sync <player>` shares it.

## Permissions

Sends game commands and group reports. Reads the GMCP packages declared in `plugin.toml`. Stores state in per-world plugin storage. No external network access.

## Development

Run `python3 -m unittest discover -s tests -v` (requires Lua 5.4 shared library). Panel tests require Python Playwright and Chromium. Build with `python3 scripts/build.py`; the reproducible archive includes only the manifest, license, README, runtime source, panel files, and assets.

![Panel preview](docs/panel-preview.png)
