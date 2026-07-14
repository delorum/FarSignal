extends StaticBody2D
class_name Maze

const ENVIRONMENT_ATLAS := preload(
	"res://assets/tiles/environment/environment_tileset_48.png"
)
const COLUMNS := 199
const ROWS := 199
const LOGICAL_COLUMNS := int((COLUMNS - 1) / 3.0)
const LOGICAL_ROWS := int((ROWS - 1) / 3.0)
const LAYOUT_COLUMNS := LOGICAL_COLUMNS * 2 + 1
const LAYOUT_ROWS := LOGICAL_ROWS * 2 + 1
const CELL_SIZE := 48.0
const COLLISION_RADIUS := 6
const COLLISION_DIAMETER := COLLISION_RADIUS * 2 + 1
const FLOOR_CELL_SEARCH_ATTEMPTS := 256
const DRAW_RADIUS := 16
const ENEMY_LEVEL_COUNT := 5
const LEVEL_BOUNDARY_COLOR := Color(1.0, 1.0, 1.0, 0.35)
const LEVEL_BOUNDARY_WIDTH := 2.0
const FLOOR_TILE_COUNT := 8
const WALL_TILE_OFFSET := 8
const WALL_TILE_COUNT := 8
const EXPLORED_WALL_TILE_MODULATE := Color(0.3, 0.32, 0.36, 1.0)
const SAFE_FLOOR_TILE_MODULATE := Color(0.58, 1.0, 0.7, 1.0)
const LOOP_DENSITY := 0.16
const NARROW_CORRIDOR_RATIO := 0.35
const ROOM_MIN_SIZE := 4
const ROOM_MAX_SIZE := 7
const ROOM_PADDING := 5
const ROOM_PLACEMENT_ATTEMPTS := 4096
const MIN_ROOM_COUNT_RATIO := 0.9
const ROOM_ENCOUNTER_SECONDS := 30.0
const ESTIMATED_PLAYER_SPEED := 230.0
const ESTIMATED_CORRIDOR_WIDTH := 2.0
const STATION_ROOM_RADIUS := 3
const STATION_FLOOR_RADIUS := 2
const PLACEMENT_SPREAD := 14
const LEFT_PLACEMENT_X := 25
const CENTER_PLACEMENT_X := int(COLUMNS / 2.0)
const RIGHT_PLACEMENT_X := COLUMNS - 26
const LEVEL_TWO_UPGRADE_STATION_Y := 140
const LEVEL_FOUR_UPGRADE_STATION_Y := 60
const MIN_GRID_SIZE := STATION_ROOM_RADIUS * 2 + 5
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
var _room_specs: Array[Dictionary] = []
var _station_specs: Array[Dictionary] = []
var _closed_door_cells: Dictionary = {}
var _safe_cell_mask := PackedByteArray()
var _planned_exit_x := int(COLUMNS / 2.0)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	assert(
		COLUMNS >= MIN_GRID_SIZE and ROWS >= MIN_GRID_SIZE,
		"Maze dimensions must be at least %dx%d cells"
		% [MIN_GRID_SIZE, MIN_GRID_SIZE]
	)
	_generate()
	_safe_cell_mask.resize(COLUMNS * ROWS)
	_safe_cell_mask.fill(0)
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


static func configured_grid_size() -> Vector2i:
	return Vector2i(COLUMNS, ROWS)


func is_wall(cell: Vector2i) -> bool:
	return _is_inside(cell) and _is_wall(cell)


func is_closed_door(cell: Vector2i) -> bool:
	return _closed_door_cells.has(cell)


func is_cell_explored(cell: Vector2i) -> bool:
	return _explored_cells.has(cell)


func is_cell_safe(cell: Vector2i) -> bool:
	return _is_inside(cell) and _safe_cell_mask[_cell_index(cell)] == 1


func explored_floor_cell_count() -> int:
	var count := 0
	for cell: Vector2i in _explored_cells:
		if not _is_wall(cell):
			count += 1
	return count


func safe_floor_cell_count() -> int:
	var count := 0
	for value in _safe_cell_mask:
		if value == 1:
			count += 1
	return count


func floor_cell_count() -> int:
	var count := 0
	for y in ROWS:
		for x in COLUMNS:
			if not _is_wall(Vector2i(x, y)):
				count += 1
	return count


func generation_seed() -> int:
	return _generation_seed


func generated_door_specs() -> Array[Dictionary]:
	return _door_specs.duplicate(true)


