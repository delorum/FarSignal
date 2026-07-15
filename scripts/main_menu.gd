extends Control

const BuildInfo = preload("res://scripts/build_info.gd")
const GAME_SCENE := "res://scenes/main.tscn"
const INTRO_SCENE := "res://scenes/intro.tscn"
const ART_HOLD_SECONDS := 1.0
const MENU_FADE_SECONDS := 1.0

@onready var background: ColorRect = $Background
@onready var center_container: CenterContainer = $CenterContainer
@onready var main_menu: VBoxContainer = $CenterContainer/MainMenu
@onready var controls_screen: VBoxContainer = $CenterContainer/ControlsScreen
@onready var settings_menu: Control = $CenterContainer/SettingsMenu
@onready var continue_button: Button = $CenterContainer/MainMenu/ContinueButton
@onready var new_game_button: Button = $CenterContainer/MainMenu/NewGameButton
@onready var exit_button: Button = $CenterContainer/MainMenu/ExitButton
@onready var back_button: Button = $CenterContainer/ControlsScreen/BackButton
@onready var version_label: Label = $VersionLabel


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	AudioManager.set_combat_active(false)
	AudioManager.set_menu_music_active(true)
	Localization.language_changed.connect(_on_language_changed)
	version_label.text = BuildInfo.display_text()
	continue_button.visible = SaveStore.has_loadable_save()
	exit_button.visible = not OS.has_feature("web")
	background.modulate.a = 0.0
	center_container.hide()
	version_label.hide()
	await get_tree().create_timer(ART_HOLD_SECONDS).timeout
	_reveal_menu()


func _on_language_changed() -> void:
	version_label.text = BuildInfo.display_text()


func _reveal_menu() -> void:
	center_container.modulate.a = 0.0
	version_label.modulate.a = 0.0
	center_container.show()
	version_label.show()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(
		background,
		"modulate:a",
		1.0,
		MENU_FADE_SECONDS
	)
	tween.tween_property(
		center_container,
		"modulate:a",
		1.0,
		MENU_FADE_SECONDS
	)
	tween.tween_property(
		version_label,
		"modulate:a",
		1.0,
		MENU_FADE_SECONDS
	)
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
	await AudioManager.wait_for_menu_confirmation()
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
