# Player sprite

`player_sheet_80x64.png` contains two animation rows with eight frames each:

- row 0: running, 10 FPS;
- row 1: idle, 5 FPS.

Each frame is 80x64 pixels. The character faces right in the source frames;
the game rotates the `Sprite2D` toward the mouse cursor. The frame pivot is
aligned to the character's body rather than the center of the long weapon.

The original generated chroma-key image is retained at
`source/player_sheet_chroma.png`.
