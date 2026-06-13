extends StaticBody2D
class_name Door

const CELL_SIZE := 48.0
const CLOSED_COLOR := Color("8a6f4d")
const CLOSED_EDGE_COLOR := Color("d0a86f")
const OPEN_COLOR := Color("4d4235")
const LOCKED_COLOR := Color("503b3b")
const LOCKED_EDGE_COLOR := Color("8a5a5a")
const EXPLORED_COLOR := Color("14171b")
const EXPLORED_EDGE_COLOR := Color("20242a")

var cell := Vector2i.ZERO
var horizontal_passage := true
var locked := false
var is_open := false
var player_placed := false
var _currently_visible := false
var _explored := false

@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func setup(
	door_cell: Vector2i,
	is_horizontal_passage: bool,
	is_locked: bool = false,
	starts_open: bool = false,
	is_player_placed: bool = false
) -> void:
	cell = door_cell
	horizontal_passage = is_horizontal_passage
	locked = is_locked
	is_open = starts_open
	player_placed = is_player_placed
	position = (Vector2(cell) + Vector2.ONE * 0.5) * CELL_SIZE


func _ready() -> void:
	_update_collision()
	queue_redraw()


func toggle(player_position: Vector2) -> bool:
	if locked:
		return false
	if is_open and player_position.distance_to(position) < CELL_SIZE * 0.7:
		return false

	is_open = not is_open
	_update_collision()
	queue_redraw()
	return true


func update_visibility(currently_visible: bool, explored: bool) -> void:
	_currently_visible = currently_visible
	_explored = explored
	visible = currently_visible or explored
	queue_redraw()


func save_data() -> Dictionary:
	return {
		"cell": [cell.x, cell.y],
		"horizontal_passage": horizontal_passage,
		"locked": locked,
		"open": is_open,
		"player_placed": player_placed,
	}


func _update_collision() -> void:
	if collision_shape != null:
		collision_shape.set_deferred("disabled", is_open)


func _draw() -> void:
	var dimmed := _explored and not _currently_visible
	var slab_size := (
		Vector2(10.0, CELL_SIZE)
		if horizontal_passage
		else Vector2(CELL_SIZE, 10.0)
	)
	if not is_open:
		var rect := Rect2(-slab_size * 0.5, slab_size)
		var color := (
			EXPLORED_COLOR
			if dimmed
			else LOCKED_COLOR if locked else CLOSED_COLOR
		)
		var edge_color := (
			EXPLORED_EDGE_COLOR
			if dimmed
			else LOCKED_EDGE_COLOR if locked else CLOSED_EDGE_COLOR
		)
		draw_rect(rect, color)
		draw_rect(rect.grow(-2.0), edge_color, false, 1.0 if dimmed else 2.0)
		return

	var panel_size := (
		Vector2(5.0, CELL_SIZE * 0.28)
		if horizontal_passage
		else Vector2(CELL_SIZE * 0.28, 5.0)
	)
	var offset := (
		Vector2(0.0, CELL_SIZE * 0.36)
		if horizontal_passage
		else Vector2(CELL_SIZE * 0.36, 0.0)
	)
	var open_color := EXPLORED_COLOR if dimmed else OPEN_COLOR
	draw_rect(Rect2(-panel_size * 0.5 - offset, panel_size), open_color)
	draw_rect(Rect2(-panel_size * 0.5 + offset, panel_size), open_color)
