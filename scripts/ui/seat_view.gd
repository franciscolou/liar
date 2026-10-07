class_name SeatView
extends Control
## An opponent at the table: name, morale, coins, face-down hand, items.

signal clicked(player: PlayerState)

const StatusFx := preload("res://scripts/ui/status_fx.gd")
const SIZE := Vector2(176, 126)

var player: PlayerState
var engine: GameEngine

var _bg: Panel
var _glow: Panel
var _name: Label
var _stats: StatBar
var _cards: Array = []
var _card_row: Control
var _items: HBoxContainer
var _chips: StatusChips
var _status_fx: StatusFx
var _dead_tag: Label
var _items_shown := ""
var _targetable := false
var _active := false
var _pulse: Tween


func _init() -> void:
	size = SIZE
	custom_minimum_size = SIZE
	pivot_offset = SIZE / 2.0
	mouse_filter = Control.MOUSE_FILTER_STOP

	# The far side of a groggy player's ring of stars goes under the box.
	_status_fx = StatusFx.new()
	add_child(_status_fx.back)

	_glow = Panel.new()
	_glow.position = Vector2(-5, -5)
	_glow.size = SIZE + Vector2(10, 10)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.visible = false
	add_child(_glow)
	_bg = Panel.new()
	_bg.size = SIZE
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	_name = UI.label("", 16, UI.CREAM, true)
	_name.position = Vector2(8, 3)
	_name.size = Vector2(SIZE.x - 16, 20)
	_name.clip_text = true
	_name.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	add_child(_name)
	_stats = StatBar.new(16, 15)
	_stats.position = Vector2(8, 24)
	add_child(_stats)

	_card_row = Control.new()
	_card_row.position = Vector2(8, 48)
	_card_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card_row)
	_items = HBoxContainer.new()
	_items.position = Vector2(92, 50)
	_items.add_theme_constant_override("separation", 2)
	_items.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_items)
	_chips = StatusChips.new()
	_chips.position = Vector2(92, 80)
	_chips.size = Vector2(78, 40)
	add_child(_chips)

	# The doll sits on the bottom right corner, one leg along the edge and one
	# over it, and the dynamite leans on the left one from outside: neither
	# covers what the box says. The stars circle the whole box.
	_status_fx.ring_centre = Vector2(SIZE.x / 2.0, SIZE.y * 0.44)
	_status_fx.ring_reach = Vector2(SIZE.x / 2.0 + 26.0, 22.0)
	_status_fx.doll_foot = Vector2(SIZE.x - 3, SIZE.y)
	_status_fx.bomb_foot = Vector2(-9, SIZE.y + 1)
	add_child(_status_fx)

	_dead_tag = UI.label("ELIMINATED", 18, UI.RED, true)
	_dead_tag.position = Vector2(0, 70)
	_dead_tag.size = Vector2(SIZE.x, 24)
	_dead_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dead_tag.rotation = -0.12
	_dead_tag.visible = false
	add_child(_dead_tag)

	mouse_entered.connect(_hover.bind(true))
	mouse_exited.connect(_hover.bind(false))
	_restyle()


func bind(seat_player: PlayerState, game_engine: GameEngine) -> void:
	player = seat_player
	engine = game_engine
	_name.text = player.name + ("  [BOT]" if player.is_bot else "")
	for card in _cards:
		card.queue_free()
	_cards.clear()
	_items_shown = ""
	sync()


func sync() -> void:
	if player == null:
		return
	_stats.sync(player, engine.config.start_morale)
	_chips.sync(player, engine)
	_status_fx.sync(player, engine)
	while _cards.size() > player.cards.size():
		_cards.pop_back().queue_free()
	while _cards.size() < player.cards.size():
		var card := CardView.new(0.7)
		card.lift = 4.0
		card.position = Vector2(_cards.size() * 41, 0)
		_card_row.add_child(card)
		_cards.append(card)
	var signature := ""
	for instance: ItemInstance in player.items:
		signature += "%s%s," % [instance.def.id, "?" if instance.hidden else ""]
	if signature != _items_shown:
		_items_shown = signature
		UI.clear(_items)
		for instance: ItemInstance in player.items:
			var view := ItemView.new(0.4)
			view.set_item(instance.def, instance.hidden)
			_items.add_child(view)
			UI.pop(view, 1.6)
	_dead_tag.visible = not player.alive
	modulate = Color.WHITE if player.alive else Color(0.5, 0.45, 0.45, 0.85)


func set_active(value: bool) -> void:
	if _active == value:
		return
	_active = value
	_restyle()


func set_targetable(value: bool) -> void:
	_targetable = value
	if not value:
		scale = Vector2.ONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if value else Control.CURSOR_ARROW
	_restyle()


func anchor() -> Vector2:
	return global_position + SIZE / 2.0


func coin_anchor() -> Vector2:
	return _stats.coin_center()


func stat_bar() -> StatBar:
	return _stats


## The middle of the place the item at `index` of the inventory takes.
func item_spot(index: int) -> Vector2:
	var item := ItemView.BASE * 0.4
	return _items.global_position + Vector2(maxi(index, 0) * (item.x + 2.0) + item.x / 2.0, item.y / 2.0)


func card_center(index: int) -> Vector2:
	if index >= 0 and index < _cards.size():
		return _cards[index].center()
	return anchor()


func card(index: int) -> CardView:
	return _cards[index] if index >= 0 and index < _cards.size() else null


func _restyle() -> void:
	var border := UI.BORDER
	if _targetable:
		border = UI.RED
	elif _active:
		border = UI.GOLD
	_bg.add_theme_stylebox_override("panel", UI.box(Color(UI.PANEL, 0.93), border, 3 if _active or _targetable else 2, 6, 0))
	_glow.add_theme_stylebox_override("panel", UI.box(Color(border, 0.22), Color(border, 0.6), 2, 9, 0))
	if _pulse != null:
		_pulse.kill()
	_glow.visible = _active or _targetable
	if _glow.visible:
		_glow.modulate.a = 1.0
		_pulse = create_tween().set_loops()
		_pulse.tween_property(_glow, "modulate:a", 0.25, 0.55).set_trans(Tween.TRANS_SINE)
		_pulse.tween_property(_glow, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_SINE)


func _hover(inside: bool) -> void:
	if _targetable:
		create_tween().tween_property(self, "scale", Vector2.ONE * (1.07 if inside else 1.0), 0.08)


func _gui_input(event: InputEvent) -> void:
	if _targetable and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(player)
