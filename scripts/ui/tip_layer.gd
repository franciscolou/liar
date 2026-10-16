class_name TipLayer
extends CanvasLayer
## One floating tooltip per screen. Controls register with TipLayer.attach
## and get an instant, rich-text hover card instead of Godot's default one.

## Widest a tooltip gets before its text wraps.
const MAX_WIDTH := 280.0
## Clear space between a tooltip and its control, and between it and the
## edge of the screen.
const GAP := 16.0
const EDGE := 6.0

enum { ABOVE, BELOW, RIGHT, LEFT }

static var current: TipLayer

var _panel: PanelContainer
var _text: RichTextLabel
var _owner: Control
var _side := -1


func _ready() -> void:
	layer = 50
	current = self
	_panel = PanelContainer.new()
	_panel.theme = UI.theme()
	_panel.add_theme_stylebox_override("panel", UI.box(Color(UI.INK, 0.97), UI.GOLD, 2, 4, 10))
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_text)
	add_child(_panel)


func _exit_tree() -> void:
	if current == self:
		current = null


## `text` is a BBCode String (translated on hover if it is a Loc key), or a
## Callable returning one, evaluated on hover. In touch mode a hover shows
## nothing (a tapped control would keep its tooltip up): a held finger does,
## through `explain`.
static func attach(control: Control, text: Variant) -> void:
	control.set_meta(&"tip", text)
	control.mouse_entered.connect(func():
		if current != null and not UI.touch:
			current.show_tip(control, _content(text)))
	control.mouse_exited.connect(func():
		if current != null:
			current.hide_tip(control))
	control.tree_exiting.connect(func():
		if current != null:
			current.hide_tip(control))


## Shows the tooltip of `control`, or of the nearest control holding it that
## has one. Whether there was one to show.
static func explain(control: Control) -> bool:
	if current == null:
		return false
	var node: Node = control
	while node is Control:
		if node.has_meta(&"tip"):
			var content := _content(node.get_meta(&"tip"))
			if content != "":
				current.show_tip(node, content)
				return true
		node = node.get_parent()
	return false


static func _content(text: Variant) -> String:
	return text.call() if text is Callable else Loc.t(text)


func show_tip(control: Control, bbcode: String) -> void:
	if bbcode == "":
		return
	_owner = control
	_side = -1
	# Laid out unwrapped first, to learn how wide the text really is.
	_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	_text.custom_minimum_size = Vector2.ZERO
	_text.text = bbcode
	_panel.visible = true
	_panel.modulate.a = 0.0
	_panel.reset_size()
	await get_tree().process_frame
	if _owner != control or not is_instance_valid(control):
		return
	_text.custom_minimum_size = Vector2(minf(ceilf(_text.get_content_width()), MAX_WIDTH), 0)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	await get_tree().process_frame
	if _owner != control or not is_instance_valid(control):
		return
	_side = -1
	_place()
	_panel.create_tween().tween_property(_panel, "modulate:a", 1.0, 0.08)


## The tooltip follows its control: most of them grow, lift or slide under
## the mouse, and the text can settle a frame late.
func _process(_delta: float) -> void:
	if _panel.visible and _side >= 0 and is_instance_valid(_owner):
		_place()


## Puts the tooltip beside its control, never over it: above, below, right
## or left, whichever has the room, keeping the side it already took.
func _place() -> void:
	_panel.reset_size()
	var screen := get_viewport().get_visible_rect().size
	var rect := _reach(_owner)
	var size := _panel.size
	var room := [
		rect.position.y - GAP - EDGE - size.y,
		screen.y - EDGE - rect.end.y - GAP - size.y,
		screen.x - EDGE - rect.end.x - GAP - size.x,
		rect.position.x - GAP - EDGE - size.x,
	]
	if _side < 0 or room[_side] < 0.0:
		_side = 0
		for side in room.size():
			if room[side] >= 0.0:
				_side = side
				break
			if room[side] > room[_side]:
				_side = side
	var pos := rect.get_center() - size / 2.0
	match _side:
		ABOVE:
			pos.y = rect.position.y - GAP - size.y
		BELOW:
			pos.y = rect.end.y + GAP
		RIGHT:
			pos.x = rect.end.x + GAP
		LEFT:
			pos.x = rect.position.x - GAP - size.x
	pos.x = clampf(pos.x, EDGE, maxf(EDGE, screen.x - size.x - EDGE))
	pos.y = clampf(pos.y, EDGE, maxf(EDGE, screen.y - size.y - EDGE))
	_panel.position = pos.round()


## The space a control takes on screen while hovered. A control that draws
## past its own rect then (a card lifting) says so in `tip_rect()`.
func _reach(control: Control) -> Rect2:
	if control.has_method(&"tip_rect"):
		return control.call(&"tip_rect")
	return control.get_global_rect()


func hide_all() -> void:
	_owner = null
	_side = -1
	_panel.visible = false


func hide_tip(control: Control) -> void:
	if _owner == control:
		_owner = null
		_side = -1
		_panel.visible = false
