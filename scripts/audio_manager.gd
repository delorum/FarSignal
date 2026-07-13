extends Node

const SAMPLE_RATE := 22050
const MUSIC_FADE_DURATION := 1.5
const MUSIC_VOLUME_DB := -8.0
const SILENT_VOLUME_DB := -60.0
const SETTINGS_PATH := "user://far_signal_settings.cfg"
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
const PLAYER_SHOT_PATH := "res://assets/audio/sfx/player_shot.ogg"
const ENEMY_SHOT_PATH := "res://assets/audio/sfx/enemy_shot.ogg"
const DOOR_OPEN_PATH := "res://assets/audio/sfx/door_open.ogg"
const DOOR_CLOSE_PATH := "res://assets/audio/sfx/door_close.ogg"

var music_enabled := true
var sounds_enabled := true
var music_volume := 80.0
var sounds_volume := 100.0

var _ambient_player: AudioStreamPlayer
var _combat_player: AudioStreamPlayer
var _combat_active := false
var _music_tween: Tween
var _rng := RandomNumberGenerator.new()
var _player_shot_stream: AudioStream
var _enemy_shot_stream: AudioStream
var _door_place_stream: AudioStream
var _door_remove_stream: AudioStream
var _door_open_stream: AudioStream
var _door_close_stream: AudioStream


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_create_audio_bus(MUSIC_BUS)
	_create_audio_bus(SFX_BUS)
	_load_settings()
	_ambient_player = _create_player("AmbientMusic")
	_combat_player = _create_player("CombatMusic")
	_ambient_player.bus = MUSIC_BUS
	_combat_player.bus = MUSIC_BUS
	_ambient_player.stream = _create_ambient_stream(false)
	_combat_player.stream = _create_ambient_stream(true)
	_player_shot_stream = load(PLAYER_SHOT_PATH)
	_enemy_shot_stream = load(ENEMY_SHOT_PATH)
	_door_place_stream = _create_door_stream(1.0, true)
	_door_remove_stream = _create_door_stream(0.72, false)
	_door_open_stream = load(DOOR_OPEN_PATH)
	_door_close_stream = load(DOOR_CLOSE_PATH)
	_ambient_player.volume_db = MUSIC_VOLUME_DB
	_combat_player.volume_db = SILENT_VOLUME_DB
	_ambient_player.play()
	_combat_player.play()
	_apply_bus_settings()


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
	if _music_tween != null:
		_music_tween.kill()
	_music_tween = create_tween().set_parallel(true)
	_music_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_music_tween.tween_property(
		_ambient_player,
		"volume_db",
		SILENT_VOLUME_DB if active else MUSIC_VOLUME_DB,
		MUSIC_FADE_DURATION
	)
	_music_tween.tween_property(
		_combat_player,
		"volume_db",
		MUSIC_VOLUME_DB if active else SILENT_VOLUME_DB,
		MUSIC_FADE_DURATION
	)


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


func _create_player(player_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	add_child(player)
	return player


func _play_effect(stream: AudioStream, volume_db: float) -> void:
	# A fresh player lets overlapping shots and door sounds finish independently.
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
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
