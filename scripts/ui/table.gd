extends Control
## The match screen. It owns a GameEngine and plays two roles for it:
## observer (present: animate every event) and the human players' hands
## (request: turn a Decision into clickable things and return the answer).

signal answered(value: Variant)
signal doubt_answered(decision: Decision, value: Variant)

const ARC_CENTER := Vector2(576, 322)
const ARC_RADIUS := Vector2(450, 240)
const MENU_SCENE := "res://scenes/menu.tscn"
const END_SCENE := "res://scenes/end.tscn"
## Loaded up front; the sound of each item ("item_<id>") is loaded on first use.
const SOUNDS := ["doubt", "damage", "breaking", "spend", "coin_1", "coin_2", "coin_3", "card_draw", "truth", "lie", "cancel", "heal", "item_get", "item_use"]
const SOUND_DIR := "res://assets/sounds/"
## Different clinks of a coin, played in turn so a pile does not sound like one note.
const COIN_SOUNDS := 3
## Most coins shown (and heard) flying for one change of coins.
const MAX_COINS_SHOWN := 12
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
## Where, and how large, a card is shown when the table stops to look at it.
const SHOWN_SCALE := 2.5
const SHOWN_CENTRE := Vector2(576, 236)
const SHOP_HEIGHT := 106.0
const SHOP_TAB_WIDTH := 126.0  # folded: mini icons + deck
const SHOP_DECK_WIDTH := 62.0
const LOG_SIZE := Vector2(232, 136)
const LOG_HEADER := 20.0  # the strip with the fold button; all that shows while folded

var engine: GameEngine
var viewer: PlayerState  # whose hand is on screen; null while spectating

var _speed := 1.0
var _humans: Array = []
var _pending: Decision
var _open_doubts: Array = []  # Decision: humans asked about the same claim
var _handoff: Dictionary = {}  # a picked card waiting for its animation: {veil, player, card, lifted}
var _seats: Dictionary = {}  # player id -> SeatView
var _hero: HeroPanel
var _table: Control
var _arrows: Control  # under whatever the mouse is on (see _lift_hovered)
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
var _log_box: PanelContainer
var _log_toggle: Button
var _log_folded := false
var _log_bottom := 470.0  # the log hangs from here, folded or not
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
	_prompt_shared_doubt()


func _process(_delta: float) -> void:
	_lift_hovered()
	# A shop opened by hovering folds again once the mouse leaves it, unless
	# it was pinned or one of its menus is still up.
	if not _shop_open or _shop_pinned or _popup.get_child_count() > 0:
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

	_arrows = _layer()
	_fx = _layer()
	_overlay = _layer()
	_popup = _layer()
	_modal = _layer()
	# Above anything _lift_hovered brings forward.
	for layer: Control in [_fx, _overlay, _popup, _modal]:
		layer.z_index = 2
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
	var title := UI.label("Log", 12, UI.MUTED)
	title.position = Vector2(8, 2)
	_log_panel.add_child(title)
	# Discreet on purpose: no frame, and nothing changes under the mouse.
	_log_toggle = Button.new()
	_log_toggle.focus_mode = Control.FOCUS_NONE
	_log_toggle.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_log_toggle.add_theme_font_size_override("font_size", roundi(16 * UI.FONT_SCALE))
	for state: String in ["normal", "hover", "pressed", "focus"]:
		_log_toggle.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		_log_toggle.add_theme_color_override(state, UI.MUTED)
	_log_toggle.size = Vector2(20, LOG_HEADER)
	_log_toggle.position = Vector2(LOG_SIZE.x - 22, 0)
	_log_toggle.pressed.connect(func():
		_log_folded = not _log_folded
		_place_log())
	_log_panel.add_child(_log_toggle)
	_place_log()


func _place_log() -> void:
	var height := LOG_HEADER + 2.0 if _log_folded else LOG_SIZE.y
	_log.visible = not _log_folded
	_log_toggle.text = "+" if _log_folded else "-"
	_log_panel.position = Vector2(8, _log_bottom - height)
	_log_panel.size = Vector2(LOG_SIZE.x, height)
	_log_box.size = _log_panel.size


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
	_place_log()
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
	if d.kind == Decision.Kind.DOUBT and d.context.get("shared", false):
		return await _request_shared_doubt(d)
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


## The engine gave up on `d`: someone else called LIAR! first.
func withdraw(d: Decision) -> void:
	if _open_doubts.has(d):
		_open_doubts.erase(d)
		if _open_doubts.is_empty() and _pending == null:
			_hide_prompt()
		# Deferred: this runs inside the emission that carried the winning call.
		doubt_answered.emit.call_deferred(d, false)
	elif _pending == d:
		_answer(false)


