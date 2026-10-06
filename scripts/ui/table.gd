extends Control
## The match screen. It owns a GameEngine and plays two roles for it:
## observer (present: animate every event) and the human players' hands
## (request: turn a Decision into clickable things and return the answer).

signal answered(value: Variant)

const ARC_CENTER := Vector2(576, 322)
const ARC_RADIUS := Vector2(450, 240)
const MENU_SCENE := "res://scenes/menu.tscn"
const END_SCENE := "res://scenes/end.tscn"
const SOUNDS := ["doubt", "damage", "breaking", "shield", "spend"]
const SHOP_HEIGHT := 106.0
const SHOP_TAB_WIDTH := 126.0  # folded: mini icons + deck
const SHOP_DECK_WIDTH := 62.0

var engine: GameEngine
var viewer: PlayerState  # whose hand is on screen; null while spectating

var _speed := 1.0
var _humans: Array = []
var _pending: Decision
var _seats: Dictionary = {}  # player id -> SeatView
var _hero: HeroPanel
var _table: Control
var _fx: Control
var _overlay: Control
var _shop: Control
var _shop_bg: Panel
var _shop_tab: Control  # what shows while folded
var _shop_body: Control  # what shows while open
var _shop_entries: Array = []  # {view, price, coin, mini, slot, def}; slot -1 = always on sale
var _shop_reroll: Button
var _shop_hint: Label
var _shop_width := 0.0
var _shop_open := false
var _shop_pinned := false
var _shop_tween: Tween
var _deck_label: Label
var _stage: PanelContainer
var _stage_stack: Array = []
var _prompt: PanelContainer
var _popup: Control
var _modal: Control
var _log: RichTextLabel
var _log_panel: Control
var _turn_label: Label
var _sfx: Dictionary = {}
var _music: AudioStreamPlayer
var _pause: Control


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
	for p: PlayerState in engine.players:
		var controller: Controller
		if p.is_bot:
			controller = BotController.new()
		else:
			controller = HumanController.new()
			controller.table = self
			_humans.append(p)
		controller.engine = engine
		controller.player = p
		engine.controllers[p.id] = controller
	# With several humans sharing the screen nobody's hand shows until the
	# device is handed over.
	viewer = _humans[0] if _humans.size() == 1 else null

	_build()
	_hero.setup(engine)
	_hero.bind(viewer)
	_layout_seats()
	_sync()
	engine.run.call_deferred()


func _exit_tree() -> void:
	engine.abort()
	# Wake whatever decision is pending so the engine coroutine can unwind.
	_pending = null
	answered.emit(null)


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
	# A shop opened by hovering folds again once the mouse leaves it, unless
	# it was pinned or one of its menus is still up.
	if not _shop_open or _shop_pinned or _popup.get_child_count() > 0:
		return
	if not _shop.get_global_rect().grow(8.0).has_point(get_global_mouse_position()):
		_set_shop_open(false)


func _unhandled_key_input(event: InputEvent) -> void:
	UI.handle_fullscreen_key(event, get_window())
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()


# === layout ===================================================================

