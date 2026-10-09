extends ColorRect
## The "how to play" overlay: a tutorial in a handful of lessons. Each lesson
## has a stage on the left, built from the widgets of the table itself (cards,
## items, hearts and coins, status chips), where the player tries the rule
## out, and its text on the right, with a small task that is ticked off once
## done. Nothing here touches a match: the stage is a toy. Shared by the
## title screen and the pause menu; add it as a child and it covers the screen
## until closed. It has no class name: preload it where it is needed.

signal closed

const Stall := preload("res://scripts/ui/shop_stall.gd")

const SIZE := Vector2(1040, 584)
const STAGE := Rect2(24, 92, 600, 412)
## The strip at the foot of the stage that says what just happened.
const NOTE := Rect2(14, 350, 572, 56)
const COLUMN := Rect2(640, 92, 376, 412)
const FELT := Color("1b3226")
## The match the lessons are played in: the player's hand and the other
## characters around.
const HAND: Array[StringName] = [&"heir", &"assassin"]
const OTHERS: Array[StringName] = [&"judge", &"spy", &"magician", &"bard"]
const RIVAL := "Bones"
const FINE := 4
const REROLL := 2
const INVENTORY := 3
## What the shop lesson starts with: one item of each kind.
const SHELF: Array[StringName] = [&"shield", &"potion", &"silencer"]
## How much smaller than the screen the table of the last lesson is drawn.
const MAP_SCALE := 0.5

## tab, title, text and task are translation keys (text and task as BBCode);
## build is the method that sets the stage.
const LESSONS := [
	{
		"tab": "THE CARDS",
		"title": "Everyone lies in Carcaj",
		"text": "Each player holds [b]character cards[/b] that nobody else sees.\n\nOn your turn you may [color=#e6bc4c]claim[/color] the ability of [b]any[/b] character in the match. The cards in your hand only decide which abilities are legitimate.\n\nWhoever hears a claim may answer it with [color=#c8402f]LIAR![/color]\n\nThe last player with Morale left becomes the new owner of Carcaj.",
		"task": "Click your two cards to look at them.",
		"build": &"_lesson_cards",
	},
	{
		"tab": "YOUR TURN",
		"title": "One claim per turn",
		"text": "You collect your income and then:\n\n[color=#e6bc4c]•[/color] [b]Buy and use items[/b], as many as you like.\n[color=#e6bc4c]•[/color] [b]Claim one ability.[/b] A card of your hand is the [color=#78a846]truth[/color]; any other character is a [color=#c8402f]bluff[/color]. The claim ends your turn, so deal with your items first.\n\nOr press END TURN and keep your coins.\n\n[b]Reactions[/b] are claimed outside your turn: the game asks you whenever you may use one.",
		"task": "Claim one ability honestly and another as a bluff.",
		"build": &"_lesson_turn",
	},
	{
		"tab": "LIAR!",
		"title": "Call the bluff",
		"text": "When someone claims an ability, anyone else may call [color=#c8402f]LIAR![/color] Only the first call counts.\n\n[color=#c8402f]•[/color] [b]If it is a lie:[/b] the liar loses 1 Morale and the ability fails.\n[color=#78a846]•[/color] [b]If it is the truth:[/b] you pay a fine in coins, the ability goes through and the proven card is traded for a new one.\n\nNo coins for the fine? You put 1 Morale on the line instead.",
		"task": "Call LIAR! on one of the claims.",
		"build": &"_lesson_liar",
	},
	{
		"tab": "MORALE",
		"title": "Three lives",
		"text": "Morale is your life. At 0 Morale, you are eliminated.\n\nYour hand can never be larger than your Morale. When you drop to 1, you give up a card, which is shown to the whole table. Recover Morale and you get to draw one back.\n\n[b]Statuses[/b] are the coloured tags next to a player: effects that last for a while. Hover one to read what it does.",
		"task": "Take hits until you have to give up a card.",
		"build": &"_lesson_morale",
	},
	{
		"tab": "SHOP",
		"title": "One shop for the whole table",
		"text": "The shop sits in the corner next to the deck. Hover it to open, click it to keep it open. A double click or a right click on an item buys it right away.\n\n[color=#e6bc4c]•[/color] [b]Active[/b] items are used on your turn, from your inventory.\n[color=#e6bc4c]•[/color] [b]Passive[/b] items work by themselves while you hold them.\n[color=#e6bc4c]•[/color] [b]Reaction[/b] items are offered the moment they can be used.\n\nA reroll replaces every slot; what is marked ALWAYS never leaves the shelf.",
		"task": "Buy an item.",
		"build": &"_lesson_shop",
	},
	{
		"tab": "THE TABLE",
		"title": "Know your way around",
		"text": "This is the table as you will see it in a match.\n\nHover anything in the game for details: cards, items, statuses, buttons.\n\nEsc or a right click cancels a target. F11 toggles fullscreen.",
		"task": "Point at every part of the table.",
		"build": &"_lesson_table",
	},
]

