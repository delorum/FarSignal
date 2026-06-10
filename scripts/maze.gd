extends StaticBody2D
class_name Maze

const COLUMNS := 500
const ROWS := 1000
const LOGICAL_COLUMNS := 166
const LOGICAL_ROWS := 333
const LAYOUT_COLUMNS := LOGICAL_COLUMNS * 2 + 1
const LAYOUT_ROWS := LOGICAL_ROWS * 2 + 1
const CELL_SIZE := 48.0
const COLLISION_RADIUS := 6
const COLLISION_DIAMETER := COLLISION_RADIUS * 2 + 1
const FLOOR_CELL_SEARCH_ATTEMPTS := 256
const DRAW_RADIUS := 16
const FLOOR_COLOR := Color("101b2d")
const FLOOR_EDGE_COLOR := Color("172943")
const WALL_COLOR := Color("29415f")
const WALL_EDGE_COLOR := Color("3f6688")
const EXPLORED_WALL_COLOR := Color("14171b")
const EXPLORED_WALL_EDGE_COLOR := Color("20242a")
const LOOP_DENSITY := 0.16
const NARROW_CORRIDOR_RATIO := 0.35
const DOOR_RATIO := 0.003
const LEVEL_COUNT := 10
const LEVEL_HEIGHT := 100
const STATION_ROOM_RADIUS := 3
const STATION_FLOOR_RADIUS := 2
const STATION_PLACEMENT_ATTEMPTS := 128
const PATH_DIRECTIONS: Array[Vector2i] = [
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.UP,
]
const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.UP,
]
const DIAGONAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 1),
	Vector2i(-1, 1),
	Vector2i(-1, -1),
	Vector2i(1, -1),
]

var _cells: Array[PackedByteArray] = []
var _visible_cells: Dictionary = {}
var _explored_cells: Dictionary = {}
var _view_cell := Vector2i(-1, -1)
var _view_position := Vector2(-1.0, -1.0)
var _view_direction := Vector2.ZERO
var _collision_shapes: Array[CollisionShape2D] = []
var _generation_seed := 0
var generation_seed_override := -1
var _door_specs: Array[Dictionary] = []
var _station_specs: Array[Dictionary] = []
var _closed_door_cells: Dictionary = {}


func _ready() -> void:
	_generate()
	_create_collision_pool()
	queue_redraw()


func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell) * CELL_SIZE + Vector2.ONE * CELL_SIZE * 0.5


func world_to_cell(world_position: Vector2) -> Vector2i:
	return Vector2i(
		floori(world_position.x / CELL_SIZE),
		floori(world_position.y / CELL_SIZE)
	)


func world_size() -> Vector2:
	return Vector2(COLUMNS, ROWS) * CELL_SIZE


func grid_size() -> Vector2i:
	return Vector2i(COLUMNS, ROWS)


func is_wall(cell: Vector2i) -> bool:
	return _is_inside(cell) and _is_wall(cell)


func is_cell_explored(cell: Vector2i) -> bool:
	return _explored_cells.has(cell)


func generation_seed() -> int:
	return _generation_seed


func generated_door_specs() -> Array[Dictionary]:
	return _door_specs.duplicate(true)


func generated_station_specs() -> Array[Dictionary]:
	return _station_specs.duplicate(true)


func station_cell_for_level(level: int) -> Vector2i:
	if level < 0 or level >= _station_specs.size():
		return Vector2i(-1, -1)
	return _station_specs[level].cell


func level_for_cell(cell: Vector2i) -> int:
	return clampi(cell.y / LEVEL_HEIGHT, 0, LEVEL_COUNT - 1)


func is_station_room_cell(cell: Vector2i) -> bool:
	return _is_inside_station(cell)


func is_cell_walkable(cell: Vector2i, avoid_station: bool = false) -> bool:
	if not _is_inside(cell) or _is_wall(cell) or _closed_door_cells.has(cell):
		return false
	return not avoid_station or not _is_inside_station(cell)


