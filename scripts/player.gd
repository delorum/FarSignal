extends CharacterBody2D
class_name Player

signal damaged

@export var speed := 200.0

const MAX_HEALTH := 100
const MAX_AMMO := 30
const PLAYER_LEVEL_COUNT := 5
const MAX_UPGRADE_LEVEL := PLAYER_LEVEL_COUNT - 1
const UPGRADE_COSTS := [300, 600, 1200, 2400]
const MAX_UPGRADED_HEALTH := 340
const MAX_UPGRADED_AMMO := 200
const BASE_DAMAGE_MIN := 27
const BASE_DAMAGE_MAX := 36
const MAX_UPGRADED_DAMAGE_MIN := 308
const MAX_UPGRADED_DAMAGE_MAX := 338
const MAX_HEALTH_BUY := 20
const MAX_AMMO_BUY := 10
const AMMO_COST_PER_ROUND := 1
const ENERGY_CORE_ENERGY_PER_LEVEL := 20
const EXPLORATION_POINTS_PER_ENERGY := 20
const MEGA_CORE_ENERGY_PER_LEVEL := 100
const MEGA_CORE_LEVEL_COUNT := 5
const DOOR_COST := 50
const TURRET_COST := 50
const TURRET_MAX_HEALTH := 200
const TURRET_MAX_AMMO := 30
const STRUCTURE_MAX_UPGRADED_HEALTH := 900
const TURRET_MAX_UPGRADED_HEALTH := STRUCTURE_MAX_UPGRADED_HEALTH
const TURRET_MAX_UPGRADED_AMMO := MAX_UPGRADED_AMMO
const TURRET_MAX_UPGRADED_DAMAGE_MIN := 190
const TURRET_MAX_UPGRADED_DAMAGE_MAX := 220
const TOWER_COST := 10
const TOWER_MAX_HEALTH := 200
const TOWER_MAX_UPGRADED_HEALTH := STRUCTURE_MAX_UPGRADED_HEALTH
const TOWER_SAFE_RADIUS := 5
const TOWER_SAFE_RADIUS_PER_LEVEL := 2
const MAINTENANCE_RESERVE_TRANSFER := 10
const STARTING_DOORS := 0
const MAX_DOOR_INVENTORY := 5
const MAX_TURRET_INVENTORY := 5
const MAX_TOWER_INVENTORY := 20
const CELL_SIZE := 48.0
const RECOIL_DISTANCE := CELL_SIZE
const NOISE_BUILDUP_DISTANCE := CELL_SIZE * 3.0
const FOOTSTEP_DISTANCE := CELL_SIZE * 1.35
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
var turret_health_upgrade_level := 0
var turret_damage_upgrade_level := 0
var turret_ammo_upgrade_level := 0
var tower_health_upgrade_level := 0
var tower_radius_upgrade_level := 0
var energy_cores := 0
var energy_core_energy := 0
var energy := 0
var maintenance_energy := 0
var energy_received_total := 0
var energy_spent_total := 0
var door_inventory := STARTING_DOORS
var turret_inventory: Array[Dictionary] = []
var tower_inventory: Array[Dictionary] = []
var exploration_points := 0
var mega_core_cells: Array[Vector2i] = [
	Vector2i(-1, -1),
	Vector2i(-1, -1),
	Vector2i(-1, -1),
	Vector2i(-1, -1),
	Vector2i(-1, -1),
]
var carried_mega_core_levels: Array[int] = []
var noise_level := 0.0
var _facing := Vector2.RIGHT
var _animation_time := 0.0
var _animation_running := false
var _footstep_distance := 0.0


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
	saved_maintenance_energy: int = 0,
	saved_door_inventory: int = 0,
	saved_exploration_points: int = 0,
	saved_damage_upgrade_level: int = 0,
	saved_health_upgrade_level: int = 0,
	saved_ammo_upgrade_level: int = 0,
	saved_energy_core_energy: int = 0,
	saved_energy_received_total: int = 0,
	saved_energy_spent_total: int = 0,
	saved_turret_inventory: Array = [],
	saved_tower_inventory: Array = [],
	saved_turret_health_upgrade_level: int = 0,
	saved_turret_damage_upgrade_level: int = 0,
	saved_turret_ammo_upgrade_level: int = 0,
	saved_tower_health_upgrade_level: int = 0,
	saved_tower_radius_upgrade_level: int = 0
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
	turret_health_upgrade_level = clampi(
		saved_turret_health_upgrade_level, 0, MAX_UPGRADE_LEVEL
	)
	turret_damage_upgrade_level = clampi(
		saved_turret_damage_upgrade_level, 0, MAX_UPGRADE_LEVEL
	)
	turret_ammo_upgrade_level = clampi(
		saved_turret_ammo_upgrade_level, 0, MAX_UPGRADE_LEVEL
	)
	tower_health_upgrade_level = clampi(
		saved_tower_health_upgrade_level, 0, MAX_UPGRADE_LEVEL
	)
	tower_radius_upgrade_level = clampi(
		saved_tower_radius_upgrade_level, 0, MAX_UPGRADE_LEVEL
	)
	_update_maximums()
	health = clampi(saved_health, 0, max_health)
	ammo = clampi(saved_ammo, 0, max_ammo)
	energy_cores = maxi(0, saved_energy_cores)
	energy_core_energy = maxi(0, saved_energy_core_energy)
	energy = maxi(0, saved_energy)
	maintenance_energy = maxi(0, saved_maintenance_energy)
	energy_received_total = maxi(0, saved_energy_received_total)
	energy_spent_total = maxi(0, saved_energy_spent_total)
	door_inventory = clampi(saved_door_inventory, 0, MAX_DOOR_INVENTORY)
	turret_inventory = _sanitize_turret_inventory(saved_turret_inventory)
	tower_inventory = _sanitize_tower_inventory(saved_tower_inventory)
	exploration_points = maxi(0, saved_exploration_points)


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


