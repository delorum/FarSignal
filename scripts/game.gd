extends Node2D

const DOOR_SCENE := preload("res://scenes/door.tscn")
const BULLET_SCENE := preload("res://scenes/bullet.tscn")
const DAMAGE_NUMBER_SCENE := preload("res://scenes/damage_number.tscn")
const STATION_SCENE := preload("res://scenes/station.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const BULLET_SPAWN_DISTANCE := 22.0
const ENEMY_COUNT := 10
const MAX_ENEMY_START_DISTANCE := 15.0
const ENEMY_START_DISTANCE_RATIO := 0.15
const ENEMY_SPAWN_ATTEMPTS := 256
const PLAYER_DAMAGE_MIN := 27
const PLAYER_DAMAGE_MAX := 36
const ENEMY_DAMAGE_MIN := 17
const ENEMY_DAMAGE_MAX := 24
const ENEMY_AUDIBLE_RANGE := 30.0
const ENEMY_HEALTH_DISPLAY_RANGE := 10.0
const SHOT_HEARING_RANGE := ENEMY_AUDIBLE_RANGE
const SHOT_REACTION_DELAY := 1.0
const PLAYER_SHOOT_INTERVAL := 1.0
const NOISE_SILENT_COLOR := Color("58d68d")
const NOISE_AUDIBLE_COLOR := Color("d66b6b")
const PANEL_WIDTH_RATIO := 0.2
const MIN_PANEL_WIDTH := 260.0
const MAX_PANEL_WIDTH := 360.0

@onready var maze: Maze = $Maze
@onready var player: Player = $Player
@onready var doors: Node2D = $Doors
@onready var stations: Node2D = $Stations
@onready var enemies: Node2D = $Enemies
@onready var bullets: Node2D = $Bullets
@onready var damage_numbers: Node2D = $DamageNumbers
@onready var camera: Camera2D = $Player/Camera2D
@onready var player_panel: Panel = $GameInterface/PlayerPanel
@onready var coordinates_label: Label = $GameInterface/PlayerPanel/Coordinates
@onready var health_value: Label = $GameInterface/PlayerPanel/Margin/VBox/HealthValue
@onready var health_bar: ProgressBar = $GameInterface/PlayerPanel/Margin/VBox/HealthBar
@onready var ammo_value: Label = $GameInterface/PlayerPanel/Margin/VBox/AmmoValue
@onready var ammo_bar: ProgressBar = $GameInterface/PlayerPanel/Margin/VBox/AmmoBar
@onready var weapon_ready_bar: ProgressBar = $GameInterface/PlayerPanel/Margin/VBox/WeaponReadyBar
@onready var noise_state_value: Label = $GameInterface/PlayerPanel/Margin/VBox/NoiseStateValue
@onready var noise_bar: ProgressBar = $GameInterface/PlayerPanel/Margin/VBox/NoiseBar
@onready var enemy_meter: Control = $GameInterface/PlayerPanel/Margin/VBox/EnemyMeter
@onready var nearby_enemy_health: VBoxContainer = $GameInterface/PlayerPanel/Margin/VBox/NearbyEnemyHealth
@onready var nearby_enemy_health_value: Label = $GameInterface/PlayerPanel/Margin/VBox/NearbyEnemyHealth/Value
@onready var nearby_enemy_health_bar: ProgressBar = $GameInterface/PlayerPanel/Margin/VBox/NearbyEnemyHealth/Bar
@onready var station_menu: Control = $StationOverlay/StationMenu
@onready var defeat_menu: Control = $DefeatOverlay/DefeatMenu

var _displayed_player_cell := Vector2i(-1, -1)
var _displayed_health := -1
var _displayed_ammo := -1
var _displayed_noise_state := ""
var _displayed_enemy_signal := -1
var _doors: Array[Node] = []
var _stations: Array[Node] = []
var _enemies: Array[Node] = []
var _enemies_killed := 0
var _defeated := false
var _shoot_cooldown := 0.0
var _rng := RandomNumberGenerator.new()


func _enter_tree() -> void:
	if not SaveStore.pending_save.is_empty():
		var maze_node: Maze = get_node("Maze")
		maze_node.generation_seed_override = int(
			SaveStore.pending_save.get("maze_seed", 0)
		)


func _ready() -> void:
	_rng.randomize()
	get_viewport().size_changed.connect(_update_adaptive_layout)
	_update_adaptive_layout()
	var save_data := SaveStore.consume_pending_save()
	if save_data.is_empty():
		_create_generated_stations()
		var player_cell := maze.station_start_cell()
		player.position = maze.cell_to_world(player_cell)
		var start_facing := maze.station_start_facing()
		player.restore_facing_direction([start_facing.x, start_facing.y])
		for station in _stations:
			station.discover()
		_create_generated_doors()
		_refresh_safe_zone()
		_create_generated_enemies(player_cell)
	else:
		_create_generated_stations()
		_restore_game(save_data)
		SaveStore.delete_save()

	_update_visibility()
	_update_coordinates()
	_update_player_panel()


func _update_adaptive_layout() -> void:
	var viewport_width := get_viewport_rect().size.x
	var panel_width := clampf(
		viewport_width * PANEL_WIDTH_RATIO,
		MIN_PANEL_WIDTH,
		MAX_PANEL_WIDTH
	)
	player_panel.offset_left = -panel_width
	camera.position.x = panel_width * 0.5


func _process(delta: float) -> void:
	if not _defeated and player.health <= 0:
		_show_defeat()
		return

	_shoot_cooldown = maxf(0.0, _shoot_cooldown - delta)
	if Input.is_action_just_pressed("toggle_ambush") \
			and player.controls_enabled:
		player.toggle_ambush_mode()
	if Input.is_action_just_pressed("shoot"):
		_shoot()
	if Input.is_action_just_pressed("place_door") \
			and player.controls_enabled:
		_toggle_player_door_at(
			maze.world_to_cell(get_global_mouse_position())
		)

	if Input.is_action_just_pressed("interact"):
		if not _interact_with_station():
			_interact_with_door()

	_update_visibility()
	_update_coordinates()
	_update_player_panel()


func _update_visibility() -> void:
	maze.update_visibility(player.position, player.facing_direction())
	for door in _doors:
		door.update_visibility(
			maze.is_cell_visible(door.cell),
			maze.is_cell_explored(door.cell)
		)
	for station in _stations:
		station.update_visibility(
			maze.is_cell_visible(station.cell),
			maze.is_cell_explored(station.cell)
		)
	for enemy in _enemies:
		enemy.update_visibility(
			maze.is_cell_visible(maze.world_to_cell(enemy.position)),
			player.ambush_mode and _is_enemy_audible(enemy)
		)


func _update_coordinates() -> void:
	var player_cell: Vector2i = maze.world_to_cell(player.position)
	if player_cell == _displayed_player_cell:
		return

	_displayed_player_cell = player_cell
	coordinates_label.text = "X: %d  Y: %d" % [player_cell.x, player_cell.y]


func _update_player_panel() -> void:
	if player.health != _displayed_health:
		_displayed_health = player.health
		health_value.text = "%d / %d" % [player.health, player.MAX_HEALTH]
		health_bar.value = player.health

	if player.ammo != _displayed_ammo:
		_displayed_ammo = player.ammo
		ammo_value.text = "%d / %d" % [player.ammo, player.MAX_AMMO]
		ammo_bar.value = player.ammo
	weapon_ready_bar.value = (
		0.0
		if player.ammo <= 0
		else (1.0 - _shoot_cooldown / PLAYER_SHOOT_INTERVAL) * 100.0
	)

	var noise_state := (
		"РЕЖИМ ЗАСАДЫ"
		if player.ambush_mode
		else (
			"ВАС СЛЫШНО"
			if player.is_audible()
			else "НЕ СЛЫШНО"
		)
	)
	if noise_state != _displayed_noise_state:
		_displayed_noise_state = noise_state
		noise_state_value.text = noise_state
		noise_state_value.modulate = (
			NOISE_SILENT_COLOR
			if player.ambush_mode or not player.is_audible()
			else NOISE_AUDIBLE_COLOR
		)
	noise_bar.visible = not player.ambush_mode
	if noise_bar.visible:
		noise_bar.value = player.noise_level * 100.0

	var enemy_signal_strength := _enemy_signal_strength()
	if enemy_signal_strength != _displayed_enemy_signal:
		_displayed_enemy_signal = enemy_signal_strength
		enemy_meter.strength = enemy_signal_strength
	_update_nearby_enemy_health()
	player.set_enemy_indicators(_audible_enemy_indicators())


func _update_nearby_enemy_health() -> void:
	var closest_enemy: Enemy
	var closest_distance := INF
	var player_cell: Vector2i = maze.world_to_cell(player.position)
	for enemy in _enemies:
		if enemy.dead:
			continue

		var enemy_cell: Vector2i = maze.world_to_cell(enemy.position)
		var distance := Vector2(enemy_cell - player_cell).length()
		if distance <= ENEMY_HEALTH_DISPLAY_RANGE \
				and distance < closest_distance:
			closest_enemy = enemy
			closest_distance = distance

	nearby_enemy_health.visible = closest_enemy != null
	if closest_enemy == null:
		return

	nearby_enemy_health_value.text = "%d / %d" % [
		closest_enemy.health,
		closest_enemy.MAX_HEALTH,
	]
	nearby_enemy_health_bar.value = closest_enemy.health


func save_game() -> bool:
	var save_data := {
		"version": SaveStore.SAVE_VERSION,
		"maze_size": [maze.grid_size().x, maze.grid_size().y],
		"maze_seed": maze.generation_seed(),
		"player_position": [player.position.x, player.position.y],
		"player_facing": player.facing_direction_for_save(),
		"player_health": player.health,
		"player_ammo": player.ammo,
		"explored_cells": maze.explored_cells_for_save(),
		"doors": _doors.map(func(door: Node): return door.save_data()),
		"station_discovered": (
			not _stations.is_empty() and _stations[0].discovered
		),
		"enemies": _enemies.map(func(enemy: Node): return enemy.save_data()),
		"enemies_killed": _enemies_killed,
	}
	return SaveStore.write_save(save_data)


func save_file_path() -> String:
	return SaveStore.save_file_path()


func _restore_game(save_data: Dictionary) -> void:
	var saved_position: Array = save_data.player_position
	player.position = Vector2(
		float(saved_position[0]),
		float(saved_position[1])
	)
	player.restore_facing_direction(save_data.player_facing)
	player.restore_status(
		int(save_data.get("player_health", player.MAX_HEALTH)),
		int(save_data.get("player_ammo", player.MAX_AMMO))
	)
	maze.restore_explored_cells(save_data.explored_cells)
	if not _stations.is_empty():
		_stations[0].discovered = bool(
			save_data.get("station_discovered", false)
		)
	if save_data.has("doors"):
		for door_data in save_data.doors:
			if _is_generated_door_data(door_data) \
					or bool(door_data.get("player_placed", false)):
				_create_door_from_save(door_data)
		_create_missing_generated_doors()
	else:
		_create_generated_doors()
	_refresh_safe_zone()
	_enemies_killed = int(save_data.get("enemies_killed", 0))
	if save_data.has("enemies"):
		for index in save_data.enemies.size():
			_create_enemy_from_save(save_data.enemies[index], index)
		_create_generated_enemies(
			maze.world_to_cell(player.position),
			maxi(0, ENEMY_COUNT - _living_enemy_count())
		)
	else:
		_create_generated_enemies(maze.world_to_cell(player.position))


func _create_generated_stations() -> void:
	for station_spec in maze.generated_station_specs():
		var station: Node = STATION_SCENE.instantiate()
		station.setup(station_spec.cell)
		stations.add_child(station)
		_stations.append(station)


func _create_generated_enemies(
	player_cell: Vector2i,
	enemy_count: int = ENEMY_COUNT
) -> void:
	var enemy_rng := RandomNumberGenerator.new()
	enemy_rng.seed = maze.generation_seed() ^ 0x5e71a9
	var occupied_cells := _occupied_enemy_cells()
	for index in enemy_count:
		var cell := _find_enemy_spawn_cell(
			enemy_rng,
			player_cell,
			occupied_cells
		)
		if cell.x < 0:
			push_warning("Could not find a free cell for an enemy")
			return
		occupied_cells[cell] = true
		_create_enemy(cell, enemy_rng.randi())


func _find_enemy_spawn_cell(
	enemy_rng: RandomNumberGenerator,
	player_cell: Vector2i,
	occupied_cells: Dictionary
) -> Vector2i:
	var grid_size := maze.grid_size()
	var minimum_distance := minf(
		MAX_ENEMY_START_DISTANCE,
		maxf(2.0, minf(grid_size.x, grid_size.y) * ENEMY_START_DISTANCE_RATIO)
	)
	for attempt in ENEMY_SPAWN_ATTEMPTS:
		var cell := maze.get_random_walkable_cell(enemy_rng, true)
		if cell.distance_to(player_cell) < minimum_distance \
				or occupied_cells.has(cell) \
				or _has_door_at(cell) \
				or maze.is_cell_safe(cell):
			continue
		return cell
	return Vector2i(-1, -1)


func _occupied_enemy_cells() -> Dictionary:
	var occupied_cells: Dictionary = {}
	for enemy in _enemies:
		occupied_cells[maze.world_to_cell(enemy.position)] = true
	return occupied_cells


func _living_enemy_count() -> int:
	var count := 0
	for enemy in _enemies:
		if not enemy.dead:
			count += 1
	return count


func _create_enemy_from_save(saved_data: Dictionary, index: int) -> void:
	var saved_position: Array = saved_data.get("position", [])
	var cell: Vector2i = maze.get_random_walkable_cell(
		_rng,
		true
	)
	if saved_position.size() == 2:
		cell = maze.world_to_cell(
			Vector2(float(saved_position[0]), float(saved_position[1]))
		)
	var enemy: Node = _create_enemy(cell, maze.generation_seed() + index)
	enemy.restore_state(saved_data)


func _create_enemy(cell: Vector2i, random_seed: int) -> Node:
	var enemy: Node = ENEMY_SCENE.instantiate()
	enemy.setup(self, maze, player, cell, random_seed)
	enemies.add_child(enemy)
	_enemies.append(enemy)
	return enemy


func _create_generated_doors() -> void:
	for door_spec in maze.generated_door_specs():
		_create_door(
			door_spec.cell,
			door_spec.horizontal_passage,
			bool(door_spec.get("locked", false)),
			false
		)


func _create_missing_generated_doors() -> void:
	for door_spec in maze.generated_door_specs():
		if _has_door_at(door_spec.cell):
			continue
		_create_door(
			door_spec.cell,
			door_spec.horizontal_passage,
			bool(door_spec.get("locked", false)),
			false
		)


func _has_door_at(cell: Vector2i) -> bool:
	for door in _doors:
		if door.cell == cell:
			return true
	return false


func _is_generated_door_data(door_data: Dictionary) -> bool:
	var saved_cell: Array = door_data.get("cell", [])
	if saved_cell.size() != 2:
		return false

	var cell := Vector2i(int(saved_cell[0]), int(saved_cell[1]))
	for door_spec in maze.generated_door_specs():
		if door_spec.cell == cell:
			return true
	return false


func _create_door_from_save(door_data: Dictionary) -> void:
	var saved_cell: Array = door_data.get("cell", [])
	if saved_cell.size() != 2:
		return

	var cell := Vector2i(int(saved_cell[0]), int(saved_cell[1]))
	var generated_spec := _generated_door_spec_at(cell)
	var is_generated := not generated_spec.is_empty()
	var locked := (
		bool(generated_spec.get("locked", false))
		if is_generated
		else bool(door_data.get("locked", false))
	)
	_create_door(
		cell,
		bool(
			generated_spec.get("horizontal_passage", true)
			if is_generated
			else door_data.get("horizontal_passage", true)
		),
		locked,
		false if locked else bool(door_data.get("open", false)),
		bool(door_data.get("player_placed", false))
	)


func _generated_door_spec_at(cell: Vector2i) -> Dictionary:
	for door_spec in maze.generated_door_specs():
		if door_spec.cell == cell:
			return door_spec
	return {}


func _create_door(
	cell: Vector2i,
	horizontal_passage: bool,
	locked: bool,
	is_open: bool,
	player_placed: bool = false
) -> Door:
	if locked:
		maze.carve_floor_cell(cell)
	elif maze.is_wall(cell):
		return null

	var door: Door = DOOR_SCENE.instantiate()
	door.setup(
		cell,
		horizontal_passage,
		locked,
		is_open,
		player_placed
	)
	doors.add_child(door)
	_doors.append(door)
	maze.set_door_closed(cell, not is_open)
	return door


func _toggle_player_door_at(target_cell: Vector2i) -> void:
	var player_cell := maze.world_to_cell(player.position)
	var cell_offset := target_cell - player_cell
	if absi(cell_offset.x) + absi(cell_offset.y) != 1:
		return

	var existing_door := _door_at(target_cell)
	if existing_door != null:
		if existing_door.player_placed:
			_remove_player_door(existing_door)
		return

	if maze.is_wall(target_cell):
		return

	var horizontal_passage := cell_offset.x != 0
	var wall_axis := (
		Vector2i.UP
		if horizontal_passage
		else Vector2i.LEFT
	)
	if not maze.is_wall(target_cell + wall_axis) \
			or not maze.is_wall(target_cell - wall_axis):
		return

	var door := _create_door(
		target_cell,
		horizontal_passage,
		false,
		false,
		true
	)
	if door != null:
		_refresh_safe_zone()


func _door_at(cell: Vector2i) -> Door:
	for door: Door in _doors:
		if door.cell == cell:
			return door
	return null


func _remove_player_door(door: Door) -> void:
	maze.set_door_closed(door.cell, false)
	_doors.erase(door)
	door.queue_free()
	_refresh_safe_zone()


func _refresh_safe_zone() -> void:
	var door_cells: Array[Vector2i] = []
	for door: Door in _doors:
		door_cells.append(door.cell)

	var station_door_cells: Array[Vector2i] = []
	for door_spec in maze.generated_door_specs():
		if bool(door_spec.get("station_door", false)):
			station_door_cells.append(door_spec.cell)

	maze.update_safe_zone(door_cells, station_door_cells)


func _interact_with_door() -> void:
	var player_cell: Vector2i = maze.world_to_cell(player.position)
	var facing: Vector2 = player.facing_direction()
	var closest_door: Node
	var closest_distance := INF

	for door in _doors:
		var cell_offset: Vector2i = door.cell - player_cell
		if absi(cell_offset.x) + absi(cell_offset.y) > 1:
			continue

		var direction_to_door: Vector2 = door.position - player.position
		if not direction_to_door.is_zero_approx() \
				and facing.dot(direction_to_door.normalized()) < 0.25:
			continue

		var distance: float = player.position.distance_to(door.position)
		if distance < closest_distance:
			closest_door = door
			closest_distance = distance

	if closest_door != null and closest_door.toggle(player.position):
		maze.set_door_closed(
			closest_door.cell,
			not closest_door.is_open
		)


func _interact_with_station() -> bool:
	var player_cell: Vector2i = maze.world_to_cell(player.position)
	var facing: Vector2 = player.facing_direction()
	var closest_station: Node
	var closest_distance := INF

	for station in _stations:
		var cell_offset: Vector2i = station.cell - player_cell
		if absi(cell_offset.x) + absi(cell_offset.y) > 1:
			continue

		var direction_to_station: Vector2 = station.position - player.position
		if not direction_to_station.is_zero_approx() \
				and facing.dot(direction_to_station.normalized()) < 0.25:
			continue

		var distance: float = player.position.distance_to(station.position)
		if distance < closest_distance:
			closest_station = station
			closest_distance = distance

	if closest_station == null:
		return false

	closest_station.discover()
	station_menu.open()
	return true


func refill_ammo() -> void:
	player.refill_ammo()
	_update_player_panel()


func refill_health() -> void:
	player.refill_health()
	_update_player_panel()


func spawn_enemy_bullet(start_position: Vector2, direction: Vector2) -> void:
	var bullet: Node = BULLET_SCENE.instantiate()
	bullet.setup(
		start_position + direction * BULLET_SPAWN_DISTANCE,
		direction,
		maze,
		_rng.randi_range(ENEMY_DAMAGE_MIN, ENEMY_DAMAGE_MAX),
		false
	)
	bullets.add_child(bullet)


func spawn_damage_number(
	start_position: Vector2,
	damage: int,
	direction: Vector2
) -> void:
	var damage_number: Node = DAMAGE_NUMBER_SCENE.instantiate()
	damage_number.setup(start_position, damage, direction)
	damage_numbers.add_child(damage_number)


func enemy_killed(_enemy: Node) -> void:
	_enemies_killed += 1
	call_deferred("_maintain_enemy_population")


func _maintain_enemy_population() -> void:
	var missing_enemies := ENEMY_COUNT - _living_enemy_count()
	if missing_enemies <= 0 or _defeated:
		return

	var player_cell := maze.world_to_cell(player.position)
	var occupied_cells := _occupied_enemy_cells()
	for index in missing_enemies:
		var cell := _find_enemy_spawn_cell(_rng, player_cell, occupied_cells)
		if cell.x < 0:
			push_warning("Could not respawn an enemy")
			return
		occupied_cells[cell] = true
		_create_enemy(cell, _rng.randi())


func _enemy_signal_strength() -> int:
	var player_cell: Vector2i = maze.world_to_cell(player.position)
	var closest_distance := INF
	for enemy in _enemies:
		if enemy.dead:
			continue
		var enemy_cell: Vector2i = maze.world_to_cell(enemy.position)
		closest_distance = minf(
			closest_distance,
			Vector2(enemy_cell - player_cell).length()
		)

	if closest_distance <= 10.0:
		return 3
	if closest_distance <= 20.0:
		return 2
	if closest_distance <= ENEMY_AUDIBLE_RANGE:
		return 1
	return 0


func _audible_enemy_indicators() -> Array[Dictionary]:
	var indicators: Array[Dictionary] = []
	for enemy in _enemies:
		if enemy.dead:
			continue

		var offset: Vector2 = enemy.position - player.position
		if _is_enemy_audible(enemy):
			indicators.append({
				"direction": offset.normalized(),
				"alerted": enemy.state != Enemy.State.PATROL,
			})
	return indicators


func _is_enemy_audible(enemy: Enemy) -> bool:
	return not enemy.dead \
			and enemy.position.distance_to(player.position) \
			<= ENEMY_AUDIBLE_RANGE * Maze.CELL_SIZE


func _alert_enemies_to_shot(shot_cell: Vector2i) -> void:
	await get_tree().create_timer(
		SHOT_REACTION_DELAY,
		false
	).timeout
	if _defeated:
		return

	for enemy in _enemies:
		if enemy.dead:
			continue
		var enemy_cell: Vector2i = maze.world_to_cell(enemy.position)
		if Vector2(enemy_cell - shot_cell).length() <= SHOT_HEARING_RANGE:
			enemy.hear_position(shot_cell)


func _show_defeat() -> void:
	_defeated = true
	player.controls_enabled = false
	defeat_menu.open(_enemies_killed)


func _shoot() -> void:
	if _shoot_cooldown > 0.0 or not player.controls_enabled \
			or not player.consume_ammo():
		return

	var direction: Vector2 = player.facing_direction()
	var bullet: Node = BULLET_SCENE.instantiate()
	bullet.setup(
		player.position + direction * BULLET_SPAWN_DISTANCE,
		direction,
		maze,
		_rng.randi_range(PLAYER_DAMAGE_MIN, PLAYER_DAMAGE_MAX),
		true
	)
	bullets.add_child(bullet)
	_shoot_cooldown = PLAYER_SHOOT_INTERVAL
	player.make_shot_noise()
	_alert_enemies_to_shot(maze.world_to_cell(player.position))
	_update_player_panel()