func generated_station_specs() -> Array[Dictionary]:
	return _station_specs.duplicate(true)


func generated_room_specs() -> Array[Dictionary]:
	return _room_specs.duplicate(true)


func station_cell() -> Vector2i:
	if _station_specs.is_empty():
		return Vector2i(-1, -1)
	return _station_specs[0].cell


func station_start_cell() -> Vector2i:
	if _station_specs.is_empty():
		return Vector2i(-1, -1)
	return _station_specs[0].start_cell


func station_start_facing() -> Vector2i:
	if _station_specs.is_empty():
		return Vector2i.UP
	return _station_specs[0].start_facing


func exit_door_cell() -> Vector2i:
	for door_spec in _door_specs:
		if bool(door_spec.get("exit_door", false)):
			return door_spec.cell
	return Vector2i(-1, -1)


func is_station_room_cell(cell: Vector2i) -> bool:
	return _is_inside_station(cell)


func is_cell_walkable(cell: Vector2i, avoid_station: bool = false) -> bool:
	if not _is_inside(cell) or _is_wall(cell) or _closed_door_cells.has(cell):
		return false
	return not avoid_station or not _is_inside_station(cell)


func get_random_walkable_cell(
	rng: RandomNumberGenerator,
	avoid_station: bool = false
) -> Vector2i:
	for attempt in FLOOR_CELL_SEARCH_ATTEMPTS:
		var cell := Vector2i(
			rng.randi_range(1, COLUMNS - 2),
			rng.randi_range(1, ROWS - 2)
		)
		if is_cell_walkable(cell, avoid_station):
			return cell

	for y in range(1, ROWS - 1):
		for x in range(1, COLUMNS - 1):
			var cell := Vector2i(x, y)
			if is_cell_walkable(cell, avoid_station):
				return cell
	return Vector2i(-1, -1)


func get_random_walkable_cell_in_y_range(
	rng: RandomNumberGenerator,
	minimum_y: int,
	maximum_y: int,
	avoid_station: bool = false
) -> Vector2i:
	var first_y := clampi(minimum_y, 1, ROWS - 2)
	var last_y := clampi(maximum_y, first_y, ROWS - 2)
	for attempt in FLOOR_CELL_SEARCH_ATTEMPTS:
		var cell := Vector2i(
			rng.randi_range(1, COLUMNS - 2),
			rng.randi_range(first_y, last_y)
		)
		if is_cell_walkable(cell, avoid_station):
			return cell

	for y in range(first_y, last_y + 1):
		for x in range(1, COLUMNS - 1):
			var cell := Vector2i(x, y)
			if is_cell_walkable(cell, avoid_station):
				return cell
	return Vector2i(-1, -1)


func find_path(
	start: Vector2i,
	target: Vector2i,
	avoid_station: bool = false,
	explored_only: bool = false,
	ignore_closed_doors: bool = false
) -> Array[Vector2i]:
	if not _is_path_cell_walkable(
			start,
			false,
			ignore_closed_doors
		) \
			or not _is_path_cell_walkable(
				target,
				avoid_station,
				ignore_closed_doors
			) \
			or explored_only and (
				not is_cell_explored(start)
				or not is_cell_explored(target)
			):
		return []

	var open_cells: Array[Vector2i] = []
	var open_priorities: Array[int] = []
	_path_heap_push(
		open_cells,
		open_priorities,
		start,
		_manhattan_distance(start, target)
	)
	var came_from: Dictionary = {start: start}
	var cost_so_far: Dictionary = {start: 0}
	var closed: Dictionary = {}

	while not open_cells.is_empty():
		var current := _path_heap_pop(open_cells, open_priorities)
		if closed.has(current):
			continue
		if current == target:
			break
		closed[current] = true

		for direction in PATH_DIRECTIONS:
			var next := current + direction
			if closed.has(next) \
					or not _is_path_cell_walkable(
						next,
						avoid_station,
						ignore_closed_doors
					) \
					or explored_only and not is_cell_explored(next):
				continue

			var new_cost: int = int(cost_so_far[current]) + 1
			if cost_so_far.has(next) and new_cost >= int(cost_so_far[next]):
				continue

			cost_so_far[next] = new_cost
			came_from[next] = current
			_path_heap_push(
				open_cells,
				open_priorities,
				next,
				new_cost + _manhattan_distance(next, target)
			)

	if not came_from.has(target):
		return []

	var path: Array[Vector2i] = []
	var current := target
	while current != start:
		path.push_front(current)
		current = came_from[current]
	return path


