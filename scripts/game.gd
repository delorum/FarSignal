extends Node2D

const DOOR_SCENE := preload("res://scenes/door.tscn")
const TURRET_SCENE := preload("res://scenes/turret.tscn")
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
const ENEMY_SPAWN_ATTEMPTS := 256
const PLAYER_DAMAGE_MIN := 27
const PLAYER_DAMAGE_MAX := 36
const ENEMY_DAMAGE_MIN := 17
const ENEMY_DAMAGE_MAX := 24
const SHOT_REACTION_DELAY := 2.0
const PLAYER_SHOOT_INTERVAL := 1.0
const PLAYER_RECOIL_ENABLED := false
const MAP_MARKER_PATH_REFRESH_SECONDS := 5.0
const CRITICAL_HEALTH_THRESHOLD := 30
const CRITICAL_AMMO_THRESHOLD := 10
const ENERGY_CORE_PICKUP_DISTANCE := 0.65 * Maze.CELL_SIZE
const MIN_TURRET_PLACEMENT_DISTANCE := 0.5 * Maze.CELL_SIZE
const STATUS_VALUE_COLOR := Color(0.92, 0.94, 0.97, 1.0)
const STATUS_CRITICAL_COLOR := Color(0.9, 0.25, 0.27, 1.0)
const NOISE_SILENT_COLOR := Color("58d68d")
const NOISE_AUDIBLE_COLOR := Color("d66b6b")
const ALERT_CLEAR_COLOR := Color("58d68d")
const ALERT_ACTIVE_COLOR := Color("d66b6b")
const NEARBY_ENEMIES_CLEAR_COLOR := Color("58d68d")
const NEARBY_ENEMIES_WARNING_COLOR := Color("d8c35a")
const NEARBY_ENEMIES_DANGER_COLOR := Color("d66b6b")
const PANEL_WIDTH_RATIO := 0.2
const MIN_PANEL_WIDTH := 260.0
const MAX_PANEL_WIDTH := 360.0
const HIT_FLASH_DURATION := 0.25
const LOCKED_DOOR_LABEL := "закрыто"
const EXIT_DOOR_LOCKED_LABEL := "Нужна безопасная зона"
const SAFE_ZONE_BOUNDARY_DOOR_LABEL := "Граница безопасной зоны"
const DOOR_REMOVE_FORBIDDEN_LABEL := "нельзя удалить"

enum BuildMode {
	DOOR,
	TURRET,
}

@onready var maze: Maze = $Maze
@onready var player: Player = $Player
@onready var doors: Node2D = $Doors
@onready var turrets: Node2D = $Turrets
@onready var stations: Node2D = $Stations
@onready var enemies: Node2D = $Enemies
@onready var bullets: Node2D = $Bullets
@onready var damage_numbers: Node2D = $DamageNumbers
@onready var enemy_target_markers: Node2D = $EnemyTargetMarkers
@onready var mega_core_marker: Node2D = $MegaCoreMarker
@onready var camera: Camera2D = $Player/Camera2D
@onready var player_panel: Panel = $GameInterface/PlayerPanel
@onready var hit_flash: Panel = $GameInterface/HitFlash
@onready var coordinates_label: Label = $GameInterface/PlayerPanel/Coordinates
@onready var health_value: Label = $GameInterface/PlayerPanel/Margin/VBox/HealthValue
@onready var health_bar: ProgressBar = $GameInterface/PlayerPanel/Margin/VBox/HealthBar
@onready var ammo_value: Label = $GameInterface/PlayerPanel/Margin/VBox/AmmoValue
@onready var ammo_bar: ProgressBar = $GameInterface/PlayerPanel/Margin/VBox/AmmoBar
@onready var energy_cores_value: Label = $GameInterface/PlayerPanel/Margin/VBox/EnergyCoresValue
@onready var energy_value: Label = $GameInterface/PlayerPanel/Margin/VBox/EnergyValue
@onready var doors_value: Label = $GameInterface/PlayerPanel/Margin/VBox/DoorsValue
@onready var turrets_value: Label = $GameInterface/PlayerPanel/Margin/VBox/TurretsValue
@onready var build_mode_value: Label = $GameInterface/PlayerPanel/Margin/VBox/BuildModeValue
@onready var explored_cells_value: Label = $GameInterface/PlayerPanel/Margin/VBox/ExploredCellsValue
@onready var mega_core_value: Label = $GameInterface/PlayerPanel/Margin/VBox/MegaCoreValue
@onready var nearby_enemies_value: Label = $GameInterface/PlayerPanel/Margin/VBox/NearbyEnemiesValue
@onready var alert_state_value: Label = $GameInterface/PlayerPanel/Margin/VBox/AlertStateValue
@onready var noise_state_value: Label = $GameInterface/PlayerPanel/Margin/VBox/NoiseStateValue
@onready var noise_bar: ProgressBar = $GameInterface/PlayerPanel/Margin/VBox/NoiseBar
@onready var station_menu: Control = $StationOverlay/StationMenu
@onready var defeat_menu: Control = $DefeatOverlay/DefeatMenu
@onready var victory_menu: Control = $VictoryOverlay/VictoryMenu

