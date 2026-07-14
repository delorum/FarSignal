extends Node

const SAMPLE_RATE := 22050
const MUSIC_FADE_DURATION := 1.5
const EXPLORATION_CROSSFADE_DURATION := 4.0
const UI_MENU_CONFIRM_DURATION := 0.3
const MUSIC_VOLUME_DB := -8.0
const MENU_MUSIC_VOLUME_DB := -3.0
const SILENT_VOLUME_DB := -60.0
const SETTINGS_PATH := "user://far_signal_settings.cfg"
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
const MENU_MUSIC_PATH := "res://assets/audio/music_menu_soft_loop.ogg"
const VICTORY_MUSIC_PATH := "res://assets/audio/music_victory_corpo_coffee.ogg"
const DEFEAT_MUSIC_PATH := "res://assets/audio/music_defeat_corpo_nostalgia.ogg"
const EXPLORATION_MUSIC_PATHS := [
	"res://assets/audio/exploration_pondering_cosmos.ogg",
	"res://assets/audio/exploration_synthwave_2.ogg",
	"res://assets/audio/exploration_synthwave_5.ogg",
	"res://assets/audio/exploration_synthwave_7.ogg",
]
const COMBAT_MUSIC_PATHS := [
	"res://assets/audio/combat_corpo_user_fight.ogg",
	"res://assets/audio/combat_battle_1.ogg",
	"res://assets/audio/combat_battle_2.ogg",
]
const PLAYER_SHOT_PATH := "res://assets/audio/sfx/player_shot.ogg"
const ENEMY_SHOT_PATH := "res://assets/audio/sfx/enemy_shot.ogg"
const DOOR_OPEN_PATH := "res://assets/audio/sfx/door_open.ogg"
const DOOR_CLOSE_PATH := "res://assets/audio/sfx/door_close.ogg"
const DOOR_ERROR_PATH := "res://assets/audio/sfx/door_error.ogg"
const MEGA_CORE_PICKUP_PATH := "res://assets/audio/sfx/mega_core_pickup.ogg"
const UI_CURSOR_PATH := "res://assets/audio/sfx/ui_cursor.ogg"
const UI_CONFIRMATION_PATH := "res://assets/audio/sfx/ui_confirmation.ogg"
const UI_MENU_CONFIRM_PATH := "res://assets/audio/sfx/ui_menu_confirm.ogg"
const MAP_MARKER_REMOVE_PATH := "res://assets/audio/sfx/map_marker_remove.ogg"
const USE_KENNEY_STATION_SOUNDS := false
const STATION_OPEN_PATH := (
	"res://assets/audio/sfx/station_open_kenney.ogg"
	if USE_KENNEY_STATION_SOUNDS
	else "res://assets/audio/sfx/station_open_jrpg.ogg"
)
const STATION_CLOSE_PATH := (
	"res://assets/audio/sfx/station_close_kenney.ogg"
	if USE_KENNEY_STATION_SOUNDS
	else "res://assets/audio/sfx/station_close_jrpg.ogg"
)
const PLAYER_FOOTSTEP_19_PATHS := [
	"res://assets/audio/sfx/player_footstep.ogg",
]
const DULL_PLAYER_FOOTSTEP_PATHS := [
	"res://assets/audio/sfx/player_footstep_02.ogg",
	"res://assets/audio/sfx/player_footstep_05.ogg",
	"res://assets/audio/sfx/player_footstep_14.ogg",
	"res://assets/audio/sfx/player_footstep.ogg",
]
const PLAYER_FOOTSTEP_PATHS := PLAYER_FOOTSTEP_19_PATHS

var music_enabled := true
var sounds_enabled := true
var music_volume := 80.0
var sounds_volume := 100.0

