extends Node2D

const DOOR_SCENE := preload("res://scenes/door.tscn")
const BULLET_SCENE := preload("res://scenes/bullet.tscn")
const DAMAGE_NUMBER_SCENE := preload("res://scenes/damage_number.tscn")
const STATION_SCENE := preload("res://scenes/station.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const BULLET_SPAWN_DISTANCE := 22.0
const BULLET_HALF_LENGTH := 6.0
const BULLET_HALF_WIDTH := 2.0
const ENEMY_COUNT := 40
const MAX_ENEMY_START_DISTANCE := 15.0
const ENEMY_START_DISTANCE_RATIO := 0.15
const ENEMY_RESPAWN_MIN_DISTANCE := 30.0
const ENEMY_SPAWN_ATTEMPTS := 256
const ENEMY_BASE_HEALTH := 100
const ENEMY_MAX_HEALTH := 615
const ENEMY_BASE_DAMAGE_MIN := 8
const ENEMY_BASE_DAMAGE_MAX := 12
const ENEMY_MAX_DAMAGE_MIN := 34
const ENEMY_MAX_DAMAGE_MAX := 38
const ENEMY_LEVEL_COUNT := 5
const SHOT_REACTION_DELAY := 2.0
const PLAYER_RECOIL_ENABLED := false
const MAP_MARKER_PATH_REFRESH_SECONDS := 5.0
const BUILD_ACTION_DURATION := 2.0
const MEGA_CORE_MIN_SAFE_ZONE_DISTANCE := 30
const MEGA_CORE_MAX_SAFE_ZONE_DISTANCE := 80
const MAX_ALERTED_ENEMIES := 3
const PURSUIT_STATUS_INTERVAL := 3.0
const COMBAT_MUSIC_HOLD_SECONDS := 10.0
const ENEMY_PATHFIND_BUDGET_PER_PHYSICS_FRAME := 4
const SLOW_FRAME_LOG_THRESHOLD := 0.08
const PERFORMANCE_LOGGING_ENABLED := true
const CRITICAL_HEALTH_THRESHOLD := 30
const CRITICAL_AMMO_THRESHOLD := 10
const ENERGY_CORE_PICKUP_DISTANCE := 0.65 * Maze.CELL_SIZE
const STATUS_VALUE_COLOR := Color(0.92, 0.94, 0.97, 1.0)
const STATUS_CRITICAL_COLOR := Color(0.9, 0.25, 0.27, 1.0)
const PANEL_WIDTH_RATIO := 0.2
const MIN_PANEL_WIDTH := 260.0
const MAX_PANEL_WIDTH := 360.0
const HIT_FLASH_DURATION := 0.25
const LOCKED_DOOR_LABEL := "закрыто"
const EXIT_DOOR_LOCKED_LABEL := "Нужна безопасная зона"
const SAFE_ZONE_BOUNDARY_DOOR_LABEL := "Граница безопасной зоны"
const DOOR_REMOVE_FORBIDDEN_LABEL := "нельзя удалить"
const INVENTORY_LIMIT_LABEL := "лимит"

enum BuildActionType {
	NONE,
	PLACE_DOOR,
	REMOVE_DOOR,
}

@onready var maze: Maze = $Maze
@onready var player: Player = $Player
@onready var doors: Node2D = $Doors
@onready var stations: Node2D = $Stations
@onready var enemies: Node2D = $Enemies
@onready var bullets: Node2D = $Bullets
@onready var damage_numbers: Node2D = $DamageNumbers
@onready var enemy_target_markers: Node2D = $EnemyTargetMarkers
@onready var mega_core_marker: Node2D = $MegaCoreMarker
@onready var build_action_marker: Node2D = $BuildActionMarker
@onready var camera: Camera2D = $Player/Camera2D
@onready var player_panel: Panel = $GameInterface/PlayerPanel
@onready var hit_flash: Panel = $GameInterface/HitFlash
@onready var health_value: Label = $GameInterface/PlayerPanel/Margin/VBox/HealthValue
@onready var health_bar: ProgressBar = $GameInterface/PlayerPanel/Margin/VBox/HealthBar
@onready var ammo_value: Label = $GameInterface/PlayerPanel/Margin/VBox/AmmoValue
@onready var ammo_bar: ProgressBar = $GameInterface/PlayerPanel/Margin/VBox/AmmoBar
@onready var damage_value: Label = $GameInterface/PlayerPanel/Margin/VBox/DamageValue
@onready var energy_cores_value: Label = $GameInterface/PlayerPanel/Margin/VBox/EnergyCoresValue
@onready var energy_value: Label = $GameInterface/PlayerPanel/Margin/VBox/EnergyValue
@onready var doors_value: Label = $GameInterface/PlayerPanel/Margin/VBox/DoorsValue
@onready var explored_cells_value: Label = $GameInterface/PlayerPanel/Margin/VBox/ExploredCellsValue
@onready var mega_core_value: Label = $GameInterface/PlayerPanel/Margin/VBox/MegaCoreValue
@onready var alert_value: Label = $GameInterface/PlayerPanel/Margin/VBox/AlertValue
@onready var detected_value: Label = $GameInterface/PlayerPanel/Margin/VBox/DetectedValue
@onready var enemy_in_safe_zone_value: Label = $GameInterface/PlayerPanel/Margin/VBox/EnemyInSafeZoneValue
@onready var station_menu: Control = $StationOverlay/StationMenu
@onready var defeat_menu: Control = $DefeatOverlay/DefeatMenu
@onready var victory_menu: Control = $VictoryOverlay/VictoryMenu

var _displayed_health := -1
var _displayed_ammo := -1
var _displayed_damage_min := -1
var _displayed_damage_max := -1
var _displayed_energy_cores := -1
var _displayed_energy := -1
var _displayed_door_inventory := -1
var _displayed_exploration_points := -1
var _displayed_mega_core_text := ""
var _doors: Array[Node] = []
var _stations: Array[Node] = []
var _enemies: Array[Node] = []
var _enemies_killed := 0
var _mega_cores_returned := 0
var _next_enemy_id := 1
var _defeated := false
var _victorious := false
var _station_instructions_seen := false
var _rng := RandomNumberGenerator.new()
var _hit_flash_tween: Tween
var _combat_music_active := false
var _combat_music_hold_left := 0.0
var _game_time_seconds := 0.0
var _map_marker_cell := Vector2i(-1, -1)
var _map_marker_path: Array[Vector2i] = []
var _map_marker_path_refresh_left := 0.0
var _build_action_type := BuildActionType.NONE
var _build_action_elapsed := 0.0
var _build_action_cell := Vector2i(-1, -1)
var _build_action_position := Vector2.ZERO
var _build_action_direction := Vector2.RIGHT
var _build_action_horizontal_passage := false
var _pursuit_status_refresh_left := 0.0
var _ai_budget_physics_frame := -1
var _ai_pathfind_used_this_frame := 0
var _perf_pathfind_requests := 0
var _perf_pathfind_denied := 0
var _perf_pathfind_usec := 0
var _perf_line_of_sight_checks := 0
var _perf_projectile_path_checks := 0


func _enter_tree() -> void:
	if not SaveStore.pending_save.is_empty():
		var maze_node: Maze = get_node("Maze")
		maze_node.generation_seed_override = int(
			SaveStore.pending_save.get("maze_seed", 0)
		)


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	AudioManager.set_combat_active(false)
	AudioManager.set_menu_music_active(false)
	_rng.randomize()
	enemy_target_markers.setup(maze, enemies)
	mega_core_marker.setup(maze, player, self)
	get_viewport().size_changed.connect(_update_adaptive_layout)
	player.damaged.connect(_show_hit_flash)
	player.damaged.connect(_cancel_build_action_from_damage)
	_update_adaptive_layout()
	var save_data := SaveStore.consume_pending_save()
	if save_data.is_empty():
		_create_generated_stations()
		var player_cell := maze.station_start_cell()
		player.position = maze.cell_to_world(player_cell)
		var start_facing := maze.station_start_facing()
		player.restore_facing_direction([start_facing.x, start_facing.y])
		if not _stations.is_empty():
			_stations[0].discover()
		_create_generated_doors()
		_refresh_safe_zone()
		_assign_new_mega_core()
		_create_generated_enemies(player_cell)
	else:
		_create_generated_stations()
		_restore_game(save_data)
		SaveStore.delete_save()

	_update_visibility()
	_update_player_panel()


func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _unhandled_input(event: InputEvent) -> void:
	pass


func _update_adaptive_layout() -> void:
	var viewport_width := get_viewport_rect().size.x
	var panel_width := clampf(
		viewport_width * PANEL_WIDTH_RATIO,
		MIN_PANEL_WIDTH,
		MAX_PANEL_WIDTH
	)
	player_panel.offset_left = -panel_width
	hit_flash.offset_right = -panel_width
	camera.position.x = panel_width * 0.5


func _show_hit_flash() -> void:
	if _hit_flash_tween != null:
		_hit_flash_tween.kill()
	hit_flash.modulate.a = 1.0
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_property(
		hit_flash,
		"modulate:a",
		0.0,
		HIT_FLASH_DURATION
	)


func _process(delta: float) -> void:
	if _victorious:
		return
	if not _defeated and player.health <= 0:
		_show_defeat()
		return

	_game_time_seconds += delta
	_update_build_action(delta)
	if Input.is_action_just_pressed("shoot"):
		_shoot()
	if Input.is_action_just_pressed("place_door") \
			and player.controls_enabled:
		_start_build_at(
			get_global_mouse_position()
		)

	if Input.is_action_just_pressed("interact"):
		if not _interact_with_station():
			_interact_with_door()

	_update_visibility()
	_update_pursuit_status(delta)
	_clear_reached_map_marker()
	_update_map_marker_path(delta)
	_pick_up_energy_cores()
	_pick_up_mega_core()
	_update_player_panel()
	_update_music_state(delta)
	_log_slow_frame_if_needed(delta)


func _update_music_state(delta: float) -> void:
	var has_alerted_enemy := false
	for enemy: Enemy in _enemies:
		if not enemy.dead and enemy.is_alerted():
			has_alerted_enemy = true
			break

	if has_alerted_enemy:
		_combat_music_hold_left = COMBAT_MUSIC_HOLD_SECONDS
	else:
		_combat_music_hold_left = maxf(
			0.0,
			_combat_music_hold_left - delta
		)
	var combat_active := has_alerted_enemy or _combat_music_hold_left > 0.0
	if combat_active != _combat_music_active:
		_combat_music_active = combat_active
		AudioManager.set_combat_active(combat_active)


func find_enemy_path(
	start: Vector2i,
	target: Vector2i,
	avoid_station: bool = false,
	explored_only: bool = false,
	ignore_closed_doors: bool = false
) -> Array[Vector2i]:
	_prepare_ai_budget_frame()
	_perf_pathfind_requests += 1
	if _ai_pathfind_used_this_frame >= ENEMY_PATHFIND_BUDGET_PER_PHYSICS_FRAME:
		_perf_pathfind_denied += 1
		return []

	_ai_pathfind_used_this_frame += 1
	var started_at := Time.get_ticks_usec()
	var path := maze.find_path(
		start,
		target,
		avoid_station,
		explored_only,
		ignore_closed_doors
	)
	_perf_pathfind_usec += Time.get_ticks_usec() - started_at
	return path


func enemy_path_budget_available() -> bool:
	_prepare_ai_budget_frame()
	return _ai_pathfind_used_this_frame < ENEMY_PATHFIND_BUDGET_PER_PHYSICS_FRAME


func enemy_has_line_of_sight(
	start_position: Vector2,
	target_position: Vector2,
	range_cells: float
) -> bool:
	_perf_line_of_sight_checks += 1
	return maze.has_line_of_sight(start_position, target_position, range_cells)


func can_enemy_become_alerted(enemy_to_alert: Enemy) -> bool:
	if enemy_to_alert.is_alerted():
		return true

	var alerted_count := 0
	for enemy: Enemy in _enemies:
		if enemy.dead:
			continue
		if enemy.is_alerted():
			alerted_count += 1
	return alerted_count < MAX_ALERTED_ENEMIES


func _prepare_ai_budget_frame() -> void:
	var current_frame := Engine.get_physics_frames()
	if current_frame == _ai_budget_physics_frame:
		return
	_ai_budget_physics_frame = current_frame
	_ai_pathfind_used_this_frame = 0


func _log_slow_frame_if_needed(delta: float) -> void:
	if PERFORMANCE_LOGGING_ENABLED and delta >= SLOW_FRAME_LOG_THRESHOLD:
		print(
			"slow frame %.1f ms | paths %d denied %d path %.2f ms | los %d projectile %d | enemies %d"
			% [
				delta * 1000.0,
				_perf_pathfind_requests,
				_perf_pathfind_denied,
				float(_perf_pathfind_usec) / 1000.0,
				_perf_line_of_sight_checks,
				_perf_projectile_path_checks,
				_living_enemy_count(),
			]
		)
	_reset_performance_counters()


func _reset_performance_counters() -> void:
	_perf_pathfind_requests = 0
	_perf_pathfind_denied = 0
	_perf_pathfind_usec = 0
	_perf_line_of_sight_checks = 0
	_perf_projectile_path_checks = 0


func has_map_marker() -> bool:
	return _map_marker_cell.x >= 0


func map_marker_cell() -> Vector2i:
	return _map_marker_cell


func map_marker_path() -> Array[Vector2i]:
	return _map_marker_path.duplicate()


func set_map_marker_cell(cell: Vector2i) -> void:
	_map_marker_cell = cell
	_refresh_map_marker_path()
	queue_redraw()


func clear_map_marker() -> void:
	_map_marker_cell = Vector2i(-1, -1)
	_map_marker_path.clear()
	queue_redraw()


func try_fast_travel_to_safe_cell(cell: Vector2i) -> bool:
	if not maze.is_cell_safe(maze.world_to_cell(player.position)) \
			or not maze.is_cell_safe(cell) \
			or not maze.is_cell_walkable(cell):
		return false

	player.position = maze.cell_to_world(cell)
	_update_visibility()
	_refresh_map_marker_path()
	_update_player_panel()
	return true


func _clear_reached_map_marker() -> void:
	if has_map_marker() and maze.world_to_cell(player.position) == _map_marker_cell:
		clear_map_marker()


func _update_map_marker_path(delta: float) -> void:
	if not has_map_marker():
		return

	_map_marker_path_refresh_left -= delta
	if _map_marker_path_refresh_left <= 0.0:
		_refresh_map_marker_path()


func _refresh_map_marker_path() -> void:
	_map_marker_path_refresh_left = MAP_MARKER_PATH_REFRESH_SECONDS
	if not has_map_marker():
		_map_marker_path.clear()
		return

	var player_cell := maze.world_to_cell(player.position)
	if player_cell == _map_marker_cell:
		clear_map_marker()
		return

	var explored_path := maze.find_path(
		player_cell,
		_map_marker_cell,
		false,
		true,
		true
	)
	if not explored_path.is_empty():
		_map_marker_path = explored_path
		return

	var full_path := maze.find_path(
		player_cell,
		_map_marker_cell,
		false,
		false,
		true
	)
	_map_marker_path.clear()
	for cell in full_path:
		_map_marker_path.append(cell)
		if not maze.is_cell_explored(cell):
			break


func _update_visibility() -> void:
	var newly_explored_floor_cells: Array[Vector2i] = maze.update_visibility(
		player.position,
		player.facing_direction()
	)
	for cell in newly_explored_floor_cells:
		player.discover_floor_cell(_enemy_level_for_y(cell.y))
	for door in _doors:
		door.update_visibility(
			maze.is_cell_visible(door.cell),
			maze.is_cell_explored(door.cell)
		)
	for station in _stations:
		var station_visible := maze.is_cell_visible(station.cell)
		station.update_visibility(
			station_visible,
			maze.is_cell_explored(station.cell)
		)
		if station_visible:
			station.discover()
	for enemy in _enemies:
		enemy.update_visibility(
			maze.is_cell_visible(maze.world_to_cell(enemy.position)),
			false
		)
	queue_redraw()


func _update_pursuit_status(delta: float) -> void:
	_pursuit_status_refresh_left -= delta
	if _pursuit_status_refresh_left > 0.0:
		return
	_pursuit_status_refresh_left = PURSUIT_STATUS_INTERVAL

	var has_alerted_enemies := false
	var player_detected := false
	var enemy_in_safe_zone := false
	for enemy: Enemy in _enemies:
		if enemy.dead:
			continue
		if maze.is_cell_safe(maze.world_to_cell(enemy.position)):
			enemy_in_safe_zone = true
		if not enemy.is_alerted():
			continue
		has_alerted_enemies = true
		var destination := enemy.movement_destination_cell()
		if player_detected or destination.x < 0:
			continue
		if maze.has_line_of_sight(
			maze.cell_to_world(destination),
			player.position,
			Enemy.VISION_RANGE
		):
			player_detected = true

	alert_value.visible = has_alerted_enemies
	detected_value.visible = player_detected
	enemy_in_safe_zone_value.visible = enemy_in_safe_zone


func _update_player_panel() -> void:
	var current_damage_min := player.damage_min()
	var current_damage_max := player.damage_max()
	if current_damage_min != _displayed_damage_min \
			or current_damage_max != _displayed_damage_max:
		_displayed_damage_min = current_damage_min
		_displayed_damage_max = current_damage_max
		damage_value.text = "Урон: %d-%d" % [
			current_damage_min,
			current_damage_max,
		]
	if player.health != _displayed_health:
		_displayed_health = player.health
		health_value.text = "%d / %d" % [player.health, player.max_health]
		health_bar.max_value = player.max_health
		health_value.modulate = (
			STATUS_CRITICAL_COLOR
			if player.health <= CRITICAL_HEALTH_THRESHOLD
			else STATUS_VALUE_COLOR
		)
		health_bar.value = player.health

	if player.ammo != _displayed_ammo:
		_displayed_ammo = player.ammo
		ammo_value.text = "%d / %d" % [player.ammo, player.max_ammo]
		ammo_bar.max_value = player.max_ammo
		ammo_value.modulate = (
			STATUS_CRITICAL_COLOR
			if player.ammo <= CRITICAL_AMMO_THRESHOLD
			else STATUS_VALUE_COLOR
		)
		ammo_bar.value = player.ammo
	if player.energy_cores != _displayed_energy_cores:
		_displayed_energy_cores = player.energy_cores
		energy_cores_value.text = "Энергоядра: %d" % player.energy_cores
	if player.energy != _displayed_energy:
		_displayed_energy = player.energy
		energy_value.text = "Энергия: %d" % player.energy
	if player.door_inventory != _displayed_door_inventory:
		_displayed_door_inventory = player.door_inventory
		doors_value.text = "Двери: %d" % player.door_inventory
	if player.exploration_points != _displayed_exploration_points:
		_displayed_exploration_points = player.exploration_points
		explored_cells_value.text = (
			"Очки исследования: %d" % player.exploration_points
		)
	var mega_core_text := _mega_core_status_text()
	if mega_core_text != _displayed_mega_core_text:
		_displayed_mega_core_text = mega_core_text
		mega_core_value.text = mega_core_text
	var weapon_readiness := 1.0 if player.ammo > 0 else 0.0
	player.set_aim_indicator_readiness(weapon_readiness)


func _pick_up_energy_cores() -> void:
	for enemy: Enemy in _enemies:
		if not enemy.has_energy_core():
			continue
		if enemy.position.distance_to(player.position) > ENERGY_CORE_PICKUP_DISTANCE:
			continue
		if enemy.collect_energy_core():
			player.collect_energy_core(enemy.energy_core_value())
			AudioManager.play_mega_core_pickup()
			_update_player_panel()


func _pick_up_mega_core() -> void:
	if player.has_mega_core or player.mega_core_cell.x < 0:
		return
	if maze.world_to_cell(player.position) != player.mega_core_cell:
		return
	if player.collect_mega_core():
		AudioManager.play_mega_core_pickup()
		_update_player_panel()
		queue_redraw()


func _mega_core_status_text() -> String:
	if player.has_mega_core:
		return "Мегаядро: вернуть"
	if player.mega_core_cell.x >= 0:
		return "Мегаядро: зона %d" % _enemy_level_for_y(
			player.mega_core_cell.y
		)
	return "Мегаядро: не найдено"


func save_game() -> bool:
	var save_data := {
		"version": SaveStore.SAVE_VERSION,
		"maze_size": [maze.grid_size().x, maze.grid_size().y],
		"maze_seed": maze.generation_seed(),
		"player_position": [player.position.x, player.position.y],
		"player_facing": player.facing_direction_for_save(),
		"player_health": player.health,
		"player_ammo": player.ammo,
		"player_energy_cores": player.energy_cores,
		"player_energy_core_energy": player.energy_core_energy,
		"player_energy": player.energy,
		"player_energy_received_total": player.energy_received_total,
		"player_energy_spent_total": player.energy_spent_total,
		"player_doors": player.door_inventory,
		"player_exploration_points": player.exploration_points,
		"player_mega_core_cell": [
			player.mega_core_cell.x,
			player.mega_core_cell.y,
		],
		"player_has_mega_core": player.has_mega_core,
		"player_mega_core_energy_value": player.mega_core_energy_value,
		"player_damage_upgrade_level": player.damage_upgrade_level,
		"player_health_upgrade_level": player.health_upgrade_level,
		"player_ammo_upgrade_level": player.ammo_upgrade_level,
		"map_marker_cell": [
			_map_marker_cell.x,
			_map_marker_cell.y,
		],
		"explored_cells": maze.explored_cells_for_save(),
		"doors": _doors.map(func(door: Node): return door.save_data()),
		"removed_generated_doors": _removed_generated_door_cells_for_save(),
		"station_discovered": (
			not _stations.is_empty() and _stations[0].discovered
		),
		"discovered_station_ids": _discovered_station_ids_for_save(),
		"station_instructions_seen": _station_instructions_seen,
		"enemies": _enemies.map(func(enemy: Node): return enemy.save_data()),
		"enemies_killed": _enemies_killed,
		"mega_cores_returned": _mega_cores_returned,
	}
	return SaveStore.write_save(save_data)


func save_file_path() -> String:
	return SaveStore.save_file_path()


func _discovered_station_ids_for_save() -> Array[int]:
	var station_ids: Array[int] = []
	for station in _stations:
		if station.discovered:
			station_ids.append(station.station_id)
	return station_ids


func _restore_game(save_data: Dictionary) -> void:
	var saved_position: Array = save_data.player_position
	player.position = Vector2(
		float(saved_position[0]),
		float(saved_position[1])
	)
	player.restore_facing_direction(save_data.player_facing)
	var saved_mega_core_cell := Vector2i(-1, -1)
	var saved_mega_core_cell_data: Array = save_data.get(
		"player_mega_core_cell",
		[]
	)
	if saved_mega_core_cell_data.size() == 2:
		saved_mega_core_cell = Vector2i(
			int(saved_mega_core_cell_data[0]),
			int(saved_mega_core_cell_data[1])
		)
	player.restore_status(
		int(save_data.get("player_health", Player.MAX_HEALTH)),
		int(save_data.get("player_ammo", Player.MAX_AMMO)),
		int(save_data.get("player_energy_cores", 0)),
		int(save_data.get("player_energy", 0)),
		int(save_data.get("player_doors", 0)),
		int(save_data.get("player_exploration_points", 0)),
		saved_mega_core_cell,
		bool(save_data.get("player_has_mega_core", false)),
		int(save_data.get("player_damage_upgrade_level", 0)),
		int(save_data.get("player_health_upgrade_level", 0)),
		int(save_data.get("player_ammo_upgrade_level", 0)),
		int(save_data.get("player_energy_core_energy", 0)),
		int(save_data.get("player_energy_received_total", 0)),
		int(save_data.get("player_energy_spent_total", 0)),
		int(save_data.get(
			"player_mega_core_energy_value",
			Player.EQUAL_LEVEL_MEGA_CORE_ENERGY
		))
	)
	var saved_map_marker_cell: Array = save_data.get("map_marker_cell", [])
	if saved_map_marker_cell.size() == 2:
		_map_marker_cell = Vector2i(
			int(saved_map_marker_cell[0]),
			int(saved_map_marker_cell[1])
		)
	maze.restore_explored_cells(save_data.explored_cells)
	var discovered_station_ids: Array = save_data.get(
		"discovered_station_ids",
		[]
	)
	for station in _stations:
		station.discovered = discovered_station_ids.has(station.station_id) \
				or station.station_id == 1 \
				and bool(save_data.get("station_discovered", false))
	_station_instructions_seen = bool(
		save_data.get("station_instructions_seen", false)
	)
	if save_data.has("doors"):
		var removed_generated_doors := _removed_generated_door_cells_from_save(
			save_data.get("removed_generated_doors", [])
		)
		for door_data in save_data.doors:
			if _is_generated_door_data(door_data) \
					or bool(door_data.get("player_placed", false)):
				_create_door_from_save(door_data)
		_create_missing_generated_doors(removed_generated_doors)
	else:
		_create_generated_doors()
	_refresh_safe_zone()
	if not player.has_mega_core and player.mega_core_cell.x < 0:
		_assign_new_mega_core()
	_enemies_killed = int(save_data.get("enemies_killed", 0))
	_mega_cores_returned = int(save_data.get("mega_cores_returned", 0))
	if save_data.has("enemies"):
		for index in save_data.enemies.size():
			_create_enemy_from_save(save_data.enemies[index], index)
		_create_generated_enemies(maze.world_to_cell(player.position))
	else:
		_create_generated_enemies(maze.world_to_cell(player.position))


func _create_generated_stations() -> void:
	for station_spec in maze.generated_station_specs():
		var station: Node = STATION_SCENE.instantiate()
		station.setup(
			station_spec.cell,
			int(station_spec.get("station_id", 1))
		)
		stations.add_child(station)
		_stations.append(station)


func _create_generated_enemies(
	player_cell: Vector2i
) -> void:
	var enemy_rng := RandomNumberGenerator.new()
	enemy_rng.seed = maze.generation_seed() ^ 0x5e71a9
	var occupied_cells := _occupied_enemy_cells()
	var target_count := _target_enemy_count()
	var remaining := maxi(0, target_count - _living_enemy_count())
	for level in range(1, ENEMY_LEVEL_COUNT + 1):
		var missing_for_level := maxi(
			0,
			_target_enemy_count_for_level(level, target_count)
					- _living_enemy_count_for_level(level)
		)
		for index in mini(missing_for_level, remaining):
			var cell := _find_enemy_spawn_cell(
				enemy_rng,
				player_cell,
				occupied_cells,
				level
			)
			if cell.x < 0:
				push_warning("Could not find a free cell for enemy level %d" % level)
				return
			occupied_cells[cell] = true
			_create_enemy(cell, enemy_rng.randi(), -1, level)
			remaining -= 1
		if remaining <= 0:
			return


func _find_enemy_spawn_cell(
	enemy_rng: RandomNumberGenerator,
	player_cell: Vector2i,
	occupied_cells: Dictionary,
	enemy_level: int,
	restrict_to_level_zone: bool = true,
	minimum_distance_override: float = -1.0
) -> Vector2i:
	var grid_size := maze.grid_size()
	var zone_bounds := _enemy_zone_bounds(enemy_level)
	var minimum_distance := (
		minimum_distance_override
		if minimum_distance_override >= 0.0
		else minf(
			MAX_ENEMY_START_DISTANCE,
			maxf(
				2.0,
				minf(grid_size.x, grid_size.y) * ENEMY_START_DISTANCE_RATIO
			)
		)
	)
	for attempt in ENEMY_SPAWN_ATTEMPTS:
		var cell := (
			maze.get_random_walkable_cell_in_y_range(
				enemy_rng,
				zone_bounds.x,
				zone_bounds.y
			)
			if restrict_to_level_zone
			else maze.get_random_walkable_cell(enemy_rng)
		)
		if not _enemy_spawn_cell_is_valid(
			cell,
			player_cell,
			occupied_cells,
			minimum_distance
		):
			continue
		return cell
	return Vector2i(-1, -1)


func _enemy_spawn_cell_is_valid(
	cell: Vector2i,
	player_cell: Vector2i,
	occupied_cells: Dictionary,
	minimum_distance: float
) -> bool:
	return cell.distance_to(player_cell) >= minimum_distance \
			and not occupied_cells.has(cell) \
			and not _has_door_at(cell) \
			and not maze.is_cell_safe(cell) \
			and maze.is_cell_walkable(cell)


func _occupied_enemy_cells() -> Dictionary:
	var occupied_cells: Dictionary = {}
	for enemy: Enemy in _enemies:
		if enemy.dead:
			continue
		occupied_cells[maze.world_to_cell(enemy.position)] = true
	return occupied_cells


func _living_enemy_count() -> int:
	var count := 0
	for enemy in _enemies:
		if not enemy.dead:
			count += 1
	return count


func _living_enemy_count_for_level(level: int) -> int:
	var count := 0
	for enemy: Enemy in _enemies:
		if not enemy.dead and enemy.enemy_level == level:
			count += 1
	return count


func _target_enemy_count_for_level(level: int, total_count: int) -> int:
	var maximum_per_level := ceili(
		float(ENEMY_COUNT) / float(ENEMY_LEVEL_COUNT)
	)
	var enemies_reserved_for_higher_levels := (
		ENEMY_LEVEL_COUNT - clampi(level, 1, ENEMY_LEVEL_COUNT)
	) * maximum_per_level
	return clampi(
		total_count - enemies_reserved_for_higher_levels,
		0,
		maximum_per_level
	)


func _enemy_zone_bounds(level: int) -> Vector2i:
	var clamped_level := clampi(level, 1, ENEMY_LEVEL_COUNT)
	var zone_from_top := ENEMY_LEVEL_COUNT - clamped_level
	var minimum_y := floori(
		float(zone_from_top * Maze.ROWS) / float(ENEMY_LEVEL_COUNT)
	)
	var maximum_y := floori(
		float((zone_from_top + 1) * Maze.ROWS) / float(ENEMY_LEVEL_COUNT)
	) - 1
	return Vector2i(minimum_y, maximum_y)


func _enemy_level_for_y(cell_y: int) -> int:
	var zone_from_top := clampi(
		floori(float(cell_y * ENEMY_LEVEL_COUNT) / float(Maze.ROWS)),
		0,
		ENEMY_LEVEL_COUNT - 1
	)
	return ENEMY_LEVEL_COUNT - zone_from_top


func _enemy_level_progress(level: int) -> float:
	return float(clampi(level, 1, ENEMY_LEVEL_COUNT) - 1) \
			/ float(ENEMY_LEVEL_COUNT - 1)


func _enemy_health_for_level(level: int) -> int:
	return roundi(lerpf(
		ENEMY_BASE_HEALTH,
		ENEMY_MAX_HEALTH,
		_enemy_level_progress(level)
	))


func _enemy_damage_min_for_level(level: int) -> int:
	return roundi(lerpf(
		ENEMY_BASE_DAMAGE_MIN,
		ENEMY_MAX_DAMAGE_MIN,
		_enemy_level_progress(level)
	))


func _enemy_damage_max_for_level(level: int) -> int:
	return roundi(lerpf(
		ENEMY_BASE_DAMAGE_MAX,
		ENEMY_MAX_DAMAGE_MAX,
		_enemy_level_progress(level)
	))


func _target_enemy_count() -> int:
	var total_floor_cells := maze.floor_cell_count()
	if total_floor_cells <= 0:
		return 0
	var unsafe_floor_cells := maxi(
		0,
		total_floor_cells - maze.safe_floor_cell_count()
	)
	return clampi(
		roundi(
			float(ENEMY_COUNT) * float(unsafe_floor_cells)
			/ float(total_floor_cells)
		),
		0,
		ENEMY_COUNT
	)


func station_statistics() -> Dictionary:
	return {
		"explored_cells": maze.explored_floor_cell_count(),
		"safe_zone_size": maze.safe_floor_cell_count(),
		"total_floor_cells": maze.floor_cell_count(),
		"enemies_killed": _enemies_killed,
		"living_enemies": _living_enemy_count(),
		"mega_cores_returned": _mega_cores_returned,
		"energy_received": player.energy_received_total,
		"energy_spent": player.energy_spent_total,
		"energy_remaining": player.energy,
		"enemy_level_summary": _enemy_level_summary(),
	}


func _enemy_level_summary() -> String:
	var lines: Array[String] = []
	for level in range(1, ENEMY_LEVEL_COUNT + 1):
		lines.append("%d: %d здоровья, урон %d–%d" % [
			level,
			_enemy_health_for_level(level),
			_enemy_damage_min_for_level(level),
			_enemy_damage_max_for_level(level),
		])
	return "\n".join(lines)


func _create_enemy_from_save(saved_data: Dictionary, index: int) -> void:
	var saved_position: Array = saved_data.get("position", [])
	var cell := Vector2i(-1, -1)
	var enemy_level := int(saved_data.get("enemy_level", 0))
	if saved_position.size() == 2:
		cell = maze.world_to_cell(
			Vector2(float(saved_position[0]), float(saved_position[1]))
		)
	else:
		if enemy_level <= 0:
			enemy_level = 1
		cell = _find_enemy_spawn_cell(
			_rng,
			maze.world_to_cell(player.position),
			_occupied_enemy_cells(),
			enemy_level
		)
	if cell.x < 0:
		push_warning("Could not restore an enemy without a valid position")
		return
	var saved_enemy_id := int(saved_data.get("enemy_id", _next_enemy_id))
	if enemy_level <= 0:
		enemy_level = _enemy_level_for_y(cell.y)
	_next_enemy_id = maxi(_next_enemy_id, saved_enemy_id + 1)
	var enemy: Node = _create_enemy(
		cell,
		maze.generation_seed() + index,
		saved_enemy_id,
		enemy_level
	)
	enemy.restore_state(saved_data)


func _create_enemy(
	cell: Vector2i,
	random_seed: int,
	assigned_enemy_id: int = -1,
	enemy_level: int = 1
) -> Node:
	var enemy_id := assigned_enemy_id
	if enemy_id < 0:
		enemy_id = _next_enemy_id
		_next_enemy_id += 1
	else:
		_next_enemy_id = maxi(_next_enemy_id, enemy_id + 1)

	var enemy: Node = ENEMY_SCENE.instantiate()
	enemy.setup(self, maze, player, cell, random_seed, enemy_id)
	var zone_bounds := _enemy_zone_bounds(enemy_level)
	enemy.configure_level(
		enemy_level,
		_enemy_health_for_level(enemy_level),
		_enemy_damage_min_for_level(enemy_level),
		_enemy_damage_max_for_level(enemy_level),
		zone_bounds.x,
		zone_bounds.y
	)
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


func _create_missing_generated_doors(removed_generated_doors: Dictionary = {}) -> void:
	for door_spec in maze.generated_door_specs():
		if _has_door_at(door_spec.cell):
			continue
		if removed_generated_doors.has(door_spec.cell):
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


func _removed_generated_door_cells_for_save() -> Array:
	var removed_cells: Array = []
	for door_spec in maze.generated_door_specs():
		if not _has_door_at(door_spec.cell):
			removed_cells.append([door_spec.cell.x, door_spec.cell.y])
	return removed_cells


func _removed_generated_door_cells_from_save(saved_cells: Array) -> Dictionary:
	var removed_cells: Dictionary = {}
	for saved_cell in saved_cells:
		if not saved_cell is Array or saved_cell.size() != 2:
			continue
		removed_cells[Vector2i(int(saved_cell[0]), int(saved_cell[1]))] = true
	return removed_cells


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


func _start_door_action_at(target_cell: Vector2i) -> void:
	var player_cell := maze.world_to_cell(player.position)
	var cell_offset := target_cell - player_cell
	if absi(cell_offset.x) + absi(cell_offset.y) != 1:
		return

	var existing_door := _door_at(target_cell)
	if existing_door != null:
		if not player.can_store_door():
			show_door_error(
				existing_door.position + Vector2(0.0, -Door.CELL_SIZE * 0.35),
				INVENTORY_LIMIT_LABEL,
				Vector2.UP
			)
			return
		if _can_remove_door(existing_door):
			_start_build_action(
				BuildActionType.REMOVE_DOOR,
				target_cell,
				maze.cell_to_world(target_cell),
				Vector2.RIGHT,
				false
			)
		return

	if player.door_inventory <= 0:
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

	_start_build_action(
		BuildActionType.PLACE_DOOR,
		target_cell,
		maze.cell_to_world(target_cell),
		Vector2.RIGHT,
		horizontal_passage
	)


func _finish_place_door() -> void:
	var player_cell := maze.world_to_cell(player.position)
	var cell_offset := _build_action_cell - player_cell
	if absi(cell_offset.x) + absi(cell_offset.y) != 1 \
			or player.door_inventory <= 0 \
			or maze.is_wall(_build_action_cell) \
			or _door_at(_build_action_cell) != null:
		return

	var wall_axis := (
		Vector2i.UP
		if _build_action_horizontal_passage
		else Vector2i.LEFT
	)
	if not maze.is_wall(_build_action_cell + wall_axis) \
			or not maze.is_wall(_build_action_cell - wall_axis):
		return

	var door := _create_door(
		_build_action_cell,
		_build_action_horizontal_passage,
		false,
		false,
		true
	)
	if door != null:
		player.door_inventory -= 1
		AudioManager.play_door_place()
		_refresh_safe_zone()
		_update_player_panel()


func _finish_remove_door() -> void:
	var existing_door := _door_at(_build_action_cell)
	if existing_door != null and player.can_store_door() \
			and _can_remove_door(existing_door):
		_remove_door(existing_door)


func _start_build_at(target_position: Vector2) -> void:
	if _build_action_type != BuildActionType.NONE:
		return
	_start_door_action_at(maze.world_to_cell(target_position))


func _start_build_action(
	action_type: BuildActionType,
	target_cell: Vector2i,
	world_position: Vector2,
	direction: Vector2,
	horizontal_passage: bool
) -> void:
	_build_action_type = action_type
	_build_action_elapsed = 0.0
	_build_action_cell = target_cell
	_build_action_position = world_position
	_build_action_direction = (
		Vector2.RIGHT
		if direction.is_zero_approx()
		else direction.normalized()
	)
	_build_action_horizontal_passage = horizontal_passage
	build_action_marker.show_action(
		maze.cell_to_world(target_cell),
		_build_action_label(action_type)
	)


func _update_build_action(delta: float) -> void:
	if _build_action_type == BuildActionType.NONE:
		return
	if player.is_moving():
		_cancel_build_action()
		return

	_build_action_elapsed += delta
	build_action_marker.set_progress(
		_build_action_elapsed / BUILD_ACTION_DURATION
	)
	if _build_action_elapsed < BUILD_ACTION_DURATION:
		return

	var completed_action := _build_action_type
	match completed_action:
		BuildActionType.PLACE_DOOR:
			_finish_place_door()
		BuildActionType.REMOVE_DOOR:
			_finish_remove_door()
	_clear_build_action()


func _cancel_build_action_from_damage() -> void:
	_cancel_build_action()


func _cancel_build_action() -> void:
	if _build_action_type == BuildActionType.NONE:
		return
	_clear_build_action()


func _clear_build_action() -> void:
	_build_action_type = BuildActionType.NONE
	_build_action_elapsed = 0.0
	_build_action_cell = Vector2i(-1, -1)
	_build_action_position = Vector2.ZERO
	_build_action_direction = Vector2.RIGHT
	_build_action_horizontal_passage = false
	build_action_marker.hide_action()


func _build_action_label(action_type: BuildActionType) -> String:
	return (
		"демонтаж"
		if action_type == BuildActionType.REMOVE_DOOR
		else "установка"
	)


func _door_at(cell: Vector2i) -> Door:
	for door: Door in _doors:
		if door.cell == cell:
			return door
	return null


func _can_remove_door(door: Door) -> bool:
	if _is_start_station_locked_door(door) or _is_exit_door(door):
		show_door_error(
			door.position + Vector2(0.0, -Door.CELL_SIZE * 0.35),
			DOOR_REMOVE_FORBIDDEN_LABEL,
			Vector2.UP
		)
		return false

	if not door.player_placed and _generated_door_spec_at(door.cell).is_empty():
		return false

	if _door_sides_have_matching_safe_zone(door):
		return true

	show_door_error(
		door.position + Vector2(0.0, -Door.CELL_SIZE * 0.35),
		SAFE_ZONE_BOUNDARY_DOOR_LABEL,
		Vector2.UP
	)
	return false


func _door_sides_have_matching_safe_zone(door: Door) -> bool:
	var side_direction := Vector2i.RIGHT if door.horizontal_passage else Vector2i.DOWN
	var first_side := door.cell - side_direction
	var second_side := door.cell + side_direction
	return maze.is_cell_safe(first_side) == maze.is_cell_safe(second_side)


func _remove_door(door: Door) -> void:
	AudioManager.play_door_remove()
	maze.set_door_closed(door.cell, false)
	_doors.erase(door)
	door.queue_free()
	if player.can_store_door():
		player.door_inventory += 1
	_refresh_safe_zone()
	_update_player_panel()


func _refresh_safe_zone() -> void:
	var door_cells: Array[Vector2i] = []
	for door: Door in _doors:
		door_cells.append(door.cell)

	maze.update_safe_zone(door_cells)
	_assert_station_floor_is_safe()
	call_deferred("_maintain_enemy_population")


func _assert_station_floor_is_safe() -> void:
	var center := maze.station_cell()
	for y in range(-Maze.STATION_FLOOR_RADIUS, Maze.STATION_FLOOR_RADIUS + 1):
		for x in range(-Maze.STATION_FLOOR_RADIUS, Maze.STATION_FLOOR_RADIUS + 1):
			var cell := center + Vector2i(x, y)
			assert(
				maze.is_cell_safe(cell),
				"Station floor cell %s must belong to a safe zone" % cell
			)


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

	if closest_door == null:
		return

	if _is_exit_door(closest_door):
		_interact_with_exit_door(closest_door)
		return

	if closest_door.locked and _is_start_station_locked_door(closest_door):
		show_door_error(
			closest_door.position + Vector2(0.0, -Door.CELL_SIZE * 0.35),
			LOCKED_DOOR_LABEL,
			Vector2.UP
		)
		return

	if closest_door.toggle(player.position):
		if closest_door.is_open:
			AudioManager.play_door_open()
		else:
			AudioManager.play_door_close()
		maze.set_door_closed(
			closest_door.cell,
			not closest_door.is_open
		)


func _interact_with_exit_door(door: Door) -> void:
	if not maze.is_cell_safe(door.cell + Vector2i.DOWN):
		show_door_error(
			door.position + Vector2(0.0, Door.CELL_SIZE * 0.35),
			EXIT_DOOR_LOCKED_LABEL,
			Vector2.DOWN
		)
		return

	if door.toggle(player.position):
		AudioManager.play_door_open()
		maze.set_door_closed(door.cell, false)
		_show_victory()


func _is_exit_door(door: Door) -> bool:
	return bool(_generated_door_spec_at(door.cell).get("exit_door", false))


func _is_start_station_locked_door(door: Door) -> bool:
	return door.cell == maze.station_start_cell() + Vector2i.DOWN


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

	var show_instructions: bool = closest_station.station_id == 1 \
			and not _station_instructions_seen
	if closest_station.station_id == 1:
		_station_instructions_seen = true
	closest_station.discover()
	station_menu.open(show_instructions, closest_station.station_id)
	return true


func buy_ammo() -> bool:
	var bought := player.buy_ammo()
	_update_player_panel()
	return bought


func buy_health() -> bool:
	var bought := player.buy_health()
	_update_player_panel()
	return bought


func buy_door() -> bool:
	var bought := player.buy_door()
	_update_player_panel()
	return bought


func upgrade_player_damage(station_id: int) -> bool:
	var upgraded := player.upgrade_damage(station_id)
	if upgraded:
		_update_enemy_level_labels()
	_update_player_panel()
	return upgraded


func upgrade_player_health(station_id: int) -> bool:
	var upgraded := player.upgrade_health(station_id)
	if upgraded:
		_update_enemy_level_labels()
	_update_player_panel()
	return upgraded


func upgrade_player_ammo(station_id: int) -> bool:
	var upgraded := player.upgrade_ammo(station_id)
	if upgraded:
		_update_enemy_level_labels()
	_update_player_panel()
	return upgraded


func _update_enemy_level_labels() -> void:
	for enemy: Enemy in _enemies:
		enemy.update_level_label()


func can_upgrade_player_damage(station_id: int) -> bool:
	return player.can_upgrade_damage_at_station(station_id)


func can_upgrade_player_health(station_id: int) -> bool:
	return player.can_upgrade_health_at_station(station_id)


func can_upgrade_player_ammo(station_id: int) -> bool:
	return player.can_upgrade_ammo_at_station(station_id)


func exchange_energy_cores() -> bool:
	var exchanged := player.exchange_energy_cores()
	_update_player_panel()
	return exchanged


func exchange_exploration_points() -> bool:
	var exchanged := player.exchange_exploration_points()
	_update_player_panel()
	return exchanged


func return_mega_core() -> bool:
	if not player.return_mega_core():
		return false
	_mega_cores_returned += 1
	_assign_new_mega_core()
	_update_player_panel()
	return true


func _assign_new_mega_core() -> void:
	var cell := _find_mega_core_cell()
	if cell.x >= 0:
		var core_energy_value := Player.mega_core_reward(
			_enemy_level_for_y(cell.y),
			player.current_level()
		)
		player.assign_mega_core(cell, core_energy_value)
		queue_redraw()


func _find_mega_core_cell() -> Vector2i:
	var safe_zone_distances := _safe_zone_distance_squared_map()
	return _find_valid_mega_core_cell(safe_zone_distances)


func _find_valid_mega_core_cell(
	safe_zone_distances: PackedFloat64Array
) -> Vector2i:
	for attempt in 512:
		var cell := maze.get_random_floor_cell(_rng)
		if _mega_core_cell_is_valid(cell, safe_zone_distances):
			return cell

	var grid_size := maze.grid_size()
	for y in grid_size.y:
		for x in grid_size.x:
			var cell := Vector2i(x, y)
			if _mega_core_cell_is_valid(cell, safe_zone_distances):
				return cell
	return Vector2i(-1, -1)


func _safe_zone_distance_squared_map() -> PackedFloat64Array:
	var grid_size := maze.grid_size()
	var intermediate := PackedFloat64Array()
	intermediate.resize(grid_size.x * grid_size.y)
	var line := PackedFloat64Array()
	line.resize(grid_size.y)

	for x in grid_size.x:
		for y in grid_size.y:
			line[y] = 0.0 if maze.is_cell_safe(Vector2i(x, y)) else INF
		var transformed := _squared_distance_transform(line)
		for y in grid_size.y:
			intermediate[y * grid_size.x + x] = transformed[y]

	var distances := PackedFloat64Array()
	distances.resize(grid_size.x * grid_size.y)
	line.resize(grid_size.x)
	for y in grid_size.y:
		for x in grid_size.x:
			line[x] = intermediate[y * grid_size.x + x]
		var transformed := _squared_distance_transform(line)
		for x in grid_size.x:
			distances[y * grid_size.x + x] = transformed[x]
	return distances


func _squared_distance_transform(values: PackedFloat64Array) \
		-> PackedFloat64Array:
	var result := PackedFloat64Array()
	result.resize(values.size())
	result.fill(INF)
	var sites := PackedInt32Array()
	for index in values.size():
		if not is_inf(values[index]):
			sites.append(index)
	if sites.is_empty():
		return result

	var vertices := PackedInt32Array()
	vertices.resize(sites.size())
	var boundaries := PackedFloat64Array()
	boundaries.resize(sites.size() + 1)
	var vertex_index := 0
	vertices[0] = sites[0]
	boundaries[0] = -INF
	boundaries[1] = INF

	for site_index in range(1, sites.size()):
		var site := sites[site_index]
		var intersection := _parabola_intersection(
			values,
			site,
			vertices[vertex_index]
		)
		while vertex_index > 0 and intersection <= boundaries[vertex_index]:
			vertex_index -= 1
			intersection = _parabola_intersection(
				values,
				site,
				vertices[vertex_index]
			)
		vertex_index += 1
		vertices[vertex_index] = site
		boundaries[vertex_index] = intersection
		boundaries[vertex_index + 1] = INF

	vertex_index = 0
	for index in values.size():
		while boundaries[vertex_index + 1] < float(index):
			vertex_index += 1
		var delta := index - vertices[vertex_index]
		result[index] = (
			float(delta * delta) + values[vertices[vertex_index]]
		)
	return result


func _parabola_intersection(
	values: PackedFloat64Array,
	first_index: int,
	second_index: int
) -> float:
	return (
		values[first_index]
		+ float(first_index * first_index)
		- values[second_index]
		- float(second_index * second_index)
	) / float(2 * (first_index - second_index))


func _mega_core_cell_is_valid(
	cell: Vector2i,
	safe_zone_distances: PackedFloat64Array
) -> bool:
	if cell.x < 0 or cell.y < 0:
		return false
	var grid_size := maze.grid_size()
	var distance_squared := safe_zone_distances[
		cell.y * grid_size.x + cell.x
	]
	return cell.x >= 0 \
			and distance_squared \
					>= float(MEGA_CORE_MIN_SAFE_ZONE_DISTANCE ** 2) \
			and distance_squared \
					<= float(MEGA_CORE_MAX_SAFE_ZONE_DISTANCE ** 2) \
			and not maze.is_cell_safe(cell) \
			and not _has_door_at(cell) \
			and maze.is_cell_walkable(cell)


func spawn_enemy_bullet(
	start_position: Vector2,
	direction: Vector2,
	shooter: Enemy
) -> void:
	AudioManager.play_enemy_shot()
	var bullet: Node = BULLET_SCENE.instantiate()
	bullet.setup(
		start_position + direction * BULLET_SPAWN_DISTANCE,
		direction,
		maze,
		_rng.randi_range(shooter.damage_min, shooter.damage_max),
		false
	)
	bullets.add_child(bullet)
	shooter.register_enemy_bullet()
	bullet.tree_exited.connect(func() -> void:
		if is_instance_valid(shooter):
			shooter.unregister_enemy_bullet()
	)
	_alert_enemies_to_shot(
		maze.world_to_cell(start_position),
		shooter
	)


func enemy_has_clear_shot(
	start_position: Vector2,
	target_position: Vector2
) -> bool:
	_perf_projectile_path_checks += 1
	var direction := start_position.direction_to(target_position)
	if direction.is_zero_approx() \
			or start_position.distance_to(target_position) \
			<= BULLET_SPAWN_DISTANCE + BULLET_HALF_LENGTH:
		return false
	var bullet_start := start_position + direction * BULLET_SPAWN_DISTANCE
	return maze.has_clear_projectile_path(
		bullet_start,
		target_position,
		BULLET_HALF_LENGTH,
		BULLET_HALF_WIDTH
	)


func spawn_damage_number(
	start_position: Vector2,
	damage: int,
	direction: Vector2
) -> void:
	var damage_number: Node = DAMAGE_NUMBER_SCENE.instantiate()
	damage_number.setup(start_position, damage, direction)
	damage_numbers.add_child(damage_number)


func spawn_floating_text(
	start_position: Vector2,
	text: String,
	direction: Vector2
) -> void:
	var floating_text: Node = DAMAGE_NUMBER_SCENE.instantiate()
	floating_text.setup_text(start_position, text, direction)
	damage_numbers.add_child(floating_text)


func show_door_error(
	start_position: Vector2,
	text: String,
	direction: Vector2
) -> void:
	AudioManager.play_door_error()
	spawn_floating_text(start_position, text, direction)


func enemy_killed(_enemy: Node) -> void:
	_enemies_killed += 1
	call_deferred("_maintain_enemy_population")


func attackers_near_player(
	player_position: Vector2,
	range_cells: float
) -> Array[Enemy]:
	var result: Array[Enemy] = []
	var range_world := range_cells * Maze.CELL_SIZE
	for enemy: Enemy in _enemies:
		if enemy.dead or not enemy.is_attack_state():
			continue
		if enemy.position.distance_to(player_position) <= range_world:
			result.append(enemy)
	return result


func _maintain_enemy_population() -> void:
	var target_count := _target_enemy_count()
	var remaining := target_count - _living_enemy_count()
	if remaining <= 0 or _defeated or _victorious:
		return

	var player_cell := maze.world_to_cell(player.position)
	var occupied_cells := _occupied_enemy_cells()
	for level in range(1, ENEMY_LEVEL_COUNT + 1):
		var missing_for_level := maxi(
			0,
			_target_enemy_count_for_level(level, target_count)
					- _living_enemy_count_for_level(level)
		)
		for index in mini(missing_for_level, remaining):
			var cell := _find_enemy_spawn_cell(
				_rng,
				player_cell,
				occupied_cells,
				level,
				false,
				ENEMY_RESPAWN_MIN_DISTANCE
			)
			if cell.x < 0:
				push_warning("Could not respawn enemy level %d" % level)
				return
			occupied_cells[cell] = true
			_create_enemy(cell, _rng.randi(), -1, level)
			remaining -= 1
		if remaining <= 0:
			return


func _alert_enemies_to_shot(
	shot_cell: Vector2i,
	shooter: Node = null
) -> void:
	await get_tree().create_timer(
		SHOT_REACTION_DELAY,
		false
	).timeout
	if _defeated or _victorious:
		return

	for enemy in _enemies:
		if enemy.dead or enemy == shooter:
			continue
		var enemy_cell: Vector2i = maze.world_to_cell(enemy.position)
		if Vector2(enemy_cell - shot_cell).length() <= Enemy.HEARING_RANGE:
			enemy.hear_position(shot_cell, true)


func _show_defeat() -> void:
	_defeated = true
	player.controls_enabled = false
	AudioManager.play_defeat_music()
	defeat_menu.open(
		_enemies_killed,
		maze.explored_floor_cell_count(),
		maze.safe_floor_cell_count(),
		maze.floor_cell_count(),
		_mega_cores_returned,
		player.energy_received_total,
		player.energy_spent_total,
		player.energy
	)


func _show_victory() -> void:
	_victorious = true
	player.controls_enabled = false
	AudioManager.play_victory_music()
	victory_menu.open(
		_enemies_killed,
		maze.explored_floor_cell_count(),
		maze.safe_floor_cell_count(),
		maze.floor_cell_count(),
		_mega_cores_returned,
		player.energy_received_total,
		player.energy_spent_total,
		player.energy
	)


func _shoot() -> void:
	if not player.controls_enabled or not player.consume_ammo():
		return

	_cancel_build_action()
	var direction: Vector2 = player.facing_direction()
	var bullet: Node = BULLET_SCENE.instantiate()
	bullet.setup(
		player.position + direction * BULLET_SPAWN_DISTANCE,
		direction,
		maze,
		_rng.randi_range(player.damage_min(), player.damage_max()),
		true
	)
	bullets.add_child(bullet)
	AudioManager.play_player_shot()
	if PLAYER_RECOIL_ENABLED:
		player.apply_recoil(direction)
	player.make_shot_noise()
	_alert_enemies_to_shot(maze.world_to_cell(player.position))
	_update_player_panel()
