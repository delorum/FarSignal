extends Node2D

const ARM_LENGTH := 6.0
const INNER_GAP := 1.5
const LINE_WIDTH := 1.5
const COOLDOWN_COLOR := Color(0.12, 0.16, 0.18, 0.45)
const READY_COLOR := Color(0.88, 0.96, 1.0, 0.86)

var _readiness := 1.0


func set_readiness(readiness: float) -> void:
	var normalized_readiness := clampf(readiness, 0.0, 1.0)
	if is_equal_approx(_readiness, normalized_readiness):
		return
	_readiness = normalized_readiness
	queue_redraw()


func _process(_delta: float) -> void:
	var mouse_position := get_global_mouse_position()
	if position.is_equal_approx(mouse_position):
		return
	position = mouse_position
	queue_redraw()


func _draw() -> void:
	var color := COOLDOWN_COLOR.lerp(READY_COLOR, _readiness)
	for axis in [Vector2.RIGHT, Vector2.DOWN]:
		draw_line(
			-axis * ARM_LENGTH,
			-axis * INNER_GAP,
			color,
			LINE_WIDTH,
			true
		)
		draw_line(
			axis * INNER_GAP,
			axis * ARM_LENGTH,
			color,
			LINE_WIDTH,
			true
		)