func turret_max_health() -> int:
	return _upgraded_value(
		TURRET_MAX_HEALTH,
		TURRET_MAX_UPGRADED_HEALTH,
		turret_health_upgrade_level
	)


func turret_max_ammo() -> int:
	return _upgraded_value(
		TURRET_MAX_AMMO,
		TURRET_MAX_UPGRADED_AMMO,
		turret_ammo_upgrade_level
	)


func turret_damage_min() -> int:
	return _upgraded_value(
		BASE_DAMAGE_MIN,
		TURRET_MAX_UPGRADED_DAMAGE_MIN,
		turret_damage_upgrade_level
	)


func turret_damage_max() -> int:
	return _upgraded_value(
		BASE_DAMAGE_MAX,
		TURRET_MAX_UPGRADED_DAMAGE_MAX,
		turret_damage_upgrade_level
	)


func tower_max_health() -> int:
	return _upgraded_value(
		TOWER_MAX_HEALTH,
		TOWER_MAX_UPGRADED_HEALTH,
		tower_health_upgrade_level
	)


func tower_safe_radius() -> int:
	return TOWER_SAFE_RADIUS + (
		tower_radius_upgrade_level * TOWER_SAFE_RADIUS_PER_LEVEL
	)


func _upgraded_value(base_value: int, upgraded_value: int, level: int) -> int:
	return roundi(lerpf(
		base_value,
		upgraded_value,
		float(level) / MAX_UPGRADE_LEVEL
	))


static func energy_core_reward(enemy_level: int) -> int:
	return maxi(1, enemy_level) * ENERGY_CORE_ENERGY_PER_LEVEL


func can_upgrade_damage_at_station(station_id: int) -> bool:
	return _can_upgrade_at_station(damage_upgrade_level, station_id)


func can_upgrade_health_at_station(station_id: int) -> bool:
	return _can_upgrade_at_station(health_upgrade_level, station_id)


func can_upgrade_ammo_at_station(station_id: int) -> bool:
	return _can_upgrade_at_station(ammo_upgrade_level, station_id)


func upgrade_damage(station_id: int) -> bool:
	if not can_upgrade_damage_at_station(station_id):
		return false
	_spend_energy(upgrade_cost(damage_upgrade_level))
	damage_upgrade_level += 1
	return true


