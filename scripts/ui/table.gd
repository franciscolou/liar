extends Control
## The match screen. It owns a GameEngine and plays two roles for it:
## observer (present: animate every event) and the hands of the player
## (request: turn a Decision into clickable things and return the answer).

signal answered(value: Variant)

const ARC_CENTER := Vector2(576, 322)
const ARC_RADIUS := Vector2(450, 240)
## Where the opponents sit when they are too many for the arc (their boxes
## would overlap on it): one at each side and the others in a row along the
## top, left to right in turn order. By number of opponents.
const CROWDED_SEATS := {
	6: [Vector2(141, 262), Vector2(291, 92), Vector2(481, 82), Vector2(671, 82), Vector2(861, 92), Vector2(1011, 262)],
	7: [Vector2(141, 262), Vector2(196, 96), Vector2(386, 84), Vector2(576, 82), Vector2(766, 84), Vector2(956, 96), Vector2(1011, 262)],
}
const HelpPanel := preload("res://scripts/ui/help_panel.gd")
const ShopStall := preload("res://scripts/ui/shop_stall.gd")
const Board := preload("res://scripts/ui/saloon_board.gd")
const ChalkFx := preload("res://scripts/ui/chalk_fx.gd")
const CosmosPick := preload("res://scripts/ui/cosmos_pick.gd")
const WandPick := preload("res://scripts/ui/wand_pick.gd")
const Emotes := preload("res://scripts/ui/emotes.gd")
const SuspectBook := preload("res://scripts/ui/suspect_book.gd")
const Room := preload("res://scripts/net/room.gd")
const Jukebox := preload("res://scripts/ui/jukebox.gd")
const Transition := preload("res://scripts/ui/transition.gd")
const MENU_SCENE := "res://scenes/menu.tscn"
const END_SCENE := "res://scenes/end.tscn"
## How slow time runs while the blow that ends the match lands (see
## _last_blow), the seconds the music takes to drop out as it does, and the
## seconds the table takes to go dark afterwards.
const SLOW_MOTION := 0.375
const MUSIC_DROP := 0.45
const FADE_TO_BLACK := 2.0
## Loaded up front; the sound of each item ("item_<id>") is loaded on first use.
const SOUNDS := ["doubt", "damage", "breaking", "spend", "coin_1", "coin_2", "coin_3", "card_draw", "truth", "lie", "cancel", "heal", "item_get", "item_use"]
const SOUND_DIR := "res://assets/sounds/"
## Different clinks of a coin, played in turn so a pile does not sound like one note.
const COIN_SOUNDS := 3
## Most coins shown (and heard) flying for one change of coins.
const MAX_COINS_SHOWN := 12
## The highest the gavel of a perjury may strike: its head stands above that.
const PERJURY_FLOOR := 78.0
## Seconds a swindled coin takes to dance over to the Bard, and between one
## coin and the next.
const DANCE_TIME := 2.4
const DANCE_STAGGER := 0.16
## The doll's cut of a hexed player's coins: seconds winding into the doll,
## out of sight in it, on the way to its owner, and between two coins.
const HEX_GRAB := 0.55
const HEX_PAUSE := 0.1
const HEX_FLIGHT := 0.75
const HEX_STAGGER := 0.1
## Seconds a coin takes to fly, and between one coin and the next: far enough
## apart for each clink to be heard on its own.
const COIN_FLIGHT := 0.42
const COIN_STAGGER := 0.11
## The item whose use is staged as a spin of the cylinder (_anim_roulette).
const ROULETTE := &"roulette"
const ROULETTE_CENTRE := Vector2(576, 388)
## Seconds the cylinder spins, and the fewest players the sight passes over.
const ROULETTE_SPIN := 1.7
const ROULETTE_MIN_HOPS := 12
const SIGHT_ICON := "res://assets/target.png"
const COIN_ICON := "res://assets/ui/coin.png"
const HEART_ICON := "res://assets/ui/heart.png"
const PICK_SCALE := 1.9
## A peeked card held up to whoever peeks: how big (for a human, for a bot)
## and how far from them (from the hand on screen, from a seat).
## How a card looks tipped towards someone else: its length along the way to
## them (1: not at all) and how far it is sheared across it.
const PEEK_SQUASH := 0.6
const PEEK_SHEAR := 0.18
## Where, and how large, a card is shown when the table stops to look at it.
const SHOWN_SCALE := 2.5
const SHOWN_CENTRE := Vector2(576, 236)
## The chalk a play is marked on the table with, and how far from the box of
## its actor and of its target the mark starts and ends.
## The characters shown to an eliminated viewer: how big, and how wide a row.
const ONLOOKER_SCALE := 0.62
const ONLOOKER_WIDTH := 760.0
const CHALK_WHITE := Color("efe9dc")
const CHALK_RED := Color("e8705c")
const CHALK_START := 26.0
const CHALK_END := 12.0
const SHOP_HEIGHT := 106.0
const SHOP_TAB_WIDTH := 126.0  # folded: mini icons + deck
const SHOP_DECK_WIDTH := 62.0
const SHOP_TAB_ROW := 36.0  # folded: from one row of mini icons to the next
const SHOP_ITEM_Y := 18.0  # open: the top of the goods
## How far the goods of a reroll travel off their shelf and onto it.
const REROLL_TRAVEL := 34.0
const LOG_SIZE := Vector2(232, 136)
const LOG_HEADER := 18.0  # the strip with the fold button
const LOG_FOLDED := Vector2(24, 24)  # just the button
const LOG_FOLD_TIME := 0.16
## Where the balloon of an emote goes: its centre, from the top right corner
## of a seat, and on the table for the player at this screen (by the log).
const EMOTE_AT_SEAT := Vector2(-14, 8)
const EMOTE_AT_HERO := Vector2(270, 442)
## How far from there a balloon may land while the player has others up, and
## how many of the same emote can be heard at once.
const EMOTE_SCATTER := Vector2(16, 12)
const EMOTE_VOICES := 16

var engine: GameEngine
var viewer: PlayerState  # whose hand is on screen; null while spectating

var _speed := 1.0
var _room: Node  # the room the match is played in (room.gd); null offline
var _pending: Decision
## What a hovered LIAR! button is showing as about to be lost (see _threaten):
## [player, statuses], the chips turned red as [chip, its own stylebox], and
## what makes them beat.
var _threat_on: Array = []
var _threatened: Array = []
var _threat_pulse: Tween
var _handoff: Dictionary = {}  # a picked card waiting for its animation: {veil, player, card, lifted}
var _seats: Dictionary = {}  # player id -> SeatView
var _hero: HeroPanel
var _table: Control
var _arrows: Control  # under whatever the mouse is on (see _lift_hovered)
var _fx: Control
var _overlay: Control
var _shop: Control
var _shop_bg: ShopStall
var _shop_tab: Control  # what shows while folded
var _shop_body: Control  # what shows while open
var _shop_entries: Array = []  # {view, price, coin, mini, slot, def}; slot -1 = always on sale
var _shop_reroll: Button
var _shop_reroll_price: Label
var _shop_reroll_coin: TextureRect
var _shop_reroll_queasy: ShaderMaterial
var _shop_hint: Label
var _shop_width := 0.0
var _shop_open := false
var _shop_pinned := false
var _shop_tween: Tween
## What takes the place of the viewer's panel once they are out (see _clear_hud).
var _onlooker: Control
var _deck_label: Label
var _stage: PanelContainer
## Claims declared and not over yet: one made in answer to another is nested.
var _claims_open := 0
var _stage_stack: Array = []
var _prompt: PanelContainer
var _popup: Control
var _modal: Control
var _log: RichTextLabel
var _log_panel: Control
var _log_box: PanelContainer
var _log_toggle: Button
var _log_folded := false
var _log_fold := 0.0  # 0 = open, 1 = folded; tweened in between
var _log_tween: Tween
var _log_bottom := 470.0  # the log hangs from here, folded or not
var _emotes: Control  # the emote button above the log (emotes.gd); null while spectating
var _emote_bubbles: Dictionary = {}  # player id -> the last balloon they put up
var _turn_label: Label
var _sfx: Dictionary = {}
var _slowed := false
var _time_glide: Tween
var _play_fx: PlayFx
var _pause: Control
var _peek_all: Button  # for a viewer who is out of the match (see _sync_peek)
var _book: Control  # the book of suspicions (suspect_book.gd); null while spectating
var _book_toggle: Button
# The keyboard (see _key_stops): whether it is what the player is using, the
# set of stops it is walking and where in it, the control it is on, and the
# place it was left at in the sets that remember theirs.
var _keys_on := false
var _key_id := ""
var _key_row := 0
var _key_col := 0
var _key_node: Control
var _key_places: Dictionary = {}
var _key_since := 0
var _key_turn := -1
var _key_cursor: Control
var _key_in_shop := false
var _card_pick: Dictionary = {}  # the card pick that is open: {veil, cards}


func _ready() -> void:
	Settings.ensure_loaded()
	theme = UI.theme()
	if GameConfig.current == null:
		GameConfig.current = GameConfig.default_config()
	var config := GameConfig.current
	_speed = maxf(config.anim_speed, 0.1)

	engine = GameEngine.new()
	engine.setup(config)
	engine.tree = get_tree()
	engine.observers.append(self)
	_room = Room.current if Room.current != null and Room.current.in_match else null
	var mine: int = _room.my_match_seat() if _room != null else -1
	for p: PlayerState in engine.players:
		var controller: Controller
		if p.is_bot:
			controller = BotController.new()
		else:
			controller = HumanController.new()
			controller.room = _room
			# Offline the one person at the table is whoever is not a bot.
			if p.id == mine or (_room == null and viewer == null):
				controller.table = self
				viewer = p
			if _room != null and _room.hosting:
				controller.stand_in = _stand_in(p)
		controller.engine = engine
		controller.player = p
		engine.controllers[p.id] = controller
	if _room != null:
		_room.seat_left.connect(_on_seat_left)
		_room.out_of_step.connect(_on_out_of_step)

	_build()
	_hero.setup(engine)
	_hero.bind(viewer)
	_layout_seats()
	_sync()
	engine.run.call_deferred()


## The bot that plays `p` if they leave the room. It rolls dice of its own:
## the match's have to stay the same on every machine.
func _stand_in(p: PlayerState) -> BotController:
	var bot := BotController.new()
	bot.engine = engine
	bot.player = p
	bot.rng = RandomNumberGenerator.new()
	bot.rng.randomize()
	return bot


func _on_seat_left(seat: int) -> void:
	_log_line(Loc.t("%s left the room. A bot plays in their place.") % engine.players[seat].name, &"doubt_declared")


func _on_out_of_step(turn: int) -> void:
	_log_line(Loc.t("The machines stopped agreeing about this match (turn %d). The host should end it and deal again.") % turn, &"doubt_declared")


func _exit_tree() -> void:
	engine.abort()
	_set_time(1.0)
	# Wake whatever decision is pending so the engine coroutine can unwind.
	_pending = null
	answered.emit(null)
	if _room != null and is_instance_valid(_room):
		_room.release()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_retranslate.call_deferred()


## Redraws what was written in the previous language. Lines already in the
## log, and a decision that is already on screen, keep their wording.
func _retranslate() -> void:
	_restyle_shop()
	_render_stage()
	_show_turn()
	_sync()
	if _pending != null and _pending.player == viewer:
		match _pending.kind:
			Decision.Kind.DOUBT:
				_prompt_doubt(_pending)
			Decision.Kind.REACT:
				_prompt_react(_pending)


func _process(_delta: float) -> void:
	_lift_hovered()
	_track_keys()
	# A shop opened by hovering folds again once the mouse leaves it, unless
	# it was pinned, one of its menus is still up or the keyboard is in it.
	if not _shop_open or _shop_pinned or _popup.get_child_count() > 0 or _key_in_shop:
		return
	if not _shop.get_global_rect().grow(8.0).has_point(get_global_mouse_position()):
		_set_shop_open(false)


## The arrow of a play runs across the table, over whatever is in its way.
## What the mouse is on comes in front of it for as long as it stays there.
func _lift_hovered() -> void:
	var mouse := get_global_mouse_position()
	var boxes: Array = [_prompt, _stage, _log_panel, _shop]
	boxes.append_array(_seats.values())
	for box: Control in boxes:
		box.z_index = 1 if box.is_visible_in_tree() and box.get_global_rect().has_point(mouse) else 0


func _unhandled_key_input(event: InputEvent) -> void:
	UI.handle_fullscreen_key(event, get_window())
	if event.is_action_pressed("ui_cancel") and not _back_out():
		_toggle_pause()
	# 1 to 6: an emote, without opening the column.
	if _emotes != null and event is InputEventKey and event.pressed and not event.echo:
		var number: int = event.keycode - KEY_1 if event.keycode < KEY_KP_0 else event.keycode - KEY_KP_1
		if number >= 0 and number < Emotes.KINDS.size():
			_emotes.pick(number)
	if _book != null and not is_instance_valid(_pause) and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_B:
		_toggle_book()


func _input(event: InputEvent) -> void:
	# A right click anywhere lets go of a target being chosen.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if _choosing_target() and _back_out():
			get_viewport().set_input_as_handled()
	# The mouse takes over from the keyboard as soon as it is used.
	if (event is InputEventMouseMotion and event.relative != Vector2.ZERO) or (event is InputEventMouseButton and event.pressed):
		_keys_on = false
	elif event is InputEventKey or event is InputEventJoypadButton:
		_on_key(event)


func _choosing_target() -> bool:
	return _pending != null and _pending.kind == Decision.Kind.TARGET and _pending.cancellable


## Closes the most recent thing the player opened and can still take back: a
## menu, or the choice of a target. False if there was nothing to close.
func _back_out() -> bool:
	if _pause != null and is_instance_valid(_pause):
		return false
	if _popup.get_child_count() > 0:
		_close_popup()
		return true
	if _choosing_target():
		_answer(null)
		return true
	if _book != null and _book.is_open():
		_toggle_book()
		return true
	# A choice that hangs over the whole table, with a Cancel of its own.
	if _pending != null and _pending.kind == Decision.Kind.PICK and _pending.cancellable \
			and _pending.context.get("look") in [&"cosmos", &"wand"] and _modal.get_child_count() > 0:
		_answer(-1)
		return true
	return false


# === layout ===================================================================

