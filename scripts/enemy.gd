extends CharacterBody2D
class_name Enemy

const MAX_HEALTH := 100
const SPEED := 175.0
const CELL_SIZE := 48.0
const BODY_COLOR := Color("c84545")
const EDGE_COLOR := Color("ff8a7f")
const DEAD_COLOR := Color("3b4148")
const DEAD_EDGE_COLOR := Color("626b75")
const HEARING_INTERVAL := 5.0
const SHOOT_INTERVAL := 2.0
const STEP_HEARING_RANGE := 20.0
const VISION_RANGE := 30.0
const TARGET_ATTEMPTS := 12

var level := 9
var health := MAX_HEALTH
var dead := false
var _facing := Vector2.LEFT
var _path: Array[Vector2i] = []
var _path_index := 0
var _hearing_cooldown := 0.0
var _shoot_cooldown := 0.0
var _active := false
var _player_was_safe := false
var _game: Node
var _maze: Maze
var _player: Player
var _rng := RandomNumberGenerator.new()

@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func setup(
	game: Node,
	maze: Maze,
	player: Player,
	enemy_level: int,
	start_cell: Vector2i,
	random_seed: int
) -> void:
	_game = game
	_maze = maze
	_player = player
	level = enemy_level
	position = maze.cell_to_world(start_cell)
	_rng.seed = random_seed
	visible = false


func restore_state(saved_data: Dictionary) -> void:
	var saved_position: Array = saved_data.get("position", [])
	if saved_position.size() == 2:
		position = Vector2(float(saved_position[0]), float(saved_position[1]))
	health = clampi(int(saved_data.get("health", MAX_HEALTH)), 0, MAX_HEALTH)
	dead = bool(saved_data.get("dead", health <= 0))
	if dead:
		health = 0
		_apply_dead_state()


func save_data() -> Dictionary:
	return {
		"level": level,
		"position": [position.x, position.y],
		"health": health,
		"dead": dead,
	}


func set_active(active: bool) -> void:
	_active = active and not dead
	if not _active:
		velocity = Vector2.ZERO


func update_visibility(currently_visible: bool) -> void:
	visible = currently_visible


func hear_player() -> void:
	if dead or not _active or _game.is_player_inside_station() \
			or _hearing_cooldown > 0.0:
		return
	_build_path_to(_maze.world_to_cell(_player.position))
	_hearing_cooldown = HEARING_INTERVAL


func take_damage(amount: int) -> bool:
	if dead:
		return false
	health = maxi(0, health - amount)
	if health > 0:
		return false

	dead = true
	_active = false
	velocity = Vector2.ZERO
	_apply_dead_state()
	_path.clear()
	_game.enemy_killed(self)
	queue_redraw()
	return true


func _apply_dead_state() -> void:
	collision_layer = 0
	collision_mask = 0
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if dead or not _active:
		return

	_hearing_cooldown = maxf(0.0, _hearing_cooldown - delta)
	_shoot_cooldown = maxf(0.0, _shoot_cooldown - delta)

	var player_is_safe: bool = _game.is_player_inside_station()
	if player_is_safe:
		if not _player_was_safe or _path.is_empty() \
				or _path_index >= _path.size():
			_choose_random_target()
		_player_was_safe = true
		_follow_path()
		return
	_player_was_safe = false

	var player_cell := _maze.world_to_cell(_player.position)
	var distance_to_player := Vector2(
		player_cell - _maze.world_to_cell(position)
	).length()
	var sees_player := distance_to_player <= VISION_RANGE \
			and _maze.has_line_of_sight(position, _player.position, VISION_RANGE)

	if sees_player:
		_facing = position.direction_to(_player.position)
		queue_redraw()
		if _shoot_cooldown <= 0.0:
			_game.spawn_enemy_bullet(position, _facing)
			_shoot_cooldown = SHOOT_INTERVAL

	if _player.is_moving() and distance_to_player <= STEP_HEARING_RANGE \
			and _hearing_cooldown <= 0.0:
		hear_player()

	if _path.is_empty() or _path_index >= _path.size():
		_choose_random_target()
	_follow_path()


func _follow_path() -> void:
	if _path_index >= _path.size():
		velocity = Vector2.ZERO
		return

	if not _maze.is_cell_walkable(_path[_path_index], true):
		_choose_random_target()
		if _path_index >= _path.size():
			velocity = Vector2.ZERO
			return

	var target_position := _maze.cell_to_world(_path[_path_index])
	var offset := target_position - position
	if offset.length() < 5.0:
		_path_index += 1
		_follow_path()
		return

	_facing = offset.normalized()
	velocity = _facing * SPEED
	move_and_slide()
	queue_redraw()


func _choose_random_target() -> void:
	for attempt in TARGET_ATTEMPTS:
		var target := _maze.get_random_floor_cell_in_level(_rng, level, true)
		if target.x < 0:
			return
		if _build_path_to(target):
			return
	_path.clear()


func _build_path_to(target: Vector2i) -> bool:
	var start := _maze.world_to_cell(position)
	_path = _maze.find_path(start, target, level, true)
	_path_index = 0
	return not _path.is_empty()


func _draw() -> void:
	var body_color := DEAD_COLOR if dead else BODY_COLOR
	var edge_color := DEAD_EDGE_COLOR if dead else EDGE_COLOR
	draw_circle(Vector2.ZERO, 14.0, body_color)
	draw_circle(Vector2.ZERO, 14.0, edge_color, false, 2.0, true)
	if not dead:
		draw_line(Vector2.ZERO, _facing * 11.0, edge_color, 3.0, true)