func _is_path_cell_walkable(
	cell: Vector2i,
	avoid_station: bool,
	ignore_closed_doors: bool
) -> bool:
	if not _is_inside(cell) or _is_wall(cell):
		return false
	if not ignore_closed_doors and _closed_door_cells.has(cell):
		return false
	return not avoid_station or not _is_inside_station(cell)


func _manhattan_distance(from: Vector2i, to: Vector2i) -> int:
	return absi(from.x - to.x) + absi(from.y - to.y)


func _path_heap_push(
	cells: Array[Vector2i],
	priorities: Array[int],
	cell: Vector2i,
	priority: int
) -> void:
	cells.append(cell)
	priorities.append(priority)
	var index := cells.size() - 1

	while index > 0:
		var parent := (index - 1) >> 1
		if priorities[parent] <= priority:
			break

		cells[index] = cells[parent]
		priorities[index] = priorities[parent]
		index = parent

	cells[index] = cell
	priorities[index] = priority


func _path_heap_pop(
	cells: Array[Vector2i],
	priorities: Array[int]
) -> Vector2i:
	var result := cells[0]
	var last_cell: Vector2i = cells.pop_back()
	var last_priority: int = priorities.pop_back()
	if cells.is_empty():
		return result

	var index := 0
	while true:
		var left := index * 2 + 1
		if left >= cells.size():
			break

		var right := left + 1
		var child := left
		if right < cells.size() and priorities[right] < priorities[left]:
			child = right
		if priorities[child] >= last_priority:
			break

		cells[index] = cells[child]
		priorities[index] = priorities[child]
		index = child

	cells[index] = last_cell
	priorities[index] = last_priority
	return result


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


func has_clear_projectile_path(
	from_position: Vector2,
	to_position: Vector2,
	projectile_half_length: float,
	projectile_half_width: float
) -> bool:
	var direction := from_position.direction_to(to_position)
	if direction.is_zero_approx():
		return true

	# Expanding blockers by the projectile's projected half-extents turns the
	# swept rectangle test into a segment-versus-rectangle test.
	var clearance := Vector2(
		absf(direction.x) * projectile_half_length
				+ absf(direction.y) * projectile_half_width,
		absf(direction.y) * projectile_half_length
				+ absf(direction.x) * projectile_half_width
	)
	var minimum := from_position.min(to_position) - clearance
	var maximum := from_position.max(to_position) + clearance
	var minimum_cell := world_to_cell(minimum)
	var maximum_cell := world_to_cell(maximum)

	for y in range(minimum_cell.y, maximum_cell.y + 1):
		for x in range(minimum_cell.x, maximum_cell.x + 1):
			var cell := Vector2i(x, y)
			if _is_inside(cell) and not _is_wall(cell) \
					and not _closed_door_cells.has(cell):
				continue

			var blocker := Rect2(
				Vector2(cell) * CELL_SIZE - clearance,
				Vector2.ONE * CELL_SIZE + clearance * 2.0
			)
			if _segment_intersects_rect(
				from_position,
				to_position,
				blocker
			):
				return false
	return true


func _segment_intersects_rect(
	segment_start: Vector2,
	segment_end: Vector2,
	rect: Rect2
) -> bool:
	var direction := segment_end - segment_start
	var minimum_t := 0.0
	var maximum_t := 1.0
	for axis in 2:
		if is_zero_approx(direction[axis]):
			if segment_start[axis] < rect.position[axis] \
					or segment_start[axis] > rect.end[axis]:
				return false
			continue

		var first_t := (
			rect.position[axis] - segment_start[axis]
		) / direction[axis]
		var second_t := (
			rect.end[axis] - segment_start[axis]
		) / direction[axis]
		if first_t > second_t:
			var temporary := first_t
			first_t = second_t
			second_t = temporary
		minimum_t = maxf(minimum_t, first_t)
		maximum_t = minf(maximum_t, second_t)
		if minimum_t > maximum_t:
			return false
	return true


func set_door_closed(cell: Vector2i, closed: bool) -> void:
	if closed:
		_closed_door_cells[cell] = true
	else:
		_closed_door_cells.erase(cell)
	_view_position = Vector2(-1.0, -1.0)
	queue_redraw()


