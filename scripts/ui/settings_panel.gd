class_name SettingsPanel
extends ColorRect
## The settings overlay: music and sound volume, the language and fullscreen.
## Shared by every screen that has a menu; add it as a child and it covers the
## screen until closed. Its look is saloon_board.gd.

signal closed

const Board := preload("res://scripts/ui/saloon_board.gd")

const PREVIEW_SOUND := "res://assets/sounds/spend.mp3"

var _language_buttons: Dictionary = {}  # language code -> Button
var _fullscreen_buttons: Dictionary = {}  # on (bool) -> Button
var _fullscreen_shown := false
var _preview: AudioStreamPlayer


func _init() -> void:
	color = Color(0, 0, 0, 0.7)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 30
	theme = UI.theme()

	var panel := PanelContainer.new()
	Board.frame(panel, UI.BORDER, 24)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	box.add_child(Board.plaque("SETTINGS", 26))

	box.add_child(_volume_row("Music", Settings.music, func(v: float): Settings.set_music(v)))
	var sfx_row := _volume_row("Sound effects", Settings.sfx, func(v: float): Settings.set_sfx(v))
	# Lets the new volume be heard when the slider is let go.
	sfx_row.get_node("Slider").drag_ended.connect(func(_changed): _preview.play())
	box.add_child(sfx_row)

	var language_row := _row("Language")
	for code: String in Loc.LANGUAGES:
		var b := UI.button(Loc.LANGUAGES[code], UI.BORDER, 15)
		Board.plank(b)
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.custom_minimum_size = UI.grown(Vector2(124, 32))
		b.pressed.connect(_on_language_pressed.bind(code))
		language_row.add_child(b)
		_language_buttons[code] = b
	box.add_child(language_row)
	_restyle_languages()

	var fullscreen_row := _row("Fullscreen")
	for on: bool in [true, false]:
		var b := UI.button("On" if on else "Off", UI.BORDER, 15)
		Board.plank(b)
		b.custom_minimum_size = UI.grown(Vector2(124, 32))
		b.pressed.connect(_on_fullscreen_pressed.bind(on))
		fullscreen_row.add_child(b)
		_fullscreen_buttons[on] = b
	# A phone is always full screen.
	fullscreen_row.visible = not OS.has_feature("mobile")
	box.add_child(fullscreen_row)

	var back := UI.button("Back", UI.GOLD, 18)
	Board.plank(back, UI.GOLD)
	back.custom_minimum_size = UI.grown(Vector2(200, 42))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(close)
	box.add_child(back)

	_preview = AudioStreamPlayer.new()
	_preview.stream = load(PREVIEW_SOUND)
	_preview.bus = Settings.SFX_BUS
	add_child(_preview)


func close() -> void:
	Settings.save()
	closed.emit()
	queue_free()


func _ready() -> void:
	_restyle_fullscreen()


## F11 and Alt+Enter still work with the panel open.
func _process(_delta: float) -> void:
	if UI.is_fullscreen(get_window()) != _fullscreen_shown:
		_restyle_fullscreen()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _row(text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var l := UI.label(text, 18)
	l.custom_minimum_size = UI.grown(Vector2(170, 0))
	row.add_child(l)
	return row


func _volume_row(text: String, value: float, setter: Callable) -> HBoxContainer:
	var row := _row(text)
	var slider := HSlider.new()
	slider.name = "Slider"
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = value
	slider.custom_minimum_size = UI.grown(Vector2(210, 24))
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	Board.rail(slider)
	row.add_child(slider)
	var percent := UI.label("", 18, UI.GOLD, true)
	percent.custom_minimum_size = UI.grown(Vector2(56, 0))
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(percent)
	var show_value := func(v: float): percent.text = "%d%%" % roundi(v * 100.0)
	show_value.call(value)
	slider.value_changed.connect(func(v: float):
		setter.call(v)
		show_value.call(v))
	slider.drag_ended.connect(func(_changed): Settings.save())
	return row


func _on_language_pressed(code: String) -> void:
	Settings.set_language(code)
	Settings.save()
	_restyle_languages()


func _restyle_languages() -> void:
	for code: String in _language_buttons:
		var b: Button = _language_buttons[code]
		Board.plank(b, UI.BORDER, code == Settings.language)


func _on_fullscreen_pressed(on: bool) -> void:
	if on != UI.is_fullscreen(get_window()):
		UI.toggle_fullscreen(get_window())
	_restyle_fullscreen()


func _restyle_fullscreen() -> void:
	_fullscreen_shown = UI.is_fullscreen(get_window())
	for on: bool in _fullscreen_buttons:
		Board.plank(_fullscreen_buttons[on], UI.BORDER, on == _fullscreen_shown)
