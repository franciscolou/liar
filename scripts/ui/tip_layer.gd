class_name TipLayer
extends CanvasLayer
## One floating tooltip per screen. Controls register with TipLayer.attach
## and get an instant, rich-text hover card instead of Godot's default one.

static var current: TipLayer

var _panel: PanelContainer
var _text: RichTextLabel
var _owner: Control


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
	_text.custom_minimum_size = Vector2(280, 0)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_text)
	add_child(_panel)


func _exit_tree() -> void:
	if current == self:
		current = null


## `text` is a BBCode String (translated on hover if it is a Loc key), or a
## Callable returning one, evaluated on hover.
static func attach(control: Control, text: Variant) -> void:
	control.mouse_entered.connect(func():
		if current != null:
			var content: String = text.call() if text is Callable else Loc.t(text)
			current.show_tip(control, content))
	control.mouse_exited.connect(func():
		if current != null:
			current.hide_tip(control))
	control.tree_exiting.connect(func():
		if current != null:
			current.hide_tip(control))


func show_tip(control: Control, bbcode: String) -> void:
	if bbcode == "":
		return
	_owner = control
	_text.text = bbcode
	_panel.visible = true
	_panel.modulate.a = 0.0
	_panel.reset_size()
	await get_tree().process_frame
	if _owner != control or not is_instance_valid(control):
		return
	_panel.reset_size()
	var screen := get_viewport().get_visible_rect().size
	var rect := control.get_global_rect()
	var size := _panel.size
	var pos := Vector2(rect.get_center().x - size.x / 2.0, rect.position.y - size.y - 10)
	if pos.y < 6:
		pos.y = rect.end.y + 10
	if pos.y + size.y > screen.y - 6:
		pos.y = screen.y - size.y - 6
		pos.x = rect.end.x + 10 if rect.end.x + size.x + 16 < screen.x else rect.position.x - size.x - 10
	pos.x = clampf(pos.x, 6, screen.x - size.x - 6)
	_panel.position = pos
	_panel.create_tween().tween_property(_panel, "modulate:a", 1.0, 0.08)


func hide_all() -> void:
	_owner = null
	_panel.visible = false


func hide_tip(control: Control) -> void:
	if _owner == control:
		_owner = null
		_panel.visible = false
