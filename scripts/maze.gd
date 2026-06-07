extends StaticBody2D
class_name Maze

const COLUMNS := 25
const ROWS := 17
const CELL_SIZE := 48.0
const WALL_COLOR := Color("29415f")
const WALL_EDGE_COLOR := Color("3f6688")

var _cells: Array[PackedByteArray] = []


func _ready() -> void:
	_generate(73421)
	_build_collisions()
	queue_redraw()


func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell) * CELL_SIZE + Vector2.ONE * CELL_SIZE * 0.5


func world_size() -> Vector2:
	return Vector2(COLUMNS, ROWS) * CELL_SIZE


func _generate(seed_value: int) -> void:
	_cells.clear()
	for y in ROWS:
		var row := PackedByteArray()
		row.resize(COLUMNS)
		row.fill(1)
		_cells.append(row)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var stack: Array[Vector2i] = [Vector2i(1, 1)]
	_cells[1][1] = 0

	var directions: Array[Vector2i] = [
		Vector2i.RIGHT,
		Vector2i.DOWN,
		Vector2i.LEFT,
		Vector2i.UP,
	]

	while not stack.is_empty():
		var current: Vector2i = stack.back()
		var candidates: Array[Vector2i] = []

		for direction in directions:
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


func _draw() -> void:
	for y in ROWS:
		for x in COLUMNS:
			if _cells[y][x] == 0:
				continue

			var rect := Rect2(Vector2(x, y) * CELL_SIZE, Vector2.ONE * CELL_SIZE)
			draw_rect(rect, WALL_COLOR)
			draw_rect(rect.grow(-2.0), WALL_EDGE_COLOR, false, 2.0)