var _displayed_player_cell := Vector2i(-1, -1)
var _displayed_health := -1
var _displayed_ammo := -1
var _displayed_energy_cores := -1
var _displayed_energy := -1
var _displayed_door_inventory := -1
var _displayed_turret_inventory := -1
var _displayed_build_mode := -1
var _displayed_explored_floor_cells := -1
var _displayed_mega_core_text := ""
var _displayed_nearby_enemy_count := -1
var _displayed_alert_state := ""
var _displayed_noise_state := ""
var _doors: Array[Node] = []
var _turrets: Array[Node] = []
var _stations: Array[Node] = []
var _enemies: Array[Node] = []
var _enemies_killed := 0
var _next_enemy_id := 1
var _defeated := false
var _victorious := false
var _station_instructions_seen := false
var _shoot_cooldown := 0.0
var _rng := RandomNumberGenerator.new()
var _hit_flash_tween: Tween
var _combat_music_active := false
var _game_time_seconds := 0.0
var _map_marker_cell := Vector2i(-1, -1)
var _map_marker_path: Array[Vector2i] = []
var _map_marker_path_refresh_left := 0.0
var _build_mode := BuildMode.DOOR


func _enter_tree() -> void:
	if not SaveStore.pending_save.is_empty():
		var maze_node: Maze = get_node("Maze")
		maze_node.generation_seed_override = int(
			SaveStore.pending_save.get("maze_seed", 0)
		)


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	AudioManager.set_combat_active(false)
	_rng.randomize()
	enemy_target_markers.setup(maze, enemies)
	mega_core_marker.setup(maze, player, self)
	get_viewport().size_changed.connect(_update_adaptive_layout)
	player.damaged.connect(_show_hit_flash)
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
		_assign_new_mega_core()
		_create_generated_enemies(player_cell)
	else:
		_create_generated_stations()
		_restore_game(save_data)
		SaveStore.delete_save()

	_update_visibility()
	_update_coordinates()
	_update_player_panel()


func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _unhandled_input(event: InputEvent) -> void:
	if not player.controls_enabled:
		return
	if event is InputEventMouseButton \
			and event.pressed \
			and (
				event.button_index == MOUSE_BUTTON_WHEEL_UP
				or event.button_index == MOUSE_BUTTON_WHEEL_DOWN
			):
		_toggle_build_mode()
		get_viewport().set_input_as_handled()