func _build() -> void:
	var bg := TextureRect.new()
	bg.texture = UI.tex("res://assets/table.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.28)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	_table = _layer()
	_build_shop()
	_build_stage()
	_build_log()
	_build_emotes()

	_hero = HeroPanel.new()
	_hero.position = Vector2(0, 478)
	_hero.character_clicked.connect(_on_character_clicked)
	_hero.item_clicked.connect(_on_item_clicked)
	_hero.end_turn_pressed.connect(func(): _answer_turn({"kind": &"end"}))
	_hero.extra_pressed.connect(_answer_turn)
	add_child(_hero)

	_turn_label = UI.label("", 16, UI.GOLD, true)
	_turn_label.position = Vector2(12, 8)
	add_child(_turn_label)
	var menu := UI.button("MENU", UI.BORDER, 13)
	menu.position = Vector2(1072, 8)
	menu.size = Vector2(70, 28)
	menu.pivot_offset = menu.size / 2.0
	menu.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# Three bars before the word: what a menu looks like everywhere.
	menu.draw.connect(func() -> void:
		for bar in 3:
			menu.draw_rect(Rect2(9, 8 + bar * 5, 13, 2), UI.GOLD if menu.is_hovered() else UI.CREAM))
	menu.pressed.connect(_toggle_pause)
	TipLayer.attach(menu, "Pause, settings and quit (Esc).")
	add_child(menu)
	# A button like the menu's, with only an eye in it and what it does in
	# its tooltip: with a full table, one with words on it lay over the
	# boxes of the players up there.
	_peek_all = UI.button("", UI.BORDER, 13)
	_peek_all.position = Vector2(1008, 8)
	_peek_all.size = Vector2(30, 28)
	_peek_all.pivot_offset = _peek_all.size / 2.0
	_peek_all.visible = false
	_peek_all.draw.connect(_draw_peek_all)
	_peek_all.pressed.connect(_on_peek_all_pressed)
	TipLayer.attach(_peek_all, _peek_all_tip)
	add_child(_peek_all)

	_prompt = PanelContainer.new()
	_prompt.add_theme_stylebox_override("panel", UI.box(Color(UI.INK, 0.96), UI.GOLD, 3, 6, 10))
	_prompt.visible = false
	add_child(_prompt)

	_arrows = _layer()
	_fx = _layer()
	_play_fx = PlayFx.new(self)
	_fx.add_child(_play_fx)
	_overlay = _layer()
	_build_book()
	if _book == null:
		# Nothing between the eye and the menu.
		_peek_all.position.x = 1040
	_popup = _layer()
	_modal = _layer()
	# Above anything _lift_hovered brings forward.
	for layer: Control in [_fx, _overlay, _popup, _modal]:
		layer.z_index = 2
	if _book != null:
		_book.z_index = 2
	_key_cursor = _layer()
	_key_cursor.z_index = 3
	_key_cursor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_key_cursor.draw.connect(_draw_key_cursor)
	add_child(TipLayer.new())

	Jukebox.play(Jukebox.MATCH)
	for sound: String in SOUNDS:
		_load_sfx(sound)


func _layer() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c


## The shop (one for the whole table) sits folded in a corner next to the
## deck. Hovering opens it; clicking pins it open.
func _build_shop() -> void:
	var fixed := engine.fixed_items
	var stock := fixed.size() + engine.config.shop_slots
	_shop_width = 24.0 + stock * 80.0 + 72.0 + SHOP_DECK_WIDTH
	_shop = Control.new()
	_shop.size = Vector2(_shop_width, SHOP_HEIGHT)
	_shop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_table.add_child(_shop)
	_shop_bg = ShopStall.new()
	_shop_bg.tray = SHOP_DECK_WIDTH
	_shop_bg.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_shop_bg.mouse_entered.connect(_set_shop_open.bind(true))
	_shop_bg.gui_input.connect(_on_shop_bg_input)
	_shop.add_child(_shop_bg)

	# The deck stays put at the right end whether the shop is open or not.
	var deck_x := _shop_width - SHOP_DECK_WIDTH
	var deck := CardView.new(0.52)
	deck.position = Vector2(deck_x + 16, 24)
	deck.interactive = false
	deck.mouse_entered.connect(_set_shop_open.bind(true))
	_shop.add_child(deck)
	TipLayer.attach(deck, "[b]Deck[/b]\nCharacters nobody holds. The cards of eliminated players stay on the table.")
	var deck_title := UI.label("DECK", 11, UI.MUTED, true)
	deck_title.position = Vector2(deck_x + 14, 3)
	_shop.add_child(deck_title)
	_deck_label = UI.label("", 13, UI.CREAM, true)
	_deck_label.position = Vector2(deck_x + 12, 82)
	_deck_label.size = Vector2(38, 18)
	_deck_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop.add_child(_deck_label)

	_shop_tab = Control.new()
	_shop_tab.position = Vector2(_shop_width - SHOP_TAB_WIDTH, 0)
	_shop_tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shop.add_child(_shop_tab)
	var tab_title := UI.label("SHOP", 11, UI.GOLD, true)
	tab_title.position = Vector2(8, 3)
	_shop_tab.add_child(tab_title)

	_shop_body = Control.new()
	_shop_body.size = _shop.size
	_shop_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shop.add_child(_shop_body)
	if not fixed.is_empty():
		var always := UI.label("ALWAYS", 11, UI.GOLD, true)
		always.position = Vector2(12, 3)
		_shop_body.add_child(always)
		var divider := ColorRect.new()
		divider.color = UI.BORDER.darkened(0.3)
		divider.position = Vector2(12 + fixed.size() * 80 - 14, 16)
		divider.size = Vector2(2, 80)
		divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shop_body.add_child(divider)
	var title := UI.label("SHOP", 11, UI.MUTED, true)
	title.position = Vector2(12 + fixed.size() * 80, 3)
	_shop_body.add_child(title)
	_shop_hint = UI.label("", 10, UI.MUTED)
	_shop_hint.position = Vector2(12 + fixed.size() * 80 + 38, 4)
	_shop_body.add_child(_shop_hint)

	for i in stock:
		var x := 12.0 + i * 80.0
		var view := ItemView.new(0.9)
		view.position = Vector2(x, SHOP_ITEM_Y)
		view.clicked.connect(_on_shop_clicked.bind(i))
		view.picked.connect(_buy_now.bind(i))
		_shop_body.add_child(view)
		var coin := _shop_icon("res://assets/ui/coin.png", Vector2(x + 10, 82), Vector2(16, 16))
		_shop_body.add_child(coin)
		var price := _price_tag(Vector2(x + 30, 81))
		_shop_body.add_child(price)
		var mini := _shop_icon("", Vector2(8 + (i % 2) * 27, 22 + (i >> 1) * SHOP_TAB_ROW), ItemView.BASE * 0.4)
		_shop_tab.add_child(mini)
		_shop_entries.append({
			"view": view, "price": price, "coin": coin, "mini": mini,
			"slot": i - fixed.size() if i >= fixed.size() else -1,
			"def": fixed[i] if i < fixed.size() else null,
			# How each part looks to a groggy viewer: item, mini icon, price.
			"queasy": [UI.queasy(view.size, i * 1.9, 1.5), UI.queasy(mini.size, i * 1.9, 1.0), UI.queasy(price.size, i * 1.9 + 0.8)],
		})

	# The reroll is not one of the goods: it stands apart, past a divider.
	var reroll_x := 12.0 + stock * 80.0
	var apart := ColorRect.new()
	apart.color = UI.BORDER.darkened(0.3)
	apart.position = Vector2(reroll_x - 6, 16)
	apart.size = Vector2(2, 80)
	apart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shop_body.add_child(apart)
	_shop_reroll = Button.new()
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		_shop_reroll.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_shop_reroll.position = Vector2(reroll_x + 10, 24)
	_shop_reroll.size = Vector2(48, 48)
	_shop_reroll.pivot_offset = _shop_reroll.size / 2.0
	_shop_reroll.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_shop_reroll.draw.connect(_draw_reroll)
	_shop_reroll.pressed.connect(_on_reroll_pressed)
	TipLayer.attach(_shop_reroll, _reroll_tip)
	_shop_body.add_child(_shop_reroll)
	_shop_reroll_coin = _shop_icon("res://assets/ui/coin.png", Vector2(reroll_x + 16, 82), Vector2(16, 16))
	_shop_body.add_child(_shop_reroll_coin)
	_shop_reroll_price = _price_tag(Vector2(reroll_x + 36, 81))
	_shop_reroll_price.text = str(engine.config.reroll_cost)
	_shop_reroll_queasy = UI.queasy(_shop_reroll_price.size, stock * 1.9 + 0.8)
	_shop_body.add_child(_shop_reroll_price)
	_set_shop_open(false, true)


## The number next to a coin of the shop, level with the coin at `at`.
func _price_tag(at: Vector2) -> Label:
	var price := UI.label("", 15, UI.GOLD, true)
	price.position = at
	price.size = Vector2(30, 16)
	price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return price


## The reroll button: two arrows chasing each other, in the blocks of the stall.
func _draw_reroll() -> void:
	UI.draw_reroll(_shop_reroll)


func _shop_icon(path: String, at: Vector2, icon_size: Vector2) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = UI.tex(path)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.size = icon_size
	icon.position = at
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _set_shop_open(open: bool, instant := false) -> void:
	if open == _shop_open and not instant:
		return
	_shop_open = open
	_shop_tab.visible = not open
	_shop_body.visible = open
	# Folded, the little icons stand on two shelves; open, the goods share one.
	var shelves: Array[float] = [75.0]
	if not open:
		shelves = [48.0, 48.0 + SHOP_TAB_ROW]
	_shop_bg.shelves = shelves
	_restyle_shop()
	var width := _shop_width if open else SHOP_TAB_WIDTH
	var at := Vector2(_shop_width - width, 0)
	if _shop_tween != null:
		_shop_tween.kill()
	if instant:
		_shop_bg.position = at
		_shop_bg.size = Vector2(width, SHOP_HEIGHT)
		return
	_shop_body.modulate.a = 0.0
	_shop_tween = create_tween().set_parallel()
	_shop_tween.tween_property(_shop_bg, "position", at, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_shop_tween.tween_property(_shop_bg, "size", Vector2(width, SHOP_HEIGHT), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_shop_tween.tween_property(_shop_body, "modulate:a", 1.0, 0.12)


func _restyle_shop() -> void:
	_shop_bg.pinned = _shop_pinned
	_shop_hint.text = "pinned · click to unpin" if _shop_pinned else "click to keep open"


func _on_shop_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_shop_pinned = not _shop_pinned
		_set_shop_open(true)
		_restyle_shop()


func _build_stage() -> void:
	_stage = PanelContainer.new()
	# Clear of the seats on the far arc, and of whatever sits on their boxes.
	_stage.position = Vector2(356, 206)
	_stage.custom_minimum_size = Vector2(440, 132)
	_stage.size = _stage.custom_minimum_size
	_stage.add_theme_stylebox_override("panel", UI.box(Color(UI.INK, 0.93), UI.GOLD, 3, 6, 10))
	_stage.visible = false
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_table.add_child(_stage)


func _build_log() -> void:
	_log_panel = Control.new()
	_log_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_table.add_child(_log_panel)
	var style := UI.box(Color(UI.INK, 0.72), UI.BORDER.darkened(0.3), 2, 4, 6)
	style.content_margin_top = LOG_HEADER
	_log_box = PanelContainer.new()
	_log_box.add_theme_stylebox_override("panel", style)
	_log_panel.add_child(_log_box)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.add_theme_font_size_override("normal_font_size", 14)
	_log.add_theme_font_size_override("bold_font_size", 14)
	_log.custom_minimum_size = Vector2(LOG_SIZE.x - 16, LOG_SIZE.y - LOG_HEADER - 10)
	_log_box.add_child(_log)
	# Discreet on purpose: no frame, and nothing changes under the mouse.
	_log_toggle = Button.new()
	_log_toggle.focus_mode = Control.FOCUS_NONE
	_log_toggle.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_log_toggle.add_theme_font_size_override("font_size", roundi(16 * UI.FONT_SCALE))
	for state: String in ["normal", "hover", "pressed", "focus"]:
		_log_toggle.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		_log_toggle.add_theme_color_override(state, UI.MUTED)
	_log_toggle.text = "-"
	_log_toggle.size = Vector2(20, LOG_HEADER)
	_log_toggle.pressed.connect(_toggle_log)
	_log_panel.add_child(_log_toggle)
	_place_log(_log_fold)


func _toggle_log() -> void:
	_log_folded = not _log_folded
	if _log_tween != null:
		_log_tween.kill()
	_log_tween = create_tween()
	_log_tween.tween_method(_place_log, _log_fold, 1.0 if _log_folded else 0.0, LOG_FOLD_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## The panel shrinks into its bottom left corner. The text only shows fully
## open: it would hold the panel at its full size.
func _place_log(fold: float) -> void:
	_log_fold = fold
	var box := LOG_SIZE.lerp(LOG_FOLDED, fold)
	_log.visible = fold <= 0.0
	_log_panel.position = Vector2(8, _log_bottom - box.y)
	_log_panel.size = box
	_log_box.size = box
	_log_toggle.position = Vector2(box.x - 22, 0)
	if _emotes != null:
		_emotes.position = _log_panel.position - Vector2(0, Emotes.BUTTON.y + 4.0)


# === emotes ===================================================================

## Emotes are talk between the people at the table: they go round the room on
## their own, outside the match, and nothing in the engine knows about them.
func _build_emotes() -> void:
	if viewer == null:
		return
	_emotes = Emotes.new()
	_emotes.picked.connect(_send_emote)
	_table.add_child(_emotes)
	_place_log(_log_fold)
	if _room != null:
		_room.emoted.connect(_show_emote)
	for kind: Dictionary in Emotes.KINDS:
		var voice := _load_sfx("emote_" + kind.id)
		if voice != null:
			voice.max_polyphony = EMOTE_VOICES


func _send_emote(kind: int) -> void:
	if _room != null:
		_room.emote(kind)
	else:
		_show_emote(viewer.id, kind)


## The balloon of `kind` over the player at `seat`, with its sound. Nothing
## waits for the one before: balloons pile up, each a little off the last so
## that all of them show, and their sounds ring over each other.
func _show_emote(seat: int, kind: int) -> void:
	if seat < 0 or seat >= engine.players.size() or kind < 0 or kind >= Emotes.KINDS.size():
		return
	var p: PlayerState = engine.players[seat]
	var at := EMOTE_AT_HERO
	if p != viewer:
		var box: SeatView = _seats.get(p.id)
		if box == null:
			return
		at = box.position + Vector2(SeatView.SIZE.x, 0) + EMOTE_AT_SEAT
	if is_instance_valid(_emote_bubbles.get(seat)):
		# Only drawing: the dice of the match are not for this.
		at += Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * EMOTE_SCATTER
	var bubble := Emotes.Bubble.new(kind)
	bubble.position = (at - Emotes.Bubble.SIZE / 2.0).clamp(Vector2(4, 12), size - Emotes.Bubble.SIZE - Vector2(4, 4)).round()
	_fx.add_child(bubble)
	_emote_bubbles[seat] = bubble
	_play_sfx("emote_" + Emotes.KINDS[kind].id)


# === book of suspicions =======================================================

## The viewer's notes on who holds what (see suspect_book.gd): a button next
## to the menu's, the B key, and a board over the table, under its menus.
## It is only theirs: nothing of it goes through the engine or the room.
func _build_book() -> void:
	if viewer == null or not engine.config.suspect_book:
		return
	_book = SuspectBook.new()
	add_child(_book)
	_book.setup(engine, viewer)
	_book.closed.connect(func() -> void: _book_toggle.queue_redraw())
	_book.marked.connect(_play_sfx.bind("ui_key"))
	# A button like the menu's, with an open book in it.
	_book_toggle = UI.button("", UI.BORDER, 13)
	_book_toggle.position = Vector2(1040, 8)
	_book_toggle.size = Vector2(30, 28)
	_book_toggle.pivot_offset = _book_toggle.size / 2.0
	_book_toggle.draw.connect(_draw_book_toggle)
	_book_toggle.pressed.connect(_toggle_book)
	TipLayer.attach(_book_toggle, "[b]Suspicion book[/b]\nWho you think holds each card: your own notes, or the ones the book keeps for you (B).")
	add_child(_book_toggle)
	# Under the layers that were made before the book was.
	move_child(_book_toggle, _prompt.get_index())


func _toggle_book() -> void:
	_book.toggle()
	_play_sfx("card_draw")
	_book_toggle.queue_redraw()


func _draw_book_toggle() -> void:
	var ink := UI.GOLD if _book_toggle.is_hovered() or _book.is_open() else UI.CREAM
	var rows := [
		".###.###.",
		"#...#...#",
		"#.#.#.#.#",
		"#...#...#",
		"#.#.#.#.#",
		"#...#...#",
		".###.###.",
	]
	for y: int in rows.size():
		for x: int in rows[y].length():
			if rows[y][x] == "#":
				_book_toggle.draw_rect(Rect2(6 + x * 2, 7 + y * 2, 2, 2), ink)


func _layout_seats() -> void:
	var others := []
	var count := engine.players.size()
	var start := viewer.id + 1 if viewer != null else 0
	for i in count:
		var p: PlayerState = engine.players[(start + i) % count]
		if p != viewer:
			others.append(p)
	for id: int in _seats.keys():
		if viewer != null and id == viewer.id:
			_seats[id].queue_free()
			_seats.erase(id)
	# With a hand on screen the opponents share the far arc of the table; a
	# spectator sees everyone spread around the whole of it.
	var spread := minf(150.0, 45.0 * (others.size() - 1))
	var full_circle := viewer == null
	_log_bottom = 642.0 if full_circle else 470.0
	_place_log(_log_fold)
	_shop.position = Vector2(1144 - _shop_width, (642 if full_circle else 470) - SHOP_HEIGHT)
	for i in others.size():
		var p: PlayerState = others[i]
		var seat: SeatView = _seats.get(p.id)
		if seat == null:
			seat = SeatView.new()
			seat.bind(p, engine)
			seat.clicked.connect(_on_seat_clicked)
			seat.item_clicked.connect(_on_seat_item_clicked)
			_table.add_child(seat)
			_seats[p.id] = seat
		var degrees := 270.0
		if full_circle:
			degrees = 270.0 + 360.0 * i / others.size()
		elif others.size() > 1:
			degrees = 270.0 - spread / 2.0 + spread * i / (others.size() - 1)
		var angle := deg_to_rad(degrees)
		var radius := Vector2(410, 222) if full_circle else ARC_RADIUS
		var at := ARC_CENTER + Vector2(cos(angle), sin(angle)) * radius
		if not full_circle and CROWDED_SEATS.has(others.size()):
			at = CROWDED_SEATS[others.size()][i]
		seat.position = at - SeatView.SIZE / 2.0
	_set_active(engine.current)


# === decisions ================================================================

func request(d: Decision) -> Variant:
	_pending = d
	match d.kind:
		Decision.Kind.TURN:
			# A new turn: the keyboard starts from the hand again.
			if _key_turn != engine.turn_count:
				_key_turn = engine.turn_count
				_key_places.erase("turn")
			_hero.set_turn(d.options)
			_sync_shop()
		Decision.Kind.TARGET:
			_prompt_target(d)
		Decision.Kind.DOUBT:
			_prompt_doubt(d)
		Decision.Kind.REACT:
			_prompt_react(d)
		Decision.Kind.PICK:
			_open_pick(d)
	var value: Variant = await answered
	if engine.aborted:
		return await engine.ask(d)  # the engine's own "nobody answers" default
	_pending = null
	_hero.set_turn(null)
	_sync_shop()
	return value


## The engine gave up on `d`: someone else called LIAR! first.
func withdraw(d: Decision) -> void:
	if _pending == d:
		_answer(false)


func _answer(value: Variant) -> void:
	if _pending == null:
		return
	_close_popup()
	_hide_prompt()
	UI.clear(_modal)
	if TipLayer.current != null:
		TipLayer.current.hide_all()
	for seat: SeatView in _seats.values():
		seat.set_targetable(false)
		seat.set_item_pick(false)
	answered.emit(value)


func _answer_turn(option: Dictionary) -> void:
	if _pending != null and _pending.kind == Decision.Kind.TURN:
		_answer(option)


func _turn_options() -> Variant:
	if _pending != null and _pending.kind == Decision.Kind.TURN:
		return _pending.options
	return null


func _on_character_clicked(def: CharacterDef, view: CardView) -> void:
	var options: Variant = _turn_options()
	var rows := []
	for ability: Ability in def.abilities:
		var option: Variant = null
		if options != null:
			for candidate: Dictionary in options.abilities:
				if candidate.ability == ability:
					option = candidate
		if option == null:
			rows.append({"info": UI.ability_tip(ability)})
			continue
		var text := ability.display_name
		if option.get("detail", "") != "":
			text += "  ·  " + option.detail
		# What it costs right now: a status may have raised the price.
		var cost: int = option.get("cost", ability.cost)
		if cost > 0:
			text += "  ·  " + Loc.t("%d coins") % cost
		var tip := UI.ability_tip(ability)
		if option.reason != "":
			tip += "[color=%s]%s[/color]" % [UI.hex(UI.RED), option.reason]
		elif option.credit:
			tip += "[color=%s]%s[/color]" % [UI.hex(UI.BLUE), Loc.t("You can't afford it: you will also claim Vagabond (On the Cuff).")]
		rows.append({
			"text": text, "tip": tip, "enabled": option.enabled,
			"accent": UI.GREEN if option.legit else UI.RED,
			"action": _answer_turn.bind(option), "reason": option.reason,
			"note": ability.description,
		})
	if options != null:
		for extra: Dictionary in options.extras:
			if extra.get("character") != def.id:
				continue
			var cost: int = extra.get("cost", 0)
			rows.append({
				"text": extra.label + ("  ·  " + Loc.t("%d coins") % cost if cost > 0 else ""),
				"tip": extra.get("description", ""), "enabled": extra.enabled, "accent": UI.PURPLE,
				"action": _answer_turn.bind(extra), "reason": extra.get("reason", ""),
			})
	var held := viewer != null and viewer.has_character(def.id)
	var subtitle := "You hold this card: claiming it is the truth." if held else "Not in your hand: claiming it is a bluff."
	if viewer == null or not viewer.alive:
		subtitle = ""
	_open_popup(view.get_global_rect(), def.display_name.to_upper(), subtitle, UI.GREEN if held else UI.RED, rows)


func _on_shop_clicked(index: int) -> void:
	var entry: Dictionary = _shop_entries[index]
	var option: Variant = _buy_option(_turn_options(), entry)
	if option == null:
		return
	var def: ItemDef = option.item
	var tip := UI.item_tip(def)
	if option.reason != "":
		tip += "\n[color=%s]%s[/color]" % [UI.hex(UI.RED), option.reason]
	elif option.credit:
		tip += "\n[color=%s]%s[/color]" % [UI.hex(UI.BLUE), Loc.t("You can't afford it: you will claim Vagabond (On the Cuff).")]
	# The price is on the tag under the item already.
	_open_popup(entry.view.get_global_rect(), def.display_name.to_upper(), def.description, UI.MUTED, [{
		"text": "Buy", "tip": tip, "enabled": option.enabled,
		"accent": UI.GOLD, "action": _answer_turn.bind(option), "reason": option.reason,
	}], _buy_now.bind(index))


## Buys what is in a shop entry without asking again: a right click or a
## double click on it.
func _buy_now(index: int) -> void:
	var option: Variant = _buy_option(_turn_options(), _shop_entries[index])
	if option != null and option.enabled:
		_answer_turn(option)


func _on_reroll_pressed() -> void:
	var options: Variant = _turn_options()
	if options != null and options.reroll != null and options.reroll.enabled:
		_answer_turn(options.reroll)


func _reroll_tip() -> String:
	var cost := _price(engine.config.reroll_cost)
	var tip := Loc.t("[b]Reroll[/b]\nPay %d coins to replace every item in the shop slots.") % cost
	var kept := engine.fixed_items.map(func(def): return def.display_name)
	if not kept.is_empty():
		tip += " " + Loc.t("%s always stays on sale.") % Loc.t(" and ").join(kept)
	var options: Variant = _turn_options()
	if options == null:
		tip += "\n[color=%s]%s[/color]" % [UI.hex(UI.MUTED), Loc.t("Only on your turn.")]
	elif options.reroll != null and options.reroll.reason != "":
		tip += "\n[color=%s]%s[/color]" % [UI.hex(UI.RED), options.reroll.reason]
	elif options.reroll != null and options.reroll.credit:
		tip += "\n[color=%s]%s[/color]" % [UI.hex(UI.BLUE), Loc.t("You can't afford it: you will claim Vagabond (On the Cuff).")]
	return tip


## What sits in a shop entry right now (null for an empty slot).
func _entry_def(entry: Dictionary) -> ItemDef:
	return entry.def if entry.slot < 0 else engine.shop[entry.slot]


func _buy_option(options: Variant, entry: Dictionary) -> Variant:
	if options == null:
		return null
	var def := _entry_def(entry)
	for candidate: Dictionary in options.buy:
		if candidate.slot == entry.slot and candidate.item == def:
			return candidate
	return null


## Where an item bought from `slot` flies from.
func _shop_point(slot: int, def: ItemDef) -> Vector2:
	for entry: Dictionary in _shop_entries:
		if entry.slot == slot and (slot >= 0 or entry.def == def):
			return entry.view.center() if _shop_open else entry.mini.global_position + entry.mini.size / 2.0
	return _bank()


func _on_item_clicked(instance: ItemInstance, _view: ItemView) -> void:
	var option: Variant = _hero.use_option(instance)
	if option != null and option.enabled:
		_answer_turn(option)


## An item picked where it lies, in the box of whoever holds it (see _open_pick).
func _on_seat_item_clicked(index: int) -> void:
	if _pending != null and _pending.kind == Decision.Kind.PICK and _pending.context.has("held_by") \
			and index >= 0 and index < _pending.options.size():
		_answer(index)


func _on_seat_clicked(p: PlayerState) -> void:
	if _pending != null and _pending.kind == Decision.Kind.TARGET and _pending.options.has(p):
		_answer(p)
	elif _looking_on() and p.alive:
		var seat: SeatView = _seats[p.id]
		seat.set_revealed(not seat.is_revealed())
		_play_sfx("card_draw")
		_sync_peek()


## The viewer is out of the match: their side of the counter is cleared
## away. What stays on screen is the log, the shop and, where the hand was,
## the cards they left on the table and a row of the characters in the match,
## to look up what each one does.
func _clear_hud() -> void:
	if _onlooker != null:
		return
	_close_popup()
	_hide_prompt()
	# Hidden, not freed: it still says where the viewer's things were.
	var leave := _hero.create_tween()
	leave.tween_property(_hero, "modulate:a", 0.0, 0.4 / _speed)
	leave.tween_callback(_hero.hide)
	_onlooker = Control.new()
	_onlooker.position = _hero.position
	_onlooker.size = Vector2(1152, 170)
	_onlooker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_onlooker.modulate.a = 0.0
	_hero.add_sibling(_onlooker)
	_onlooker.create_tween().tween_property(_onlooker, "modulate:a", 1.0, 0.4 / _speed).set_delay(0.3 / _speed)

	var left: Array = viewer.left
	var mine := UI.label("YOUR LAST CARD" if left.size() == 1 else "YOUR LAST CARDS", 11, UI.MUTED, true)
	mine.position = Vector2(28, 34)
	_onlooker.add_child(mine)
	for i in left.size():
		var card := CardView.new(0.9)
		card.position = Vector2(28 + i * 56, 52)
		card.pivot_offset = card.size / 2.0
		card.rotation = 0.05 * (1.0 if i % 2 == 0 else -1.4)
		card.modulate = SeatView.LEFT_TINT
		card.interactive = false
		card.set_card(left[i], true)
		_onlooker.add_child(card)

	var cast := engine.characters
	var card_size := CardView.BASE * ONLOOKER_SCALE
	var step := 44.0
	if cast.size() > 1:
		step = minf(step, (ONLOOKER_WIDTH - card_size.x) / (cast.size() - 1))
	var row_width := card_size.x + step * maxi(cast.size() - 1, 0)
	# Never narrower than what is written across the top of it.
	var heading_text := Loc.t("CHARACTERS IN THIS MATCH (click for details)")
	var heading_width := UI.bold().get_string_size(heading_text, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(11 * UI.FONT_SCALE)).x
	var width := maxf(row_width, ceilf(heading_width)) + 24.0
	var shelf := Panel.new()
	shelf.add_theme_stylebox_override("panel", UI.box(Color(UI.INK, 0.88), UI.BORDER, 2, 6, 0))
	shelf.size = Vector2(width, card_size.y + 38.0)
	shelf.position = Vector2(roundf((1152 - width) / 2.0), 170 - shelf.size.y - 10.0)
	_onlooker.add_child(shelf)
	var heading := UI.label(heading_text, 11, UI.GOLD, true)
	heading.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Before the size, and the size only once it is in the tree: a label
	# that does not clip is never narrower than its text, as measured with
	# whatever font it has outside the tree.
	heading.clip_text = true
	shelf.add_child(heading)
	heading.position = Vector2(12, 5)
	heading.size = Vector2(width - 24.0, 14)
	for i in cast.size():
		var def: CharacterDef = cast[i]
		var card := CardView.new(ONLOOKER_SCALE)
		card.position = Vector2(roundf((width - row_width) / 2.0 + i * step), 24)
		card.lift = 5.0
		card.set_card(def.id, true)
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.clicked.connect(_on_character_clicked.bind(def, card))
		shelf.add_child(card)


## Whether the player at this screen was eliminated and may see the hands of
## the others. It changes nothing in the match: the faces are only drawn here.
func _looking_on() -> bool:
	return viewer != null and not viewer.alive


func _peekable_seats() -> Array:
	return _seats.values().filter(func(seat: SeatView) -> bool: return seat.player.alive)


func _on_peek_all_pressed() -> void:
	var seats := _peekable_seats()
	var reveal := not seats.all(func(seat: SeatView) -> bool: return seat.is_revealed())
	for seat: SeatView in seats:
		seat.set_revealed(reveal)
	_play_sfx("card_draw")
	_sync_peek()


## Whether every hand that may be looked at is face up on this screen.
func _all_hands_shown() -> bool:
	var seats := _peekable_seats()
	return not seats.is_empty() and seats.all(func(seat: SeatView) -> bool: return seat.is_revealed())


## An eye in blocks (SeatView.EYE), drawn in the button as the bars of
## the menu are, and struck through while every hand is shown.
func _draw_peek_all() -> void:
	var px := SeatView.PX
	var ink := UI.GOLD if _peek_all.is_hovered() else UI.CREAM
	var rows: Array = SeatView.EYE
	var at := ((_peek_all.size - Vector2(rows[0].length(), rows.size()) * px) / 2.0).floor()
	for y: int in rows.size():
		var row: String = rows[y]
		for x: int in row.length():
			if row[x] == "#" or row[x] == "o":
				_peek_all.draw_rect(Rect2(at + Vector2(x, y) * px, Vector2(px, px)), ink)
	if _all_hands_shown():
		for i in rows.size():
			_peek_all.draw_rect(Rect2(at + Vector2(2 + i, rows.size() - 1 - i) * px, Vector2(px, px)), UI.RED)


func _peek_all_tip() -> String:
	if _all_hands_shown():
		return Loc.t("[b]Hide all hands[/b]\nTurns every hand face down again.")
	return Loc.t("[b]Show all hands[/b]\nYou are out of the match: click a player to see their hand, or this eye to see them all.")


func _sync_peek() -> void:
	var on := _looking_on()
	var seats := _peekable_seats()
	_peek_all.visible = on and not seats.is_empty()
	_peek_all.queue_redraw()
	for seat: SeatView in _seats.values():
		seat.set_peekable(on and seat.player.alive)


func _prompt_target(d: Decision) -> void:
	for p: PlayerState in d.options:
		if _seats.has(p.id):
			_seats[p.id].set_targetable(true)
	var buttons := []
	if d.cancellable:
		buttons.append({"text": "Cancel", "action": _answer.bind(null)})
	_show_prompt("[b]%s[/b]\n[color=%s]%s[/color]" % [d.prompt, UI.hex(UI.MUTED), Loc.t("Click a highlighted player. Esc or right click cancels." if d.cancellable else "Click a highlighted player.")], buttons)


func _prompt_doubt(d: Decision) -> void:
	var play: Play = d.context.play
	var def := Content.character(play.ability().character_id)
	var text := _claim_line(play, "\n[color=%s]%s[/color]" % [UI.hex(UI.MUTED),
		Loc.t("You hold %d of the %d %s cards. Is it a lie?") % [d.player.cards.count(def.id), engine.copies_in_play(), def.display_name]])
	if d.options.is_empty():
		# Only here for what they may play instead (context.reactions).
		text += "\n[color=%s]%s[/color]" % [UI.hex(UI.RED), engine.blocked_reason(d.player, [&"doubt"])]
	elif not d.options.has(GameEngine.STAKE_COINS):
		text += "\n[color=%s]%s[/color]" % [UI.hex(UI.BLUE), Loc.t("You don't have the %d coins a wrong call costs: pick what you put on the line.") % engine.config.doubt_cost]
	if not d.options.is_empty():
		# What the call itself would cost, whoever turns out to be lying.
		for status_id: StringName in d.player.statuses:
			var warning: String = Content.statuses.get(status_id, {}).get("doubt_warning", "")
			if warning != "":
				text += "\n[color=%s]%s[/color]" % [UI.hex(UI.RED), Loc.t(warning)]
	var buttons := _doubt_buttons(d)
	for option: Dictionary in d.context.get("reactions", []):
		buttons.append(_reaction_button(option))
	buttons.append({"text": "Let it pass", "action": _answer.bind(false)})
	_show_prompt(text, buttons)


## What is being claimed, as the first lines of a doubt prompt. `private` goes
## right under the claim (what only the player being asked may read).
func _claim_line(play: Play, private := "") -> String:
	var def := Content.character(play.ability().character_id)
	var text := Loc.t("[b]%s[/b] claims [b][color=%s]%s[/color][/b]: %s%s.") % [
		play.actor.name, UI.hex(UI.GOLD), def.display_name.to_upper(), EventText.title(play), _on_target(play)]
	text += private
	if play.actor.has_status(&"truth_bound"):
		text += "\n[color=%s]%s[/color]" % [UI.hex(UI.GOLD), Loc.t("%s is Under Oath: a lie costs them every coin too.") % play.actor.name]
	return text


## One LIAR! button per stake `d.player` may put up: {text, stake, action...}.
func _doubt_buttons(d: Decision) -> Array:
	var play: Play = d.context.play
	var cost := engine.config.doubt_cost
	var stakes: Array = d.options
	var bluff := Loc.t("Call the bluff.\nIf %s lied, they lose 1 Morale and the ability fails.") % play.actor.name
	# What the call throws away, whoever turns out to be lying.
	var dooms: Array = d.player.statuses.keys().filter(func(status_id: StringName) -> bool:
		return Content.statuses.get(status_id, {}).has("doubt_warning"))
	var buttons := []
	for stake: StringName in stakes:
		var spec := {"text": "LIAR!", "stake": stake, "accent": UI.RED, "action": _answer.bind(stake)}
		if not dooms.is_empty():
			spec["dooms"] = {"player": d.player, "statuses": dooms}
		match stake:
			GameEngine.STAKE_COINS:
				spec["price"] = {"icon": COIN_ICON, "amount": str(cost), "color": UI.GOLD}
				spec["tip"] = bluff + "\n" + Loc.t("If it was true, you pay %d coins.") % cost
			GameEngine.STAKE_DEBT:
				# The fine goes on a tab, and the tab is a claim of its own.
				var vagabond := Content.character(&"vagabond").display_name
				var holds := d.player.has_character(&"vagabond")
				spec["text"] = "LIAR! on credit"
				spec["price"] = {"icon": COIN_ICON, "amount": str(cost), "color": UI.RED.lightened(0.15)}
				spec["tip"] = (bluff + "\n" + Loc.t("If it was true, you claim %s (On the Cuff) to go %d coins into debt, down to %d.") % [vagabond, cost, d.player.coins - cost]
						+ "\n[color=%s]%s[/color]" % [UI.hex(UI.GREEN if holds else UI.RED),
						Loc.t("You hold %s: this is the truth." if holds else "You don't hold %s: that claim is a bluff too, and anyone may call LIAR! on it.") % vagabond])
				if holds:
					spec["accent"] = UI.BLUE
				else:
					spec["shady"] = true
			GameEngine.STAKE_MORALE:
				spec["price"] = {"icon": HEART_ICON, "amount": "1", "color": UI.CREAM}
				spec["tip"] = bluff + "\n" + Loc.t("If it was true, you lose 1 Morale.")
				if d.player.morale <= 1:
					spec["tip"] += "\n[color=%s]%s[/color]" % [UI.hex(UI.RED), Loc.t("It is your last Morale: a wrong call eliminates you.")]
		buttons.append(spec)
	return buttons


## The button that answers a decision with reaction `option`.
func _reaction_button(option: Dictionary) -> Dictionary:
	if option.kind != &"ability":
		var item: ItemDef = option.item.def
		return {
			"text": Loc.t("Use %s") % item.display_name, "tip": UI.item_tip(item),
			"accent": UI.BLUE, "action": _answer.bind(option),
		}
	var ability: Ability = option.ability
	var def := Content.character(ability.character_id)
	var price: int = option.get("cost", ability.cost)
	var cost := "  ·  %d" % price if price > 0 else ""
	var tip := UI.ability_tip(ability)
	var accent := UI.GREEN if option.legit else UI.RED
	tip += Loc.t("You hold %s: this is the truth." if option.legit else "You don't hold %s: this is a bluff.") % def.display_name
	if option.credit:
		tip += "\n[color=%s]%s[/color]" % [UI.hex(UI.BLUE), Loc.t("You can't afford it: you will also claim Vagabond.")]
	return {
		"text": "%s: %s%s" % [def.display_name, ability.display_name, cost], "tip": tip,
		"accent": accent, "action": _answer.bind(option),
	}


func _prompt_react(d: Decision) -> void:
	var triggers := []
	var buttons := []
	for option: Dictionary in d.options:
		if option.kind == &"ability" and not triggers.has(option.ability.trigger_text):
			triggers.append(option.ability.trigger_text)
		buttons.append(_reaction_button(option))
	buttons.append({"text": "Pass", "action": _answer.bind(null)})
	var why := ". ".join(triggers)
	var event: GameEvent = d.context.get("event")
	if event != null and event.type == &"before_gain":
		why = Loc.t("%s is about to gain %d coins.") % [event.data.player.name, event.data.amount]
	_show_prompt("[b]%s[/b]\n[color=%s]%s[/color]" % [
		Loc.t("%s, you may react.") % d.player.name, UI.hex(UI.MUTED),
		why if why != "" else Loc.t("An opponent's ability is about to take effect.")], buttons)


func _open_pick(d: Decision) -> void:
	if d.options.all(func(option: Dictionary): return option.has("card")):
		_open_card_pick(d)
		return
	# The options are the items another player holds, in the order they lie in
	# that player's box: they are picked right there, with no menu.
	var holder: Variant = d.context.get("held_by")
	if holder is PlayerState and _seats.has(holder.id):
		_seats[holder.id].set_item_pick(true)
		_show_prompt("[b]%s[/b]\n[color=%s]%s[/color]" % [d.prompt, UI.hex(UI.MUTED), Loc.t("Click one of the highlighted items.")], [])
		return
	if d.context.get("look") == &"cosmos":
		# Not a window: the options hang in the dark (see cosmos_pick.gd).
		UI.clear(_modal)
		var sky := CosmosPick.new()
		sky.setup(d)
		sky.picked.connect(_answer)
		_modal.add_child(sky)
		_play_sfx("fx_stardust")
		return
	if d.context.get("look") == &"wand":
		var spots := _wand_spots(d)
		if not spots.is_empty():
			# Not a window either: the items float up where they lie (see wand_pick.gd).
			UI.clear(_modal)
			var show := WandPick.new()
			show.setup(d, spots, _price_ink())
			show.picked.connect(_answer)
			_modal.add_child(show)
			_play_sfx("fx_stardust")
			return
	var panel := _open_modal(d.prompt)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	for i in d.options.size():
		var option: Dictionary = d.options[i]
		var column := VBoxContainer.new()
		column.alignment = BoxContainer.ALIGNMENT_END
		column.add_theme_constant_override("separation", 6)
		row.add_child(column)
		var picture: Control = null
		if option.has("card"):
			picture = CardView.new(1.3)
			picture.set_card(option.card, true)
		elif option.has("item"):
			picture = ItemView.new(1.0)
			picture.set_item(option.item, option.get("hidden", false))
		if picture != null:
			picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			picture.clicked.connect(_answer.bind(i))
			column.add_child(picture)
		var b := UI.button(option.get("label", "?"), UI.GOLD, 14)
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.pressed.connect(_answer.bind(i))
		if picture == null and option.get("description", "") != "":
			TipLayer.attach(b, option.description)
		column.add_child(b)
	if d.cancellable:
		var cancel := UI.button("Cancel", UI.BORDER, 14)
		cancel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cancel.pressed.connect(_answer.bind(-1))
		panel.add_child(cancel)


## Where each item a Counterfeit may copy lies, and where it floats to while
## the player chooses: under the box of whoever holds it, side by side.
## [{option, from, to}], from the left of the screen to the right.
func _wand_spots(d: Decision) -> Array:
	var spots := []
	for p: PlayerState in engine.opponents(d.player):
		if not _seats.has(p.id):
			continue
		var held := []
		for i in p.items.size():
			var instance: ItemInstance = p.items[i]
			if instance.hidden:
				continue
			for o in d.options.size():
				if d.options[o].get("item") == instance.def:
					held.append({"option": o, "from": _item_spot(p, i)})
		var box: Rect2 = _seats[p.id].get_global_rect()
		var step := 56.0
		for i in held.size():
			var x := box.get_center().x + (i - (held.size() - 1) / 2.0) * step
			held[i]["to"] = Vector2(clampf(x, 30.0, size.x - 30.0), box.end.y + 36.0)
		spots.append_array(held)
	spots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.to.x < b.to.x)
	return spots


## Choosing among cards: no window, the table sinks into a dark red and the
## cards glide to the middle (out of the hand, when they are the viewer's own)
## and hover there until one is clicked.
func _open_card_pick(d: Decision) -> void:
	UI.clear(_modal)
	var veil := ColorRect.new()
	veil.color = Color(0.13, 0.015, 0.02, 0.0)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(veil)
	create_tween().bind_node(veil).tween_property(veil, "color:a", 0.88, 0.35 / _speed)

	var heading := UI.label(d.prompt, 22, UI.CREAM, true)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.position = Vector2(0, 118)
	heading.size = Vector2(1152, 30)
	heading.modulate.a = 0.0
	veil.add_child(heading)
	var late := [heading]

	var card_size := CardView.BASE * PICK_SCALE
	var count: int = d.options.size()
	var gap := 44.0
	var left := 576.0 - (count * card_size.x + (count - 1) * gap) / 2.0
	var lifted := []
	var cards := []
	for i in count:
		var option: Dictionary = d.options[i]
		var card := CardView.new(PICK_SCALE)
		card.set_card(option.card, true)
		card.lift = 14.0
		var rest := Vector2(left + i * (card_size.x + gap), 214)
		var own: bool = d.player == viewer and not d.context.get("foreign", false)
		var origin: CardView = _hero.card(i) if own else null
		if origin != null and origin.card_id == option.card and origin.face_up:
			card.position = origin.global_position
			card.scale = origin.size / card_size
			card.set_meta(&"origin", origin)
			origin.modulate.a = 0.0
			lifted.append(origin)
		else:
			card.position = rest + Vector2(0, 60)
			card.modulate.a = 0.0
		veil.add_child(card)
		cards.append(card)
		var name_tag := UI.label(option.get("label", ""), 16, UI.GOLD, true)
		name_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_tag.position = Vector2(-40, card_size.y + 12)
		name_tag.size = Vector2(card_size.x + 80, 22)
		name_tag.modulate.a = 0.0
		card.add_child(name_tag)
		late.append(name_tag)
		card.clicked.connect(_close_card_pick.bind(veil, cards, i))
		var glide := card.create_tween().set_parallel()
		card.set_meta(&"glide", glide)
		glide.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		var time := (0.55 + 0.07 * i) / _speed
		glide.tween_property(card, "position", rest, time)
		glide.tween_property(card, "scale", Vector2.ONE, time)
		glide.tween_property(card, "modulate:a", 1.0, time * 0.6)
		# Then a slow bob, each card a little out of step with its neighbour.
		glide.chain().tween_callback(func():
			if veil.has_meta(&"closing"):
				return
			var bob := card.create_tween().set_loops()
			card.set_meta(&"bob", bob)
			bob.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			bob.tween_property(card, "position:y", rest.y - 7.0, 1.3 + 0.17 * i)
			bob.tween_property(card, "position:y", rest.y + 3.0, 1.3 + 0.17 * i))
	# Whatever closes the pick, the hand gets its cards back.
	veil.tree_exiting.connect(func():
		if veil.has_meta(&"handed"):
			return
		for origin: CardView in lifted:
			if is_instance_valid(origin):
				origin.modulate.a = 1.0)

	if d.cancellable:
		var cancel := UI.button("Cancel", UI.BORDER, 14)
		cancel.position = Vector2(526, 470)
		cancel.custom_minimum_size = Vector2(100, 32)
		cancel.modulate.a = 0.0
		cancel.pressed.connect(_close_card_pick.bind(veil, cards, -1))
		veil.add_child(cancel)
		late.append(cancel)
	veil.set_meta(&"late", late)
	_card_pick = {"veil": veil, "cards": cards}
	var reveal := create_tween().bind_node(veil).set_parallel()
	for node: Control in late:
		reveal.tween_property(node, "modulate:a", 1.0, 0.3 / _speed).set_delay(0.3 / _speed)


## Closes a card pick. The cards left alone glide back to the hand; the chosen
## one moves on to the middle of the table, where the animation of whatever
## happens to it (traded, lost...) picks it up without a cut.
func _close_card_pick(veil: ColorRect, cards: Array, choice: int) -> void:
	if veil.has_meta(&"closing") or _pending == null:
		return
	veil.set_meta(&"closing", true)
	var d := _pending
	for card: CardView in cards:
		card.settle()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for key: StringName in [&"glide", &"bob"]:
			var moving: Tween = card.get_meta(key, null)
			if moving != null:
				moving.kill()
		card.modulate.a = 1.0
	var out := create_tween().bind_node(veil).set_parallel()
	# Cards from somewhere else have no animation waiting to pick them up.
	if choice < 0 or d.context.get("foreign", false):
		out.tween_property(veil, "modulate:a", 0.0, 0.28 / _speed)
		await out.finished
		if _pending == d:
			_answer(choice)
		return
	out.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	for node: Control in veil.get_meta(&"late"):
		out.tween_property(node, "modulate:a", 0.0, 0.2 / _speed)
	for i in cards.size():
		var card: CardView = cards[i]
		var origin: CardView = card.get_meta(&"origin", null)
		if i == choice:
			var grow := SHOWN_SCALE / PICK_SCALE
			out.tween_property(card, "position", SHOWN_CENTRE - card.size * grow / 2.0, 0.45 / _speed)
			out.tween_property(card, "scale", Vector2.ONE * grow, 0.45 / _speed)
		elif origin != null and is_instance_valid(origin):
			out.tween_property(card, "position", origin.global_position, 0.4 / _speed)
			out.tween_property(card, "scale", origin.size / card.size, 0.4 / _speed)
		else:
			out.tween_property(card, "modulate:a", 0.0, 0.2 / _speed)
	await out.finished
	if _pending != d:
		return
	var lifted := []
	for i in cards.size():
		var origin: CardView = cards[i].get_meta(&"origin", null)
		if origin == null or not is_instance_valid(origin):
			continue
		if i == choice:
			lifted.append(origin)
		else:
			origin.modulate.a = 1.0
			cards[i].visible = false
	# Out of the modal layer, which the answer wipes, to wait for that animation.
	veil.set_meta(&"handed", true)
	veil.reparent(_overlay)
	_handoff = {"veil": veil, "player": d.player, "card": d.options[choice].card, "lifted": lifted}
	_answer(choice)
	await _wait(0.6)
	if _handoff.get("veil") == veil:
		_take_pick_handoff(null, &"")


## Whether `card_id` of `p` is already in the middle of the table, left there
## by the card pick that just closed. Either way that pick's veil goes away.
func _take_pick_handoff(p: PlayerState, card_id: StringName) -> bool:
	if _handoff.is_empty():
		return false
	var handoff := _handoff
	_handoff = {}
	for origin: Variant in handoff.lifted:
		if is_instance_valid(origin):
			origin.modulate.a = 1.0
	var veil: ColorRect = handoff.veil
	if not is_instance_valid(veil):
		return false
	var fade := veil.create_tween()
	fade.tween_property(veil, "modulate:a", 0.0, 0.25 / _speed)
	fade.tween_callback(veil.queue_free)
	return p != null and handoff.player == p and handoff.card == card_id


# === prompt, popup, modal =====================================================

func _show_prompt(bbcode: String, buttons: Array) -> void:
	UI.clear(_prompt)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_prompt.add_child(row)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(360, 0)
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.text = bbcode
	row.add_child(text)
	for spec: Dictionary in buttons:
		var b := UI.button(spec.text, spec.get("accent", UI.BORDER), 16)
		b.custom_minimum_size = Vector2(96, 40)
		if spec.get("shady", false):
			_make_shady(b)
		if spec.has("price"):
			_add_price(b, spec.text, spec.price)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(spec.action)
		if spec.has("tip"):
			TipLayer.attach(b, spec.tip)
		if spec.has("dooms"):
			b.mouse_entered.connect(_threaten.bind(spec.dooms.player, spec.dooms.statuses, true))
			b.mouse_exited.connect(_threaten.bind(spec.dooms.player, spec.dooms.statuses, false))
		row.add_child(b)
	_prompt.visible = true
	_prompt.reset_size()
	await get_tree().process_frame
	_prompt.reset_size()
	_prompt.position = Vector2(576 - _prompt.size.x / 2.0, 474 - _prompt.size.y)
	UI.pop(_prompt, 1.08, 0.18)


## Puts "text [icon] amount" inside `b`, for a choice that costs something
## other than a plain number of coins. price: {icon, amount, color}.
func _add_price(b: Button, text: String, price: Dictionary) -> void:
	var ink: Color = b.get_theme_color("font_color") if b.has_theme_color_override("font_color") else UI.CREAM
	b.text = ""
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(UI.label(text, 16, ink))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(4, 0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)
	var icon := TextureRect.new()
	icon.texture = UI.tex(price.icon)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(16, 16)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	row.add_child(UI.label(price.amount, 16, price.color, true))
	b.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.custom_minimum_size.x = maxf(b.custom_minimum_size.x, row.get_combined_minimum_size().x + 24.0)


## A choice the player is allowed to make but shouldn't feel good about.
func _make_shady(b: Button) -> void:
	var edge := UI.RED.darkened(0.45)
	b.add_theme_stylebox_override("normal", UI.box(Color(UI.INK, 0.9), edge, 1, 4, 6))
	b.add_theme_stylebox_override("hover", UI.box(UI.INK.lightened(0.06), UI.RED.darkened(0.2), 1, 4, 6))
	b.add_theme_stylebox_override("pressed", UI.box(UI.INK, edge, 1, 4, 6))
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, UI.MUTED.darkened(0.2))


## A hand on a button that would cost `who` these statuses (or off it
## again): their looks and their chips go red on the box, so that it is seen
## before it is done. Nothing is asked: the call is as quick as ever.
func _threaten(who: PlayerState, statuses: Array, on: bool) -> void:
	var box: Variant = _node_of(who)
	if _threat_pulse != null:
		_threat_pulse.kill()
		_threat_pulse = null
	for entry: Array in _threatened:
		if is_instance_valid(entry[0]):
			entry[0].modulate = Color.WHITE
			entry[0].add_theme_stylebox_override("panel", entry[1])
	_threatened.clear()
	if box == null:
		return
	for status_id: StringName in statuses:
		box.status_threatened(status_id, on)
		var chip: Control = box.status_chip(status_id)
		if not on or chip == null:
			continue
		_threatened.append([chip, chip.get_theme_stylebox("panel")])
		chip.add_theme_stylebox_override("panel", UI.box(UI.RED.darkened(0.35), UI.RED.lightened(0.35), 1, 3, 3))
		if _threat_pulse == null:
			_threat_pulse = create_tween().set_loops()
		_threat_pulse.tween_property(chip, "modulate", Color(1.7, 1.5, 1.5), 0.12)
		_threat_pulse.tween_property(chip, "modulate", Color.WHITE, 0.12)
	_threat_on = [who, statuses] if on else []


func _hide_prompt() -> void:
	if not _threat_on.is_empty():
		_threaten(_threat_on[0], _threat_on[1], false)
	_prompt.visible = false
	UI.clear(_prompt)


## A small menu anchored to something on screen. rows: {info} for a text
## block, or {text, tip, enabled, accent, action, note, reason} for a button
## (`note`: a line under it saying what it does). `quick` is what a right
## click or the second click of a double click on the anchor does, in place
## of only closing the menu.
func _open_popup(anchor: Rect2, title: String, subtitle: String, subtitle_color: Color, rows: Array, quick := Callable()) -> void:
	_close_popup()
	var catcher := Control.new()
	catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			var again: bool = event.double_click or event.button_index == MOUSE_BUTTON_RIGHT
			_close_popup()
			if again and quick.is_valid() and anchor.has_point(event.global_position):
				quick.call())
	_popup.add_child(catcher)
	var panel := PanelContainer.new()
	Board.frame(panel, UI.BORDER, 14)
	_popup.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	box.add_child(UI.label(title, 18, UI.GOLD, true))
	if subtitle != "":
		var sub := UI.label(subtitle, 12, subtitle_color)
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.custom_minimum_size = Vector2(270, 0)
		box.add_child(sub)
	for spec: Dictionary in rows:
		if spec.has("info"):
			var info := RichTextLabel.new()
			info.bbcode_enabled = true
			info.fit_content = true
			info.scroll_active = false
			info.custom_minimum_size = Vector2(270, 0)
			info.mouse_filter = Control.MOUSE_FILTER_IGNORE
			info.text = spec.info.strip_edges()
			box.add_child(info)
			continue
		var b := UI.button(spec.text, spec.get("accent", UI.BORDER), 15)
		if not spec.has("accent"):
			Board.plank(b)
		b.custom_minimum_size = Vector2(270, 36)
		b.disabled = not spec.get("enabled", true)
		b.pressed.connect(spec.action)
		if spec.has("tip"):
			TipLayer.attach(b, spec.tip)
		box.add_child(b)
		if spec.get("note", "") != "":
			# What the button does, readable without hovering it.
			var note := UI.label(spec.note, 12, UI.MUTED if b.disabled else UI.CREAM)
			note.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			note.custom_minimum_size = Vector2(270, 0)
			box.add_child(note)
		if spec.get("reason", "") != "":
			box.add_child(UI.label(spec.reason, 12, UI.RED))
	panel.reset_size()
	await get_tree().process_frame
	if not is_instance_valid(panel):
		return
	panel.reset_size()
	var pos := Vector2(anchor.get_center().x - panel.size.x / 2.0, anchor.position.y - panel.size.y - 8)
	if pos.y < 6:
		pos.y = anchor.end.y + 8
	pos.x = clampf(pos.x, 6, size.x - panel.size.x - 6)
	panel.position = pos
	UI.pop(panel, 1.06, 0.15)


func _close_popup() -> void:
	UI.clear(_popup)


## Dims the table and returns a centred column to fill.
func _open_modal(title: String) -> VBoxContainer:
	UI.clear(_modal)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(dim)
	var panel := PanelContainer.new()
	Board.frame(panel, UI.BORDER, 22)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	dim.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var heading := UI.label(title, 20, UI.CREAM, true)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)
	return box


