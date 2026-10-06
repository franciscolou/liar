class_name CardView
extends Control
## A character card: face or back, with hover lift, flip and a highlight frame.

signal clicked

const BASE := Vector2(55, 100)

var card_id: StringName
var face_up := false
var interactive := true
var lift := 10.0
## Extra green line in the tooltip (e.g. "You hold this card").
var note := ""

var _inner: Control
var _art: TextureRect
var _frame: Panel
var _tween: Tween


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


func _tip() -> String:
	var def := Content.character(card_id) if face_up else null
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
