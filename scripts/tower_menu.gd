extends Control

@onready var game: Node = $"../.."
@onready var tower_status: Label = $Background/Center/Menu/TowerStatus
@onready var tower_stats: Label = $Background/Center/Menu/TowerStats
@onready var player_status: Label = $Background/Center/Menu/PlayerStatus
@onready var health_button: Button = $Background/Center/Menu/HealthButton
@onready var information_panel: Control = $Background/InformationPanel
@onready var information_text: Label = $Background/InformationPanel/Information/InformationText
@onready var information_back_button: Button = $Background/InformationPanel/Information/BackButton

var _tower: Tower


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


func open(tower: Tower) -> void:
	_tower = tower
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_update_menu()
	$Background/Center.visible = true
	information_panel.visible = false
	if not health_button.disabled:
		health_button.grab_focus()
	else:
		$Background/Center/Menu/ExitButton.grab_focus()


func close() -> void:
	visible = false
	_tower = null
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


func _on_health_pressed() -> void:
	if is_instance_valid(_tower):
		game.buy_tower_health(_tower)
	_update_menu()


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
	if not is_instance_valid(_tower):
		return
	tower_status.text = tr("Башня: здоровье %d/%d") % [
		_tower.health,
		Tower.MAX_HEALTH,
	]
	tower_stats.text = tr("Максимальное здоровье: %d (%d уровень)") % [
		Tower.MAX_HEALTH,
		1,
	]
	player_status.text = tr("Энергия: %d") % game.player.energy
	var amount: int = game.tower_health_purchase_amount(_tower)
	var cost := Player.health_energy_cost(amount)
	health_button.disabled = amount <= 0 or game.player.energy < cost
	health_button.text = (
		tr("Полное здоровье")
		if amount <= 0
		else tr("Восстановить %d здоровья за %d энергии") % [amount, cost]
	)
	if information_panel.visible:
		_update_information_text()


func _update_information_text() -> void:
	information_text.text = tr("Уровни врагов:\n%s") % (
		game.tower_enemy_level_summary()
	)