# === keyboard =================================================================

## What the keyboard can be on right now, or {} if there is nothing for it:
## {id, rows, upright, start, keep}. `rows` are rows of controls, walked with
## left and right, and from one row to the other with up and down; an
## `upright` set is one column, walked with up and down. Enter does to the
## control what a click would (_key_press). `start` is the control the
## keyboard begins on; a set with `keep` is taken up again where it was left.
func _key_stops() -> Dictionary:
	if engine == null or (_pause != null and is_instance_valid(_pause)):
		return {}
	if _popup.get_child_count() > 0:
		return {"id": "popup", "rows": [_buttons_in(_popup)], "upright": true}
	if _modal.get_child_count() > 0:
		var top := _modal.get_child(_modal.get_child_count() - 1)
		var buttons := _buttons_in(_modal)
		if top.has_method(&"views"):
			var views: Array = top.call(&"views")
			return {"id": "views", "rows": [views, buttons], "start": views.front() if not views.is_empty() else null}
		var veil: Variant = _card_pick.get("veil")
		if is_instance_valid(veil) and veil.get_parent() == _modal:
			if veil.has_meta(&"closing"):
				return {}
			return {"id": "cards", "rows": [_card_pick.cards, buttons]}
		return {"id": "modal", "rows": [buttons]}
	if _pending == null:
		return {}
	match _pending.kind:
		Decision.Kind.TURN:
			var goods := []
			for entry: Dictionary in _shop_entries:
				if _entry_def(entry) != null:
					goods.append(entry.view)
			if _shop_reroll.visible and not _shop_reroll.disabled:
				goods.append(_shop_reroll)
			return {"id": "turn", "rows": [goods, _hero.key_stops()], "start": _hero.card(0), "keep": true}
		Decision.Kind.TARGET:
			var seats := []
			for p: PlayerState in _pending.options:
				if _seats.has(p.id):
					seats.append(_seats[p.id])
			seats.sort_custom(func(a: Control, b: Control) -> bool: return a.position.x < b.position.x)
			return {"id": "target", "rows": [seats]}
		Decision.Kind.DOUBT, Decision.Kind.REACT:
			var buttons := _buttons_in(_prompt)
			# Letting it pass is the answer a stray Enter costs the least.
			return {"id": "prompt", "rows": [buttons], "start": buttons.back() if not buttons.is_empty() else null}
		Decision.Kind.PICK:
			var holder: Variant = _pending.context.get("held_by")
			if holder is PlayerState and _seats.has(holder.id):
				return {"id": "items", "rows": [_seats[holder.id].item_views()]}
	return {}