func _build() -> void:
	var bg := TextureRect.new()
	bg.texture = UI.tex("res://assets/background.png")
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
	menu.position = Vector2(1070, 8)
	menu.size = Vector2(72, 28)
	menu.pressed.connect(_toggle_pause)
	TipLayer.attach(menu, "Pause, settings and quit (Esc).")
	add_child(menu)

	_prompt = PanelContainer.new()
	_prompt.add_theme_stylebox_override("panel", UI.box(Color(UI.INK, 0.96), UI.GOLD, 3, 6, 10))
	_prompt.visible = false
	add_child(_prompt)

	_fx = _layer()
	_overlay = _layer()
	_popup = _layer()
	_modal = _layer()
	add_child(TipLayer.new())

	_music = AudioStreamPlayer.new()
	_music.stream = load("res://assets/sounds/background.mp3")
	_music.volume_db = -10.0
	_music.bus = Settings.MUSIC_BUS
	add_child(_music)
	if _music.stream is AudioStreamMP3:
		_music.stream.loop = true
	_music.play()
	for sound: String in SOUNDS:
		var player := AudioStreamPlayer.new()
		player.stream = load("res://assets/sounds/%s.mp3" % sound)
		player.bus = Settings.SFX_BUS
		add_child(player)
		_sfx[sound] = player


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
	_shop_bg = Panel.new()
	_shop_bg.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_shop_bg.mouse_entered.connect(_set_shop_open.bind(true))
	_shop_bg.gui_input.connect(_on_shop_bg_input)
	_shop.add_child(_shop_bg)

	# The deck stays put at the right end whether the shop is open or not.
	var deck_x := _shop_width - SHOP_DECK_WIDTH
	var deck := CardView.new(0.62)
	deck.position = Vector2(deck_x + 14, 18)
	deck.interactive = false
	deck.mouse_entered.connect(_set_shop_open.bind(true))
	_shop.add_child(deck)
	TipLayer.attach(deck, "[b]Deck[/b]\nCharacters nobody holds. Eliminated players' cards are shuffled back in.")
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
		view.position = Vector2(x, 18)
		view.clicked.connect(_on_shop_clicked.bind(i))
		_shop_body.add_child(view)
		var coin := _shop_icon("res://assets/ui/coin.png", Vector2(x + 10, 82), Vector2(16, 16))
		_shop_body.add_child(coin)
		var price := UI.label("", 15, UI.GOLD, true)
		price.position = Vector2(x + 30, 79)
		_shop_body.add_child(price)
		var mini := _shop_icon("", Vector2(6 + (i % 2) * 27, 20 + (i >> 1) * 27), ItemView.BASE * 0.4)
		_shop_tab.add_child(mini)
		_shop_entries.append({
			"view": view, "price": price, "coin": coin, "mini": mini,
			"slot": i - fixed.size() if i >= fixed.size() else -1,
			"def": fixed[i] if i < fixed.size() else null,
		})

	var reroll_x := 12.0 + stock * 80.0
	_shop_reroll = UI.button("REROLL", UI.BLUE, 13)
	_shop_reroll.position = Vector2(reroll_x, 24)
	_shop_reroll.size = Vector2(68, 46)
	_shop_reroll.pressed.connect(_on_reroll_pressed)
	TipLayer.attach(_shop_reroll, _reroll_tip)
	_shop_body.add_child(_shop_reroll)
	_shop_body.add_child(_shop_icon("res://assets/ui/coin.png", Vector2(reroll_x + 18, 82), Vector2(16, 16)))
	var reroll_price := UI.label(str(engine.config.reroll_cost), 15, UI.GOLD, true)
	reroll_price.position = Vector2(reroll_x + 38, 79)
	_shop_body.add_child(reroll_price)
	_set_shop_open(false, true)


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
	_shop_bg.add_theme_stylebox_override("panel", UI.box(
			Color(UI.PANEL, 0.94), UI.GOLD if _shop_pinned else UI.BORDER, 2, 6, 0))
	_shop_hint.text = "pinned · click to unpin" if _shop_pinned else "click to keep open"


func _on_shop_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_shop_pinned = not _shop_pinned
		_set_shop_open(true)
		_restyle_shop()


func _build_stage() -> void:
	_stage = PanelContainer.new()
	_stage.position = Vector2(356, 166)
	_stage.custom_minimum_size = Vector2(440, 132)
	_stage.size = _stage.custom_minimum_size
	_stage.add_theme_stylebox_override("panel", UI.box(Color(UI.INK, 0.93), UI.GOLD, 3, 6, 10))
	_stage.visible = false
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_table.add_child(_stage)


