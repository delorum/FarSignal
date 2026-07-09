extends Node2D

const VISION_LINE_COLOR := Color("bd3f43")
const VISION_LINE_WIDTH := 2.0
const SAMPLE_STEP := Maze.CELL_SIZE * 0.25

var enemies: Node2D
var maze: Maze


func setup(maze_node: Maze, enemies_node: Node2D) -> void:
	maze = maze_node
	enemies = enemies_node
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if maze == null or enemies == null:
		return

	for enemy: Enemy in enemies.get_children():
		if not enemy.should_draw_vision_line():
			continue
		_draw_visible_vision_line(enemy)


func _draw_visible_vision_line(enemy: Enemy) -> void:
	var start := enemy.position
	var direction := enemy.facing_direction()
	if direction.is_zero_approx():
		return

	direction = direction.normalized()
	var end := _vision_line_end(start, direction)
	var distance := start.distance_to(end)
	if distance <= 0.0:
		return

	var segment_start := Vector2.ZERO
	var previous_point := start
	var drawing_segment := false
	var steps := ceili(distance / SAMPLE_STEP)
	for index in range(steps + 1):
		var progress := float(index) / float(steps)
		var point := start.lerp(end, progress)
		var visible := _is_visible_floor_point(point)
		if visible and not drawing_segment:
			segment_start = point
			drawing_segment = true
		elif not visible and drawing_segment:
			draw_line(
				segment_start,
				previous_point,
				VISION_LINE_COLOR,
				VISION_LINE_WIDTH,
				true
			)
			drawing_segment = false
		previous_point = point

	if drawing_segment:
		draw_line(
			segment_start,
			previous_point,
			VISION_LINE_COLOR,
			VISION_LINE_WIDTH,
			true
		)


func _is_visible_floor_point(point: Vector2) -> bool:
	var cell := maze.world_to_cell(point)
	return maze.is_cell_visible(cell) \
			and not maze.is_wall(cell) \
			and not maze.is_closed_door(cell)


func _vision_line_end(start: Vector2, direction: Vector2) -> Vector2:
	var max_distance := Enemy.VISION_RANGE * Maze.CELL_SIZE
	var last_clear := start
	var steps := ceili(max_distance / SAMPLE_STEP)
	for index in range(1, steps + 1):
		var point := start + direction * SAMPLE_STEP * float(index)
		var cell := maze.world_to_cell(point)
		if maze.is_wall(cell) \
				or maze.is_closed_door(cell) \
				or not maze.has_line_of_sight(
					start,
					point,
					Enemy.VISION_RANGE
				):
			break
		last_clear = point
	return last_clear