func update_safe_zone(
	door_cells: Array[Vector2i]
) -> void:
	var cell_count := COLUMNS * ROWS
	_safe_cell_mask.resize(cell_count)
	_safe_cell_mask.fill(0)

	var door_mask := PackedByteArray()
	door_mask.resize(cell_count)
	door_mask.fill(0)
	for cell in door_cells:
		if _is_inside(cell):
			door_mask[_cell_index(cell)] = 1
	var component_ids := PackedInt32Array()
	component_ids.resize(cell_count)
	component_ids.fill(-1)
	var component_sizes: Array[int] = []
	var component_touches_station: Array[bool] = []
	var largest_component := -1
	var largest_component_size := 0

	for y in ROWS:
		for x in COLUMNS:
			var start := Vector2i(x, y)
			var start_index := _cell_index(start)
			if component_ids[start_index] >= 0 \
					or _is_wall(start) \
					or door_mask[start_index] == 1:
				continue

			var component_id := component_sizes.size()
			var component_size := 0
			var touches_station := _is_inside_primary_station(start)
			var pending := PackedInt32Array([start_index])
			component_ids[start_index] = component_id
			var pending_index := 0
			while pending_index < pending.size():
				var current_index := pending[pending_index]
				pending_index += 1
				component_size += 1
				var current_x := current_index % COLUMNS
				var current_y := current_index / COLUMNS
				if _is_inside_primary_station(Vector2i(current_x, current_y)):
					touches_station = true
				var neighbor_indices := PackedInt32Array()
				if current_x > 0:
					neighbor_indices.append(current_index - 1)
				if current_x < COLUMNS - 1:
					neighbor_indices.append(current_index + 1)
				if current_y > 0:
					neighbor_indices.append(current_index - COLUMNS)
				if current_y < ROWS - 1:
					neighbor_indices.append(current_index + COLUMNS)

				for next_index in neighbor_indices:
					if component_ids[next_index] >= 0 \
							or door_mask[next_index] == 1:
						continue
					var next_x := next_index % COLUMNS
					var next_y := next_index / COLUMNS
					if _cells[next_y][next_x] == 1:
						continue
					component_ids[next_index] = component_id
					pending.append(next_index)

			component_sizes.append(component_size)
			component_touches_station.append(touches_station)
			if component_size > largest_component_size:
				largest_component = component_id
				largest_component_size = component_size

	var safe_components: Dictionary = {}
	var component_neighbors: Dictionary = {}
	for door_cell in door_cells:
		if not _is_inside(door_cell):
			continue

		var adjacent_components: Array[int] = []
		for direction in CARDINAL_DIRECTIONS:
			var neighbor := door_cell + direction
			if not _is_inside(neighbor):
				continue
			var component_id := component_ids[_cell_index(neighbor)]
			if component_id >= 0 \
					and not adjacent_components.has(component_id):
				adjacent_components.append(component_id)

		for component_id in adjacent_components:
			if not component_neighbors.has(component_id):
				component_neighbors[component_id] = []
			for neighbor_id in adjacent_components:
				if neighbor_id != component_id \
						and not component_neighbors[component_id].has(neighbor_id):
					component_neighbors[component_id].append(neighbor_id)

	var pending_safe_components: Array[int] = []
	for component_id in component_sizes.size():
		if component_id != largest_component \
				and component_touches_station[component_id]:
			safe_components[component_id] = true
			pending_safe_components.append(component_id)

	var pending_safe_index := 0
	while pending_safe_index < pending_safe_components.size():
		var component_id := pending_safe_components[pending_safe_index]
		pending_safe_index += 1
		for neighbor_id in component_neighbors.get(component_id, []):
			if neighbor_id == largest_component \
					or safe_components.has(neighbor_id):
				continue
			safe_components[neighbor_id] = true
			pending_safe_components.append(neighbor_id)

	for index in cell_count:
		if safe_components.has(component_ids[index]):
			_safe_cell_mask[index] = 1
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


func update_visibility(
	viewer_position: Vector2,
	viewer_direction: Vector2
) -> Array[Vector2i]:
	var viewer_cell := world_to_cell(viewer_position)
	if not _is_inside(viewer_cell) or viewer_direction.is_zero_approx():
		return []

	if viewer_cell != _view_cell:
		_view_cell = viewer_cell
		_update_nearby_collisions(viewer_cell)

	var normalized_direction := viewer_direction.normalized()
	if viewer_position.is_equal_approx(_view_position) \
			and normalized_direction.is_equal_approx(_view_direction):
		return []

	_view_position = viewer_position
	_view_direction = normalized_direction
	_update_visible_cells(
		viewer_position,
		normalized_direction,
		viewer_cell
	)

	var newly_explored_floor_cells: Array[Vector2i] = []
	for visible_cell in _visible_cells:
		var cell: Vector2i = visible_cell
		if not _explored_cells.has(cell) and not _is_wall(cell):
			newly_explored_floor_cells.append(cell)
		_explored_cells[cell] = true

	queue_redraw()
	return newly_explored_floor_cells


