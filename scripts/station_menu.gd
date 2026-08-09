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
@onready var upgrades_screen: Control = $Background/UpgradesPanel
@onready var upgrades_energy_value: Label = $Background/UpgradesPanel/UpgradesScreen/EnergyValue
@onready var resources_screen: Control = $Background/ResourcesPanel
@onready var resources_energy_value: Label = $Background/ResourcesPanel/ResourcesScreen/EnergyValue
@onready var notes_screen: Control = $Background/NotesPanel
@onready var notes_list: VBoxContainer = $Background/NotesPanel/NotesScreen/NotesList
@onready var note_reader: Control = $Background/NoteReaderPanel
@onready var note_title: Label = $Background/NoteReaderPanel/NoteReader/Title
@onready var note_text: Label = $Background/NoteReaderPanel/NoteReader/NoteScroll/NoteText
@onready var energy_value: Label = $Background/Center/Menu/EnergyValue
@onready var player_status_value: Label = $Background/Center/Menu/PlayerStatusValue
@onready var ammo_button: Button = $Background/ResourcesPanel/ResourcesScreen/ActionsGrid/AmmoButton
@onready var health_button: Button = $Background/ResourcesPanel/ResourcesScreen/ActionsGrid/HealthButton
@onready var resources_button: Button = $Background/Center/Menu/ActionsGrid/ResourcesButton
@onready var exchange_button: Button = $Background/ResourcesPanel/ResourcesScreen/ActionsGrid/ExchangeButton
@onready var exchange_cells_button: Button = $Background/ResourcesPanel/ResourcesScreen/ActionsGrid/ExchangeCellsButton
@onready var return_mega_core_button: Button = $Background/ResourcesPanel/ResourcesScreen/ActionsGrid/ReturnMegaCoreButton
@onready var door_button: Button = $Background/Center/Menu/ActionsGrid/DoorButton
@onready var upgrades_button: Button = $Background/Center/Menu/ActionsGrid/UpgradesButton
@onready var turret_button: Button = $Background/ResourcesPanel/ResourcesScreen/ActionsGrid/TurretButton
@onready var tower_button: Button = $Background/ResourcesPanel/ResourcesScreen/ActionsGrid/TowerButton
@onready var maintenance_reserve_button: Button = $Background/ResourcesPanel/ResourcesScreen/ActionsGrid/MaintenanceReserveButton
@onready var instructions_button: Button = $Background/Center/Menu/ActionsGrid/InstructionsButton
@onready var information_button: Button = $Background/Center/Menu/ActionsGrid/InformationButton
@onready var notes_button: Button = $Background/Center/Menu/ActionsGrid/NotesButton
@onready var damage_upgrade_button: Button = $Background/UpgradesPanel/UpgradesScreen/ActionsGrid/DamageUpgradeButton
@onready var health_upgrade_button: Button = $Background/UpgradesPanel/UpgradesScreen/ActionsGrid/HealthUpgradeButton
@onready var ammo_upgrade_button: Button = $Background/UpgradesPanel/UpgradesScreen/ActionsGrid/AmmoUpgradeButton
@onready var turret_health_upgrade_button: Button = $Background/UpgradesPanel/UpgradesScreen/ActionsGrid/TurretHealthUpgradeButton
@onready var turret_damage_upgrade_button: Button = $Background/UpgradesPanel/UpgradesScreen/ActionsGrid/TurretDamageUpgradeButton
@onready var turret_ammo_upgrade_button: Button = $Background/UpgradesPanel/UpgradesScreen/ActionsGrid/TurretAmmoUpgradeButton
@onready var tower_health_upgrade_button: Button = $Background/UpgradesPanel/UpgradesScreen/ActionsGrid/TowerHealthUpgradeButton
@onready var tower_radius_upgrade_button: Button = $Background/UpgradesPanel/UpgradesScreen/ActionsGrid/TowerRadiusUpgradeButton
@onready var exit_button: Button = $Background/Center/Menu/ActionsGrid/ExitButton
@onready var instructions_back_button: Button = $Background/InstructionsPanel/InstructionsScreen/BackButton
@onready var information_back_button: Button = $Background/InformationPanel/InformationScreen/BackButton
@onready var upgrades_back_button: Button = $Background/UpgradesPanel/UpgradesScreen/BackButton
@onready var resources_back_button: Button = $Background/ResourcesPanel/ResourcesScreen/BackButton
@onready var notes_back_button: Button = $Background/NotesPanel/NotesScreen/BackButton
@onready var note_back_button: Button = $Background/NoteReaderPanel/NoteReader/BackButton

