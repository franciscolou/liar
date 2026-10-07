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
const CARD_FRAME := "res://assets/ui/card_frame.png"
## Folder of an alternative set of card art, looked up by file name; a card
## missing from it keeps its own art. "" uses the art each character names.
## "res://assets/cards_proto/" and "res://assets/cards_proto2/" are cut from
## assets/prototype and assets/prototype2 by tools/gen_proto_cards.py.
const CARD_ART_DIR := "res://assets/cards_proto2/"
## Transparent pixels at each end of the first rows of a card: the rounded
## corners of the card back.
const CARD_CORNER := [3, 2, 1]

static var _theme: Theme
static var _font: Font
static var _bold: Font
static var _textures: Dictionary = {}
static var _faces: Dictionary = {}


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
		var texture: Texture2D = null
		if ResourceLoader.exists(path):
			texture = load(path)
		elif FileAccess.file_exists(path):
			# Not imported yet (the editor has not rescanned): read the file directly.
			var image := Image.load_from_file(path)
			if image != null:
				texture = ImageTexture.create_from_image(image)
		_textures[path] = texture
	return _textures[path]


## The face of a card: its art under the card frame, with the corners rounded
## like the card back. The plain art if the frame does not fit it. `path` is
## the character's own art; CARD_ART_DIR may swap it for another set.
static func card_face(path: String) -> Texture2D:
	if not _faces.has(path):
		_faces[path] = _frame_card(tex(_card_art(path)), tex(CARD_FRAME))
	return _faces[path]


## Pixel art cards are drawn with hard pixels; art larger than the card is
## scaled down smoothly.
static func card_filter(texture: Texture2D) -> CanvasItem.TextureFilter:
	if texture != null and texture.get_width() > tex(CARD_BACK).get_width():
		return CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return CanvasItem.TEXTURE_FILTER_NEAREST


static func _card_art(path: String) -> String:
	if CARD_ART_DIR == "":
		return path
	var other := CARD_ART_DIR + path.get_file()
	return other if ResourceLoader.exists(other) or FileAccess.file_exists(other) else path


## `art` may be a whole number of times the size of the frame: the frame and
## the corners grow with it.
static func _frame_card(art: Texture2D, frame: Texture2D) -> Texture2D:
	if art == null or frame == null:
		return art
	@warning_ignore("integer_division")
	var zoom := art.get_width() / frame.get_width()
	if zoom < 1 or Vector2i(art.get_size()) != Vector2i(frame.get_size()) * zoom:
		return art
	var image := art.get_image()
	var overlay := frame.get_image()
	if image == null or overlay == null:
		return art
	for layer: Image in [image, overlay]:
		if layer.is_compressed():
			layer.decompress()
		layer.convert(Image.FORMAT_RGBA8)
	var width := image.get_width()
	var height := image.get_height()
	if zoom > 1:
		image.clear_mipmaps()
		overlay.clear_mipmaps()
		overlay.resize(width, height, Image.INTERPOLATE_NEAREST)
	image.blend_rect(overlay, Rect2i(0, 0, width, height), Vector2i.ZERO)
	var clear := Color(0, 0, 0, 0)
	for row in CARD_CORNER.size():
		var cut: int = CARD_CORNER[row] * zoom
		for y: int in [row * zoom, height - (row + 1) * zoom]:
			image.fill_rect(Rect2i(0, y, cut, zoom), clear)
			image.fill_rect(Rect2i(width - cut, y, cut, zoom), clear)
	if zoom > 1:
		image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


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
