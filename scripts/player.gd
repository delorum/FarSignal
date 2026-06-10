extends CharacterBody2D
class_name Player

@export var speed := 230.0

const BODY_COLOR := Color("58d6f5")
const DIRECTION_COLOR := Color("e8fbff")
const MAX_HEALTH := 100
const MAX_AMMO := 30

var controls_enabled := true
var health := MAX_HEALTH
var ammo := MAX_AMMO
var _facing := Vector2.RIGHT


func facing_direction() -> Vector2:
	return _facing


func facing_direction_for_save() -> Array[float]:
	return [_facing.x, _facing.y]


func restore_facing_direction(saved_facing: Array) -> void:
	if saved_facing.size() != 2:
		return

	var restored_facing := Vector2(
		float(saved_facing[0]),
		float(saved_facing[1])
	)
	if restored_facing.is_zero_approx():
		return

	_facing = restored_facing.normalized()
	queue_redraw()


func restore_status(saved_health: int, saved_ammo: int) -> void:
	health = clampi(saved_health, 0, MAX_HEALTH)
	ammo = clampi(saved_ammo, 0, MAX_AMMO)


func consume_ammo() -> bool:
	if ammo <= 0:
		return false

	ammo -= 1
	return true


func refill_health() -> void:
	health = MAX_HEALTH


func refill_ammo() -> void:
	ammo = MAX_AMMO


func take_damage(amount: int) -> bool:
	if health <= 0:
		return false
	health = maxi(0, health - amount)
	return health == 0


func is_moving() -> bool:
	return velocity.length_squared() > 1.0


func _process(_delta: float) -> void:
	var mouse_direction := get_local_mouse_position()
	if mouse_direction.is_zero_approx():
		return

	var new_facing := mouse_direction.normalized()
	if not new_facing.is_equal_approx(_facing):
		_facing = new_facing
		queue_redraw()


func _physics_process(_delta: float) -> void:
	var input_direction := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)
	input_direction += Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	input_direction = input_direction.limit_length()

	if not controls_enabled:
		input_direction = Vector2.ZERO

	velocity = input_direction * speed
	move_and_slide()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 14.0, BODY_COLOR)
	draw_circle(Vector2.ZERO, 14.0, DIRECTION_COLOR, false, 2.0, true)
	draw_line(Vector2.ZERO, _facing * 11.0, DIRECTION_COLOR, 3.0, true)