## The parts of the table, for the last lesson: [label, where on the real
## screen, what it is, what is drawn in it]. Parts with the same text count as
## one.
const PARTS := [
	["TURN", Rect2(8, 6, 250, 34), "Shows whose turn it is.", &""],
	["MENU", Rect2(1060, 6, 84, 34), "Pause, settings, this guide and the way out.", &""],
	["OPPONENT", Rect2(98, 138, 176, 126), "An opponent: name, Morale, coins, statuses, items and the backs of their cards.", &"seat"],
	["OPPONENT", Rect2(488, 19, 176, 126), "An opponent: name, Morale, coins, statuses, items and the backs of their cards.", &"seat"],
	["OPPONENT", Rect2(878, 138, 176, 126), "An opponent: name, Morale, coins, statuses, items and the backs of their cards.", &"seat"],
	["THE MIDDLE", Rect2(380, 196, 392, 150), "Every claim is shown here, with a mark that also shows where it comes from and its target. The questions the game asks you show up here too.", &""],
	["LOG", Rect2(8, 334, 232, 136), "Everything that happened in the match, in case you really need to look it up.", &"log"],
	["SHOP", Rect2(984, 364, 84, 106), "The shop, folded: hover it to see the items and their prices.", &"shop"],
	["DECK", Rect2(1070, 364, 74, 106), "The characters nobody holds. A card that proved a claim goes back here.", &"deck"],
	["YOU", Rect2(0, 478, 228, 62), "Your name, Morale and coins, and the statuses on you.", &"stats"],
	["YOUR ITEMS", Rect2(0, 542, 228, 106), "Your inventory. On your turn, click an item to use it.", &"items"],
	["YOUR HAND", Rect2(232, 478, 196, 170), "Your cards. Click one to claim an ability of it: that play is legitimate.", &"hand"],
	["THE OTHER CHARACTERS", Rect2(432, 478, 586, 170), "Every other character of the match. Click one to claim an ability of it: but mind the risk of being caught lying.", &"rack"],
	["END TURN", Rect2(1022, 478, 130, 170), "Passes the turn without claiming anything. Extra options of the turn show up under it.", &"end"],
]

var _tabs: Array = []  # Button, one per lesson
var _done: Array = []  # bool, one per lesson
var _index := 0
var _panel: Panel
var _stage: Control
var _note: RichTextLabel
var _title: Label
var _text: RichTextLabel
var _task: RichTextLabel
var _task_box: PanelContainer
var _next: Button
var _count: Label
## Whatever the lesson on stage keeps track of; emptied when it changes.
var _s: Dictionary = {}


func _init() -> void:
	color = Color(0, 0, 0, 0.78)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 30
	theme = UI.theme()
	Content.ensure_loaded()

	_panel = Panel.new()
	_panel.add_theme_stylebox_override("panel", UI.box(Color(UI.INK, 0.98), UI.GOLD, 3, 8, 0))
	_panel.size = SIZE
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -SIZE.x / 2.0
	_panel.offset_top = -SIZE.y / 2.0
	_panel.offset_right = SIZE.x / 2.0
	_panel.offset_bottom = SIZE.y / 2.0
	add_child(_panel)
	var heading := UI.label("HOW TO PLAY", 26, UI.GOLD, true)
	heading.position = Vector2(0, 10)
	heading.size = Vector2(SIZE.x, 34)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(heading)

	var gap := 6.0
	var width := floorf((SIZE.x - 48.0 - gap * (LESSONS.size() - 1)) / LESSONS.size())
	for i: int in LESSONS.size():
		var b := UI.button(LESSONS[i].tab, UI.BORDER, 14)
		b.position = Vector2(24 + i * (width + gap), 50)
		b.size = Vector2(width, 30)
		b.pressed.connect(_show.bind(i))
		_panel.add_child(b)
		_tabs.append(b)
		_done.append(false)

	var felt := Panel.new()
	felt.add_theme_stylebox_override("panel", UI.box(FELT, UI.BORDER.darkened(0.2), 2, 4, 0))
	felt.position = STAGE.position
	felt.size = STAGE.size
	felt.clip_contents = true
	_panel.add_child(felt)
	_stage = Control.new()
	_stage.size = STAGE.size
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	felt.add_child(_stage)
	var rule := ColorRect.new()
	rule.color = Color(0, 0, 0, 0.35)
	rule.position = Vector2(2, NOTE.position.y - 8)
	rule.size = Vector2(STAGE.size.x - 4, STAGE.size.y - NOTE.position.y + 6)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	felt.add_child(rule)
	_note = _rich(15)
	_note.position = NOTE.position
	_note.size = NOTE.size
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	felt.add_child(_note)

	_title = UI.label("", 21, UI.GOLD, true)
	_title.position = COLUMN.position
	_title.size = Vector2(COLUMN.size.x, 28)
	_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_panel.add_child(_title)
	_text = _rich(16)
	_text.position = COLUMN.position + Vector2(0, 34)
	_text.size = Vector2(COLUMN.size.x, 292)
	_text.mouse_filter = Control.MOUSE_FILTER_PASS
	_panel.add_child(_text)
	_task_box = PanelContainer.new()
	_task_box.position = COLUMN.position + Vector2(0, 334)
	_task_box.size = Vector2(COLUMN.size.x, 78)
	_panel.add_child(_task_box)
	_task = _rich(16)
	_task.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_task_box.add_child(_task)

	var previous := UI.button("<", UI.BORDER, 18)
	previous.position = Vector2(364, 520)
	previous.size = Vector2(46, 44)
	previous.pressed.connect(_step.bind(-1))
	_panel.add_child(previous)
	var back := UI.button("Back", UI.BORDER, 18)
	back.position = Vector2(420, 520)
	back.size = Vector2(200, 44)
	back.pressed.connect(close)
	_panel.add_child(back)
	_next = UI.button(">", UI.BORDER, 18)
	_next.position = Vector2(630, 520)
	_next.size = Vector2(46, 44)
	_next.pressed.connect(_step.bind(1))
	_panel.add_child(_next)
	_count = UI.label("", 15, UI.MUTED, true)
	_count.position = Vector2(COLUMN.position.x, 520)
	_count.size = Vector2(COLUMN.size.x, 44)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_panel.add_child(_count)


