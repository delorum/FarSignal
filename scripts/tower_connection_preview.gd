extends Node2D

const LINE_COLOR := Color(1.0, 0.82, 0.18, 0.82)
const PLACEMENT_COLOR := Color(0.58, 0.64, 0.7, 0.82)
const TURRET_RADIUS := 14.0
const TOWER_RADIUS := 20.0

enum PreviewType {
	NONE,
	TOWER,
	TURRET,
}

var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _preview_type := PreviewType.NONE
var _show_line := false


func set_tower(
	from: Vector2,
	to: Vector2,
	show_tower: bool,
	show_line: bool
) -> void:
	_from = from
	_to = to
	_show_line = show_line
	_preview_type = PreviewType.TOWER if show_tower else PreviewType.NONE
	visible = show_tower
	queue_redraw()


func set_turret(world_position: Vector2, show_turret: bool) -> void:
	_to = world_position
	_preview_type = PreviewType.TURRET if show_turret else PreviewType.NONE
	visible = show_turret
	queue_redraw()


func hide_preview() -> void:
	_preview_type = PreviewType.NONE
	visible = false
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	if _preview_type == PreviewType.TOWER:
		var center := to_local(_to)
		var points := PackedVector2Array([
			center + Vector2(0.0, -TOWER_RADIUS),
			center + Vector2(TOWER_RADIUS * 0.87, TOWER_RADIUS * 0.5),
			center + Vector2(-TOWER_RADIUS * 0.87, TOWER_RADIUS * 0.5),
		])
		draw_colored_polygon(points, PLACEMENT_COLOR)
		if _show_line:
			draw_line(to_local(_from), center, LINE_COLOR, 3.0, true)
	elif _preview_type == PreviewType.TURRET:
		draw_circle(
			to_local(_to),
			TURRET_RADIUS,
			PLACEMENT_COLOR,
			true,
			-1.0,
			true
		)
