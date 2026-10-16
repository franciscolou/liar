class_name SeatView
extends Control
## An opponent at the table: name, morale, coins, face-down hand, items, in a
## small framed case (brass corners, a plate for the name). Once eliminated
## the case is gone: what is left on the table is the cards they held, face
## up and gone dull, and their name.

signal clicked(player: PlayerState)
## One of the items in the box was clicked while they were up for picking
## (see set_item_pick).
signal item_clicked(index: int)
## One of the cards of the hand was clicked while they were up for picking
## (see set_card_pick).
signal card_clicked(index: int)
## The host chose what becomes of the seat of a player who left (see
## set_away): &"idle", &"bot" or &"kick".
signal away_chosen(mode: StringName)

const StatusFx := preload("res://scripts/ui/status_fx.gd")
const TurnClock := preload("res://scripts/ui/turn_clock.gd")
const Board := preload("res://scripts/ui/saloon_board.gd")
## What the box says about a player who left the room, by what is done about
## their seat (Room.away). A seat a bot plays is not covered at all.
const AWAY_TEXT := {
	&"idle": "DISCONNECTED",
	&"kick": "KICKED",
}
## The badge that says how the player stands in a question put to the whole
## table (see set_answer): its size, where it sits on the case, and a tick.
const BADGE := Vector2(22, 18)
const BADGE_AT := Vector2(-8, -9)
const TICK := [
	"......#",
	".....##",
	"#...##.",
	"##.##..",
	".###...",
	"..#....",
]
const SIZE := Vector2(176, 126)
const PX := 2.0
## The plate the name is written on, from the top of the case.
const PLATE := 22.0
## A corner bracket, as seen in the top left corner.
const BRACKET := [
	"#####",
	"#o##.",
	"##...",
	"##...",
	"#....",
]
## An eye in blocks: what the table draws in its button that shows every hand.
const EYE := [
	"...#####...",
	".##.....##.",
	"#...ooo...#",
	"#..ooPoo..#",
	"#...ooo...#",
	".##.....##.",
	"...#####...",
]
## How dull the cards of an eliminated player are, and how they lie.
const LEFT_TINT := Color(0.5, 0.46, 0.44)
const LEFT_TURN := 0.06
## How long the case takes to be dragged off the table, and how far it goes.
const LEAVE := 0.5
const LEAVE_REACH := 48.0

var player: PlayerState
var engine: GameEngine

var _bg: Control
var _edge := UI.BORDER
var _gone := false
## How many items the player may carry: a socket is drawn for each.
var _sockets := 0
var _glow: Panel
var _name: Label
var _stats: StatBar
var _cards: Array = []
var _card_row: Control
var _items: HBoxContainer
var _chips: StatusChips
var _status_fx: StatusFx
var _items_shown := ""
var _item_pick := false
## The red frames on the items while one of them is to be picked.
var _marks: Control
var _marks_pulse: Tween
var _card_pick := false
var _clock: TurnClock
## 0: not asked, 1: still thinking, 2: let it pass.
var _answer := 0
var _badge: Control
var _targetable := false
var _revealed := false
var _peekable := false
var _active := false
var _pulse: Tween
## The veil over the box of a player who left the room (see set_away).
var _away: Control
var _away_mode := &""
var _away_shown := []  # what the veil was last drawn for: [mode, choose]


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
	_bg = Control.new()
	_bg.size = SIZE
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.draw.connect(_draw_case)
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
	_marks = Control.new()
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_marks)
	_chips = StatusChips.new()
	_chips.position = Vector2(92, 80)
	_chips.size = Vector2(78, 40)
	add_child(_chips)

	# The doll sits inside the box, in its bottom right corner: its back to
	# the right side, a leg laid along the bottom edge and the other hanging
	# under it (thrown, it strikes the top corner and slides down). The
	# dynamite leans on the left side from outside. The stars circle the
	# whole box.
	_status_fx.ring_centre = Vector2(SIZE.x / 2.0, SIZE.y * 0.44)
	_status_fx.ring_reach = Vector2(SIZE.x / 2.0 + 26.0, 22.0)
	_status_fx.doll_foot = Vector2(SIZE.x - 17, SIZE.y - 3)
	_status_fx.doll_drop = Vector2(0, 44 - SIZE.y)
	_status_fx.doll_drain = SIZE / 2.0
	_status_fx.bomb_foot = Vector2(-9, SIZE.y + 1)
	_status_fx.chain_box = Rect2(Vector2.ZERO, SIZE)
	# The seal of an oath is set on the end of the name plate, over its top edge.
	_status_fx.seal_at = Vector2(SIZE.x - 22, 7)
	add_child(_status_fx)
	# The chips are for reading: nothing a status draws goes over them.
	move_child(_chips, -1)

	_clock = TurnClock.new()
	_clock.box = Rect2(Vector2.ZERO, SIZE)
	add_child(_clock)
	_badge = Control.new()
	_badge.position = BADGE_AT
	_badge.size = BADGE
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.visible = false
	_badge.draw.connect(_draw_badge)
	add_child(_badge)

	_away = Control.new()
	_away.position = Vector2(PX * 2.0, PLATE + PX * 2.0)
	_away.size = Vector2(SIZE.x - PX * 4.0, SIZE.y - PLATE - PX * 4.0)
	_away.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_away.visible = false
	add_child(_away)

	TipLayer.attach(self, _tip)

	mouse_entered.connect(_hover.bind(true))
	mouse_exited.connect(_hover.bind(false))
	_restyle()


