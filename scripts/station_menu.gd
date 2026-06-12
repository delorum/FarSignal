extends Control

@onready var game: Node = $"../.."
@onready var ammo_button: Button = $Background/Center/Menu/AmmoButton
@onready var health_button: Button = $Background/Center/Menu/HealthButton
@onready var exit_button: Button = $Background/Center/Menu/ExitButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	_update_buttons()
	visible = true
	get_tree().paused = true
	if not ammo_button.disabled:
		ammo_button.grab_focus()
	elif not health_button.disabled:
		health_button.grab_focus()
	else:
		exit_button.grab_focus()


func close() -> void:
	visible = false
	get_tree().paused = false


func _on_ammo_pressed() -> void:
	game.refill_ammo()
	_update_buttons()
	if not health_button.disabled:
		health_button.grab_focus()
	else:
		exit_button.grab_focus()


func _on_health_pressed() -> void:
	game.refill_health()
	_update_buttons()
	if not ammo_button.disabled:
		ammo_button.grab_focus()
	else:
		exit_button.grab_focus()


func _on_exit_pressed() -> void:
	close()


func _update_buttons() -> void:
	var ammo_is_full: bool = game.player.ammo >= game.player.MAX_AMMO
	ammo_button.disabled = ammo_is_full
	ammo_button.text = (
		"Полный боезапас"
		if ammo_is_full
		else "Пополнить боезапас"
	)

	var health_is_full: bool = game.player.health >= game.player.MAX_HEALTH
	health_button.disabled = health_is_full
	health_button.text = (
		"Полное здоровье"
		if health_is_full
		else "Пополнить здоровье"
	)
