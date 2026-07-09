extends CharacterBody2D
class_name Player

signal damaged

@export var speed := 200.0

const MAX_HEALTH := 100
const MAX_AMMO := 30
const MAX_HEALTH_BUY := 20
const MAX_AMMO_BUY := 10
const ENERGY_PER_CORE := 20
const DOOR_COST := 10
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
var energy_cores := 0
var energy := 0
var door_inventory := 0
var noise_level := 0.0
var ambush_energy := AMBUSH_DURATION
var ambush_mode := false
var _facing := Vector2.RIGHT
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


func restore_status(
	saved_health: int,
	saved_ammo: int,
	saved_energy_cores: int = 0,
	saved_energy: int = 0,
	saved_door_inventory: int = 0
) -> void:
	health = clampi(saved_health, 0, MAX_HEALTH)
	ammo = clampi(saved_ammo, 0, MAX_AMMO)
	energy_cores = maxi(0, saved_energy_cores)
	energy = maxi(0, saved_energy)
	door_inventory = maxi(0, saved_door_inventory)


func consume_ammo() -> bool:
	if ammo <= 0:
		return false

	ammo -= 1
	return true


func refill_health() -> void:
	health = MAX_HEALTH


func refill_ammo() -> void:
	ammo = MAX_AMMO


func missing_health() -> int:
	return MAX_HEALTH - health


func missing_ammo() -> int:
	return MAX_AMMO - ammo


func health_purchase_amount() -> int:
	return mini(MAX_HEALTH_BUY, missing_health())


func health_purchase_cost() -> int:
	return ceili(float(health_purchase_amount()) * 10.0 / MAX_HEALTH_BUY)


func ammo_purchase_amount() -> int:
	return mini(MAX_AMMO_BUY, missing_ammo())


func ammo_purchase_cost() -> int:
	return ceili(float(ammo_purchase_amount()) * 10.0 / MAX_AMMO_BUY)


func can_buy_health() -> bool:
	var cost := health_purchase_cost()
	return cost > 0 and energy >= cost


func can_buy_ammo() -> bool:
	var cost := ammo_purchase_cost()
	return cost > 0 and energy >= cost


func can_buy_door() -> bool:
	return energy >= DOOR_COST


func buy_health() -> bool:
	if not can_buy_health():
		return false
	energy -= health_purchase_cost()
	health = mini(MAX_HEALTH, health + health_purchase_amount())
	return true


func buy_ammo() -> bool:
	if not can_buy_ammo():
		return false
	energy -= ammo_purchase_cost()
	ammo = mini(MAX_AMMO, ammo + ammo_purchase_amount())
	return true


func buy_door() -> bool:
	if not can_buy_door():
		return false
	energy -= DOOR_COST
	door_inventory += 1
	return true


func exchange_energy_cores() -> bool:
	if energy_cores <= 0:
		return false
	energy += energy_cores * ENERGY_PER_CORE
	energy_cores = 0
	return true


func collect_energy_core() -> void:
	energy_cores += 1


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
