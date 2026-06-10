extends Control

const PANEL_COLOR := Color("0c1727")
const FLOOR_COLOR := Color("172943")
const WALL_COLOR := Color("3f6688")
const PLAYER_COLOR := Color("58d6f5")
const CLOSED_DOOR_COLOR := Color("d0a86f")
const OPEN_DOOR_COLOR := Color("8a6f4d")
const STATION_COLOR := Color("245d3b")
const STATION_EDGE_COLOR := Color("3d8155")

var scroll_position := Vector2.ZERO
var cell_size := 40.0

var _maze: Maze
var _player: Player
var _doors: Node2D
var _stations: Node2D


func setup(
	maze: Maze,
	player: Player,
	doors: Node2D,
	stations: Node2D,
	cell_size: float
) -> void:
	_maze = maze
	_player = player
	_doors = doors
	_stations = stations
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

	_draw_doors(map_origin)
	_draw_stations(map_origin)

	var player_cell := _maze.world_to_cell(_player.position)
	var player_position := (
		map_origin
		+ (Vector2(player_cell) + Vector2.ONE * 0.5) * cell_size
	)
	draw_circle(player_position, cell_size * 0.22, PLAYER_COLOR)


func _draw_doors(map_origin: Vector2) -> void:
	if _doors == null:
		return

	for door in _doors.get_children():
		if not _maze.is_cell_explored(door.cell):
			continue

		var center := (
			map_origin
			+ (Vector2(door.cell) + Vector2.ONE * 0.5) * cell_size
		)
		var half_length := cell_size * 0.42
		var line_width := maxf(2.0, cell_size * 0.12)
		var axis := (
			Vector2.DOWN
			if door.horizontal_passage
			else Vector2.RIGHT
		)

		if not door.is_open:
			draw_line(
				center - axis * half_length,
				center + axis * half_length,
				CLOSED_DOOR_COLOR,
				line_width
			)
			continue

		var outer := half_length
		var inner := half_length * 0.45
		draw_line(
			center - axis * outer,
			center - axis * inner,
			OPEN_DOOR_COLOR,
			line_width
		)
		draw_line(
			center + axis * inner,
			center + axis * outer,
			OPEN_DOOR_COLOR,
			line_width
		)


func _draw_stations(map_origin: Vector2) -> void:
	if _stations == null:
		return

	for station in _stations.get_children():
		if not station.discovered:
			continue

		var center := (
			map_origin
			+ (Vector2(station.cell) + Vector2.ONE * 0.5) * cell_size
		)
		var radius := cell_size * 0.3
		var points := PackedVector2Array([
			center + Vector2(0.0, -radius),
			center + Vector2(radius, 0.0),
			center + Vector2(0.0, radius),
			center + Vector2(-radius, 0.0),
		])
		draw_colored_polygon(points, STATION_COLOR)
		var outline := points.duplicate()
		outline.append(points[0])
		draw_polyline(outline, STATION_EDGE_COLOR, 1.0, true)