var _station_id := 1
var _open_note_number := 0
var _station_one_buttons: Array[Button] = []
var _upgrade_buttons: Array[Button] = []
var _player_status_values: Array[Label] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	instructions_text.text = LoreText.station_instructions()
	Localization.language_changed.connect(_on_language_changed)
	for node in find_children("PlayerStatusValue", "Label", true, false):
		_player_status_values.append(node as Label)
	_station_one_buttons = [
		resources_button,
		door_button,
		upgrades_button,
		instructions_button,
	]
	_upgrade_buttons = [
		damage_upgrade_button,
		health_upgrade_button,
		ammo_upgrade_button,
		turret_health_upgrade_button,
		turret_damage_upgrade_button,
		turret_ammo_upgrade_button,
		tower_health_upgrade_button,
		tower_radius_upgrade_button,
	]


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open(show_instructions: bool = false, station_id: int = 1) -> void:
	AudioManager.play_station_open()
	AudioManager.set_station_music_active(true)
	_station_id = station_id
	title.text = tr("Станция %d") % station_id
	for button in _station_one_buttons:
		button.visible = station_id == 1
	door_button.visible = station_id == 1 and game.door_gameplay_enabled()
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
	upgrades_screen.visible = false
	resources_screen.visible = false
	notes_screen.visible = false
	note_reader.visible = false
	if door_button.visible and not door_button.disabled:
		door_button.grab_focus()
	elif resources_button.visible and not resources_button.disabled:
		resources_button.grab_focus()
	else:
		exit_button.grab_focus()


func _show_instructions() -> void:
	menu.visible = false
	instructions_screen.visible = true
	information_screen.visible = false
	upgrades_screen.visible = false
	resources_screen.visible = false
	notes_screen.visible = false
	note_reader.visible = false
	instructions_scroll.scroll_vertical = 0
	instructions_back_button.grab_focus()


func _show_information() -> void:
	var statistics: Dictionary = game.station_statistics()
	var total_floor_cells: int = statistics.total_floor_cells
	var enemy_count_text: String = tr("Врагов на карте: %d\n") % (
		statistics.living_enemies
	)
	if statistics.living_enemies != statistics.target_enemies:
		enemy_count_text = tr(
			"Врагов на карте: %d (целевое: %d)\n"
		) % [statistics.living_enemies, statistics.target_enemies]
	information_text.text = (
		tr("Исследовано клеток: %d (%.1f%%)\n")
		+ tr("Размер безопасной зоны: %d (%.1f%%)\n")
		+ tr("Убито врагов: %d\n")
		+ enemy_count_text
		+ tr("Возвращено мегаядер: %d\n")
		+ tr("Получено энергии: %d\n")
		+ tr("Потрачено энергии: %d\n")
		+ tr("Осталось энергии: %d\n\n")
		+ tr("Уровни врагов:\n%s")
	) % [
		statistics.explored_cells,
		_percentage(statistics.explored_cells, total_floor_cells),
		statistics.safe_zone_size,
		_percentage(statistics.safe_zone_size, total_floor_cells),
		statistics.enemies_killed,
		statistics.mega_cores_returned,
		statistics.energy_received,
		statistics.energy_spent,
		statistics.energy_remaining,
		statistics.enemy_level_summary,
	]
	menu.visible = false
	instructions_screen.visible = false
	information_screen.visible = true
	upgrades_screen.visible = false
	resources_screen.visible = false
	notes_screen.visible = false
	note_reader.visible = false
	information_back_button.grab_focus()


func _show_upgrades() -> void:
	menu.visible = false
	instructions_screen.visible = false
	information_screen.visible = false
	upgrades_screen.visible = true
	resources_screen.visible = false
	notes_screen.visible = false
	note_reader.visible = false
	for button in _upgrade_buttons:
		if not button.disabled:
			button.grab_focus()
			return
	upgrades_back_button.grab_focus()


