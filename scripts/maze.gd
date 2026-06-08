extends StaticBody2D
class_name Maze

const COLUMNS := 25
const ROWS := 17
const CELL_SIZE := 48.0
const FLOOR_COLOR := Color("101b2d")
const FLOOR_EDGE_COLOR := Color("172943")
const WALL_COLOR := Color("29415f")
const WALL_EDGE_COLOR := Color("3f6688")
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


func _ready() -> void:
	_generate()
	_build_collisions()
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


func get_random_floor_cell(rng: RandomNumberGenerator) -> Vector2i:
	var floor_cells: Array[Vector2i] = []
	for y in ROWS:
		for x in COLUMNS:
			var cell := Vector2i(x, y)
			if not _is_wall(cell):
				floor_cells.append(cell)

	return floor_cells[rng.randi_range(0, floor_cells.size() - 1)]


func get_random_distant_floor_cell(
	origin: Vector2i,
	rng: RandomNumberGenerator,
	minimum_steps: int
) -> Vector2i:
	var distances: Dictionary = {origin: 0}
	var queue: Array[Vector2i] = [origin]
	var candidates: Array[Vector2i] = []
	var farthest_cells: Array[Vector2i] = [origin]
	var farthest_distance := 0
	var queue_index := 0

	while queue_index < queue.size():
		var current := queue[queue_index]
		queue_index += 1
		var current_distance: int = distances[current]

		if current_distance >= minimum_steps:
			candidates.append(current)

		if current_distance > farthest_distance:
			farthest_distance = current_distance
			farthest_cells.assign([current])
		elif current_distance == farthest_distance:
			farthest_cells.append(current)

		for direction in CARDINAL_DIRECTIONS:
			var neighbor := current + direction
			if _is_inside(neighbor) and not _is_wall(neighbor) \
					and not distances.has(neighbor):
				distances[neighbor] = current_distance + 1
				queue.append(neighbor)

	var available_cells := candidates if not candidates.is_empty() else farthest_cells
	return available_cells[rng.randi_range(0, available_cells.size() - 1)]


func update_visibility(viewer_position: Vector2) -> void:
	var viewer_cell := world_to_cell(viewer_position)
	if viewer_cell == _view_cell or not _is_inside(viewer_cell):
		return

	_view_cell = viewer_cell
	_visible_cells.clear()
	_reveal_floor_with_walls(viewer_cell)
	_reveal_diagonal_walls(viewer_cell)

	for direction in CARDINAL_DIRECTIONS:
		var cell := viewer_cell + direction
		while _is_inside(cell) and not _is_wall(cell):
			_reveal_floor_with_walls(cell)
			cell += direction

	_mark_cell_explored(viewer_cell)

	queue_redraw()


func is_cell_visible(cell: Vector2i) -> bool:
	return _visible_cells.has(cell)


func _generate() -> void:
	_cells.clear()
	for y in ROWS:
		var row := PackedByteArray()
		row.resize(COLUMNS)
		row.fill(1)
		_cells.append(row)

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var stack: Array[Vector2i] = [Vector2i(1, 1)]
	_cells[1][1] = 0

	while not stack.is_empty():
		var current: Vector2i = stack.back()
		var candidates: Array[Vector2i] = []

		for direction in CARDINAL_DIRECTIONS:
			var next: Vector2i = current + direction * 2
			if next.x > 0 and next.x < COLUMNS - 1 \
					and next.y > 0 and next.y < ROWS - 1 \
					and _cells[next.y][next.x] == 1:
				candidates.append(next)

		if candidates.is_empty():
			stack.pop_back()
			continue

		var next: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]
		var between: Vector2i = (current + next) / 2
		_cells[between.y][between.x] = 0
		_cells[next.y][next.x] = 0
		stack.append(next)


func _build_collisions() -> void:
	for y in ROWS:
		for x in COLUMNS:
			if _cells[y][x] == 0:
				continue

			var collision := CollisionShape2D.new()
			var shape := RectangleShape2D.new()
			shape.size = Vector2.ONE * CELL_SIZE
			collision.shape = shape
			collision.position = cell_to_world(Vector2i(x, y))
			add_child(collision)


func _reveal_floor_with_walls(cell: Vector2i) -> void:
	if not _is_inside(cell) or _is_wall(cell):
		return

	_visible_cells[cell] = true
	for direction in CARDINAL_DIRECTIONS:
		var neighbor: Vector2i = cell + direction
		if _is_inside(neighbor) and _is_wall(neighbor):
			_visible_cells[neighbor] = true


func _reveal_diagonal_walls(cell: Vector2i) -> void:
	for direction in DIAGONAL_DIRECTIONS:
		var neighbor := cell + direction
		if _is_inside(neighbor) and _is_wall(neighbor):
			_visible_cells[neighbor] = true


func _mark_cell_explored(cell: Vector2i) -> void:
	_explored_cells[cell] = true
	for direction in CARDINAL_DIRECTIONS + DIAGONAL_DIRECTIONS:
		var neighbor := cell + direction
		if _is_inside(neighbor) and _is_wall(neighbor):
			_explored_cells[neighbor] = true


func _is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < COLUMNS and cell.y >= 0 and cell.y < ROWS


func _is_wall(cell: Vector2i) -> bool:
	return _cells[cell.y][cell.x] == 1


func _draw() -> void:
	for y in ROWS:
		for x in COLUMNS:
			var cell := Vector2i(x, y)
			if not _visible_cells.has(cell):
				continue

			var rect := Rect2(Vector2(x, y) * CELL_SIZE, Vector2.ONE * CELL_SIZE)
			if _is_wall(cell):
				draw_rect(rect, WALL_COLOR)
				draw_rect(rect.grow(-2.0), WALL_EDGE_COLOR, false, 2.0)
			else:
				draw_rect(rect, FLOOR_COLOR)
				draw_rect(rect.grow(-2.0), FLOOR_EDGE_COLOR, false, 1.0)
