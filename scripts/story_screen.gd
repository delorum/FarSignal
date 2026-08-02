extends Control

signal continued

@onready var title: Label = $Background/Center/Panel/Title
@onready var text: Label = $Background/Center/Panel/Text
@onready var continue_button: Button = $Background/Center/Panel/ContinueButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func open(screen_title: String, screen_text: String) -> void:
	title.text = screen_title
	text.text = screen_text
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	continue_button.grab_focus()


func _on_continue_pressed() -> void:
	visible = false
	continued.emit()
