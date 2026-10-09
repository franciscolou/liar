class_name StatusChips
extends Control
## Small coloured tags for the statuses on a player (Hexed, Under Oath...).
## Only SHOWN of them stay on the box; the rest fold into a "+N" tag beside
## them, and the whole lot opens out under the mouse.

## How many chips a box shows before the rest fold away. The wide board of
## the player's own panel fits them all: it sets `limit` to 0, for no limit.
const SHOWN := 2
const GAP := Vector2(3, 2)
const OPEN_TIME := 0.14
## How far around the chips the mouse still counts as over them.
const REACH := 3.0

var limit := SHOWN

var _shown := ""
var _chips := {}  # status id -> its chip
var _order: Array[StringName] = []
var _widths := {}  # status id -> the width its chip wants
var _more: PanelContainer  # the "+N" tag; null when everything fits
var _folded := {}  # status id -> Rect2, with the extra chips tucked under the tag
var _spread := {}  # status id -> Rect2, with every chip out
var _more_at := Vector2.ZERO
var _hover := false
var _tween: Tween
## 0 folded, 1 opened out.
var _open := 0.0:
	set(value):
		_open = value
		_place()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_input(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_shown = ""  # redraw on the next sync
	elif what == NOTIFICATION_WM_MOUSE_EXIT and _more != null:
		_set_hover(false)


func sync(player: PlayerState, engine: GameEngine) -> void:
	var signature := str(player.statuses.keys())
	if signature == _shown:
		return
	_shown = signature
	var known := _chips.keys()
	UI.clear(self)
	_chips.clear()
	_widths.clear()
	_order.clear()
	_more = null
	for status_id: StringName in player.statuses:
		var def: Dictionary = Content.statuses.get(status_id, {})
		var color: Color = def.get("color", UI.MUTED)
		var chip := _chip(Loc.t(def.get("name", String(status_id))).to_upper(), color)
		chip.mouse_filter = Control.MOUSE_FILTER_PASS
		var tip := "[b]%s[/b]\n%s" % [Loc.t(def.get("name", status_id)), Loc.t(def.get("description", ""))]
		var by := engine.player_by_id(player.statuses[status_id].get("by", -1))
		if by != null:
			tip += "\n[color=%s]%s[/color]" % [UI.hex(UI.MUTED), Loc.t("Placed by %s.") % by.name]
		TipLayer.attach(chip, tip)
		_chips[status_id] = chip
		_widths[status_id] = chip.size.x
		_order.append(status_id)
	if limit > 0 and _order.size() > limit:
		_more = _chip("+%d" % (_order.size() - limit), UI.MUTED)
	_lay_out()
	if _more == null:
		_hover = false
		_open = 0.0
	else:
		_place()
	set_process_input(_more != null)
	for status_id: StringName in _order:
		if not known.has(status_id) and _chips[status_id].visible:
			UI.pop(_chips[status_id], 1.4)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var at: Vector2 = make_input_local(event).position
		_set_hover(is_visible_in_tree() and modulate.a > 0.5 and _reach().has_point(at))


func _set_hover(over: bool) -> void:
	if over == _hover:
		return
	_hover = over
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "_open", 1.0 if over else 0.0, OPEN_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	if _open <= 0.0 or _spread.is_empty():
		return
	# Opened out, the chips may hang over whatever is next to them.
	var back := Rect2(_spread[_order[0]])
	for status_id: StringName in _order:
		back = back.merge(_spread[status_id])
	draw_rect(back.grow(3), Color(UI.INK, 0.85 * _open))
	draw_rect(back.grow(3), Color(UI.BORDER, _open), false, 1.0)


## The chip showing `status_id` (the "+N" tag while it is folded under it),
## null if there is none.
func chip_of(status_id: StringName) -> Control:
	var found: Variant = _chips.get(status_id)
	if found == null or not is_instance_valid(found):
		return null
	return found if found.visible or _more == null else _more


func _chip(text: String, color: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UI.box(color.darkened(0.45), color, 1, 3, 3))
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := UI.label(text, 10, UI.CREAM, true)
	chip.add_child(label)
	add_child(chip)
	chip.size = chip.get_combined_minimum_size()
	# From here on the chip is as wide as it is told to be.
	label.clip_text = true
	return chip


## Works out where every chip sits folded and opened out.
func _lay_out() -> void:
	_folded.clear()
	_spread = _flow(_order)
	if _more == null:
		_folded = _spread
		return
	var kept := _order.slice(0, limit)
	_folded = _flow(kept)
	# The tag goes beside the last chip it fits next to; if it fits next to
	# none, the last one is cut short to make room.
	var room := _more.size.x + GAP.x
	var beside: StringName = kept[-1]
	for index in range(kept.size() - 1, -1, -1):
		var rect: Rect2 = _folded[kept[index]]
		var last_of_row: bool = index == kept.size() - 1 or _folded[kept[index + 1]].position.y != rect.position.y
		if last_of_row and rect.end.x + room <= size.x:
			beside = kept[index]
			break
	var host: Rect2 = _folded[beside]
	if host.end.x + room > size.x:
		host.size.x = maxf(size.x - room - host.position.x, 0.0)
		_folded[beside] = host
	_more_at = Vector2(host.end.x + GAP.x, host.position.y)
	for status_id: StringName in _order.slice(limit):
		_folded[status_id] = Rect2(_more_at, Vector2(_more.size.x, _chips[status_id].size.y))


## `ids` in rows no wider than this control: status id -> Rect2.
func _flow(ids: Array) -> Dictionary:
	var out := {}
	var at := Vector2.ZERO
	for status_id: StringName in ids:
		var chip: Control = _chips[status_id]
		var wide: float = _widths[status_id]
		if at.x > 0.0 and at.x + wide > size.x:
			at = Vector2(0, at.y + chip.size.y + GAP.y)
		out[status_id] = Rect2(at, Vector2(wide, chip.size.y))
		at.x += wide + GAP.x
	return out


func _place() -> void:
	for index in _order.size():
		var status_id := _order[index]
		var chip: Control = _chips[status_id]
		if not is_instance_valid(chip):
			continue
		var from: Rect2 = _folded[status_id]
		var to: Rect2 = _spread[status_id]
		chip.position = from.position.lerp(to.position, _open)
		chip.size = from.size.lerp(to.size, _open)
		if index >= limit and _more != null:
			chip.visible = _open > 0.0
			chip.modulate.a = _open
	if _more != null:
		_more.position = _more_at
		_more.modulate.a = 1.0 - _open
		_more.visible = _open < 1.0
	z_index = 20 if _open > 0.0 else 0
	queue_redraw()


## Where the mouse has to be: over the chips as they are now.
func _reach() -> Rect2:
	var layout := _spread if _hover else _folded
	var reach := Rect2(_more_at, _more.size) if not _hover else Rect2(layout[_order[0]])
	for status_id: StringName in (_order if _hover else _order.slice(0, limit)):
		reach = reach.merge(layout[status_id])
	return reach.grow(REACH)