var _exploration_players: Array[AudioStreamPlayer] = []
var _exploration_streams: Array[AudioStream] = []
var _active_exploration_player := 0
var _last_exploration_track := -1
var _exploration_track_time_left := 0.0
var _combat_players: Array[AudioStreamPlayer] = []
var _combat_streams: Array[AudioStream] = []
var _active_combat_player := 0
var _last_combat_track := -1
var _combat_track_time_left := 0.0
var _menu_music_player: AudioStreamPlayer
var _ending_music_player: AudioStreamPlayer
var _victory_music_stream: AudioStreamOggVorbis
var _defeat_music_stream: AudioStreamOggVorbis
var _combat_active := false
var _menu_music_active := false
var _ending_music_active := false
var _music_tween: Tween
var _rng := RandomNumberGenerator.new()
var _player_shot_stream: AudioStream
var _enemy_shot_stream: AudioStream
var _door_place_stream: AudioStream
var _door_remove_stream: AudioStream
var _door_open_stream: AudioStream
var _door_close_stream: AudioStream
var _door_error_stream: AudioStream
var _mega_core_pickup_stream: AudioStream
var _ui_cursor_stream: AudioStream
var _ui_confirmation_stream: AudioStream
var _ui_menu_confirm_stream: AudioStream
var _map_marker_remove_stream: AudioStream
var _station_open_stream: AudioStream
var _station_close_stream: AudioStream
var _player_footstep_streams: Array[AudioStream] = []
var _last_footstep_index := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_create_audio_bus(MUSIC_BUS)
	_create_audio_bus(SFX_BUS)
	_load_settings()
	_exploration_players = [
		_create_player("ExplorationMusicA"),
		_create_player("ExplorationMusicB"),
	]
	_combat_players = [
		_create_player("CombatMusicA"),
		_create_player("CombatMusicB"),
	]
	_menu_music_player = _create_player("MenuMusic")
	_ending_music_player = _create_player("EndingMusic")
	for player: AudioStreamPlayer in _exploration_players:
		player.bus = MUSIC_BUS
	for player: AudioStreamPlayer in _combat_players:
		player.bus = MUSIC_BUS
	_menu_music_player.bus = MUSIC_BUS
	_ending_music_player.bus = MUSIC_BUS
	for path: String in EXPLORATION_MUSIC_PATHS:
		var stream: AudioStreamOggVorbis = load(path)
		stream.loop = false
		_exploration_streams.append(stream)
	for path: String in COMBAT_MUSIC_PATHS:
		var stream: AudioStreamOggVorbis = load(path)
		stream.loop = false
		_combat_streams.append(stream)
	var menu_music_stream: AudioStreamOggVorbis = load(MENU_MUSIC_PATH)
	menu_music_stream.loop = true
	_menu_music_player.stream = menu_music_stream
	_victory_music_stream = load(VICTORY_MUSIC_PATH)
	_victory_music_stream.loop = true
	_defeat_music_stream = load(DEFEAT_MUSIC_PATH)
	_defeat_music_stream.loop = true
	_player_shot_stream = load(PLAYER_SHOT_PATH)
	_enemy_shot_stream = load(ENEMY_SHOT_PATH)
	_door_place_stream = _create_door_stream(1.0, true)
	_door_remove_stream = _create_door_stream(0.72, false)
	_door_open_stream = load(DOOR_OPEN_PATH)
	_door_close_stream = load(DOOR_CLOSE_PATH)
	_door_error_stream = load(DOOR_ERROR_PATH)
	_mega_core_pickup_stream = load(MEGA_CORE_PICKUP_PATH)
	_ui_cursor_stream = load(UI_CURSOR_PATH)
	_ui_confirmation_stream = load(UI_CONFIRMATION_PATH)
	_ui_menu_confirm_stream = load(UI_MENU_CONFIRM_PATH)
	_map_marker_remove_stream = load(MAP_MARKER_REMOVE_PATH)
	_station_open_stream = load(STATION_OPEN_PATH)
	_station_close_stream = load(STATION_CLOSE_PATH)
	for path: String in PLAYER_FOOTSTEP_PATHS:
		_player_footstep_streams.append(load(path))
	get_tree().node_added.connect(_on_node_added)
	_register_ui_buttons(get_tree().root)
	_start_initial_exploration_track()
	for player: AudioStreamPlayer in _combat_players:
		player.volume_db = SILENT_VOLUME_DB
	_menu_music_player.volume_db = SILENT_VOLUME_DB
	_menu_music_player.play()
	_ending_music_player.volume_db = SILENT_VOLUME_DB
	_update_player_pause_states()
	_apply_bus_settings()


func _process(delta: float) -> void:
	if _menu_music_active or _ending_music_active:
		return
	if _combat_active:
		_combat_track_time_left -= delta
		if _combat_track_time_left <= EXPLORATION_CROSSFADE_DURATION:
			_start_next_combat_track()
	else:
		_exploration_track_time_left -= delta
		if _exploration_track_time_left <= EXPLORATION_CROSSFADE_DURATION:
			_start_next_exploration_track()


func set_music_enabled(enabled: bool) -> void:
	music_enabled = enabled
	_apply_bus_settings()
	_save_settings()


func set_sounds_enabled(enabled: bool) -> void:
	sounds_enabled = enabled
	_apply_bus_settings()
	_save_settings()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 100.0)
	_apply_bus_settings()
	_save_settings()


func set_sounds_volume(value: float) -> void:
	sounds_volume = clampf(value, 0.0, 100.0)
	_apply_bus_settings()
	_save_settings()