func _ready() -> void:
	# The stage lives on hover cards; the title screen has no layer for them.
	if TipLayer.current == null:
		add_child(TipLayer.new())
	_show(0)


func close() -> void:
	closed.emit()
	queue_free()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _stage != null and is_inside_tree():
		_show(_index)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		_step(-1)
	elif event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		_step(1)


func _step(by: int) -> void:
	_show(posmod(_index + by, LESSONS.size()))


## Sets the stage for a lesson, from scratch.
func _show(index: int) -> void:
	_index = index
	var lesson: Dictionary = LESSONS[index]
	if TipLayer.current != null:
		TipLayer.current.hide_all()
	UI.clear(_stage)
	_s = {}
	_note.text = ""
	_title.text = Loc.t(lesson.title)
	_text.text = Loc.t(lesson.text)
	_count.text = "%d / %d" % [index + 1, LESSONS.size()]
	call(lesson.build)
	_refresh()


## The task of the lesson on stage is done.
func _complete() -> void:
	if _done[_index]:
		return
	_done[_index] = true
	_refresh()
	UI.pop(_task_box, 1.06)
	UI.pop(_next, 1.3)


func _refresh() -> void:
	var lesson: Dictionary = LESSONS[_index]
	var done: bool = _done[_index]
	var ink := UI.GREEN if done else UI.GOLD
	_task.text = "[b][color=%s]%s[/color][/b]\n%s" % [UI.hex(ink), Loc.t("DONE" if done else "TRY IT"), Loc.t(lesson.task)]
	_task_box.add_theme_stylebox_override("panel", UI.box(ink.darkened(0.78), ink.darkened(0.25), 2, 4, 10))
	# Done: the way on lights up.
	_next.add_theme_stylebox_override("normal", UI.box(UI.GOLD.darkened(0.55), UI.GOLD, 2, 4, 6) if done else UI.box(UI.PANEL_LIGHT, UI.BORDER, 2, 4, 6))
	_next.add_theme_color_override("font_color", UI.GOLD if done else UI.CREAM)
	for i: int in _tabs.size():
		var b: Button = _tabs[i]
		var on := i == _index
		var accent := UI.GOLD if on else (UI.GREEN.darkened(0.2) if _done[i] else UI.BORDER.darkened(0.3))
		b.add_theme_stylebox_override("normal", UI.box(accent.darkened(0.6) if on else UI.PANEL, accent, 2, 4, 6))
		b.add_theme_color_override("font_color", UI.GOLD if on else (UI.GREEN if _done[i] else UI.MUTED))


# --- stage props ---------------------------------------------------------------

func _rich(font_size: int) -> RichTextLabel:
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.add_theme_font_size_override("normal_font_size", roundi(font_size * UI.FONT_SCALE))
	text.add_theme_font_size_override("bold_font_size", roundi(font_size * UI.FONT_SCALE))
	return text


## What just happened on the stage, as translated BBCode.
func _say(bbcode: String) -> void:
	_note.text = bbcode
	_note.modulate.a = 0.0
	_note.create_tween().tween_property(_note, "modulate:a", 1.0, 0.15)


func _tag(text: String, at: Vector2, ink: Color = UI.MUTED) -> Label:
	var tag := UI.label(text, 12, ink, true)
	tag.position = at
	_stage.add_child(tag)
	return tag


func _card(id: StringName, face: bool, card_scale: float, at: Vector2, parent: Control = null) -> CardView:
	var card := CardView.new(card_scale)
	card.position = at
	card.set_card(id, face)
	(parent if parent != null else _stage).add_child(card)
	return card


func _named(id: StringName) -> String:
	return Content.character(id).display_name


## A player of the stage: hearts and coins are the real ones of the table.
func _player(player_name: String, morale: int, coins: int) -> PlayerState:
	var p := PlayerState.new()
	p.name = player_name
	p.morale = morale
	p.coins = coins
	return p


func _stats(p: PlayerState, at: Vector2, parent: Control = null, icon := 20) -> StatBar:
	var bar := StatBar.new(icon, 17)
	bar.position = at
	(parent if parent != null else _stage).add_child(bar)
	bar.sync(p, 3)
	return bar


# --- 1: the cards --------------------------------------------------------------

func _lesson_cards() -> void:
	_tag("YOUR HAND", Vector2(40, 16), UI.GOLD)
	var seen := [false, false]
	for i: int in HAND.size():
		var card := _card(HAND[i], false, 1.5, Vector2(40 + i * 98, 42))
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.clicked.connect(func() -> void:
			if seen[i]:
				return
			seen[i] = true
			card.set_card(card.card_id, true, true)
			card.highlight(UI.GREEN)
			if seen.has(false):
				_say(Loc.t("One more."))
				return
			_say(Loc.t("You hold the [b]%s[/b] and the [b]%s[/b]: those you can claim at no risk at all. Any other character, only by bluffing. Hover a card to read its abilities.") % [_named(HAND[0]), _named(HAND[1])])
			_complete())
	_tag("ALSO IN THIS MATCH", Vector2(292, 16))
	for i: int in OTHERS.size():
		var card := _card(OTHERS[i], true, 1.15, Vector2(292 + i * 74, 42))
		card.set_caption(_named(OTHERS[i]))
	_tag("WHAT THE OTHERS SEE OF YOUR HAND", Vector2(292, 190))
	for i: int in HAND.size():
		var back := _card(&"", false, 0.7, Vector2(292 + i * 46, 214))
		back.interactive = false
	_say(Loc.t("Your cards lie face down: nobody but you gets to look at them."))


