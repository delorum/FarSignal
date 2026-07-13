extends Control

const GAME_SCENE := "res://scenes/main.tscn"
const INTRO_SCENE := "res://scenes/intro.tscn"

@onready var main_menu: VBoxContainer = $CenterContainer/MainMenu
@onready var controls_screen: VBoxContainer = $CenterContainer/ControlsScreen
@onready var settings_menu: Control = $CenterContainer/SettingsMenu
@onready var continue_button: Button = $CenterContainer/MainMenu/ContinueButton
@onready var new_game_button: Button = $CenterContainer/MainMenu/NewGameButton
@onready var exit_button: Button = $CenterContainer/MainMenu/ExitButton
@onready var back_button: Button = $CenterContainer/ControlsScreen/BackButton


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	AudioManager.set_combat_active(false)
	continue_button.visible = SaveStore.has_loadable_save()
	exit_button.visible = not OS.has_feature("web")
	_focus_first_menu_button()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if settings_menu.visible and settings_menu.close_submenu():
		get_viewport().set_input_as_handled()
		return
	if controls_screen.visible or settings_menu.visible:
		_show_main_menu()
		get_viewport().set_input_as_handled()


func _on_continue_pressed() -> void:
	var save_data := SaveStore.read_save()
	if save_data.is_empty():
		continue_button.hide()
		new_game_button.grab_focus()
		return

	SaveStore.request_load(save_data)
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_new_game_pressed() -> void:
	if SaveStore.delete_save():
		get_tree().change_scene_to_file(INTRO_SCENE)


func _on_controls_pressed() -> void:
	main_menu.hide()
	controls_screen.show()
	back_button.grab_focus()


func _on_settings_pressed() -> void:
	main_menu.hide()
	settings_menu.open()


func _on_settings_back_requested() -> void:
	_show_main_menu()


func _on_exit_pressed() -> void:
	if OS.has_feature("web"):
		return
	get_tree().quit()


func _on_back_pressed() -> void:
	_show_main_menu()


func _show_main_menu() -> void:
	controls_screen.hide()
	settings_menu.hide()
	main_menu.show()
	_focus_first_menu_button()


func _focus_first_menu_button() -> void:
	if continue_button.visible:
		continue_button.grab_focus()
	else:
		new_game_button.grab_focus()
