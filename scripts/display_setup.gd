extends Node

func _ready() -> void:
	if DisplayServer.get_name() == "headless" or OS.has_feature("editor"):
		return

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
