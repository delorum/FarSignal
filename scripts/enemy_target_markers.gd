extends Node2D

const MARKER_COLOR := Color("e8fbff")
const MARKER_RADIUS := 9.0

var enemies: Node2D
var maze: Maze


func setup(maze_node: Maze, enemies_node: Node2D) -> void:
	maze = maze_node
	enemies = enemies_node
	queue_redraw()


func target_cells() -> Array[Vector2i]:
	var cells: Dictionary = {}
	if enemies == null:
		return []

	for enemy: Enemy in enemies.get_children():
		var target := enemy.pursuit_target_cell()
		if target.x >= 0:
			cells[target] = true

	var result: Array[Vector2i] = []
	result.assign(cells.keys())
	return result


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if maze == null:
		return

	for cell in target_cells():
		var center := maze.cell_to_world(cell)
		var points := PackedVector2Array([
			center + Vector2(0.0, -MARKER_RADIUS),
			center + Vector2(MARKER_RADIUS, 0.0),
			center + Vector2(0.0, MARKER_RADIUS),
			center + Vector2(-MARKER_RADIUS, 0.0),
			center + Vector2(0.0, -MARKER_RADIUS),
		])
		draw_polyline(points, MARKER_COLOR, 3.0, true)