func is_cell_visible(cell: Vector2i) -> bool:
	return _visible_cells.has(cell)


func _generate() -> void:
	_door_specs.clear()
	_room_specs.clear()
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
	_connect_disconnected_floor_pockets()
	_add_rooms(rng)
	_connect_disconnected_floor_pockets()
	_add_exit_door(rng)

	for station_spec in _station_specs:
		for door_spec in station_spec.doors:
			_door_specs.append(door_spec)


func _add_exit_door(_rng: RandomNumberGenerator) -> void:
	var first_floor_y := -1
	for y in range(1, ROWS):
		if not _is_wall(Vector2i(_planned_exit_x, y)):
			first_floor_y = y
			break
	if first_floor_y < 0:
		push_warning("Could not place exit door")
		return

	for y in range(0, first_floor_y + 1):
		_cells[y][_planned_exit_x] = 0
	_door_specs.append({
		"cell": Vector2i(_planned_exit_x, 0),
		"horizontal_passage": false,
		"exit_door": true,
		"locked": false,
	})


func _add_rooms(rng: RandomNumberGenerator) -> void:
	var target_room_count := _calculate_room_count()
	var minimum_room_count := ceili(
		target_room_count * MIN_ROOM_COUNT_RATIO
	)
	for index in target_room_count:
		var room_rect := _find_room_rect(rng)
		if room_rect.size == Vector2i.ZERO:
			break

		_carve_rect(room_rect)
		_room_specs.append({
			"origin": room_rect.position,
			"size": room_rect.size,
		})

	if _room_specs.size() < minimum_room_count:
		push_warning(
			"Placed %d maze rooms; expected at least %d of %d"
			% [
				_room_specs.size(),
				minimum_room_count,
				target_room_count,
			]
		)


func _calculate_room_count() -> int:
	var floor_cell_count := 0
	for y in range(1, ROWS - 1):
		for x in range(1, COLUMNS - 1):
			if not _is_wall(Vector2i(x, y)):
				floor_cell_count += 1

	var travel_distance_cells := (
		ESTIMATED_PLAYER_SPEED / CELL_SIZE * ROOM_ENCOUNTER_SECONDS
	)
	var explored_cells_per_room := (
		travel_distance_cells * ESTIMATED_CORRIDOR_WIDTH
	)
	return maxi(1, roundi(floor_cell_count / explored_cells_per_room))


func _find_room_rect(rng: RandomNumberGenerator) -> Rect2i:
	for attempt in ROOM_PLACEMENT_ATTEMPTS:
		var size := Vector2i(
			rng.randi_range(ROOM_MIN_SIZE, ROOM_MAX_SIZE),
			rng.randi_range(ROOM_MIN_SIZE, ROOM_MAX_SIZE)
		)
		var room_rect := Rect2i(
			Vector2i(
				rng.randi_range(1, COLUMNS - size.x - 1),
				rng.randi_range(1, ROWS - size.y - 1)
			),
			size
		)
		if _room_overlaps_existing_room(room_rect) \
				or _room_overlaps_station(room_rect) \
				or not _rect_contains_floor(room_rect):
			continue
		return room_rect
	return Rect2i()


func _room_overlaps_existing_room(room_rect: Rect2i) -> bool:
	var padded_rect := room_rect.grow(ROOM_PADDING)
	for room_spec in _room_specs:
		var existing_rect := Rect2i(room_spec.origin, room_spec.size)
		if padded_rect.intersects(existing_rect):
			return true
	return false


func _room_overlaps_station(room_rect: Rect2i) -> bool:
	var padded_room := room_rect.grow(ROOM_PADDING)
	for station_spec in _station_specs:
		var center: Vector2i = station_spec.cell
		var station_rect := Rect2i(
			center - Vector2i.ONE * STATION_ROOM_RADIUS,
			Vector2i.ONE * (STATION_ROOM_RADIUS * 2 + 1)
		)
		if padded_room.intersects(station_rect):
			return true
	return false


