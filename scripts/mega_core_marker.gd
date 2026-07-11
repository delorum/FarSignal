extends Node2D

const ANIMATION_FRAME_COUNT := 8
const ANIMATION_FPS := 5.0
const MAP_MARKER_PATH_COLOR := Color(1.0, 1.0, 1.0, 0.58)
const MAP_MARKER_PATH_WIDTH := 3.0

var maze: Maze
var player: Player
var game: Node
var _animation_time := 0.0

@onready var mega_core_sprite: Sprite2D = $Sprite2D


func setup(maze_node: Maze, player_node: Player, game_node: Node) -> void:
	maze = maze_node
	player = player_node
	game = game_node
	queue_redraw()


func _process(delta: float) -> void:
	_update_mega_core_sprite(delta)
	queue_redraw()


func _draw() -> void:
	_draw_map_marker_path()


func _update_mega_core_sprite(delta: float) -> void:
	var should_show := player != null \
			and maze != null \
			and not player.has_mega_core \
			and player.mega_core_cell.x >= 0 \
			and maze.is_cell_visible(player.mega_core_cell)
	mega_core_sprite.visible = should_show
	if not should_show:
		return

	mega_core_sprite.position = maze.cell_to_world(player.mega_core_cell)
	_animation_time += delta
	mega_core_sprite.frame = posmod(
		floori(_animation_time * ANIMATION_FPS),
		ANIMATION_FRAME_COUNT
	)


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
