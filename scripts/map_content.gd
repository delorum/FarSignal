extends Control

const PANEL_COLOR := Color("0c1727")
const FLOOR_COLOR := Color("172943")
const WALL_COLOR := Color("3f6688")
const PLAYER_COLOR := Color("58d6f5")
const SIGNAL_COLOR := Color("ffc247")

var scroll_position := Vector2.ZERO
var cell_size := 40.0

var _maze: Maze
var _player: Player
var _goal: Node2D


func setup(
	maze: Maze,
	player: Player,
	goal: Node2D,
	cell_size: float
) -> void:
	_maze = maze
	_player = player
	_goal = goal
	self.cell_size = cell_size
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PANEL_COLOR)
	if _maze == null or _player == null:
		return

	var map_origin := size * 0.5 - scroll_position
	var grid_size := _maze.grid_size()
	for y in grid_size.y:
		for x in grid_size.x:
			var cell := Vector2i(x, y)
			if not _maze.is_cell_explored(cell):
				continue

			var cell_rect := Rect2(
				map_origin + Vector2(cell) * cell_size,
				Vector2.ONE * cell_size
			)
			var color := WALL_COLOR if _maze.is_wall(cell) else FLOOR_COLOR
			draw_rect(cell_rect.grow(-1.0), color)

	var player_cell := _maze.world_to_cell(_player.position)
	var player_position := (
		map_origin
		+ (Vector2(player_cell) + Vector2.ONE * 0.5) * cell_size
	)
	draw_circle(player_position, cell_size * 0.22, PLAYER_COLOR)

	var goal_cell := _maze.world_to_cell(_goal.position)
	if _maze.is_cell_explored(goal_cell):
		var goal_position := (
			map_origin
			+ (Vector2(goal_cell) + Vector2.ONE * 0.5) * cell_size
		)
		var marker_size := cell_size * 0.28
		var points := PackedVector2Array([
			goal_position + Vector2(0.0, -marker_size),
			goal_position + Vector2(marker_size, marker_size),
			goal_position + Vector2(-marker_size, marker_size),
		])
		draw_colored_polygon(points, SIGNAL_COLOR)
