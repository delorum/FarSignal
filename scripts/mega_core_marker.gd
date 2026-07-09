extends Node2D

const MARKER_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const MARKER_RADIUS := Maze.CELL_SIZE * 0.28
const MAP_MARKER_PATH_COLOR := Color(1.0, 1.0, 1.0, 0.58)
const MAP_MARKER_PATH_WIDTH := 3.0

var maze: Maze
var player: Player
var game: Node


func setup(maze_node: Maze, player_node: Player, game_node: Node) -> void:
	maze = maze_node
	player = player_node
	game = game_node
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	_draw_map_marker_path()
	_draw_mega_core_marker()


func _draw_mega_core_marker() -> void:
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


func _draw_map_marker_path() -> void:
	if game == null \
			or player == null \
			or maze == null \
			or not game.has_method("map_marker_path"):
		return

	var path: Array[Vector2i] = game.map_marker_path()
	if path.is_empty():
		return

	var points := PackedVector2Array()
	for cell in path:
		points.append(maze.cell_to_world(cell))

	if points.size() >= 2:
		draw_polyline(points, MAP_MARKER_PATH_COLOR, MAP_MARKER_PATH_WIDTH, true)
