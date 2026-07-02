extends Node2D

const LIFETIME := 1.0
const MOVE_DISTANCE := 72.0
const FONT_SIZE := 22
const TEXT_COLOR := Color("ffdf78")
const OUTLINE_COLOR := Color("24170b")

var _text := ""
var _direction := Vector2.RIGHT
var _elapsed := 0.0


func setup(
	start_position: Vector2,
	damage: int,
	flight_direction: Vector2
) -> void:
	position = start_position
	_text = str(damage)
	_setup_direction(flight_direction)


func setup_text(
	start_position: Vector2,
	text: String,
	flight_direction: Vector2
) -> void:
	position = start_position
	_text = text
	_setup_direction(flight_direction)


func _setup_direction(flight_direction: Vector2) -> void:
	_direction = flight_direction.normalized()
	if _direction.is_zero_approx():
		_direction = Vector2.RIGHT


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= LIFETIME:
		queue_free()
		return

	position += _direction * MOVE_DISTANCE / LIFETIME * delta
	modulate.a = 1.0 - _elapsed / LIFETIME


func _draw() -> void:
	var text := _text
	var font := ThemeDB.fallback_font
	var text_size := font.get_string_size(
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		FONT_SIZE
	)
	var text_position := Vector2(-text_size.x * 0.5, text_size.y * 0.35)
	draw_string_outline(
		font,
		text_position,
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		FONT_SIZE,
		4,
		OUTLINE_COLOR
	)
	draw_string(
		font,
		text_position,
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		FONT_SIZE,
		TEXT_COLOR
	)
