extends Node2D

const LINE_COLOR := Color(1.0, 0.82, 0.18, 0.82)

var _from := Vector2.ZERO
var _to := Vector2.ZERO


func set_connection(from: Vector2, to: Vector2, show_line: bool) -> void:
	_from = from
	_to = to
	visible = show_line
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	draw_line(to_local(_from), to_local(_to), LINE_COLOR, 3.0, true)