## Several humans share the screen and are asked about a claim at once: one
## prompt for all of them, and whoever presses LIAR! first takes the call.
func _request_shared_doubt(d: Decision) -> Variant:
	_open_doubts.append(d)
	if _open_doubts.size() == 1:
		_prompt_shared_doubt.call_deferred()
	var value: Variant = false
	while true:
		var reply: Array = await doubt_answered
		if reply[0] == d:
			value = reply[1]
			break
	_open_doubts.erase(d)
	if _open_doubts.is_empty() and _pending == null:
		_hide_prompt()
		if TipLayer.current != null:
			TipLayer.current.hide_all()
	elif value is Dictionary:
		# This player reacted instead; the others are still being asked.
		_prompt_shared_doubt()
	return false if engine.aborted else value


func _prompt_shared_doubt() -> void:
	if _open_doubts.is_empty():
		return
	var play: Play = _open_doubts[0].context.play
	var text := _claim_line(play) + "\n[color=%s]%s[/color]" % [UI.hex(UI.MUTED), Loc.t("The first to call LIAR! takes it.")]
	var buttons := []
	for d: Decision in _open_doubts:
		for spec: Dictionary in _doubt_buttons(d):
			spec.text = "%s: %s" % [d.player.name, Loc.t(spec.text)]
			spec.action = doubt_answered.emit.bind(d, spec.stake)
			buttons.append(spec)
		for option: Dictionary in d.context.get("reactions", []):
			# Nothing here may tell the others what this player holds.
			var spec := _reaction_button(option, false)
			spec.text = "%s: %s" % [d.player.name, spec.text]
			spec.action = doubt_answered.emit.bind(d, option)
			buttons.append(spec)
	buttons.append({"text": "Nobody", "action": func():
		for d: Decision in _open_doubts.duplicate():
			doubt_answered.emit(d, false)})
	_show_prompt(text, buttons)


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
	var text := _claim_line(play, "\n[color=%s]%s[/color]" % [UI.hex(UI.MUTED),
		Loc.t("You hold %d of the %d %s cards. Is it a lie?") % [d.player.cards.count(def.id), engine.copies_in_play(), def.display_name]])
	if not d.options.has(GameEngine.STAKE_COINS):
		text += "\n[color=%s]%s[/color]" % [UI.hex(UI.BLUE), Loc.t("You don't have the %d coins a wrong call costs: pick what you put on the line.") % engine.config.doubt_cost]
	var buttons := _doubt_buttons(d)
	for option: Dictionary in d.context.get("reactions", []):
		buttons.append(_reaction_button(option, true))
	buttons.append({"text": "Let it pass", "action": _answer.bind(false)})
	_show_prompt(text, buttons)


## What is being claimed, as the first lines of a doubt prompt. `private` goes
## right under the claim (what only the player being asked may read).
func _claim_line(play: Play, private := "") -> String:
	var def := Content.character(play.ability().character_id)
	var text := Loc.t("[b]%s[/b] claims [b][color=%s]%s[/color][/b]: %s%s.") % [
		play.actor.name, UI.hex(UI.GOLD), def.display_name.to_upper(), play.source.display_name, _on_target(play)]
	text += private
	if play.actor.has_status(&"truth_bound"):
		text += "\n[color=%s]%s[/color]" % [UI.hex(UI.GOLD), Loc.t("%s is Under Oath and can't lie.") % play.actor.name]
	return text


## One LIAR! button per stake `d.player` may put up: {text, stake, action...}.
func _doubt_buttons(d: Decision) -> Array:
	var play: Play = d.context.play
	var cost := engine.config.doubt_cost
	var stakes: Array = d.options
	var bluff := Loc.t("Call the bluff.\nIf %s lied, they lose 1 Morale and the ability fails.") % play.actor.name
	var buttons := []
	for stake: StringName in stakes:
		var spec := {"text": "LIAR!", "stake": stake, "accent": UI.RED, "action": _answer.bind(stake)}
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