# --- 2: your turn --------------------------------------------------------------

func _lesson_turn() -> void:
	_tag("YOUR HAND", Vector2(24, 12), UI.GREEN)
	_tag("THE OTHER CHARACTERS", Vector2(212, 12), UI.RED)
	var menu := VBoxContainer.new()
	menu.position = Vector2(24, 164)
	menu.size = Vector2(552, 178)
	menu.add_theme_constant_override("separation", 2)
	_stage.add_child(menu)
	_s = {"menu": menu, "cards": [], "tried": {true: false, false: false}}
	var ids: Array[StringName] = HAND + OTHERS
	for i: int in ids.size():
		var held := i < HAND.size()
		var card := _card(ids[i], true, 1.15, Vector2(24 + i * 74 + (0 if held else 40), 40))
		card.set_caption(_named(ids[i]))
		card.note = "You hold this card." if held else ""
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.clicked.connect(_turn_open.bind(card, held))
		_s.cards.append(card)
	_say(Loc.t("It is your turn. Click a card, yours or not, to see what you can claim with it."))


## The menu of a character, as on the table: its abilities, each with what it
## does written under it.
func _turn_open(card: CardView, held: bool) -> void:
	var def := Content.character(card.card_id)
	var ink := UI.GREEN if held else UI.RED
	# The hover card says the same as the menu, and would lie on top of it.
	if TipLayer.current != null:
		TipLayer.current.hide_all()
	for other: CardView in _s.cards:
		other.highlight(ink if other == card else null)
	var menu: VBoxContainer = _s.menu
	UI.clear(menu)
	var heading := UI.label(def.display_name.to_upper(), 16, UI.GOLD, true)
	heading.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	menu.add_child(heading)
	menu.add_child(UI.label("You hold this card: claiming it is the truth." if held else "Not in your hand: claiming it is a bluff.", 13, ink))
	for ability: Ability in def.abilities:
		var text := ability.display_name
		if ability.cost > 0:
			text += "  ·  " + Loc.t("%d coins") % ability.cost
		var about := ability.description
		if ability.on_turn:
			var b := UI.button(text, ink, 14)
			b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			b.pressed.connect(_turn_claim.bind(ability, held))
			menu.add_child(b)
		else:
			# Not for the turn: it is listed, but there is nothing to press.
			var line := UI.label("%s  ·  %s" % [text, ability.kind_label()], 14, UI.BLUE, true)
			line.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			menu.add_child(line)
			if ability.trigger_text != "":
				about = "%s: %s" % [ability.trigger_text, about]
		var note := UI.label(about, 12, UI.MUTED)
		note.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size.x = menu.size.x
		menu.add_child(note)
	_say(Loc.t("Green is the truth, red is a bluff. Pick an ability to claim it."))


func _turn_claim(ability: Ability, held: bool) -> void:
	_s.tried[held] = true
	if held:
		_say(Loc.t("[color=#78a846][b]The truth.[/b][/color] You claim [b]%s[/b] and your turn ends. Whoever calls LIAR! on it pays for the mistake.") % ability.display_name)
	else:
		_say(Loc.t("[color=#c8402f][b]A bluff.[/b][/color] If nobody calls LIAR!, [b]%s[/b] works just the same. If someone does, you lose 1 Morale.") % ability.display_name)
	if _s.tried[true] and _s.tried[false]:
		_complete()


# --- 3: LIAR! ------------------------------------------------------------------

func _lesson_liar() -> void:
	var rival := _player(RIVAL, 3, 5)
	var you := _player("", 3, 6)
	_s = {"rival": rival, "you": you, "round": 0}
	var boxes := []
	for side: int in 2:
		var box := Panel.new()
		box.add_theme_stylebox_override("panel", UI.box(Color(UI.PANEL, 0.96), UI.BORDER, 2, 4, 0))
		box.position = Vector2(24 + side * 352, 14)
		box.size = Vector2(200, 150)
		_stage.add_child(box)
		var title := UI.label(RIVAL.to_upper() if side == 0 else "YOU", 15, UI.CREAM if side == 0 else UI.GOLD, true)
		title.position = Vector2(10, 4)
		box.add_child(title)
		boxes.append(box)
	_s.rival_box = boxes[0]
	_s.you_box = boxes[1]
	_s.rival_stats = _stats(rival, Vector2(10, 28), boxes[0])
	_s.you_stats = _stats(you, Vector2(10, 28), boxes[1])
	_s.rival_cards = []
	for i: int in 2:
		var back := _card(&"", false, 0.8, Vector2(52 + i * 50, 60), boxes[0])
		back.interactive = false
		_s.rival_cards.append(back)
		var mine := _card(HAND[i], true, 0.8, Vector2(52 + i * 50, 60), boxes[1])
		mine.interactive = false
	var versus := UI.label("VS", 22, UI.MUTED, true)
	versus.position = Vector2(224, 70)
	versus.size = Vector2(152, 30)
	versus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage.add_child(versus)
	var prompt := PanelContainer.new()
	prompt.add_theme_stylebox_override("panel", UI.box(Color(UI.INK, 0.96), UI.GOLD, 3, 6, 10))
	prompt.position = Vector2(24, 176)
	prompt.size = Vector2(552, 160)
	_stage.add_child(prompt)
	_s.prompt = VBoxContainer.new()
	_s.prompt.add_theme_constant_override("separation", 6)
	prompt.add_child(_s.prompt)
	_liar_ask()


