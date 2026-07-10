extends Node2D

const TEXT_COLOR := Color(0.88, 0.96, 1.0, 0.92)
const BAR_BACKGROUND_COLOR := Color(0.02, 0.035, 0.055, 0.85)
const BAR_FILL_COLOR := Color(0.58, 0.86, 0.95, 0.92)
const BAR_BORDER_COLOR := Color(0.82, 0.9, 0.96, 0.9)
const BAR_SIZE := Vector2(42.0, 7.0)
const BAR_OFFSET := Vector2(-21.0, 12.0)
const TEXT_OFFSET := Vector2(-30.0, -14.0)

var _label := ""
var _progress := 0.0


func show_action(world_position: Vector2, label: String) -> void:
	position = world_position
	_label = label
	_progress = 0.0
	visible = true
	queue_redraw()


func set_progress(progress: float) -> void:
	var normalized_progress := clampf(progress, 0.0, 1.0)
	if is_equal_approx(_progress, normalized_progress):
		return
	_progress = normalized_progress
	queue_redraw()


func hide_action() -> void:
	visible = false
	_progress = 0.0
	queue_redraw()


func _draw() -> void:
	if not visible:
		return

	draw_string(
		ThemeDB.fallback_font,
		TEXT_OFFSET,
		_label,
		HORIZONTAL_ALIGNMENT_LEFT,
		60.0,
		14,
		TEXT_COLOR
	)
	var background_rect := Rect2(BAR_OFFSET, BAR_SIZE)
	draw_rect(background_rect, BAR_BACKGROUND_COLOR, true)
	draw_rect(
		Rect2(BAR_OFFSET, Vector2(BAR_SIZE.x * _progress, BAR_SIZE.y)),
		BAR_FILL_COLOR,
		true
	)
	draw_rect(background_rect, BAR_BORDER_COLOR, false, 1.0)