func _build_log() -> void:
	var panel := PanelContainer.new()
	_log_panel = panel
	panel.position = Vector2(8, 334)
	panel.size = Vector2(232, 136)
	panel.add_theme_stylebox_override("panel", UI.box(Color(UI.INK, 0.72), UI.BORDER.darkened(0.3), 2, 4, 6))
	_table.add_child(panel)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.add_theme_font_size_override("normal_font_size", 14)
	_log.add_theme_font_size_override("bold_font_size", 14)
	_log.custom_minimum_size = Vector2(216, 120)
	panel.add_child(_log)


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
	_log_panel.position = Vector2(8, 506) if full_circle else Vector2(8, 334)
	_shop.position = Vector2(1144 - _shop_width, (642 if full_circle else 470) - SHOP_HEIGHT)
	for i in others.size():
		var p: PlayerState = others[i]
		var seat: SeatView = _seats.get(p.id)
		if seat == null:
			seat = SeatView.new()
			seat.bind(p, engine)
			seat.clicked.connect(_on_seat_clicked)
			_table.add_child(seat)
			_seats[p.id] = seat
		var degrees := 270.0
		if full_circle:
			degrees = 270.0 + 360.0 * i / others.size()
		elif others.size() > 1:
			degrees = 270.0 - spread / 2.0 + spread * i / (others.size() - 1)
		var angle := deg_to_rad(degrees)
		var radius := Vector2(410, 222) if full_circle else ARC_RADIUS
		seat.position = ARC_CENTER + Vector2(cos(angle), sin(angle)) * radius - SeatView.SIZE / 2.0
	_set_active(engine.current)


# === decisions ================================================================

