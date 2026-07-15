extends Control

signal back_requested

@onready var settings_screen: VBoxContainer = $SettingsScreen
@onready var audio_screen: VBoxContainer = $AudioScreen
@onready var audio_button: Button = $SettingsScreen/AudioButton
@onready var debug_info_enabled: CheckButton = $SettingsScreen/DebugInfoEnabled
@onready var language_selector: OptionButton = $SettingsScreen/LanguageRow/LanguageSelector
@onready var music_enabled: CheckButton = $AudioScreen/MusicEnabled
@onready var sounds_enabled: CheckButton = $AudioScreen/SoundsEnabled
@onready var music_volume: HSlider = $AudioScreen/MusicVolumeRow/MusicVolume
@onready var sounds_volume: HSlider = $AudioScreen/SoundsVolumeRow/SoundsVolume
@onready var music_volume_value: Label = $AudioScreen/MusicVolumeRow/Value
@onready var sounds_volume_value: Label = $AudioScreen/SoundsVolumeRow/Value

var _syncing := false


func _ready() -> void:
	language_selector.add_item("Русский")
	language_selector.add_item("English")


func open() -> void:
	visible = true
	_sync_debug_control()
	_sync_language_control()
	_show_settings_screen()


func close_submenu() -> bool:
	if audio_screen.visible:
		_show_settings_screen()
		return true
	return false


func _on_audio_pressed() -> void:
	settings_screen.hide()
	audio_screen.show()
	_sync_controls()
	music_enabled.grab_focus()


func _on_settings_back_pressed() -> void:
	back_requested.emit()


func _on_audio_back_pressed() -> void:
	_show_settings_screen()


func _on_debug_info_enabled_toggled(enabled: bool) -> void:
	if not _syncing:
		PerformanceOverlay.set_debug_info_enabled(enabled)


func _on_language_selected(index: int) -> void:
	if not _syncing:
		Localization.set_locale(Localization.SUPPORTED_LOCALES[index])


func _on_music_enabled_toggled(enabled: bool) -> void:
	if not _syncing:
		AudioManager.set_music_enabled(enabled)


func _on_sounds_enabled_toggled(enabled: bool) -> void:
	if not _syncing:
		AudioManager.set_sounds_enabled(enabled)


func _on_music_volume_changed(value: float) -> void:
	music_volume_value.text = "%d%%" % roundi(value)
	if not _syncing:
		AudioManager.set_music_volume(value)


func _on_sounds_volume_changed(value: float) -> void:
	sounds_volume_value.text = "%d%%" % roundi(value)
	if not _syncing:
		AudioManager.set_sounds_volume(value)


func _show_settings_screen() -> void:
	audio_screen.hide()
	settings_screen.show()
	audio_button.grab_focus()


func _sync_controls() -> void:
	_syncing = true
	music_enabled.button_pressed = AudioManager.music_enabled
	sounds_enabled.button_pressed = AudioManager.sounds_enabled
	music_volume.value = AudioManager.music_volume
	sounds_volume.value = AudioManager.sounds_volume
	music_volume_value.text = "%d%%" % roundi(AudioManager.music_volume)
	sounds_volume_value.text = "%d%%" % roundi(AudioManager.sounds_volume)
	_syncing = false


func _sync_debug_control() -> void:
	_syncing = true
	debug_info_enabled.button_pressed = PerformanceOverlay.debug_info_enabled
	_syncing = false


func _sync_language_control() -> void:
	_syncing = true
	language_selector.select(Localization.locale_index())
	_syncing = false
