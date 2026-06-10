extends Control

const SEGMENT_COUNT := 3
const SEGMENT_GAP := 8.0
const EMPTY_COLOR := Color("101923")
const FILLED_COLOR := Color("bd3f43")
const EDGE_COLOR := Color("75484c")

var strength := 0:
	set(value):
		var clamped_value := clampi(value, 0, SEGMENT_COUNT)
		if strength == clamped_value:
			return
		strength = clamped_value
		queue_redraw()


func _draw() -> void:
	var segment_width := (
		size.x - SEGMENT_GAP * float(SEGMENT_COUNT - 1)
	) / float(SEGMENT_COUNT)
	for index in SEGMENT_COUNT:
		var rect := Rect2(
			Vector2(float(index) * (segment_width + SEGMENT_GAP), 0.0),
			Vector2(segment_width, size.y)
		)
		draw_rect(rect, FILLED_COLOR if index < strength else EMPTY_COLOR)
		draw_rect(rect.grow(-1.0), EDGE_COLOR, false, 1.0)