func _show_resources() -> void:
	menu.visible = false
	instructions_screen.visible = false
	information_screen.visible = false
	upgrades_screen.visible = false
	resources_screen.visible = true
	notes_screen.visible = false
	note_reader.visible = false
	if not return_mega_core_button.disabled:
		return_mega_core_button.grab_focus()
	elif not exchange_button.disabled:
		exchange_button.grab_focus()
	elif not exchange_cells_button.disabled:
		exchange_cells_button.grab_focus()
	elif not health_button.disabled:
		health_button.grab_focus()
	elif not ammo_button.disabled:
		ammo_button.grab_focus()
	elif not turret_button.disabled:
		turret_button.grab_focus()
	elif not tower_button.disabled:
		tower_button.grab_focus()
	else:
		resources_back_button.grab_focus()


func _show_notes() -> void:
	menu.visible = false
	instructions_screen.visible = false
	information_screen.visible = false
	upgrades_screen.visible = false
	resources_screen.visible = false
	notes_screen.visible = true
	note_reader.visible = false
	var unlocked_count: int = game.unlocked_note_count()
	for index in notes_list.get_child_count():
		var button := notes_list.get_child(index) as Button
		button.visible = index < unlocked_count
	if unlocked_count > 0:
		(notes_list.get_child(0) as Button).grab_focus()
	else:
		notes_back_button.grab_focus()


func _show_note(note_number: int) -> void:
	_open_note_number = note_number
	notes_screen.visible = false
	note_reader.visible = true
	note_title.text = tr("Заметка %d") % note_number
	note_text.text = LoreText.note_text(note_number)
	note_back_button.grab_focus()


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
	_show_resources()


func _on_health_pressed() -> void:
	game.buy_health()
	_update_buttons()
	_show_resources()


func _on_exchange_pressed() -> void:
	game.exchange_energy_cores()
	_update_buttons()
	_show_resources()


func _on_exchange_cells_pressed() -> void:
	game.exchange_exploration_points()
	_update_buttons()
	_show_resources()


func _on_return_mega_core_pressed() -> void:
	game.return_mega_core()
	_update_buttons()
	_show_resources()


func _on_door_pressed() -> void:
	game.buy_door()
	_update_buttons()
	_show_menu()


func _on_turret_pressed() -> void:
	game.buy_turret()
	_update_buttons()
	_show_resources()


func _on_tower_pressed() -> void:
	game.buy_tower()
	_update_buttons()
	_show_resources()


func _on_maintenance_reserve_pressed() -> void:
	game.fund_maintenance_reserve()
	_update_buttons()
	_show_resources()


func _on_upgrades_pressed() -> void:
	_show_upgrades()


func _on_resources_pressed() -> void:
	_show_resources()


func _on_instructions_pressed() -> void:
	_show_instructions()


func _on_information_pressed() -> void:
	_show_information()


func _on_notes_pressed() -> void:
	_show_notes()


func _on_note_one_pressed() -> void:
	_show_note(0)


func _on_note_two_pressed() -> void:
	_show_note(1)


func _on_note_three_pressed() -> void:
	_show_note(2)


func _on_note_four_pressed() -> void:
	_show_note(3)


func _on_damage_upgrade_pressed() -> void:
	game.upgrade_player_damage(1)
	_update_buttons()
	_show_upgrades()


func _on_health_upgrade_pressed() -> void:
	game.upgrade_player_health(1)
	_update_buttons()
	_show_upgrades()


func _on_ammo_upgrade_pressed() -> void:
	game.upgrade_player_ammo(1)
	_update_buttons()
	_show_upgrades()


func _on_turret_health_upgrade_pressed() -> void:
	game.upgrade_turret_health()
	_update_buttons()
	_show_upgrades()


func _on_turret_damage_upgrade_pressed() -> void:
	game.upgrade_turret_damage()
	_update_buttons()
	_show_upgrades()


func _on_turret_ammo_upgrade_pressed() -> void:
	game.upgrade_turret_ammo()
	_update_buttons()
	_show_upgrades()


func _on_tower_health_upgrade_pressed() -> void:
	game.upgrade_tower_health()
	_update_buttons()
	_show_upgrades()


