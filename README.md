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
- `E`: open or close a nearby door, interact with a station
- `Tab`: open or close the explored map
- Mouse wheel: zoom the map
- `Esc`: pause or return from the controls screen

`Сохранить и выйти` writes `far_signal_save.json` next to the exported game
binary. When running from the editor, the file is written to the project root.
When this file exists, the main menu shows `Продолжить`. Starting a new game
deletes the previous save.

The 200 by 200 cell maze is randomized on every run.
Its dimensions are controlled by `COLUMNS` and `ROWS` in `scripts/maze.gd`;
the internal generation grid is derived automatically.
The player starts in a random floor cell along the bottom of the maze.
Five armed enemies patrol the entire maze. Moving can be heard within 20
cells after about two cells of continuous movement; stopping drains the noise
meter in about one second. Firing immediately fills the noise meter and
attracts enemies within 30 cells. The HUD shows only the distance band of the
nearest living enemy, without revealing its direction.
The maze contains one station room with four doors. Its central machine
restores health and ammunition. The HUD signal meter has a range of 100 cells.
Extra connections are opened after generation, creating loops and alternate
routes through parts of the maze. Most corridors are two cells wide while
roughly 35% of connections narrow to one cell; walls remain one cell thick.
All visuals are drawn with Godot primitives; there are no textures or tile
sets. The camera keeps the player centered, and only the current straight
corridors and their adjacent walls are visible.
