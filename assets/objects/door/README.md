# Door sprite

`door_sheet_48.png` contains eight 48x48 frames in one row. Frame 0 is fully
closed and frame 7 is fully open. Opening plays the frames forward; closing
plays them backward.

The source orientation is for a horizontal passage. The game rotates the
sprite by 90 degrees for a vertical passage.

The original generated chroma-key image is retained at
`source/door_sheet_chroma.png`.
