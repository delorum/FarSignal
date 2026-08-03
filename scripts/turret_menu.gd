extends Control

@onready var game: Node = $"../.."
@onready var turret_status: Label = $Background/Center/Menu/TurretStatus
@onready var turret_stats: Label = $Background/Center/Menu/TurretStats
@onready var player_status: Label = $Background/Center/Menu/PlayerStatus
@onready var health_button: Button = $Background/Center/Menu/HealthButton
@onready var ammo_button: Button = $Background/Center/Menu/AmmoButton
@onready var rotate_button: Button = $Background/Center/Menu/RotateButton
@onready var information_panel: Control = $Background/InformationPanel
@onready var information_text: Label = $Background/InformationPanel/Information/InformationText
@onready var information_back_button: Button = $Background/InformationPanel/Information/BackButton

var _turret: Turret


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Localization.language_changed.connect(_update_menu)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		if information_panel.visible:
			_on_information_back_pressed()
		else:
			close()
		get_viewport().set_input_as_handled()


func open(turret: Turret) -> void:
	_turret = turret
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_update_menu()
	$Background/Center.visible = true
	information_panel.visible = false
	if not health_button.disabled:
		health_button.grab_focus()
	elif not ammo_button.disabled:
		ammo_button.grab_focus()
	else:
		rotate_button.grab_focus()


func close() -> void:
	visible = false
	_turret = null
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


func _on_health_pressed() -> void:
	if is_instance_valid(_turret):
		game.buy_turret_health(_turret)
	_update_menu()


func _on_ammo_pressed() -> void:
	if is_instance_valid(_turret):
		game.buy_turret_ammo(_turret)
	_update_menu()


func _on_rotate_pressed() -> void:
	if not is_instance_valid(_turret):
		return
	var turret := _turret
	close()
	game.start_turret_reorientation(turret)


func _on_information_pressed() -> void:
	_update_information_text()
	$Background/Center.visible = false
	information_panel.visible = true
	information_back_button.grab_focus()


func _on_information_back_pressed() -> void:
	information_panel.visible = false
	$Background/Center.visible = true
	$Background/Center/Menu/InformationButton.grab_focus()


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
	turret_stats.text = tr(
		"Максимальное здоровье: %d (%d уровень)\nМаксимальное количество патронов: %d (%d уровень)\nУрон: %d-%d (%d уровень)"
	) % [
		Turret.MAX_HEALTH,
		1,
		Turret.MAX_AMMO,
		1,
		Player.BASE_DAMAGE_MIN,
		Player.BASE_DAMAGE_MAX,
		1,
	]
	player_status.text = tr("Энергия: %d") % game.player.energy
	var health_amount: int = game.turret_health_purchase_amount(_turret)
	var health_cost := Player.health_energy_cost(health_amount)
	health_button.disabled = health_amount <= 0 \
			or game.player.energy < health_cost
	health_button.text = (
		tr("Полное здоровье")
		if health_amount <= 0
		else tr("Восстановить %d здоровья за %d энергии") % [
			health_amount,
			health_cost,
		]
	)
	var ammo_amount: int = game.turret_ammo_purchase_amount(_turret)
	var ammo_cost := Player.ammo_energy_cost(ammo_amount)
	ammo_button.disabled = ammo_amount <= 0 or game.player.energy < ammo_cost
	ammo_button.text = (
		tr("Полный боезапас")
		if ammo_amount <= 0
		else tr("Купить %d патронов за %d энергии") % [
			ammo_amount,
			ammo_cost,
		]
	)
	if information_panel.visible:
		_update_information_text()


func _update_information_text() -> void:
	information_text.text = tr("Уровни врагов:\n%s") % (
		game.turret_enemy_level_summary()
	)
