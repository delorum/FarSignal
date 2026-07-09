extends Control

const MIN_MAP_CELL_SIZE := 16.0
const SCROLL_SPEED := 420.0
const MAP_MARGIN := 80.0
const BACKGROUND_COLOR := Color("07101d")
const FRAME_COLOR := Color("6f8eaa")
const TEXT_COLOR := Color("d8e7f5")

@onready var maze: Maze = $"../../Maze"
@onready var game: Node = $"../.."
@onready var player: Player = $"../../Player"
@onready var doors: Node2D = $"../../Doors"
@onready var stations: Node2D = $"../../Stations"
@onready var enemies: Node2D = $"../../Enemies"
@onready var pause_menu: Control = $"../../PauseOverlay/PauseMenu"
@onready var station_menu: Control = $"../../StationOverlay/StationMenu"
@onready var defeat_menu: Control = $"../../DefeatOverlay/DefeatMenu"
@onready var victory_menu: Control = $"../../VictoryOverlay/VictoryMenu"
@onready var map_viewport: Control = $MapViewport
@onready var map_content: Control = $MapViewport/MapContent

var _scroll_position := Vector2.ZERO
var _cell_size := MIN_MAP_CELL_SIZE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	resized.connect(_on_resized)
	map_content.setup(game, maze, player, doors, stations, enemies, _cell_size)


func _exit_tree() -> void:
	if get_tree().paused:
		get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		_close_map()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_RIGHT \
			and event.pressed:
		_set_marker_at_mouse()
		get_viewport().set_input_as_handled()
		return


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("toggle_map"):
		if pause_menu.visible \
				or station_menu.visible \
				or defeat_menu.visible \
				or victory_menu.visible:
			return
		if visible:
			_close_map()
		else:
			_open_map()
		return

	if not visible:
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
	_cell_size = MIN_MAP_CELL_SIZE
	var player_cell := maze.world_to_cell(player.position)
	_scroll_position = (Vector2(player_cell) + Vector2.ONE * 0.5) * _cell_size
	_clamp_scroll_position()
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_update_map_content()
	queue_redraw()


func _close_map() -> void:
	visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


func _map_rect() -> Rect2:
	return $MapViewport.get_rect()


func _clamp_scroll_position() -> void:
	var map_rect := _map_rect()
	var map_size := Vector2(maze.grid_size()) * _cell_size
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
	map_content.cell_size = _cell_size
	map_content.queue_redraw()


func _set_marker_at_mouse() -> void:
	var local_position := map_content.get_local_mouse_position()
	if not Rect2(Vector2.ZERO, map_content.size).has_point(local_position):
		return

	var cell: Vector2i = map_content.cell_at_local_position(local_position)
	if cell.x < 0 or not maze.is_cell_explored(cell):
		return

	if game.has_map_marker() and game.map_marker_cell() == cell:
		game.clear_map_marker()
	else:
		game.set_map_marker_cell(cell)
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
		"MAP    WASD / arrows - scroll    Tab / Esc - close",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		20,
		TEXT_COLOR
	)