## The two claims of the lesson: the first one is a lie, the second the truth.
func _liar_claim() -> Ability:
	return Content.abilities[&"heir.sold_out" if _s.round == 0 else &"assassin.blood_count"]


func _liar_ask() -> void:
	var ability := _liar_claim()
	var def := Content.character(ability.character_id)
	var box: VBoxContainer = _s.prompt
	UI.clear(box)
	var claim := _rich(16)
	claim.fit_content = true
	claim.scroll_active = false
	claim.text = Loc.t("[b]%s[/b] claims [b][color=%s]%s[/color][/b]: %s.") % [RIVAL, UI.hex(UI.GOLD), def.display_name, ability.display_name] \
			+ "\n[color=%s]%s[/color]" % [UI.hex(UI.MUTED), ability.description]
	box.add_child(claim)
	var question := UI.label(Loc.t("You hold %d of the %d %s cards. Is it a lie?") % [1, 3, def.display_name], 15, UI.CREAM)
	question.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	box.add_child(question)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	_s.asking = [question, row]
	var liar := UI.button("LIAR!", UI.RED, 18)
	liar.custom_minimum_size = Vector2(150, 40)
	liar.pressed.connect(_liar_answer.bind(true))
	TipLayer.attach(liar, Loc.t("If it is the truth, you pay %d coins.") % FINE)
	row.add_child(liar)
	var skip := UI.button("Let it pass", UI.BORDER, 16)
	skip.custom_minimum_size = Vector2(150, 40)
	skip.pressed.connect(_liar_answer.bind(false))
	row.add_child(skip)
	_say(Loc.t("%s is claiming an ability. You don't see their cards, all you have is what you hold yourself.") % RIVAL)


func _liar_answer(doubt: bool) -> void:
	var rival: PlayerState = _s.rival
	var you: PlayerState = _s.you
	var ability := _liar_claim()
	var who := _named(ability.character_id)
	if _s.round == 0:
		if doubt:
			rival.morale -= 1
			UI.shake(_s.rival_box)
			_say(Loc.t("[color=#c8402f][b]Caught![/b][/color] %s did not hold the %s: 1 Morale lost, and the ability fails.") % [RIVAL, who])
		else:
			rival.coins += 4
			_say(Loc.t("Nobody doubted, so it goes through: %s takes the coins. It was a lie, and now you will never know.") % RIVAL)
	else:
		rival.coins -= ability.cost
		you.morale -= 1
		UI.shake(_s.you_box)
		if doubt:
			you.coins -= FINE
			# The card that proved the claim is shown, then traded for another.
			var proven: CardView = _s.rival_cards[0]
			proven.set_card(ability.character_id, true, true)
			var later := proven.create_tween()
			later.tween_interval(1.6)
			later.tween_callback(proven.set_card.bind(&"", false, true))
			_say(Loc.t("[color=#78a846][b]It was the truth.[/b][/color] You pay the fine of %d coins, the ability still hits you, and %s trades the proven %s for a new card.") % [FINE, RIVAL, who])
		else:
			_say(Loc.t("It goes through: you lose 1 Morale. This one was the truth: doubting it would have cost you %d coins on top.") % FINE)
	_s.rival_stats.sync(rival, 3)
	_s.you_stats.sync(you, 3)
	if doubt:
		_complete()
	# The claim stays on the table; the question gives way to the verdict.
	var box: VBoxContainer = _s.prompt
	for part: Control in _s.asking:
		box.remove_child(part)
		part.queue_free()
	var last: bool = _s.round == 1
	var verdict := UI.label("IT WAS THE TRUTH" if last else "IT WAS A LIE", 20, UI.GREEN if last else UI.RED, true)
	box.add_child(verdict)
	UI.pop(verdict, 1.25)
	var again := UI.button("Start over" if last else "Next claim", UI.GOLD, 16)
	again.custom_minimum_size = Vector2(180, 40)
	again.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if last:
		again.pressed.connect(_show.bind(_index))
	else:
		again.pressed.connect(func() -> void:
			_s.round = 1
			_liar_ask())
	box.add_child(again)


# --- 4: morale -----------------------------------------------------------------

