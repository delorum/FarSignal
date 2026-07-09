extends Node2D

const MARKER_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const MARKER_RADIUS := Maze.CELL_SIZE * 0.28

var maze: Maze
var player: Player


func setup(maze_node: Maze, player_node: Player) -> void:
	maze = maze_node
	player = player_node
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if player == null \
			or maze == null \
			or player.has_mega_core \
			or player.mega_core_cell.x < 0 \
			or not maze.is_cell_visible(player.mega_core_cell):
		return

	var center := maze.cell_to_world(player.mega_core_cell)
	var points := PackedVector2Array([
		center + Vector2(0.0, -MARKER_RADIUS),
		center + Vector2(MARKER_RADIUS, 0.0),
		center + Vector2(0.0, MARKER_RADIUS),
		center + Vector2(-MARKER_RADIUS, 0.0),
		center + Vector2(0.0, -MARKER_RADIUS),
	])
	draw_polyline(points, MARKER_COLOR, 3.0, true)
