extends Control

const LoreText = preload("res://scripts/lore_text.gd")

@onready var game: Node = $"../.."
@onready var menu: VBoxContainer = $Background/Center/Menu
@onready var instructions_screen: Control = $Background/InstructionsPanel
@onready var instructions_text: Label = $Background/InstructionsPanel/InstructionsScreen/InstructionsText
@onready var energy_value: Label = $Background/Center/Menu/EnergyValue
@onready var ammo_button: Button = $Background/Center/Menu/ActionsGrid/AmmoButton
@onready var health_button: Button = $Background/Center/Menu/ActionsGrid/HealthButton
@onready var exchange_button: Button = $Background/Center/Menu/ActionsGrid/ExchangeButton
@onready var exchange_cells_button: Button = $Background/Center/Menu/ActionsGrid/ExchangeCellsButton
@onready var return_mega_core_button: Button = $Background/Center/Menu/ActionsGrid/ReturnMegaCoreButton
@onready var door_button: Button = $Background/Center/Menu/ActionsGrid/DoorButton
@onready var turret_button: Button = $Background/Center/Menu/ActionsGrid/TurretButton
@onready var instructions_button: Button = $Background/Center/Menu/ActionsGrid/InstructionsButton
@onready var exit_button: Button = $Background/Center/Menu/ActionsGrid/ExitButton
@onready var instructions_back_button: Button = $Background/InstructionsPanel/InstructionsScreen/BackButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	instructions_text.text = LoreText.STATION_INSTRUCTIONS


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open(show_instructions: bool = false) -> void:
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
	if not exchange_button.disabled:
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
	elif not turret_button.disabled:
		turret_button.grab_focus()
	else:
		exit_button.grab_focus()


func _show_instructions() -> void:
	menu.visible = false
	instructions_screen.visible = true
	instructions_back_button.grab_focus()


func close() -> void:
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
	game.exchange_explored_floor_cells()
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


func _on_turret_pressed() -> void:
	game.buy_turret()
	_update_buttons()
	_show_menu()


func _on_instructions_pressed() -> void:
	_show_instructions()


func _on_instructions_back_pressed() -> void:
	_show_menu()


func _on_exit_pressed() -> void:
	close()


func _update_buttons() -> void:
	energy_value.text = "Энергия: %d" % game.player.energy

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
			game.player.energy_cores * Player.ENERGY_PER_CORE
		)
	)

	var exchanged_cells: int = game.player.explored_cell_exchange_cells()
	var exchange_energy: int = game.player.explored_cell_exchange_energy()
	exchange_cells_button.disabled = exchanged_cells <= 0
	exchange_cells_button.text = (
		"Нужно %d клеток для обмена" % Player.EXPLORED_CELLS_PER_EXCHANGE
		if exchanged_cells <= 0
		else "Сдать %d клеток: +%d энергии" % [
			exchanged_cells,
			exchange_energy,
		]
	)

	return_mega_core_button.disabled = not game.player.has_mega_core
	return_mega_core_button.text = (
		"Вернуть мегаядро: +%d энергии" % Player.MEGA_CORE_RETURN_ENERGY
		if game.player.has_mega_core
		else "Мегаядро не найдено"
	)

	door_button.disabled = not game.player.can_buy_door()
	door_button.text = (
		"Двери: максимум"
		if not game.player.can_store_door()
		else "Купить дверь за %d энергии" % Player.DOOR_COST
	)

	turret_button.disabled = not game.player.can_buy_turret()
	turret_button.text = (
		"Турели: максимум"
		if not game.player.can_store_turret()
		else "Купить турель за %d энергии" % Player.TURRET_COST
	)
