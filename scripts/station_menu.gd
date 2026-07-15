extends Control

const LoreText = preload("res://scripts/lore_text.gd")

@onready var game: Node = $"../.."
@onready var menu: VBoxContainer = $Background/Center/Menu
@onready var title: Label = $Background/Center/Menu/Title
@onready var instructions_screen: Control = $Background/InstructionsPanel
@onready var instructions_scroll: ScrollContainer = $Background/InstructionsPanel/InstructionsScreen/InstructionsScroll
@onready var instructions_text: Label = $Background/InstructionsPanel/InstructionsScreen/InstructionsScroll/InstructionsText
@onready var information_screen: Control = $Background/InformationPanel
@onready var information_text: Label = $Background/InformationPanel/InformationScreen/InformationText
@onready var energy_value: Label = $Background/Center/Menu/EnergyValue
@onready var player_status_value: Label = $Background/Center/Menu/PlayerStatusValue
@onready var ammo_button: Button = $Background/Center/Menu/ActionsGrid/AmmoButton
@onready var health_button: Button = $Background/Center/Menu/ActionsGrid/HealthButton
@onready var exchange_button: Button = $Background/Center/Menu/ActionsGrid/ExchangeButton
@onready var exchange_cells_button: Button = $Background/Center/Menu/ActionsGrid/ExchangeCellsButton
@onready var return_mega_core_button: Button = $Background/Center/Menu/ActionsGrid/ReturnMegaCoreButton
@onready var door_button: Button = $Background/Center/Menu/ActionsGrid/DoorButton
@onready var instructions_button: Button = $Background/Center/Menu/ActionsGrid/InstructionsButton
@onready var information_button: Button = $Background/Center/Menu/ActionsGrid/InformationButton
@onready var damage_upgrade_button: Button = $Background/Center/Menu/ActionsGrid/DamageUpgradeButton
@onready var health_upgrade_button: Button = $Background/Center/Menu/ActionsGrid/HealthUpgradeButton
@onready var ammo_upgrade_button: Button = $Background/Center/Menu/ActionsGrid/AmmoUpgradeButton
@onready var exit_button: Button = $Background/Center/Menu/ActionsGrid/ExitButton
@onready var instructions_back_button: Button = $Background/InstructionsPanel/InstructionsScreen/BackButton
@onready var information_back_button: Button = $Background/InformationPanel/InformationScreen/BackButton

var _station_id := 1
var _station_one_buttons: Array[Button] = []
var _upgrade_buttons: Array[Button] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	instructions_text.text = LoreText.STATION_INSTRUCTIONS
	_station_one_buttons = [
		ammo_button,
		health_button,
		exchange_button,
		exchange_cells_button,
		return_mega_core_button,
		door_button,
		instructions_button,
	]
	_upgrade_buttons = [
		damage_upgrade_button,
		health_upgrade_button,
		ammo_upgrade_button,
	]


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open(show_instructions: bool = false, station_id: int = 1) -> void:
	AudioManager.play_station_open()
	AudioManager.set_station_music_active(true)
	_station_id = station_id
	title.text = "Станция %d" % station_id
	for button in _station_one_buttons:
		button.visible = station_id == 1
	for button in _upgrade_buttons:
		button.visible = station_id > 1
	_update_buttons()
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if show_instructions:
		_show_instructions()
	else:
		_show_menu()


func _show_menu() -> void:
	menu.visible = true
	instructions_screen.visible = false
	information_screen.visible = false
	if _station_id > 1:
		for button in _upgrade_buttons:
			if not button.disabled:
				button.grab_focus()
				return
		information_button.grab_focus()
	elif not exchange_button.disabled:
		exchange_button.grab_focus()
	elif not return_mega_core_button.disabled:
		return_mega_core_button.grab_focus()
	elif not exchange_cells_button.disabled:
		exchange_cells_button.grab_focus()
	elif not health_button.disabled:
		health_button.grab_focus()
	elif not ammo_button.disabled:
		ammo_button.grab_focus()
	elif not door_button.disabled:
		door_button.grab_focus()
	else:
		exit_button.grab_focus()


func _show_instructions() -> void:
	menu.visible = false
	instructions_screen.visible = true
	information_screen.visible = false
	instructions_scroll.scroll_vertical = 0
	instructions_back_button.grab_focus()


func _show_information() -> void:
	var statistics: Dictionary = game.station_statistics()
	var total_floor_cells: int = statistics.total_floor_cells
	information_text.text = (
		"Исследовано клеток: %d (%.1f%%)\n"
		+ "Размер безопасной зоны: %d (%.1f%%)\n"
		+ "Убито врагов: %d\n"
		+ "Врагов на карте: %d\n"
		+ "Возвращено мегаядер: %d\n"
		+ "Получено энергии: %d\n"
		+ "Потрачено энергии: %d\n"
		+ "Осталось энергии: %d\n\n"
		+ "Уровни врагов:\n%s"
	) % [
		statistics.explored_cells,
		_percentage(statistics.explored_cells, total_floor_cells),
		statistics.safe_zone_size,
		_percentage(statistics.safe_zone_size, total_floor_cells),
		statistics.enemies_killed,
		statistics.living_enemies,
		statistics.mega_cores_returned,
		statistics.energy_received,
		statistics.energy_spent,
		statistics.energy_remaining,
		statistics.enemy_level_summary,
	]
	menu.visible = false
	instructions_screen.visible = false
	information_screen.visible = true
	information_back_button.grab_focus()


