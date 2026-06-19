extends CharacterBody2D
class_name Enemy

const MAX_HEALTH := 100
const PATROL_SPEED := 100.0
const ALERT_SPEED := 175.0
const CELL_SIZE := 48.0
const BODY_COLOR := Color("c84545")
const EDGE_COLOR := Color("ff8a7f")
const DEAD_COLOR := Color("3b4148")
const DEAD_EDGE_COLOR := Color("626b75")
const AMBUSH_PATROL_COLOR := Color("69717a")
const AMBUSH_ALERT_COLOR := Color("bd3f43")
const DEAD_Z_INDEX := 0
const ALIVE_Z_INDEX := 1
const AMBUSH_ARROW_LENGTH := 24.0
const AMBUSH_ARROW_HEAD_LENGTH := 7.0
const AMBUSH_ARROW_HEAD_ANGLE := deg_to_rad(32.0)
const HEARING_INTERVAL := 5.0
const SHOOT_INTERVAL := 2.0
const STEP_HEARING_RANGE := 20.0
const VISION_RANGE := 30.0
const TARGET_ATTEMPTS := 12
const SEARCH_DURATION := 5.0
const MANEUVER_CHANCE := 0.4
const MANEUVER_DISTANCE := 2
const FLANK_GROUP_RANGE := 18.0
const FLANK_DISTANCE := 6
const FLANK_DANGER_RADIUS := 5.0
const FLANK_REPATH_INTERVAL := 3.0
const FLANK_TARGET_SEARCH_RADIUS := 2
const TURN_SPEED := deg_to_rad(150.0)
const AIM_TOLERANCE := deg_to_rad(10.0)

enum State {
	PATROL,
	INVESTIGATE,
	COMBAT,
	MANEUVER,
	SEARCH,
}

var health := MAX_HEALTH
var dead := false
var state := State.PATROL
var enemy_id := 0
var _facing := Vector2.LEFT
var _desired_facing := Vector2.LEFT
var _path: Array[Vector2i] = []
var _path_index := 0
var _hearing_cooldown := 0.0
var _shoot_cooldown := 0.0
var _flank_repath_cooldown := 0.0
var _search_time_left := 0.0
var _last_known_player_cell := Vector2i(-1, -1)
var _active := true
var _normally_visible := false
var _ambush_revealed := false
var _game: Node
var _maze: Maze
var _player: Player
var _rng := RandomNumberGenerator.new()

@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func setup(
	game: Node,
	maze: Maze,
	player: Player,
	start_cell: Vector2i,
	random_seed: int,
	assigned_enemy_id: int
) -> void:
	_game = game
	_maze = maze
	_player = player
	enemy_id = assigned_enemy_id
	position = maze.cell_to_world(start_cell)
	_rng.seed = random_seed
	z_index = ALIVE_Z_INDEX
	visible = false


func restore_state(saved_data: Dictionary) -> void:
	enemy_id = int(saved_data.get("enemy_id", enemy_id))
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
		"enemy_id": enemy_id,
		"position": [position.x, position.y],
		"health": health,
		"dead": dead,
	}


func facing_direction() -> Vector2:
	return _facing


func pursuit_target_cell() -> Vector2i:
	if dead or state == State.PATROL:
		return Vector2i(-1, -1)
	return _last_known_player_cell


func is_attack_state() -> bool:
	return state == State.COMBAT or state == State.MANEUVER


func uses_ambush_marker() -> bool:
	return _ambush_revealed and not _normally_visible and not dead


func set_active(active: bool) -> void:
	_active = active and not dead
	if not _active:
		velocity = Vector2.ZERO


func update_visibility(
	currently_visible: bool,
	ambush_revealed: bool = false
) -> void:
	if _normally_visible == currently_visible \
			and _ambush_revealed == ambush_revealed:
		return
	_normally_visible = currently_visible
	_ambush_revealed = ambush_revealed and not dead
	visible = _normally_visible or _ambush_revealed
	queue_redraw()


