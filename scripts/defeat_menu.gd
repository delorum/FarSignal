extends Control

@onready var kills_value: Label = $Background/Center/Menu/KillsValue


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func open(enemies_killed: int) -> void:
	kills_value.text = "Убито врагов: %d" % enemies_killed
	visible = true
	get_tree().paused = true


func _on_exit_pressed() -> void:
	get_tree().quit()
