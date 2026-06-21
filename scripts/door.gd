extends StaticBody2D
class_name Door

const CELL_SIZE := 48.0
const FRAME_COUNT := 8
const LAST_FRAME := FRAME_COUNT - 1
const ANIMATION_DURATION := 0.35
const LOCKED_MODULATE := Color(0.82, 0.52, 0.52, 1.0)
const EXPLORED_MODULATE := Color(0.3, 0.32, 0.36, 1.0)

var cell := Vector2i.ZERO
var horizontal_passage := true
var locked := false
var is_open := false
var player_placed := false
var _currently_visible := false
var _explored := false
var _animation_elapsed := 0.0
var _animation_start_frame := 0
var _animation_end_frame := 0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var door_sprite: Sprite2D = $Sprite2D


func setup(
	door_cell: Vector2i,
	is_horizontal_passage: bool,
	is_locked: bool = false,
	starts_open: bool = false,
	is_player_placed: bool = false
) -> void:
	cell = door_cell
	horizontal_passage = is_horizontal_passage
	locked = is_locked
	is_open = starts_open
	player_placed = is_player_placed
	position = (Vector2(cell) + Vector2.ONE * 0.5) * CELL_SIZE


func _ready() -> void:
	door_sprite.rotation = 0.0 if horizontal_passage else PI * 0.5
	door_sprite.frame = LAST_FRAME if is_open else 0
	_update_sprite_modulate()
	_update_collision()
	set_process(false)


func _process(delta: float) -> void:
	_animation_elapsed += delta
	var progress := minf(_animation_elapsed / ANIMATION_DURATION, 1.0)
	door_sprite.frame = roundi(lerpf(
		float(_animation_start_frame),
		float(_animation_end_frame),
		progress
	))
	if progress >= 1.0:
		set_process(false)


func toggle(player_position: Vector2) -> bool:
	if locked:
		return false
	if is_open and player_position.distance_to(position) < CELL_SIZE * 0.7:
		return false

	is_open = not is_open
	_start_animation()
	_update_collision()
	return true


func update_visibility(currently_visible: bool, explored: bool) -> void:
	_currently_visible = currently_visible
	_explored = explored
	visible = currently_visible or explored
	_update_sprite_modulate()


func save_data() -> Dictionary:
	return {
		"cell": [cell.x, cell.y],
		"horizontal_passage": horizontal_passage,
		"locked": locked,
		"open": is_open,
		"player_placed": player_placed,
	}


func _update_collision() -> void:
	if collision_shape != null:
		collision_shape.set_deferred("disabled", is_open)


func _start_animation() -> void:
	_animation_elapsed = 0.0
	_animation_start_frame = door_sprite.frame
	_animation_end_frame = LAST_FRAME if is_open else 0
	set_process(true)


func _update_sprite_modulate() -> void:
	if door_sprite == null:
		return
	if _explored and not _currently_visible:
		door_sprite.modulate = EXPLORED_MODULATE
	elif locked:
		door_sprite.modulate = LOCKED_MODULATE
	else:
		door_sprite.modulate = Color.WHITE
