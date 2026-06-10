extends Control

const LoreText = preload("res://scripts/lore_text.gd")

@onready var pause_menu: VBoxContainer = $CenterContainer/PauseMenu
@onready var controls_screen: VBoxContainer = $CenterContainer/ControlsScreen
@onready var objective_screen: VBoxContainer = $CenterContainer/ObjectiveScreen
@onready var continue_button: Button = $CenterContainer/PauseMenu/ContinueButton
@onready var controls_back_button: Button = $CenterContainer/ControlsScreen/BackButton
@onready var objective_back_button: Button = $CenterContainer/ObjectiveScreen/BackButton
@onready var objective_text: Label = $CenterContainer/ObjectiveScreen/ObjectiveText
@onready var map_view: Control = $"../../MapOverlay/MapView"
@onready var game: Node = $"../.."


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	objective_text.text = LoreText.OBJECTIVE_TEXT


func _exit_tree() -> void:
	if get_tree().paused:
		get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return

	if not visible:
		_open_pause_menu()
	elif controls_screen.visible or objective_screen.visible:
		_show_pause_menu()
	else:
		_resume_game()

	get_viewport().set_input_as_handled()


func _on_continue_pressed() -> void:
	_resume_game()


func _on_controls_pressed() -> void:
	pause_menu.hide()
	controls_screen.show()
	controls_back_button.grab_focus()


func _on_objective_pressed() -> void:
	pause_menu.hide()
	objective_screen.show()
	objective_back_button.grab_focus()


func _on_save_and_exit_pressed() -> void:
	if game.save_game():
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
	objective_screen.hide()
	pause_menu.show()
	continue_button.grab_focus()
