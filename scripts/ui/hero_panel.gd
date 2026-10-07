class_name HeroPanel
extends Control
## The bottom band: the viewing player's hand, inventory, and the row of the
## other characters of the match, which the player can only claim as a bluff.
## The characters in the hand are claimed by clicking the hand itself.

signal character_clicked(def: CharacterDef, view: CardView)
signal item_clicked(instance: ItemInstance, view: ItemView)
signal end_turn_pressed
signal extra_pressed(option: Dictionary)

const StatusFx := preload("res://scripts/ui/status_fx.gd")
const SIZE := Vector2(1152, 170)
const MAX_EXTRAS := 3
const STRIP_SCALE := 0.92
## Room for the strip, from its left edge to the END TURN button.
const STRIP_WIDTH := 572.0

var player: PlayerState
var engine: GameEngine

var _bg: Panel
var _name: Label
var _stats: StatBar
var _chips: StatusChips
var _status_fx: StatusFx
var _inventory: HBoxContainer
var _hand: Control
var _hand_cards: Array = []
var _hand_shown: Array = []
var _strip: Control
var _strip_cards: Dictionary = {}  # character id -> CardView
var _strip_shown: Variant  # character ids in the strip, null before it is built
var _strip_hint: Label
var _end_turn: Button
var _extras: VBoxContainer
var _options: Variant  # turn options while it is this player's move
var _items_shown := ""
var _active := false


func _init() -> void:
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg = Panel.new()
	_bg.size = SIZE + Vector2(0, 8)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	# The far side of the ring of stars: over the band, under what is written on it.
	_status_fx = StatusFx.new()
	add_child(_status_fx.back)

	_name = UI.label("", 20, UI.CREAM, true)
	_name.position = Vector2(14, 6)
	_name.size = Vector2(178, 26)  # the dynamite stands to its right
	_name.clip_text = true
	_name.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	add_child(_name)
	_stats = StatBar.new(22, 20)
	_stats.position = Vector2(14, 34)
	add_child(_stats)
	_chips = StatusChips.new()
	_chips.position = Vector2(14, 64)
	_chips.size = Vector2(210, 34)
	add_child(_chips)
	_inventory = HBoxContainer.new()
	_inventory.position = Vector2(14, 104)
	_inventory.add_theme_constant_override("separation", 6)
	add_child(_inventory)

	_hand = Control.new()
	_hand.position = Vector2(238, 8)
	_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hand)

	_strip_hint = UI.label("", 12, UI.MUTED)
	_strip_hint.position = Vector2(440, 6)
	add_child(_strip_hint)
	_strip = Control.new()
	_strip.position = Vector2(440, 28)
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_strip)

	_end_turn = UI.button("END TURN", UI.GOLD, 16)
	_end_turn.position = Vector2(1024, 28)
	_end_turn.size = Vector2(116, 42)
	_end_turn.pressed.connect(func(): end_turn_pressed.emit())
	TipLayer.attach(_end_turn, "Finish your turn without using a character ability.")
	add_child(_end_turn)
	_extras = VBoxContainer.new()
	_extras.position = Vector2(1024, 78)
	_extras.size = Vector2(116, 80)
	add_child(_extras)
	# The player's own box is the block on the left: the stars circle the
	# name and the hearts, the doll sits on the top edge of the band where the
	# block ends (a leg along it, a leg hanging into the gap before the hand)
	# and the dynamite stands beside the name.
	_status_fx.ring_centre = Vector2(116, 44)
	_status_fx.ring_reach = Vector2(110, 20)
	_status_fx.doll_foot = Vector2(232, 1)
	_status_fx.bomb_foot = Vector2(203, 46)
	add_child(_status_fx)
	_restyle()


func setup(game_engine: GameEngine) -> void:
	engine = game_engine
	_strip_shown = null
	sync()