## Every button under `node` that can be pressed, in tree order.
func _buttons_in(node: Node) -> Array:
	var found := []
	for child: Node in node.get_children():
		if child is BaseButton and child.is_visible_in_tree() and not child.disabled:
			found.append(child)
		found.append_array(_buttons_in(child))
	return found


## An arrow or Enter. The first key after the mouse only shows where the
## keyboard is; from then on arrows move it and Enter presses what it is on.
func _on_key(event: InputEvent) -> void:
	var step := Vector2i.ZERO
	for way: Array in [["ui_left", Vector2i.LEFT], ["ui_right", Vector2i.RIGHT], ["ui_up", Vector2i.UP], ["ui_down", Vector2i.DOWN]]:
		if event.is_action_pressed(way[0], true):
			step = way[1]
	var enter := event.is_action_pressed("ui_accept")
	if step == Vector2i.ZERO and not enter:
		return
	var stops := _key_stops()
	if stops.is_empty():
		return
	get_viewport().set_input_as_handled()
	var rows: Array = stops.rows.filter(func(row: Array) -> bool: return not row.is_empty())
	if rows.is_empty():
		# A menu with nothing to press in it: Enter or down puts it away.
		if (enter or step == Vector2i.DOWN) and stops.id == "popup":
			_close_popup()
		return
	if not _keys_on:
		_keys_on = true
		_track_keys()
		return
	_track_keys()
	if enter:
		# Not the Enter that was meant for what was on screen a moment ago.
		if Time.get_ticks_msec() - _key_since > 250:
			_key_press(_key_node)
		return
	if stops.get("upright", false):
		if stops.id == "popup" and step.y != 0 and (_key_col + step.y < 0 or _key_col + step.y >= rows[_key_row].size()):
			# Down from the last button of a menu steps out of it, back to
			# what it was opened from; up from the first one stays there.
			if step.y > 0:
				_close_popup()
				_play_sfx("ui_key")
		elif step.y != 0:
			_key_col = posmod(_key_col + step.y, rows[_key_row].size())
			_play_sfx("ui_key")
	elif step.x != 0:
		_key_col = posmod(_key_col + step.x, rows[_key_row].size())
		_play_sfx("ui_key")
	elif rows.size() > 1:
		var to := clampi(_key_row + step.y, 0, rows.size() - 1)
		if to != _key_row:
			# The one straight above or below, as near as there is.
			var from: float = rows[_key_row][_key_col].get_global_rect().get_center().x
			var nearest := 0
			for i in rows[to].size():
				if absf(rows[to][i].get_global_rect().get_center().x - from) < absf(rows[to][nearest].get_global_rect().get_center().x - from):
					nearest = i
			_key_row = to
			_key_col = nearest
			_play_sfx("ui_key")
	_track_keys()


## Keeps the keyboard on a control of the set that is up now, and whatever
## it is on under a pretend mouse: lifted, lit and with its tooltip out.
func _track_keys() -> void:
	var stops := _key_stops() if _keys_on else {}
	var rows: Array = stops.get("rows", []).filter(func(row: Array) -> bool: return not row.is_empty())
	var on: Control = null
	var in_shop := false
	if not rows.is_empty():
		if stops.id != _key_id:
			_key_id = stops.id
			_key_since = Time.get_ticks_msec()
			var place: Vector2i = _key_places.get(_key_id, Vector2i(-1, -1)) if stops.get("keep", false) else Vector2i(-1, -1)
			if place.x < 0:
				place = Vector2i(rows.size() - 1, 0)
				for r in rows.size():
					var c: int = rows[r].find(stops.get("start"))
					if c != -1:
						place = Vector2i(r, c)
			_key_row = place.x
			_key_col = place.y
		_key_row = clampi(_key_row, 0, rows.size() - 1)
		_key_col = clampi(_key_col, 0, rows[_key_row].size() - 1)
		_key_places[_key_id] = Vector2i(_key_row, _key_col)
		on = rows[_key_row][_key_col]
		in_shop = _key_id == "turn" and rows.size() > 1 and _key_row == 0
	elif _keys_on:
		_key_id = ""
		# Between two choices of the same turn the shop stays as it was.
		in_shop = _key_in_shop and viewer != null and engine.current == viewer and not engine.over
	if in_shop != _key_in_shop:
		_key_in_shop = in_shop
		if in_shop:
			_set_shop_open(true)
	if on != _key_node:
		if _key_node != null and is_instance_valid(_key_node):
			_key_node.mouse_exited.emit()
		_key_node = on
		if on != null:
			on.mouse_entered.emit()
			# A menu says under each button what it does: no tooltip over it.
			if _key_id == "popup" and TipLayer.current != null:
				TipLayer.current.hide_all()
	_key_cursor.queue_redraw()