func get_random_floor_cell_in_level(
	rng: RandomNumberGenerator,
	level: int,
	avoid_station: bool = false
) -> Vector2i:
	var min_y := clampi(level, 0, LEVEL_COUNT - 1) * LEVEL_HEIGHT
	var max_y := mini(ROWS - 1, min_y + LEVEL_HEIGHT - 1)
	for attempt in FLOOR_CELL_SEARCH_ATTEMPTS:
		var cell := Vector2i(
			rng.randi_range(1, COLUMNS - 2),
			rng.randi_range(maxi(1, min_y), mini(ROWS - 2, max_y))
		)
		if is_cell_walkable(cell, avoid_station):
			return cell

	for y in range(maxi(1, min_y), mini(ROWS - 1, max_y + 1)):
		for x in range(1, COLUMNS - 1):
			var cell := Vector2i(x, y)
			if is_cell_walkable(cell, avoid_station):
				return cell
	return Vector2i(-1, -1)


func find_path(
	start: Vector2i,
	target: Vector2i,
	level: int,
	avoid_station: bool = false
) -> Array[Vector2i]:
	if level_for_cell(start) != level or level_for_cell(target) != level \
			or not is_cell_walkable(start, false) \
			or not is_cell_walkable(target, avoid_station):
		return []

	var frontier: Array[Vector2i] = [start]
	var frontier_index := 0
	var came_from: Dictionary = {start: start}
	while frontier_index < frontier.size():
		var current := frontier[frontier_index]
		frontier_index += 1
		if current == target:
			break

		for direction in PATH_DIRECTIONS:
			var next := current + direction
			if came_from.has(next) or level_for_cell(next) != level \
					or not is_cell_walkable(next, avoid_station):
				continue
			came_from[next] = current
			frontier.append(next)

	if not came_from.has(target):
		return []

	var path: Array[Vector2i] = []
	var current := target
	while current != start:
		path.push_front(current)
		current = came_from[current]
	return path


func has_line_of_sight(
	from_position: Vector2,
	to_position: Vector2,
	max_distance_cells: float = INF
) -> bool:
	var from_cell := world_to_cell(from_position)
	var to_cell := world_to_cell(to_position)
	if Vector2(to_cell - from_cell).length() > max_distance_cells:
		return false

	var difference := to_cell - from_cell
	var steps := maxi(absi(difference.x), absi(difference.y))
	if steps == 0:
		return true

	for index in range(1, steps):
		var progress := float(index) / float(steps)
		var cell := Vector2i(Vector2(from_cell).lerp(Vector2(to_cell), progress).round())
		if _is_wall(cell) or _closed_door_cells.has(cell):
			return false
	return true


func set_door_closed(cell: Vector2i, closed: bool) -> void:
	if closed:
		_closed_door_cells[cell] = true
	else:
		_closed_door_cells.erase(cell)
	_view_position = Vector2(-1.0, -1.0)
	queue_redraw()


func carve_floor_cell(cell: Vector2i) -> void:
	if not _is_inside(cell):
		return

	_cells[cell.y][cell.x] = 0
	if cell.distance_squared_to(_view_cell) \
			<= COLLISION_RADIUS * COLLISION_RADIUS:
		_update_nearby_collisions(_view_cell)
	queue_redraw()


func explored_cells_for_save() -> Array:
	var cells: Array = []
	for explored_cell in _explored_cells:
		var cell: Vector2i = explored_cell
		cells.append([cell.x, cell.y])
	return cells


func restore_explored_cells(saved_cells: Array) -> void:
	_explored_cells.clear()
	for saved_cell in saved_cells:
		if not saved_cell is Array or saved_cell.size() != 2:
			continue

		var cell := Vector2i(int(saved_cell[0]), int(saved_cell[1]))
		if _is_inside(cell):
			_explored_cells[cell] = true
	queue_redraw()


func get_random_floor_cell(rng: RandomNumberGenerator) -> Vector2i:
	for attempt in FLOOR_CELL_SEARCH_ATTEMPTS:
		var cell := Vector2i(
			rng.randi_range(1, COLUMNS - 2),
			rng.randi_range(1, ROWS - 2)
		)
		if not _is_wall(cell):
			return cell

	for y in ROWS:
		for x in COLUMNS:
			var cell := Vector2i(x, y)
			if not _is_wall(cell):
				return cell

	push_error("Generated maze contains no floor cells")
	return Vector2i.ZERO