func set_combat_active(active: bool) -> void:
	if _combat_active == active:
		return
	_combat_active = active
	if active:
		_start_combat_encounter_track()
	_update_player_pause_states()
	_update_music_mix()


func set_menu_music_active(active: bool) -> void:
	if active and _ending_music_active:
		_ending_music_active = false
		_ending_music_player.stop()
	if _menu_music_active == active:
		return
	_menu_music_active = active
	_update_player_pause_states()
	_update_music_mix()


func play_victory_music() -> void:
	_play_ending_music(_victory_music_stream)


func play_defeat_music() -> void:
	_play_ending_music(_defeat_music_stream)


func _play_ending_music(stream: AudioStreamOggVorbis) -> void:
	_combat_active = false
	_menu_music_active = false
	_ending_music_active = true
	_ending_music_player.stream = stream
	_ending_music_player.volume_db = SILENT_VOLUME_DB
	_ending_music_player.play()
	_update_player_pause_states()
	_update_music_mix()


func _update_music_mix() -> void:
	if _music_tween != null:
		_music_tween.kill()
	_music_tween = create_tween().set_parallel(true)
	_music_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	for index: int in _exploration_players.size():
		_music_tween.tween_property(
			_exploration_players[index],
			"volume_db",
			MUSIC_VOLUME_DB
			if index == _active_exploration_player \
				and not _menu_music_active \
				and not _combat_active \
				and not _ending_music_active
			else SILENT_VOLUME_DB,
			MUSIC_FADE_DURATION
		)
	for index: int in _combat_players.size():
		_music_tween.tween_property(
			_combat_players[index],
			"volume_db",
			MUSIC_VOLUME_DB
			if index == _active_combat_player \
				and not _menu_music_active \
				and _combat_active \
				and not _ending_music_active
			else SILENT_VOLUME_DB,
			MUSIC_FADE_DURATION
		)
	_music_tween.tween_property(
		_menu_music_player,
		"volume_db",
		MENU_MUSIC_VOLUME_DB if _menu_music_active else SILENT_VOLUME_DB,
		MUSIC_FADE_DURATION
	)
	_music_tween.tween_property(
		_ending_music_player,
		"volume_db",
		MUSIC_VOLUME_DB if _ending_music_active else SILENT_VOLUME_DB,
		MUSIC_FADE_DURATION
	)


func _start_initial_exploration_track() -> void:
	var track_index := _next_exploration_track_index()
	_last_exploration_track = track_index
	var player := _exploration_players[_active_exploration_player]
	player.stream = _exploration_streams[track_index]
	player.volume_db = MUSIC_VOLUME_DB
	player.play()
	_exploration_track_time_left = player.stream.get_length()


func _start_next_exploration_track() -> void:
	var track_index := _next_exploration_track_index()
	var previous_player := _exploration_players[_active_exploration_player]
	_active_exploration_player = 1 - _active_exploration_player
	var next_player := _exploration_players[_active_exploration_player]
	next_player.stream = _exploration_streams[track_index]
	next_player.volume_db = SILENT_VOLUME_DB
	next_player.play()
	_last_exploration_track = track_index
	_exploration_track_time_left = next_player.stream.get_length()

	if _music_tween != null:
		_music_tween.kill()
	_music_tween = create_tween().set_parallel(true)
	_music_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_music_tween.tween_property(
		previous_player,
		"volume_db",
		SILENT_VOLUME_DB,
		EXPLORATION_CROSSFADE_DURATION
	)
	_music_tween.tween_property(
		next_player,
		"volume_db",
		MUSIC_VOLUME_DB
		if not _menu_music_active and not _combat_active
		else SILENT_VOLUME_DB,
		EXPLORATION_CROSSFADE_DURATION
	)


func _next_exploration_track_index() -> int:
	if _last_exploration_track < 0:
		return _rng.randi_range(0, _exploration_streams.size() - 1)

	var index := _rng.randi_range(0, _exploration_streams.size() - 2)
	if index >= _last_exploration_track:
		index += 1
	return index


func _start_combat_encounter_track() -> void:
	for player: AudioStreamPlayer in _combat_players:
		player.stop()
		player.volume_db = SILENT_VOLUME_DB
	_active_combat_player = 0
	var track_index := _next_combat_track_index()
	_last_combat_track = track_index
	var player := _combat_players[_active_combat_player]
	player.stream = _combat_streams[track_index]
	player.play()
	_combat_track_time_left = player.stream.get_length()


