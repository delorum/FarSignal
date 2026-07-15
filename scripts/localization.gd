extends Node

signal language_changed

const SETTINGS_PATH := "user://far_signal_settings.cfg"
const SUPPORTED_LOCALES: Array[String] = ["ru", "en"]
const DEFAULT_LOCALE := "ru"
const SOURCE_TEXT_META := &"localization_source_text"

var locale := DEFAULT_LOCALE


func _ready() -> void:
	locale = _load_locale()
	TranslationServer.set_locale(locale)
	get_tree().node_added.connect(_on_node_added)
	localize_tree(get_tree().root)


func set_locale(value: String) -> void:
	var normalized := value.to_lower()
	if not SUPPORTED_LOCALES.has(normalized) or locale == normalized:
		return
	locale = normalized
	TranslationServer.set_locale(locale)
	localize_tree(get_tree().root)
	_save_locale()
	language_changed.emit()


func locale_index() -> int:
	return maxi(0, SUPPORTED_LOCALES.find(locale))


func localize_tree(root: Node) -> void:
	_localize_text_node(root)
	for child: Node in root.get_children():
		localize_tree(child)


func _on_node_added(node: Node) -> void:
	_localize_text_node.call_deferred(node)


func _localize_text_node(node: Node) -> void:
	if not is_instance_valid(node) \
			or node is OptionButton \
			or not (node is Label or node is BaseButton):
		return
	if not node.has_meta(SOURCE_TEXT_META):
		node.set_meta(SOURCE_TEXT_META, str(node.get("text")))
	var source_text := str(node.get_meta(SOURCE_TEXT_META, ""))
	node.set("text", TranslationServer.translate(source_text))


func _load_locale() -> String:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return DEFAULT_LOCALE
	var saved_locale := str(
		config.get_value("localization", "locale", DEFAULT_LOCALE)
	).to_lower()
	return saved_locale if SUPPORTED_LOCALES.has(saved_locale) else DEFAULT_LOCALE


func _save_locale() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("localization", "locale", locale)
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_error("Could not save language setting: %s" % error_string(error))