func hear_player() -> void:
	hear_position(_maze.world_to_cell(_player.position))


func hear_position(source_cell: Vector2i) -> void:
	if dead or not _active or _hearing_cooldown > 0.0:
		return

	_last_known_player_cell = source_cell
	if _build_path_to(_last_known_player_cell):
		state = State.INVESTIGATE
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


func show_damage_number(amount: int, direction: Vector2) -> void:
	_game.spawn_damage_number(position, amount, direction)


func _apply_dead_state() -> void:
	z_index = DEAD_Z_INDEX
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
	_flank_repath_cooldown = maxf(0.0, _flank_repath_cooldown - delta)
	_update_facing(delta)

	var player_cell := _maze.world_to_cell(_player.position)
	var distance_to_player := Vector2(
		player_cell - _maze.world_to_cell(position)
	).length()
	var direction_to_player := position.direction_to(_player.position)
	var sees_player := distance_to_player <= VISION_RANGE \
			and _facing.dot(direction_to_player) > 0.0 \
			and _maze.has_line_of_sight(position, _player.position, VISION_RANGE)

	if state == State.MANEUVER:
		if sees_player:
			_last_known_player_cell = player_cell
			_desired_facing = direction_to_player
			_update_maneuver(true)
		else:
			_update_maneuver(false)
		return

	if sees_player:
		_last_known_player_cell = player_cell
		if state != State.COMBAT:
			_enter_combat()
		_desired_facing = direction_to_player
		if _try_start_coordinated_flank(player_cell):
			return
		if _shoot_cooldown <= 0.0 and _is_aimed_at(direction_to_player):
			_game.spawn_enemy_bullet(position, _facing, self)
			_shoot_cooldown = SHOOT_INTERVAL
			_try_start_combat_maneuver(direction_to_player)
		return

	if state == State.COMBAT:
		_enter_search()

	if _player.is_audible() \
			and distance_to_player <= STEP_HEARING_RANGE \
			and _hearing_cooldown <= 0.0:
		hear_player()

	match state:
		State.PATROL:
			_update_patrol()
		State.INVESTIGATE:
			_update_investigate()
		State.SEARCH:
			_update_search(delta)
		State.COMBAT:
			velocity = Vector2.ZERO
		State.MANEUVER:
			velocity = Vector2.ZERO


func _enter_patrol() -> void:
	state = State.PATROL
	_search_time_left = 0.0
	_last_known_player_cell = Vector2i(-1, -1)
	_path.clear()
	_path_index = 0
	_choose_random_target()


func _enter_combat() -> void:
	state = State.COMBAT
	velocity = Vector2.ZERO
	_path.clear()
	_path_index = 0


func _enter_search() -> void:
	state = State.SEARCH
	_search_time_left = SEARCH_DURATION
	if not _build_path_to(_last_known_player_cell):
		_path.clear()
		_path_index = 0


func _try_start_combat_maneuver(direction_to_player: Vector2) -> bool:
	if _rng.randf() >= MANEUVER_CHANCE:
		return false

	var forward := _cardinal_direction(direction_to_player)
	if forward == Vector2i.ZERO:
		return false
	var left := Vector2i(forward.y, -forward.x)
	var right := -left
	var current_cell := _maze.world_to_cell(position)
	var side_directions: Array[Vector2i] = [left, right]
	if _rng.randi_range(0, 1) == 1:
		side_directions.reverse()

	var maneuver_directions: Array[Vector2i] = side_directions
	maneuver_directions.append(-forward)
	maneuver_directions.append(forward)
	for direction in maneuver_directions:
		var maneuver_path: Array[Vector2i] = []
		for step in range(1, MANEUVER_DISTANCE + 1):
			var target := current_cell + direction * step
			if not _maze.is_cell_walkable(target):
				break
			maneuver_path.append(target)
		if maneuver_path.is_empty():
			continue

		state = State.MANEUVER
		_path = maneuver_path
		_path_index = 0
		return true
	return false