func upgrade_health(station_id: int) -> bool:
	if not can_upgrade_health_at_station(station_id):
		return false
	var previous_max := max_health
	_spend_energy(upgrade_cost(health_upgrade_level))
	health_upgrade_level += 1
	_update_maximums()
	health += max_health - previous_max
	return true


func upgrade_ammo(station_id: int) -> bool:
	if not can_upgrade_ammo_at_station(station_id):
		return false
	var previous_max := max_ammo
	_spend_energy(upgrade_cost(ammo_upgrade_level))
	ammo_upgrade_level += 1
	_update_maximums()
	ammo += max_ammo - previous_max
	return true


func can_upgrade_turret_health() -> bool:
	return _can_upgrade_structure(turret_health_upgrade_level)


func can_upgrade_turret_damage() -> bool:
	return _can_upgrade_structure(turret_damage_upgrade_level)


func can_upgrade_turret_ammo() -> bool:
	return _can_upgrade_structure(turret_ammo_upgrade_level)


func can_upgrade_tower_health() -> bool:
	return _can_upgrade_structure(tower_health_upgrade_level)


func can_upgrade_tower_radius() -> bool:
	return _can_upgrade_structure(tower_radius_upgrade_level)


func upgrade_turret_health() -> bool:
	if not can_upgrade_turret_health():
		return false
	var previous_max := turret_max_health()
	_spend_energy(upgrade_cost(turret_health_upgrade_level))
	turret_health_upgrade_level += 1
	_increase_inventory_values(
		turret_inventory,
		"health",
		turret_max_health() - previous_max,
		turret_max_health()
	)
	return true


func upgrade_turret_damage() -> bool:
	if not can_upgrade_turret_damage():
		return false
	_spend_energy(upgrade_cost(turret_damage_upgrade_level))
	turret_damage_upgrade_level += 1
	return true


func upgrade_turret_ammo() -> bool:
	if not can_upgrade_turret_ammo():
		return false
	var previous_max := turret_max_ammo()
	_spend_energy(upgrade_cost(turret_ammo_upgrade_level))
	turret_ammo_upgrade_level += 1
	_increase_inventory_values(
		turret_inventory,
		"ammo",
		turret_max_ammo() - previous_max,
		turret_max_ammo()
	)
	return true


func upgrade_tower_health() -> bool:
	if not can_upgrade_tower_health():
		return false
	var previous_max := tower_max_health()
	_spend_energy(upgrade_cost(tower_health_upgrade_level))
	tower_health_upgrade_level += 1
	_increase_inventory_values(
		tower_inventory,
		"health",
		tower_max_health() - previous_max,
		tower_max_health()
	)
	return true


func upgrade_tower_radius() -> bool:
	if not can_upgrade_tower_radius():
		return false
	_spend_energy(upgrade_cost(tower_radius_upgrade_level))
	tower_radius_upgrade_level += 1
	return true


func _can_upgrade_structure(level: int) -> bool:
	return level < MAX_UPGRADE_LEVEL and energy >= upgrade_cost(level)


func _increase_inventory_values(
	inventory: Array[Dictionary],
	key: String,
	amount: int,
	maximum: int
) -> void:
	for item in inventory:
		item[key] = mini(maximum, int(item.get(key, 0)) + amount)


func _can_upgrade_at_station(
	level: int,
	_station_id: int
) -> bool:
	return level < MAX_UPGRADE_LEVEL and energy >= upgrade_cost(level)


static func upgrade_cost(current_upgrade_level: int) -> int:
	if current_upgrade_level < 0 \
			or current_upgrade_level >= UPGRADE_COSTS.size():
		return 0
	return UPGRADE_COSTS[current_upgrade_level]


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
	return health_energy_cost(health_purchase_amount())


func ammo_purchase_amount() -> int:
	return mini(MAX_AMMO_BUY, missing_ammo())


func ammo_purchase_cost() -> int:
	return ammo_energy_cost(ammo_purchase_amount())


static func health_energy_cost(amount: int) -> int:
	return ceili(float(maxi(0, amount)) * 10.0 / MAX_HEALTH_BUY)