func get_random_bottom_floor_cell(
	rng: RandomNumberGenerator
) -> Vector2i:
	for y in range(ROWS - 2, 0, -1):
		var floor_cells: Array[Vector2i] = []
		for x in range(1, COLUMNS - 1):
			var cell := Vector2i(x, y)
			if not _is_wall(cell):
				floor_cells.append(cell)

		if not floor_cells.is_empty():
			return floor_cells[rng.randi_range(0, floor_cells.size() - 1)]

	push_error("Generated maze contains no floor cells")
	return Vector2i.ZERO


func update_visibility(
	viewer_position: Vector2,
	viewer_direction: Vector2
) -> void:
	var viewer_cell := world_to_cell(viewer_position)
	if not _is_inside(viewer_cell) or viewer_direction.is_zero_approx():
		return

	if viewer_cell != _view_cell:
		_view_cell = viewer_cell
		_update_nearby_collisions(viewer_cell)

	var normalized_direction := viewer_direction.normalized()
	if viewer_position.is_equal_approx(_view_position) \
			and normalized_direction.is_equal_approx(_view_direction):
		return

	_view_position = viewer_position
	_view_direction = normalized_direction
	_visible_cells.clear()
	_reveal_floor_with_walls(viewer_cell)
	_reveal_diagonal_walls(viewer_cell)

	for direction in CARDINAL_DIRECTIONS:
		_reveal_corridor_in_direction(viewer_cell, direction)

	_filter_cells_outside_view(viewer_position, normalized_direction, viewer_cell)
	_reveal_distant_corner_walls(viewer_position, normalized_direction)

	for cell in _visible_cells:
		_explored_cells[cell] = true

	queue_redraw()


func is_cell_visible(cell: Vector2i) -> bool:
	return _visible_cells.has(cell)


func _generate() -> void:
	_door_specs.clear()
	_station_specs.clear()
	var rng := RandomNumberGenerator.new()
	if generation_seed_override >= 0:
		_generation_seed = generation_seed_override
	else:
		rng.randomize()
		_generation_seed = rng.randi()
	rng.seed = _generation_seed
	var layout := _create_wall_grid(LAYOUT_COLUMNS, LAYOUT_ROWS)
	var stack: Array[Vector2i] = [Vector2i(1, 1)]
	layout[1][1] = 0

	while not stack.is_empty():
		var current: Vector2i = stack.back()
		var candidates: Array[Vector2i] = []

		for direction in CARDINAL_DIRECTIONS:
			var next: Vector2i = current + direction * 2
			if next.x > 0 and next.x < LAYOUT_COLUMNS - 1 \
					and next.y > 0 and next.y < LAYOUT_ROWS - 1 \
					and layout[next.y][next.x] == 1:
				candidates.append(next)

		if candidates.is_empty():
			stack.pop_back()
			continue

		var next: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]
		var between: Vector2i = (current + next) / 2
		layout[between.y][between.x] = 0
		layout[next.y][next.x] = 0
		stack.append(next)

	_add_loops(layout, rng)
	_rasterize_layout(layout, rng)


func _create_wall_grid(columns: int, rows: int) -> Array[PackedByteArray]:
	var grid: Array[PackedByteArray] = []
	for y in rows:
		var row := PackedByteArray()
		row.resize(columns)
		row.fill(1)
		grid.append(row)
	return grid


func _add_loops(
	layout: Array[PackedByteArray],
	rng: RandomNumberGenerator
) -> void:
	var candidates: Array[Vector2i] = []
	for y in range(1, LAYOUT_ROWS - 1):
		for x in range(1, LAYOUT_COLUMNS - 1):
			var cell := Vector2i(x, y)
			if layout[y][x] == 1 and _connects_existing_passages(layout, cell):
				candidates.append(cell)

	var loop_count := maxi(1, roundi(candidates.size() * LOOP_DENSITY))
	for index in mini(loop_count, candidates.size()):
		var candidate_index := rng.randi_range(index, candidates.size() - 1)
		var candidate := candidates[candidate_index]
		candidates[candidate_index] = candidates[index]
		candidates[index] = candidate
		layout[candidate.y][candidate.x] = 0


