# Far Signal

Minimal top-down 2D maze prototype for Godot 4.

## Run

1. Open this directory in Godot 4.
2. Run the project with `F6`/`F5`.

The project starts at the main menu. Select `Новая игра` to generate and enter
the maze. A short story screen introduces the expedition before a new game.

Controls:

- `WASD` or arrow keys: move
- Left mouse button: fire one bullet
- `E`: open or close a nearby door, interact with a station
- `Tab`: open or close the explored map
- Mouse wheel: zoom the map
- `Esc`: pause or return from the controls screen

`Сохранить и выйти` writes `far_signal_save.json` next to the exported game
binary. When running from the editor, the file is written to the project root.
When this file exists, the main menu shows `Продолжить`. Starting a new game
deletes the previous save.

The 500 by 1000 cell maze is randomized on every run.
The player starts in a random floor cell along the bottom of the maze.
Three armed enemies patrol the starting level. Moving can be heard within 20
cells, while shots attract enemies within 60 cells. The HUD shows only the
distance band of the nearest living enemy, without revealing its direction.
Each 100-cell-high level contains one station room with four doors. Its central
machine restores health and ammunition. The HUD signal meter detects only the
station on the player's current level and has a range of 100 cells.
Extra connections are opened after generation, creating loops and alternate
routes through parts of the maze. Most corridors are two cells wide while
roughly 35% of connections narrow to one cell; walls remain one cell thick.
All visuals are drawn with Godot primitives; there are no textures or tile
sets. The camera keeps the player centered, and only the current straight
corridors and their adjacent walls are visible.
