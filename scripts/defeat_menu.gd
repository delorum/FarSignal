extends Control

const MAIN_MENU_SCENE := "res://scenes/menu.tscn"

@onready var kills_value: Label = $Background/Center/Menu/KillsValue


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func open(enemies_killed: int) -> void:
	kills_value.text = "Убито врагов: %d" % enemies_killed
	visible = true
	get_tree().paused = true


func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