func _percentage(value: int, total: int) -> float:
	if total <= 0:
		return 0.0
	return float(value) * 100.0 / float(total)


func close() -> void:
	AudioManager.set_station_music_active(false)
	visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


func _on_ammo_pressed() -> void:
	game.buy_ammo()
	_update_buttons()
	_show_menu()


func _on_health_pressed() -> void:
	game.buy_health()
	_update_buttons()
	_show_menu()


func _on_exchange_pressed() -> void:
	game.exchange_energy_cores()
	_update_buttons()
	_show_menu()


func _on_exchange_cells_pressed() -> void:
	game.exchange_exploration_points()
	_update_buttons()
	_show_menu()


func _on_return_mega_core_pressed() -> void:
	game.return_mega_core()
	_update_buttons()
	_show_menu()


func _on_door_pressed() -> void:
	game.buy_door()
	_update_buttons()
	_show_menu()


func _on_instructions_pressed() -> void:
	_show_instructions()


func _on_information_pressed() -> void:
	_show_information()


func _on_damage_upgrade_pressed() -> void:
	game.upgrade_player_damage(_station_id)
	_update_buttons()
	_show_menu()


func _on_health_upgrade_pressed() -> void:
	game.upgrade_player_health(_station_id)
	_update_buttons()
	_show_menu()


func _on_ammo_upgrade_pressed() -> void:
	game.upgrade_player_ammo(_station_id)
	_update_buttons()
	_show_menu()


func _on_instructions_back_pressed() -> void:
	_show_menu()


func _on_information_back_pressed() -> void:
	_show_menu()


func _on_exit_pressed() -> void:
	AudioManager.play_station_close()
	close()


func _update_buttons() -> void:
	energy_value.text = "Энергия: %d" % game.player.energy
	player_status_value.text = "Здоровье: %d/%d    Патроны: %d/%d" % [
		game.player.health,
		game.player.max_health,
		game.player.ammo,
		game.player.max_ammo,
	]

	var ammo_amount: int = game.player.ammo_purchase_amount()
	var ammo_cost: int = game.player.ammo_purchase_cost()
	ammo_button.disabled = ammo_amount <= 0 or game.player.energy < ammo_cost
	ammo_button.text = (
		"Полный боезапас"
		if ammo_amount <= 0
		else "Купить %d патронов за %d энергии" % [ammo_amount, ammo_cost]
	)

	var health_amount: int = game.player.health_purchase_amount()
	var health_cost: int = game.player.health_purchase_cost()
	health_button.disabled = health_amount <= 0 or game.player.energy < health_cost
	health_button.text = (
		"Полное здоровье"
		if health_amount <= 0
		else "Восстановить %d здоровья за %d энергии" % [
			health_amount,
			health_cost,
		]
	)

	exchange_button.disabled = game.player.energy_cores <= 0
	exchange_button.text = (
		"Нет энергоядер"
		if game.player.energy_cores <= 0
		else "Сдать энергоядра: +%d энергии" % (
			game.player.energy_core_exchange_energy()
		)
	)

	var exchanged_points: int = game.player.exploration_exchange_points()
	var exchange_energy: int = game.player.exploration_exchange_energy()
	exchange_cells_button.disabled = exchanged_points <= 0
	exchange_cells_button.text = (
		"Нужно %d очков исследования" % Player.EXPLORATION_POINTS_PER_ENERGY
		if exchanged_points <= 0
		else "Сдать %d очков: +%d энергии" % [
			exchanged_points,
			exchange_energy,
		]
	)

	return_mega_core_button.disabled = not game.player.has_mega_core
	return_mega_core_button.text = (
		"Вернуть мегаядро: +%d энергии" % game.player.mega_core_energy_value
		if game.player.has_mega_core
		else "Мегаядро не найдено"
	)

	door_button.disabled = not game.player.can_buy_door()
	door_button.text = (
		"Двери: максимум"
		if not game.player.can_store_door()
		else "Купить дверь за %d энергии" % Player.DOOR_COST
	)

	damage_upgrade_button.disabled = not game.can_upgrade_player_damage(
		_station_id
	)
	damage_upgrade_button.text = _upgrade_button_text(
		"Урон",
		game.player.damage_upgrade_level
	)
	health_upgrade_button.disabled = not game.can_upgrade_player_health(
		_station_id
	)
	health_upgrade_button.text = _upgrade_button_text(
		"Здоровье",
		game.player.health_upgrade_level
	)
	ammo_upgrade_button.disabled = not game.can_upgrade_player_ammo(
		_station_id
	)
	ammo_upgrade_button.text = _upgrade_button_text(
		"Боезапас",
		game.player.ammo_upgrade_level
	)


func _upgrade_button_text(label: String, level: int) -> String:
	var station_minimum := (_station_id - 2) * Player.UPGRADES_PER_STATION
	var station_maximum := station_minimum + Player.UPGRADES_PER_STATION
	if level < station_minimum:
		return "%s: нужна предыдущая станция" % label
	if level >= station_maximum and level < Player.MAX_UPGRADE_LEVEL:
		return "%s: на этой станции максимум" % label
	if level >= Player.MAX_UPGRADE_LEVEL:
		return "%s: максимум" % label
	return "%s: уровень %d/%d за %d энергии" % [
		label,
		level + 2,
		Player.PLAYER_LEVEL_COUNT,
		Player.UPGRADE_COST,
	]
