class_name UI
extends RefCounted
## Shared look and feel: palette, theme, small widget factories and tweens.

const INK := Color("160c08")
const PANEL := Color("2a1810")
const PANEL_LIGHT := Color("40281a")
const BORDER := Color("8a6a3a")
const GOLD := Color("e6bc4c")
const CREAM := Color("f1e3c0")
const MUTED := Color("a8946f")
const RED := Color("c8402f")
const GREEN := Color("78a846")
const BLUE := Color("5fb0d0")
const PURPLE := Color("9a62c4")

## Jersey 15 is drawn small for its point size; sizes asked of label() and
## button() are multiplied by this.
const FONT_SCALE := 1.15
const FONT_PATH := "res://assets/fonts/Jersey15-Regular.ttf"
const CARD_BACK := "res://assets/Card.png"
const ITEM_BACK := "res://assets/Item.png"

static var _theme: Theme
static var _font: Font
static var _bold: Font
static var _textures: Dictionary = {}


static func font() -> Font:
	if _font == null:
		if ResourceLoader.exists(FONT_PATH):
			_font = load(FONT_PATH)
		elif FileAccess.file_exists(FONT_PATH):
			# Not imported yet (the editor has not rescanned): read the file directly.
			var file := FontFile.new()
			_font = file if file.load_dynamic_font(FONT_PATH) == OK else ThemeDB.fallback_font
		else:
			_font = ThemeDB.fallback_font
	return _font


static func bold() -> Font:
	if _bold == null:
		var variation := FontVariation.new()
		variation.base_font = font()
		variation.variation_embolden = 0.6
		_bold = variation
	return _bold


static func tex(path: String) -> Texture2D:
	if path == "":
		return null
	if not _textures.has(path):
		_textures[path] = load(path) if ResourceLoader.exists(path) else null
	return _textures[path]


static func box(bg: Color, border: Color = BORDER, width := 2, radius := 4, margin := 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	sb.anti_aliasing = false
	return sb


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 18
	t.set_color("font_color", "Label", CREAM)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.6))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)

	t.set_stylebox("normal", "Button", box(PANEL_LIGHT, BORDER, 2, 4, 6))
	t.set_stylebox("hover", "Button", box(PANEL_LIGHT.lightened(0.12), GOLD, 2, 4, 6))
	t.set_stylebox("pressed", "Button", box(PANEL.darkened(0.2), GOLD, 2, 4, 6))
	t.set_stylebox("disabled", "Button", box(PANEL.darkened(0.25), BORDER.darkened(0.5), 2, 4, 6))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", CREAM)
	t.set_color("font_hover_color", "Button", GOLD)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", MUTED.darkened(0.35))

	t.set_stylebox("panel", "PanelContainer", box(Color(PANEL, 0.94)))
	t.set_stylebox("panel", "Panel", box(Color(PANEL, 0.94)))
	t.set_stylebox("normal", "LineEdit", box(INK, BORDER, 2, 4, 5))
	t.set_stylebox("focus", "LineEdit", box(INK, GOLD, 2, 4, 5))
	t.set_color("font_color", "LineEdit", CREAM)
	t.set_stylebox("slider", "HSlider", box(INK, BORDER, 2, 4, 4))
	t.set_stylebox("grabber_area", "HSlider", box(GOLD.darkened(0.35), BORDER, 2, 4, 4))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(GOLD.darkened(0.2), GOLD, 2, 4, 4))
	t.set_icon("grabber", "HSlider", _grabber(CREAM))
	t.set_icon("grabber_highlight", "HSlider", _grabber(GOLD))
	t.set_icon("grabber_disabled", "HSlider", _grabber(MUTED))
	t.set_color("default_color", "RichTextLabel", CREAM)
	t.set_font("normal_font", "RichTextLabel", font())
	t.set_font("bold_font", "RichTextLabel", bold())
	t.set_font_size("normal_font_size", "RichTextLabel", 16)
	t.set_font_size("bold_font_size", "RichTextLabel", 16)
	_theme = t
	return t


## The knob of a slider: a small plate in the given colour.
static func _grabber(color: Color) -> ImageTexture:
	var image := Image.create(12, 22, false, Image.FORMAT_RGBA8)
	image.fill(INK)
	image.fill_rect(Rect2i(2, 2, 8, 18), color)
	return ImageTexture.create_from_image(image)


