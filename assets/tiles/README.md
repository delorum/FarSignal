# Environment tiles

`environment/environment_tileset_48.png` is the game-ready 4x4 atlas. Each
tile is 48x48 pixels:

- rows 0-1: floor variants;
- rows 2-3: wall variants.

`environment/environment_tileset.tres` exposes all 16 cells as a Godot
`TileSet` atlas source.

The original generated 1254x1254 image is retained at
`source/environment_tileset_4x4.png`. The game-ready atlas was produced by
splitting the source into 16 regions and resizing each region independently,
which prevents neighboring tiles from bleeding into each other.