func _lesson_morale() -> void:
	var you := _player("", 3, 4)
	_s = {"you": you, "cards": [], "giving": false}
	_tag("YOU", Vector2(40, 14), UI.GOLD)
	_s.stats = _stats(you, Vector2(40, 36), null, 28)
	_tag("YOUR HAND", Vector2(40, 78))
	for id: StringName in HAND:
		_morale_draw(id)
	_s.hit = UI.button("Take a hit", UI.RED, 16)
	_s.hit.position = Vector2(330, 36)
	_s.hit.size = Vector2(230, 40)
	_s.hit.pressed.connect(_morale_hit)
	_stage.add_child(_s.hit)
	_s.heal = UI.button("Recover Morale", UI.GREEN, 16)
	_s.heal.position = Vector2(330, 84)
	_s.heal.size = Vector2(230, 40)
	_s.heal.pressed.connect(_morale_heal)
	_stage.add_child(_s.heal)
	_tag("STATUSES", Vector2(330, 150))
	var chips := HFlowContainer.new()
	chips.position = Vector2(330, 172)
	chips.size = Vector2(240, 80)
	chips.add_theme_constant_override("h_separation", 4)
	chips.add_theme_constant_override("v_separation", 4)
	_stage.add_child(chips)
	for status_id: StringName in Content.statuses:
		var def: Dictionary = Content.statuses[status_id]
		var tint: Color = def.get("color", UI.MUTED)
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", UI.box(tint.darkened(0.45), tint, 1, 3, 4))
		chip.mouse_filter = Control.MOUSE_FILTER_PASS
		var word := UI.label(Loc.t(def.get("name", String(status_id))).to_upper(), 11, UI.CREAM, true)
		word.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		chip.add_child(word)
		TipLayer.attach(chip, "[b]%s[/b]\n%s" % [Loc.t(def.get("name", String(status_id))), Loc.t(def.get("description", ""))])
		chips.add_child(chip)
	_morale_sync()
	_say(Loc.t("Three hearts, two cards. See what a hit does to your hand."))


func _morale_draw(id: StringName) -> void:
	var card := _card(id, true, 1.3, Vector2(40 + _s.cards.size() * 84, 100))
	card.clicked.connect(_morale_give.bind(card))
	_s.cards.append(card)


func _morale_sync() -> void:
	var you: PlayerState = _s.you
	_s.stats.sync(you, 3)
	_s.hit.text = "Start over" if you.morale == 0 else "Take a hit"
	_s.hit.disabled = _s.giving
	_s.heal.disabled = _s.giving or you.morale == 0 or you.morale == 3
	for card: CardView in _s.cards:
		card.highlight(UI.GOLD if _s.giving else null)
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _s.giving else Control.CURSOR_ARROW
		card.modulate = Color(0.45, 0.42, 0.4) if you.morale == 0 else Color.WHITE


func _morale_hit() -> void:
	var you: PlayerState = _s.you
	if you.morale == 0:
		_show(_index)
		return
	you.morale -= 1
	UI.shake(_s.stats, 5.0)
	match you.morale:
		2:
			_say(Loc.t("2 Morale left. Your hand is still whole: it holds two cards."))
		1:
			_s.giving = true
			_say(Loc.t("[color=#e6bc4c][b]1 Morale: choose a card to give up.[/b][/color] The whole table gets to see which one."))
		0:
			_say(Loc.t("[color=#c8402f][b]You are out.[/b][/color] The cards you held stay on the table, face up, out of the match."))
	_morale_sync()


func _morale_give(card: CardView) -> void:
	if not _s.giving:
		return
	_s.giving = false
	_s.cards.erase(card)
	card.settle()
	card.highlight(null)
	var leave := card.create_tween().set_parallel()
	leave.tween_property(card, "position:y", card.position.y - 40.0, 0.3)
	leave.tween_property(card, "modulate:a", 0.0, 0.3)
	leave.chain().tween_callback(card.queue_free)
	for i: int in _s.cards.size():
		var kept: CardView = _s.cards[i]
		kept.create_tween().tween_property(kept, "position:x", 40.0 + i * 84, 0.2)
	_say(Loc.t("The %s goes back to the deck. With 1 Morale you hold a single card.") % _named(card.card_id))
	_morale_sync()
	_complete()


func _morale_heal() -> void:
	var you: PlayerState = _s.you
	you.morale += 1
	if _s.cards.size() < mini(HAND.size(), you.morale):
		_morale_draw(OTHERS[0])
		UI.pop(_s.cards.back(), 1.2)
		_say(Loc.t("Morale recovered: your hand has room again, and you draw a card from the deck."))
	else:
		_say(Loc.t("Morale recovered."))
	_morale_sync()


# --- 5: the shop ---------------------------------------------------------------

