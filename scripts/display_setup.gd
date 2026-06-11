extends Node

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
