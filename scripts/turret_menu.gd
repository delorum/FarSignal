extends Control

const TRANSFER_STEP := 5

@onready var game: Node = $"../.."
@onready var turret_status: Label = $Background/Center/Menu/TurretStatus
@onready var player_status: Label = $Background/Center/Menu/PlayerStatus
@onready var health_button: Button = $Background/Center/Menu/HealthButton
@onready var ammo_button: Button = $Background/Center/Menu/AmmoButton

var _turret: Turret


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Localization.language_changed.connect(_update_menu)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open(turret: Turret) -> void:
	_turret = turret
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_update_menu()
	if not health_button.disabled:
		health_button.grab_focus()
	elif not ammo_button.disabled:
		ammo_button.grab_focus()
	else:
		$Background/Center/Menu/ExitButton.grab_focus()


func close() -> void:
	visible = false
	_turret = null
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


func _on_health_pressed() -> void:
	if is_instance_valid(_turret):
		game.transfer_health_to_turret(_turret, TRANSFER_STEP)
	_update_menu()


func _on_ammo_pressed() -> void:
	if is_instance_valid(_turret):
		game.transfer_ammo_to_turret(_turret, TRANSFER_STEP)
	_update_menu()


func _on_exit_pressed() -> void:
	close()


func _update_menu() -> void:
	if not is_instance_valid(_turret):
		return
	turret_status.text = tr("Турель: здоровье %d/%d, патроны %d/%d") % [
		_turret.health,
		Turret.MAX_HEALTH,
		_turret.ammo,
		Turret.MAX_AMMO,
	]
	player_status.text = tr("Игрок: здоровье %d, патроны %d") % [
		game.player.health,
		game.player.ammo,
	]
	var health_amount: int = game.turret_health_transfer_amount(
		_turret,
		TRANSFER_STEP
	)
	health_button.disabled = health_amount <= 0
	health_button.text = (
		tr("Передать %d здоровья") % health_amount
		if health_amount > 0
		else tr("Здоровье передать нельзя")
	)
	var ammo_amount: int = game.turret_ammo_transfer_amount(
		_turret,
		TRANSFER_STEP
	)
	ammo_button.disabled = ammo_amount <= 0
	ammo_button.text = (
		tr("Передать %d патронов") % ammo_amount
		if ammo_amount > 0
		else tr("Патроны передать нельзя")
	)