func _on_tower_radius_upgrade_pressed() -> void:
	game.upgrade_tower_radius()
	_update_buttons()
	_show_upgrades()


func _on_instructions_back_pressed() -> void:
	_show_menu()


func _on_information_back_pressed() -> void:
	_show_menu()


func _on_upgrades_back_pressed() -> void:
	_show_menu()


func _on_resources_back_pressed() -> void:
	_show_menu()


func _on_notes_back_pressed() -> void:
	_show_menu()


func _on_note_back_pressed() -> void:
	_show_notes()


func _on_exit_pressed() -> void:
	AudioManager.play_station_close()
	close()


func _update_buttons() -> void:
	var safe_zone_seconds: int = game.safe_zone_time_seconds()
	var energy_text := tr("Энергия: %d    Резерв обслуживания: %d") % [
		game.player.energy,
		game.player.maintenance_energy,
	]
	energy_value.text = energy_text
	upgrades_energy_value.text = energy_text
	resources_energy_value.text = energy_text
	var player_status_text := tr(
		"Здоровье: %d/%d    Патроны: %d/%d    Турели: %d    Башни: %d\nПитание сети: %02d:%02d"
	) % [
		game.player.health,
		game.player.max_health,
		game.player.ammo,
		game.player.max_ammo,
		game.player.turret_inventory_count(),
		game.player.tower_inventory_count(),
		floori(float(safe_zone_seconds) / 60.0),
		safe_zone_seconds % 60,
	]
	for status_value in _player_status_values:
		status_value.text = player_status_text

	var ammo_amount: int = game.player.ammo_purchase_amount()
	var ammo_cost: int = game.player.ammo_purchase_cost()
	ammo_button.disabled = ammo_amount <= 0 or game.player.energy < ammo_cost
	ammo_button.text = (
		tr("Полный боезапас")
		if ammo_amount <= 0
		else tr("Купить %d патронов за %d энергии") % [ammo_amount, ammo_cost]
	)

	var health_amount: int = game.player.health_purchase_amount()
	var health_cost: int = game.player.health_purchase_cost()
	health_button.disabled = health_amount <= 0 or game.player.energy < health_cost
	health_button.text = (
		tr("Полное здоровье")
		if health_amount <= 0
		else tr("Восстановить %d здоровья за %d энергии") % [
			health_amount,
			health_cost,
		]
	)

	exchange_button.disabled = game.player.energy_cores <= 0
	exchange_button.text = (
		tr("Нет энергоядер")
		if game.player.energy_cores <= 0
		else tr("Сдать энергоядра: +%d энергии") % (
			game.player.energy_core_exchange_energy()
		)
	)

	var exchanged_points: int = game.player.exploration_exchange_points()
	var exchange_energy: int = game.player.exploration_exchange_energy()
	exchange_cells_button.disabled = exchanged_points <= 0
	exchange_cells_button.text = (
		tr("Нужно %d очков исследования") % Player.EXPLORATION_POINTS_PER_ENERGY
		if exchanged_points <= 0
		else tr("Сдать %d очков: +%d энергии") % [
			exchanged_points,
			exchange_energy,
		]
	)

	return_mega_core_button.disabled = not game.player.has_carried_mega_cores()
	return_mega_core_button.text = (
		tr("Сдать мегаядра (%d): +%d энергии") % [
			game.player.carried_mega_core_count(),
			game.player.carried_mega_core_energy(),
		]
		if game.player.has_carried_mega_cores()
		else tr("Нет мегаядер для сдачи")
	)
	door_button.disabled = not game.player.can_buy_door()
	door_button.text = (
		tr("Двери: максимум")
		if not game.player.can_store_door()
		else tr("Купить дверь за %d энергии") % Player.DOOR_COST
	)
	turret_button.disabled = not game.player.can_buy_turret()
	turret_button.text = (
		tr("Турели: максимум")
		if not game.player.can_store_turret()
		else tr("Купить турель за %d энергии") % Player.TURRET_COST
	)
	tower_button.disabled = not game.player.can_buy_tower()
	tower_button.text = (
		tr("Башни: максимум")
		if not game.player.can_store_tower()
		else tr("Купить башню за %d энергии") % Player.TOWER_COST
	)
	maintenance_reserve_button.disabled = not game.can_fund_maintenance_reserve()
	maintenance_reserve_button.text = tr(
		"Добавить %d энергии в резерв обслуживания"
	) % Player.MAINTENANCE_RESERVE_TRANSFER
	resources_button.disabled = health_button.disabled \
			and ammo_button.disabled \
			and turret_button.disabled \
			and tower_button.disabled \
			and exchange_button.disabled \
			and exchange_cells_button.disabled \
			and return_mega_core_button.disabled \
			and maintenance_reserve_button.disabled

	damage_upgrade_button.disabled = not game.can_upgrade_player_damage(1)
	damage_upgrade_button.text = _upgrade_button_text(
		tr("Урон"),
		game.player.damage_upgrade_level
	)
	health_upgrade_button.disabled = not game.can_upgrade_player_health(1)
	health_upgrade_button.text = _upgrade_button_text(
		tr("Здоровье"),
		game.player.health_upgrade_level
	)
	ammo_upgrade_button.disabled = not game.can_upgrade_player_ammo(1)
	ammo_upgrade_button.text = _upgrade_button_text(
		tr("Боезапас"),
		game.player.ammo_upgrade_level
	)
	turret_health_upgrade_button.disabled = not game.can_upgrade_turret_health()
	turret_health_upgrade_button.text = _structure_upgrade_button_text(
		tr("Здоровье турели"),
		game.player.turret_health_upgrade_level
	)
	turret_damage_upgrade_button.disabled = not game.can_upgrade_turret_damage()
	turret_damage_upgrade_button.text = _structure_upgrade_button_text(
		tr("Урон турели"),
		game.player.turret_damage_upgrade_level
	)
	turret_ammo_upgrade_button.disabled = not game.can_upgrade_turret_ammo()
	turret_ammo_upgrade_button.text = _structure_upgrade_button_text(
		tr("Боезапас турели"),
		game.player.turret_ammo_upgrade_level
	)
	tower_health_upgrade_button.disabled = not game.can_upgrade_tower_health()
	tower_health_upgrade_button.text = _structure_upgrade_button_text(
		tr("Здоровье башни"),
		game.player.tower_health_upgrade_level
	)
	tower_radius_upgrade_button.disabled = not game.can_upgrade_tower_radius()
	tower_radius_upgrade_button.text = _structure_upgrade_button_text(
		tr("Радиус башни"),
		game.player.tower_radius_upgrade_level
	)


