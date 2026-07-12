extends Control

const PANEL_COLOR := Color("0c1727")
const FLOOR_COLOR := Color("172943")
const SAFE_FLOOR_COLOR := Color("24513d")
const WALL_COLOR := Color("3f6688")
const PLAYER_COLOR := Color("58d6f5")
const CLOSED_DOOR_COLOR := Color("d0a86f")
const OPEN_DOOR_COLOR := Color("8a6f4d")
const STATION_COLOR := Color("245d3b")
const STATION_EDGE_COLOR := Color("3d8155")
const DEAD_ENEMY_COLOR := Color("3b4148")
const DEAD_ENEMY_EDGE_COLOR := Color("626b75")
const DEAD_ENEMY_CORE_COLOR := Color(1.0, 0.92, 0.36, 1.0)
const DEAD_ENEMY_CORE_EDGE_COLOR := Color(1.0, 1.0, 0.78, 1.0)
const MEGA_CORE_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const MAP_MARKER_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const MAP_MARKER_PATH_COLOR := Color(1.0, 1.0, 1.0, 0.62)
const LEVEL_BOUNDARY_COLOR := Color(1.0, 1.0, 1.0, 0.82)
const LEVEL_LABEL_SHADOW_COLOR := Color(0.02, 0.03, 0.04, 0.95)
const ENEMY_LEVEL_COUNT := 5

var scroll_position := Vector2.ZERO
var cell_size := 40.0

var _game: Node
var _maze: Maze
var _player: Player
var _doors: Node2D
var _stations: Node2D
var _enemies: Node2D


func setup(
	game: Node,
	maze: Maze,
	player: Player,
	doors: Node2D,
	stations: Node2D,
	enemies: Node2D,
	cell_size: float
) -> void:
	_game = game
	_maze = maze
	_player = player
	_doors = doors
	_stations = stations
	_enemies = enemies
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
			var color := (
				WALL_COLOR
				if _maze.is_wall(cell)
				else (
					SAFE_FLOOR_COLOR
					if _maze.is_cell_safe(cell)
					else FLOOR_COLOR
				)
			)
			draw_rect(cell_rect.grow(-1.0), color)

	_draw_enemy_level_boundaries(map_origin, grid_size)
	_draw_doors(map_origin)
	_draw_map_marker_path(map_origin)
	_draw_stations(map_origin)
	_draw_dead_enemies(map_origin)
	_draw_mega_core(map_origin)
	_draw_map_marker(map_origin)

	var player_cell := _maze.world_to_cell(_player.position)
	var player_position := (
		map_origin
		+ (Vector2(player_cell) + Vector2.ONE * 0.5) * cell_size
	)
	draw_circle(player_position, cell_size * 0.22, PLAYER_COLOR)


func _draw_enemy_level_boundaries(
	map_origin: Vector2,
	grid_size: Vector2i
) -> void:
	var map_left := map_origin.x
	var map_right := map_origin.x + float(grid_size.x) * cell_size
	var visible_left := maxf(0.0, map_left)
	var visible_right := minf(size.x, map_right)
	if visible_left >= visible_right:
		return

	var font := ThemeDB.fallback_font
	var font_size := maxi(12, roundi(cell_size * 0.8))
	for boundary_index in range(1, ENEMY_LEVEL_COUNT):
		var boundary_cell_y := floori(
			float(boundary_index * grid_size.y) / float(ENEMY_LEVEL_COUNT)
		)
		var line_y := map_origin.y + float(boundary_cell_y) * cell_size
		if line_y < 0.0 or line_y > size.y:
			continue
		draw_line(
			Vector2(visible_left, line_y),
			Vector2(visible_right, line_y),
			LEVEL_BOUNDARY_COLOR,
			2.0,
			true
		)

		var upper_level := ENEMY_LEVEL_COUNT + 1 - boundary_index
		var lower_level := ENEMY_LEVEL_COUNT - boundary_index
		var label_x := visible_left + 6.0
		_draw_level_label(
			font,
			Vector2(label_x, line_y - 5.0),
			str(upper_level),
			font_size
		)
		_draw_level_label(
			font,
			Vector2(label_x, line_y + float(font_size) + 5.0),
			str(lower_level),
			font_size
		)