func _start_next_combat_track() -> void:
	var track_index := _next_combat_track_index()
	var previous_player := _combat_players[_active_combat_player]
	_active_combat_player = 1 - _active_combat_player
	var next_player := _combat_players[_active_combat_player]
	next_player.stream = _combat_streams[track_index]
	next_player.volume_db = SILENT_VOLUME_DB
	next_player.play()
	_last_combat_track = track_index
	_combat_track_time_left = next_player.stream.get_length()

	if _music_tween != null:
		_music_tween.kill()
	_music_tween = create_tween().set_parallel(true)
	_music_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_music_tween.tween_property(
		previous_player,
		"volume_db",
		SILENT_VOLUME_DB,
		EXPLORATION_CROSSFADE_DURATION
	)
	_music_tween.tween_property(
		next_player,
		"volume_db",
		MUSIC_VOLUME_DB,
		EXPLORATION_CROSSFADE_DURATION
	)


func _next_combat_track_index() -> int:
	if _last_combat_track < 0:
		return _rng.randi_range(0, _combat_streams.size() - 1)

	var index := _rng.randi_range(0, _combat_streams.size() - 2)
	if index >= _last_combat_track:
		index += 1
	return index


func _update_player_pause_states() -> void:
	var exploration_paused := (
		_menu_music_active or _combat_active or _ending_music_active
	)
	for player: AudioStreamPlayer in _exploration_players:
		player.stream_paused = exploration_paused
	var combat_paused := (
		_menu_music_active or not _combat_active or _ending_music_active
	)
	for player: AudioStreamPlayer in _combat_players:
		player.stream_paused = combat_paused


func play_player_shot() -> void:
	_play_effect(_player_shot_stream, -7.0)


func play_enemy_shot() -> void:
	_play_effect(_enemy_shot_stream, -9.0)


func play_door_place() -> void:
	_play_effect(_door_place_stream, -8.0)


func play_door_remove() -> void:
	_play_effect(_door_remove_stream, -9.0)


func play_door_open() -> void:
	_play_effect(_door_open_stream, -10.0)


func play_door_close() -> void:
	_play_effect(_door_close_stream, -8.0)


func play_door_error() -> void:
	_play_effect(_door_error_stream, -10.0)


func play_mega_core_pickup() -> void:
	_play_effect(_mega_core_pickup_stream, -6.0)


func play_player_footstep() -> void:
	var footstep_index := _next_footstep_index()
	_play_effect(
		_player_footstep_streams[footstep_index],
		_rng.randf_range(-14.0, -11.0),
		_rng.randf_range(0.97, 1.03)
	)
	_last_footstep_index = footstep_index


func play_station_open() -> void:
	_play_effect(_station_open_stream, -10.0)


func play_station_close() -> void:
	_play_effect(_station_close_stream, -10.0)


func play_menu_confirmation() -> void:
	_play_effect(_ui_menu_confirm_stream, -12.0)


func play_map_marker_remove() -> void:
	_play_effect(_map_marker_remove_stream, -12.0)


func wait_for_menu_confirmation() -> void:
	await get_tree().create_timer(
		UI_MENU_CONFIRM_DURATION,
		true,
		false,
		true
	).timeout


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		_register_ui_button(node)


func _register_ui_buttons(node: Node) -> void:
	if node is BaseButton:
		_register_ui_button(node)
	for child: Node in node.get_children():
		_register_ui_buttons(child)


func _register_ui_button(button: BaseButton) -> void:
	var hover_callback := _on_ui_button_mouse_entered.bind(button)
	if not button.mouse_entered.is_connected(hover_callback):
		button.mouse_entered.connect(hover_callback)
	var pressed_callback := _on_ui_button_pressed.bind(button)
	if not button.pressed.is_connected(pressed_callback):
		button.pressed.connect(pressed_callback)


func _on_ui_button_mouse_entered(button: BaseButton) -> void:
	if button.disabled or not button.is_visible_in_tree():
		return
	_play_effect(_ui_cursor_stream, -16.0)


func _on_ui_button_pressed(button: BaseButton) -> void:
	if _is_station_exit_button(button):
		return
	var stream := (
		_ui_confirmation_stream
		if _is_station_button(button)
		else _ui_menu_confirm_stream
	)
	_play_effect(stream, -12.0)


func _is_station_exit_button(button: BaseButton) -> bool:
	return button.name == &"ExitButton" and _is_station_button(button)


func _is_station_button(button: BaseButton) -> bool:
	var node: Node = button
	while node != null:
		if node.name == &"StationOverlay":
			return true
		node = node.get_parent()
	return false


