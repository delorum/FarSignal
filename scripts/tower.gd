extends StaticBody2D
class_name Tower

const MAX_HEALTH := Player.TOWER_MAX_HEALTH
const TRIANGLE_RADIUS := 20.0
const CONNECTED_COLOR := Color(0.35, 0.82, 0.92, 1.0)
const OUTLINE_COLOR := Color(0.58, 0.64, 0.7, 1.0)
const CONNECTION_COLOR := Color(1.0, 0.82, 0.18, 0.38)
const OUTLINE_WIDTH := 2.5

var cell := Vector2i(-1, -1)
var health := MAX_HEALTH
var connected := false
var connection_target := Vector2.INF

var _game: Node
var _normally_visible := false


func setup(
	game: Node,
	tower_cell: Vector2i,
	world_position: Vector2,
	saved_health: int = MAX_HEALTH
) -> void:
	_game = game
	cell = tower_cell
	position = world_position
	health = clampi(saved_health, 0, MAX_HEALTH)
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


func set_connection(is_connected: bool, target: Vector2 = Vector2.INF) -> void:
	if connected == is_connected and connection_target == target:
		return
	connected = is_connected
	connection_target = target
	queue_redraw()


func update_visibility(currently_visible: bool) -> void:
	if _normally_visible == currently_visible:
		return
	_normally_visible = currently_visible
	visible = currently_visible
	queue_redraw()


func _draw() -> void:
	if connected and connection_target != Vector2.INF:
		draw_line(
			Vector2.ZERO,
			to_local(connection_target),
			CONNECTION_COLOR,
			3.0,
			true
		)
	var points := PackedVector2Array([
		Vector2(0.0, -TRIANGLE_RADIUS),
		Vector2(TRIANGLE_RADIUS * 0.87, TRIANGLE_RADIUS * 0.5),
		Vector2(-TRIANGLE_RADIUS * 0.87, TRIANGLE_RADIUS * 0.5),
	])
	if connected:
		draw_colored_polygon(points, CONNECTED_COLOR)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(
		outline,
		OUTLINE_COLOR,
		OUTLINE_WIDTH,
		true
	)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-16.0, TRIANGLE_RADIUS + 18.0),
		str(health),
		HORIZONTAL_ALIGNMENT_CENTER,
		32.0,
		14,
		Color(0.9, 0.25, 0.27, 1.0)
	)