static func ammo_energy_cost(amount: int) -> int:
	return maxi(0, amount) * AMMO_COST_PER_ROUND


func spend_energy(amount: int) -> bool:
	if amount <= 0 or energy < amount:
		return false
	_spend_energy(amount)
	return true


func can_fund_maintenance_reserve() -> bool:
	return energy >= MAINTENANCE_RESERVE_TRANSFER


func fund_maintenance_reserve() -> bool:
	if not can_fund_maintenance_reserve():
		return false
	_spend_energy(MAINTENANCE_RESERVE_TRANSFER)
	maintenance_energy += MAINTENANCE_RESERVE_TRANSFER
	return true


func consume_maintenance_energy(amount: int = 1) -> bool:
	if amount <= 0 or maintenance_energy < amount:
		return false
	maintenance_energy -= amount
	return true


func can_buy_health() -> bool:
	var cost := health_purchase_cost()
	return cost > 0 and energy >= cost


func can_buy_ammo() -> bool:
	var cost := ammo_purchase_cost()
	return cost > 0 and energy >= cost


func can_buy_door() -> bool:
	return energy >= DOOR_COST and can_store_door()


func can_buy_turret() -> bool:
	return energy >= TURRET_COST and can_store_turret()


func can_buy_tower() -> bool:
	return energy >= TOWER_COST and can_store_tower()


func can_store_door() -> bool:
	return door_inventory < MAX_DOOR_INVENTORY


func can_store_turret() -> bool:
	return turret_inventory.size() < MAX_TURRET_INVENTORY


func can_store_tower() -> bool:
	return tower_inventory.size() < MAX_TOWER_INVENTORY


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


func buy_turret() -> bool:
	if not can_buy_turret():
		return false
	_spend_energy(TURRET_COST)
	turret_inventory.append({
		"health": turret_max_health(),
		"ammo": turret_max_ammo(),
	})
	return true


func turret_inventory_count() -> int:
	return turret_inventory.size()


func take_turret_from_inventory() -> Dictionary:
	if turret_inventory.is_empty():
		return {}
	return turret_inventory.pop_back()


func store_turret_in_inventory(health_value: int, ammo_value: int) -> bool:
	if not can_store_turret():
		return false
	turret_inventory.append({
		"health": clampi(health_value, 1, turret_max_health()),
		"ammo": clampi(ammo_value, 0, turret_max_ammo()),
	})
	return true


func turret_inventory_for_save() -> Array:
	return turret_inventory.duplicate(true)


func buy_tower() -> bool:
	if not can_buy_tower():
		return false
	_spend_energy(TOWER_COST)
	tower_inventory.append({"health": tower_max_health()})
	return true


func tower_inventory_count() -> int:
	return tower_inventory.size()


func take_tower_from_inventory() -> Dictionary:
	if tower_inventory.is_empty():
		return {}
	return tower_inventory.pop_back()


func store_tower_in_inventory(health_value: int) -> bool:
	if not can_store_tower():
		return false
	tower_inventory.append({
		"health": clampi(health_value, 1, tower_max_health()),
	})
	return true


func tower_inventory_for_save() -> Array:
	return tower_inventory.duplicate(true)


func _sanitize_turret_inventory(saved_turrets: Array) -> Array[Dictionary]:
	var restored: Array[Dictionary] = []
	for saved_turret in saved_turrets:
		if restored.size() >= MAX_TURRET_INVENTORY:
			break
		if not saved_turret is Dictionary:
			continue
		restored.append({
			"health": clampi(
				int(saved_turret.get("health", turret_max_health())),
				1,
				turret_max_health()
			),
			"ammo": clampi(
				int(saved_turret.get("ammo", turret_max_ammo())),
				0,
				turret_max_ammo()
			),
		})
	return restored


func _sanitize_tower_inventory(saved_towers: Array) -> Array[Dictionary]:
	var restored: Array[Dictionary] = []
	for saved_tower in saved_towers:
		if restored.size() >= MAX_TOWER_INVENTORY:
			break
		if not saved_tower is Dictionary:
			continue
		restored.append({
			"health": clampi(
				int(saved_tower.get("health", tower_max_health())),
				1,
				tower_max_health()
			),
		})
	return restored


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


