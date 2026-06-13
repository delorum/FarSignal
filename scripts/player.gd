extends CharacterBody2D
class_name Player

@export var speed := 230.0

const BODY_COLOR := Color("58d6f5")
const DIRECTION_COLOR := Color("e8fbff")
const ENEMY_ARROW_COLOR := Color("bd3f43")
const ENEMY_ARROW_EDGE_COLOR := Color("e0787b")
const PATROL_ARROW_COLOR := Color("69717a")
const PATROL_ARROW_EDGE_COLOR := Color("929ba5")
const MAX_HEALTH := 100
const MAX_AMMO := 100
const ENEMY_ARROW_START := 20.0
const ENEMY_ARROW_LENGTH := 13.0
const ENEMY_ARROW_RADIUS_STEP := 6.0
const ENEMY_ARROW_HEAD_LENGTH := 6.0
const ENEMY_ARROW_HEAD_ANGLE := deg_to_rad(32.0)
const CELL_SIZE := 48.0
const NOISE_BUILDUP_DISTANCE := CELL_SIZE * 2.0
const NOISE_DECAY_TIME := 1.0

var controls_enabled := true
var health := MAX_HEALTH
var ammo := MAX_AMMO
var noise_level := 0.0
var _facing := Vector2.RIGHT
var _enemy_indicators: Array[Dictionary] = []


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


func show_damage_number(amount: int, direction: Vector2) -> void:
	get_parent().spawn_damage_number(position, amount, direction)


func is_moving() -> bool:
	return velocity.length_squared() > 1.0


func is_audible() -> bool:
	return is_equal_approx(noise_level, 1.0)


func make_shot_noise() -> void:
	noise_level = 1.0


func set_enemy_indicators(indicators: Array[Dictionary]) -> void:
	if _enemy_indicators == indicators:
		return
	_enemy_indicators = indicators.duplicate(true)
	queue_redraw()


func _process(_delta: float) -> void:
	var mouse_direction := get_local_mouse_position()
	if mouse_direction.is_zero_approx():
		return

	var new_facing := mouse_direction.normalized()
	if not new_facing.is_equal_approx(_facing):
		_facing = new_facing
		queue_redraw()


func _physics_process(delta: float) -> void:
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

	if is_moving():
		noise_level = move_toward(
			noise_level,
			1.0,
			velocity.length() * delta / NOISE_BUILDUP_DISTANCE
		)
	else:
		noise_level = move_toward(
			noise_level,
			0.0,
			delta / NOISE_DECAY_TIME
		)


func _draw() -> void:
	draw_circle(Vector2.ZERO, 14.0, BODY_COLOR)
	draw_circle(Vector2.ZERO, 14.0, DIRECTION_COLOR, false, 2.0, true)
	draw_line(Vector2.ZERO, _facing * 11.0, DIRECTION_COLOR, 3.0, true)
	_draw_enemy_directions()


func _draw_enemy_directions() -> void:
	for index in _enemy_indicators.size():
		var indicator: Dictionary = _enemy_indicators[index]
		var direction: Vector2 = indicator.direction
		if direction.is_zero_approx():
			continue

		var alerted := bool(indicator.alerted)
		var arrow_color := (
			ENEMY_ARROW_COLOR if alerted else PATROL_ARROW_COLOR
		)
		var edge_color := (
			ENEMY_ARROW_EDGE_COLOR if alerted else PATROL_ARROW_EDGE_COLOR
		)
		direction = direction.normalized()
		var start_distance := (
			ENEMY_ARROW_START + float(index) * ENEMY_ARROW_RADIUS_STEP
		)
		var start := direction * start_distance
		var tip := start + direction * ENEMY_ARROW_LENGTH
		draw_line(start, tip, arrow_color, 2.0, true)

		var back := -direction
		var left_head := tip + back.rotated(
			ENEMY_ARROW_HEAD_ANGLE
		) * ENEMY_ARROW_HEAD_LENGTH
		var right_head := tip + back.rotated(
			-ENEMY_ARROW_HEAD_ANGLE
		) * ENEMY_ARROW_HEAD_LENGTH
		draw_line(tip, left_head, edge_color, 2.0, true)
		draw_line(tip, right_head, edge_color, 2.0, true)
