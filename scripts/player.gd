extends CharacterBody2D
class_name Player

signal damaged

@export var speed := 200.0

const MAX_HEALTH := 100
const MAX_AMMO := 30
const PLAYER_LEVEL_COUNT := 5
const MAX_UPGRADE_LEVEL := PLAYER_LEVEL_COUNT - 1
const UPGRADES_PER_STATION := 2
const UPGRADE_COST := 300
const MAX_UPGRADED_HEALTH := 340
const MAX_UPGRADED_AMMO := 200
const BASE_DAMAGE_MIN := 27
const BASE_DAMAGE_MAX := 36
const MAX_UPGRADED_DAMAGE_MIN := 308
const MAX_UPGRADED_DAMAGE_MAX := 338
const MAX_HEALTH_BUY := 20
const MAX_AMMO_BUY := 10
const AMMO_COST_PER_ROUND := 1
const LOWER_LEVEL_CORE_ENERGY := 10
const EQUAL_LEVEL_CORE_ENERGY := 20
const EXPLORATION_POINTS_PER_ENERGY := 20
const MEGA_CORE_RETURN_ENERGY := 100
const DOOR_COST := 50
const STARTING_DOORS := 0
const MAX_DOOR_INVENTORY := 5
const CELL_SIZE := 48.0
const RECOIL_DISTANCE := CELL_SIZE
const NOISE_BUILDUP_DISTANCE := CELL_SIZE * 3.0
const NOISE_DECAY_TIME := 1.0
const ANIMATION_FRAME_COUNT := 8
const RUN_ANIMATION_FPS := 10.0
const IDLE_ANIMATION_FPS := 5.0
const IDLE_FRAME_OFFSET := 8
@onready var player_sprite: Sprite2D = $Sprite2D
@onready var aim_indicator: Node2D = $"../AimIndicator"

var controls_enabled := true
var health := MAX_HEALTH
var ammo := MAX_AMMO
var max_health := MAX_HEALTH
var max_ammo := MAX_AMMO
var damage_upgrade_level := 0
var health_upgrade_level := 0
var ammo_upgrade_level := 0
var energy_cores := 0
var energy_core_energy := 0
var energy := 0
var energy_received_total := 0
var energy_spent_total := 0
var door_inventory := STARTING_DOORS
var exploration_points := 0
var mega_core_cell := Vector2i(-1, -1)
var has_mega_core := false
var noise_level := 0.0
var _facing := Vector2.RIGHT
var _animation_time := 0.0
var _animation_running := false


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
	saved_door_inventory: int = 0,
	saved_exploration_points: int = 0,
	saved_mega_core_cell: Vector2i = Vector2i(-1, -1),
	saved_has_mega_core: bool = false,
	saved_damage_upgrade_level: int = 0,
	saved_health_upgrade_level: int = 0,
	saved_ammo_upgrade_level: int = 0,
	saved_energy_core_energy: int = 0,
	saved_energy_received_total: int = 0,
	saved_energy_spent_total: int = 0
) -> void:
	damage_upgrade_level = clampi(
		saved_damage_upgrade_level,
		0,
		MAX_UPGRADE_LEVEL
	)
	health_upgrade_level = clampi(
		saved_health_upgrade_level,
		0,
		MAX_UPGRADE_LEVEL
	)
	ammo_upgrade_level = clampi(saved_ammo_upgrade_level, 0, MAX_UPGRADE_LEVEL)
	_update_maximums()
	health = clampi(saved_health, 0, max_health)
	ammo = clampi(saved_ammo, 0, max_ammo)
	energy_cores = maxi(0, saved_energy_cores)
	energy_core_energy = maxi(0, saved_energy_core_energy)
	energy = maxi(0, saved_energy)
	energy_received_total = maxi(0, saved_energy_received_total)
	energy_spent_total = maxi(0, saved_energy_spent_total)
	door_inventory = clampi(saved_door_inventory, 0, MAX_DOOR_INVENTORY)
	exploration_points = maxi(0, saved_exploration_points)
	mega_core_cell = saved_mega_core_cell
	has_mega_core = saved_has_mega_core


func consume_ammo() -> bool:
	if ammo <= 0:
		return false

	ammo -= 1
	return true


func refill_health() -> void:
	health = max_health


func refill_ammo() -> void:
	ammo = max_ammo


func missing_health() -> int:
	return max_health - health


func missing_ammo() -> int:
	return max_ammo - ammo


func damage_min() -> int:
	return roundi(lerpf(
		BASE_DAMAGE_MIN,
		MAX_UPGRADED_DAMAGE_MIN,
		float(damage_upgrade_level) / MAX_UPGRADE_LEVEL
	))


func damage_max() -> int:
	return roundi(lerpf(
		BASE_DAMAGE_MAX,
		MAX_UPGRADED_DAMAGE_MAX,
		float(damage_upgrade_level) / MAX_UPGRADE_LEVEL
	))


func current_level() -> int:
	return mini(damage_upgrade_level, health_upgrade_level) + 1


static func energy_core_reward(enemy_level: int, player_level: int) -> int:
	if enemy_level < player_level:
		return LOWER_LEVEL_CORE_ENERGY
	return EQUAL_LEVEL_CORE_ENERGY * (enemy_level - player_level + 1)


func can_upgrade_damage_at_station(station_id: int) -> bool:
	return _can_upgrade_at_station(damage_upgrade_level, station_id)


func can_upgrade_health_at_station(station_id: int) -> bool:
	return _can_upgrade_at_station(health_upgrade_level, station_id)


func can_upgrade_ammo_at_station(station_id: int) -> bool:
	return _can_upgrade_at_station(ammo_upgrade_level, station_id)


