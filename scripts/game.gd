extends Node2D

const DOOR_SCENE := preload("res://scenes/door.tscn")
const BULLET_SCENE := preload("res://scenes/bullet.tscn")
const START_FACING := Vector2.UP
const BULLET_SPAWN_DISTANCE := 22.0

@onready var maze = $Maze
@onready var player = $Player
@onready var doors: Node2D = $Doors
@onready var bullets: Node2D = $Bullets
@onready var coordinates_label: Label = $GameInterface/Coordinates
@onready var health_value: Label = $GameInterface/PlayerPanel/Margin/VBox/HealthValue
@onready var health_bar: ProgressBar = $GameInterface/PlayerPanel/Margin/VBox/HealthBar
@onready var ammo_value: Label = $GameInterface/PlayerPanel/Margin/VBox/AmmoValue
@onready var ammo_bar: ProgressBar = $GameInterface/PlayerPanel/Margin/VBox/AmmoBar

var _displayed_player_cell := Vector2i(-1, -1)
var _displayed_health := -1
var _displayed_ammo := -1
var _doors: Array[Node] = []


func _enter_tree() -> void:
	if not SaveStore.pending_save.is_empty():
		var maze_node: Maze = get_node("Maze")
		maze_node.generation_seed_override = int(
			SaveStore.pending_save.get("maze_seed", 0)
		)


func _ready() -> void:
	var save_data := SaveStore.consume_pending_save()
	if save_data.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var player_cell: Vector2i = maze.get_random_bottom_floor_cell(rng)
		player.position = maze.cell_to_world(player_cell)
		player.restore_facing_direction([START_FACING.x, START_FACING.y])
		_create_generated_doors()
		var start_door_cell := player_cell + Vector2i.DOWN
		_create_door(start_door_cell, false, true, false)
	else:
		_restore_game(save_data)
		SaveStore.delete_save()

	_update_visibility()
	_update_coordinates()
	_update_player_panel()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("shoot"):
		_shoot()

	if Input.is_action_just_pressed("interact"):
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


func save_game() -> bool:
	var save_data := {
		"version": SaveStore.SAVE_VERSION,
		"maze_seed": maze.generation_seed(),
		"player_position": [player.position.x, player.position.y],
		"player_facing": player.facing_direction_for_save(),
		"player_health": player.health,
		"player_ammo": player.ammo,
		"explored_cells": maze.explored_cells_for_save(),
		"doors": _doors.map(func(door: Node): return door.save_data()),
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
	if save_data.has("doors"):
		for door_data in save_data.doors:
			_create_door_from_save(door_data)
	else:
		_create_generated_doors()


func _create_generated_doors() -> void:
	for door_spec in maze.generated_door_specs():
		_create_door(
			door_spec.cell,
			door_spec.horizontal_passage,
			false,
			false
		)


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


func _shoot() -> void:
	if not player.controls_enabled or not player.consume_ammo():
		return

	var direction: Vector2 = player.facing_direction()
	var bullet: Node = BULLET_SCENE.instantiate()
	bullet.setup(
		player.position + direction * BULLET_SPAWN_DISTANCE,
		direction,
		maze
	)
	bullets.add_child(bullet)
	_update_player_panel()
