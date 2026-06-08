extends Control

const MAP_CELL_SIZE := 40.0
const SCROLL_SPEED := 420.0
const MAP_MARGIN := 80.0
const BACKGROUND_COLOR := Color("07101d")
const FRAME_COLOR := Color("6f8eaa")
const TEXT_COLOR := Color("d8e7f5")

@onready var maze: Maze = $"../../Maze"
@onready var player: Player = $"../../Player"
@onready var map_content: Control = $MapViewport/MapContent

var _scroll_position := Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	resized.connect(_on_resized)
	map_content.setup(maze, player, MAP_CELL_SIZE)


func _exit_tree() -> void:
	if get_tree().paused:
		get_tree().paused = false


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("toggle_map"):
		if visible:
			_close_map()
		else:
			_open_map()
		return

	if not visible:
		return

	if Input.is_action_just_pressed("close_map"):
		_close_map()
		return

	if Input.is_action_just_pressed("quit_game"):
		get_tree().quit()
		return

	var scroll_direction := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)
	scroll_direction += Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	scroll_direction = scroll_direction.limit_length()

	if not scroll_direction.is_zero_approx():
		_scroll_position += scroll_direction * SCROLL_SPEED * delta
		_clamp_scroll_position()
		_update_map_content()


func _open_map() -> void:
	var player_cell := maze.world_to_cell(player.position)
	_scroll_position = (Vector2(player_cell) + Vector2.ONE * 0.5) * MAP_CELL_SIZE
	_clamp_scroll_position()
	visible = true
	get_tree().paused = true
	_update_map_content()
	queue_redraw()


func _close_map() -> void:
	visible = false
	get_tree().paused = false


func _map_rect() -> Rect2:
	return $MapViewport.get_rect()


func _clamp_scroll_position() -> void:
	var map_rect := _map_rect()
	var map_size := Vector2(maze.grid_size()) * MAP_CELL_SIZE
	var half_view := map_rect.size * 0.5

	for axis in 2:
		if map_size[axis] <= map_rect.size[axis]:
			_scroll_position[axis] = map_size[axis] * 0.5
		else:
			_scroll_position[axis] = clampf(
				_scroll_position[axis],
				half_view[axis],
				map_size[axis] - half_view[axis]
			)


func _update_map_content() -> void:
	map_content.scroll_position = _scroll_position
	map_content.queue_redraw()


func _on_resized() -> void:
	_clamp_scroll_position()
	_update_map_content()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND_COLOR)

	var map_rect := _map_rect()
	draw_rect(map_rect, FRAME_COLOR, false, 2.0)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(MAP_MARGIN, 48.0),
		"MAP    WASD / arrows - scroll    M / Esc - close",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		20,
		TEXT_COLOR
	)
