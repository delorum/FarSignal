extends Control

const GAME_SCENE := "res://scenes/main.tscn"
const LoreText = preload("res://scripts/lore_text.gd")

@onready var objective_text: Label = $MarginContainer/VBoxContainer/ObjectiveText

var _input_enabled := false


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	AudioManager.set_combat_active(false)
	AudioManager.set_menu_music_active(false)
	objective_text.text = LoreText.objective_text()
	await get_tree().process_frame
	_input_enabled = true


func _unhandled_input(event: InputEvent) -> void:
	if not _input_enabled or not event is InputEventKey:
		return

	var key_event := event as InputEventKey
	if key_event.pressed and not key_event.echo:
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file(GAME_SCENE)