## What Enter does to the control the keyboard is on: what a click would.
func _key_press(node: Control) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node is BaseButton:
		if not node.disabled:
			node.pressed.emit()
	elif node is SeatView:
		_on_seat_clicked(node.player)
	elif node.has_signal(&"clicked"):
		node.emit_signal(&"clicked")


## Four brass corners round what the keyboard is on, breathing.
func _draw_key_cursor() -> void:
	if _key_node == null or not is_instance_valid(_key_node) or not _key_node.is_visible_in_tree():
		return
	var box: Rect2 = _key_node.get_global_rect()
	if _key_node is CardView:
		# The card itself, lifted out of its place.
		box = _key_node.get_child(0).get_global_rect()
	var breath := 3.0 + roundf(1.5 + 1.5 * sin(Time.get_ticks_msec() / 160.0))
	box = Rect2(box.position.round(), box.size.round()).grow(breath)
	var arm := minf(12.0, minf(box.size.x, box.size.y) / 3.0)
	for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var at := box.position + box.size * corner
		var inward := Vector2(1, 1) - corner * 2.0
		for pass_: int in 2:
			# A dark edge under the brass, to read on anything.
			var ink := UI.INK if pass_ == 0 else UI.GOLD
			var fat := 6.0 if pass_ == 0 else 2.0
			var off := (fat - 2.0) / 2.0
			for bar: Vector2 in [Vector2(arm, 2), Vector2(2, arm)]:
				var bar_size := bar + Vector2(off, off) * 2.0
				var corner_at := at - inward * off
				_key_cursor.draw_rect(Rect2(
						Vector2(corner_at.x if inward.x > 0 else corner_at.x - bar_size.x, corner_at.y if inward.y > 0 else corner_at.y - bar_size.y),
						bar_size), ink)


func _toggle_pause() -> void:
	if _pause != null and is_instance_valid(_pause):
		_pause.queue_free()
		_pause = null
		return
	if TipLayer.current != null:
		TipLayer.current.hide_all()
	_pause = ColorRect.new()
	_pause.color = Color(0, 0, 0, 0.7)
	_pause.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.z_index = 20
	add_child(_pause)
	var panel := PanelContainer.new()
	Board.frame(panel, UI.BORDER, 24)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_pause.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var heading: Control = Board.plaque("PAUSED", 26)
	box.add_child(heading)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 2)
	box.add_child(gap)
	var resume := UI.button("Resume", UI.GOLD, 18)
	Board.plank(resume, UI.GOLD)
	resume.custom_minimum_size = Vector2(240, 44)
	resume.pressed.connect(_toggle_pause)
	box.add_child(resume)
	var settings := UI.button("Settings", UI.BORDER, 18)
	Board.plank(settings)
	settings.pressed.connect(func(): _pause.add_child(SettingsPanel.new()))
	box.add_child(settings)
	var help := UI.button("How to play", UI.BORDER, 18)
	Board.plank(help)
	help.pressed.connect(func(): _pause.add_child(HelpPanel.new()))
	box.add_child(help)
	var fullscreen := UI.button("Fullscreen: on" if UI.is_fullscreen(get_window()) else "Fullscreen: off", UI.BORDER, 18)
	fullscreen.pressed.connect(func():
		UI.toggle_fullscreen(get_window())
		fullscreen.text = "Fullscreen: on" if UI.is_fullscreen(get_window()) else "Fullscreen: off")
	Board.plank(fullscreen)
	TipLayer.attach(fullscreen, "Also F11 or Alt+Enter, on any screen.")
	box.add_child(fullscreen)
	if _room != null and _room.hosting:
		var lobby := UI.button("End the match", UI.RED, 18)
		Board.plank(lobby, UI.RED)
		lobby.pressed.connect(_confirm.bind("End the match for everyone and take the whole room back to the lobby?", "End the match", _room.to_lobby))
		TipLayer.attach(lobby, "Stops the match for everyone and takes the whole room back to the lobby.")
		box.add_child(lobby)
	var quit := UI.button("Quit to menu", UI.RED, 18)
	Board.plank(quit, UI.RED)
	var leave := func() -> void:
		if Room.current != null:
			Room.current.leave()
		Transition.go(MENU_SCENE, Transition.DOORS, true)
	var asks := "Leave the match and go back to the menu?"
	if _room != null and _room.hosting:
		asks = "Leave the match and go back to the menu? The room closes for everyone."
	quit.pressed.connect(_confirm.bind(asks, "Quit to menu", leave))
	if _room != null:
		TipLayer.attach(quit, "Closes the room for everyone." if _room.hosting else "Leaves the room. A bot plays the rest of the match for you.")
	box.add_child(quit)


## Asks again before something that cannot be taken back: `question`, and
## two buttons, the one that goes ahead (`yes`, which runs `action`) and the
## one that does not. Shown over the pause menu.
func _confirm(question: String, yes: String, action: Callable) -> void:
	if _pause == null or not is_instance_valid(_pause):
		return
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0.7)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(veil)
	var panel := PanelContainer.new()
	Board.frame(panel, UI.RED, 24)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	veil.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	var text := UI.label(question, 18, UI.CREAM)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.custom_minimum_size = Vector2(360, 0)
	box.add_child(text)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	var back := UI.button("Cancel", UI.BORDER, 18)
	Board.plank(back)
	back.custom_minimum_size = Vector2(150, 44)
	back.pressed.connect(veil.queue_free)
	row.add_child(back)
	var go := UI.button(yes, UI.RED, 18)
	Board.plank(go, UI.RED)
	go.custom_minimum_size = Vector2(170, 44)
	go.pressed.connect(action)
	row.add_child(go)
	UI.pop(panel, 1.06, 0.15)


# === presentation =============================================================

func present(e: GameEvent) -> void:
	var line := EventText.describe(e)
	var d := e.data
	# The roulette names its victim only once the cylinder has stopped.
	var held_line: bool = e.type == &"item_used" and d.play.source.id == ROULETTE
	if line != "" and not held_line:
		_log_line(line, e.type)
	if _last_blow(e):
		_slow_time()
	match e.type:
		&"game_started":
			_sync()
			await _banner("WELCOME TO CARCAJ", "The last one standing takes the crown", UI.GOLD, 1.4)
		&"turn_started":
			_drop_transient_stage()
			_play_fx.drop_bets()
			_play_fx.drop_vanished()
			for q: PlayerState in engine.players:
				var bar := _stat_bar(q)
				if bar != null:
					bar.coin_bias = 0
			_set_active(d.player)
			_show_turn()
			if d.player == viewer:
				await _banner("YOUR TURN", "", UI.GOLD, 0.8)
			else:
				await _banner(Loc.t("%s'S TURN") % d.player.name.to_upper(), "", UI.CREAM, 0.55)
		&"coins":
			await _anim_coins(d)
		&"claim_declared":
			# A claim made in the middle of a borrowed action is nobody's copy.
			_claims_open += 1
			_play_fx.step_in(d.play)
			_test_oath(d.play.actor)
			await _anim_claim(d.play)
		&"doubt_declared":
			await _anim_doubt(d.doubter)
		&"doubt_revealed":
			await _anim_reveal(d.play, d.truthful)
		&"claim_cancelled":
			_play_sfx("cancel")
			await _stamp("SILENCED", UI.BLUE)
		&"claim_resolved":
			# A claim answering another one (a Silver Tongue caught lying, a
			# Swindle) ends in the middle of it: what the first left out on
			# the table is still waiting.
			_claims_open = maxi(_claims_open - 1, 0)
			if _claims_open == 0:
				_play_fx.put_away()
			_play_fx.step_out(d.play)
			if d.play.aimed() != d.play:
				# The Impostor's borrowed action is over, and so is its look.
				_play_fx.cleanse()
			await _pop_stage(d.play)
		&"item_buying":
			_sync_shop()
		&"item_bought":
			await _anim_item_bought(d)
		&"item_gained":
			await _anim_item_gained(d)
		&"targeted":
			_play_fx.last_attacker = d.play.actor
		&"play_effect":
			await _play_fx.play_effect(d.play)
		&"item_used":
			await _anim_item_used(d)
			if held_line:
				_log_line(line, e.type)
		&"item_broken":
			await _anim_item_broken(d)
		&"item_stolen":
			await _anim_item_stolen(d)
		&"item_missed":
			await _play_fx.rope_missed(d.thief, _item_spot(d.victim, 0))
		&"shop_restocked":
			_sync_shop()
			_pop_shop_slot(d.slot)
		&"shop_rerolled":
			await _anim_reroll()
		&"morale_lost":
			await _anim_damage(d.target, d.amount)
		&"morale_spent":
			await _anim_morale_spent(d)
		&"income":
			# Whatever is left of a broken Entropy has had its chance.
			_play_fx.chains_paid()
		&"morale_gained":
			var healed: Variant = _node_of(d.player)
			if healed != null and _play_fx.releasing(d.player):
				# Out of the chains of an Entropy.
				await _play_fx.release_morale(d.player, healed.heart_spot(d.player.morale - 1))
			_play_sfx("heal")
			_float(Loc.t("+%d MORALE") % d.amount, _anchor(d.player), UI.GREEN, 22)
			await _wait(0.4)
		&"player_eliminated":
			_float("ELIMINATED", _anchor(d.player), UI.RED, 28)
			_shake_screen(10.0)
			# What they held is shown to the table, card by card, and left
			# where they sat. Not after the last blow of the match: that is
			# the winner's moment.
			var shown_first := not engine.over
			# Their box is dragged off first and the cards stay behind: still
			# face down if they are about to be shown, turning over if not.
			# Whatever was on them goes first, as plain things with nobody
			# to be on: the chains just break, with none of the sky in it.
			var gone_box: Variant = _node_of(d.player)
			if gone_box != null:
				var lost: Array[StringName] = gone_box.statuses_lost()
				if lost.has(&"entropy"):
					_play_sfx("fx_chains_break")
				if lost.size() > (1 if lost.has(&"entropy") else 0):
					_play_sfx("status_break")
			var gone_seat: SeatView = _seats.get(d.player.id)
			if gone_seat != null:
				gone_seat.leave(not shown_first, _speed)
			await _wait(0.9)
			if shown_first:
				var hand: Array = []
				for i in d.player.left.size():
					hand.append(_card_view(d.player, i))
				for i in d.player.left.size():
					_set_cards_shown([hand[i]], false)
					await _anim_card_lost({"player": d.player, "card": d.player.left[i], "index": i}, true)
					if gone_seat != null and is_instance_valid(gone_seat):
						gone_seat.turn_up(i)
			_sync()
			if d.player == viewer:
				_log_line(Loc.t("You are out. Click a player to see their hand."), &"coins")
				_clear_hud()
		&"cards_changed":
			await _anim_card_traded(d)
		&"card_lost":
			await _anim_card_lost(d)
		&"card_drawn":
			_sync()
			await _anim_card_changed(d.player, d.index)
		&"cards_swapped":
			await _anim_cards_swapped(d)
		&"hand_redrawn":
			await _anim_hand_redrawn(d)
		&"cards_recalled":
			await _play_fx.cards_binned(d)
		&"coin_flipped":
			await _play_fx.coin_flip(d.player, d.heads, d.won)
		&"note":
			_float((Loc.t(d.text) % d.player.name).trim_suffix(".").to_upper(), _anchor(d.player) + Vector2(0, -24),
					UI.GREEN.lightened(0.25) if d.good else UI.MUTED, 16)
			if d.get("tag") == &"side_bet" and _play_fx.betting(d.player):
				# The stake goes back to who laid it, or to the house.
				await _play_fx.bet_settled(d.player, d.good)
			else:
				await _wait(0.45)
		&"card_peeked":
			await _play_fx.card_snatched(d)
			if d.viewer == viewer:
				# It was a quick look: what they saw stays written down.
				_log_line(Loc.t("You saw %s's %s.") % [d.owner.name, Content.character(d.card).display_name], &"coins")
		&"hand_missed":
			# The hand an Untraceable took off the table: whatever came for
			# it finds nothing, and only then are the cards back.
			if d.how == &"peek":
				await _play_fx.lurk_fooled(d)
			else:
				_float(Loc.t("NOTHING THERE"), _play_fx._hand_middle(d.owner), UI.MUTED, 16)
				await _wait(0.45)
			# Out of a Last Call they stay gone until the tray is taken
			# away (PlayFx.cards_binned).
			if d.how != &"recall":
				await _play_fx.hand_found(d.owner)
		&"status_added":
			# A status the Impostor copied keeps the look of the copy.
			var marked: Variant = _node_of(d.player)
			if marked != null:
				marked.status_borrowed(d.status, _play_fx.borrowing())
			if d.status == &"hexed" and _play_fx.doll_thrown_at(d.player):
				# The doll that was thrown becomes the one the player carries.
				_sync()
				_node_of(d.player).doll_landed()
				_play_fx.drop_doll(true)
			if d.status == &"entropy":
				# The chains are thrown on while the word is up.
				_sync()
				_play_sfx("fx_chains")
			var def: Dictionary = Content.statuses.get(d.status, {})
			_float(Loc.t(def.get("name", String(d.status))).to_upper(), _anchor(d.player), def.get("color", UI.PURPLE).lightened(0.35), 20)
			await _wait(0.65 if d.status == &"entropy" else 0.4)
		&"status_removed":
			await _anim_status_broken(d)
		&"counter_changed":
			var def: Dictionary = Content.counters.get(d.counter, {})
			if d.delta != 0 and (d.player == viewer or not def.get("private", false)):
				_float("%+d %s" % [d.delta, Loc.t(def.get("name", String(d.counter))).to_upper()], _anchor(d.player) + Vector2(0, -24), UI.BLUE, 18)
				await _wait(0.35)
		&"game_over":
			await _game_over(d.winner)
			return
	# Once the table has shown it: the book must not tell before the cards do.
	if _book != null:
		_book.record(e)
	_sync()


func _sync() -> void:
	for seat: SeatView in _seats.values():
		seat.sync()
	_hero.sync()
	_sync_shop()
	_sync_peek()


func _sync_shop() -> void:
	var options: Variant = _turn_options()
	var ink := _price_ink()
	var queasy := ink != UI.GOLD
	_shop_reroll_price.text = str(_price(engine.config.reroll_cost))
	_shop_reroll_price.add_theme_color_override("font_color", ink)
	_shop_reroll_price.material = _shop_reroll_queasy if queasy else null
	for entry: Dictionary in _shop_entries:
		var def := _entry_def(entry)
		for node: Control in [entry.view, entry.price, entry.coin, entry.mini]:
			node.visible = def != null
		if def == null:
			continue
		entry.view.set_item(def)
		entry.mini.texture = UI.tex(def.texture_path)
		entry.price.text = str(_price(def.price))
		entry.price.add_theme_color_override("font_color", ink)
		# The goods swim in front of a groggy viewer, and so does every
		# number the drink has raised.
		entry.view.set_look(entry.queasy[0] if queasy else null)
		entry.mini.material = entry.queasy[1] if queasy else null
		entry.price.material = entry.queasy[2] if queasy else null
		var option: Variant = _buy_option(options, entry)
		var buyable: bool = option == null or option.enabled
		entry.view.set_enabled(buyable)
		entry.mini.modulate = Color.WHITE if buyable else Color(0.55, 0.5, 0.5, 0.9)
		var notes := PackedStringArray()
		if entry.slot < 0:
			notes.append(Loc.t("Always on sale."))
		if option != null:
			notes.append(Loc.t("Double click or right click to buy.") if option.enabled else option.reason)
		entry.view.note = " ".join(notes)
	var reroll: Variant = options.reroll if options != null else null
	for node: Control in [_shop_reroll, _shop_reroll_coin, _shop_reroll_price]:
		node.visible = not engine.item_pool.is_empty()
	_shop_reroll.disabled = reroll == null or not reroll.enabled
	_shop_reroll.mouse_default_cursor_shape = Control.CURSOR_ARROW if _shop_reroll.disabled else Control.CURSOR_POINTING_HAND
	_deck_label.text = "x%d" % engine.deck.size()