func _draw_level_label(
	font: Font,
	position: Vector2,
	text: String,
	font_size: int
) -> void:
	draw_string(
		font,
		position + Vector2.ONE,
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size,
		LEVEL_LABEL_SHADOW_COLOR
	)
	draw_string(
		font,
		position,
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size,
		LEVEL_BOUNDARY_COLOR
	)


func cell_at_local_position(local_position: Vector2) -> Vector2i:
	var map_origin := size * 0.5 - scroll_position
	var cell := Vector2i(floor((local_position - map_origin) / cell_size))
	if _maze == null:
		return Vector2i(-1, -1)
	var grid_size := _maze.grid_size()
	if cell.x < 0 or cell.y < 0 \
			or cell.x >= grid_size.x or cell.y >= grid_size.y:
		return Vector2i(-1, -1)
	return cell


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


func _draw_dead_enemies(map_origin: Vector2) -> void:
	if _enemies == null:
		return

	for enemy in _enemies.get_children():
		if not enemy.dead:
			continue

		var enemy_cell: Vector2i = _maze.world_to_cell(enemy.position)
		if not _maze.is_cell_explored(enemy_cell):
			continue

		var center := (
			map_origin
			+ (Vector2(enemy_cell) + Vector2.ONE * 0.5) * cell_size
		)
		var radius := cell_size * 0.22
		if enemy.has_energy_core():
			draw_circle(center, radius, DEAD_ENEMY_CORE_COLOR)
		draw_circle(
			center,
			radius,
			(
				DEAD_ENEMY_CORE_EDGE_COLOR
				if enemy.has_energy_core()
				else DEAD_ENEMY_EDGE_COLOR
			),
			false,
			maxf(1.0, cell_size * 0.05),
			true
		)


func _draw_mega_core(map_origin: Vector2) -> void:
	if _player.has_mega_core or _player.mega_core_cell.x < 0:
		return

	var center := (
		map_origin
		+ (Vector2(_player.mega_core_cell) + Vector2.ONE * 0.5) * cell_size
	)
	var radius := cell_size * 0.28
	var points := PackedVector2Array([
		center + Vector2(0.0, -radius),
		center + Vector2(radius, 0.0),
		center + Vector2(0.0, radius),
		center + Vector2(-radius, 0.0),
		center + Vector2(0.0, -radius),
	])
	draw_polyline(points, MEGA_CORE_COLOR, maxf(1.5, cell_size * 0.08), true)


func _draw_map_marker_path(map_origin: Vector2) -> void:
	if _game == null \
			or not _game.has_method("map_marker_path") \
			or _player == null:
		return

	var path: Array[Vector2i] = _game.map_marker_path()
	if path.is_empty():
		return

	var points := PackedVector2Array()
	for cell in path:
		points.append(_map_cell_center(map_origin, cell))

	if points.size() >= 2:
		draw_polyline(
			points,
			MAP_MARKER_PATH_COLOR,
			maxf(2.0, cell_size * 0.08),
			true
		)


func _draw_map_marker(map_origin: Vector2) -> void:
	if _game == null \
			or not _game.has_method("has_map_marker") \
			or not _game.has_map_marker():
		return

	var marker_cell: Vector2i = _game.map_marker_cell()
	if not _maze.is_cell_explored(marker_cell):
		return

	var center := (
		_map_cell_center(map_origin, marker_cell)
	)
	draw_circle(center, cell_size * 0.22, MAP_MARKER_COLOR)


func _map_cell_center(map_origin: Vector2, cell: Vector2i) -> Vector2:
	return map_origin + (Vector2(cell) + Vector2.ONE * 0.5) * cell_size
