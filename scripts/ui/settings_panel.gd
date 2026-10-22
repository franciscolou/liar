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

	box.add_child(_volume_row("Music", Settings.music, func(v: float): Settings.set_music(v),
			func() -> bool: return Settings.music_muted, func(on: bool): Settings.set_music_muted(on)))
	var sfx_row := _volume_row("Sound effects", Settings.sfx, func(v: float): Settings.set_sfx(v),
			func() -> bool: return Settings.sfx_muted, func(on: bool): Settings.set_sfx_muted(on))
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


## The speaker of the mute button, in 2 px blocks: its body, then a wave
## for every third of the volume (each further out and taller than the one
## before), or a cross where the waves would be when the bus is muted.
const SPEAKER: Array[String] = [
	"....#",
	"...##",
	"#####",
	"#####",
	"#####",
	"#####",
	"...##",
	"....#",
]
## Column and height (in blocks) of each wave, centred on the speaker.
const WAVES := [Vector2i(6, 2), Vector2i(8, 4), Vector2i(10, 6)]
const CROSS: Array[String] = [
	"#...#",
	".#.#.",
	"..#..",
	".#.#.",
	"#...#",
]


## A volume: the mute button, the slider and the percent. Muting keeps the
## volume, which comes back when it is heard again; moving the slider of a
## muted bus brings it back too.
func _volume_row(text: String, value: float, setter: Callable, muted: Callable, set_muted: Callable) -> HBoxContainer:
	var row := _row(text)
	var mute := UI.button("", UI.BORDER, 15)
	mute.custom_minimum_size = UI.grown(Vector2(40, 32))
	mute.focus_mode = Control.FOCUS_NONE
	row.add_child(mute)
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
	var show_muted := func():
		var on: bool = muted.call()
		Board.plank(mute, UI.RED if on else UI.BORDER)
		slider.modulate.a = 0.4 if on else 1.0
		percent.modulate.a = 0.4 if on else 1.0
		mute.queue_redraw()
	show_muted.call()
	TipLayer.attach(mute, func() -> String: return Loc.t("Unmute") if muted.call() else Loc.t("Mute"))
	mute.draw.connect(func():
		var cell := 2.0
		var rows := SPEAKER.size()
		var origin := ((mute.size - Vector2(11, rows) * cell) / 2.0).round()
		var ink := UI.CREAM if muted.call() else UI.GOLD
		var block := func(x: int, y: int):
			mute.draw_rect(Rect2(origin + Vector2(x, y) * cell, Vector2(cell, cell)), ink)
		for y in rows:
			for x in SPEAKER[y].length():
				if SPEAKER[y][x] == "#":
					block.call(x, y)
		if muted.call():
			for y in CROSS.size():
				for x in CROSS[y].length():
					if CROSS[y][x] == "#":
						block.call(6 + x, (rows - CROSS.size()) / 2 + y)
			return
		var waves := ceili(slider.value * WAVES.size() - 0.001)
		for i in clampi(waves, 0, WAVES.size()):
			var wave: Vector2i = WAVES[i]
			for y in wave.y:
				block.call(wave.x, (rows - wave.y) / 2 + y))
	mute.pressed.connect(func():
		set_muted.call(not muted.call())
		show_muted.call()
		Settings.save())
	slider.value_changed.connect(func(v: float):
		setter.call(v)
		show_value.call(v)
		mute.queue_redraw()
		if muted.call():
			set_muted.call(false)
			show_muted.call())
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
