extends Control

const PANEL_COLOR := Color("0c1727")
const FLOOR_COLOR := Color("172943")
const WALL_COLOR := Color("3f6688")
const PLAYER_COLOR := Color("58d6f5")

var scroll_position := Vector2.ZERO
var cell_size := 40.0

var _maze: Maze
var _player: Player


func setup(
	maze: Maze,
	player: Player,
	cell_size: float
) -> void:
	_maze = maze
	_player = player
	self.cell_size = cell_size
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PANEL_COLOR)
	if _maze == null or _player == null:
		return

	var map_origin := size * 0.5 - scroll_position
	var grid_size := _maze.grid_size()
	var first_cell := Vector2i(
		maxi(0, floori(-map_origin.x / cell_size)),
		maxi(0, floori(-map_origin.y / cell_size))
	)
	var last_cell := Vector2i(
		mini(grid_size.x - 1, ceili((size.x - map_origin.x) / cell_size)),
		mini(grid_size.y - 1, ceili((size.y - map_origin.y) / cell_size))
	)

	for y in range(first_cell.y, last_cell.y + 1):
		for x in range(first_cell.x, last_cell.x + 1):
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