func request(d: Decision) -> Variant:
	if d.player != viewer:
		await _hand_over(d.player)
	_pending = d
	match d.kind:
		Decision.Kind.TURN:
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
		if ability.cost > 0:
			text += "  ·  " + Loc.t("%d coins") % ability.cost
		var tip := UI.ability_tip(ability)
		if option.reason != "":
			tip += "[color=%s]%s[/color]" % [UI.hex(UI.RED), option.reason]
		elif option.credit:
			tip += "[color=%s]%s[/color]" % [UI.hex(UI.BLUE), Loc.t("You can't afford it: you will also claim Vagabond (On the Cuff).")]
		rows.append({
			"text": text, "tip": tip, "enabled": option.enabled,
			"accent": UI.GREEN if option.legit else UI.RED,
			"action": _answer_turn.bind(option), "reason": option.reason,
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
	if viewer == null:
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
	_open_popup(entry.view.get_global_rect(), def.display_name.to_upper(), def.description, UI.MUTED, [{
		"text": Loc.t("Buy  ·  %d coins") % def.price, "tip": tip, "enabled": option.enabled,
		"accent": UI.GOLD, "action": _answer_turn.bind(option), "reason": option.reason,
	}])


func _on_reroll_pressed() -> void:
	var options: Variant = _turn_options()
	if options != null and options.reroll != null and options.reroll.enabled:
		_answer_turn(options.reroll)


func _reroll_tip() -> String:
	var cost := engine.config.reroll_cost
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


func _on_seat_clicked(p: PlayerState) -> void:
	if _pending != null and _pending.kind == Decision.Kind.TARGET and _pending.options.has(p):
		_answer(p)


func _prompt_target(d: Decision) -> void:
	for p: PlayerState in d.options:
		if _seats.has(p.id):
			_seats[p.id].set_targetable(true)
	var buttons := []
	if d.cancellable:
		buttons.append({"text": "Cancel", "action": _answer.bind(null)})
	_show_prompt("[b]%s[/b]\n[color=%s]%s[/color]" % [d.prompt, UI.hex(UI.MUTED), Loc.t("Click a highlighted player.")], buttons)


func _prompt_doubt(d: Decision) -> void:
	var play: Play = d.context.play
	var def := Content.character(play.ability().character_id)
	var text := Loc.t("[b]%s[/b] claims [b][color=%s]%s[/color][/b]: %s%s.") % [
		play.actor.name, UI.hex(UI.GOLD), def.display_name.to_upper(), play.source.display_name, _on_target(play)]
	var held := d.player.cards.count(def.id)
	text += "\n[color=%s]%s[/color]" % [UI.hex(UI.MUTED),
		Loc.t("You hold %d of the %d %s cards. Is it a lie?") % [held, engine.copies_in_play(), def.display_name]]
	if play.actor.has_status(&"truth_bound"):
		text += "\n[color=%s]%s[/color]" % [UI.hex(UI.GOLD), Loc.t("%s is Under Oath and can't lie.") % play.actor.name]
	var cost := engine.config.doubt_cost
	if d.player.coins < cost:
		text += "\n[color=%s]%s[/color]" % [UI.hex(UI.BLUE), Loc.t("You can't afford to be wrong: if it was true, you will also claim Vagabond (On the Cuff).")]
	_show_prompt(text, [
		{
			"text": "LIAR!", "accent": UI.RED, "action": _answer.bind(true),
			"tip": Loc.t("Call the bluff.\nIf %s lied, they lose 1 Morale and the ability fails.\nIf it was true, you pay %d coins.") % [play.actor.name, cost],
		},
		{"text": "Let it pass", "action": _answer.bind(false)},
	])


func _prompt_react(d: Decision) -> void:
	var triggers := []
	var buttons := []
	for option: Dictionary in d.options:
		if option.kind == &"ability":
			var ability: Ability = option.ability
			var def := Content.character(ability.character_id)
			if not triggers.has(ability.trigger_text):
				triggers.append(ability.trigger_text)
			var cost := "  ·  %d" % ability.cost if ability.cost > 0 else ""
			var tip := UI.ability_tip(ability) + Loc.t("You hold %s: this is the truth." if option.legit else "You don't hold %s: this is a bluff.") % def.display_name
			if option.credit:
				tip += "\n[color=%s]%s[/color]" % [UI.hex(UI.BLUE), Loc.t("You can't afford it: you will also claim Vagabond.")]
			buttons.append({
				"text": "%s: %s%s" % [def.display_name, ability.display_name, cost], "tip": tip,
				"accent": UI.GREEN if option.legit else UI.RED, "action": _answer.bind(option),
			})
		else:
			var item: ItemDef = option.item.def
			buttons.append({
				"text": Loc.t("Use %s") % item.display_name, "tip": UI.item_tip(item),
				"accent": UI.BLUE, "action": _answer.bind(option),
			})
	buttons.append({"text": "Pass", "action": _answer.bind(null)})
	var why := ". ".join(triggers)
	_show_prompt("[b]%s[/b]\n[color=%s]%s[/color]" % [
		Loc.t("%s, you may react.") % d.player.name, UI.hex(UI.MUTED),
		why if why != "" else Loc.t("An opponent's ability is about to take effect.")], buttons)


func _open_pick(d: Decision) -> void:
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
			picture.set_item(option.item)
		if picture != null:
			picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			picture.clicked.connect(_answer.bind(i))
			column.add_child(picture)
		var b := UI.button(option.get("label", "?"), UI.GOLD, 14)
		b.pressed.connect(_answer.bind(i))
		column.add_child(b)
	if d.cancellable:
		var cancel := UI.button("Cancel", UI.BORDER, 14)
		cancel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cancel.pressed.connect(_answer.bind(-1))
		panel.add_child(cancel)


## Hot-seat: hide everything until the next human confirms they hold the device.
func _hand_over(next: PlayerState) -> void:
	_close_popup()
	var curtain := ColorRect.new()
	curtain.color = UI.INK
	curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(curtain)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	curtain.add_child(box)
	var title := UI.label("PASS THE DEVICE TO", 20, UI.MUTED, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var who := UI.label(next.name.to_upper(), 48, UI.GOLD, true)
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(who)
	var ready := UI.button(Loc.t("I am %s") % next.name, UI.GOLD, 20)
	ready.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(ready)
	viewer = next
	_hero.bind(viewer)
	_layout_seats()
	_sync()
	await ready.pressed
	UI.clear(_modal)


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
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(spec.action)
		if spec.has("tip"):
			TipLayer.attach(b, spec.tip)
		row.add_child(b)
	_prompt.visible = true
	_prompt.reset_size()
	await get_tree().process_frame
	_prompt.reset_size()
	_prompt.position = Vector2(576 - _prompt.size.x / 2.0, 474 - _prompt.size.y)
	UI.pop(_prompt, 1.08, 0.18)


func _hide_prompt() -> void:
	_prompt.visible = false
	UI.clear(_prompt)


## A small menu anchored to something on screen. rows: {info} for a text
## block, or {text, tip, enabled, accent, action} for a button.
func _open_popup(anchor: Rect2, title: String, subtitle: String, subtitle_color: Color, rows: Array) -> void:
	_close_popup()
	var catcher := Control.new()
	catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			_close_popup())
	_popup.add_child(catcher)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.box(Color(UI.INK, 0.97), UI.GOLD, 2, 6, 10))
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
		b.custom_minimum_size = Vector2(270, 36)
		b.disabled = not spec.get("enabled", true)
		b.pressed.connect(spec.action)
		if spec.has("tip"):
			TipLayer.attach(b, spec.tip)
		box.add_child(b)
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
	panel.add_theme_stylebox_override("panel", UI.box(Color(UI.INK, 0.98), UI.GOLD, 3, 8, 18))
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
	panel.add_theme_stylebox_override("panel", UI.box(Color(UI.INK, 0.98), UI.GOLD, 3, 8, 22))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_pause.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var heading := UI.label("PAUSED", 28, UI.GOLD, true)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)
	var resume := UI.button("Resume", UI.GOLD, 18)
	resume.custom_minimum_size = Vector2(240, 44)
	resume.pressed.connect(_toggle_pause)
	box.add_child(resume)
	var settings := UI.button("Settings", UI.BORDER, 18)
	settings.pressed.connect(func(): _pause.add_child(SettingsPanel.new()))
	box.add_child(settings)
	var fullscreen := UI.button("Fullscreen: on" if UI.is_fullscreen(get_window()) else "Fullscreen: off", UI.BORDER, 18)
	fullscreen.pressed.connect(func():
		UI.toggle_fullscreen(get_window())
		fullscreen.text = "Fullscreen: on" if UI.is_fullscreen(get_window()) else "Fullscreen: off")
	TipLayer.attach(fullscreen, "Also F11 or Alt+Enter, on any screen.")
	box.add_child(fullscreen)
	var quit := UI.button("Quit to menu", UI.RED, 18)
	quit.pressed.connect(func(): get_tree().change_scene_to_file(MENU_SCENE))
	box.add_child(quit)