func _toggle_build_mode() -> void:
	_build_mode = (
		BuildMode.TURRET
		if _build_mode == BuildMode.DOOR
		else BuildMode.DOOR
	)
	_update_player_panel()


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
	_shoot_cooldown = maxf(0.0, _shoot_cooldown - delta)
	if Input.is_action_just_pressed("shoot"):
		_shoot()
	if Input.is_action_just_pressed("place_door") \
			and player.controls_enabled:
		_use_build_mode_at(
			get_global_mouse_position()
		)

	if Input.is_action_just_pressed("interact"):
		if not _interact_with_station():
			_interact_with_door()

	_update_visibility()
	_update_coordinates()
	_clear_reached_map_marker()
	_update_map_marker_path(delta)
	_pick_up_energy_cores()
	_pick_up_mega_core()
	_update_player_panel()
	_update_music_state()


func _update_music_state() -> void:
	var combat_active := false
	for enemy: Enemy in _enemies:
		if not enemy.dead and enemy.is_attack_state():
			combat_active = true
			break
	if combat_active != _combat_music_active:
		_combat_music_active = combat_active
		AudioManager.set_combat_active(combat_active)


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
	_update_coordinates()
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
	var newly_explored_floor_cells := maze.update_visibility(
		player.position,
		player.facing_direction()
	)
	if newly_explored_floor_cells > 0:
		player.discover_floor_cells(newly_explored_floor_cells)
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
			false
		)
	queue_redraw()


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
		health_value.modulate = (
			STATUS_CRITICAL_COLOR
			if player.health <= CRITICAL_HEALTH_THRESHOLD
			else STATUS_VALUE_COLOR
		)
		health_bar.value = player.health

	if player.ammo != _displayed_ammo:
		_displayed_ammo = player.ammo
		ammo_value.text = "%d / %d" % [player.ammo, player.MAX_AMMO]
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
	var turret_count := player.turret_inventory_count()
	if turret_count != _displayed_turret_inventory:
		_displayed_turret_inventory = turret_count
		turrets_value.text = "Турели: %d" % turret_count
	if _build_mode != _displayed_build_mode:
		_displayed_build_mode = _build_mode
		build_mode_value.text = "Ставим: %s" % (
			"дверь" if _build_mode == BuildMode.DOOR else "турель"
		)
	if player.explored_floor_cells != _displayed_explored_floor_cells:
		_displayed_explored_floor_cells = player.explored_floor_cells
		explored_cells_value.text = (
			"Клетки: %d" % player.explored_floor_cells
		)
	var mega_core_text := _mega_core_status_text()
	if mega_core_text != _displayed_mega_core_text:
		_displayed_mega_core_text = mega_core_text
		mega_core_value.text = mega_core_text
	var nearby_enemy_count := _nearby_enemy_count()
	if nearby_enemy_count != _displayed_nearby_enemy_count:
		_displayed_nearby_enemy_count = nearby_enemy_count
		nearby_enemies_value.text = "Количество врагов: %d" % nearby_enemy_count
		nearby_enemies_value.modulate = _nearby_enemies_color(
			nearby_enemy_count
		)
	var has_alerted_enemies := _has_alerted_enemies()
	var alert_state := "ТРЕВОГА" if has_alerted_enemies else ""
	if alert_state != _displayed_alert_state:
		_displayed_alert_state = alert_state
		alert_state_value.text = alert_state
		alert_state_value.modulate = (
			ALERT_ACTIVE_COLOR
			if has_alerted_enemies
			else ALERT_CLEAR_COLOR
		)
	alert_state_value.visible = has_alerted_enemies
	var weapon_readiness := (
		0.0
		if player.ammo <= 0
		else 1.0 - _shoot_cooldown / PLAYER_SHOOT_INTERVAL
	)
	player.set_aim_indicator_readiness(weapon_readiness)

	var noise_state := "ВАС СЛЫШНО" if player.is_audible() else "НЕ СЛЫШНО"
	if noise_state != _displayed_noise_state:
		_displayed_noise_state = noise_state
		noise_state_value.text = noise_state
		noise_state_value.modulate = (
			NOISE_SILENT_COLOR
			if not player.is_audible()
			else NOISE_AUDIBLE_COLOR
		)
	noise_state_value.visible = has_alerted_enemies
	noise_bar.visible = has_alerted_enemies
	if noise_bar.visible:
		noise_bar.value = player.noise_level * 100.0


