# Far Signal

Minimal top-down 2D maze prototype for Godot 4.

Exported builds start in borderless fullscreen mode. The gameplay viewport,
camera offset, and right HUD panel adapt to the screen resolution. Debug runs
also use fullscreen when the editor is configured to launch the game in a
separate window. Embedded runs remain limited to the editor's Game panel.

## Run

1. Open this directory in Godot 4.
2. Run the project with `F6`/`F5`.

The project starts at the main menu. Select `Новая игра` to generate and enter
the maze. A short story screen introduces the expedition before a new game.

Controls:

- `WASD` or arrow keys: move
- Left mouse button: fire one bullet
- Right mouse button: place or remove a door in the cell under the cursor
- Left Shift: toggle ambush mode
- `E`: open or close a nearby door, interact with a station
- `Tab`: open or close the explored map
- Mouse wheel: zoom the map
- Right mouse button on the map: set or clear a route destination
- `Esc`: pause or return from the controls screen

`Сохранить и выйти` writes `far_signal_save.json` next to the exported game
binary. When running from the editor, the file is written to the project root.
When this file exists, the main menu shows `Продолжить`. Starting a new game
deletes the previous save.

The 200 by 200 cell maze is randomized on every run.
Its dimensions are controlled by `COLUMNS` and `ROWS` in `scripts/maze.gd`;
the internal generation grid is derived automatically.
The player starts in a random floor cell along the bottom of the maze.
Ten armed enemies patrol the entire maze. When one is killed, a replacement
spawns elsewhere outside the station and away from the player. After firing,
enemies have a 40% chance to change position before taking another shot.
Moving can be heard within 20
cells after about two cells of continuous movement; stopping drains the noise
meter in about one second. Firing immediately fills the noise meter and
attracts enemies within 30 cells. The HUD shows only the distance band of the
nearest living enemy. Audible enemies are indicated by arrows around the
player: gray while patrolling and red after they become alerted.
Ambush mode suppresses movement noise. Audible living enemies remain marked
by direction arrows around the player and also appear as facing-direction
arrows in the game world and on the map. Firing leaves ambush mode and can
still alert enemies.
The player starts inside a station room built into the bottom maze boundary.
The exterior door behind the player is permanently locked; the player faces
up into the room, and the other three doors can be opened normally. The
station's central machine restores health and ammunition.
Player-built doors can enclose parts of the maze. A separated floor component
that touches a station door is marked as a safe zone in green in the game and
on the map. Safety also propagates through doors to adjacent enclosed
components without crossing the main open maze. Enemies never spawn inside
safe zones. The zone topology is recalculated only when a door is placed,
removed, or restored from a save.
The map can plot a route to a previously explored floor cell. Routes use only
known floor cells, may pass through doors regardless of their current state,
and refresh from the player's current position every five seconds.
Extra connections are opened after generation, creating loops and alternate
routes through parts of the maze. Most corridors are two cells wide while
roughly 35% of connections narrow to one cell; walls remain one cell thick.
The generator also carves rectangular rooms from 4 by 4 to 7 by 7 cells.
Their number scales with the amount of walkable space so that continuous
exploration should reach a room roughly every 30 seconds. Rooms are kept at
least five cells apart so neighboring rooms do not merge into larger spaces.
Generation may place up to 10% fewer rooms when the map has no suitable space.
All visuals are drawn with Godot primitives; there are no textures or tile
sets. The camera keeps the player centered. Visibility is calculated uniformly
for rooms and corridors: cells in front of the player are visible when no wall
or closed door blocks the line of sight, while cells behind the player remain
hidden.