func _next_footstep_index() -> int:
	if _player_footstep_streams.size() == 1:
		return 0
	if _last_footstep_index < 0:
		return _rng.randi_range(0, _player_footstep_streams.size() - 1)

	var index := _rng.randi_range(0, _player_footstep_streams.size() - 2)
	if index >= _last_footstep_index:
		index += 1
	return index


func _create_player(player_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	add_child(player)
	return player


func _play_effect(
	stream: AudioStream,
	volume_db: float,
	pitch_scale: float = 1.0
) -> void:
	# A fresh player lets overlapping shots and door sounds finish independently.
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.bus = SFX_BUS
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


func _create_audio_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)


func _apply_bus_settings() -> void:
	var music_bus_index := AudioServer.get_bus_index(MUSIC_BUS)
	var sfx_bus_index := AudioServer.get_bus_index(SFX_BUS)
	AudioServer.set_bus_mute(music_bus_index, not music_enabled)
	AudioServer.set_bus_mute(sfx_bus_index, not sounds_enabled)
	AudioServer.set_bus_volume_db(
		music_bus_index,
		linear_to_db(maxf(music_volume / 100.0, 0.0001))
	)
	AudioServer.set_bus_volume_db(
		sfx_bus_index,
		linear_to_db(maxf(sounds_volume / 100.0, 0.0001))
	)


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	music_enabled = bool(config.get_value("audio", "music_enabled", true))
	sounds_enabled = bool(config.get_value("audio", "sounds_enabled", true))
	music_volume = clampf(
		float(config.get_value("audio", "music_volume", 80.0)),
		0.0,
		100.0
	)
	sounds_volume = clampf(
		float(config.get_value("audio", "sounds_volume", 100.0)),
		0.0,
		100.0
	)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("audio", "music_enabled", music_enabled)
	config.set_value("audio", "sounds_enabled", sounds_enabled)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sounds_volume", sounds_volume)
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_error("Could not save audio settings: %s" % error_string(error))


func _create_ambient_stream(combat: bool) -> AudioStreamWAV:
	var duration := 12.0
	var sample_count := int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var phase_noise := 0.0
	for index in sample_count:
		var time := float(index) / SAMPLE_RATE
		phase_noise = lerpf(phase_noise, _rng.randf_range(-1.0, 1.0), 0.002)
		var drone := sin(TAU * 43.0 * time) * 0.18
		drone += sin(TAU * 64.5 * time + sin(time * 0.21)) * 0.1
		# Mid-range harmonics keep the ambience audible on small speakers.
		drone += sin(TAU * 172.0 * time + sin(time * 0.17)) * 0.11
		var distant_tone := sin(TAU * 258.0 * time) * (0.055 + 0.025 * sin(time * 0.7))
		distant_tone += sin(TAU * 344.0 * time + sin(time * 0.31)) * 0.035
		var value := drone + distant_tone + phase_noise * 0.035
		if combat:
			var pulse := pow(maxf(0.0, sin(TAU * 1.75 * time)), 7.0)
			value += pulse * sin(TAU * 86.0 * time) * 0.24
			value += sin(TAU * 516.0 * time + sin(time * 2.0)) * 0.065
		samples[index] = value
	return _samples_to_stream(samples, true)


func _create_blaster_stream(pitch: float) -> AudioStreamWAV:
	var duration := 0.22
	var sample_count := int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	for index in sample_count:
		var time := float(index) / SAMPLE_RATE
		var progress := time / duration
		var frequency := lerpf(980.0 * pitch, 180.0 * pitch, progress)
		var envelope := pow(1.0 - progress, 2.2)
		var noise := _rng.randf_range(-1.0, 1.0) * 0.16 * envelope
		samples[index] = (sin(TAU * frequency * time) * 0.75 + noise) * envelope
	return _samples_to_stream(samples)


func _create_door_stream(pitch: float, impact: bool) -> AudioStreamWAV:
	var duration := 0.28 if impact else 0.38
	var sample_count := int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	for index in sample_count:
		var time := float(index) / SAMPLE_RATE
		var progress := time / duration
		var scrape := _rng.randf_range(-1.0, 1.0) * (1.0 - progress) * 0.28
		var motor := sin(TAU * (72.0 * pitch + 25.0 * progress) * time) * 0.3
		var hit := 0.0
		if impact and progress > 0.72:
			hit = sin(TAU * 55.0 * time) * (1.0 - progress) * 1.1
		samples[index] = (scrape + motor + hit) * (1.0 - progress)
	return _samples_to_stream(samples)


func _samples_to_stream(
	samples: PackedFloat32Array,
	looped: bool = false
) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for index in samples.size():
		bytes.encode_s16(index * 2, int(clampf(samples[index], -1.0, 1.0) * 32767.0))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	if looped:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples.size()
	return stream
