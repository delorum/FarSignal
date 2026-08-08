extends StaticBody2D
class_name Tower

const MAX_HEALTH := Player.TOWER_MAX_HEALTH
const ANIMATION_FRAME_COUNT := 5
const ANIMATION_FPS := 5.0
const DISCONNECTED_MODULATE := Color(0.45, 0.5, 0.54, 0.72)
const EXPLORED_MODULATE := Color(0.34, 0.38, 0.4, 0.82)
const HEALTH_LABEL_Y := 38.0

var cell := Vector2i(-1, -1)
var health := MAX_HEALTH
var max_health := MAX_HEALTH
var connected := false
var connection_target := Vector2.INF

var _game: Node
var _normally_visible := false
var _explored := false
var _animation_time := 0.0

@onready var tower_sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_update_sprite_state()


func _process(delta: float) -> void:
	if not _normally_visible:
		return
	_animation_time += delta
	tower_sprite.frame = posmod(
		floori(_animation_time * ANIMATION_FPS),
		ANIMATION_FRAME_COUNT
	)


func setup(
	game: Node,
	tower_cell: Vector2i,
	world_position: Vector2,
	saved_health: int = MAX_HEALTH
) -> void:
	_game = game
	cell = tower_cell
	position = world_position
	max_health = game.player.tower_max_health()
	health = clampi(saved_health, 0, max_health)
	z_index = 2
	visible = false
	queue_redraw()


func save_data() -> Dictionary:
	return {
		"cell": [cell.x, cell.y],
		"position": [position.x, position.y],
		"health": health,
	}


func take_damage(amount: int) -> bool:
	health = maxi(0, health - amount)
	if health <= 0:
		_game.destroy_tower(self)
		return true
	queue_redraw()
	return false


func show_damage_number(amount: int, direction: Vector2) -> void:
	_game.spawn_damage_number(position, amount, direction)


func is_active() -> bool:
	return health > 0


func apply_upgraded_maximum(
	new_max_health: int,
	refill_increase: bool = true
) -> void:
	var health_increase := maxi(0, new_max_health - max_health)
	max_health = new_max_health
	if refill_increase:
		health = mini(max_health, health + health_increase)
	else:
		health = mini(health, max_health)
	queue_redraw()


func set_connection(is_connected: bool, target: Vector2 = Vector2.INF) -> void:
	if connected == is_connected and connection_target == target:
		return
	connected = is_connected
	connection_target = target
	_update_sprite_state()
	queue_redraw()


func update_visibility(currently_visible: bool, explored: bool) -> void:
	if _normally_visible == currently_visible and _explored == explored:
		return
	_normally_visible = currently_visible
	_explored = explored
	visible = currently_visible or explored
	_update_sprite_state()
	queue_redraw()


func _draw() -> void:
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-16.0, HEALTH_LABEL_Y),
		str(health),
		HORIZONTAL_ALIGNMENT_CENTER,
		32.0,
		14,
		Color(0.9, 0.25, 0.27, 1.0)
	)


func _update_sprite_state() -> void:
	if not is_node_ready():
		return
	if _explored and not _normally_visible:
		tower_sprite.modulate = EXPLORED_MODULATE
	else:
		tower_sprite.modulate = (
			Color.WHITE if connected else DISCONNECTED_MODULATE
		)
