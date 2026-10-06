extends Control
## Shown when the match ends: who took the crown, play again or leave.

# The look of the plates painted on the artwork.
const PLATE := Color("1d0a08")
const PLATE_BORDER := Color("4a1c16")
const PLATE_INK := Color("d9935c")

@onready var again_button: Button = $Again
@onready var back_button: Button = $Back


func _ready() -> void:
	Settings.ensure_loaded()
	theme = UI.theme()
	var winner := GameConfig.last_winner
	$Label.text = Loc.t("%s now holds\nCarcaj's crown.") % winner if winner != "" else Loc.t("Nobody is left\nto take the crown.")
	$Label.add_theme_color_override("font_color", UI.GOLD)
	$Label.add_theme_font_override("font", UI.bold())
	$Label.add_theme_font_size_override("font_size", 40)
	UI.art_button(again_button, "PLAY AGAIN", PLATE, PLATE_BORDER, PLATE_INK, 30)
	UI.art_button(back_button, "QUIT", PLATE, PLATE_BORDER, PLATE_INK, 30)
	for b: Button in [again_button, back_button]:
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		UI.juice(b, 1.04)
	again_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/menu.tscn"))


func _unhandled_key_input(event: InputEvent) -> void:
	UI.handle_fullscreen_key(event, get_window())
