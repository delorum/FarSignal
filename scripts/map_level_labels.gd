extends Control

const ENEMY_LEVEL_COUNT := 5
const LABEL_COLOR := Color(1.0, 1.0, 1.0, 0.82)
const SHADOW_COLOR := Color(0.02, 0.03, 0.04, 0.95)
const EDGE_INSET := 6.0

var _maze: Maze
var _map_rect := Rect2()
var _scroll_position := Vector2.ZERO
var _cell_size := 16.0


func setup(maze: Maze) -> void:
	_maze = maze
	queue_redraw()


func update_layout(
	map_rect: Rect2,
	scroll_position: Vector2,
	cell_size: float
) -> void:
	_map_rect = map_rect
	_scroll_position = scroll_position
	_cell_size = cell_size
	queue_redraw()


func _draw() -> void:
	if _maze == null:
		return
	var grid_size := _maze.grid_size()
	var font := ThemeDB.fallback_font
	var font_size := maxi(12, roundi(_cell_size * 0.8))
	for boundary_index in range(1, ENEMY_LEVEL_COUNT):
		var boundary_cell_y := floori(
			float(boundary_index * grid_size.y) / float(ENEMY_LEVEL_COUNT)
		)
		var line_y := (
			_map_rect.position.y
			+ _map_rect.size.y * 0.5
			- _scroll_position.y
			+ float(boundary_cell_y) * _cell_size
		)
		if line_y < _map_rect.position.y or line_y > _map_rect.end.y:
			continue
		var upper_level := ENEMY_LEVEL_COUNT + 1 - boundary_index
		var lower_level := ENEMY_LEVEL_COUNT - boundary_index
		_draw_edge_labels(line_y - 5.0, str(upper_level), font, font_size)
		_draw_edge_labels(
			line_y + float(font_size) + 5.0,
			str(lower_level),
			font,
			font_size
		)


func _draw_edge_labels(
	y: float,
	text: String,
	font: Font,
	font_size: int
) -> void:
	_draw_label(
		font,
		Vector2(_map_rect.position.x + EDGE_INSET, y),
		text,
		font_size
	)


func _draw_label(
	font: Font,
	position: Vector2,
	text: String,
	font_size: int
) -> void:
	draw_string(
		font,
		position + Vector2.ONE,
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size,
		SHADOW_COLOR
	)
	draw_string(
		font,
		position,
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size,
		LABEL_COLOR
	)