## The goods of the slots leave their shelf, each one up or down, and the new
## ones come in the same way: the shelf is being rearranged, not repainted.
func _anim_reroll() -> void:
	var spin := _shop_reroll.create_tween()
	_shop_reroll.rotation = 0.0
	spin.tween_property(_shop_reroll, "rotation", TAU, 0.55 / _speed).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	spin.tween_callback(_shop_reroll.set.bind("rotation", 0.0))
	_play_sfx("card_draw")
	var moved: Array = []  # {node, home, way, travel, delay}
	var order := 0
	for entry: Dictionary in _shop_entries:
		if entry.slot < 0:
			continue
		# Only drawing: the dice of the match stay out of it.
		var way := -1.0 if randf() < 0.5 else 1.0
		var delay := order * 0.05
		for part: Array in [[entry.view, SHOP_ITEM_Y, REROLL_TRAVEL], [entry.mini, entry.mini.position.y, 16.0]]:
			var node: Control = part[0]
			var home: float = part[1]
			var travel: float = part[2]
			moved.append({"node": node, "home": home, "way": way, "travel": travel, "delay": delay})
			var out := node.create_tween().set_parallel()
			out.tween_property(node, "position:y", home + way * travel, 0.16 / _speed) \
					.set_delay(delay / _speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			out.tween_property(node, "modulate:a", 0.0, 0.16 / _speed).set_delay(delay / _speed)
		for tag: Control in [entry.price, entry.coin]:
			tag.create_tween().tween_property(tag, "modulate:a", 0.0, 0.12 / _speed)
		order += 1
	await _wait(0.16 + order * 0.05)
	_sync_shop()
	_play_sfx("card_draw")
	for move: Dictionary in moved:
		var node: Control = move.node
		# It comes in from the side the old one did not leave by.
		node.position.y = move.home - move.way * move.travel
		var back := node.create_tween().set_parallel()
		back.tween_property(node, "position:y", move.home, 0.22 / _speed) \
				.set_delay(move.delay / _speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		back.tween_property(node, "modulate:a", 1.0, 0.14 / _speed).set_delay(move.delay / _speed)
	for entry: Dictionary in _shop_entries:
		if entry.slot >= 0:
			for tag: Control in [entry.price, entry.coin]:
				tag.create_tween().tween_property(tag, "modulate:a", 1.0, 0.2 / _speed).set_delay(0.1 / _speed)
	await _wait(0.3 + order * 0.05)


func _pop_shop_slot(slot: int) -> void:
	for entry: Dictionary in _shop_entries:
		if entry.slot == slot:
			UI.pop(entry.view if _shop_open else entry.mini, 1.6, 0.3)


func _show_turn() -> void:
	if engine.current != null:
		_turn_label.text = Loc.t("TURN %d  ·  %s") % [engine.turn_count, engine.current.name.to_upper()]


func _set_active(p: PlayerState) -> void:
	for seat: SeatView in _seats.values():
		seat.set_active(seat.player == p)
	_hero.set_active(p != null and p == viewer)


func _log_line(line: String, type: StringName) -> void:
	var color := UI.CREAM
	match type:
		&"turn_started":
			color = UI.GOLD
		&"doubt_declared", &"morale_lost", &"player_eliminated":
			color = UI.RED
		&"claim_declared":
			color = UI.BLUE.lightened(0.3)
		&"coins":
			color = UI.MUTED
	_log.append_text("[color=%s]%s[/color]\n" % [UI.hex(color), line])


# --- the stage: what is being played right now --------------------------------

func _anim_claim(play: Play) -> void:
	var entry := {"play": play, "arrow": null, "transient": false}
	_push_stage(entry)
	var card: CardView = _hero.character_card(play.ability().character_id)
	if card != null and viewer != null:
		UI.pop(card, 1.25, 0.3)
	await _wait(0.8)


func _anim_item_used(d: Dictionary) -> void:
	var play: Play = d.play
	if _play_fx.has_effect(play):
		# Its own effect, sound included, comes when it takes effect (play_effect).
		_push_stage({"play": play, "arrow": null, "transient": true})
		await _wait(0.55)
		return
	_play_sfx("item_%s" % play.source.id, "item_use")
	if play.source.id == ROULETTE:
		await _anim_roulette(play)
		return
	_push_stage({"play": play, "arrow": null, "transient": true})
	await _wait(0.9)


## Russian roulette: the cylinder is spun while a sight hops from player to
## player, slower and slower, until it stops on the one the engine drew. Then
## the hammer, a held breath and the shot. Who gets it stays off the stage
## until the cylinder stops.
func _anim_roulette(play: Play) -> void:
	var entry := {"play": play, "arrow": null, "transient": true, "concealed": true}
	_push_stage(entry)
	var players: Array = play.source.target_candidates(play)
	if not players.has(play.target):
		players.append(play.target)
	var at := maxi(players.find(play.actor), 0)
	var hops := posmod(players.find(play.target) - at, players.size())
	while hops < ROULETTE_MIN_HOPS:
		hops += players.size()

	var cylinder := CylinderFx.new()
	cylinder.position = ROULETTE_CENTRE - cylinder.size / 2.0
	# One chamber goes by per hop: the round ends up under the hammer.
	cylinder.loaded = posmod(-hops, CylinderFx.CHAMBERS)
	cylinder.modulate.a = 0.0
	_fx.add_child(cylinder)
	var sight := _sprite(UI.tex(SIGHT_ICON), _anchor(players[at]), Vector2(84, 84))
	sight.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sight.modulate.a = 0.0
	var enter := cylinder.create_tween().set_parallel()
	enter.tween_property(cylinder, "modulate:a", 1.0, 0.2 / _speed)
	enter.tween_property(sight, "modulate:a", 1.0, 0.2 / _speed)
	UI.pop(cylinder, 1.4, 0.25)
	await _wait(0.2)

	# The spin: each hop takes a little longer than the one before.
	var growth := 1.18 if hops <= 14 else 1.12
	var interval := ROULETTE_SPIN * (growth - 1.0) / (pow(growth, hops) - 1.0)
	for i in hops:
		if not is_instance_valid(cylinder):
			return
		at = (at + 1) % players.size()
		sight.position = _anchor(players[at]) - sight.size / 2.0
		UI.pop(sight, 1.3, 0.1)
		_play_sfx("item_roulette_tick")
		cylinder.create_tween().tween_property(cylinder, "turn", float(i + 1), minf(interval, 0.12) / _speed) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await _wait(interval)
		interval *= growth
	if not is_instance_valid(cylinder):
		return

	# It stopped: now the table knows who.
	entry.concealed = false
	if _stage_stack.has(entry):
		entry.arrow = _stage_arrow(play)
		_render_stage()
	UI.pop(sight, 1.8, 0.3)
	await _wait(0.25)
	_play_sfx("item_roulette_cock")
	UI.shake(cylinder, 4.0, 0.15)
	await _wait(0.45)
	# The held breath: the sight closes in.
	sight.create_tween().tween_property(sight, "scale", Vector2.ONE * 0.7, 0.35 / _speed) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await _wait(0.4)
	if not is_instance_valid(cylinder):
		return

	# The shot.
	_play_sfx("item_roulette_shot")
	var blast := ColorRect.new()
	blast.color = Color(1.0, 0.96, 0.85, 0.9)
	blast.set_anchors_preset(Control.PRESET_FULL_RECT)
	blast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(blast)
	var fade := blast.create_tween()
	fade.tween_property(blast, "color", Color(0.55, 0.05, 0.03, 0.45), 0.1 / _speed)
	fade.tween_property(blast, "color:a", 0.0, 0.5 / _speed)
	fade.tween_callback(blast.queue_free)
	cylinder.flash = 1.0
	var recoil := cylinder.create_tween()
	recoil.tween_property(cylinder, "position:y", cylinder.position.y - 22.0, 0.05 / _speed)
	recoil.parallel().tween_property(cylinder, "rotation", -0.22, 0.05 / _speed)
	recoil.tween_property(cylinder, "position:y", cylinder.position.y, 0.3 / _speed) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	recoil.parallel().tween_property(cylinder, "rotation", 0.0, 0.3 / _speed)
	recoil.parallel().tween_property(cylinder, "flash", 0.0, 0.22 / _speed)
	UI.pop(sight, 2.2, 0.35)
	UI.shake(_table, 24.0, 0.5)
	await _wait(0.55)
	if not is_instance_valid(cylinder):
		return
	var leave := cylinder.create_tween().set_parallel()
	leave.tween_property(cylinder, "modulate:a", 0.0, 0.25 / _speed)
	leave.tween_property(sight, "modulate:a", 0.0, 0.25 / _speed)
	leave.chain().tween_callback(cylinder.queue_free)
	leave.tween_callback(sight.queue_free)


func _push_stage(entry: Dictionary) -> void:
	_drop_transient_stage()
	# A concealed entry keeps its target to itself for now (see _anim_roulette).
	if not entry.get("concealed", false):
		entry.arrow = _stage_arrow(entry.play)
	_stage_stack.append(entry)
	_render_stage()
	UI.pop(_stage, 1.12, 0.22)


## The chalk mark from the actor of `play` to its target, null if there is
## none to draw. It runs on the table between the two boxes, not over them.
func _stage_arrow(play: Play) -> Control:
	play = play.aimed()
	var whom := play.whom()
	if whom == null or whom == play.actor:
		return null
	var from := _anchor(play.actor)
	var to := _anchor(whom)
	var arrow := ChalkFx.new()
	arrow.set_anchors_preset(Control.PRESET_FULL_RECT)
	arrow.from = _clear_of(_node_of(play.actor), from, to, CHALK_START)
	arrow.to = _clear_of(_node_of(whom), to, from, CHALK_END)
	if (arrow.to - arrow.from).dot(to - from) <= 0.0 or arrow.from.distance_to(arrow.to) < 24.0:
		# The two boxes all but touch: there is no table between them.
		arrow.from = from
		arrow.to = to
	arrow.color = CHALK_RED if play.source.tags.has(&"damage") or play.source.tags.has(&"steal") else CHALK_WHITE
	_arrows.add_child(arrow)
	arrow.create_tween().tween_property(arrow, "progress", 1.0, 0.35 / _speed)
	_play_sfx("chalk")
	return arrow


## The point on the way from `from` to `to` that is `gap` past the edge of
## `box` (`from` itself if there is no box, or it is not inside it).
func _clear_of(box: Control, from: Vector2, to: Vector2, gap: float) -> Vector2:
	if box == null:
		return from
	var rect := box.get_global_rect()
	var way := (to - from).normalized()
	var at := from
	var reach := from.distance_to(to)
	while rect.has_point(at) and at.distance_to(from) < reach:
		at += way * 2.0
	return at + way * gap if at != from else from


func _pop_stage(play: Play) -> void:
	for entry: Dictionary in _stage_stack:
		if entry.play == play:
			await _wait(0.35)
			_remove_stage_entry(entry)
			_render_stage()
			return


func _drop_transient_stage() -> void:
	for entry: Dictionary in _stage_stack.duplicate():
		if entry.transient:
			_remove_stage_entry(entry)
	_render_stage()


func _remove_stage_entry(entry: Dictionary) -> void:
	_stage_stack.erase(entry)
	if entry.arrow != null and is_instance_valid(entry.arrow):
		entry.arrow.wipe(0.3 / _speed)


func _render_stage() -> void:
	UI.clear(_stage)
	_stage.visible = not _stage_stack.is_empty()
	for i in _stage_stack.size():
		var arrow: Variant = _stage_stack[i].arrow
		if arrow != null and is_instance_valid(arrow):
			arrow.visible = i == _stage_stack.size() - 1
	if _stage_stack.is_empty():
		return
	var play: Play = _stage_stack.back().play
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_stage.add_child(row)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	var mine := play.actor == viewer
	var actor := play.actor.name.to_upper()
	if play.is_claim():
		var def := Content.character(play.ability().character_id)
		var card := CardView.new(1.1)
		card.set_card(def.id, true)
		card.interactive = false
		card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(card)
		text.add_child(UI.label("YOU CLAIM" if mine else Loc.t("%s CLAIMS") % actor, 13, UI.MUTED, true))
		text.add_child(UI.label(def.display_name.to_upper(), 28, UI.GOLD, true))
	else:
		var item := ItemView.new(1.2)
		item.set_item(play.source)
		item.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(item)
		text.add_child(UI.label("YOU USE" if mine else Loc.t("%s USES") % actor, 13, UI.MUTED, true))
		text.add_child(UI.label(play.source.display_name.to_upper(), 26, UI.BLUE.lightened(0.2), true))
	row.add_child(text)
	if play.is_claim():
		var cost := "  (%s)" % (Loc.t("%d coins") % play.cost) if play.cost > 0 else ""
		text.add_child(UI.label(EventText.title(play) + _on_target(play) + cost, 17, UI.CREAM, true))
	elif play.target != null and not _stage_stack.back().get("concealed", false):
		text.add_child(UI.label(_on_target(play).strip_edges().capitalize(), 17, UI.CREAM, true))
	var description := UI.label(play.source.description, 12, UI.MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(300, 0)
	text.add_child(description)


func _on_target(play: Play) -> String:
	var whom := play.aimed().whom()
	if whom == null:
		return ""
	if whom == play.aimed().actor:
		return Loc.t(" on themselves")
	return Loc.t(" on you") if whom == viewer else Loc.t(" on %s") % whom.name


func _anim_doubt(doubter: PlayerState) -> void:
	_play_sfx("doubt")
	_float("LIAR!", _anchor(doubter), UI.RED, 30)
	_shake_screen(9.0)
	await _stamp("LIAR!", UI.RED)


func _anim_reveal(play: Play, truthful: bool) -> void:
	var character_id := play.ability().character_id
	var shown: CardView = null
	if truthful and play.actor != viewer and _seats.has(play.actor.id):
		shown = _seats[play.actor.id].card(play.actor.cards.find(character_id))
		if shown != null:
			shown.set_card(character_id, true, true)
	if truthful:
		_play_sfx("truth")
		await _stamp("TRUTH", UI.GREEN)
	else:
		_play_sfx("lie")
		UI.shake(_stage, 12.0, 0.35)
		await _stamp("LIE!", UI.RED)
	# Someone looking on with that hand face up keeps it that way.
	if shown != null and is_instance_valid(shown) and not _seats[play.actor.id].is_revealed():
		shown.set_card(&"", false, true)


# --- effects ------------------------------------------------------------------

func _anim_coins(d: Dictionary) -> void:
	var p: PlayerState = d.player
	var delta: int = d.delta
	var here := _coin_anchor(p)
	var there := _coin_anchor(d.other) if d.other != null else _bank()
	var bar := _stat_bar(p)
	var other_bar := _stat_bar(d.other)
	if d.reason == &"swindle" and delta > 0:
		_dance_coins(d)
		return
	if d.reason == &"voodoo" and delta > 0 and d.other != null:
		await _anim_hex_cut(d)
		return
	# A Cash Out pays out of the vault standing open on the table.
	if d.reason == &"vault" and _play_fx.vault_mouth(p) != Vector2.INF:
		there = _play_fx.vault_mouth(p)
	# The change of a Materialize comes out of where the item did.
	if d.reason == &"materialize" and _play_fx.made_at(p) != Vector2.INF:
		there = _play_fx.made_at(p)
	# What a Materialize costs on top of the Morale is fed to the singularity.
	if d.reason == &"cost" and delta < 0 and _materializing(p):
		await _play_fx.hoard_cost(d)
		if bar != null:
			bar.coin_bias = 0
		_float("%+d" % delta, here + Vector2(0, -18), UI.RED, 22)
		return
	# The chains of an Entropy: what is left of them becomes the coins.
	if d.reason == &"entropy" and delta > 0 and _play_fx.releasing(p):
		await _play_fx.release_coins(d)
		if bar != null:
			bar.coin_bias = 0
		_float("+%d" % delta, here + Vector2(0, -18), UI.GOLD, 22)
		return
	# A Shakedown: the boot stamps the coins out of the pile and carries
	# them home itself.
	if d.reason == &"stolen" and delta < 0 and _play_fx.booting(d.other, p):
		await _play_fx.boot_stomp(d)
		if bar != null:
			bar.coin_bias = 0
		_float("%+d" % delta, here + Vector2(0, -18), UI.RED, 22)
		return
	if d.reason == &"steal" and _play_fx.boot_loaded(p):
		await _play_fx.boot_pour(d)
		if bar != null:
			bar.coin_bias = 0
		_float("+%d" % delta, here + Vector2(0, -18), UI.GOLD, 22)
		return
	if d.reason == &"steal":
		# The coins already flew out of the victim's pile, and were counted
		# in as they landed.
		if bar != null:
			bar.coin_bias = 0
		_float("+%d" % delta, here + Vector2(0, -18), UI.GOLD, 22)
		await _wait(0.25)
		return
	# The engine already moved the coins: each pile catches up one flying
	# coin at a time, as it leaves or lands.
	if bar != null:
		bar.hold_coins(p)
	# Perjury: the gavel comes down on the purse first, and then it all goes.
	if d.reason == &"oath" and delta < 0:
		# Not so high that the gavel is off the screen, on the seats at the top.
		await _play_fx.perjury(p, Vector2(here.x, maxf(here.y, PERJURY_FLOOR)))
	var total := absi(delta)
	var coins := clampi(total, 1, MAX_COINS_SHOWN)
	# Coins the other pile is showing ahead of time (a thief yet to be paid).
	var ahead := maxi(other_bar.coin_bias, 0) if other_bar != null else 0
	for i in coins:
		var from := there if delta > 0 else here
		var to := here if delta > 0 else there
		var leaves := i * COIN_STAGGER
		var lands := COIN_FLIGHT + leaves
		# More coins than sprites: each sprite stands for its share of them.
		var share := total * (i + 1) / coins - total * i / coins
		_fly(UI.tex("res://assets/ui/coin.png"), from, to, Vector2(20, 20), COIN_FLIGHT, leaves)
		# One clink per coin, as it lands.
		_play_sfx_later("coin_%d" % (i % COIN_SOUNDS + 1), lands)
		if delta > 0:
			_count_coins(bar, share, lands)
			var taken := mini(share, ahead)
			ahead -= taken
			_count_coins(other_bar, -taken, leaves)
		else:
			_count_coins(bar, -share, leaves)
			# A thief's pile grows now; the engine pays them right after.
			if d.reason == &"stolen":
				_count_coins(other_bar, share, lands)
	await _wait(COIN_FLIGHT + coins * COIN_STAGGER)
	if bar != null:
		bar.coin_bias = 0
	_float("%+d" % delta, here + Vector2(0, -18), UI.GOLD if delta > 0 else UI.RED, 22)


## True while a Materialize of `p` is the claim being played out.
func _materializing(p: PlayerState) -> bool:
	if _stage_stack.is_empty():
		return false
	var play: Play = _stage_stack.back().play
	return play.actor == p and play.source.id == &"entity.materialize"


## Morale given up as the price of something. For a Materialize it is what
## the singularity is fed: the heart goes round it until it is the item.
func _anim_morale_spent(d: Dictionary) -> void:
	var p: PlayerState = d.player
	var box: Variant = _node_of(p)
	# The heart is gone from its place: it is the one that flies.
	if box != null:
		box.sync()
	var play: Variant = d.get("play")
	if box != null and play is Play and play.params.get("item") is ItemDef and _play_fx.materializing(p):
		var def: ItemDef = play.params.item
		await _play_fx.spaghettify(p, box.heart_spot(p.morale), UI.tex(def.texture_path), "+ %s" % def.display_name.to_upper())
		return
	_play_sfx("spend")
	_float(Loc.t("-%d MORALE") % d.amount, _anchor(p), UI.PURPLE.lightened(0.3), 22)
	await _wait(0.5)


## The doll's cut of what a hexed player gains, carried by the same purple
## swirl that hangs round the doll: the coins are drawn out of the victim's
## pile and wind in round the doll, shrinking and turning purple, until it
## has swallowed them; then they come out again and are borne off to whoever
## owns the doll on a winding trail of motes. Nobody is left wondering why
## half the coins went somewhere else.
func _anim_hex_cut(d: Dictionary) -> void:
	var owner_player: PlayerState = d.player
	var victim: PlayerState = d.other
	var bar := _stat_bar(owner_player)
	if bar != null:
		bar.hold_coins(owner_player)
	var from := _coin_anchor(victim)
	var doll := _anchor(victim)
	var box := _node_of(victim)
	if box != null:
		var pieces: Array[Vector2] = box.status_pieces(&"hexed")
		if not pieces.is_empty():
			doll = pieces[0]
	var total: int = d.delta
	var coins := clampi(total, 1, MAX_COINS_SHOWN)
	var hex: Color = Content.statuses.get(&"hexed", {}).get("color", UI.PURPLE)
	_play_sfx("fx_doll_hit")
	_float(Loc.t("THE DOLL TAKES %d") % total, doll + Vector2(0, -52), hex.lightened(0.45), 18)
	for i in coins:
		var share := total * (i + 1) / coins - total * i / coins
		var leaves := i * HEX_STAGGER
		var sprite := _sprite(UI.tex("res://assets/ui/coin.png"), from, Vector2(20, 20))
		sprite.hide()
		var way := sprite.create_tween()
		way.tween_interval(maxf(leaves, 0.001) / _speed)
		way.tween_callback(sprite.show)
		way.tween_method(_hex_wind.bind(sprite, from, doll, i, hex), 0.0, 1.0, HEX_GRAB / _speed)
		# Swallowed: for a moment there is nothing to see.
		way.tween_callback(sprite.hide)
		way.tween_interval(HEX_PAUSE / _speed)
		way.tween_callback(sprite.show)
		way.tween_method(_hex_carry.bind(sprite, doll, owner_player, i, hex), 0.0, 1.0, HEX_FLIGHT / _speed)
		way.tween_callback(sprite.queue_free)
		var lands := leaves + HEX_GRAB + HEX_PAUSE + HEX_FLIGHT
		_play_sfx_later("coin_%d" % (i % COIN_SOUNDS + 1), lands)
		_count_coins(bar, share, lands)
	await _wait(HEX_GRAB + HEX_PAUSE + HEX_FLIGHT + coins * HEX_STAGGER)
	if bar != null:
		bar.coin_bias = 0
	_float("%+d" % total, _coin_anchor(owner_player) + Vector2(0, -18), hex.lightened(0.45), 22)


## A coin `t` of its way from `from` into the doll at `doll`: round and
## round it, closer every turn, smaller and more purple as it goes.
func _hex_wind(t: float, sprite: Control, from: Vector2, doll: Vector2, index: int, hex: Color) -> void:
	var out := from - doll
	var turn := out.angle() + t * t * TAU * 1.6
	var reach := out.length() * (1.0 - t) + 26.0 * sin(t * PI)
	var at := doll + Vector2(cos(turn), sin(turn) * lerpf(1.0, 0.66, t)) * reach
	sprite.position = at - sprite.size / 2.0
	sprite.scale = Vector2.ONE * lerpf(1.0, 0.7, t)
	sprite.modulate = Color.WHITE.lerp(hex.lightened(0.6), t)
	_hex_trail(sprite, at, t, index, hex)


## A coin `t` of its way from the doll to the pile of `p`: out along a wide
## bend, turning about its own path like the motes that carry it.
func _hex_carry(t: float, sprite: Control, doll: Vector2, p: PlayerState, index: int, hex: Color) -> void:
	var to := _coin_anchor(p)
	var across := to - doll
	var side := across.orthogonal().normalized()
	var bend := doll.lerp(to, 0.5) + side * across.length() * 0.22 * (1.0 if index % 2 == 0 else -0.6)
	var at := doll.lerp(bend, t).lerp(bend.lerp(to, t), t)
	var turn := t * TAU * 3.0 + index * 1.7
	at += Vector2(cos(turn), sin(turn) * 0.66) * 14.0 * sin(t * PI)
	sprite.position = at - sprite.size / 2.0
	sprite.scale = Vector2.ONE * lerpf(0.7, 1.0, t)
	sprite.modulate = hex.lightened(0.6).lerp(Color.WHITE, t * t * t)
	_hex_trail(sprite, at, t, index, hex)


## Leaves motes behind a coin the swirl is carrying, a few to every stretch
## of its way.
func _hex_trail(sprite: Control, at: Vector2, t: float, index: int, hex: Color) -> void:
	var stretch := int(t * 44.0)
	if sprite.get_meta(&"stretch", -1) == stretch:
		return
	sprite.set_meta(&"stretch", stretch)
	for twin in 2:
		var mote := ColorRect.new()
		var side := 6.0 if (stretch + index + twin) % 3 == 0 else 4.0
		mote.size = Vector2(side, side)
		mote.color = hex.lightened(0.5) if (stretch + index + twin) % 2 == 0 else hex.lightened(0.15)
		mote.position = (at + Vector2(randf_range(-9, 9), randf_range(-9, 9)) - mote.size / 2.0).round()
		mote.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fx.add_child(mote)
		_fx.move_child(mote, 0)
		var fade := mote.create_tween().set_parallel()
		fade.tween_property(mote, "modulate:a", 0.0, 0.6 / _speed)
		fade.tween_property(mote, "position:y", mote.position.y - 8.0, 0.6 / _speed)
		fade.chain().tween_callback(mote.queue_free)


## Swindled coins take their time: they sway over to the Bard's pile to the
## tune (PlayFx._fx_bard_swindle) while the match goes on, and each is
## counted in as it lands. Nothing waits for them.
func _dance_coins(d: Dictionary) -> void:
	var p: PlayerState = d.player
	var bar := _stat_bar(p)
	var other_bar := _stat_bar(d.other)
	var from := _coin_anchor(d.other) if d.other != null else _bank()
	# Swindled out of the boot that had just stamped them loose.
	var boot: Vector2 = _play_fx.boot_robbed(d.other)
	if boot != Vector2.INF:
		from = boot
	var total: int = d.delta
	var coins := clampi(total, 1, MAX_COINS_SHOWN)
	if bar != null:
		bar.hold_coins(p)
	# Stolen coins that were swindled on the way: the thief's pile was shown
	# ahead of a payment that is not coming.
	if other_bar != null:
		other_bar.coin_bias = 0
	for i in coins:
		var share := total * (i + 1) / coins - total * i / coins
		var sprite := _sprite(UI.tex("res://assets/ui/coin.png"), from, Vector2(20, 20))
		sprite.pivot_offset = sprite.size / 2.0
		sprite.hide()
		var dance := sprite.create_tween()
		dance.tween_interval(i * DANCE_STAGGER / _speed)
		dance.tween_callback(sprite.show)
		dance.tween_method(_dance_step.bind(sprite, p, from, i), 0.0, 1.0, DANCE_TIME / _speed)
		dance.tween_callback(_dance_landed.bind(sprite, p, share, total if i == coins - 1 else 0))


## A dancing coin `t` of its way from `from` to the pile of `p`: it swings
## from side to side and hops, widest in the middle of the way.
func _dance_step(t: float, sprite: Control, p: PlayerState, from: Vector2, index: int) -> void:
	var across := _coin_anchor(p) - from
	var side := across.orthogonal().normalized()
	var room := sin(t * PI)
	var at := from + across * smoothstep(0.0, 1.0, t)
	at += side * sin(t * TAU * 2.0 + index * 0.9) * 28.0 * room
	at.y -= absf(sin(t * TAU * 4.0 + index)) * 9.0 * room
	sprite.position = at - sprite.size / 2.0
	sprite.rotation = sin(t * TAU * 3.0 + index) * 0.4


## A dancing coin reaches the pile of `p`, worth `share` coins. `total` is
## what the whole dance brought, on the last coin of it.
func _dance_landed(sprite: Control, p: PlayerState, share: int, total: int) -> void:
	sprite.queue_free()
	_play_sfx("coin_%d" % (randi() % COIN_SOUNDS + 1))
	var bar := _stat_bar(p)
	# Only what the pile is still short of: something else may have caught
	# it up in the meantime.
	if bar != null and bar.coin_bias < 0:
		bar.add_coins(mini(share, -bar.coin_bias))
	if total > 0:
		_float("%+d" % total, _coin_anchor(p) + Vector2(0, -18), UI.GOLD, 22)


## Moves the coins shown on `bar` by `amount`, `delay` seconds from now.
func _count_coins(bar: StatBar, amount: int, delay: float) -> void:
	if bar == null or amount == 0:
		return
	if delay <= 0.0:
		bar.add_coins(amount)
	else:
		get_tree().create_timer(delay / _speed).timeout.connect(bar.add_coins.bind(amount))


func _anim_damage(target: PlayerState, amount: int) -> void:
	_play_sfx("damage")
	var node := _node_of(target)
	if node != null:
		var tween := node.create_tween()
		tween.tween_property(node, "modulate", Color(1.6, 0.4, 0.4), 0.08)
		tween.tween_property(node, "modulate", Color.WHITE, 0.3)
		if node is SeatView:
			UI.shake(node, 10.0, 0.35)
	_shake_screen(6.0)
	_float(Loc.t("-%d MORALE") % amount, _anchor(target), UI.RED, 24)
	await _wait(0.6)


func _anim_item_bought(d: Dictionary) -> void:
	_play_sfx("spend")
	var instance: ItemInstance = d.item
	var concealed: bool = instance.hidden and d.player != viewer
	var texture := UI.tex(UI.ITEM_BACK if concealed else instance.def.texture_path)
	# Bought out of sight, it comes from the shop at large: nobody is shown
	# which shelf it was on (the shop keeps it on sale, see GameEngine.buy_item).
	var from := _shop_bg.get_global_rect().get_center() if concealed else _shop_point(d.slot, instance.def)
	_fly(texture, from, _anchor(d.player), Vector2(48, 50), 0.4)
	await _wait(0.42)


## An item out of nowhere. Out of the Magician's hat it is printed into being
## first, and only then goes to its place in the inventory.
func _anim_item_gained(d: Dictionary) -> void:
	var instance: ItemInstance = d.item
	var concealed: bool = instance.hidden and d.player != viewer
	var label := "+ %s" % (Loc.t("ITEM") if concealed else instance.def.display_name.to_upper())
	if _play_fx.conjuring(d.player):
		var texture := UI.tex(UI.ITEM_BACK if concealed else instance.def.texture_path)
		await _play_fx.item_conjured(texture, _item_spot(d.player, d.player.items.size() - 1), label)
		return
	if _play_fx.made_for(d.player):
		# Made out of Morale: it is still going round the singularity.
		await _play_fx.item_materialized(_item_spot(d.player, d.player.items.size() - 1), 0.8 if d.player == viewer else 0.4)
		return
	if _play_fx.copying(d.player):
		var texture := UI.tex(UI.ITEM_BACK if concealed else instance.def.texture_path)
		await _play_fx.item_copied(texture, _item_spot(d.player, d.player.items.size() - 1),
				ItemView.BASE * (0.8 if d.player == viewer else 0.4), label)
		return
	_play_sfx("item_get")
	_float(label, _anchor(d.player), UI.BLUE)
	await _wait(0.35)


func _anim_item_broken(d: Dictionary) -> void:
	if _play_fx.bombing():
		# The Bomber's "Demolition": the bomb rolls to it and takes it along.
		var held: Variant = _node_of(d.player)
		var gone := func() -> void:
			if held != null and is_instance_valid(held):
				held.sync()
		await _play_fx.item_bombed(UI.tex(d.item.def.texture_path), _item_spot(d.player, d.get("index", 0)),
				ItemView.BASE * (0.8 if d.player == viewer else 0.4), gone)
		return
	_play_sfx("item_%s" % d.item.def.id, "breaking")
	_play_fx.item_broken(d.player, d.item.def)
	var at := _anchor(d.player)
	var icon := _sprite(UI.tex(d.item.def.texture_path), at, Vector2(70, 73))
	var tween := icon.create_tween()
	tween.tween_property(icon, "scale", Vector2.ONE * 1.5, 0.12)
	tween.tween_property(icon, "rotation", 0.3, 0.06)
	tween.tween_property(icon, "rotation", -0.3, 0.06)
	tween.tween_property(icon, "modulate:a", 0.0, 0.3)
	tween.tween_callback(icon.queue_free)
	await _stamp("%s!" % d.item.def.display_name.to_upper(), UI.BLUE)


## An item taken from one inventory into another, at the end of a rope. Only
## the two of them see what it is if it was hidden.
func _anim_item_stolen(d: Dictionary) -> void:
	var instance: ItemInstance = d.item
	var concealed: bool = instance.hidden and d.thief != viewer and d.victim != viewer
	var texture := UI.tex(UI.ITEM_BACK if concealed else instance.def.texture_path)
	var lost: Control = _node_of(d.victim)
	# The loop closes on it: from then on it is not in the victim's inventory.
	var caught := func() -> void:
		if lost != null and is_instance_valid(lost):
			lost.sync()
	await _play_fx.item_roped(d.thief, texture, _item_spot(d.victim, d.get("index", 0)),
			_item_spot(d.thief, d.thief.items.size() - 1), caught)


## A whole hand goes into the deck and as many cards come back out of it, all
## of it face down.
func _anim_hand_redrawn(d: Dictionary) -> void:
	var p: PlayerState = d.player
	var views := []
	var spots := []
	var sizes := []
	for i: int in d.count:
		var view := _card_view(p, i)
		views.append(view)
		spots.append(_card_center(p, i))
		sizes.append(view.size if view != null else Vector2(33, 60))
	_float("NEW HAND", _anchor(p) + Vector2(0, -30), UI.CREAM, 16)
	_play_sfx("card_draw")
	_set_cards_shown(views, false)
	for i: int in d.count:
		_fly_card(spots[i], _bank(), sizes[i], Vector2(33, 60), 0.4)
	await _wait(0.6)
	_play_sfx("card_draw")
	for i: int in d.count:
		_fly_card(_bank(), spots[i], Vector2(33, 60), sizes[i], 0.4)
	await _wait(0.4)
	for view: Variant in views:
		if view != null and is_instance_valid(view):
			# They land face down; the viewer's own turn over on the next sync.
			view.set_card(&"", false)
			UI.pop(view, 1.15, 0.2)
	_set_cards_shown(views, true)
	await _wait(0.2)


## A card dealt from the deck: its place in the hand stays empty until it lands.
func _anim_card_changed(p: PlayerState, index: int) -> void:
	_float("NEW CARD", _anchor(p) + Vector2(0, -30), UI.CREAM, 16)
	_play_sfx("card_draw")
	var card := _card_view(p, index)
	_set_cards_shown([card], false)
	var landing := card.size if card != null else Vector2(33, 60)
	_fly_card(_bank(), _card_center(p, index), Vector2(33, 60), landing, 0.35)
	await _wait(0.35)
	_set_cards_shown([card], true)
	if card != null and is_instance_valid(card):
		UI.pop(card, 1.15, 0.2)
	await _wait(0.15)


## A card goes back to the deck and another one comes out, in two clear beats
## at the centre of the table. Faces show only to who may know them: the old
## card if a doubt already revealed it, both cards to their owner.
func _anim_card_traded(d: Dictionary) -> void:
	var p: PlayerState = d.player
	var proven: bool = d.reason == &"proven"
	var mine := p == viewer
	var old_def := Content.character(d.old) if proven or mine else null
	var centre := Vector2(576, 236)
	var scene := Control.new()
	scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(scene)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.74)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.modulate.a = 0.0
	scene.add_child(dim)

	var card := CardView.new(2.5)
	card.interactive = false
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.pivot_offset = card.size / 2.0
	if old_def != null:
		card.set_card(d.old, true)
	scene.add_child(card)

	var who: String
	if proven:
		who = "IT WAS THE TRUTH: YOU TRADE THE CARD" if mine else Loc.t("IT WAS THE TRUTH: %s TRADES THE CARD") % p.name.to_upper()
	else:
		who = "YOU TRADE A CARD" if mine else Loc.t("%s TRADES A CARD") % p.name.to_upper()
	var heading := _reveal_label(scene, who, 26, UI.GREEN if proven else UI.CREAM, centre.y - card.size.y / 2.0 - 58)
	var name_label := _reveal_label(scene, old_def.display_name.to_upper() if old_def != null else "", 46, UI.GOLD, centre.y + card.size.y / 2.0 + 14)
	var caption := _reveal_label(scene, "GOES BACK TO THE DECK", 18, UI.CREAM, centre.y + card.size.y / 2.0 + 80)
	var small := Vector2.ONE * 0.25
	var at_deck := Vector2.ONE * 0.14
	var slot := _card_center(p, d.index) - card.size / 2.0
	var deck_spot := _bank() - card.size / 2.0

	# The old card: out of the hand and up to the centre.
	var held := _take_pick_handoff(p, d.old)
	var in_hand := _card_view(p, d.index)
	_set_cards_shown([in_hand], false)
	card.position = slot
	card.scale = small
	if held:
		# The player just picked it: it is already there.
		card.position = centre - card.size / 2.0
		card.scale = Vector2.ONE
		dim.modulate.a = 1.0
	var enter := scene.create_tween().set_parallel()
	for node: Control in [dim, heading, name_label, caption]:
		enter.tween_property(node, "modulate:a", 1.0, 0.25 / _speed)
	enter.tween_property(card, "position", centre - card.size / 2.0, 0.45 / _speed) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	enter.tween_property(card, "scale", Vector2.ONE, 0.45 / _speed) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _wait(1.3)

	# Into the deck.
	var away := scene.create_tween().set_parallel()
	away.tween_property(name_label, "modulate:a", 0.0, 0.2 / _speed)
	away.tween_property(caption, "modulate:a", 0.0, 0.2 / _speed)
	away.tween_property(card, "position", deck_spot, 0.45 / _speed) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	away.tween_property(card, "scale", at_deck, 0.45 / _speed) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await _wait(0.75)
	if not is_instance_valid(scene):
		return

	# The new card: out of the deck, face down.
	card.set_card(&"", false)
	caption.text = "A NEW CARD COMES FROM THE DECK"
	_play_sfx("card_draw")
	var draw := scene.create_tween().set_parallel()
	draw.tween_property(caption, "modulate:a", 1.0, 0.2 / _speed)
	draw.tween_property(card, "position", centre - card.size / 2.0, 0.45 / _speed) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	draw.tween_property(card, "scale", Vector2.ONE, 0.45 / _speed) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _wait(0.8)
	if not is_instance_valid(scene):
		return
	if mine and d.index < p.cards.size():
		# Only its owner gets to see it.
		var new_id: StringName = p.cards[d.index]
		card.set_card(new_id, true, true)
		await _wait(0.12)
		name_label.text = Content.character(new_id).display_name.to_upper()
		name_label.modulate.a = 1.0
		card.highlight(UI.GOLD)
		UI.pop(card, 1.18, 0.3)
		UI.pop(name_label, 1.8, 0.3)
		await _wait(1.3)
	else:
		await _wait(0.6)
	if not is_instance_valid(scene):
		return

	# Into the hand.
	var leave := scene.create_tween().set_parallel()
	for node: Control in [heading, name_label, caption]:
		leave.tween_property(node, "modulate:a", 0.0, 0.2 / _speed)
	leave.tween_property(dim, "modulate:a", 0.0, 0.4 / _speed)
	leave.tween_property(card, "position", slot, 0.4 / _speed) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	leave.tween_property(card, "scale", small, 0.4 / _speed) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await _wait(0.45)
	if is_instance_valid(scene):
		scene.queue_free()
	if mine and in_hand != null and is_instance_valid(in_hand) and d.index < p.cards.size():
		# Already the new card when it shows up again, instead of turning over.
		in_hand.set_card(p.cards[d.index], true)
	_set_cards_shown([in_hand], true)


## The card given up gets its moment: the table dims, the card travels from
## its owner to the centre, turns face up for everyone and only then goes back
## to the deck.
## A card leaves a hand for good and the whole table is shown which: it comes
## up to the middle, is turned over and named. `left` is for a card of
## somebody who was just eliminated: it does not go back to the deck, it is
## put down where they sat (and the table is not brought up to date first).
## With `index`, it comes from the place of that card of theirs and goes
## back to lie exactly there, as that card lies.
func _anim_card_lost(d: Dictionary, left := false) -> void:
	if not left:
		_sync()
	var def := Content.character(d.card)
	var loser: PlayerState = d.player
	var centre := Vector2(576, 236)
	# The card of an opponent who is out, lying where their box was.
	var lies: CardView = _card_view(loser, d.index) if left and loser != viewer and d.has("index") else null
	var home := lies.center() if lies != null else _anchor(loser)
	var scene := Control.new()
	scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(scene)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.74)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.modulate.a = 0.0
	scene.add_child(dim)

	var card := CardView.new(2.5)
	card.interactive = false
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.pivot_offset = card.size / 2.0
	var glow := Panel.new()
	glow.add_theme_stylebox_override("panel", UI.box(Color(UI.GOLD, 0.16), Color(UI.GOLD, 0.85), 3, 14, 0))
	glow.size = card.size + Vector2(30, 30)
	glow.pivot_offset = glow.size / 2.0
	glow.position = centre - glow.size / 2.0
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.modulate.a = 0.0
	scene.add_child(glow)
	scene.add_child(card)

	var who := "YOU LOSE A CARD" if loser == viewer else Loc.t("%s LOSES A CARD") % loser.name.to_upper()
	if left:
		who = "YOU ARE OUT" if loser == viewer else Loc.t("%s IS OUT") % loser.name.to_upper()
	var heading := _reveal_label(scene, who, 26, UI.RED, centre.y - card.size.y / 2.0 - 58)
	var name_label := _reveal_label(scene, def.display_name.to_upper(), 46, UI.GOLD, centre.y + card.size.y / 2.0 + 14)
	var fate := "%s  ·  left on the table" if left else "%s  ·  shuffled back into the deck"
	var caption := _reveal_label(scene, Loc.t(fate) % def.title, 15, UI.CREAM, centre.y + card.size.y / 2.0 + 80)

	var enter := scene.create_tween().set_parallel()
	enter.tween_property(heading, "modulate:a", 1.0, 0.25 / _speed)
	if _take_pick_handoff(loser, d.card):
		# The loser just picked it: it is already there, face up.
		card.set_card(d.card, true)
		card.position = centre - card.size / 2.0
		dim.modulate.a = 1.0
		await _wait(0.2)
	else:
		# Face down, out of the loser's hand and up to the centre.
		card.position = home - card.size / 2.0
		card.scale = Vector2.ONE * 0.25
		if lies != null:
			card.scale = lies.size / card.size
			card.rotation = lies.rotation
			enter.tween_property(card, "rotation", 0.0, 0.45 / _speed) \
					.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		enter.tween_property(dim, "modulate:a", 1.0, 0.25 / _speed)
		enter.tween_property(card, "position", centre - card.size / 2.0, 0.45 / _speed) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		enter.tween_property(card, "scale", Vector2.ONE, 0.45 / _speed) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await _wait(0.75)
		card.set_card(d.card, true, true)
		await _wait(0.12)

	# The reveal.
	_play_sfx("breaking")
	_shake_screen(8.0)
	card.highlight(UI.GOLD)
	UI.pop(card, 1.18, 0.3)
	UI.pop(name_label, 1.8, 0.3)
	var reveal := scene.create_tween().set_parallel()
	reveal.tween_property(name_label, "modulate:a", 1.0, 0.12 / _speed)
	reveal.tween_property(caption, "modulate:a", 1.0, 0.3 / _speed).set_delay(0.25 / _speed)
	reveal.tween_property(glow, "modulate:a", 1.0, 0.15 / _speed)
	var pulse := scene.create_tween().set_loops()
	pulse.tween_property(glow, "scale", Vector2.ONE * 1.06, 0.45 / _speed).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(glow, "scale", Vector2.ONE, 0.45 / _speed).set_trans(Tween.TRANS_SINE)
	await _wait(1.9)

	# Back to the deck, or down where its owner sat.
	var goes := home if left else _bank()
	pulse.kill()
	var leave := scene.create_tween().set_parallel()
	for node: Control in [glow, heading, name_label, caption]:
		leave.tween_property(node, "modulate:a", 0.0, 0.2 / _speed)
	leave.tween_property(dim, "modulate:a", 0.0, 0.4 / _speed)
	leave.tween_property(card, "position", goes - card.size / 2.0, 0.4 / _speed) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	leave.tween_property(card, "scale", Vector2.ONE * (0.28 if left else 0.14), 0.4 / _speed) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	if lies != null:
		# Down as the card it stands for lies: tilted and gone dull.
		leave.tween_property(card, "rotation", lies.rotation, 0.4 / _speed) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		leave.tween_property(card, "modulate", SeatView.LEFT_TINT, 0.4 / _speed)
	await _wait(0.45)
	if is_instance_valid(scene):
		scene.queue_free()


## A centred, outlined line of the card-lost reveal; starts invisible.
func _reveal_label(parent: Control, text: String, font_size: int, color: Color, y: float) -> Label:
	var l := UI.label(text, font_size, color, true)
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", UI.INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(0, y)
	l.size = Vector2(1152, font_size * 1.5)
	l.modulate.a = 0.0
	parent.add_child(l)
	return l


## Two cards cross the table, face down; both places stay empty on the way.
func _anim_cards_swapped(d: Dictionary) -> void:
	var a := _card_center(d.a, d.a_index)
	var b := _card_center(d.b, d.b_index)
	var views: Array = [_card_view(d.a, d.a_index), _card_view(d.b, d.b_index)]
	var a_size: Vector2 = views[0].size if views[0] != null else Vector2(44, 80)
	var b_size: Vector2 = views[1].size if views[1] != null else Vector2(44, 80)
	_set_cards_shown(views, false)
	_play_sfx("card_draw")
	_fly_card(a, b, a_size, b_size, 0.55)
	_fly_card(b, a, b_size, a_size, 0.55)
	await _wait(0.55)
	for view: Variant in views:
		if view != null and is_instance_valid(view):
			# It lands face down; the viewer's own turns over on the next sync.
			view.set_card(&"", false)
	_set_cards_shown(views, true)
	_play_sfx("card_draw")
	for view: Variant in views:
		if view != null and is_instance_valid(view):
			UI.pop(view, 1.15, 0.2)
	await _wait(0.25)


## Tips a card held up to someone, as seen from behind and above: squashed
## along `toward` (the way from the card to whoever looks at its face) and
## sheared a little across it. `lean` goes from 0, flat, to 1; `holder` is the
## node the card hangs from.
func _lean_card(lean: float, holder: Node2D, toward: Vector2) -> void:
	if not is_instance_valid(holder):
		return
	var push := (toward * (PEEK_SQUASH - 1.0) + toward.orthogonal() * PEEK_SHEAR) * lean
	holder.transform = Transform2D(Vector2.RIGHT + push * toward.x, Vector2.DOWN + push * toward.y, Vector2.ZERO)


func _game_over(winner: PlayerState) -> void:
	_sync()
	GameConfig.last_winner = winner.name if winner != null else ""
	GameConfig.last_winner_cards = winner.cards.duplicate() if winner != null else []
	if winner == null:
		_resume_time()
		await _banner("NO SURVIVORS", "Carcaj has a new boss", UI.GOLD, 2.2)
	else:
		await _go_dark()
	_set_time(1.0)
	get_tree().change_scene_to_file(END_SCENE)


## The table goes dark slowly, in the silence the last blow left, and time
## comes back to its pace on the way: the end screen opens on the winner's hand.
func _go_dark() -> void:
	Jukebox.play(Jukebox.SILENCE, FADE_TO_BLACK)
	var dark := ColorRect.new()
	dark.color = Color(0, 0, 0, 0)
	dark.size = size
	dark.z_index = 20
	add_child(dark)
	_resume_time(FADE_TO_BLACK)
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(dark, "color:a", 1.0, FADE_TO_BLACK).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(0.3)
	await tween.finished


# --- the last blow ------------------------------------------------------------

## Whether `e` is the blow that ends the match: the last Morale of one of the
## last two players, already lost. Nothing earlier is sure (a reaction may
## still save them, and slowing down before it would tell the table whether
## they have one), so the play that did it has run at its own pace by now:
## what is slowed is the hit and the fall.
func _last_blow(e: GameEvent) -> bool:
	return e.type == &"morale_lost" and not _slowed and e.data.target.morale <= 0 \
			and engine.alive_players().size() == 2


## Time slows and the music drops out, quickly but not at once.
func _slow_time() -> void:
	_slowed = true
	Jukebox.play(Jukebox.SILENCE, MUSIC_DROP)
	_glide_time(SLOW_MOTION, 0.25)


func _resume_time(seconds := 0.5) -> void:
	_slowed = false
	_glide_time(1.0, seconds)


## Takes the pace of the game to `pace` over `seconds` of real time.
func _glide_time(pace: float, seconds: float) -> void:
	if _time_glide != null:
		_time_glide.kill()
	_time_glide = create_tween()
	_time_glide.set_ignore_time_scale(true)
	_time_glide.tween_method(_set_time, Engine.time_scale, pace, seconds)


## Slows (or restores) everything that moves and everything that sounds:
## a sound played slower is longer and lower, like the picture.
func _set_time(pace: float) -> void:
	Engine.time_scale = pace
	AudioServer.playback_speed_scale = pace


# --- small fx helpers ---------------------------------------------------------

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds / _speed).timeout


