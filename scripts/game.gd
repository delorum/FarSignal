extends Node2D

const START_CELL := Vector2i(1, 1)
const GOAL_CELL := Vector2i(23, 15)
const GOAL_DISTANCE := 24.0

@onready var maze = $Maze
@onready var player = $Player
@onready var goal: Node2D = $Goal
@onready var status_label: Label = $Interface/MarginContainer/VBoxContainer/Status

var _finished := false


func _ready() -> void:
	player.position = maze.cell_to_world(START_CELL)
	goal.position = maze.cell_to_world(GOAL_CELL)
	_configure_camera()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()

	if not _finished and player.position.distance_to(goal.position) <= GOAL_DISTANCE:
		_finished = true
		player.controls_enabled = false
		status_label.text = "Signal found! Press R to restart"


func _configure_camera() -> void:
	var camera: Camera2D = player.get_node("Camera2D")
	var size: Vector2 = maze.world_size()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(size.x)
	camera.limit_bottom = int(size.y)
