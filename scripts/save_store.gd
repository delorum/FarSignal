extends Node

const SAVE_FILE_NAME := "far_signal_save.json"
const SAVE_VERSION := 2

var pending_save: Dictionary = {}


func save_file_path() -> String:
	var game_directory := OS.get_executable_path().get_base_dir()
	if OS.has_feature("editor"):
		game_directory = ProjectSettings.globalize_path("res://")
	return game_directory.path_join(SAVE_FILE_NAME)


func has_save() -> bool:
	return FileAccess.file_exists(save_file_path())


func has_loadable_save() -> bool:
	return has_save() and not _read_save(false).is_empty()


func write_save(save_data: Dictionary) -> bool:
	var save_path := save_file_path()
	var save_file := FileAccess.open(save_path, FileAccess.WRITE)
	if save_file == null:
		push_error(
			"Could not write save file %s: %s"
			% [save_path, error_string(FileAccess.get_open_error())]
		)
		return false

	save_file.store_string(JSON.stringify(save_data, "\t"))
	save_file.close()
	return true


func read_save() -> Dictionary:
	return _read_save(true)


func _read_save(report_error: bool) -> Dictionary:
	var save_file := FileAccess.open(save_file_path(), FileAccess.READ)
	if save_file == null:
		return {}

	var parsed_data = JSON.parse_string(save_file.get_as_text())
	if not _is_valid_save(parsed_data):
		if report_error:
			push_error("Save file is invalid or uses an unsupported version")
		return {}

	return parsed_data


func delete_save() -> bool:
	pending_save.clear()
	if not has_save():
		return true

	var error := DirAccess.remove_absolute(save_file_path())
	if error != OK:
		push_error("Could not delete save file: %s" % error_string(error))
		return false
	return true


func request_load(save_data: Dictionary) -> void:
	pending_save = save_data.duplicate(true)


func consume_pending_save() -> Dictionary:
	var save_data := pending_save
	pending_save = {}
	return save_data


func _is_valid_save(save_data) -> bool:
	if not save_data is Dictionary:
		return false
	if int(save_data.get("version", 0)) != SAVE_VERSION:
		return false
	if not save_data.has("maze_seed"):
		return false

	var maze_size = save_data.get("maze_size")
	var position = save_data.get("player_position")
	var facing = save_data.get("player_facing")
	var explored = save_data.get("explored_cells")
	var configured_size := Maze.configured_grid_size()
	return maze_size is Array and maze_size.size() == 2 \
			and int(maze_size[0]) == configured_size.x \
			and int(maze_size[1]) == configured_size.y \
			and position is Array and position.size() == 2 \
			and facing is Array and facing.size() == 2 \
			and explored is Array
