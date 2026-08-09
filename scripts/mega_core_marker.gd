extends Node2D

const ANIMATION_FRAME_COUNT := 8
const ANIMATION_FPS := 5.0
const MAP_MARKER_PATH_COLOR := Color(1.0, 1.0, 1.0, 0.58)
const MAP_MARKER_PATH_WIDTH := 3.0

var maze: Maze
var player: Player
var game: Node
var _animation_time := 0.0
var _mega_core_sprites: Array[Sprite2D] = []

@onready var mega_core_sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_mega_core_sprites.append(mega_core_sprite)
	for index in range(1, Player.MEGA_CORE_LEVEL_COUNT):
		var sprite := mega_core_sprite.duplicate() as Sprite2D
		add_child(sprite)
		_mega_core_sprites.append(sprite)


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
	if player == null or maze == null:
		for sprite in _mega_core_sprites:
			sprite.visible = false
		return
	_animation_time += delta
	var frame := posmod(
		floori(_animation_time * ANIMATION_FPS),
		ANIMATION_FRAME_COUNT
	)
	for index in _mega_core_sprites.size():
		var cell := player.mega_core_cell_for_level(index + 1)
		var sprite := _mega_core_sprites[index]
		sprite.visible = cell.x >= 0 and maze.is_cell_visible(cell)
		if sprite.visible:
			sprite.position = maze.cell_to_world(cell)
			sprite.frame = frame


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