func _lesson_shop() -> void:
	var you := _player("", 3, 15)
	var pool := Content.item_list().filter(func(def: ItemDef) -> bool: return not def.fixed)
	var shelf: Array = []
	for id: StringName in SHELF:
		if Content.items.has(id):
			shelf.append(Content.items[id])
	for def: ItemDef in pool:
		if shelf.size() < SHELF.size() and not shelf.has(def):
			shelf.append(def)
	_s = {"you": you, "pool": pool, "next": 0, "shelf": shelf, "views": [], "prices": [], "bag": []}
	# The goods sit low on the stage, with room above them for their hover
	# cards; what the player has is beside the stall, out of their way.
	_tag("YOU", Vector2(406, 132), UI.GOLD)
	_s.stats = _stats(you, Vector2(406, 152))

	var stall := Stall.new()
	stall.position = Vector2(40, 150)
	stall.size = Vector2(24 + shelf.size() * 80 + 72, 106)
	stall.shelves = [75.0]
	stall.pinned = true
	_stage.add_child(stall)
	var title := UI.label("SHOP", 11, UI.GOLD, true)
	title.position = Vector2(12, 3)
	stall.add_child(title)
	for i: int in shelf.size():
		var x := 12.0 + i * 80.0
		var view := ItemView.new(0.9)
		view.position = Vector2(x, 18)
		view.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		view.clicked.connect(_shop_buy.bind(i))
		view.picked.connect(_shop_buy.bind(i))
		stall.add_child(view)
		stall.add_child(_coin(Vector2(x + 10, 82)))
		var price := UI.label("", 15, UI.GOLD, true)
		price.position = Vector2(x + 30, 81)
		price.size = Vector2(30, 16)
		price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		stall.add_child(price)
		_s.views.append(view)
		_s.prices.append(price)
	var reroll_x := 12.0 + shelf.size() * 80.0
	var apart := ColorRect.new()
	apart.color = UI.BORDER.darkened(0.3)
	apart.position = Vector2(reroll_x - 6, 16)
	apart.size = Vector2(2, 80)
	stall.add_child(apart)
	# The same button as on the table: just the two arrows.
	var reroll := Button.new()
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		reroll.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	reroll.position = Vector2(reroll_x + 10, 24)
	reroll.size = Vector2(48, 48)
	reroll.pivot_offset = reroll.size / 2.0
	reroll.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	reroll.draw.connect(UI.draw_reroll.bind(reroll))
	reroll.pressed.connect(_shop_reroll)
	TipLayer.attach(reroll, "Replaces every item on the shelf.")
	stall.add_child(reroll)
	stall.add_child(_coin(Vector2(reroll_x + 16, 82)))
	var cost := UI.label(str(REROLL), 15, UI.GOLD, true)
	cost.position = Vector2(reroll_x + 36, 81)
	cost.size = Vector2(30, 16)
	cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stall.add_child(cost)

	_tag("YOUR INVENTORY", Vector2(406, 186))
	for i: int in INVENTORY:
		var socket := Panel.new()
		socket.add_theme_stylebox_override("panel", UI.box(FELT.darkened(0.35), UI.BORDER.darkened(0.35), 2, 3, 0))
		socket.position = _shop_socket(i)
		socket.size = Vector2(60, 60)
		socket.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stage.add_child(socket)
	_shop_stock()
	_say(Loc.t("The shelf is the same for everybody: what you buy, nobody else can. Click an item to buy it, or hover it to read what it does."))


func _coin(at: Vector2) -> TextureRect:
	var coin := TextureRect.new()
	coin.texture = UI.tex("res://assets/ui/coin.png")
	coin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.position = at
	coin.size = Vector2(16, 16)
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return coin


func _shop_socket(index: int) -> Vector2:
	return Vector2(406 + index * 62, 206)


## Puts on the shelf what `_s.shelf` says is there.
func _shop_stock() -> void:
	for i: int in _s.views.size():
		var def: ItemDef = _s.shelf[i]
		var view: ItemView = _s.views[i]
		if view.def != def:
			view.set_item(def)
			UI.pop(view, 1.25)
		_s.prices[i].text = str(def.price)


## The next item of the pool that is not on the shelf already.
func _shop_fresh() -> ItemDef:
	var pool: Array = _s.pool
	for _attempt: int in pool.size():
		var def: ItemDef = pool[_s.next % pool.size()]
		_s.next += 1
		if not _s.shelf.has(def):
			return def
	return pool[0]


func _shop_pay(amount: int, from: Control) -> bool:
	var you: PlayerState = _s.you
	if you.coins < amount:
		UI.shake(from, 4.0)
		_say(Loc.t("[color=#c8402f]Not enough coins.[/color] In a match you would wait for the income of your next turns, or claim an ability that pays."))
		return false
	you.coins -= amount
	_s.stats.sync(you, 3)
	return true


func _shop_buy(slot: int) -> void:
	var def: ItemDef = _s.shelf[slot]
	var view: ItemView = _s.views[slot]
	var bag: Array = _s.bag
	if bag.size() >= INVENTORY:
		UI.shake(view, 4.0)
		_say(Loc.t("Your inventory is full: use an item before you buy another."))
		return
	if not _shop_pay(def.price, view):
		return
	# The hover card of what was just sold.
	if TipLayer.current != null:
		TipLayer.current.hide_all()
	var bought := ItemView.new(0.9)
	bought.set_item(def)
	bought.position = view.global_position - _stage.global_position
	_stage.add_child(bought)
	bought.create_tween().tween_property(bought, "position", _shop_socket(bag.size()) + Vector2(2, 1), 0.3) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	bag.append(bought)
	_s.shelf[slot] = _shop_fresh()
	_shop_stock()
	match def.kind:
		ItemDef.Kind.PASSIVE:
			_say(Loc.t("You buy the [b]%s[/b], a [b]passive[/b] item: it works by itself while you hold it. A new item takes its place on the shelf.") % def.display_name)
		ItemDef.Kind.REACTION:
			_say(Loc.t("You buy the [b]%s[/b], a [b]reaction[/b] item: the game offers it the moment it can be used. A new item takes its place on the shelf.") % def.display_name)
		_:
			_say(Loc.t("You buy the [b]%s[/b], an [b]active[/b] item: on your turn, click it in your inventory to use it. A new item takes its place on the shelf.") % def.display_name)
	_complete()


func _shop_reroll() -> void:
	if not _shop_pay(REROLL, _s.views[0].get_parent()):
		return
	var fresh: Array = []
	for i: int in _s.shelf.size():
		fresh.append(_shop_fresh())
	_s.shelf = fresh
	_shop_stock()
	_say(Loc.t("A reroll costs %d coins and replaces every item on the shelf, for the whole table.") % REROLL)


# --- 6: the table --------------------------------------------------------------