## The button that answers a decision with reaction `option`. `private`: only
## the player being asked is looking, so it may say whether it is a bluff.
func _reaction_button(option: Dictionary, private: bool) -> Dictionary:
	if option.kind != &"ability":
		var item: ItemDef = option.item.def
		return {
			"text": Loc.t("Use %s") % item.display_name, "tip": UI.item_tip(item),
			"accent": UI.BLUE, "action": _answer.bind(option),
		}
	var ability: Ability = option.ability
	var def := Content.character(ability.character_id)
	var cost := "  ·  %d" % ability.cost if ability.cost > 0 else ""
	var tip := UI.ability_tip(ability)
	var accent := UI.GOLD
	if private:
		tip += Loc.t("You hold %s: this is the truth." if option.legit else "You don't hold %s: this is a bluff.") % def.display_name
		accent = UI.GREEN if option.legit else UI.RED
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
		buttons.append(_reaction_button(option, true))
	buttons.append({"text": "Pass", "action": _answer.bind(null)})
	var why := ". ".join(triggers)
	_show_prompt("[b]%s[/b]\n[color=%s]%s[/color]" % [
		Loc.t("%s, you may react.") % d.player.name, UI.hex(UI.MUTED),
		why if why != "" else Loc.t("An opponent's ability is about to take effect.")], buttons)


func _open_pick(d: Decision) -> void:
	if d.options.all(func(option: Dictionary): return option.has("card")):
		_open_card_pick(d)
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
		var origin: CardView = _hero.card(i) if d.player == viewer else null
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
	if choice < 0:
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
		if spec.get("shady", false):
			_make_shady(b)
		if spec.has("price"):
			_add_price(b, spec.text, spec.price)
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
	var d := e.data
	# The roulette names its victim only once the cylinder has stopped.
	var held_line: bool = e.type == &"item_used" and d.play.source.id == ROULETTE
	if line != "" and not held_line:
		_log_line(line, e.type)
	match e.type:
		&"game_started":
			_sync()
			await _banner("WELCOME TO CARCAJ", "The last one standing takes the crown", UI.GOLD, 1.4)
		&"turn_started":
			_drop_transient_stage()
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
			_play_sfx("cancel")
			await _stamp("SILENCED", UI.BLUE)
		&"claim_resolved":
			await _pop_stage(d.play)
		&"item_buying":
			_sync_shop()
		&"item_bought":
			await _anim_item_bought(d)
		&"item_gained":
			_play_sfx("item_get")
			_float("+ %s" % (Loc.t("ITEM") if d.item.hidden and d.player != viewer else d.item.def.display_name.to_upper()), _anchor(d.player), UI.BLUE)
			await _wait(0.35)
		&"item_used":
			await _anim_item_used(d)
			if held_line:
				_log_line(line, e.type)
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
			_play_sfx("heal")
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
	await _wait(0.8)


func _anim_item_used(d: Dictionary) -> void:
	var play: Play = d.play
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


## The arrow from the actor of `play` to its target, null if there is none to draw.
func _stage_arrow(play: Play) -> ArrowFx:
	if play.target == null or play.target == play.actor:
		return null
	var arrow := ArrowFx.new()
	arrow.set_anchors_preset(Control.PRESET_FULL_RECT)
	arrow.from = _anchor(play.actor)
	arrow.to = _anchor(play.target)
	arrow.color = UI.RED if play.source.tags.has(&"damage") or play.source.tags.has(&"steal") else UI.GOLD
	_arrows.add_child(arrow)
	arrow.create_tween().tween_property(arrow, "progress", 1.0, 0.3 / _speed)
	return arrow


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
	elif play.target != null and not _stage_stack.back().get("concealed", false):
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
		_play_sfx("truth")
		await _stamp("TRUTH", UI.GREEN)
	else:
		_play_sfx("lie")
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
	var bar := _stat_bar(p)
	var other_bar := _stat_bar(d.other)
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
	_fly(texture, _shop_point(d.slot, instance.def), _anchor(d.player), Vector2(48, 50), 0.4)
	await _wait(0.42)


func _anim_item_broken(d: Dictionary) -> void:
	_play_sfx("item_%s" % d.item.def.id, "breaking")
	var at := _anchor(d.player)
	var icon := _sprite(UI.tex(d.item.def.texture_path), at, Vector2(70, 73))
	var tween := icon.create_tween()
	tween.tween_property(icon, "scale", Vector2.ONE * 1.5, 0.12)
	tween.tween_property(icon, "rotation", 0.3, 0.06)
	tween.tween_property(icon, "rotation", -0.3, 0.06)
	tween.tween_property(icon, "modulate:a", 0.0, 0.3)
	tween.tween_callback(icon.queue_free)
	await _stamp("%s!" % d.item.def.display_name.to_upper(), UI.BLUE)


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
		card.position = _anchor(loser) - card.size / 2.0
		card.scale = Vector2.ONE * 0.25
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


func _bank() -> Vector2:
	return _shop.global_position + Vector2(_shop_width - SHOP_DECK_WIDTH + 31, 48)
