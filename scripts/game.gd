extends Node2D

@onready var maze = $Maze
@onready var player = $Player
@onready var coordinates_label: Label = $GameInterface/Coordinates

var _displayed_player_cell := Vector2i(-1, -1)


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
	else:
		_restore_game(save_data)
		SaveStore.delete_save()

	_update_visibility()
	_update_coordinates()


func _process(_delta: float) -> void:
	_update_visibility()
	_update_coordinates()


func _update_visibility() -> void:
	maze.update_visibility(player.position, player.facing_direction())


func _update_coordinates() -> void:
	var player_cell: Vector2i = maze.world_to_cell(player.position)
	if player_cell == _displayed_player_cell:
		return

	_displayed_player_cell = player_cell
	coordinates_label.text = "X: %d  Y: %d" % [player_cell.x, player_cell.y]


func save_game() -> bool:
	var save_data := {
		"version": SaveStore.SAVE_VERSION,
		"maze_seed": maze.generation_seed(),
		"player_position": [player.position.x, player.position.y],
		"player_facing": player.facing_direction_for_save(),
		"explored_cells": maze.explored_cells_for_save(),
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
	maze.restore_explored_cells(save_data.explored_cells)