func _structure_upgrade_button_text(label: String, level: int) -> String:
	if level >= Player.MAX_UPGRADE_LEVEL:
		return tr("%s: максимум") % label
	return tr("%s: уровень %d/%d за %d энергии") % [
		label,
		level + 2,
		Player.PLAYER_LEVEL_COUNT,
		Player.UPGRADE_COST,
	]


func _upgrade_button_text(label: String, level: int) -> String:
	if _station_id == 1:
		if level >= Player.MAX_UPGRADE_LEVEL:
			return tr("%s: максимум") % label
		return tr("%s: уровень %d/%d за %d энергии") % [
			label,
			level + 2,
			Player.PLAYER_LEVEL_COUNT,
			Player.UPGRADE_COST,
		]
	var station_minimum := (_station_id - 2) * Player.UPGRADES_PER_STATION
	var station_maximum := station_minimum + Player.UPGRADES_PER_STATION
	if level < station_minimum:
		return tr("%s: нужна предыдущая станция") % label
	if level >= station_maximum and level < Player.MAX_UPGRADE_LEVEL:
		return tr("%s: на этой станции максимум") % label
	if level >= Player.MAX_UPGRADE_LEVEL:
		return tr("%s: максимум") % label
	return tr("%s: уровень %d/%d за %d энергии") % [
		label,
		level + 2,
		Player.PLAYER_LEVEL_COUNT,
		Player.UPGRADE_COST,
	]


func _on_language_changed() -> void:
	title.text = tr("Станция %d") % _station_id
	instructions_text.text = LoreText.station_instructions()
	_update_buttons()
	if information_screen.visible:
		_show_information()
	elif notes_screen.visible:
		_show_notes()
	elif note_reader.visible and _open_note_number > 0:
		_show_note(_open_note_number)
