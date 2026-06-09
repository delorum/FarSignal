extends Node2D

@onready var maze = $Maze
@onready var player = $Player
@onready var coordinates_label: Label = $GameInterface/Coordinates

var _displayed_player_cell := Vector2i(-1, -1)


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var player_cell: Vector2i = maze.get_random_bottom_floor_cell(rng)
	player.position = maze.cell_to_world(player_cell)
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
