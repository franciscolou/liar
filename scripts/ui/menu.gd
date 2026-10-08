extends Control
## Title screen. The artwork fills the screen and keeps its right side dark and
## empty; the buttons are a column of plates stacked there.

const HelpPanel := preload("res://scripts/ui/help_panel.gd")
# The plates, in the wood and brass of the room in the artwork.
const PLATE := Color("21130c", 0.9)
const PLATE_BORDER := Color("86603a")
const PLATE_INK := Color("e8dcb8")
# The column: where it starts, how wide it is and the gap between plates.
const COLUMN := Vector2(794, 232)
const WIDTH := 270.0
const GAP := 12.0
const MAIN_HEIGHT := 70.0
const HEIGHT := 50.0


func _ready() -> void:
	Settings.ensure_loaded()
	theme = UI.theme()
	var y := COLUMN.y
	y = _plate("PLAY", y, MAIN_HEIGHT, 40,
			func(): get_tree().change_scene_to_file("res://scenes/room.tscn"))
	y = _plate("HOW TO PLAY", y, HEIGHT, 24, func(): add_child(HelpPanel.new()))
	y = _plate("SETTINGS", y, HEIGHT, 24, func(): add_child(SettingsPanel.new()))
	_plate("QUIT", y, HEIGHT, 24, func(): get_tree().quit())


## Adds one plate of the column at `y` and returns where the next one goes.
func _plate(text: String, y: float, height: float, font_size: int, action: Callable) -> float:
	var b := Button.new()
	b.text = text
	b.position = Vector2(COLUMN.x, y)
	b.size = Vector2(WIDTH, height)
	b.add_theme_font_size_override("font_size", roundi(font_size * UI.FONT_SCALE))
	b.add_theme_color_override("font_color", PLATE_INK)
	b.add_theme_stylebox_override("normal", UI.box(PLATE, PLATE_BORDER, 3, 4, 0))
	b.add_theme_stylebox_override("hover", UI.box(PLATE.lightened(0.1), UI.GOLD, 3, 4, 0))
	b.add_theme_stylebox_override("pressed", UI.box(PLATE.darkened(0.3), UI.GOLD, 3, 4, 0))
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UI.juice(b, 1.04)
	b.pressed.connect(action)
	add_child(b)
	return y + height + GAP


func _unhandled_key_input(event: InputEvent) -> void:
	UI.handle_fullscreen_key(event, get_window())