func upgrade_damage(station_id: int) -> bool:
	if not can_upgrade_damage_at_station(station_id):
		return false
	_spend_energy(UPGRADE_COST)
	damage_upgrade_level += 1
	return true


func upgrade_health(station_id: int) -> bool:
	if not can_upgrade_health_at_station(station_id):
		return false
	var previous_max := max_health
	_spend_energy(UPGRADE_COST)
	health_upgrade_level += 1
	_update_maximums()
	health += max_health - previous_max
	return true


func upgrade_ammo(station_id: int) -> bool:
	if not can_upgrade_ammo_at_station(station_id):
		return false
	var previous_max := max_ammo
	_spend_energy(UPGRADE_COST)
	ammo_upgrade_level += 1
	_update_maximums()
	ammo += max_ammo - previous_max
	return true


func _can_upgrade_at_station(
	level: int,
	station_id: int
) -> bool:
	var station_index := station_id - 2
	if station_index < 0 or station_index >= 2:
		return false
	var minimum_level := station_index * UPGRADES_PER_STATION
	var maximum_level := minimum_level + UPGRADES_PER_STATION
	return level >= minimum_level \
			and level < maximum_level \
			and energy >= UPGRADE_COST


func _update_maximums() -> void:
	max_health = roundi(lerpf(
		MAX_HEALTH,
		MAX_UPGRADED_HEALTH,
		float(health_upgrade_level) / MAX_UPGRADE_LEVEL
	))
	max_ammo = roundi(lerpf(
		MAX_AMMO,
		MAX_UPGRADED_AMMO,
		float(ammo_upgrade_level) / MAX_UPGRADE_LEVEL
	))


func health_purchase_amount() -> int:
	return mini(MAX_HEALTH_BUY, missing_health())


func health_purchase_cost() -> int:
	return ceili(float(health_purchase_amount()) * 10.0 / MAX_HEALTH_BUY)


func ammo_purchase_amount() -> int:
	return mini(MAX_AMMO_BUY, missing_ammo())


func ammo_purchase_cost() -> int:
	return ammo_purchase_amount() * AMMO_COST_PER_ROUND


func can_buy_health() -> bool:
	var cost := health_purchase_cost()
	return cost > 0 and energy >= cost


func can_buy_ammo() -> bool:
	var cost := ammo_purchase_cost()
	return cost > 0 and energy >= cost


func can_buy_door() -> bool:
	return energy >= DOOR_COST and can_store_door()


func can_store_door() -> bool:
	return door_inventory < MAX_DOOR_INVENTORY


func exploration_exchange_points() -> int:
	return exploration_exchange_energy() * EXPLORATION_POINTS_PER_ENERGY


func exploration_exchange_energy() -> int:
	return floori(
		float(exploration_points) / float(EXPLORATION_POINTS_PER_ENERGY)
	)


func buy_health() -> bool:
	if not can_buy_health():
		return false
	_spend_energy(health_purchase_cost())
	health = mini(max_health, health + health_purchase_amount())
	return true


func buy_ammo() -> bool:
	if not can_buy_ammo():
		return false
	_spend_energy(ammo_purchase_cost())
	ammo = mini(max_ammo, ammo + ammo_purchase_amount())
	return true


func buy_door() -> bool:
	if not can_buy_door():
		return false
	_spend_energy(DOOR_COST)
	door_inventory += 1
	return true


func exchange_energy_cores() -> bool:
	if energy_cores <= 0:
		return false
	_gain_energy(energy_core_energy)
	energy_cores = 0
	energy_core_energy = 0
	return true


func energy_core_exchange_energy() -> int:
	return energy_core_energy


func exchange_exploration_points() -> bool:
	var exchanged_points := exploration_exchange_points()
	if exchanged_points <= 0:
		return false
	_gain_energy(exploration_exchange_energy())
	exploration_points -= exchanged_points
	return true


func assign_mega_core(cell: Vector2i) -> void:
	mega_core_cell = cell
	has_mega_core = false


func collect_mega_core() -> bool:
	if has_mega_core or mega_core_cell.x < 0:
		return false
	has_mega_core = true
	return true


func return_mega_core() -> bool:
	if not has_mega_core:
		return false
	_gain_energy(MEGA_CORE_RETURN_ENERGY)
	mega_core_cell = Vector2i(-1, -1)
	has_mega_core = false
	return true


func collect_energy_core(core_energy: int) -> void:
	energy_cores += 1
	energy_core_energy += maxi(0, core_energy)


func discover_floor_cell(zone_level: int) -> void:
	exploration_points += exploration_point_multiplier(
		zone_level,
		current_level()
	)


static func exploration_point_multiplier(zone_level: int, player_level: int) -> int:
	return maxi(1, zone_level - player_level + 1)


func _gain_energy(amount: int) -> void:
	var gained := maxi(0, amount)
	energy += gained
	energy_received_total += gained


func _spend_energy(amount: int) -> void:
	var spent := maxi(0, amount)
	energy -= spent
	energy_spent_total += spent


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
	return is_equal_approx(noise_level, 1.0)


func make_shot_noise() -> void:
	noise_level = 1.0
	queue_redraw()


func apply_recoil(shot_direction: Vector2) -> void:
	if shot_direction.is_zero_approx():
		return
	move_and_collide(-shot_direction.normalized() * RECOIL_DISTANCE)


func set_aim_indicator_readiness(readiness: float) -> void:
	if aim_indicator != null and aim_indicator.has_method("set_readiness"):
		aim_indicator.set_readiness(readiness)


func _process(_delta: float) -> void:
	var mouse_direction := get_global_mouse_position() - global_position
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
	pass
