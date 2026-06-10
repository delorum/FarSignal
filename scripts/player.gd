extends CharacterBody2D
class_name Player

@export var speed := 230.0

const BODY_COLOR := Color("58d6f5")
const DIRECTION_COLOR := Color("e8fbff")
const ENEMY_ARROW_COLOR := Color("bd3f43")
const ENEMY_ARROW_EDGE_COLOR := Color("e0787b")
const MAX_HEALTH := 100
const MAX_AMMO := 30
const ENEMY_ARROW_START := 20.0
const ENEMY_ARROW_LENGTH := 13.0
const ENEMY_ARROW_RADIUS_STEP := 6.0
const ENEMY_ARROW_HEAD_LENGTH := 6.0
const ENEMY_ARROW_HEAD_ANGLE := deg_to_rad(32.0)
const WALK_SPEED_MULTIPLIER := 0.5

var controls_enabled := true
var health := MAX_HEALTH
var ammo := MAX_AMMO
var walking := false
var _facing := Vector2.RIGHT
var _enemy_directions: Array[Vector2] = []


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


func restore_movement_mode(saved_walking: bool) -> void:
	walking = saved_walking


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


func is_making_step_noise() -> bool:
	return is_moving() and not walking


func movement_mode_name() -> String:
	return "Ходьба" if walking else "Бег"


func set_enemy_directions(directions: Array[Vector2]) -> void:
	if _enemy_directions == directions:
		return
	_enemy_directions = directions.duplicate()
	queue_redraw()


func _process(_delta: float) -> void:
	if controls_enabled and Input.is_action_just_pressed("toggle_movement_mode"):
		walking = not walking

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

	var movement_speed := speed * WALK_SPEED_MULTIPLIER if walking else speed
	velocity = input_direction * movement_speed
	move_and_slide()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 14.0, BODY_COLOR)
	draw_circle(Vector2.ZERO, 14.0, DIRECTION_COLOR, false, 2.0, true)
	draw_line(Vector2.ZERO, _facing * 11.0, DIRECTION_COLOR, 3.0, true)
	_draw_enemy_directions()


func _draw_enemy_directions() -> void:
	for index in _enemy_directions.size():
		var direction := _enemy_directions[index]
		if direction.is_zero_approx():
			continue

		direction = direction.normalized()
		var start_distance := (
			ENEMY_ARROW_START + float(index) * ENEMY_ARROW_RADIUS_STEP
		)
		var start := direction * start_distance
		var tip := start + direction * ENEMY_ARROW_LENGTH
		draw_line(start, tip, ENEMY_ARROW_COLOR, 2.0, true)

		var back := -direction
		var left_head := tip + back.rotated(
			ENEMY_ARROW_HEAD_ANGLE
		) * ENEMY_ARROW_HEAD_LENGTH
		var right_head := tip + back.rotated(
			-ENEMY_ARROW_HEAD_ANGLE
		) * ENEMY_ARROW_HEAD_LENGTH
		draw_line(tip, left_head, ENEMY_ARROW_EDGE_COLOR, 2.0, true)
		draw_line(tip, right_head, ENEMY_ARROW_EDGE_COLOR, 2.0, true)
