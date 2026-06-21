extends StaticBody2D
class_name Station

const CELL_SIZE := 48.0
const ANIMATION_FRAME_COUNT := 8
const ANIMATION_FPS := 5.0
const EXPLORED_MODULATE := Color(0.34, 0.38, 0.36, 1.0)

var cell := Vector2i.ZERO
var discovered := false
var _currently_visible := false
var _explored := false
var _animation_time := 0.0

@onready var station_sprite: Sprite2D = $Sprite2D


func setup(station_cell: Vector2i) -> void:
	cell = station_cell
	position = (Vector2(cell) + Vector2.ONE * 0.5) * CELL_SIZE
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	_animation_time += delta
	station_sprite.frame = posmod(
		floori(_animation_time * ANIMATION_FPS),
		ANIMATION_FRAME_COUNT
	)


func update_visibility(currently_visible: bool, explored: bool) -> void:
	_currently_visible = currently_visible
	_explored = explored
	visible = currently_visible or explored
	station_sprite.modulate = (
		EXPLORED_MODULATE
		if explored and not currently_visible
		else Color.WHITE
	)


func discover() -> void:
	discovered = true