static func label(text: String, size := 16, color: Color = CREAM, is_bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", roundi(size * FONT_SCALE))
	l.add_theme_color_override("font_color", color)
	if is_bold:
		l.add_theme_font_override("font", bold())
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A button that grows a little under the mouse. `accent` tints its border.
static func button(text: String, accent: Color = BORDER, size := 16) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", roundi(size * FONT_SCALE))
	if accent != BORDER:
		b.add_theme_stylebox_override("normal", box(accent.darkened(0.55), accent, 2, 4, 6))
		b.add_theme_stylebox_override("hover", box(accent.darkened(0.35), accent.lightened(0.3), 2, 4, 6))
		b.add_theme_stylebox_override("pressed", box(accent.darkened(0.65), accent, 2, 4, 6))
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	juice(b)
	return b


## For a button painted on a screen's artwork, where the label is in English.
## It stays invisible over the painting; in any other language it becomes an
## opaque plate with the translated `text`.
static func art_button(b: Button, text: String, fill: Color, border: Color, ink: Color, size: int) -> void:
	var painted := Loc.t(text) == text
	b.text = "" if painted else text
	b.add_theme_font_size_override("font_size", roundi(size * FONT_SCALE))
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, ink)
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new() if painted else box(fill, border, 4, 4, 0))
	b.add_theme_stylebox_override("hover", box(Color(1, 0.85, 0.4, 0.12) if painted else fill.lightened(0.08), GOLD, 4, 4, 0))
	b.add_theme_stylebox_override("pressed", box(Color(0, 0, 0, 0.25) if painted else fill.darkened(0.25), GOLD, 4, 4, 0))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


## Hover feedback for any control: a quick scale-up around its centre.
static func juice(c: Control, amount := 1.06) -> void:
	c.mouse_entered.connect(func():
		if c is BaseButton and c.disabled:
			return
		c.pivot_offset = c.size / 2.0
		c.create_tween().tween_property(c, "scale", Vector2.ONE * amount, 0.08))
	c.mouse_exited.connect(func():
		c.pivot_offset = c.size / 2.0
		c.create_tween().tween_property(c, "scale", Vector2.ONE, 0.1))


## Scale punch, for things that just changed.
static func pop(c: CanvasItem, amount := 1.3, time := 0.25) -> void:
	if c is Control:
		c.pivot_offset = c.size / 2.0
	c.scale = Vector2.ONE * amount
	c.create_tween().tween_property(c, "scale", Vector2.ONE, time) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func shake(c: Control, strength := 8.0, time := 0.3) -> void:
	var origin := c.position
	var tween := c.create_tween()
	var steps := 6
	for i in steps:
		var falloff := 1.0 - float(i) / steps
		var offset := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * falloff
		tween.tween_property(c, "position", origin + offset, time / steps)
	tween.tween_property(c, "position", origin, 0.03)


## Removes every child right away (queue_free alone leaves them in the layout
## for a frame).
static func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


## F11 or Alt+Enter. Every screen forwards its unhandled keys here.
static func handle_fullscreen_key(event: InputEvent, window: Window) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed):
		toggle_fullscreen(window)


static func is_fullscreen(window: Window) -> bool:
	return window.mode == Window.MODE_FULLSCREEN or window.mode == Window.MODE_EXCLUSIVE_FULLSCREEN


static func toggle_fullscreen(window: Window) -> void:
	window.mode = Window.MODE_WINDOWED if is_fullscreen(window) else Window.MODE_FULLSCREEN


static func hex(c: Color) -> String:
	return "#" + c.to_html(false)


# --- tooltip texts (BBCode) ----------------------------------------------------

static func character_tip(def: CharacterDef, note := "") -> String:
	var text := "[b][color=%s]%s[/color][/b]  [color=%s]%s[/color]\n" % [
		hex(GOLD), def.display_name.to_upper(), hex(MUTED), def.title]
	for ability: Ability in def.abilities:
		text += "\n" + ability_tip(ability)
	if note != "":
		text += "\n[color=%s]%s[/color]" % [hex(GREEN), Loc.t(note)]
	return text


static func ability_tip(ability: Ability) -> String:
	var head := "[b]%s[/b] [color=%s](%s)[/color]" % [ability.display_name, hex(MUTED), ability.kind_label()]
	if ability.cost > 0:
		head += " [color=%s]%s[/color]" % [hex(GOLD), Loc.t("%d coins") % ability.cost]
	var body := ability.description
	if ability.trigger_text != "":
		body = "[color=%s]%s:[/color] %s" % [hex(BLUE), ability.trigger_text, body]
	return "%s\n%s\n" % [head, body]


static func item_tip(def: ItemDef, note := "") -> String:
	var text := "[b][color=%s]%s[/color][/b]  [color=%s]%s · %s[/color]\n%s" % [
		hex(GOLD), def.display_name.to_upper(), hex(MUTED), Loc.t("%d coins") % def.price, def.kind_label(), def.description]
	if note != "":
		text += "\n[color=%s]%s[/color]" % [hex(BLUE), Loc.t(note)]
	return text
