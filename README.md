# Far Signal

Minimal top-down 2D maze prototype for Godot 4.

## Run

1. Open this directory in Godot 4.
2. Run the project with `F6`/`F5`.

Controls:

- `WASD` or arrow keys: move
- `Tab`: open or close the explored map
- `Esc`: close the map
- Mouse wheel: zoom the map
- `R`: restart
- `Ctrl+Q`: quit

The maze, player position, and signal position are randomized on every run.
The signal is placed at least 20 corridor steps from the player when possible.
Extra connections are opened after generation, creating loops and alternate
routes through parts of the maze. Most corridors are two cells wide while
roughly 35% of connections narrow to one cell; walls remain one cell thick.
All visuals are drawn with Godot primitives; there are no textures or tile
sets. The camera keeps the player centered, and only the current straight
corridors and their adjacent walls are visible.
