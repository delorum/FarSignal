extends Node2D

const CONNECTION_COLOR := Color(1.0, 0.82, 0.18, 0.38)
const CONNECTION_WIDTH := 3.0

var _game: Node


func _ready() -> void:
	_game = get_parent()


func _draw() -> void:
	if _game == null or not _game.has_method("tower_connection_segments"):
		return
	for segment: PackedVector2Array in _game.tower_connection_segments():
		if segment.size() != 2:
			continue
		draw_line(
			to_local(segment[0]),
			to_local(segment[1]),
			CONNECTION_COLOR,
			CONNECTION_WIDTH,
			true
		)
