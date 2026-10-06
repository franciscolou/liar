class_name SettingsPanel
extends ColorRect
## The settings overlay: music and sound volume, and the language. Shared by
## the title screen and the pause menu; add it as a child and it covers the
## screen until closed.

signal closed

const PREVIEW_SOUND := "res://assets/sounds/spend.mp3"

var _language_buttons: Dictionary = {}  # language code -> Button
var _preview: AudioStreamPlayer


func _init() -> void:
	color = Color(0, 0, 0, 0.7)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 30
	theme = UI.theme()

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.box(Color(UI.INK, 0.98), UI.GOLD, 3, 8, 22))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var heading := UI.label("SETTINGS", 28, UI.GOLD, true)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)

	box.add_child(_volume_row("Music", Settings.music, func(v: float): Settings.set_music(v)))
	var sfx_row := _volume_row("Sound effects", Settings.sfx, func(v: float): Settings.set_sfx(v))
	# Lets the new volume be heard when the slider is let go.
	sfx_row.get_node("Slider").drag_ended.connect(func(_changed): _preview.play())
	box.add_child(sfx_row)

	var language_row := _row("Language")
	for code: String in Loc.LANGUAGES:
		var b := UI.button(Loc.LANGUAGES[code], UI.BORDER, 15)
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.custom_minimum_size = Vector2(124, 32)
		b.pressed.connect(_on_language_pressed.bind(code))
		language_row.add_child(b)
		_language_buttons[code] = b
	box.add_child(language_row)
	_restyle_languages()

	var back := UI.button("Back", UI.GOLD, 18)
	back.custom_minimum_size = Vector2(200, 42)
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


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _row(text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var l := UI.label(text, 18)
	l.custom_minimum_size = Vector2(170, 0)
	row.add_child(l)
	return row


func _volume_row(text: String, value: float, setter: Callable) -> HBoxContainer:
	var row := _row(text)
	var slider := HSlider.new()
	slider.name = "Slider"
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(210, 24)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.add_child(slider)
	var percent := UI.label("", 18, UI.GOLD, true)
	percent.custom_minimum_size = Vector2(56, 0)
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
		var on := code == Settings.language
		var accent := UI.GOLD if on else UI.BORDER.darkened(0.3)
		b.add_theme_stylebox_override("normal", UI.box(accent.darkened(0.6) if on else UI.PANEL, accent, 2, 4, 6))
		b.add_theme_color_override("font_color", UI.GOLD if on else UI.MUTED)
