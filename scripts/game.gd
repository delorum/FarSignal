extends Node2D

const DOOR_SCENE := preload("res://scenes/door.tscn")
const BULLET_SCENE := preload("res://scenes/bullet.tscn")
const STATION_SCENE := preload("res://scenes/station.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const START_FACING := Vector2.UP
const BULLET_SPAWN_DISTANCE := 22.0
const SIGNAL_LEVEL_HEIGHT := 100
const SIGNAL_RANGE := 100.0
const SIGNAL_STEP := 10.0
const START_LEVEL := 9
const START_ENEMY_COUNT := 3
const PLAYER_DAMAGE_MIN := 20
const PLAYER_DAMAGE_MAX := 27
const ENEMY_DAMAGE_MIN := 27
const ENEMY_DAMAGE_MAX := 36
const SHOT_HEARING_RANGE := 60.0
const PLAYER_SHOOT_INTERVAL := 1.0
const WEAPON_READY_COLOR := Color("58d68d")
const WEAPON_BLOCKED_COLOR := Color("d66b6b")
const PANEL_WIDTH_RATIO := 0.2
const MIN_PANEL_WIDTH := 260.0
const MAX_PANEL_WIDTH := 360.0

@onready var maze: Maze = $Maze
@onready var player: Player = $Player
@onready var doors: Node2D = $Doors
@onready var stations: Node2D = $Stations
@onready var enemies: Node2D = $Enemies
@onready var bullets: Node2D = $Bullets
@onready var camera: Camera2D = $Player/Camera2D
@onready var player_panel: Panel = $GameInterface/PlayerPanel
@onready var coordinates_label: Label = $GameInterface/PlayerPanel/Coordinates
@onready var health_value: Label = $GameInterface/PlayerPanel/Margin/VBox/HealthValue
@onready var health_bar: ProgressBar = $GameInterface/PlayerPanel/Margin/VBox/HealthBar
@onready var ammo_value: Label = $GameInterface/PlayerPanel/Margin/VBox/AmmoValue
@onready var ammo_bar: ProgressBar = $GameInterface/PlayerPanel/Margin/VBox/AmmoBar
@onready var weapon_state_value: Label = $GameInterface/PlayerPanel/Margin/VBox/WeaponStateValue
@onready var weapon_ready_bar: ProgressBar = $GameInterface/PlayerPanel/Margin/VBox/WeaponReadyBar
@onready var movement_mode_value: Label = $GameInterface/PlayerPanel/Margin/VBox/MovementModeValue
@onready var signal_meter: Control = $GameInterface/PlayerPanel/Margin/VBox/SignalMeter
@onready var enemy_meter: Control = $GameInterface/PlayerPanel/Margin/VBox/EnemyMeter
@onready var station_menu: Control = $StationOverlay/StationMenu
@onready var defeat_menu: Control = $DefeatOverlay/DefeatMenu

var _displayed_player_cell := Vector2i(-1, -1)
var _displayed_health := -1
var _displayed_ammo := -1
var _displayed_weapon_state := ""
var _displayed_walking := false
var _movement_mode_initialized := false
var _displayed_signal := -1
var _displayed_enemy_signal := -1
var _doors: Array[Node] = []
var _stations: Array[Node] = []
var _enemies: Array[Node] = []
var _enemies_killed := 0
var _levels_passed := 0
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
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var player_cell: Vector2i = maze.get_random_bottom_floor_cell(rng)
		player.position = maze.cell_to_world(player_cell)
		player.restore_facing_direction([START_FACING.x, START_FACING.y])
		_create_generated_stations()
		_create_generated_doors()
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
	if Input.is_action_just_pressed("shoot"):
		_shoot()

	if Input.is_action_just_pressed("interact"):
		if not _interact_with_station():
			_interact_with_door()

	_update_visibility()
	_update_coordinates()
	_update_player_panel()
	_update_enemies()


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
		enemy.update_visibility(maze.is_cell_visible(maze.world_to_cell(enemy.position)))


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

	var weapon_state := "ГОТОВО"
	if player.ammo <= 0:
		weapon_state = "НЕТ ПАТРОНОВ"
	elif _shoot_cooldown > 0.0:
		weapon_state = "ПЕРЕЗАРЯДКА"
	if weapon_state != _displayed_weapon_state:
		_displayed_weapon_state = weapon_state
		weapon_state_value.text = weapon_state
		weapon_state_value.modulate = (
			WEAPON_READY_COLOR
			if weapon_state == "ГОТОВО"
			else WEAPON_BLOCKED_COLOR
		)
	weapon_ready_bar.value = (
		0.0
		if player.ammo <= 0
		else (1.0 - _shoot_cooldown / PLAYER_SHOOT_INTERVAL) * 100.0
	)

	if not _movement_mode_initialized or player.walking != _displayed_walking:
		_movement_mode_initialized = true
		_displayed_walking = player.walking
		movement_mode_value.text = player.movement_mode_name()

	var signal_strength := _signal_strength()
	if signal_strength != _displayed_signal:
		_displayed_signal = signal_strength
		signal_meter.strength = signal_strength

	var enemy_signal_strength := _enemy_signal_strength()
	if enemy_signal_strength != _displayed_enemy_signal:
		_displayed_enemy_signal = enemy_signal_strength
		enemy_meter.strength = enemy_signal_strength
	player.set_enemy_directions(_audible_enemy_directions())


func save_game() -> bool:
	var save_data := {
		"version": SaveStore.SAVE_VERSION,
		"maze_seed": maze.generation_seed(),
		"player_position": [player.position.x, player.position.y],
		"player_facing": player.facing_direction_for_save(),
		"player_health": player.health,
		"player_ammo": player.ammo,
		"player_walking": player.walking,
		"explored_cells": maze.explored_cells_for_save(),
		"doors": _doors.map(func(door: Node): return door.save_data()),
		"discovered_stations": _stations.filter(
			func(station: Node): return station.discovered
		).map(func(station: Node): return station.level),
		"enemies": _enemies.map(func(enemy: Node): return enemy.save_data()),
		"enemies_killed": _enemies_killed,
		"levels_passed": _levels_passed,
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
	player.restore_movement_mode(bool(save_data.get("player_walking", false)))
	maze.restore_explored_cells(save_data.explored_cells)
	var discovered_stations: Array = save_data.get("discovered_stations", [])
	for station in _stations:
		station.discovered = discovered_stations.has(station.level)
	if save_data.has("doors"):
		for door_data in save_data.doors:
			if _is_generated_door_data(door_data):
				_create_door_from_save(door_data)
		_create_missing_generated_doors()
	else:
		_create_generated_doors()
	_enemies_killed = int(save_data.get("enemies_killed", 0))
	_levels_passed = int(save_data.get("levels_passed", 0))
	if save_data.has("enemies"):
		for index in save_data.enemies.size():
			_create_enemy_from_save(save_data.enemies[index], index)
	else:
		_create_generated_enemies(maze.world_to_cell(player.position))


func _create_generated_stations() -> void:
	for station_spec in maze.generated_station_specs():
		var station: Node = STATION_SCENE.instantiate()
		station.setup(station_spec.cell, station_spec.level)
		stations.add_child(station)
		_stations.append(station)


func _create_generated_enemies(player_cell: Vector2i) -> void:
	var enemy_rng := RandomNumberGenerator.new()
	enemy_rng.seed = maze.generation_seed() ^ 0x5e71a9
	var occupied_cells: Dictionary = {}
	for index in START_ENEMY_COUNT:
		var cell: Vector2i = maze.get_random_floor_cell_in_level(
			enemy_rng,
			START_LEVEL,
			true
		)
		for attempt in 64:
			if cell.distance_to(player_cell) >= 15.0 \
					and not occupied_cells.has(cell):
				break
			cell = maze.get_random_floor_cell_in_level(
				enemy_rng,
				START_LEVEL,
				true
			)
		occupied_cells[cell] = true
		_create_enemy(START_LEVEL, cell, enemy_rng.randi())


func _create_enemy_from_save(saved_data: Dictionary, index: int) -> void:
	var level: int = int(saved_data.get("level", START_LEVEL))
	var saved_position: Array = saved_data.get("position", [])
	var cell: Vector2i = maze.get_random_floor_cell_in_level(
		_rng,
		level,
		true
	)
	if saved_position.size() == 2:
		cell = maze.world_to_cell(
			Vector2(float(saved_position[0]), float(saved_position[1]))
		)
	var enemy: Node = _create_enemy(
		level,
		cell,
		maze.generation_seed() + index
	)
	enemy.restore_state(saved_data)


func _create_enemy(level: int, cell: Vector2i, random_seed: int) -> Node:
	var enemy: Node = ENEMY_SCENE.instantiate()
	enemy.setup(self, maze, player, level, cell, random_seed)
	enemies.add_child(enemy)
	_enemies.append(enemy)
	return enemy


func _create_generated_doors() -> void:
	for door_spec in maze.generated_door_specs():
		_create_door(
			door_spec.cell,
			door_spec.horizontal_passage,
			false,
			false
		)


func _create_missing_generated_doors() -> void:
	for door_spec in maze.generated_door_specs():
		if _has_door_at(door_spec.cell):
			continue
		_create_door(
			door_spec.cell,
			door_spec.horizontal_passage,
			false,
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

	_create_door(
		Vector2i(int(saved_cell[0]), int(saved_cell[1])),
		bool(door_data.get("horizontal_passage", true)),
		bool(door_data.get("locked", false)),
		bool(door_data.get("open", false))
	)


func _create_door(
	cell: Vector2i,
	horizontal_passage: bool,
	locked: bool,
	is_open: bool
) -> void:
	if locked:
		maze.carve_floor_cell(cell)
	elif maze.is_wall(cell):
		return

	var door: Node = DOOR_SCENE.instantiate()
	door.setup(cell, horizontal_passage, locked, is_open)
	doors.add_child(door)
	_doors.append(door)
	maze.set_door_closed(cell, not is_open)


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


func is_player_inside_station() -> bool:
	var player_cell: Vector2i = maze.world_to_cell(player.position)
	for station in _stations:
		var offset: Vector2i = player_cell - station.cell
		if absi(offset.x) <= 2 and absi(offset.y) <= 2:
			return true
	return false


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


func enemy_killed(_enemy: Node) -> void:
	_enemies_killed += 1


func _update_enemies() -> void:
	var player_level: int = maze.level_for_cell(
		maze.world_to_cell(player.position)
	)
	_levels_passed = maxi(_levels_passed, START_LEVEL - player_level)
	for enemy in _enemies:
		enemy.set_active(enemy.level == player_level)


func _enemy_signal_strength() -> int:
	var player_cell: Vector2i = maze.world_to_cell(player.position)
	var player_level: int = maze.level_for_cell(player_cell)
	var closest_distance := INF
	for enemy in _enemies:
		if enemy.dead or enemy.level != player_level:
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
	if closest_distance <= 30.0:
		return 1
	return 0


func _audible_enemy_directions() -> Array[Vector2]:
	var directions: Array[Vector2] = []
	var player_cell: Vector2i = maze.world_to_cell(player.position)
	var player_level: int = maze.level_for_cell(player_cell)
	for enemy in _enemies:
		if enemy.dead or enemy.level != player_level:
			continue

		var offset: Vector2 = enemy.position - player.position
		if offset.length() <= 30.0 * Maze.CELL_SIZE:
			directions.append(offset.normalized())
	return directions


func _alert_enemies_to_shot() -> void:
	if is_player_inside_station():
		return
	var player_cell: Vector2i = maze.world_to_cell(player.position)
	var player_level: int = maze.level_for_cell(player_cell)
	for enemy in _enemies:
		if enemy.dead or enemy.level != player_level:
			continue
		var enemy_cell: Vector2i = maze.world_to_cell(enemy.position)
		if Vector2(enemy_cell - player_cell).length() <= SHOT_HEARING_RANGE:
			enemy.hear_player()


func _show_defeat() -> void:
	_defeated = true
	player.controls_enabled = false
	defeat_menu.open(_levels_passed, _enemies_killed)


func _signal_strength() -> int:
	if _stations.is_empty():
		return 0

	var player_cell: Vector2i = maze.world_to_cell(player.position)
	var level := clampi(
		player_cell.y / SIGNAL_LEVEL_HEIGHT,
		0,
		_stations.size() - 1
	)
	if level < 0 or level >= _stations.size():
		return 0

	var station_cell: Vector2i = _stations[level].cell
	var distance := Vector2(player_cell - station_cell).length()
	if distance >= SIGNAL_RANGE:
		return 0
	return clampi(10 - floori(distance / SIGNAL_STEP), 1, 10)


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
	_alert_enemies_to_shot()
	_update_player_panel()
