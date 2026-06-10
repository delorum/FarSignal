extends Control

@onready var game: Node = $"../.."
@onready var ammo_button: Button = $Background/Center/Menu/AmmoButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	get_tree().paused = true
	ammo_button.grab_focus()


func close() -> void:
	visible = false
	get_tree().paused = false


func _on_ammo_pressed() -> void:
	game.refill_ammo()


func _on_health_pressed() -> void:
	game.refill_health()


func _on_exit_pressed() -> void:
	close()