func bind(seat_player: PlayerState, game_engine: GameEngine) -> void:
	player = seat_player
	engine = game_engine
	_name.text = player.name + ("  [BOT]" if player.is_bot else "")
	_sockets = engine.config.inventory_limit
	_bg.queue_redraw()
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
	if not player.alive and not _gone:
		leave()
	# Out of the match, what is shown is what they left on the table.
	var hand: Array = player.cards if player.alive else player.left
	while _cards.size() > hand.size():
		_cards.pop_back().queue_free()
	while _cards.size() < hand.size():
		var card := CardView.new(0.7)
		card.lift = 4.0
		card.clicked.connect(_on_card_clicked.bind(card))
		_card_row.add_child(card)
		_cards.append(card)
	for i in _cards.size():
		var card: CardView = _cards[i]
		if player.alive:
			card.position = Vector2(i * 41, 0)
			card.set_card(hand[i] if _revealed else &"", _revealed)
		elif not card.has_meta(&"laid"):
			_lay(i, true, 0.0)
	var signature := ""
	for instance: ItemInstance in player.items:
		signature += "%s%s," % [instance.def.id, "?" if instance.hidden else ""]
	if signature != _items_shown:
		_items_shown = signature
		UI.clear(_items)
		for instance: ItemInstance in player.items:
			var view := ItemView.new(0.4)
			view.set_item(instance.def, instance.hidden)
			view.clicked.connect(_on_item_clicked.bind(view))
			_items.add_child(view)
			UI.pop(view, 1.6)
		_mark_items()


