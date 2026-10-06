class_name ItemView
extends Control
## An item icon (shop slot or inventory), or the item back when hidden.

signal clicked

const BASE := Vector2(61, 64)

var def: ItemDef
var concealed := false
var enabled := true
var note := ""

var _art: TextureRect


func _init(item_scale := 1.0) -> void:
	custom_minimum_size = BASE * item_scale
	size = custom_minimum_size
	pivot_offset = size / 2.0
	mouse_filter = Control.MOUSE_FILTER_PASS
	_art = TextureRect.new()
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_SCALE
	_art.size = size
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)
	mouse_entered.connect(_hover.bind(true))
	mouse_exited.connect(_hover.bind(false))
	TipLayer.attach(self, _tip)


func set_item(item_def: ItemDef, is_concealed := false) -> void:
	def = item_def
	concealed = is_concealed
	_art.texture = UI.tex(UI.ITEM_BACK) if concealed else (UI.tex(def.texture_path) if def != null else null)


func set_enabled(value: bool) -> void:
	enabled = value
	_art.modulate = Color.WHITE if value else Color(0.55, 0.5, 0.5, 0.9)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if value else Control.CURSOR_ARROW


func center() -> Vector2:
	return global_position + size / 2.0


func _tip() -> String:
	if concealed:
		return Loc.t("[b]Hidden item[/b]\nBought under a Low Profile.")
	return UI.item_tip(def, note) if def != null else ""


func _hover(inside: bool) -> void:
	z_index = 5 if inside else 0
	create_tween().tween_property(self, "scale", Vector2.ONE * (1.15 if inside and enabled else 1.0), 0.08)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit()