func _has_alerted_enemies() -> bool:
	for enemy: Enemy in _enemies:
		if not enemy.dead and enemy.is_alerted():
			return true
	return false


func _nearby_enemy_count() -> int:
	var count := 0
	var hearing_radius := Enemy.HEARING_RANGE * Maze.CELL_SIZE
	for enemy: Enemy in _enemies:
		if enemy.dead:
			continue
		if enemy.position.distance_to(player.position) <= hearing_radius:
			count += 1
	return count


func _nearby_enemies_color(enemy_count: int) -> Color:
	if enemy_count <= 0:
		return NEARBY_ENEMIES_CLEAR_COLOR
	if enemy_count <= 2:
		return NEARBY_ENEMIES_WARNING_COLOR
	return NEARBY_ENEMIES_DANGER_COLOR


func _pick_up_energy_cores() -> void:
	for enemy: Enemy in _enemies:
		if not enemy.has_energy_core():
			continue
		if enemy.position.distance_to(player.position) > ENERGY_CORE_PICKUP_DISTANCE:
			continue
		if enemy.collect_energy_core():
			player.collect_energy_core()
			_update_player_panel()


func _pick_up_mega_core() -> void:
	if player.has_mega_core or player.mega_core_cell.x < 0:
		return
	if maze.world_to_cell(player.position) != player.mega_core_cell:
		return
	if player.collect_mega_core():
		_update_player_panel()
		queue_redraw()


func _mega_core_status_text() -> String:
	if player.has_mega_core:
		if not _stations.is_empty():
			var station_cell: Vector2i = _stations[0].cell
			return "Мегаядро: Вернуть X: %d, Y: %d" % [
				station_cell.x,
				station_cell.y,
			]
		return "Мегаядро: Вернуть"
	if player.mega_core_cell.x >= 0:
		return "Мегаядро: X: %d, Y: %d" % [
			player.mega_core_cell.x,
			player.mega_core_cell.y,
		]
	return "Мегаядро: нет координат"


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
		"player_energy": player.energy,
		"player_doors": player.door_inventory,
		"player_turrets": player.turret_inventory_for_save(),
		"build_mode": _build_mode_for_save(),
		"player_explored_floor_cells": player.explored_floor_cells,
		"player_mega_core_cell": [
			player.mega_core_cell.x,
			player.mega_core_cell.y,
		],
		"player_has_mega_core": player.has_mega_core,
		"map_marker_cell": [
			_map_marker_cell.x,
			_map_marker_cell.y,
		],
		"explored_cells": maze.explored_cells_for_save(),
		"doors": _doors.map(func(door: Node): return door.save_data()),
		"turrets": _turrets.map(func(turret: Node): return turret.save_data()),
		"removed_generated_doors": _removed_generated_door_cells_for_save(),
		"station_discovered": (
			not _stations.is_empty() and _stations[0].discovered
		),
		"station_instructions_seen": _station_instructions_seen,
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
		int(save_data.get("player_health", player.MAX_HEALTH)),
		int(save_data.get("player_ammo", player.MAX_AMMO)),
		int(save_data.get("player_energy_cores", 0)),
		int(save_data.get("player_energy", 0)),
		int(save_data.get("player_doors", 0)),
		int(save_data.get("player_explored_floor_cells", 0)),
		saved_mega_core_cell,
		bool(save_data.get("player_has_mega_core", false)),
		save_data.get("player_turrets", [])
	)
	var saved_map_marker_cell: Array = save_data.get("map_marker_cell", [])
	if saved_map_marker_cell.size() == 2:
		_map_marker_cell = Vector2i(
			int(saved_map_marker_cell[0]),
			int(saved_map_marker_cell[1])
		)
	_restore_build_mode(str(save_data.get("build_mode", "door")))
	maze.restore_explored_cells(save_data.explored_cells)
	if not _stations.is_empty():
		_stations[0].discovered = bool(
			save_data.get("station_discovered", false)
		)
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
	if save_data.has("turrets"):
		for turret_data in save_data.turrets:
			_create_turret_from_save(turret_data)
	if not player.has_mega_core and player.mega_core_cell.x < 0:
		_assign_new_mega_core()
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
		var cell := maze.get_random_walkable_cell(enemy_rng)
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
	var cell := Vector2i(-1, -1)
	if saved_position.size() == 2:
		cell = maze.world_to_cell(
			Vector2(float(saved_position[0]), float(saved_position[1]))
		)
	else:
		cell = _find_enemy_spawn_cell(
			_rng,
			maze.world_to_cell(player.position),
			_occupied_enemy_cells()
		)
	if cell.x < 0:
		push_warning("Could not restore an enemy without a valid position")
		return
	var saved_enemy_id := int(saved_data.get("enemy_id", _next_enemy_id))
	_next_enemy_id = maxi(_next_enemy_id, saved_enemy_id + 1)
	var enemy: Node = _create_enemy(
		cell,
		maze.generation_seed() + index,
		saved_enemy_id
	)
	enemy.restore_state(saved_data)


