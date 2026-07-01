extends CharacterBody2D
class_name Player

signal damaged

@export var speed := 200.0

const ENEMY_ARROW_COLOR := Color("bd3f43")
const ENEMY_ARROW_EDGE_COLOR := Color("e0787b")
const PATROL_ARROW_COLOR := Color("69717a")
const PATROL_ARROW_EDGE_COLOR := Color("929ba5")
const MAX_HEALTH := 100
const MAX_AMMO := 30
const ENEMY_ARROW_START := 20.0
const ENEMY_ARROW_LENGTH := 13.0
const ENEMY_ARROW_RADIUS_STEP := 6.0
const ENEMY_ARROW_HEAD_LENGTH := 6.0
const ENEMY_ARROW_HEAD_ANGLE := deg_to_rad(32.0)
const CELL_SIZE := 48.0
const RECOIL_DISTANCE := CELL_SIZE
const NOISE_BUILDUP_DISTANCE := CELL_SIZE * 3.0
const NOISE_DECAY_TIME := 1.0
const AMBUSH_DURATION := 20.0
const AMBUSH_RECOVERY_TIME := 40.0
const ANIMATION_FRAME_COUNT := 8
const RUN_ANIMATION_FPS := 10.0
const IDLE_ANIMATION_FPS := 5.0
const IDLE_FRAME_OFFSET := 8
const AIM_INDICATOR_ARM_LENGTH := 6.0
const AIM_INDICATOR_INNER_GAP := 1.5
const AIM_INDICATOR_LINE_WIDTH := 1.5
const AIM_INDICATOR_COOLDOWN_COLOR := Color(0.12, 0.16, 0.18, 0.45)
const AIM_INDICATOR_READY_COLOR := Color(0.88, 0.96, 1.0, 0.86)
const AIM_INDICATOR_AMBUSH_ALPHA := 0.45

@onready var player_sprite: Sprite2D = $Sprite2D

var controls_enabled := true
var health := MAX_HEALTH
var ammo := MAX_AMMO
var noise_level := 0.0
var ambush_energy := AMBUSH_DURATION
var ambush_mode := false
var _facing := Vector2.RIGHT
var _enemy_indicators: Array[Dictionary] = []
var _animation_time := 0.0
var _animation_running := false
var _aim_indicator_readiness := 1.0
var _aim_indicator_position := Vector2.ZERO


func _ready() -> void:
	_update_sprite_facing()


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
	_update_sprite_facing()
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
	damaged.emit()
	return health == 0


func show_damage_number(amount: int, direction: Vector2) -> void:
	get_parent().spawn_damage_number(position, amount, direction)


func is_moving() -> bool:
	return velocity.length_squared() > 1.0


func is_audible() -> bool:
	return not ambush_mode and is_equal_approx(noise_level, 1.0)


func make_shot_noise() -> void:
	ambush_mode = false
	noise_level = 1.0
	queue_redraw()


func apply_recoil(shot_direction: Vector2) -> void:
	if shot_direction.is_zero_approx():
		return
	move_and_collide(-shot_direction.normalized() * RECOIL_DISTANCE)


func toggle_ambush_mode() -> void:
	if ambush_mode:
		ambush_mode = false
	elif ambush_energy > 0.0:
		ambush_mode = true
	if ambush_mode:
		noise_level = 0.0
	queue_redraw()


func ambush_energy_ratio() -> float:
	return ambush_energy / AMBUSH_DURATION


func set_aim_indicator_readiness(readiness: float) -> void:
	var normalized_readiness := clampf(readiness, 0.0, 1.0)
	if is_equal_approx(_aim_indicator_readiness, normalized_readiness):
		return
	_aim_indicator_readiness = normalized_readiness
	queue_redraw()


func set_enemy_indicators(indicators: Array[Dictionary]) -> void:
	if _enemy_indicators == indicators:
		return
	_enemy_indicators = indicators.duplicate(true)
	queue_redraw()


func _process(_delta: float) -> void:
	var mouse_position := get_local_mouse_position()
	if not mouse_position.is_equal_approx(_aim_indicator_position):
		_aim_indicator_position = mouse_position
		queue_redraw()

	var mouse_direction := mouse_position
	if mouse_direction.is_zero_approx():
		return

	var new_facing := mouse_direction.normalized()
	if not new_facing.is_equal_approx(_facing):
		_facing = new_facing
		_update_sprite_facing()
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

	if ambush_mode:
		ambush_energy = maxf(0.0, ambush_energy - delta)
		if is_zero_approx(ambush_energy):
			ambush_mode = false
		noise_level = 0.0
	elif ambush_energy < AMBUSH_DURATION:
		ambush_energy = minf(
			AMBUSH_DURATION,
			ambush_energy + AMBUSH_DURATION * delta / AMBUSH_RECOVERY_TIME
		)

	if not ambush_mode:
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

	_update_animation(delta)


func _update_sprite_facing() -> void:
	if player_sprite != null:
		player_sprite.rotation = _facing.angle()
		player_sprite.flip_v = _facing.x < 0.0


func _update_animation(delta: float) -> void:
	var running := is_moving()
	if running != _animation_running:
		_animation_running = running
		_animation_time = 0.0
	else:
		_animation_time += delta

	var animation_fps := RUN_ANIMATION_FPS if running else IDLE_ANIMATION_FPS
	var frame_offset := 0 if running else IDLE_FRAME_OFFSET
	player_sprite.frame = frame_offset + posmod(
		floori(_animation_time * animation_fps),
		ANIMATION_FRAME_COUNT
	)


func _draw() -> void:
	_draw_aim_indicator()
	_draw_enemy_directions()


func _draw_aim_indicator() -> void:
	var center := _aim_indicator_position
	var color := AIM_INDICATOR_COOLDOWN_COLOR.lerp(
		AIM_INDICATOR_READY_COLOR,
		_aim_indicator_readiness
	)
	if ambush_mode:
		color.a *= AIM_INDICATOR_AMBUSH_ALPHA
	var horizontal := Vector2.RIGHT
	var vertical := Vector2.DOWN
	for axis in [horizontal, vertical]:
		draw_line(
			center - axis * AIM_INDICATOR_ARM_LENGTH,
			center - axis * AIM_INDICATOR_INNER_GAP,
			color,
			AIM_INDICATOR_LINE_WIDTH,
			true
		)
		draw_line(
			center + axis * AIM_INDICATOR_INNER_GAP,
			center + axis * AIM_INDICATOR_ARM_LENGTH,
			color,
			AIM_INDICATOR_LINE_WIDTH,
			true
		)


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