# === presentation =============================================================

func present(e: GameEvent) -> void:
	var line := EventText.describe(e)
	if line != "":
		_log_line(line, e.type)
	var d := e.data
	match e.type:
		&"game_started":
			_sync()
			await _banner("WELCOME TO CARCAJ", "The last one standing takes the crown", UI.GOLD, 1.4)
		&"turn_started":
			_drop_transient_stage()
			_set_active(d.player)
			_show_turn()
			if d.player == viewer:
				await _banner("YOUR TURN", "", UI.GOLD, 0.8)
			else:
				await _banner(Loc.t("%s'S TURN") % d.player.name.to_upper(), "", UI.CREAM, 0.55)
		&"coins":
			await _anim_coins(d)
		&"claim_declared":
			await _anim_claim(d.play)
		&"doubt_declared":
			if d.play.params.get("standing", false):
				# Doubting something claimed long ago: bring it back on stage.
				_push_stage({"play": d.play, "arrow": null, "transient": true})
				await _wait(0.6)
			await _anim_doubt(d.doubter)
		&"doubt_revealed":
			await _anim_reveal(d.play, d.truthful)
		&"claim_cancelled":
			_play_sfx("shield")
			await _stamp("SILENCED", UI.BLUE)
		&"claim_resolved":
			await _pop_stage(d.play)
		&"item_buying":
			_sync_shop()
		&"item_bought":
			await _anim_item_bought(d)
		&"item_gained":
			_play_sfx("shield")
			_float("+ %s" % (Loc.t("ITEM") if d.item.hidden and d.player != viewer else d.item.def.display_name.to_upper()), _anchor(d.player), UI.BLUE)
			await _wait(0.35)
		&"item_used":
			await _anim_item_used(d)
		&"item_broken":
			await _anim_item_broken(d)
		&"shop_restocked":
			_sync_shop()
			_pop_shop_slot(d.slot)
		&"shop_rerolled":
			_sync_shop()
			for slot in engine.shop.size():
				_pop_shop_slot(slot)
			_float("REROLL", _shop_bg.get_global_rect().get_center() + Vector2(0, -40), UI.BLUE, 20)
			await _wait(0.4)
		&"morale_lost":
			await _anim_damage(d.target, d.amount)
		&"morale_gained":
			_play_sfx("shield")
			_float(Loc.t("+%d MORALE") % d.amount, _anchor(d.player), UI.GREEN, 22)
			await _wait(0.4)
		&"player_eliminated":
			_sync()
			_float("ELIMINATED", _anchor(d.player), UI.RED, 28)
			_shake_screen(10.0)
			await _wait(0.9)
		&"cards_changed":
			await _anim_card_traded(d)
		&"card_lost":
			await _anim_card_lost(d)
		&"card_drawn":
			_sync()
			await _anim_card_changed(d.player, d.index)
		&"cards_swapped":
			await _anim_cards_swapped(d)
		&"card_peeked":
			await _anim_peek(d)
		&"status_added":
			var def: Dictionary = Content.statuses.get(d.status, {})
			_float(Loc.t(def.get("name", String(d.status))).to_upper(), _anchor(d.player), def.get("color", UI.PURPLE).lightened(0.35), 20)
			await _wait(0.4)
		&"status_removed":
			var def: Dictionary = Content.statuses.get(d.status, {})
			_float(Loc.t("%s ENDS") % Loc.t(def.get("name", String(d.status))).to_upper(), _anchor(d.player), UI.MUTED, 14)
		&"counter_changed":
			var def: Dictionary = Content.counters.get(d.counter, {})
			if d.delta != 0 and (d.player == viewer or not def.get("private", false)):
				_float("%+d %s" % [d.delta, Loc.t(def.get("name", String(d.counter))).to_upper()], _anchor(d.player) + Vector2(0, -24), UI.BLUE, 18)
				await _wait(0.35)
		&"game_over":
			await _game_over(d.winner)
			return
	_sync()


