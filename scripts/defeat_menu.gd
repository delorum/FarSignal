extends Control

@onready var levels_value: Label = $Background/Center/Menu/LevelsValue
@onready var kills_value: Label = $Background/Center/Menu/KillsValue


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func open(levels_passed: int, enemies_killed: int) -> void:
	levels_value.text = "Пройдено уровней: %d" % levels_passed
	kills_value.text = "Убито врагов: %d" % enemies_killed
	visible = true
	get_tree().paused = true


func _on_exit_pressed() -> void:
	get_tree().quit()