## The player is out. The case and everything in it are dragged off the
## table, away from the middle of it; what stays is the cards, which slide
## to the middle of where it stood as it goes, and the name under them.
## With `face_up` they turn over on the way; without, each one waits for
## `turn_up` (the table shows them one by one first). `pace` is the speed
## the table is playing at.
func leave(face_up := true, pace := 1.0) -> void:
	if _gone:
		return
	_gone = true
	_targetable = false
	_peekable = false
	_revealed = false
	_active = false
	scale = Vector2.ONE
	_clock.left = -1.0
	set_answer(0)
	# Nothing stays floating over a box that is no longer there.
	_status_fx.die()
	set_away(&"", false)
	_set_cursor()
	_restyle()
	var parts: Array[Control] = [_bg, _stats, _items, _marks, _chips]
	if not is_inside_tree():
		for part in parts:
			part.hide()
		_name_under()
		return
	var time := LEAVE / maxf(pace, 0.01)
	var out := global_position + SIZE / 2.0 - get_viewport_rect().size / 2.0
	out = (out.normalized() if out.length() > 1.0 else Vector2.UP) * LEAVE_REACH
	for part in parts:
		var go := part.create_tween().set_parallel()
		go.tween_property(part, "position", part.position + out, time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		go.tween_property(part, "modulate:a", 0.0, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		go.chain().tween_callback(part.hide)
	var rename := _name.create_tween()
	rename.tween_property(_name, "modulate:a", 0.0, time * 0.4)
	rename.tween_callback(_name_under)
	rename.tween_property(_name, "modulate:a", 1.0, time * 0.6)
	for i in _cards.size():
		_lay(i, face_up, time)


## The name of somebody who is out goes under the cards they left.
func _name_under() -> void:
	_name.position = Vector2(8, 48 + CardView.BASE.y * 0.7 + 2)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.add_theme_color_override("font_color", UI.MUTED)


## Puts the card at `index` where it is left on the table: side by side with
## the others in the middle of the seat, none of them straight, gone dull.
## It gets there in `time` seconds, turning over as it goes if `face_up`.
func _lay(index: int, face_up: bool, time: float) -> void:
	var card: CardView = _cards[index]
	var place := Vector2((SIZE.x - 16 - _cards.size() * 41 + 2) / 2.0 + index * 41, 0)
	var turn := LEFT_TURN * (1.0 if index % 2 == 0 else -1.4)
	card.set_meta(&"laid", true)
	card.interactive = false
	card.pivot_offset = card.size / 2.0
	if face_up and index < player.left.size():
		card.set_card(player.left[index], true, time > 0.0)
	if time <= 0.0:
		card.position = place
		card.rotation = turn
		card.modulate = LEFT_TINT
		return
	var lay := card.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	lay.tween_property(card, "position", place, time)
	lay.tween_property(card, "rotation", turn, time)
	lay.tween_property(card, "modulate", LEFT_TINT, time)


## Turns the card left at `index` face up where it lies: the table has shown
## it to everybody and has just put it back down.
func turn_up(index: int) -> void:
	if index < 0 or index >= _cards.size() or index >= player.left.size():
		return
	_cards[index].set_card(player.left[index], true)
	_cards[index].modulate = LEFT_TINT


func set_active(value: bool) -> void:
	if _active == value:
		return
	_active = value
	_restyle()


## Puts the items of the box up for picking: each gets a red frame, and a
## click on one is told by `item_clicked`.
func set_item_pick(value: bool) -> void:
	if value == _item_pick:
		return
	_item_pick = value
	_mark_items()


func _mark_items() -> void:
	UI.clear(_marks)
	if _marks_pulse != null:
		_marks_pulse.kill()
	_marks.modulate.a = 1.0
	for view: ItemView in _items.get_children():
		view.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _item_pick else Control.CURSOR_ARROW
	if not _item_pick:
		return
	var item := ItemView.BASE * 0.4
	for i in player.items.size():
		var mark := Panel.new()
		mark.add_theme_stylebox_override("panel", UI.box(Color(UI.RED, 0.2), UI.RED, 1, 2, 0))
		mark.position = (_items.position + Vector2(i * (item.x + 2.0) - 2.0, -2.0)).round()
		mark.size = (item + Vector2(4, 4)).round()
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_marks.add_child(mark)
	_marks_pulse = create_tween().set_loops()
	_marks_pulse.tween_property(_marks, "modulate:a", 0.45, 0.45).set_trans(Tween.TRANS_SINE)
	_marks_pulse.tween_property(_marks, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE)


## The items in the box, as they lie: what the keyboard walks while one of
## them is being picked.
func item_views() -> Array:
	return _items.get_children()


## Puts the cards of the hand up for picking, face down as they are: each
## gets a red frame, and a click on one is told by `card_clicked`.
func set_card_pick(value: bool) -> void:
	if value == _card_pick:
		return
	_card_pick = value
	for card: CardView in _cards:
		if is_instance_valid(card):
			card.highlight(UI.RED if value and player.alive else null)
			card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if value else Control.CURSOR_ARROW


## The cards of the hand, as they lie.
func card_views() -> Array:
	return _cards.duplicate()


func _on_card_clicked(card: CardView) -> void:
	if _card_pick and player.alive:
		card_clicked.emit(_cards.find(card))


## Shows or hides what the player holds (an Untraceable takes it off the
## table for a moment: see PlayFx.vanish_items).
## The player left the room: the box says so and what is done about their
## seat (`mode`, see Room.away; &"" when they are here). Played by a bot, the
## box is left as it is. `choose` gives the host the buttons to have a bot
## play the seat until they come back, or to kick them out of the match.
func set_away(mode: StringName, choose: bool) -> void:
	if _gone or mode == &"bot":
		mode = &""
	if _away_shown == [mode, choose]:
		return
	_away_shown = [mode, choose]
	_away_mode = mode
	UI.clear(_away)
	_away.visible = mode != &""
	if mode == &"":
		return
	var veil := ColorRect.new()
	veil.color = Color(UI.INK, 0.84)
	veil.size = _away.size
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_away.add_child(veil)
	var title := UI.label(AWAY_TEXT.get(mode, AWAY_TEXT[&"idle"]), 15, UI.RED if mode == &"kick" else UI.GOLD, true)
	title.position = Vector2(0, 16)
	title.size = Vector2(_away.size.x, 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_away.add_child(title)
	if not choose or mode == &"kick":
		return
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.position = Vector2(0, _away.size.y - 30)
	row.size = Vector2(_away.size.x, 26)
	_away.add_child(row)
	var bot := UI.button("Bot", UI.GOLD, 12)
	Board.plank(bot, UI.GOLD)
	bot.custom_minimum_size = Vector2(66, 24)
	bot.pressed.connect(away_chosen.emit.bind(&"bot"))
	TipLayer.attach(bot, "A bot plays the seat until they come back.")
	row.add_child(bot)
	var kick := UI.button("Kick", UI.RED, 12)
	Board.plank(kick, UI.RED)
	kick.custom_minimum_size = Vector2(66, 24)
	kick.pressed.connect(away_chosen.emit.bind(&"kick"))
	TipLayer.attach(kick, "Takes them out of the match: their cards go back into the deck, and they cannot come back.")
	row.add_child(kick)


func set_items_shown(shown: bool) -> void:
	_items.modulate.a = 1.0 if shown else 0.0


## How much of the time of their turn is left, 1 to 0 (see turn_clock.gd);
## below 0 there is no clock.
func set_clock(left: float) -> void:
	_clock.left = -1.0 if _gone else left


## How the player stands in a question the whole table was asked at once:
## 0 not asked (no badge), 1 still thinking, 2 let it pass.
func set_answer(state: int) -> void:
	if _gone:
		state = 0
	if state == _answer:
		return
	_answer = state
	_badge.visible = state != 0
	_badge.queue_redraw()
	if state == 2:
		UI.pop(_badge, 1.5, 0.2)


func _process(_delta: float) -> void:
	# The dots of a badge that is still waiting go round.
	if _answer == 1:
		_badge.queue_redraw()


## The badge: three dots that light one after the other while the player
## thinks, a green tick once they have let it pass.
func _draw_badge() -> void:
	var passed := _answer == 2
	var edge := UI.GREEN if passed else UI.GOLD.darkened(0.2)
	_badge.draw_rect(Rect2(Vector2.ZERO, BADGE), UI.INK)
	_badge.draw_rect(Rect2(PX, PX, BADGE.x - PX * 2.0, BADGE.y - PX * 2.0), edge)
	_badge.draw_rect(Rect2(PX * 2.0, PX * 2.0, BADGE.x - PX * 4.0, BADGE.y - PX * 4.0), UI.PANEL)
	if passed:
		for y: int in TICK.size():
			for x: int in TICK[y].length():
				if TICK[y][x] == "#":
					_badge.draw_rect(Rect2(4 + x * PX, 3 + y * PX, PX, PX), UI.GREEN.lightened(0.2))
		return
	var lit := int(Time.get_ticks_msec() / 280.0) % 3
	for dot in 3:
		_badge.draw_rect(Rect2(5 + dot * 5, 8, PX, PX), UI.GOLD if dot == lit else UI.MUTED.darkened(0.3))


func _on_item_clicked(view: ItemView) -> void:
	if _item_pick:
		item_clicked.emit(view.get_index())


func set_targetable(value: bool) -> void:
	_targetable = value
	if not value:
		scale = Vector2.ONE
	_set_cursor()
	_restyle()


## Whether this hand is face up on screen: only for someone who is out of the
## match and looking on.
func is_revealed() -> bool:
	return _revealed


func set_revealed(value: bool) -> void:
	if _revealed == value:
		return
	_revealed = value
	for i in mini(_cards.size(), player.cards.size()):
		_cards[i].set_card(player.cards[i] if value else &"", value, true)


## Lets a click on the box reach the table when nobody is being targeted.
func set_peekable(value: bool) -> void:
	_peekable = value and not _gone
	_set_cursor()


func anchor() -> Vector2:
	return global_position + SIZE / 2.0


## The chip of status `id` on this player, null if it has none.
func status_chip(id: StringName) -> Control:
	return _chips.chip_of(id)


## A thrown doll's way to its place on this box (see StatusFx.doll_way), and
## its arrival there.
func doll_way() -> Array[Vector2]:
	return _status_fx.doll_way()


func doll_facing() -> float:
	return _status_fx.doll_facing


func doll_hangs() -> bool:
	return _status_fx.doll_hangs


func doll_landed() -> void:
	_status_fx.doll_landed()


## Whether status `id` came from a borrowed action (see StatusFx.set_borrowed).
func status_borrowed(id: StringName, on: bool) -> void:
	_status_fx.set_borrowed(id, on)


func status_is_borrowed(id: StringName) -> bool:
	return _status_fx.borrowed(id)


## Where the seal of an oath is set on this box, on screen.
func seal_spot() -> Vector2:
	return _status_fx.seal_spot()


## The gavel has just pressed the seal (see StatusFx.press_seal).
func seal_pressed() -> void:
	_status_fx.press_seal()


func seal_jolt() -> void:
	_status_fx.jolt_seal()


## The look of status `id` shows that it is about to be thrown away, or
## stops showing it (see StatusFx.threaten).
func status_threatened(id: StringName, on: bool) -> void:
	_status_fx.threaten(id, on)


## The player is out: whatever their statuses looked like comes apart (see
## StatusFx.die). Returns the looks that were showing.
func statuses_lost() -> Array[StringName]:
	return _status_fx.die()


## The points the look of status `id` breaks up from (see StatusFx.pieces).
func status_pieces(id: StringName) -> Array[Vector2]:
	return _status_fx.pieces(id)


## Where the Morale point at `index` is shown.
func heart_spot(index: int) -> Vector2:
	return _stats.heart_center(index)


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


func _set_cursor() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _targetable or _peekable else Control.CURSOR_ARROW


func _restyle() -> void:
	_edge = UI.BORDER
	if _targetable:
		_edge = UI.RED
	elif _active:
		_edge = UI.GOLD
	_bg.queue_redraw()
	_glow.add_theme_stylebox_override("panel", UI.box(Color(_edge, 0.22), Color(_edge, 0.6), 2, 9, 0))
	if _pulse != null:
		_pulse.kill()
	_glow.visible = (_active or _targetable) and not _gone
	if _glow.visible:
		_glow.modulate.a = 1.0
		_pulse = create_tween().set_loops()
		_pulse.tween_property(_glow, "modulate:a", 0.25, 0.55).set_trans(Tween.TRANS_SINE)
		_pulse.tween_property(_glow, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_SINE)


## The case: a dark board in a frame the colour of the player's state, an
## inlay just inside it, a plate across the top for the name and a brass
## bracket on every corner.
func _draw_case() -> void:
	var w := SIZE.x
	var h := SIZE.y
	var lit := _active or _targetable
	var rim := PX * (2.0 if lit else 1.0)
	_bg.draw_rect(Rect2(Vector2.ZERO, SIZE), Color(UI.INK, 0.95))
	_bg.draw_rect(Rect2(rim, rim, w - rim * 2.0, h - rim * 2.0), Color(UI.PANEL, 0.93))
	# The plate, a shade lighter than the board, and the rule under it.
	_bg.draw_rect(Rect2(rim, rim, w - rim * 2.0, PLATE - rim), Color(1, 1, 1, 0.045))
	_bg.draw_rect(Rect2(8, PLATE, w - 16, PX), Color(_edge, 0.55))
	_bg.draw_rect(Rect2(8, PLATE + PX, w - 16, PX), Color(0, 0, 0, 0.3))
	for x: float in [8.0, w - 8.0 - PX * 2.0]:
		_bg.draw_rect(Rect2(x, PLATE - PX, PX * 2.0, PX * 3.0), Color(_edge, 0.8))
	# The frame, lit from the top left, and the inlay.
	for edge: Rect2 in [Rect2(0, 0, w, rim), Rect2(0, 0, rim, h)]:
		_bg.draw_rect(edge, _edge)
	for edge: Rect2 in [Rect2(0, h - rim, w, rim), Rect2(w - rim, 0, rim, h)]:
		_bg.draw_rect(edge, _edge.darkened(0.3))
	var inlay := Color(_edge.darkened(0.45), 0.9)
	var gap := rim + PX
	for edge: Rect2 in [Rect2(gap, gap, w - gap * 2.0, PX / 2.0), Rect2(gap, h - gap - PX / 2.0, w - gap * 2.0, PX / 2.0),
			Rect2(gap, gap, PX / 2.0, h - gap * 2.0), Rect2(w - gap - PX / 2.0, gap, PX / 2.0, h - gap * 2.0)]:
		_bg.draw_rect(edge, inlay)
	# A socket for every item the player may carry, sunk into the board.
	var item := ItemView.BASE * 0.4
	for i in _sockets:
		var socket := Rect2(_items.position + Vector2(i * (item.x + 2.0) - 1.0, -1.0), item + Vector2(2, 2)).abs()
		socket = Rect2(socket.position.round(), socket.size.round())
		_bg.draw_rect(socket, Color(0, 0, 0, 0.34))
		_bg.draw_rect(Rect2(socket.position, Vector2(socket.size.x, 1)), Color(0, 0, 0, 0.5))
		_bg.draw_rect(Rect2(socket.position, Vector2(1, socket.size.y)), Color(0, 0, 0, 0.5))
		_bg.draw_rect(Rect2(socket.position.x, socket.end.y - 1, socket.size.x, 1), Color(_edge, 0.3))
		_bg.draw_rect(Rect2(socket.end.x - 1, socket.position.y, 1, socket.size.y), Color(_edge, 0.3))
		for corner: Vector2 in [socket.position, Vector2(socket.end.x - PX, socket.position.y),
				Vector2(socket.position.x, socket.end.y - PX), socket.end - Vector2(PX, PX)]:
			_bg.draw_rect(Rect2(corner, Vector2(PX, PX)), Color(UI.GOLD.darkened(0.35), 0.8))
	# Three studs at the foot of the board.
	for i in 3:
		_bg.draw_rect(Rect2(w / 2.0 - 7.0 + i * 6.0, h - gap - 5.0, PX, PX), Color(_edge, 0.45))
	var brass := UI.GOLD if lit else UI.GOLD.darkened(0.25)
	for corner in 4:
		var at := Vector2(w if corner % 2 == 1 else 0.0, h if corner >= 2 else 0.0)
		var way := Vector2(-1 if corner % 2 == 1 else 1, -1 if corner >= 2 else 1)
		for y: int in BRACKET.size():
			var row: String = BRACKET[y]
			for x: int in row.length():
				if row[x] == ".":
					continue
				var cell := at + Vector2(x, y) * PX * way
				cell -= Vector2(PX if way.x < 0.0 else 0.0, PX if way.y < 0.0 else 0.0)
				var ink := UI.CREAM if row[x] == "o" else (brass.darkened(0.45) if x == 0 or y == 0 else brass)
				_bg.draw_rect(Rect2(cell, Vector2(PX, PX)), ink)


func _tip() -> String:
	if not _peekable:
		return ""
	return Loc.t("Click to hide this hand.") if _revealed else Loc.t("Click to see this hand.")


func _hover(inside: bool) -> void:
	if _targetable:
		create_tween().tween_property(self, "scale", Vector2.ONE * (1.07 if inside else 1.0), 0.08)


func _gui_input(event: InputEvent) -> void:
	if (_targetable or _peekable) and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(player)