func _connects_existing_passages(
	layout: Array[PackedByteArray],
	cell: Vector2i
) -> bool:
	if cell.x % 2 == 0 and cell.y % 2 == 1:
		return layout[cell.y][cell.x - 1] == 0 \
				and layout[cell.y][cell.x + 1] == 0

	if cell.x % 2 == 1 and cell.y % 2 == 0:
		return layout[cell.y - 1][cell.x] == 0 \
				and layout[cell.y + 1][cell.x] == 0

	return false


func _rasterize_layout(
	layout: Array[PackedByteArray],
	rng: RandomNumberGenerator
) -> void:
	_cells = _create_wall_grid(COLUMNS, ROWS)

	for logical_y in LOGICAL_ROWS:
		for logical_x in LOGICAL_COLUMNS:
			var room_origin := Vector2i(
				logical_x * 3 + 1,
				logical_y * 3 + 1
			)
			_carve_room(room_origin)

	var connectors: Array[Vector2i] = []
	for y in range(1, LAYOUT_ROWS - 1):
		for x in range(1, LAYOUT_COLUMNS - 1):
			if layout[y][x] == 1:
				continue

			var connector := Vector2i(x, y)
			if x % 2 != y % 2:
				connectors.append(connector)

	var narrow_connectors: Dictionary = {}
	var narrow_count := roundi(connectors.size() * NARROW_CORRIDOR_RATIO)
	for index in narrow_count:
		var candidate_index := rng.randi_range(index, connectors.size() - 1)
		var candidate := connectors[candidate_index]
		connectors[candidate_index] = connectors[index]
		connectors[index] = candidate
		narrow_connectors[candidate] = true

	for connector in connectors:
		_carve_connector(
			connector,
			connector.x % 2 == 0,
			narrow_connectors.has(connector),
			rng
		)

	_add_stations(rng)

	var door_candidates: Array[Dictionary] = []
	for connector in connectors:
		if not narrow_connectors.has(connector):
			continue

		var horizontal := connector.x % 2 == 0
		var cell := _connector_floor_cell(connector, horizontal)
		if _is_inside_station(cell):
			continue
		door_candidates.append({
			"cell": cell,
			"horizontal_passage": horizontal,
		})

	var door_count := roundi(door_candidates.size() * DOOR_RATIO)
	for index in mini(door_count, door_candidates.size()):
		var candidate_index := rng.randi_range(
			index,
			door_candidates.size() - 1
		)
		var candidate := door_candidates[candidate_index]
		door_candidates[candidate_index] = door_candidates[index]
		door_candidates[index] = candidate
		_door_specs.append(candidate)

	for station_spec in _station_specs:
		for door_spec in station_spec.doors:
			_door_specs.append(door_spec)


func _add_stations(rng: RandomNumberGenerator) -> void:
	for level in LEVEL_COUNT:
		var level_start := level * LEVEL_HEIGHT
		var center := _find_station_center(level_start, rng)
		_carve_station(center)

		var doors: Array[Dictionary] = []
		for direction in CARDINAL_DIRECTIONS:
			var door_cell := center + direction * STATION_ROOM_RADIUS
			doors.append({
				"cell": door_cell,
				"horizontal_passage": direction.x != 0,
				"station_door": true,
			})
			_connect_station_door(door_cell, direction)

		_station_specs.append({
			"cell": center,
			"level": level,
			"doors": doors,
		})


func _find_station_center(
	level_start: int,
	rng: RandomNumberGenerator
) -> Vector2i:
	var min_y := level_start + STATION_ROOM_RADIUS + 2
	var max_y := mini(
		ROWS - STATION_ROOM_RADIUS - 2,
		level_start + LEVEL_HEIGHT - STATION_ROOM_RADIUS - 3
	)
	var fallback := Vector2i(
		rng.randi_range(STATION_ROOM_RADIUS + 2, COLUMNS - STATION_ROOM_RADIUS - 3),
		rng.randi_range(min_y, max_y)
	)

	for attempt in STATION_PLACEMENT_ATTEMPTS:
		var candidate := Vector2i(
			rng.randi_range(
				STATION_ROOM_RADIUS + 2,
				COLUMNS - STATION_ROOM_RADIUS - 3
			),
			rng.randi_range(min_y, max_y)
		)
		if not _is_wall(candidate):
			return candidate

	return fallback


