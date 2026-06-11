extends StaticBody2D
class_name Station

const CELL_SIZE := 48.0
const BODY_COLOR := Color("2f9e62")
const EDGE_COLOR := Color("7be0a3")
const EXPLORED_BODY_COLOR := Color("12251c")
const EXPLORED_EDGE_COLOR := Color("1d3a2b")

var cell := Vector2i.ZERO
var discovered := false
var _currently_visible := false
var _explored := false


func setup(station_cell: Vector2i) -> void:
	cell = station_cell
	position = (Vector2(cell) + Vector2.ONE * 0.5) * CELL_SIZE


func update_visibility(currently_visible: bool, explored: bool) -> void:
	if _currently_visible == currently_visible and _explored == explored:
		return

	_currently_visible = currently_visible
	_explored = explored
	visible = currently_visible or explored
	queue_redraw()


func discover() -> void:
	discovered = true


func _draw() -> void:
	var dimmed := _explored and not _currently_visible
	var radius := 17.0
	var points := PackedVector2Array([
		Vector2(0.0, -radius),
		Vector2(radius, 0.0),
		Vector2(0.0, radius),
		Vector2(-radius, 0.0),
	])
	var body_color := EXPLORED_BODY_COLOR if dimmed else BODY_COLOR
	var edge_color := EXPLORED_EDGE_COLOR if dimmed else EDGE_COLOR
	draw_colored_polygon(points, body_color)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, edge_color, 1.0 if dimmed else 2.0, true)
