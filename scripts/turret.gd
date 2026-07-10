extends StaticBody2D
class_name Turret

const MAX_HEALTH := Player.TURRET_MAX_HEALTH
const MAX_AMMO := Player.TURRET_MAX_AMMO
const VISION_RANGE := 30.0
const VISION_HALF_ANGLE := PI * 0.5
const TURN_SPEED := deg_to_rad(180.0)
const AIM_TOLERANCE := deg_to_rad(6.0)
const SHOOT_INTERVAL := 1.0
const BODY_RADIUS := 24.0
const BARREL_LENGTH := 20.0
const STATUS_BACK_OFFSET := 18.0
const STATUS_SIDE_OFFSET := 10.0
const IDLE_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const FIRING_COLOR := Color("e03f43")
const AMMO_TEXT_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const HEALTH_TEXT_COLOR := Color(0.9, 0.25, 0.27, 1.0)
const OUTLINE_WIDTH := 2.0

var cell := Vector2i(-1, -1)
var health := MAX_HEALTH
var ammo := MAX_AMMO
var base_direction := Vector2.RIGHT
var aim_direction := Vector2.RIGHT
var firing := false

var _game: Node
var _maze: Maze
var _enemies: Node2D
var _shoot_cooldown := 0.0
var _firing_flash_left := 0.0

@onready var turret_sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_update_sprite()


func setup(
	game: Node,
	maze: Maze,
	enemies: Node2D,
	turret_cell: Vector2i,
	facing_direction: Vector2,
	saved_health: int = MAX_HEALTH,
	saved_ammo: int = MAX_AMMO,
	world_position: Vector2 = Vector2.INF
) -> void:
	_game = game
	_maze = maze
	_enemies = enemies
	cell = turret_cell
	position = maze.cell_to_world(cell) if world_position == Vector2.INF else world_position
	base_direction = (
		Vector2.RIGHT
		if facing_direction.is_zero_approx()
		else facing_direction.normalized()
	)
	aim_direction = base_direction
	health = clampi(saved_health, 0, MAX_HEALTH)
	ammo = clampi(saved_ammo, 0, MAX_AMMO)
	z_index = 2
	_update_sprite()


func save_data() -> Dictionary:
	return {
		"cell": [cell.x, cell.y],
		"position": [position.x, position.y],
		"base_direction": [base_direction.x, base_direction.y],
		"aim_direction": [aim_direction.x, aim_direction.y],
		"health": health,
		"ammo": ammo,
	}


func inventory_data() -> Dictionary:
	return {
		"health": health,
		"ammo": ammo,
	}


func take_damage(amount: int) -> bool:
	health = maxi(0, health - amount)
	if health <= 0:
		_game.destroy_turret(self)
		return true
	queue_redraw()
	return false


func show_damage_number(amount: int, direction: Vector2) -> void:
	_game.spawn_damage_number(position, amount, direction)


func is_active() -> bool:
	return health > 0 and ammo > 0


func _process(delta: float) -> void:
	if not is_active():
		_game.destroy_turret(self)
		return

	_shoot_cooldown = maxf(0.0, _shoot_cooldown - delta)
	_firing_flash_left = maxf(0.0, _firing_flash_left - delta)
	firing = _firing_flash_left > 0.0

	var target := _visible_target()
	if target != null:
		var desired_direction := _clamp_to_arc(position.direction_to(target.position))
		aim_direction = aim_direction.rotated(
			clampf(
				aim_direction.angle_to(desired_direction),
				-TURN_SPEED * delta,
				TURN_SPEED * delta
			)
		).normalized()
		if _shoot_cooldown <= 0.0 and _is_aimed_at(desired_direction):
			_fire()
	else:
		aim_direction = aim_direction.rotated(
			clampf(
				aim_direction.angle_to(base_direction),
				-TURN_SPEED * delta,
				TURN_SPEED * delta
			)
		).normalized()

	queue_redraw()


func _visible_target() -> Node:
	if _enemies == null or _maze == null:
		return null

	var best_enemy: Enemy
	var best_distance := INF
	for enemy: Enemy in _enemies.get_children():
		if enemy.dead:
			continue
		var offset := enemy.position - position
		var distance_cells := offset.length() / Maze.CELL_SIZE
		if distance_cells > VISION_RANGE:
			continue
		var direction := offset.normalized()
		if absf(base_direction.angle_to(direction)) > VISION_HALF_ANGLE:
			continue
		if not _game.enemy_has_line_of_sight(
			position,
			enemy.position,
			VISION_RANGE
		):
			continue
		if distance_cells < best_distance:
			best_distance = distance_cells
			best_enemy = enemy
	return best_enemy


func _clamp_to_arc(direction: Vector2) -> Vector2:
	if direction.is_zero_approx():
		return base_direction
	var angle := clampf(
		base_direction.angle_to(direction.normalized()),
		-VISION_HALF_ANGLE,
		VISION_HALF_ANGLE
	)
	return base_direction.rotated(angle).normalized()


func _is_aimed_at(direction: Vector2) -> bool:
	return absf(aim_direction.angle_to(direction)) <= AIM_TOLERANCE


func _fire() -> void:
	if ammo <= 0:
		return
	_game.spawn_turret_bullet(position, aim_direction, self)
	ammo -= 1
	_shoot_cooldown = SHOOT_INTERVAL
	_firing_flash_left = 0.18
	firing = true
	if ammo <= 0:
		_game.destroy_turret(self)


func _draw() -> void:
	var body_color := FIRING_COLOR if firing else IDLE_COLOR
	_update_sprite()
	if turret_sprite == null or turret_sprite.texture == null:
		draw_circle(
			Vector2.ZERO,
			BODY_RADIUS,
			body_color,
			false,
			OUTLINE_WIDTH,
			true
		)
		draw_line(
			Vector2.ZERO,
			aim_direction * BARREL_LENGTH,
			body_color,
			3.0,
			true
		)
	var back_direction := -aim_direction.normalized()
	var side_direction := Vector2(-aim_direction.y, aim_direction.x).normalized()
	var status_position := (
		back_direction * (BODY_RADIUS + STATUS_BACK_OFFSET)
		+ side_direction * STATUS_SIDE_OFFSET
	)
	draw_string(
		ThemeDB.fallback_font,
		status_position,
		str(ammo),
		HORIZONTAL_ALIGNMENT_LEFT,
		40.0,
		14,
		AMMO_TEXT_COLOR
	)
	draw_string(
		ThemeDB.fallback_font,
		status_position + Vector2(0.0, 16.0),
		str(health),
		HORIZONTAL_ALIGNMENT_LEFT,
		40.0,
		14,
		HEALTH_TEXT_COLOR
	)


func _update_sprite() -> void:
	if turret_sprite == null:
		return
	turret_sprite.rotation = aim_direction.angle()
	turret_sprite.modulate = (
		FIRING_COLOR
		if firing
		else IDLE_COLOR
	)
