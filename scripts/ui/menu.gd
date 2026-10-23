extends Control
## Title screen. The artwork (the Scene node, the painting come alive) fills the
## screen and keeps its right side dark and empty; the buttons are a column of
## plates stacked there.

const HelpPanel := preload("res://scripts/ui/help_panel.gd")
const Jukebox := preload("res://scripts/ui/jukebox.gd")
const Transition := preload("res://scripts/ui/transition.gd")
const MatchServer := preload("res://scripts/net/match_server.gd")
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
## The same column under a finger: taller plates, for a thumb and for the
## bigger text, starting higher so it still ends above the floor.
const TOUCH_COLUMN := Vector2(774, 168)
const TOUCH_WIDTH := 310.0
const TOUCH_MAIN_HEIGHT := 86.0
const TOUCH_HEIGHT := 66.0


func _ready() -> void:
	# Started by the house as a ranked table: no menu, no window to speak of.
	if MatchServer.wanted():
		get_tree().change_scene_to_file.call_deferred("res://scenes/server.tscn")
		return
	Settings.ensure_loaded()
	theme = UI.theme()
	Jukebox.play(Jukebox.LOBBY)
	$TextureRect.texture = $Scene.get_texture()
	var main := TOUCH_MAIN_HEIGHT if UI.touch else MAIN_HEIGHT
	var height := TOUCH_HEIGHT if UI.touch else HEIGHT
	var y := (TOUCH_COLUMN if UI.touch else COLUMN).y
	y = _plate("PLAY", y, main, 40,
			func(): Transition.go("res://scenes/room.tscn", Transition.DOORS))
	y = _plate("HOW TO PLAY", y, height, 24, func(): add_child(HelpPanel.new()))
	y = _plate("SETTINGS", y, height, 24, func(): add_child(SettingsPanel.new()))
	_plate("QUIT", y, height, 24, func(): get_tree().quit())


## Adds one plate of the column at `y` and returns where the next one goes.
func _plate(text: String, y: float, height: float, font_size: int, action: Callable) -> float:
	var b := Button.new()
	b.text = text
	b.position = Vector2((TOUCH_COLUMN if UI.touch else COLUMN).x, y)
	b.size = Vector2(TOUCH_WIDTH if UI.touch else WIDTH, height)
	b.add_theme_font_size_override("font_size", UI.px(font_size))
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