func _create_enemy(
	cell: Vector2i,
	random_seed: int,
	assigned_enemy_id: int = -1
) -> Node:
	var enemy_id := assigned_enemy_id
	if enemy_id < 0:
		enemy_id = _next_enemy_id
		_next_enemy_id += 1
	else:
		_next_enemy_id = maxi(_next_enemy_id, enemy_id + 1)

	var enemy: Node = ENEMY_SCENE.instantiate()
	enemy.setup(self, maze, player, cell, random_seed, enemy_id)
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


func _has_turret_at(cell: Vector2i) -> bool:
	return _turret_at(cell) != null


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


func _toggle_player_door_at(target_cell: Vector2i) -> void:
	var player_cell := maze.world_to_cell(player.position)
	var cell_offset := target_cell - player_cell
	if absi(cell_offset.x) + absi(cell_offset.y) != 1:
		return

	var existing_door := _door_at(target_cell)
	if existing_door != null:
		if _can_remove_door(existing_door):
			_remove_door(existing_door)
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

	var door := _create_door(
		target_cell,
		horizontal_passage,
		false,
		false,
		true
	)
	if door != null:
		player.door_inventory -= 1
		AudioManager.play_door_place()
		_refresh_safe_zone()
		_update_player_panel()


func _use_build_mode_at(target_position: Vector2) -> void:
	if _build_mode == BuildMode.DOOR:
		_toggle_player_door_at(maze.world_to_cell(target_position))
	else:
		_toggle_turret_at(target_position)


func _build_mode_for_save() -> String:
	return "turret" if _build_mode == BuildMode.TURRET else "door"


func _restore_build_mode(saved_build_mode: String) -> void:
	_build_mode = (
		BuildMode.TURRET
		if saved_build_mode == "turret"
		else BuildMode.DOOR
	)


func _toggle_turret_at(target_position: Vector2) -> void:
	var placement_direction := player.position.direction_to(target_position)
	if placement_direction.is_zero_approx():
		placement_direction = player.facing_direction()
	var placement_position := (
		player.position + placement_direction.normalized() * Maze.CELL_SIZE
	)
	var target_cell := maze.world_to_cell(placement_position)

	var existing_turret := _turret_at(target_cell)
	if existing_turret != null:
		return

	if player.turret_inventory_count() <= 0 \
			or not maze.is_cell_walkable(target_cell) \
			or _has_turret_near(placement_position) \
			or _has_door_at(target_cell):
		return

	var turret_data := player.take_turret_from_inventory()
	if turret_data.is_empty():
		return

	_create_turret(
		target_cell,
		placement_direction,
		int(turret_data.get("health", Player.TURRET_MAX_HEALTH)),
		int(turret_data.get("ammo", Player.TURRET_MAX_AMMO)),
		placement_position
	)
	_update_player_panel()