func _try_start_coordinated_flank(player_cell: Vector2i) -> bool:
	if _flank_repath_cooldown > 0.0:
		return false

	_flank_repath_cooldown = FLANK_REPATH_INTERVAL
	var attackers: Array[Enemy] = _game.attackers_near_player(
		_player.position,
		FLANK_GROUP_RANGE
	)
	if attackers.size() < 2:
		return false

	attackers.sort_custom(func(left: Enemy, right: Enemy) -> bool:
		return left.enemy_id < right.enemy_id
	)
	var attacker_index := attackers.find(self)
	if attacker_index < 0:
		return false

	var flank_path := _find_flank_path(
		player_cell,
		attacker_index,
		attackers.size()
	)
	if flank_path.is_empty():
		return false

	_path = flank_path
	state = State.MANEUVER
	_path_index = 0
	return true


func _find_flank_path(
	player_cell: Vector2i,
	attacker_index: int,
	attacker_count: int
) -> Array[Vector2i]:
	var current_cell := _maze.world_to_cell(position)
	var best_path: Array[Vector2i] = []
	for target in _flank_candidates(player_cell, attacker_index, attacker_count):
		if current_cell.distance_to(target) <= 1.0:
			continue

		var path := _maze.find_path(current_cell, target)
		if path.is_empty() or _path_crosses_flank_danger(path, player_cell):
			continue
		if best_path.is_empty() or path.size() < best_path.size():
			best_path = path
	return best_path


func _find_flank_cell(
	player_cell: Vector2i,
	attacker_index: int,
	attacker_count: int
) -> Vector2i:
	var candidates := _flank_candidates(
		player_cell,
		attacker_index,
		attacker_count
	)
	return candidates[0] if not candidates.is_empty() else Vector2i(-1, -1)


func _flank_candidates(
	player_cell: Vector2i,
	attacker_index: int,
	attacker_count: int
) -> Array[Vector2i]:
	var angle := TAU * float(attacker_index) / float(attacker_count)
	var direction := Vector2.from_angle(angle)
	var base_offset := Vector2i(
		roundi(direction.x * FLANK_DISTANCE),
		roundi(direction.y * FLANK_DISTANCE)
	)
	if base_offset == Vector2i.ZERO:
		return []

	var base_cell := player_cell + base_offset
	var candidates: Array[Vector2i] = []
	if _flank_candidate_is_valid(base_cell, player_cell):
		candidates.append(base_cell)

	for radius in range(1, FLANK_TARGET_SEARCH_RADIUS + 1):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				if absi(x) != radius and absi(y) != radius:
					continue
				var candidate := base_cell + Vector2i(x, y)
				if _flank_candidate_is_valid(candidate, player_cell):
					candidates.append(candidate)
	return candidates


func _flank_candidate_is_valid(
	cell: Vector2i,
	player_cell: Vector2i
) -> bool:
	return _maze.is_cell_walkable(cell) \
			and cell.distance_to(player_cell) > FLANK_DANGER_RADIUS


func _path_crosses_flank_danger(
	path: Array[Vector2i],
	player_cell: Vector2i
) -> bool:
	for cell in path:
		if cell.distance_to(player_cell) <= FLANK_DANGER_RADIUS:
			return true
	return false


func _cardinal_direction(direction: Vector2) -> Vector2i:
	if absf(direction.x) >= absf(direction.y):
		return Vector2i(int(signf(direction.x)), 0)
	return Vector2i(0, int(signf(direction.y)))


