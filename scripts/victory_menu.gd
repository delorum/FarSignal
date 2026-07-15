extends Control

const MAIN_MENU_SCENE := "res://scenes/menu.tscn"

@onready var kills_value: Label = $Background/Center/Menu/KillsValue
@onready var explored_value: Label = $Background/Center/Menu/ExploredValue
@onready var safe_zone_value: Label = $Background/Center/Menu/SafeZoneValue
@onready var mega_cores_value: Label = $Background/Center/Menu/MegaCoresValue
@onready var energy_value: Label = $Background/Center/Menu/EnergyValue


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func open(
	enemies_killed: int,
	explored_cells: int,
	safe_zone_size: int,
	total_floor_cells: int,
	mega_cores_returned: int,
	energy_received: int,
	energy_spent: int,
	energy_remaining: int
) -> void:
	kills_value.text = tr("Убито врагов: %d") % enemies_killed
	explored_value.text = tr("Исследовано клеток: %d (%.1f%%)") % [
		explored_cells,
		_percentage(explored_cells, total_floor_cells),
	]
	safe_zone_value.text = tr("Размер безопасной зоны: %d (%.1f%%)") % [
		safe_zone_size,
		_percentage(safe_zone_size, total_floor_cells),
	]
	mega_cores_value.text = tr("Возвращено мегаядер: %d") % mega_cores_returned
	energy_value.text = (
		tr("Получено энергии: %d\nПотрачено энергии: %d\nОсталось энергии: %d")
	) % [energy_received, energy_spent, energy_remaining]
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _percentage(value: int, total: int) -> float:
	if total <= 0:
		return 0.0
	return float(value) * 100.0 / float(total)


func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