func _turret_at(cell: Vector2i) -> Node:
	for turret in _turrets:
		if turret.cell == cell:
			return turret
	return null


func _has_turret_near(world_position: Vector2) -> bool:
	for turret in _turrets:
		if turret.position.distance_to(world_position) < MIN_TURRET_PLACEMENT_DISTANCE:
			return true
	return false


func _create_turret(
	cell: Vector2i,
	facing_direction: Vector2,
	health_value: int = Player.TURRET_MAX_HEALTH,
	ammo_value: int = Player.TURRET_MAX_AMMO,
	world_position: Vector2 = Vector2.INF
) -> Node:
	var turret: Node = TURRET_SCENE.instantiate()
	turret.setup(
		self,
		maze,
		enemies,
		cell,
		facing_direction,
		health_value,
		ammo_value,
		world_position
	)
	turrets.add_child(turret)
	_turrets.append(turret)
	return turret


func _create_turret_from_save(saved_data: Dictionary) -> void:
	var saved_cell: Array = saved_data.get("cell", [])
	if saved_cell.size() != 2:
		return
	var cell := Vector2i(int(saved_cell[0]), int(saved_cell[1]))
	if not maze.is_cell_walkable(cell) or _has_turret_at(cell):
		return
	var saved_position: Array = saved_data.get("position", [])
	var world_position := Vector2.INF
	if saved_position.size() == 2:
		world_position = Vector2(
			float(saved_position[0]),
			float(saved_position[1])
		)
	var saved_direction: Array = saved_data.get("base_direction", [])
	var direction := Vector2.RIGHT
	if saved_direction.size() == 2:
		direction = Vector2(
			float(saved_direction[0]),
			float(saved_direction[1])
		).normalized()
	var turret: Node = _create_turret(
		cell,
		direction,
		int(saved_data.get("health", Player.TURRET_MAX_HEALTH)),
		int(saved_data.get("ammo", Player.TURRET_MAX_AMMO)),
		world_position
	)
	var saved_aim: Array = saved_data.get("aim_direction", [])
	if saved_aim.size() == 2:
		turret.aim_direction = Vector2(
			float(saved_aim[0]),
			float(saved_aim[1])
		).normalized()


func destroy_turret(turret: Node) -> void:
	if not is_instance_valid(turret):
		return
	_turrets.erase(turret)
	turret.queue_free()
	_update_player_panel()


func _door_at(cell: Vector2i) -> Door:
	for door: Door in _doors:
		if door.cell == cell:
			return door
	return null