## Rebuilds the strip when the hand changed: it lists every character of the
## match that is not in the hand.
func _sync_strip() -> void:
	var defs := engine.characters.filter(func(def: CharacterDef): return not player.has_character(def.id))
	var ids := defs.map(func(def: CharacterDef): return def.id)
	if _strip_shown != null and ids == _strip_shown:
		return
	_strip_shown = ids
	for child in _strip.get_children():
		_strip.remove_child(child)
		child.queue_free()
	_strip_cards.clear()
	# Up to eleven sit side by side; a bigger cast overlaps like a fanned hand
	# (the one under the mouse comes to the front) and drops the captions,
	# which would run into each other. The tooltip still names every card.
	var card_width := CardView.BASE.x * STRIP_SCALE
	var step := 60.0
	if defs.size() > 1:
		step = minf(step, (STRIP_WIDTH - card_width) / (defs.size() - 1))
	var captioned := step >= card_width
	for i in defs.size():
		var def: CharacterDef = defs[i]
		var card := CardView.new(STRIP_SCALE)
		card.position = Vector2(roundf(i * step), 0)
		card.set_card(def.id, true)
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.clicked.connect(func(): character_clicked.emit(def, card))
		_strip.add_child(card)
		_strip_cards[def.id] = card
		if not captioned:
			continue
		var caption := UI.label(def.display_name, 10, UI.MUTED)
		caption.position = Vector2(i * step - 6, 94)
		caption.size = Vector2(step + 12 - 4, 14)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.clip_text = true
		_strip.add_child(caption)


func _notification(what: int) -> void:
	# The strip captions and item notes were written in the old language.
	if what == NOTIFICATION_TRANSLATION_CHANGED and engine != null:
		_items_shown = ""
		setup(engine)


func bind(hero: PlayerState) -> void:
	player = hero
	_stats.coin_bias = 0
	_hand_shown = []
	_strip_shown = null
	_items_shown = ""
	visible = player != null
	sync()


## `options` are the engine's turn options while this player is choosing,
## null otherwise.
func set_turn(options: Variant) -> void:
	_options = options
	sync()


func set_active(value: bool) -> void:
	if _active != value:
		_active = value
		_restyle()


func sync() -> void:
	if player == null or engine == null:
		return
	_name.text = player.name if player.alive else Loc.t("%s (eliminated)") % player.name
	_stats.sync(player, engine.config.start_morale, true)
	_chips.sync(player, engine)
	_status_fx.sync(player, engine)
	_sync_hand()
	_sync_strip()
	_sync_inventory()

	var my_turn := _options != null
	_end_turn.disabled = not my_turn
	_strip_hint.text = ("YOUR MOVE: play a card from your hand, or bluff with one of these."
			if my_turn else "OTHER CHARACTERS IN THIS MATCH (click for details)")
	_strip_hint.add_theme_color_override("font_color", UI.GOLD if my_turn else UI.MUTED)
	for character_id: StringName in _strip_cards:
		var card: CardView = _strip_cards[character_id]
		card.modulate = Color.WHITE if my_turn else Color(0.72, 0.68, 0.66)

	UI.clear(_extras)
	if my_turn:
		# All of them are also listed in their character's menu; only so many
		# fit next to END TURN.
		var shown := _urgent_first(_options.extras).slice(0, MAX_EXTRAS)
		var compact := shown.size() > 2
		_extras.add_theme_constant_override("separation", 2 if compact else 4)
		for extra: Dictionary in shown:
			var cost: int = extra.get("cost", 0)
			var b := UI.button("%s (%d)" % [extra.label, cost] if cost > 0 else extra.label, UI.PURPLE, 11 if compact else 12)
			b.custom_minimum_size = Vector2(116, 26 if compact else 34)
			if compact:
				b.clip_text = true
			else:
				b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.disabled = not extra.enabled
			b.pressed.connect(func(): extra_pressed.emit(extra))
			TipLayer.attach(b, extra.get("description", "") + ("\n[color=%s]%s[/color]" % [UI.hex(UI.RED), extra.reason] if extra.get("reason", "") != "" else ""))
			_extras.add_child(b)


