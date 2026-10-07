extends Control
## Title screen. The buttons are painted on the artwork; the real ones sit
## on top of them and only draw a highlight.

const HelpPanel := preload("res://scripts/ui/help_panel.gd")
# The look of the plates painted on the artwork.
const PLATE := Color("3b2a20")
const PLATE_BORDER := Color("86705a")
const PLATE_INK := Color("e8dcb8")

@onready var play_button: Button = $Play
@onready var quit_button: Button = $Quit


func _ready() -> void:
	Settings.ensure_loaded()
	theme = UI.theme()
	for b: Button in [play_button, quit_button]:
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		UI.juice(b, 1.04)
	_relabel()
	play_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/setup.tscn"))
	quit_button.pressed.connect(func(): get_tree().quit())
	var settings := UI.button("SETTINGS", UI.BORDER, 16)
	settings.position = Vector2(1000, 12)
	settings.size = Vector2(140, 38)
	settings.pressed.connect(func(): add_child(SettingsPanel.new()))
	add_child(settings)
	var help := UI.button("HOW TO PLAY", UI.BORDER, 16)
	help.position = Vector2(836, 12)
	help.size = Vector2(154, 38)
	help.pressed.connect(func(): add_child(HelpPanel.new()))
	add_child(help)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_relabel()


func _relabel() -> void:
	UI.art_button(play_button, "PLAY", PLATE, PLATE_BORDER, PLATE_INK, 40)
	UI.art_button(quit_button, "QUIT", PLATE, PLATE_BORDER, PLATE_INK, 40)


func _unhandled_key_input(event: InputEvent) -> void:
	UI.handle_fullscreen_key(event, get_window())