func _can_remove_door(door: Door) -> bool:
	if _is_start_station_locked_door(door) or _is_exit_door(door):
		spawn_floating_text(
			door.position + Vector2(0.0, -Door.CELL_SIZE * 0.35),
			DOOR_REMOVE_FORBIDDEN_LABEL,
			Vector2.UP
		)
		return false

	if not door.player_placed and _generated_door_spec_at(door.cell).is_empty():
		return false

	if _door_sides_have_matching_safe_zone(door):
		return true

	spawn_floating_text(
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
	if door.player_placed:
		player.door_inventory += 1
	_refresh_safe_zone()
	_update_player_panel()


func _refresh_safe_zone() -> void:
	var door_cells: Array[Vector2i] = []
	for door: Door in _doors:
		door_cells.append(door.cell)

	maze.update_safe_zone(door_cells)
	_assert_station_floor_is_safe()


func _assert_station_floor_is_safe() -> void:
	for station_spec in maze.generated_station_specs():
		var center: Vector2i = station_spec.cell
		for y in range(
			-Maze.STATION_FLOOR_RADIUS,
			Maze.STATION_FLOOR_RADIUS + 1
		):
			for x in range(
				-Maze.STATION_FLOOR_RADIUS,
				Maze.STATION_FLOOR_RADIUS + 1
			):
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
		spawn_floating_text(
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
		spawn_floating_text(
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

	var show_instructions := not _station_instructions_seen
	_station_instructions_seen = true
	closest_station.discover()
	station_menu.open(show_instructions)
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


func buy_turret() -> bool:
	var bought := player.buy_turret()
	_update_player_panel()
	return bought


func exchange_energy_cores() -> bool:
	var exchanged := player.exchange_energy_cores()
	_update_player_panel()
	return exchanged


func exchange_explored_floor_cells() -> bool:
	var exchanged := player.exchange_explored_floor_cells()
	_update_player_panel()
	return exchanged


func return_mega_core() -> bool:
	if not player.return_mega_core():
		return false
	_assign_new_mega_core()
	_update_player_panel()
	return true


func _assign_new_mega_core() -> void:
	var cell := _find_mega_core_cell()
	if cell.x >= 0:
		player.assign_mega_core(cell)
		queue_redraw()


func _find_mega_core_cell() -> Vector2i:
	for attempt in 512:
		var cell := maze.get_random_floor_cell(_rng)
		if _mega_core_cell_is_valid(cell):
			return cell

	var grid_size := maze.grid_size()
	for y in grid_size.y:
		for x in grid_size.x:
			var cell := Vector2i(x, y)
			if _mega_core_cell_is_valid(cell):
				return cell
	return Vector2i(-1, -1)


func _mega_core_cell_is_valid(cell: Vector2i) -> bool:
	return cell.x >= 0 \
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
		_rng.randi_range(ENEMY_DAMAGE_MIN, ENEMY_DAMAGE_MAX),
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


func spawn_turret_bullet(
	start_position: Vector2,
	direction: Vector2,
	shooter: Node
) -> void:
	AudioManager.play_player_shot()
	var bullet: Node = BULLET_SCENE.instantiate()
	bullet.setup(
		start_position + direction * BULLET_SPAWN_DISTANCE,
		direction,
		maze,
		_rng.randi_range(PLAYER_DAMAGE_MIN, PLAYER_DAMAGE_MAX),
		true
	)
	bullets.add_child(bullet)
	_alert_enemies_to_shot(
		maze.world_to_cell(start_position),
		shooter
	)


func enemy_has_clear_shot(
	start_position: Vector2,
	target_position: Vector2
) -> bool:
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


func visible_turret_for_enemy(
	enemy: Enemy,
	range_cells: float,
	facing_direction: Vector2,
	half_angle: float
) -> Node:
	var best_turret: Node
	var best_distance := INF
	for turret in _turrets:
		if not turret.is_active():
			continue
		var offset: Vector2 = turret.position - enemy.position
		var distance_cells: float = offset.length() / Maze.CELL_SIZE
		if distance_cells > range_cells:
			continue
		var direction: Vector2 = offset.normalized()
		if absf(facing_direction.angle_to(direction)) > half_angle:
			continue
		if not maze.has_line_of_sight(enemy.position, turret.position, range_cells):
			continue
		if distance_cells < best_distance:
			best_distance = distance_cells
			best_turret = turret
	return best_turret


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
	var missing_enemies := ENEMY_COUNT - _living_enemy_count()
	if missing_enemies <= 0 or _defeated or _victorious:
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
	defeat_menu.open(_enemies_killed)


func _show_victory() -> void:
	_victorious = true
	player.controls_enabled = false
	victory_menu.open(_enemies_killed)


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
	AudioManager.play_player_shot()
	if PLAYER_RECOIL_ENABLED:
		player.apply_recoil(direction)
	_shoot_cooldown = PLAYER_SHOOT_INTERVAL
	player.make_shot_noise()
	_alert_enemies_to_shot(maze.world_to_cell(player.position))
	_update_player_panel()
