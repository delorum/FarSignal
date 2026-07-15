extends Control

const BuildInfo = preload("res://scripts/build_info.gd")
const LoreText = preload("res://scripts/lore_text.gd")
const INTRO_SCENE := "res://scenes/intro.tscn"
const MAIN_MENU_SCENE := "res://scenes/menu.tscn"
const UNSAVED_EXIT_COLOR := Color(0.95, 0.22, 0.22)
const UNSAVED_EXIT_HOVER_COLOR := Color(1.0, 0.38, 0.38)

@onready var pause_menu: VBoxContainer = $CenterContainer/PauseMenu
@onready var controls_screen: VBoxContainer = $CenterContainer/ControlsScreen
@onready var objective_screen: VBoxContainer = $CenterContainer/ObjectiveScreen
@onready var settings_menu: Control = $CenterContainer/SettingsMenu
@onready var continue_button: Button = $CenterContainer/PauseMenu/ContinueButton
@onready var save_and_exit_button: Button = $CenterContainer/PauseMenu/SaveAndExitButton
@onready var controls_back_button: Button = $CenterContainer/ControlsScreen/BackButton
@onready var objective_back_button: Button = $CenterContainer/ObjectiveScreen/BackButton
@onready var objective_text: Label = $CenterContainer/ObjectiveScreen/ObjectiveText
@onready var map_view: Control = $"../../MapOverlay/MapView"
@onready var station_menu: Control = $"../../StationOverlay/StationMenu"
@onready var defeat_menu: Control = $"../../DefeatOverlay/DefeatMenu"
@onready var victory_menu: Control = $"../../VictoryOverlay/VictoryMenu"
@onready var game: Node = $"../.."
@onready var version_label: Label = $VersionLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	version_label.text = BuildInfo.display_text()
	objective_text.text = LoreText.OBJECTIVE_TEXT


func _exit_tree() -> void:
	if get_tree().paused:
		get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if station_menu.visible or defeat_menu.visible or victory_menu.visible:
		return

	if not visible:
		_open_pause_menu()
	elif settings_menu.visible and settings_menu.close_submenu():
		pass
	elif controls_screen.visible or objective_screen.visible \
			or settings_menu.visible:
		_show_pause_menu()
	else:
		_resume_game()

	get_viewport().set_input_as_handled()


func _on_continue_pressed() -> void:
	_resume_game()


func _on_new_game_pressed() -> void:
	if not SaveStore.delete_save():
		return

	get_tree().paused = false
	get_tree().change_scene_to_file(INTRO_SCENE)


func _on_controls_pressed() -> void:
	pause_menu.hide()
	controls_screen.show()
	controls_back_button.grab_focus()


func _on_objective_pressed() -> void:
	pause_menu.hide()
	objective_screen.show()
	objective_back_button.grab_focus()


func _on_settings_pressed() -> void:
	pause_menu.hide()
	settings_menu.open()


func _on_settings_back_requested() -> void:
	_show_pause_menu()


func _on_save_and_exit_pressed() -> void:
	if game.can_save_game() and not game.save_game():
		return
	if OS.has_feature("web"):
		get_tree().paused = false
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	else:
		await AudioManager.wait_for_menu_confirmation()
		get_tree().quit()


func _on_back_pressed() -> void:
	_show_pause_menu()


func _open_pause_menu() -> void:
	visible = true
	get_tree().paused = true
	AudioManager.set_menu_music_active(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_show_pause_menu()


func _resume_game() -> void:
	visible = false
	AudioManager.set_menu_music_active(false)
	get_tree().paused = map_view.visible
	Input.set_mouse_mode(
		Input.MOUSE_MODE_VISIBLE
		if map_view.visible
		else Input.MOUSE_MODE_HIDDEN
	)


func _show_pause_menu() -> void:
	controls_screen.hide()
	objective_screen.hide()
	settings_menu.hide()
	var can_save: bool = game.can_save_game()
	save_and_exit_button.text = (
		"Сохранить и выйти"
		if can_save
		else "Выйти без сохранения"
	)
	_set_unsaved_exit_warning(not can_save)
	pause_menu.show()
	continue_button.grab_focus()


func _set_unsaved_exit_warning(enabled: bool) -> void:
	var color_names := [
		"font_color",
		"font_focus_color",
		"font_hover_color",
		"font_hover_pressed_color",
		"font_pressed_color",
	]
	if not enabled:
		for color_name: String in color_names:
			save_and_exit_button.remove_theme_color_override(color_name)
		return

	for color_name: String in color_names:
		save_and_exit_button.add_theme_color_override(
			color_name,
			UNSAVED_EXIT_HOVER_COLOR
			if color_name != "font_color"
			else UNSAVED_EXIT_COLOR
		)
