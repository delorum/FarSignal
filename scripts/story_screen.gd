extends Control

signal continued
signal choice_selected(choice_id: String)

@onready var title: Label = $Background/Center/Panel/Title
@onready var text: Label = $Background/Center/Panel/Text
@onready var continue_button: Button = $Background/Center/Panel/ContinueButton
@onready var choice_buttons: HBoxContainer = $Background/Center/Panel/ChoiceButtons
@onready var first_choice_button: Button = $Background/Center/Panel/ChoiceButtons/FirstChoiceButton
@onready var second_choice_button: Button = $Background/Center/Panel/ChoiceButtons/SecondChoiceButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func open(screen_title: String, screen_text: String) -> void:
	title.text = screen_title
	text.text = screen_text
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	continue_button.grab_focus()
	continue_button.visible = true
	choice_buttons.visible = false


func open_choice(
	screen_title: String,
	screen_text: String,
	first_choice: String,
	second_choice: String
) -> void:
	open(screen_title, screen_text)
	continue_button.visible = false
	choice_buttons.visible = true
	first_choice_button.text = first_choice
	second_choice_button.text = second_choice
	first_choice_button.grab_focus()


func _on_continue_pressed() -> void:
	visible = false
	continued.emit()


func _on_first_choice_pressed() -> void:
	visible = false
	choice_selected.emit("leave")


func _on_second_choice_pressed() -> void:
	visible = false
	choice_selected.emit("community")