func _sync() -> void:
	for seat: SeatView in _seats.values():
		seat.sync()
	_hero.sync()
	_sync_shop()


func _sync_shop() -> void:
	var options: Variant = _turn_options()
	for entry: Dictionary in _shop_entries:
		var def := _entry_def(entry)
		for node: Control in [entry.view, entry.price, entry.coin, entry.mini]:
			node.visible = def != null
		if def == null:
			continue
		entry.view.set_item(def)
		entry.mini.texture = UI.tex(def.texture_path)
		entry.price.text = str(def.price)
		var option: Variant = _buy_option(options, entry)
		var buyable: bool = option == null or option.enabled
		entry.view.set_enabled(buyable)
		entry.mini.modulate = Color.WHITE if buyable else Color(0.55, 0.5, 0.5, 0.9)
		var notes := PackedStringArray()
		if entry.slot < 0:
			notes.append(Loc.t("Always on sale."))
		if option != null:
			notes.append(Loc.t("Click to buy.") if option.enabled else option.reason)
		entry.view.note = " ".join(notes)
	var reroll: Variant = options.reroll if options != null else null
	_shop_reroll.visible = not engine.item_pool.is_empty()
	_shop_reroll.disabled = reroll == null or not reroll.enabled
	_deck_label.text = "x%d" % engine.deck.size()


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
	var notice := _no_doubt_notice(play)
	if notice == "":
		await _wait(0.8)
		return
	# Nobody asks a player who can't cover the fine: say why.
	_show_prompt("[color=%s]%s[/color]" % [UI.hex(UI.RED), notice], [])
	await _wait(1.8)
	if _pending == null:
		_hide_prompt()


## Tells the humans who won't be asked about `play` that they are too poor to
## call LIAR!. Empty when everyone at the screen can.
func _no_doubt_notice(play: Play) -> String:
	var cost := engine.config.doubt_cost
	var broke := _humans.filter(func(p: PlayerState):
		return p != play.actor and p.alive and not engine.can_doubt(p))
	if broke.is_empty():
		return ""
	if viewer != null:
		return Loc.t("You can't call LIAR!: you need %d coins to cover a wrong call.") % cost
	var names := ", ".join(broke.map(func(p: PlayerState): return p.name))
	return Loc.t("%s can't call LIAR!: %d coins are needed to cover a wrong call.") % [names, cost]


func _anim_item_used(d: Dictionary) -> void:
	var play: Play = d.play
	_play_sfx("damage" if play.source.tags.has(&"damage") else "shield")
	_push_stage({"play": play, "arrow": null, "transient": true})
	await _wait(0.9)