func _update_facing(delta: float) -> void:
	if _desired_facing.is_zero_approx():
		return

	var current_angle := _facing.angle()
	var target_angle := _desired_facing.angle()
	var new_angle := rotate_toward(
		current_angle,
		target_angle,
		TURN_SPEED * delta
	)
	var new_facing := Vector2.from_angle(new_angle)
	if not new_facing.is_equal_approx(_facing):
		_facing = new_facing
		queue_redraw()


func _is_aimed_at(direction: Vector2) -> bool:
	return absf(_facing.angle_to(direction)) <= AIM_TOLERANCE


func _update_patrol() -> void:
	if _path.is_empty() or _path_index >= _path.size():
		_choose_random_target()
	_follow_path()


func _update_investigate() -> void:
	if _path.is_empty() or _path_index >= _path.size():
		_enter_search()
		return
	_follow_path()
	if _path_index >= _path.size():
		_enter_search()


func _update_search(delta: float) -> void:
	if _path_index < _path.size():
		_follow_path()
		return

	velocity = Vector2.ZERO
	_search_time_left = maxf(0.0, _search_time_left - delta)
	if _search_time_left <= 0.0:
		_enter_patrol()


func _update_maneuver(sees_player: bool) -> void:
	if _path_index < _path.size():
		_follow_path(false)
	if _path_index < _path.size():
		return

	if sees_player:
		_enter_combat()
	else:
		_enter_search()


func _follow_path(update_facing: bool = true) -> void:
	if _path_index >= _path.size():
		velocity = Vector2.ZERO
		return

	if not _maze.is_cell_walkable(_path[_path_index]):
		_path.clear()
		_path_index = 0
		velocity = Vector2.ZERO
		return

	var target_position := _maze.cell_to_world(_path[_path_index])
	var offset := target_position - position
	if offset.length() < 5.0:
		_path_index += 1
		_follow_path(update_facing)
		return

	var movement_direction := offset.normalized()
	if update_facing:
		_desired_facing = movement_direction
	var movement_speed := (
		PATROL_SPEED if state == State.PATROL else ALERT_SPEED
	)
	velocity = movement_direction * movement_speed
	move_and_slide()
	queue_redraw()


func _choose_random_target() -> void:
	for attempt in TARGET_ATTEMPTS:
		var target := _maze.get_random_walkable_cell(_rng, true)
		if target.x < 0:
			return
		if _build_path_to(target):
			return
	_path.clear()


func _build_path_to(target: Vector2i) -> bool:
	var start := _maze.world_to_cell(position)
	_path = _maze.find_path(start, target)
	_path_index = 0
	return not _path.is_empty()


func _draw() -> void:
	if uses_ambush_marker():
		_draw_ambush_arrow()
		return

	var body_color := (
		DEAD_COLOR
		if dead
		else BODY_COLOR
	)
	var edge_color := (
		DEAD_EDGE_COLOR
		if dead
		else EDGE_COLOR
	)
	draw_circle(Vector2.ZERO, 14.0, body_color)
	draw_circle(Vector2.ZERO, 14.0, edge_color, false, 2.0, true)
	if not dead:
		draw_line(Vector2.ZERO, _facing * 11.0, edge_color, 3.0, true)


func _draw_ambush_arrow() -> void:
	var color := (
		AMBUSH_PATROL_COLOR
		if state == State.PATROL
		else AMBUSH_ALERT_COLOR
	)
	var tail := -_facing * AMBUSH_ARROW_LENGTH * 0.35
	var tip := _facing * AMBUSH_ARROW_LENGTH * 0.65
	draw_line(tail, tip, color, 3.0, true)
	var back := -_facing
	draw_line(
		tip,
		tip + back.rotated(AMBUSH_ARROW_HEAD_ANGLE)
				* AMBUSH_ARROW_HEAD_LENGTH,
		color,
		3.0,
		true
	)
	draw_line(
		tip,
		tip + back.rotated(-AMBUSH_ARROW_HEAD_ANGLE)
				* AMBUSH_ARROW_HEAD_LENGTH,
		color,
		3.0,
		true
	)
