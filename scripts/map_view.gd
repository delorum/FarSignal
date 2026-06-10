extends Control

const MAP_CELL_SIZE := 40.0
const MIN_MAP_CELL_SIZE := 16.0
const MAX_MAP_CELL_SIZE := 72.0
const ZOOM_FACTOR := 1.2
const SCROLL_SPEED := 420.0
const MAP_MARGIN := 80.0
const BACKGROUND_COLOR := Color("07101d")
const FRAME_COLOR := Color("6f8eaa")
const TEXT_COLOR := Color("d8e7f5")

@onready var maze: Maze = $"../../Maze"
@onready var player: Player = $"../../Player"
@onready var doors: Node2D = $"../../Doors"
@onready var stations: Node2D = $"../../Stations"
@onready var pause_menu: Control = $"../../PauseOverlay/PauseMenu"
@onready var station_menu: Control = $"../../StationOverlay/StationMenu"
@onready var defeat_menu: Control = $"../../DefeatOverlay/DefeatMenu"
@onready var map_viewport: Control = $MapViewport
@onready var map_content: Control = $MapViewport/MapContent

var _scroll_position := Vector2.ZERO
var _cell_size := MAP_CELL_SIZE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	resized.connect(_on_resized)
	map_viewport.gui_input.connect(_on_map_viewport_gui_input)
	map_content.setup(maze, player, doors, stations, _cell_size)


func _exit_tree() -> void:
	if get_tree().paused:
		get_tree().paused = false


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("toggle_map"):
		if pause_menu.visible or station_menu.visible or defeat_menu.visible:
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


func _on_map_viewport_gui_input(event: InputEvent) -> void:
	if not visible or not event is InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return

	var zoom_factor := 1.0
	if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
		zoom_factor = ZOOM_FACTOR
	elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		zoom_factor = 1.0 / ZOOM_FACTOR
	else:
		return

	_zoom_at(mouse_event.position, zoom_factor)
	map_viewport.accept_event()


func _open_map() -> void:
	var player_cell := maze.world_to_cell(player.position)
	_scroll_position = (Vector2(player_cell) + Vector2.ONE * 0.5) * _cell_size
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


func _zoom_at(mouse_position: Vector2, zoom_factor: float) -> void:
	var old_cell_size := _cell_size
	var new_cell_size := clampf(
		old_cell_size * zoom_factor,
		MIN_MAP_CELL_SIZE,
		MAX_MAP_CELL_SIZE
	)
	if is_equal_approx(new_cell_size, old_cell_size):
		return

	var offset_from_center := mouse_position - map_viewport.size * 0.5
	var map_position := (
		_scroll_position + offset_from_center
	) / old_cell_size

	_cell_size = new_cell_size
	_scroll_position = map_position * _cell_size - offset_from_center
	_clamp_scroll_position()
	_update_map_content()


func _update_map_content() -> void:
	map_content.scroll_position = _scroll_position
	map_content.cell_size = _cell_size
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
		"MAP    WASD / arrows - scroll    Wheel - zoom    Tab - close",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		20,
		TEXT_COLOR
	)
