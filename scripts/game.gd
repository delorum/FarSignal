extends Node2D

const GOAL_DISTANCE := 24.0
const MINIMUM_GOAL_STEPS := 20

@onready var maze = $Maze
@onready var player = $Player
@onready var goal: Node2D = $Goal
@onready var status_label: Label = $Interface/MarginContainer/VBoxContainer/Status

var _finished := false
var _goal_cell := Vector2i.ZERO


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var player_cell: Vector2i = maze.get_random_floor_cell(rng)
	_goal_cell = maze.get_random_distant_floor_cell(
		player_cell,
		rng,
		MINIMUM_GOAL_STEPS
	)
	player.position = maze.cell_to_world(player_cell)
	goal.position = maze.cell_to_world(_goal_cell)
	_update_visibility()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("quit_game"):
		get_tree().quit()
		return

	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()

	_update_visibility()

	if not _finished and player.position.distance_to(goal.position) <= GOAL_DISTANCE:
		_finished = true
		player.controls_enabled = false
		status_label.text = "Signal found! Press R to restart"


func _update_visibility() -> void:
	maze.update_visibility(player.position, player.facing_direction())
	goal.visible = maze.is_cell_visible(_goal_cell)