## `extras` with the ones that can't wait in front (see CharacterDef.turn_extras),
## otherwise in the order they came.
func _urgent_first(extras: Array) -> Array:
	var levels := []
	for extra: Dictionary in extras:
		if not levels.has(extra.get("priority", 0)):
			levels.append(extra.get("priority", 0))
	levels.sort()
	levels.reverse()
	var out := []
	for level: int in levels:
		out.append_array(extras.filter(func(extra: Dictionary) -> bool: return extra.get("priority", 0) == level))
	return out


func hand_center() -> Vector2:
	return _hand.global_position + Vector2(90, 78)


func coin_anchor() -> Vector2:
	return _stats.coin_center()


func stat_bar() -> StatBar:
	return _stats


## The middle of the inventory slot at `index`.
func item_spot(index: int) -> Vector2:
	return _inventory.global_position + Vector2(maxi(index, 0) * 64.0 + 29.0, 29.0)


func card_center(index: int) -> Vector2:
	if index >= 0 and index < _hand_cards.size():
		return _hand_cards[index].center()
	return hand_center()


func card(index: int) -> CardView:
	return _hand_cards[index] if index >= 0 and index < _hand_cards.size() else null


## The card that stands for a character on this panel: the one in the hand if
## the player holds it, the one in the strip otherwise.
func character_card(character_id: StringName) -> CardView:
	var held := player.cards.find(character_id) if player != null else -1
	return card(held) if held != -1 else _strip_cards.get(character_id)


func use_option(instance: ItemInstance) -> Variant:
	if _options == null:
		return null
	for option: Dictionary in _options.use:
		if option.item == instance:
			return option
	return null


func _sync_hand() -> void:
	while _hand_cards.size() > player.cards.size():
		_hand_cards.pop_back().queue_free()
	while _hand_cards.size() < player.cards.size():
		var card := CardView.new(1.55)
		card.position = Vector2(_hand_cards.size() * 95, 0)
		card.lift = 14.0
		card.note = "You hold this card."
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.clicked.connect(func(): character_clicked.emit(Content.character(card.card_id), card))
		_hand.add_child(card)
		_hand_cards.append(card)
	for i in player.cards.size():
		var changed: bool = i >= _hand_shown.size() or _hand_shown[i] != player.cards[i]
		_hand_cards[i].set_card(player.cards[i], true, changed and not _hand_shown.is_empty())
	_hand_shown = player.cards.duplicate()


func _sync_inventory() -> void:
	var signature := str(_options != null)
	for instance: ItemInstance in player.items:
		signature += "%s:%d," % [instance.def.id, instance.get_instance_id()]
	if signature == _items_shown:
		return
	_items_shown = signature
	UI.clear(_inventory)
	for slot in engine.config.inventory_limit:
		var frame := PanelContainer.new()
		frame.add_theme_stylebox_override("panel", UI.box(Color(UI.INK, 0.75), UI.BORDER.darkened(0.3), 2, 4, 3))
		frame.custom_minimum_size = Vector2(58, 58)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_inventory.add_child(frame)
		if slot >= player.items.size():
			continue
		var instance: ItemInstance = player.items[slot]
		var view := ItemView.new(0.8)
		view.set_item(instance.def)
		var option: Variant = use_option(instance)
		var usable: bool = option != null and option.enabled
		view.set_enabled(usable or instance.def.kind != ItemDef.Kind.ACTIVE)
		view.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if usable else Control.CURSOR_ARROW
		if instance.hidden:
			view.note = "Hidden from the other players."
		elif option != null and not option.enabled and instance.def.kind == ItemDef.Kind.ACTIVE:
			view.note = option.reason
		elif usable:
			view.note = "Click to use."
		view.clicked.connect(func(): item_clicked.emit(instance, view))
		frame.add_child(view)


func _restyle() -> void:
	var sb := UI.box(Color(UI.INK, 0.9), UI.GOLD if _active else UI.BORDER, 0, 0, 0)
	sb.border_width_top = 3
	_bg.add_theme_stylebox_override("panel", sb)