func _carve_station(center: Vector2i) -> void:
	for offset_y in range(-STATION_ROOM_RADIUS, STATION_ROOM_RADIUS + 1):
		for offset_x in range(-STATION_ROOM_RADIUS, STATION_ROOM_RADIUS + 1):
			var cell := center + Vector2i(offset_x, offset_y)
			var is_floor := absi(offset_x) <= STATION_FLOOR_RADIUS \
					and absi(offset_y) <= STATION_FLOOR_RADIUS
			_cells[cell.y][cell.x] = 0 if is_floor else 1

	for direction in CARDINAL_DIRECTIONS:
		var door_cell := center + direction * STATION_ROOM_RADIUS
		_cells[door_cell.y][door_cell.x] = 0


func _connect_station_door(
	door_cell: Vector2i,
	direction: Vector2i
) -> void:
	var cell := door_cell + direction
	while _is_inside(cell):
		if not _is_wall(cell):
			return
		_cells[cell.y][cell.x] = 0
		cell += direction


func _is_inside_station(cell: Vector2i) -> bool:
	for station_spec in _station_specs:
		var center: Vector2i = station_spec.cell
		if absi(cell.x - center.x) <= STATION_ROOM_RADIUS \
				and absi(cell.y - center.y) <= STATION_ROOM_RADIUS:
			return true
	return false


func _carve_room(origin: Vector2i) -> void:
	for offset_y in 2:
		for offset_x in 2:
			_cells[origin.y + offset_y][origin.x + offset_x] = 0


func _carve_connector(
	layout_cell: Vector2i,
	horizontal: bool,
	narrow: bool,
	rng: RandomNumberGenerator
) -> void:
	var open_lane := rng.randi_range(0, 1)

	if horizontal:
		var wall_x := (layout_cell.x / 2) * 3
		var top_y := ((layout_cell.y - 1) / 2) * 3 + 1
		for lane in 2:
			if not narrow or lane == open_lane:
				_cells[top_y + lane][wall_x] = 0
	else:
		var wall_y := (layout_cell.y / 2) * 3
		var left_x := ((layout_cell.x - 1) / 2) * 3 + 1
		for lane in 2:
			if not narrow or lane == open_lane:
				_cells[wall_y][left_x + lane] = 0


func _connector_floor_cell(
	layout_cell: Vector2i,
	horizontal: bool
) -> Vector2i:
	if horizontal:
		var wall_x := (layout_cell.x / 2) * 3
		var top_y := ((layout_cell.y - 1) / 2) * 3 + 1
		for lane in 2:
			var cell := Vector2i(wall_x, top_y + lane)
			if not _is_wall(cell):
				return cell
	else:
		var wall_y := (layout_cell.y / 2) * 3
		var left_x := ((layout_cell.x - 1) / 2) * 3 + 1
		for lane in 2:
			var cell := Vector2i(left_x + lane, wall_y)
			if not _is_wall(cell):
				return cell

	return Vector2i.ZERO


func _create_collision_pool() -> void:
	for index in COLLISION_DIAMETER * COLLISION_DIAMETER:
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2.ONE * CELL_SIZE
		collision.shape = shape
		collision.disabled = true
		add_child(collision)
		_collision_shapes.append(collision)


func _update_nearby_collisions(viewer_cell: Vector2i) -> void:
	var shape_index := 0
	for y in range(
		viewer_cell.y - COLLISION_RADIUS,
		viewer_cell.y + COLLISION_RADIUS + 1
	):
		for x in range(
			viewer_cell.x - COLLISION_RADIUS,
			viewer_cell.x + COLLISION_RADIUS + 1
		):
			var collision := _collision_shapes[shape_index]
			var cell := Vector2i(x, y)
			var enabled := _is_inside(cell) and _is_wall(cell)
			if enabled:
				collision.position = cell_to_world(cell)
			collision.set_deferred("disabled", not enabled)
			shape_index += 1


func _reveal_floor_with_walls(cell: Vector2i) -> void:
	if not _is_inside(cell) or _is_wall(cell):
		return

	_visible_cells[cell] = true
	for direction in CARDINAL_DIRECTIONS:
		var neighbor: Vector2i = cell + direction
		if _is_inside(neighbor) and _is_wall(neighbor):
			_visible_cells[neighbor] = true