func _push_stage(entry: Dictionary) -> void:
	_drop_transient_stage()
	var play: Play = entry.play
	if play.target != null and play.target != play.actor:
		var arrow := ArrowFx.new()
		arrow.set_anchors_preset(Control.PRESET_FULL_RECT)
		arrow.from = _anchor(play.actor)
		arrow.to = _anchor(play.target)
		arrow.color = UI.RED if play.source.tags.has(&"damage") or play.source.tags.has(&"steal") else UI.GOLD
		_fx.add_child(arrow)
		arrow.create_tween().tween_property(arrow, "progress", 1.0, 0.3 / _speed)
		entry.arrow = arrow
	_stage_stack.append(entry)
	_render_stage()
	UI.pop(_stage, 1.12, 0.22)


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
		entry.arrow.queue_free()


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
		text.add_child(UI.label(play.source.display_name + _on_target(play) + cost, 17, UI.CREAM, true))
	elif play.target != null:
		text.add_child(UI.label(_on_target(play).strip_edges().capitalize(), 17, UI.CREAM, true))
	var description := UI.label(play.source.description, 12, UI.MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(300, 0)
	text.add_child(description)


func _on_target(play: Play) -> String:
	if play.target == null:
		return ""
	if play.target == play.actor:
		return Loc.t(" on themselves")
	return Loc.t(" on you") if play.target == viewer else Loc.t(" on %s") % play.target.name


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
		_play_sfx("shield")
		await _stamp("TRUTH", UI.GREEN)
	else:
		UI.shake(_stage, 12.0, 0.35)
		await _stamp("LIE!", UI.RED)
	if shown != null and is_instance_valid(shown):
		shown.set_card(&"", false, true)


# --- effects ------------------------------------------------------------------

func _anim_coins(d: Dictionary) -> void:
	var p: PlayerState = d.player
	var delta: int = d.delta
	var here := _coin_anchor(p)
	var there := _coin_anchor(d.other) if d.other != null else _bank()
	if d.reason == &"steal":
		# The coins already flew out of the victim's pile.
		_float("+%d" % delta, here + Vector2(0, -18), UI.GOLD, 22)
		await _wait(0.25)
		return
	if delta < 0 and (p == viewer or d.reason == &"shop"):
		_play_sfx("spend")
	var coins := clampi(absi(delta), 1, 6)
	for i in coins:
		var from := there if delta > 0 else here
		var to := here if delta > 0 else there
		_fly(UI.tex("res://assets/ui/coin.png"), from, to, Vector2(20, 20), 0.32, i * 0.045)
	await _wait(0.3 + coins * 0.045)
	_float("%+d" % delta, here + Vector2(0, -18), UI.GOLD if delta > 0 else UI.RED, 22)


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
	_fly(texture, _shop_point(d.slot, instance.def), _anchor(d.player), Vector2(48, 50), 0.4)
	await _wait(0.42)


func _anim_item_broken(d: Dictionary) -> void:
	_play_sfx("breaking")
	var at := _anchor(d.player)
	var icon := _sprite(UI.tex(d.item.def.texture_path), at, Vector2(70, 73))
	var tween := icon.create_tween()
	tween.tween_property(icon, "scale", Vector2.ONE * 1.5, 0.12)
	tween.tween_property(icon, "rotation", 0.3, 0.06)
	tween.tween_property(icon, "rotation", -0.3, 0.06)
	tween.tween_property(icon, "modulate:a", 0.0, 0.3)
	tween.tween_callback(icon.queue_free)
	await _stamp("%s!" % d.item.def.display_name.to_upper(), UI.BLUE)


func _anim_card_changed(p: PlayerState, index: int) -> void:
	_float("NEW CARD", _anchor(p) + Vector2(0, -30), UI.CREAM, 16)
	if p != viewer and _seats.has(p.id):
		var card: CardView = _seats[p.id].card(index)
		if card != null:
			card.flip()
	_fly(UI.tex(UI.CARD_BACK), _bank(), _card_center(p, index), Vector2(33, 60), 0.3)
	await _wait(0.4)


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
	var in_hand: CardView = _hero.card(d.index) if mine else null
	if in_hand != null:
		in_hand.modulate.a = 0.0
	card.position = slot
	card.scale = small
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
	_play_sfx("shield")
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
	if in_hand != null and is_instance_valid(in_hand):
		in_hand.modulate.a = 1.0
	if not mine and _seats.has(p.id):
		var seat_card: CardView = _seats[p.id].card(d.index)
		if seat_card != null:
			seat_card.flip()


## The card given up gets its moment: the table dims, the card travels from
## its owner to the centre, turns face up for everyone and only then goes back
## to the deck.
func _anim_card_lost(d: Dictionary) -> void:
	_sync()
	var def := Content.character(d.card)
	var loser: PlayerState = d.player
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
	var heading := _reveal_label(scene, who, 26, UI.RED, centre.y - card.size.y / 2.0 - 58)
	var name_label := _reveal_label(scene, def.display_name.to_upper(), 46, UI.GOLD, centre.y + card.size.y / 2.0 + 14)
	var caption := _reveal_label(scene, Loc.t("%s  ·  shuffled back into the deck") % def.title, 15, UI.CREAM, centre.y + card.size.y / 2.0 + 80)

	# Face down, out of the loser's hand and up to the centre.
	card.position = _anchor(loser) - card.size / 2.0
	card.scale = Vector2.ONE * 0.25
	var enter := scene.create_tween().set_parallel()
	enter.tween_property(dim, "modulate:a", 1.0, 0.25 / _speed)
	enter.tween_property(heading, "modulate:a", 1.0, 0.25 / _speed)
	enter.tween_property(card, "position", centre - card.size / 2.0, 0.45 / _speed) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	enter.tween_property(card, "scale", Vector2.ONE, 0.45 / _speed) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _wait(0.75)

	# The reveal.
	card.set_card(d.card, true, true)
	await _wait(0.12)
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

	# Back to the deck.
	pulse.kill()
	var leave := scene.create_tween().set_parallel()
	for node: Control in [glow, heading, name_label, caption]:
		leave.tween_property(node, "modulate:a", 0.0, 0.2 / _speed)
	leave.tween_property(dim, "modulate:a", 0.0, 0.4 / _speed)
	leave.tween_property(card, "position", _bank() - card.size / 2.0, 0.4 / _speed) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	leave.tween_property(card, "scale", Vector2.ONE * 0.14, 0.4 / _speed) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
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


func _anim_cards_swapped(d: Dictionary) -> void:
	var a := _card_center(d.a, d.a_index)
	var b := _card_center(d.b, d.b_index)
	_fly(UI.tex(UI.CARD_BACK), a, b, Vector2(44, 80), 0.45)
	_fly(UI.tex(UI.CARD_BACK), b, a, Vector2(44, 80), 0.45)
	await _wait(0.5)


func _anim_peek(d: Dictionary) -> void:
	var peeker: PlayerState = d.viewer
	var owner: PlayerState = d.owner
	if peeker.is_bot:
		_float("PEEK", _card_center(owner, d.index), UI.BLUE, 18)
		if owner == viewer:
			var card: CardView = _hero.card(d.index)
			if card != null:
				card.highlight(UI.BLUE)
				await _wait(0.9)
				card.highlight(null)
				return
		await _wait(0.6)
		return
	if peeker != viewer:
		await _hand_over(peeker)
	var box := _open_modal(Loc.t("One of %s's cards") % owner.name)
	var card := CardView.new(2.2)
	card.set_card(d.card, true)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(card)
	var ok := UI.button("Got it", UI.GOLD, 16)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(ok)
	await ok.pressed
	UI.clear(_modal)


func _game_over(winner: PlayerState) -> void:
	_sync()
	GameConfig.last_winner = winner.name if winner != null else ""
	await _banner(Loc.t("%s WINS") % winner.name.to_upper() if winner != null else "NO SURVIVORS", "Carcaj has a new boss", UI.GOLD, 2.2)
	get_tree().change_scene_to_file(END_SCENE)


# --- small fx helpers ---------------------------------------------------------

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds / _speed).timeout


func _play_sfx(sound: String) -> void:
	if _sfx.has(sound):
		_sfx[sound].play()


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


func _coin_anchor(p: PlayerState) -> Vector2:
	if p == viewer:
		return _hero.coin_anchor()
	var seat: SeatView = _seats.get(p.id)
	return seat.coin_anchor() if seat != null else _bank()


func _card_center(p: PlayerState, index: int) -> Vector2:
	if p == viewer:
		return _hero.card_center(index)
	var seat: SeatView = _seats.get(p.id)
	return seat.card_center(index) if seat != null else _bank()


func _bank() -> Vector2:
	return _shop.global_position + Vector2(_shop_width - SHOP_DECK_WIDTH + 31, 48)