func _lesson_table() -> void:
	var board := Panel.new()
	board.add_theme_stylebox_override("panel", UI.box(Color("2b1a10"), UI.INK, 2, 2, 0))
	board.position = Vector2(12, 12)
	board.size = Vector2(1152, 648) * MAP_SCALE
	board.clip_contents = true
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(board)
	var art := TextureRect.new()
	art.texture = UI.tex("res://assets/table.png")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.position = Vector2(2, 2)
	art.size = board.size - Vector2(4, 4)
	art.modulate = Color(0.7, 0.7, 0.7)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(art)
	# The counter the player sits at, across the bottom.
	var counter := ColorRect.new()
	counter.color = Color("3b2216")
	counter.position = Vector2(2, 478 * MAP_SCALE)
	counter.size = Vector2(board.size.x - 4, board.size.y - 478 * MAP_SCALE - 2)
	counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(counter)
	_s = {"seen": {}, "spots": []}
	for part: Array in PARTS:
		var where: Rect2 = part[1]
		var spot := Button.new()
		spot.position = where.position * MAP_SCALE + Vector2(1, 1)
		spot.size = where.size * MAP_SCALE - Vector2(2, 2)
		spot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		spot.mouse_entered.connect(_table_point.bind(spot))
		spot.pressed.connect(_table_point.bind(spot))
		board.add_child(spot)
		_table_prop(spot, part[3])
		var plate := UI.label(part[0], 9, UI.CREAM, true)
		plate.position = Vector2(4, 1)
		spot.add_child(plate)
		_s.spots.append({"spot": spot, "name": part[0], "about": part[2], "plate": plate})
	_table_paint(null)
	_say(Loc.t("Point at a part of the table to learn what it is."))


## What stands in a part of the little table: the real thing, only smaller.
func _table_prop(spot: Button, kind: StringName) -> void:
	var foot := spot.size.y - 5.0
	match kind:
		&"seat":
			_table_cards(spot, [&"", &""], false, 0.36, foot)
		&"hand":
			_table_cards(spot, HAND, true, 0.62, foot)
		&"rack":
			_table_cards(spot, OTHERS, true, 0.62, foot)
		&"deck":
			_table_cards(spot, [&""], false, 0.36, foot)
		&"shop", &"items":
			var ids: Array = SHELF.slice(0, 2) if kind == &"shop" else SHELF.slice(0, 1)
			for i: int in ids.size():
				var item := ItemView.new(0.3)
				item.set_item(Content.items.get(ids[i]))
				item.position = Vector2(8, 14 + i * 17)
				item.mouse_filter = Control.MOUSE_FILTER_IGNORE
				spot.add_child(item)
		&"stats":
			var bar := StatBar.new(10, 9)
			bar.position = Vector2(48, 9)
			spot.add_child(bar)
			bar.sync(_player("", 3, 2), 3)
		&"log":
			for i: int in 4:
				var line := ColorRect.new()
				line.color = Color(UI.MUTED, 0.5)
				line.position = Vector2(8, 20 + i * 10)
				line.size = Vector2([86, 64, 92, 50][i], 2)
				line.mouse_filter = Control.MOUSE_FILTER_IGNORE
				spot.add_child(line)
		&"end":
			var brass := Panel.new()
			brass.add_theme_stylebox_override("panel", UI.box(UI.GOLD.darkened(0.45), UI.GOLD, 1, 2, 0))
			brass.position = Vector2(6, 22)
			brass.size = Vector2(spot.size.x - 12, 22)
			brass.mouse_filter = Control.MOUSE_FILTER_IGNORE
			spot.add_child(brass)


## A row of small cards standing on `foot`, in the middle of `spot`.
func _table_cards(spot: Button, ids: Array, face: bool, card_scale: float, foot: float) -> void:
	var card_size := CardView.BASE * card_scale
	var step := card_size.x + 3.0
	var left := (spot.size.x - (ids.size() * step - 3.0)) / 2.0
	for i: int in ids.size():
		var card := _card(ids[i], face, card_scale, Vector2(roundf(left + i * step), roundf(foot - card_size.y)), spot)
		card.interactive = false
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _table_point(spot: Button) -> void:
	var all := true
	for entry: Dictionary in _s.spots:
		if entry.spot == spot:
			_s.seen[entry.about] = true
			_say("[b][color=%s]%s[/color][/b]  %s" % [UI.hex(UI.GOLD), Loc.t(entry.name), Loc.t(entry.about)])
	for entry: Dictionary in _s.spots:
		all = all and _s.seen.has(entry.about)
	_table_paint(spot)
	if all:
		_complete()


## Parts already pointed at stay marked; `current` is the one under the mouse.
func _table_paint(current: Button) -> void:
	for entry: Dictionary in _s.spots:
		var spot: Button = entry.spot
		var seen: bool = _s.seen.has(entry.about)
		var ink := UI.GOLD if spot == current else (UI.GREEN.darkened(0.1) if seen else UI.BORDER)
		var fill := Color(UI.GOLD.darkened(0.5), 0.45) if spot == current else Color(UI.INK, 0.45)
		for state: String in ["normal", "hover", "pressed", "focus"]:
			spot.add_theme_stylebox_override(state, UI.box(fill, ink, 2 if spot == current else 1, 2, 0))
		entry.plate.add_theme_color_override("font_color", UI.GOLD if spot == current else (UI.GREEN if seen else UI.CREAM))
