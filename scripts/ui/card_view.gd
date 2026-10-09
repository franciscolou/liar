class_name CardView
extends Control
## A character card: face or back, with hover lift, flip and a highlight frame.

signal clicked

const BASE := Vector2(55, 100)
## The size a caption is written at, and the smallest it shrinks to when the
## name does not fit on the plate.
const CAPTION_FONT := 11
const CAPTION_SMALLEST := 7
## How far above the middle of its line the text of a caption is put: the
## letters of the font hang low in theirs.
const CAPTION_RISE := 0.0

var card_id: StringName
var face_up := false
var interactive := true
var lift := 10.0
## Extra green line in the tooltip (e.g. "You hold this card").
var note := ""
## False where the screen shows what the card does somewhere else.
var tips := true

var _inner: Control
var _art: TextureRect
var _frame: Panel
var _tween: Tween
var _caption: Label


func _init(card_scale := 1.0) -> void:
	custom_minimum_size = BASE * card_scale
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_PASS
	_inner = Control.new()
	_inner.size = size
	_inner.pivot_offset = size / 2.0
	_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_inner)
	_art = TextureRect.new()
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_SCALE
	_art.size = size
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.texture = UI.tex(UI.CARD_BACK)
	_inner.add_child(_art)
	_frame = Panel.new()
	_frame.size = size
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.visible = false
	_inner.add_child(_frame)
	mouse_entered.connect(_hover.bind(true))
	mouse_exited.connect(_hover.bind(false))
	TipLayer.attach(self, _tip)


func set_card(id: StringName, show_face: bool, animate := false) -> void:
	if id == card_id and show_face == face_up:
		return
	card_id = id
	face_up = show_face
	if animate and is_inside_tree():
		flip()
	else:
		_apply()


## Turns the card over to show its current state.
func flip() -> void:
	var tween := create_tween()
	tween.tween_property(_inner, "scale:x", 0.0, 0.1)
	tween.tween_callback(_apply)
	tween.tween_property(_inner, "scale:x", 1.0, 0.12)


func highlight(color: Variant = null) -> void:
	_frame.visible = color != null
	if color != null:
		_frame.add_theme_stylebox_override("panel", UI.box(Color(0, 0, 0, 0), color, 3, 3, 0))


## Writes `text` on a plate across the foot of the card, over the bottom of
## the picture ("" takes the plate away).
func set_caption(text: String) -> void:
	if _caption == null:
		var inset := roundf(size.x * 0.06)
		var plate := ColorRect.new()
		plate.color = Color(UI.INK, 0.88)
		plate.size = Vector2(size.x - inset * 2.0, roundf(size.y * 0.135))
		plate.position = Vector2(inset, size.y - plate.size.y - inset)
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_inner.add_child(plate)
		var rule := ColorRect.new()
		rule.color = UI.GOLD.darkened(0.25)
		rule.size = Vector2(plate.size.x, 1)
		rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.add_child(rule)
		_caption = UI.label("", CAPTION_FONT, UI.CREAM, true)
		# Clipping comes before the size: until then the label refuses to be
		# narrower than its text.
		_caption.clip_text = true
		_caption.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		plate.add_child(_caption)
		# The font sits low in its line: the line is centred on the plate
		# and then raised by what the letters leave empty above them.
		var line := _caption.get_minimum_size().y
		_caption.size = Vector2(plate.size.x - 2.0, line)
		_caption.position = Vector2(1, roundf((plate.size.y - line) / 2.0) - CAPTION_RISE)
	_caption.text = text
	_caption.get_parent().visible = text != ""
	# A name too long for the plate is written smaller, down to CAPTION_SMALLEST;
	# past that it is cut like before.
	var font := _caption.get_theme_font("font")
	var points := roundi(CAPTION_FONT * UI.FONT_SCALE)
	var smallest := roundi(CAPTION_SMALLEST * UI.FONT_SCALE)
	while points > smallest and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, points).x > _caption.size.x:
		points -= 1
	_caption.add_theme_font_size_override("font_size", points)


func center() -> Vector2:
	return global_position + size / 2.0


## Drops the hover pose and stops reacting to the mouse.
func settle() -> void:
	interactive = false
	if _tween != null:
		_tween.kill()
	z_index = 0
	_tween = create_tween().set_parallel()
	_tween.tween_property(_inner, "position:y", 0.0, 0.1)
	_tween.tween_property(_inner, "scale", Vector2.ONE, 0.1)


func _apply() -> void:
	var def := Content.character(card_id) if face_up else null
	_art.texture = UI.card_face(def.texture_path) if def != null else UI.tex(UI.CARD_BACK)
	_art.texture_filter = UI.card_filter(_art.texture)


func _tip() -> String:
	var def := Content.character(card_id) if face_up and tips else null
	return UI.character_tip(def, note) if def != null else ""


func _hover(inside: bool) -> void:
	if not interactive:
		return
	if _tween != null:
		_tween.kill()
	z_index = 5 if inside else 0
	_tween = create_tween().set_parallel()
	_tween.tween_property(_inner, "position:y", -lift if inside else 0.0, 0.1)
	_tween.tween_property(_inner, "scale", Vector2.ONE * (1.08 if inside else 1.0), 0.1)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit()