func _reveal_corridor_in_direction(
	viewer_cell: Vector2i,
	direction: Vector2i
) -> void:
	var perpendicular := Vector2i(-direction.y, direction.x)
	var ray_origins: Array[Vector2i] = [viewer_cell]

	for side in [-1, 1]:
		var adjacent: Vector2i = viewer_cell + perpendicular * int(side)
		if _is_inside(adjacent) and not _is_wall(adjacent):
			ray_origins.append(adjacent)

	for origin in ray_origins:
		_reveal_floor_with_walls(origin)
		var cell := origin + direction
		while _is_inside(cell) and not _is_wall(cell):
			_reveal_floor_with_walls(cell)
			if _closed_door_cells.has(cell):
				break
			cell += direction


func _reveal_diagonal_walls(cell: Vector2i) -> void:
	for direction in DIAGONAL_DIRECTIONS:
		var neighbor := cell + direction
		if _is_inside(neighbor) and _is_wall(neighbor):
			_visible_cells[neighbor] = true


func _reveal_distant_corner_walls(
	viewer_position: Vector2,
	viewer_direction: Vector2
) -> void:
	var corner_walls: Dictionary = {}
	for visible_cell in _visible_cells:
		var cell: Vector2i = visible_cell
		if _is_wall(cell):
			continue

		for diagonal_direction in DIAGONAL_DIRECTIONS:
			var candidate := cell + diagonal_direction
			if not _is_inside(candidate) or not _is_wall(candidate) \
					or _visible_cells.has(candidate):
				continue

			var direction_to_candidate := (
				cell_to_world(candidate) - viewer_position
			)
			if viewer_direction.dot(direction_to_candidate) <= 0.0:
				continue

			var horizontal_wall := cell + Vector2i(diagonal_direction.x, 0)
			var vertical_wall := cell + Vector2i(0, diagonal_direction.y)
			if _visible_cells.has(horizontal_wall) \
					and _is_wall(horizontal_wall) \
					and _visible_cells.has(vertical_wall) \
					and _is_wall(vertical_wall):
				corner_walls[candidate] = true

	for wall in corner_walls:
		_visible_cells[wall] = true


func _filter_cells_outside_view(
	viewer_position: Vector2,
	viewer_direction: Vector2,
	viewer_cell: Vector2i
) -> void:
	var cells_outside_view: Array[Vector2i] = []
	for visible_cell in _visible_cells:
		var cell: Vector2i = visible_cell
		if cell == viewer_cell:
			continue

		var direction_to_cell := cell_to_world(cell) - viewer_position
		if viewer_direction.dot(direction_to_cell) <= 0.0:
			cells_outside_view.append(cell)

	for cell in cells_outside_view:
		_visible_cells.erase(cell)


func _is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < COLUMNS and cell.y >= 0 and cell.y < ROWS


func _is_wall(cell: Vector2i) -> bool:
	return _cells[cell.y][cell.x] == 1


func _draw() -> void:
	for y in range(
		maxi(0, _view_cell.y - DRAW_RADIUS),
		mini(ROWS, _view_cell.y + DRAW_RADIUS + 1)
	):
		for x in range(
			maxi(0, _view_cell.x - DRAW_RADIUS),
			mini(COLUMNS, _view_cell.x + DRAW_RADIUS + 1)
		):
			var cell := Vector2i(x, y)
			if not _explored_cells.has(cell) or _visible_cells.has(cell):
				continue
			if not _is_wall(cell):
				continue

			var rect := Rect2(
				Vector2(cell) * CELL_SIZE,
				Vector2.ONE * CELL_SIZE
			)
			draw_rect(rect, EXPLORED_WALL_COLOR)
			draw_rect(
				rect.grow(-2.0),
				EXPLORED_WALL_EDGE_COLOR,
				false,
				1.0
			)

	for visible_cell in _visible_cells:
		var cell: Vector2i = visible_cell
		var rect := Rect2(Vector2(cell) * CELL_SIZE, Vector2.ONE * CELL_SIZE)
		if _is_wall(cell):
			draw_rect(rect, WALL_COLOR)
			draw_rect(rect.grow(-2.0), WALL_EDGE_COLOR, false, 2.0)
		else:
			draw_rect(rect, FLOOR_COLOR)
			draw_rect(rect.grow(-2.0), FLOOR_EDGE_COLOR, false, 1.0)
