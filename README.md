# Far Signal

Minimal top-down 2D maze prototype for Godot 4.

## Run

1. Open this directory in Godot 4.
2. Run the project with `F6`/`F5`.

The project starts at the main menu. Select `Новая игра` to generate and enter
the maze.

Controls:

- `WASD` or arrow keys: move
- `Tab`: open or close the explored map
- Mouse wheel: zoom the map
- `Esc`: pause or return from the controls screen

`Сохранить и выйти` writes `far_signal_save.json` next to the exported game
binary. When running from the editor, the file is written to the project root.
When this file exists, the main menu shows `Продолжить`. Starting a new game
deletes the previous save.

The 500 by 1000 cell maze is randomized on every run.
The player starts in a random floor cell along the bottom of the maze.
Extra connections are opened after generation, creating loops and alternate
routes through parts of the maze. Most corridors are two cells wide while
roughly 35% of connections narrow to one cell; walls remain one cell thick.
All visuals are drawn with Godot primitives; there are no textures or tile
sets. The camera keeps the player centered, and only the current straight
corridors and their adjacent walls are visible.
