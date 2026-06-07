extends CharacterBody2D
class_name Player

@export var speed := 230.0

const BODY_COLOR := Color("58d6f5")
const DIRECTION_COLOR := Color("e8fbff")

var controls_enabled := true
var _facing := Vector2.RIGHT


func _physics_process(_delta: float) -> void:
	var input_direction := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)
	input_direction += Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	input_direction = input_direction.limit_length()

	if not controls_enabled:
		input_direction = Vector2.ZERO

	velocity = input_direction * speed
	if not input_direction.is_zero_approx():
		_facing = input_direction.normalized()
		queue_redraw()

	move_and_slide()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 14.0, BODY_COLOR)
	draw_circle(Vector2.ZERO, 14.0, DIRECTION_COLOR, false, 2.0, true)
	draw_line(Vector2.ZERO, _facing * 11.0, DIRECTION_COLOR, 3.0, true)
