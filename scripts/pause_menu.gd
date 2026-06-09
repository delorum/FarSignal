extends Control

@onready var pause_menu: VBoxContainer = $CenterContainer/PauseMenu
@onready var controls_screen: VBoxContainer = $CenterContainer/ControlsScreen
@onready var continue_button: Button = $CenterContainer/PauseMenu/ContinueButton
@onready var back_button: Button = $CenterContainer/ControlsScreen/BackButton
@onready var map_view: Control = $"../../MapOverlay/MapView"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _exit_tree() -> void:
	if get_tree().paused:
		get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return

	if not visible:
		_open_pause_menu()
	elif controls_screen.visible:
		_show_pause_menu()
	else:
		_resume_game()

	get_viewport().set_input_as_handled()


func _on_continue_pressed() -> void:
	_resume_game()


func _on_controls_pressed() -> void:
	pause_menu.hide()
	controls_screen.show()
	back_button.grab_focus()


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_back_pressed() -> void:
	_show_pause_menu()


func _open_pause_menu() -> void:
	visible = true
	get_tree().paused = true
	_show_pause_menu()


func _resume_game() -> void:
	visible = false
	get_tree().paused = map_view.visible


func _show_pause_menu() -> void:
	controls_screen.hide()
	pause_menu.show()
	continue_button.grab_focus()