## Plays `sound`, or `fallback` if there is no such file.
func _play_sfx(sound: String, fallback := "") -> void:
	var player: AudioStreamPlayer = _sfx[sound] if _sfx.has(sound) else _load_sfx(sound)
	if player != null:
		player.play()
	elif fallback != "":
		_play_sfx(fallback)


func _play_sfx_later(sound: String, delay: float) -> void:
	get_tree().create_timer(delay / _speed).timeout.connect(_play_sfx.bind(sound))


func _load_sfx(sound: String) -> AudioStreamPlayer:
	var stream: AudioStream = null
	for extension: String in ["wav", "mp3"]:
		var path := "%s%s.%s" % [SOUND_DIR, sound, extension]
		if ResourceLoader.exists(path):
			stream = load(path)
		elif extension == "wav" and FileAccess.file_exists(path):
			# Not imported yet (the editor has not rescanned): read the file directly.
			stream = AudioStreamWAV.load_from_file(path)
		if stream != null:
			break
	var player: AudioStreamPlayer = null
	if stream != null:
		player = AudioStreamPlayer.new()
		player.stream = stream
		player.bus = Settings.SFX_BUS
		# Quick repeats (coins) ring out instead of cutting each other off.
		player.max_polyphony = 4
		add_child(player)
	_sfx[sound] = player
	return player


