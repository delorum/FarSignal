extends Node2D

const SIGNAL_COLOR := Color("ffc247")

var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var pulse := 1.0 + sin(_time * 3.5) * 0.12
	var points := PackedVector2Array([
		Vector2(0.0, -16.0) * pulse,
		Vector2(15.0, 12.0) * pulse,
		Vector2(-15.0, 12.0) * pulse,
	])
	draw_colored_polygon(points, SIGNAL_COLOR)
	draw_arc(Vector2.ZERO, 23.0 * pulse, 0.0, TAU, 32, SIGNAL_COLOR, 2.0, true)
