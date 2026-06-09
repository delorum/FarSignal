extends Control

const GAME_SCENE := "res://scenes/main.tscn"

@onready var main_menu: VBoxContainer = $CenterContainer/MainMenu
@onready var controls_screen: VBoxContainer = $CenterContainer/ControlsScreen
@onready var new_game_button: Button = $CenterContainer/MainMenu/NewGameButton
@onready var back_button: Button = $CenterContainer/ControlsScreen/BackButton


func _ready() -> void:
	new_game_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and controls_screen.visible:
		_show_main_menu()
		get_viewport().set_input_as_handled()


func _on_new_game_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_controls_pressed() -> void:
	main_menu.hide()
	controls_screen.show()
	back_button.grab_focus()


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_back_pressed() -> void:
	_show_main_menu()


func _show_main_menu() -> void:
	controls_screen.hide()
	main_menu.show()
	new_game_button.grab_focus()
