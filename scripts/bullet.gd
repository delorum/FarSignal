extends CharacterBody2D

const SPEED := 500.0
const BULLET_COLOR := Color("f2f5f7")
const MAX_LIFETIME := 5.0

var direction := Vector2.RIGHT
var maze: Maze
var damage := 0
var _lifetime := 0.0


func setup(
	start_position: Vector2,
	shot_direction: Vector2,
	maze_node: Maze,
	shot_damage: int,
	from_player: bool
) -> void:
	position = start_position
	direction = shot_direction.normalized()
	maze = maze_node
	damage = shot_damage
	rotation = direction.angle()
	collision_mask = 1 | (4 if from_player else 2)


func _physics_process(delta: float) -> void:
	_lifetime += delta
	if _lifetime >= MAX_LIFETIME:
		queue_free()
		return

	var collision := move_and_collide(direction * SPEED * delta)
	if collision != null:
		var collider := collision.get_collider()
		if collider != null and collider.has_method("take_damage"):
			collider.take_damage(damage)
		queue_free()
		return

	if maze != null and maze.is_wall(maze.world_to_cell(position)):
		queue_free()


func _draw() -> void:
	draw_rect(Rect2(-6.0, -2.0, 12.0, 4.0), BULLET_COLOR)
