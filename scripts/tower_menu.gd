extends Control

const TRANSFER_STEP := 5

@onready var game: Node = $"../.."
@onready var tower_status: Label = $Background/Center/Menu/TowerStatus
@onready var player_status: Label = $Background/Center/Menu/PlayerStatus
@onready var health_button: Button = $Background/Center/Menu/HealthButton

var _tower: Tower


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Localization.language_changed.connect(_update_menu)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open(tower: Tower) -> void:
	_tower = tower
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_update_menu()
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
		game.transfer_health_to_tower(_tower, TRANSFER_STEP)
	_update_menu()


func _on_exit_pressed() -> void:
	close()


func _update_menu() -> void:
	if not is_instance_valid(_tower):
		return
	tower_status.text = tr("Башня: здоровье %d/%d") % [
		_tower.health,
		Tower.MAX_HEALTH,
	]
	player_status.text = tr("Игрок: здоровье %d") % game.player.health
	var amount: int = game.tower_health_transfer_amount(_tower, TRANSFER_STEP)
	health_button.disabled = amount <= 0
	health_button.text = (
		tr("Передать %d здоровья") % amount
		if amount > 0
		else tr("Здоровье передать нельзя")
	)
