extends CanvasLayer

const DISPLAY_UPDATE_SECONDS := 0.25
const PEAK_WINDOW_SECONDS := 5.0
const SETTINGS_PATH := "user://far_signal_settings.cfg"

var _label: Label
var debug_info_enabled := true
var _measurement_signals_connected := false
var _last_frame_ticks_usec := 0
var _display_elapsed := 0.0
var _peak_elapsed := 0.0
var _frame_time_ms := 0.0
var _peak_frame_time_ms := 0.0
var _logic_start_ticks_usec := 0
var _logic_time_ms := 0.0
var _peak_logic_time_ms := 0.0


func _ready() -> void:
	layer = 1000
	process_mode = Node.PROCESS_MODE_ALWAYS

	_label = Label.new()
	_label.position = Vector2(10.0, 8.0)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.97))
	_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	_label.add_theme_constant_override("outline_size", 4)
	add_child(_label)

	_load_setting()
	_apply_enabled_state()


func set_debug_info_enabled(enabled: bool) -> void:
	if debug_info_enabled == enabled:
		return
	debug_info_enabled = enabled
	_apply_enabled_state()
	_save_setting()


func _process(delta: float) -> void:
	var current_ticks_usec := Time.get_ticks_usec()
	_frame_time_ms = float(current_ticks_usec - _last_frame_ticks_usec) / 1000.0
	_last_frame_ticks_usec = current_ticks_usec
	_peak_frame_time_ms = maxf(_peak_frame_time_ms, _frame_time_ms)

	_display_elapsed += delta
	_peak_elapsed += delta
	if _display_elapsed >= DISPLAY_UPDATE_SECONDS:
		_display_elapsed = 0.0
		_update_text()
	if _peak_elapsed >= PEAK_WINDOW_SECONDS:
		_peak_elapsed = 0.0
		_peak_frame_time_ms = _frame_time_ms
		_peak_logic_time_ms = _logic_time_ms


func _on_logic_frame_started() -> void:
	# Preserve the first physics tick when Godot catches up with multiple ticks.
	if _logic_start_ticks_usec == 0:
		_logic_start_ticks_usec = Time.get_ticks_usec()


func _on_frame_pre_draw() -> void:
	if _logic_start_ticks_usec == 0:
		return
	_logic_time_ms = float(
		Time.get_ticks_usec() - _logic_start_ticks_usec
	) / 1000.0
	_peak_logic_time_ms = maxf(_peak_logic_time_ms, _logic_time_ms)
	_logic_start_ticks_usec = 0


func _update_text() -> void:
	var physics_time_ms := (
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	)
	var draw_calls := int(Performance.get_monitor(
		Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME
	))
	_label.text = (
		"FPS: %d\nКадр: %.1f мс\nПик (5 с): %.1f мс\n"
		+ "Логика: %.1f мс (пик %.1f)\n"
		+ "Физика: %.1f мс\nОтрисовка: %d выз."
	) % [
		Engine.get_frames_per_second(),
		_frame_time_ms,
		_peak_frame_time_ms,
		_logic_time_ms,
		_peak_logic_time_ms,
		physics_time_ms,
		draw_calls,
	]


func _apply_enabled_state() -> void:
	_label.visible = debug_info_enabled
	set_process(debug_info_enabled)
	if debug_info_enabled:
		_connect_measurement_signals()
		_reset_measurements()
		_update_text()
	else:
		_disconnect_measurement_signals()


func _connect_measurement_signals() -> void:
	if _measurement_signals_connected:
		return
	get_tree().physics_frame.connect(_on_logic_frame_started)
	get_tree().process_frame.connect(_on_logic_frame_started)
	RenderingServer.frame_pre_draw.connect(_on_frame_pre_draw)
	_measurement_signals_connected = true


func _disconnect_measurement_signals() -> void:
	if not _measurement_signals_connected:
		return
	get_tree().physics_frame.disconnect(_on_logic_frame_started)
	get_tree().process_frame.disconnect(_on_logic_frame_started)
	RenderingServer.frame_pre_draw.disconnect(_on_frame_pre_draw)
	_measurement_signals_connected = false


func _reset_measurements() -> void:
	_last_frame_ticks_usec = Time.get_ticks_usec()
	_display_elapsed = 0.0
	_peak_elapsed = 0.0
	_frame_time_ms = 0.0
	_peak_frame_time_ms = 0.0
	_logic_start_ticks_usec = 0
	_logic_time_ms = 0.0
	_peak_logic_time_ms = 0.0


func _load_setting() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	debug_info_enabled = bool(config.get_value(
		"debug",
		"performance_overlay_enabled",
		true
	))


func _save_setting() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(
		"debug",
		"performance_overlay_enabled",
		debug_info_enabled
	)
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_error("Could not save debug settings: %s" % error_string(error))