func restore_mega_cores(saved_cells: Array, saved_carried_levels: Array) -> void:
	mega_core_cells.fill(Vector2i(-1, -1))
	for index in mini(saved_cells.size(), MEGA_CORE_LEVEL_COUNT):
		var saved_cell: Variant = saved_cells[index]
		if saved_cell is Array and saved_cell.size() == 2:
			mega_core_cells[index] = Vector2i(
				int(saved_cell[0]),
				int(saved_cell[1])
			)
	carried_mega_core_levels.clear()
	for saved_level: Variant in saved_carried_levels:
		var level := int(saved_level)
		if level >= 1 and level <= MEGA_CORE_LEVEL_COUNT \
				and not carried_mega_core_levels.has(level):
			carried_mega_core_levels.append(level)
			mega_core_cells[level - 1] = Vector2i(-1, -1)
	carried_mega_core_levels.sort()


func mega_core_cell_for_level(level: int) -> Vector2i:
	if level < 1 or level > MEGA_CORE_LEVEL_COUNT:
		return Vector2i(-1, -1)
	return mega_core_cells[level - 1]


func assign_mega_core(level: int, cell: Vector2i) -> void:
	if level < 1 or level > MEGA_CORE_LEVEL_COUNT \
			or carried_mega_core_levels.has(level):
		return
	mega_core_cells[level - 1] = cell


func collect_mega_core(level: int) -> bool:
	var cell := mega_core_cell_for_level(level)
	if cell.x < 0 or carried_mega_core_levels.has(level):
		return false
	mega_core_cells[level - 1] = Vector2i(-1, -1)
	carried_mega_core_levels.append(level)
	carried_mega_core_levels.sort()
	return true


func has_carried_mega_cores() -> bool:
	return not carried_mega_core_levels.is_empty()


func carried_mega_core_count() -> int:
	return carried_mega_core_levels.size()


func carried_mega_core_energy() -> int:
	var result := 0
	for level in carried_mega_core_levels:
		result += mega_core_reward(level)
	return result


func return_mega_cores() -> Array[int]:
	var returned_levels := carried_mega_core_levels.duplicate()
	if returned_levels.is_empty():
		return returned_levels
	_gain_energy(carried_mega_core_energy())
	carried_mega_core_levels.clear()
	return returned_levels


static func mega_core_reward(zone_level: int) -> int:
	return clampi(zone_level, 1, MEGA_CORE_LEVEL_COUNT) \
			* MEGA_CORE_ENERGY_PER_LEVEL


func collect_energy_core(core_energy: int) -> void:
	energy_cores += 1
	energy_core_energy += maxi(0, core_energy)


func discover_floor_cell(zone_level: int) -> void:
	exploration_points += exploration_point_multiplier(zone_level)


static func exploration_point_multiplier(zone_level: int) -> int:
	return clampi(zone_level, 1, PLAYER_LEVEL_COUNT)


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


func set_aim_indicator_shooting_enabled(enabled: bool) -> void:
	if aim_indicator != null \
			and aim_indicator.has_method("set_shooting_enabled"):
		aim_indicator.set_shooting_enabled(enabled)


func _process(_delta: float) -> void:
	if not controls_enabled:
		return
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
	var previous_position := position
	move_and_slide()
	_update_footsteps(position.distance_to(previous_position))

	if is_moving():
		noise_level = move_toward(
			noise_level,
			1.0,
			velocity.length() * delta / NOISE_BUILDUP_DISTANCE
		)
	else:
		noise_level = 0.0

	_update_animation(delta)


func _update_footsteps(distance_moved: float) -> void:
	if distance_moved <= 0.01:
		_footstep_distance = 0.0
		return

	_footstep_distance += distance_moved
	if _footstep_distance < FOOTSTEP_DISTANCE:
		return

	_footstep_distance = fmod(_footstep_distance, FOOTSTEP_DISTANCE)
	AudioManager.play_player_footstep()


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