func _rect_contains_floor(rect: Rect2i) -> bool:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if not _is_wall(Vector2i(x, y)):
				return true
	return false


func _carve_rect(rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			_cells[y][x] = 0


func _connect_disconnected_floor_pockets() -> void:
	var components := _floor_components()
	if components.size() <= 1:
		return

	var connected_component: Array[Vector2i] = components[0]
	for index in range(1, components.size()):
		var component: Array[Vector2i] = components[index]
		var connection := _nearest_component_connection(
			connected_component,
			component
		)
		if connection.is_empty():
			continue

		_carve_l_corridor(connection[0], connection[1])
		connected_component.append_array(component)


func _floor_components() -> Array[Array]:
	var visited: Dictionary = {}
	var components: Array[Array] = []
	for y in range(1, ROWS - 1):
		for x in range(1, COLUMNS - 1):
			var start := Vector2i(x, y)
			if visited.has(start) or _is_wall(start):
				continue

			var component: Array[Vector2i] = []
			var pending: Array[Vector2i] = [start]
			visited[start] = true
			var pending_index := 0
			while pending_index < pending.size():
				var current := pending[pending_index]
				pending_index += 1
				component.append(current)
				for direction in CARDINAL_DIRECTIONS:
					var next := current + direction
					if not _is_inside(next) \
							or visited.has(next) \
							or _is_wall(next):
						continue
					visited[next] = true
					pending.append(next)
			components.append(component)

	components.sort_custom(
		func(left: Array[Vector2i], right: Array[Vector2i]) -> bool:
			return left.size() > right.size()
	)
	return components


func _nearest_component_connection(
	from_component: Array[Vector2i],
	to_component: Array[Vector2i]
) -> Array[Vector2i]:
	var from_edges := _component_edge_cells(from_component)
	var to_edges := _component_edge_cells(to_component)
	var best_from := Vector2i(-1, -1)
	var best_to := Vector2i(-1, -1)
	var best_distance := INF

	for from_cell in from_edges:
		for to_cell in to_edges:
			var distance := (
				absi(from_cell.x - to_cell.x)
				+ absi(from_cell.y - to_cell.y)
			)
			if distance < best_distance:
				best_distance = distance
				best_from = from_cell
				best_to = to_cell

	if best_from.x < 0 or best_to.x < 0:
		return []
	return [best_from, best_to]


func _component_edge_cells(component: Array[Vector2i]) -> Array[Vector2i]:
	var edges: Array[Vector2i] = []
	for cell in component:
		for direction in CARDINAL_DIRECTIONS:
			var neighbor := cell + direction
			if _is_inside(neighbor) and _is_wall(neighbor):
				edges.append(cell)
				break
	return edges


func _carve_l_corridor(from_cell: Vector2i, to_cell: Vector2i) -> void:
	var carve_x_first := from_cell.x % 2 == 0
	var corner := (
		Vector2i(to_cell.x, from_cell.y)
		if carve_x_first
		else Vector2i(from_cell.x, to_cell.y)
	)
	_carve_straight_corridor(from_cell, corner)
	_carve_straight_corridor(corner, to_cell)


func _carve_straight_corridor(from_cell: Vector2i, to_cell: Vector2i) -> void:
	var step := Vector2i(
		signi(to_cell.x - from_cell.x),
		signi(to_cell.y - from_cell.y)
	)
	var cell := from_cell
	while cell != to_cell:
		_cells[cell.y][cell.x] = 0
		cell += step
	_cells[to_cell.y][to_cell.x] = 0


func _add_stations(rng: RandomNumberGenerator) -> void:
	var placement := rng.randi_range(0, 2)
	var station_one_x := CENTER_PLACEMENT_X
	if placement == 0:
		station_one_x = LEFT_PLACEMENT_X
	elif placement == 2:
		station_one_x = RIGHT_PLACEMENT_X
	station_one_x += rng.randi_range(-PLACEMENT_SPREAD, PLACEMENT_SPREAD)

	if placement == 1:
		_planned_exit_x = (
			LEFT_PLACEMENT_X
			if rng.randi_range(0, 1) == 0
			else RIGHT_PLACEMENT_X
		)
	else:
		_planned_exit_x = CENTER_PLACEMENT_X
	_planned_exit_x += rng.randi_range(-PLACEMENT_SPREAD, PLACEMENT_SPREAD)

	_add_station(
		Vector2i(station_one_x, ROWS - STATION_ROOM_RADIUS - 1),
		1,
		Vector2i.DOWN
	)
	var station_two_region := rng.randi_range(0, 2)
	var remaining_regions: Array[int] = [0, 1, 2]
	remaining_regions.erase(station_two_region)
	var station_three_region := remaining_regions[
		rng.randi_range(0, remaining_regions.size() - 1)
	]
	_add_station(
		Vector2i(
			_upgrade_station_x(station_two_region, rng),
			LEVEL_TWO_UPGRADE_STATION_Y
		),
		2,
		Vector2i.ZERO
	)
	_add_station(
		Vector2i(
			_upgrade_station_x(station_three_region, rng),
			LEVEL_FOUR_UPGRADE_STATION_Y
		),
		3,
		Vector2i.ZERO
	)


func _upgrade_station_x(region: int, rng: RandomNumberGenerator) -> int:
	var base_x := CENTER_PLACEMENT_X
	if region == 0:
		base_x = LEFT_PLACEMENT_X
	elif region == 2:
		base_x = RIGHT_PLACEMENT_X
	return base_x + rng.randi_range(-PLACEMENT_SPREAD, PLACEMENT_SPREAD)


func _add_station(
	center: Vector2i,
	station_id: int,
	locked_direction: Vector2i
) -> void:
	_carve_station(center)

	var doors: Array[Dictionary] = []
	for direction in CARDINAL_DIRECTIONS:
		var door_cell := center + direction * STATION_ROOM_RADIUS
		var locked := direction == locked_direction
		doors.append({
			"cell": door_cell,
			"horizontal_passage": direction.x != 0,
			"locked": locked,
		})
		if not locked:
			_connect_station_door(door_cell, direction)

	_station_specs.append({
		"cell": center,
		"station_id": station_id,
		"doors": doors,
		"start_cell": center
				+ Vector2i.DOWN * STATION_FLOOR_RADIUS,
		"start_facing": Vector2i.UP,
	})


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
	while cell.x > 0 and cell.x < COLUMNS - 1 \
			and cell.y > 0 and cell.y < ROWS - 1:
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


func _is_inside_primary_station(cell: Vector2i) -> bool:
	if _station_specs.is_empty():
		return false
	var center: Vector2i = _station_specs[0].cell
	return absi(cell.x - center.x) <= STATION_ROOM_RADIUS \
			and absi(cell.y - center.y) <= STATION_ROOM_RADIUS


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


func _update_visible_cells(
	viewer_position: Vector2,
	viewer_direction: Vector2,
	viewer_cell: Vector2i,
) -> void:
	_visible_cells.clear()
	_visible_cells[viewer_cell] = true
	for y in range(
		maxi(0, viewer_cell.y - DRAW_RADIUS),
		mini(ROWS, viewer_cell.y + DRAW_RADIUS + 1)
	):
		for x in range(
			maxi(0, viewer_cell.x - DRAW_RADIUS),
			mini(COLUMNS, viewer_cell.x + DRAW_RADIUS + 1)
		):
			var cell := Vector2i(x, y)
			if cell == viewer_cell \
					or cell.distance_squared_to(viewer_cell) \
					> DRAW_RADIUS * DRAW_RADIUS:
				continue
			if _cell_is_visible_from(
				cell,
				viewer_position,
				viewer_direction
			):
				_visible_cells[cell] = true


func _cell_is_visible_from(
	cell: Vector2i,
	viewer_position: Vector2,
	viewer_direction: Vector2
) -> bool:
	var cell_origin := Vector2(cell) * CELL_SIZE
	var inset := 1.0
	var forward_point := cell_origin + Vector2(
		CELL_SIZE - inset if viewer_direction.x >= 0.0 else inset,
		CELL_SIZE - inset if viewer_direction.y >= 0.0 else inset
	)
	if viewer_direction.dot(forward_point - viewer_position) > 0.0 \
			and _has_clear_view_to_point(
				viewer_position,
				forward_point,
				cell
			):
		return true

	var center := cell_to_world(cell)
	return viewer_direction.dot(center - viewer_position) > 0.0 \
			and _has_clear_view_to_point(
				viewer_position,
				center,
				cell
			)


func _has_clear_view_to_point(
	from_position: Vector2,
	to_position: Vector2,
	target_cell: Vector2i
) -> bool:
	var direction := to_position - from_position
	if direction.is_zero_approx():
		return true

	var current := world_to_cell(from_position)
	var step := Vector2i(
		int(signf(direction.x)),
		int(signf(direction.y))
	)
	var delta_t := Vector2(
		INF if is_zero_approx(direction.x) else CELL_SIZE / absf(direction.x),
		INF if is_zero_approx(direction.y) else CELL_SIZE / absf(direction.y)
	)
	var next_boundary := Vector2(
		float(current.x + (1 if step.x > 0 else 0)) * CELL_SIZE,
		float(current.y + (1 if step.y > 0 else 0)) * CELL_SIZE
	)
	var max_t := Vector2(
		INF if step.x == 0 else (
			next_boundary.x - from_position.x
		) / direction.x,
		INF if step.y == 0 else (
			next_boundary.y - from_position.y
		) / direction.y
	)

	while current != target_cell:
		if max_t.x < max_t.y:
			current.x += step.x
			max_t.x += delta_t.x
		elif max_t.y < max_t.x:
			current.y += step.y
			max_t.y += delta_t.y
		else:
			var horizontal_cell := current + Vector2i(step.x, 0)
			var vertical_cell := current + Vector2i(0, step.y)
			if _cell_blocks_view(horizontal_cell, target_cell) \
					or _cell_blocks_view(vertical_cell, target_cell):
				return false
			current.x += step.x
			current.y += step.y
			max_t += delta_t

		if current == target_cell:
			return true
		if not _is_inside(current) \
				or _is_wall(current) \
				or _closed_door_cells.has(current):
			return false
	return true


func _cell_blocks_view(cell: Vector2i, target_cell: Vector2i) -> bool:
	if cell == target_cell:
		return false
	return not _is_inside(cell) \
			or _is_wall(cell) \
			or _closed_door_cells.has(cell)


func _is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < COLUMNS and cell.y >= 0 and cell.y < ROWS


func _is_wall(cell: Vector2i) -> bool:
	return _cells[cell.y][cell.x] == 1


func _cell_index(cell: Vector2i) -> int:
	return cell.y * COLUMNS + cell.x


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

			_draw_environment_tile(
				cell,
				true,
				EXPLORED_WALL_TILE_MODULATE
			)

	for visible_cell in _visible_cells:
		var cell: Vector2i = visible_cell
		if _is_wall(cell):
			_draw_environment_tile(cell, true)
		else:
			var safe := is_cell_safe(cell)
			_draw_environment_tile(
				cell,
				false,
				SAFE_FLOOR_TILE_MODULATE if safe else Color.WHITE
			)

	_draw_enemy_level_boundaries()


func _draw_enemy_level_boundaries() -> void:
	if _view_cell.x < 0 or _view_cell.y < 0:
		return
	var left_cell_x := maxi(0, _view_cell.x - DRAW_RADIUS)
	var right_cell_x := mini(COLUMNS, _view_cell.x + DRAW_RADIUS + 1)
	for boundary_index in range(1, ENEMY_LEVEL_COUNT):
		var boundary_cell_y := floori(
			float(boundary_index * ROWS) / float(ENEMY_LEVEL_COUNT)
		)
		if absi(boundary_cell_y - _view_cell.y) > DRAW_RADIUS:
			continue
		var line_y := float(boundary_cell_y) * CELL_SIZE
		draw_line(
			Vector2(float(left_cell_x) * CELL_SIZE, line_y),
			Vector2(float(right_cell_x) * CELL_SIZE, line_y),
			LEVEL_BOUNDARY_COLOR,
			LEVEL_BOUNDARY_WIDTH,
			true
		)


func _draw_environment_tile(
	cell: Vector2i,
	wall: bool,
	modulate: Color = Color.WHITE
) -> void:
	var tile_count := WALL_TILE_COUNT if wall else FLOOR_TILE_COUNT
	var tile_index := posmod(_cell_visual_hash(cell), tile_count)
	if wall:
		tile_index += WALL_TILE_OFFSET
	var atlas_cell := Vector2i(tile_index % 4, tile_index / 4)
	var destination := Rect2(
		Vector2(cell) * CELL_SIZE,
		Vector2.ONE * CELL_SIZE
	)
	var source := Rect2(
		Vector2(atlas_cell) * CELL_SIZE,
		Vector2.ONE * CELL_SIZE
	)
	draw_texture_rect_region(
		ENVIRONMENT_ATLAS,
		destination,
		source,
		modulate
	)


func _cell_visual_hash(cell: Vector2i) -> int:
	return cell.x * 73856093 ^ cell.y * 19349663 ^ _generation_seed
