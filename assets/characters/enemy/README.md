# Enemy sprite

`enemy_sheet_80x64.png` contains two animation rows with eight frames each:

- row 0: running, 10 FPS;
- row 1: idle, 5 FPS.

Each frame is 80x64 pixels. The source frames face right; the game rotates the
sprite toward the enemy's current facing direction and mirrors it in the left
half-plane.

`fallen_enemy_96x64.png` is the separate sprite used for dead enemies. It is
rotated to their last facing direction and dimmed in the game.

The original generated chroma-key image is retained at
`source/enemy_sheet_chroma.png` and `source/fallen_enemy_chroma.png`.