func _sprite(texture: Texture2D, center: Vector2, sprite_size: Vector2) -> TextureRect:
	var sprite := TextureRect.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.size = sprite_size
	sprite.pivot_offset = sprite_size / 2.0
	sprite.position = center - sprite_size / 2.0
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.add_child(sprite)
	return sprite


func _fly(texture: Texture2D, from: Vector2, to: Vector2, sprite_size: Vector2, time: float, delay := 0.0) -> void:
	var sprite := _sprite(texture, from, sprite_size)
	sprite.visible = delay <= 0.0
	var tween := sprite.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay / _speed)
		tween.tween_callback(sprite.show)
	tween.tween_property(sprite, "position", to - sprite_size / 2.0, time / _speed) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(sprite.queue_free)


## A face-down card that travels between two places, growing or shrinking to
## the size of the card it lands on.
func _fly_card(from: Vector2, to: Vector2, from_size: Vector2, to_size: Vector2, time: float) -> void:
	var sprite := _sprite(UI.tex(UI.CARD_BACK), from, from_size)
	var tween := sprite.create_tween().set_parallel()
	tween.tween_property(sprite, "position", to - from_size / 2.0, time / _speed) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite, "scale", to_size / from_size, time / _speed) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.chain().tween_callback(sprite.queue_free)


## Text that drifts up from a point and fades.
func _float(text: String, at: Vector2, color: Color, font_size := 20) -> void:
	var l := UI.label(text, font_size, color, true)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", UI.INK)
	_fx.add_child(l)
	l.reset_size()
	l.position = at - l.size / 2.0
	l.position.x = clampf(l.position.x, 4, size.x - l.size.x - 4)
	UI.pop(l, 1.6, 0.2)
	var tween := l.create_tween()
	tween.tween_property(l, "position:y", l.position.y - 46, 1.0 / _speed).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(l, "modulate:a", 0.0, 0.4 / _speed).set_delay(0.6 / _speed)
	tween.tween_callback(l.queue_free)


## A status coming off a player, without a word: its chip cracks and flies
## apart, and so does whatever it looked like on their box.
func _anim_status_broken(d: Dictionary) -> void:
	var box: Variant = _node_of(d.player)
	if box == null:
		return
	var color: Color = Content.statuses.get(d.status, {}).get("color", UI.MUTED)
	var chip: Control = box.status_chip(d.status)
	if chip != null:
		var rect := chip.get_global_rect()
		_play_fx.line(rect.position + Vector2(rect.size.x * 0.62, -3), rect.position + Vector2(rect.size.x * 0.38, rect.size.y + 3),
				Color.WHITE, 2.0, 0.12, 0.06)
		UI.shake(chip, 3.0, 0.08)
		await _wait(0.08)
		_play_sfx("status_break")
		if is_instance_valid(chip):
			chip.modulate.a = 0.0
		_play_fx.burst(rect.get_center(), color, 10, 150.0, 0.45, 520.0, 6.0)
		_play_fx.burst(rect.get_center(), UI.CREAM, 4, 110.0, 0.35, 520.0, 4.0)
	else:
		_play_sfx("status_break")
	if d.status == &"entropy":
		# The chains do not crumble: they go all at once, and what is left
		# of them hangs in the air to be made into what they pay.
		var links: Array[Vector2] = box.status_pieces(d.status)
		var borrowed: bool = box.status_is_borrowed(d.status)
		box.sync()
		if d.get("reason", &"") == &"wasted":
			# Thrown away: nothing is left of them to be paid in.
			await _play_fx.chains_swallowed(links, borrowed)
		else:
			await _play_fx.chains_break(d.player, links, borrowed)
		return
	for piece: Vector2 in box.status_pieces(d.status):
		if d.status == &"truth_bound":
			# The seal, in bits of wax and nothing else.
			_play_fx.burst(piece, PlayFx.SEAL_WAX, 10, 170.0, 0.5, 520.0, 4.0)
			_play_fx.burst(piece, PlayFx.SEAL_WAX.lightened(0.3), 5, 120.0, 0.4, 520.0, 4.0)
			continue
		_play_fx.burst(piece, color.lightened(0.35), 7, 150.0, 0.45, 360.0, 6.0)
		_play_fx.ring(piece, color.lightened(0.5), 6.0, 26.0, 0.25, 3.0)
	await _wait(0.25)


## Somebody under oath claims something: the seal on their box jumps. The
## same for a truth as for a lie; it only reminds the table of what is at stake.
func _test_oath(p: PlayerState) -> void:
	var box: Variant = _node_of(p)
	if box == null or not p.has_status(&"truth_bound"):
		return
	box.seal_jolt()
	_play_fx.ring(box.seal_spot(), PlayFx.SEAL_WAX.lightened(0.45), 8.0, 38.0, 0.35, 3.0)


## A big word slammed over the stage.
func _stamp(text: String, color: Color) -> void:
	var l := UI.label(text, 64, color, true)
	l.add_theme_constant_override("outline_size", 12)
	l.add_theme_color_override("font_outline_color", UI.INK)
	_overlay.add_child(l)
	l.reset_size()
	l.pivot_offset = l.size / 2.0
	l.position = Vector2(576, 232) - l.size / 2.0
	l.rotation = -0.1
	l.scale = Vector2.ONE * 3.0
	l.modulate.a = 0.0
	var tween := l.create_tween()
	tween.tween_property(l, "scale", Vector2.ONE, 0.16 / _speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(l, "modulate:a", 1.0, 0.08 / _speed)
	tween.tween_interval(0.55 / _speed)
	tween.tween_property(l, "modulate:a", 0.0, 0.2 / _speed)
	tween.tween_callback(l.queue_free)
	await _wait(0.85)


## A ribbon that sweeps across the table (turn changes, game start and end).
func _banner(title: String, subtitle: String, color: Color, hold: float) -> void:
	var ribbon := Panel.new()
	var sb := UI.box(Color(UI.INK, 0.9), color, 0, 0, 0)
	sb.border_width_top = 3
	sb.border_width_bottom = 3
	ribbon.add_theme_stylebox_override("panel", sb)
	ribbon.size = Vector2(size.x, 84 if subtitle != "" else 62)
	ribbon.position = Vector2(-size.x, 206)
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(ribbon)
	var heading := UI.label(title, 38, color, true)
	heading.size = Vector2(size.x, 50)
	heading.position = Vector2(0, 4)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ribbon.add_child(heading)
	if subtitle != "":
		var sub := UI.label(subtitle, 16, UI.MUTED)
		sub.size = Vector2(size.x, 22)
		sub.position = Vector2(0, 52)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ribbon.add_child(sub)
	var tween := ribbon.create_tween()
	tween.tween_property(ribbon, "position:x", 0.0, 0.18 / _speed).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_interval(hold / _speed)
	tween.tween_property(ribbon, "position:x", size.x, 0.16 / _speed).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_callback(ribbon.queue_free)
	await _wait(0.2 + hold)


func _shake_screen(strength: float) -> void:
	UI.shake(_table, strength, 0.3)


func _node_of(p: PlayerState) -> Control:
	if p != null and p == viewer:
		return _hero
	return _seats.get(p.id) if p != null else null


func _anchor(p: PlayerState) -> Vector2:
	if p == null:
		return _bank()
	if p == viewer:
		return _hero.hand_center()
	var seat: SeatView = _seats.get(p.id)
	return seat.anchor() if seat != null else _bank()


func _stat_bar(p: PlayerState) -> StatBar:
	if p == null:
		return null
	if p == viewer:
		return _hero.stat_bar()
	var seat: SeatView = _seats.get(p.id)
	return seat.stat_bar() if seat != null else null


## Where the item at `index` of the inventory of `p` is drawn.
func _item_spot(p: PlayerState, index: int) -> Vector2:
	if p == viewer:
		return _hero.item_spot(index)
	var seat: SeatView = _seats.get(p.id)
	return seat.item_spot(index) if seat != null else _bank()


func _coin_anchor(p: PlayerState) -> Vector2:
	if p == viewer:
		return _hero.coin_anchor()
	var seat: SeatView = _seats.get(p.id)
	return seat.coin_anchor() if seat != null else _bank()


## The card on screen at `index` of the hand of `p`, null if it is not drawn.
func _card_view(p: PlayerState, index: int) -> CardView:
	if p == viewer:
		return _hero.card(index)
	var seat: SeatView = _seats.get(p.id)
	return seat.card(index) if seat != null else null


## Empties or fills the places of `cards` in their hands while the cards
## themselves are flying across the table.
func _set_cards_shown(cards: Array, shown: bool) -> void:
	for card: Variant in cards:
		if card != null and is_instance_valid(card):
			card.modulate.a = 1.0 if shown else 0.0


func _card_center(p: PlayerState, index: int) -> Vector2:
	if p == viewer:
		return _hero.card_center(index)
	var seat: SeatView = _seats.get(p.id)
	return seat.card_center(index) if seat != null else _bank()


## What the viewer pays right now for something priced at `amount` (a status
## may have raised every price for them).
func _price(amount: int) -> int:
	return engine.price(viewer, amount) if viewer != null else amount


## The colour prices are written in for the viewer: gold, or the colour of
## the status that is raising them.
func _price_ink() -> Color:
	if viewer != null:
		for status_id: StringName in viewer.statuses:
			if int(viewer.statuses[status_id].get("surcharge", 0)) > 0:
				var color: Color = Content.statuses.get(status_id, {}).get("color", UI.GOLD)
				return color.lightened(0.15)
	return UI.GOLD


func _bank() -> Vector2:
	return _shop.global_position + Vector2(_shop_width - SHOP_DECK_WIDTH + 31, 48)
