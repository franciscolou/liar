extends Control
## The book of suspicions: the viewer's notes on who holds which card, in an
## open book lying over the table. Every player still in the match has an
## entry with as many slots as a hand has cards, and smaller cards beside
## them. A card the player surely holds sits in a slot, with a tick on its
## corner; one they claimed and nobody knows about sits beside, with a
## question mark; one they surely do not hold sits beside too, greyed, with
## a cross. The book has two pages of notes over the same entries, on two
## index tabs, and turning from one to the other loses nothing of either:
## - AUTO is kept by the book itself, from what everybody at the table saw
##   happen (record): claims, doubts won and lost, cards given up, and the
##   few things only the viewer knows (a card they peeked at or handed over);
## - MANUAL is the viewer's own: every character lies faint beside the
##   slots, and a click on one changes its mark.
## It belongs to this screen alone: nothing in it reaches the engine or the
## room, and it only ever reads what the viewer is entitled to know.
## It is not modal (it is there to be read while a claim waits for an
## answer): the book can be dragged out of the way. Everything is drawn in
## code, in blocks. No class name: preload it.

signal closed
## The viewer changed a mark of the manual page, or turned the page.
signal marked

const Desk := preload("res://scripts/ui/noir_desk.gd")

## The marks of a card.
const NONE := 0
const MAYBE := 1
const HAS := 2
const NOT := 3
## The pages.
const AUTO := 0
const MANUAL := 1

const PX := 2.0
const TOP := 8.0  # where the book opens, from the top of the screen
## Touch mode: the book is made bigger whole, nearly the width of the screen;
## what is written in it keeps its desktop size inside (see UI.native).
const TOUCH_SCALE := 1.3
## The book: the leather showing around the pages, the room the index tabs
## take above it, the edges of the pages under the open ones, and a page.
const COVER := 10.0
const TAB_RISE := 20.0
const TAB := Vector2(116, 32)
const EDGES := 6.0
const PAGE_WIDTH := 420.0
const MARGIN := 16.0  # of a page, at its outer side
const GUTTER := 22.0  # and at the spine
const HEADER := 44.0
const FOOTER := 36.0
## An entry: the name over a rule, the slots and the cards beside them.
const ENTRY := 116.0
const ENTRY_WIDTH := PAGE_WIDTH - MARGIN - GUTTER
const CARDS_AT := 28.0  # under the name
const SLOT_SCALE := 0.8
const SLOT_STEP := 50.0
## The cards beside the slots: in one row while they fit, else in two
## rows of smaller ones.
const SIDE_SCALE := 0.64
const SIDE_STEP := 40.0
const SMALL_SCALE := 0.4
const SMALL_STEP := 26.0
const SMALL_ROW := 41.0
const LEATHER := Color("5a2a1c")
const LEATHER_LIGHT := Color("7c402b")
const LEATHER_DARK := Color("331610")
const STITCH := Color("c9a25a")
const RIBBON := Color("8e2018")
## The marks, in blocks, and the ink of each.
const GLYPHS := {
	MAYBE: [
		"..###..",
		".##.##.",
		"....##.",
		"...##..",
		"...#...",
		".......",
		"...#...",
	],
	HAS: [
		".......",
		"......#",
		".....##",
		"#...##.",
		"##.##..",
		".###...",
		"..#....",
	],
	NOT: [
		"#.....#",
		"##...##",
		".##.##.",
		"..###..",
		".##.##.",
		"##...##",
		"#.....#",
	],
}
const INKS := {MAYBE: Color("8a5a0c"), HAS: Color("2f6a1c"), NOT: Color("a3281c")}
const MARK_NAMES := {
	NONE: "No note.",
	MAYBE: "Might have it.",
	HAS: "Has it.",
	NOT: "Does not have it.",
}
## Why the automatic page marks a card as it does: a translation key with
## the turn it happened on.
const REASONS := {
	&"proven": "Proved it when doubted, on turn %d.",
	&"traded": "Proved it on turn %d, then traded it for a new card.",
	&"caught": "Caught lying about it on turn %d. Their hand has not changed since.",
	&"seen": "You saw it in their hand on turn %d.",
	&"given": "It went to their hand in a trade with you, on turn %d.",
	&"lost": "Gave one up on turn %d.",
	&"recalled": "Every copy in their hand went back to the deck on turn %d.",
	&"stale_has": "They had it on turn %d, but their hand has changed since.",
	&"stale_not": "They did not have it on turn %d, but their hand has changed since.",
	&"redrawn": "Drew a whole new hand on turn %d.",
}
const HINTS := {
	AUTO: "Kept by the book itself, from what happens at the table. Hover a card to see why.",
	MANUAL: "Yours to fill in: click a card to change its mark, right click to clear it.",
}
## The same, for a finger.
const TOUCH_HINTS := {
	AUTO: "Kept by the book itself, from what happens at the table. Hold a finger on a card to see why.",
	MANUAL: "Yours to fill in: tap a card to change its mark.",
}

## The page the book is on. It outlives the match: whoever likes one page
## finds the book on it in the next.
static var mode := AUTO

var _engine: GameEngine
var _viewer: PlayerState
## player id -> {character id -> {mark, why, turn, claims, last}}: `why` is a
## key of REASONS (or &""), `claims` how many times they claimed the
## character in the match and `last` the turn of the latest.
var _auto: Dictionary = {}
var _manual: Dictionary = {}  # player id -> {character id -> mark}
## Who kept their hand out of the Last Call that is resolving.
var _kept: Array = []
var _book: Control  # the book itself: cover and pages are drawn on it
var _entries: Control  # what is written on the pages; made again on every change
var _tabs: Dictionary = {}  # page -> Button
var _wipe: Button
var _shut: Button
var _hint: Label
var _legend: Control
var _page_height := 0.0
var _queued := false
var _placed := false
var _dragging := false


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func setup(engine: GameEngine, viewer: PlayerState) -> void:
	UI.native(_setup.bind(engine, viewer))


func _setup(engine: GameEngine, viewer: PlayerState) -> void:
	_engine = engine
	_viewer = viewer

	_book = Control.new()
	_book.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_book.draw.connect(_draw_book)
	_book.gui_input.connect(_on_book_input)
	if UI.touch:
		_book.scale = Vector2.ONE * TOUCH_SCALE
	add_child(_book)
	# The index tabs stand out of the top of the right page.
	for page: int in [AUTO, MANUAL]:
		var tab := Button.new()
		tab.text = "Automatic" if page == AUTO else "Manual"
		tab.focus_mode = Control.FOCUS_NONE
		tab.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tab.add_theme_font_size_override("font_size", UI.px(14))
		tab.pressed.connect(set_mode.bind(page))
		_book.add_child(tab)
		_tabs[page] = tab
	var right := COVER + PAGE_WIDTH
	var title := Desk.written("SUSPICIONS", 22, Desk.INK, true)
	title.position = Vector2(COVER + MARGIN, TAB_RISE + COVER + 6.0)
	_book.add_child(title)
	_shut = _penned("x", Vector2(28, 26))
	_shut.position = Vector2(right + PAGE_WIDTH - MARGIN - 28.0, TAB_RISE + COVER + 8.0)
	_shut.pressed.connect(shut)
	TipLayer.attach(_shut, "Close")
	_book.add_child(_shut)
	_wipe = _penned("Clear", Vector2(78, 26))
	_wipe.position = _shut.position - Vector2(84, 0)
	_wipe.pressed.connect(_on_wipe_pressed)
	TipLayer.attach(_wipe, "Erases every mark of the manual page.")
	_book.add_child(_wipe)
	_hint = Desk.written("", 13, Desk.INK_FADED)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_book.add_child(_hint)
	_hint.size = Vector2(ENTRY_WIDTH, FOOTER - 6.0)
	# What each mark means, at the foot of the right page.
	_legend = Control.new()
	_legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book.add_child(_legend)
	var x := 0.0
	for mark: int in [MAYBE, HAS, NOT]:
		var badge := _badge(mark, PX)
		_legend.add_child(badge)
		badge.position = Vector2(x, 0)
		var words := Desk.written(MARK_NAMES[mark].trim_suffix("."), 13, Desk.INK_FADED)
		_legend.add_child(words)
		words.position = Vector2(x + 23.0, 0)
		x += 23.0 + words.get_minimum_size().x + 14.0
	_entries = Control.new()
	_entries.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book.add_child(_entries)
	_rebuild()


func _penned(text: String, extent: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.size = extent
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", UI.px(14))
	# Filled in, so that it reads as a button against the page.
	var fills := {"normal": Desk.PAPER_DARK, "hover": Desk.PAPER_LIGHT, "pressed": Desk.PAPER_SHADE, "focus": Desk.PAPER_DARK}
	for state: String in fills:
		b.add_theme_stylebox_override(state, UI.box(fills[state], Desk.INK, 2, 2, 4))
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, Desk.INK)
	b.add_theme_font_override("font", UI.bold())
	return b


func is_open() -> bool:
	return visible


func toggle() -> void:
	if visible:
		shut()
	else:
		open()


func open() -> void:
	visible = true
	_rebuild()
	if not _placed:
		_placed = true
		_book.position = Vector2(roundf((size.x - _extent().x) / 2.0), TOP)


func shut() -> void:
	if not visible:
		return
	visible = false
	_dragging = false
	if TipLayer.current != null:
		TipLayer.current.hide_all()
	closed.emit()


## Turns to `page`. Both pages keep what is written on them.
func set_mode(page: int) -> void:
	if page == mode:
		return
	mode = page
	marked.emit()
	_refresh()


# === the automatic page ========================================================

## What the table just saw happen, for the automatic page. Called for every
## event, with the book open or shut and on either page.
func record(e: GameEvent) -> void:
	var d := e.data
	match e.type:
		&"turn_started":
			_kept.clear()
		&"claim_declared":
			if d.play.is_claim():
				_claimed(d.play.actor, d.play.ability().character_id)
		&"doubt_revealed":
			if d.play.is_claim():
				var id: StringName = d.play.ability().character_id
				if not d.truthful:
					_note(d.play.actor, id, NOT, &"caught")
				elif not d.play.stand_in:
					_note(d.play.actor, id, HAS, &"proven")
		&"cards_changed":
			_hand_changed(d.player)
			# The card that stood up to a doubt is the one that left.
			if d.reason == &"proven":
				_note(d.player, d.old, NONE, &"traded")
		&"card_drawn":
			_hand_changed(d.player)
		&"hand_redrawn":
			for id: StringName in _page(_auto, d.player.id):
				_note(d.player, id, NONE, &"redrawn")
		&"card_lost":
			_note(d.player, d.card, NONE, &"lost")
		&"cards_swapped":
			_hand_changed(d.a)
			_hand_changed(d.b)
			# The viewer knows the card they handed over.
			if d.a == _viewer and d.b_index < d.b.cards.size():
				_note(d.b, d.b.cards[d.b_index], HAS, &"given")
			elif d.b == _viewer and d.a_index < d.a.cards.size():
				_note(d.a, d.a.cards[d.a_index], HAS, &"given")
		&"card_peeked":
			if d.viewer == _viewer:
				_note(d.owner, d.card, HAS, &"seen")
		&"hand_missed":
			if d.how == &"recall":
				_kept.append(d.owner)
		&"cards_recalled":
			var redealt: Array = []
			for hand: Dictionary in d.hands:
				if not redealt.has(hand.player):
					redealt.append(hand.player)
					_hand_changed(hand.player)
			# Nobody is left with a copy, but for whoever kept their hand
			# out of it: the new cards were drawn before these went back.
			for p: PlayerState in _engine.players:
				if p.alive and not _kept.has(p):
					_note(p, d.card, NOT, &"recalled")
			_kept.clear()
	_refresh()


func _page(book: Dictionary, player_id: int) -> Dictionary:
	if not book.has(player_id):
		book[player_id] = {}
	return book[player_id]


func _entry(p: PlayerState, id: StringName) -> Dictionary:
	var page := _page(_auto, p.id)
	if not page.has(id):
		page[id] = {"mark": NONE, "why": &"", "turn": 0, "claims": 0, "last": 0}
	return page[id]


func _note(p: PlayerState, id: StringName, mark: int, why: StringName) -> void:
	if p == _viewer:
		return
	var entry := _entry(p, id)
	entry.mark = mark
	entry.why = why
	entry.turn = _engine.turn_count


## A claim is a suspicion and no more, and it never unsays what is known:
## whoever was caught lying and has the same hand is lying again.
func _claimed(p: PlayerState, id: StringName) -> void:
	if p == _viewer:
		return
	var entry := _entry(p, id)
	entry.claims += 1
	entry.last = _engine.turn_count
	if entry.mark == NONE:
		entry.mark = MAYBE
		entry.why = &""


## A card of `p` nobody saw was replaced: what was sure about the hand is
## not any more.
func _hand_changed(p: PlayerState) -> void:
	for entry: Dictionary in _page(_auto, p.id).values():
		if entry.mark == HAS:
			entry.mark = MAYBE
			entry.why = &"stale_has"
		elif entry.mark == NOT:
			entry.mark = NONE
			entry.why = &"stale_not"


# === the pages =================================================================

func _suspects() -> Array:
	return _engine.players.filter(func(p: PlayerState) -> bool: return p.alive and p != _viewer)


## What is written changed: the entries are made again, once, when whatever
## is going on is over (a click on a card must not free the card under it).
func _refresh() -> void:
	if not visible or _queued:
		return
	_queued = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	UI.native(_rebuild_now)


func _rebuild_now() -> void:
	_queued = false
	var suspects := _suspects()
	var left_count := ceili(suspects.size() / 2.0)
	_page_height = HEADER + maxi(left_count, 1) * ENTRY + FOOTER
	_book.size = Vector2(COVER * 2.0 + PAGE_WIDTH * 2.0, TAB_RISE + COVER * 2.0 + _page_height + EDGES)
	_book.position = _on_screen(_book.position)
	var right := COVER + PAGE_WIDTH
	var page_top := TAB_RISE + COVER
	var foot := page_top + _page_height - FOOTER
	_hint.text = TOUCH_HINTS[mode] if UI.touch else HINTS[mode]
	_hint.position = Vector2(COVER + MARGIN, foot)
	_legend.position = Vector2(right + GUTTER, foot + FOOTER - 26.0)
	_wipe.visible = mode == MANUAL
	for page: int in _tabs:
		var tab: Button = _tabs[page]
		var on: bool = page == mode
		# The one the book is open at stands taller, in the colour of its page.
		var drop := 0.0 if on else 6.0
		tab.position = Vector2(right + GUTTER + 4.0 + page * (TAB.x + 4.0), drop)
		tab.size = Vector2(TAB.x, TAB.y - drop)
		for state: String in ["normal", "hover", "pressed", "focus"]:
			var paper := Desk.DIM_PAPER if on else Desk.PAPER_SHADE
			var box := UI.box(paper.lightened(0.08) if state == "hover" and not on else paper, LEATHER_DARK, 2, 0, 4)
			box.border_width_bottom = 0
			box.content_margin_bottom = TAB.y - drop - 20.0
			tab.add_theme_stylebox_override(state, box)
		for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			tab.add_theme_color_override(state, Desk.INK if on else Desk.INK_FADED.darkened(0.3))
		if on:
			tab.add_theme_font_override("font", UI.bold())
		else:
			tab.remove_theme_font_override("font")

	UI.clear(_entries)
	if TipLayer.current != null:
		TipLayer.current.hide_all()
	for i: int in suspects.size():
		var on_left := i < left_count
		var at := Vector2(COVER + MARGIN if on_left else right + GUTTER, page_top + HEADER + (i if on_left else i - left_count) * ENTRY)
		_write_entry(suspects[i], at)
	if suspects.is_empty():
		var nobody := Desk.written("Nobody left to suspect.", 16, Desk.INK_FADED)
		_entries.add_child(nobody)
		nobody.position = Vector2(COVER + MARGIN, page_top + HEADER + 8.0)
	_book.queue_redraw()


## The entry of `p`, with its top left corner at `at`.
func _write_entry(p: PlayerState, at: Vector2) -> void:
	var plate := Desk.written(p.name, 16, Desk.INK, true)
	plate.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	plate.clip_text = true
	_entries.add_child(plate)
	plate.position = at
	plate.size = Vector2(ENTRY_WIDTH, 20)
	var rule := ColorRect.new()
	rule.color = Color(Desk.INK_FADED, 0.55)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.position = at + Vector2(0, 21)
	rule.size = Vector2(ENTRY_WIDTH, PX)
	_entries.add_child(rule)

	# Sure cards go in the slots, as far as there are slots for them.
	var cast: Array = _engine.characters
	var slots: int = clampi(_engine.config.hand_size, 1, 4)
	var sure: Array = []
	var beside: Array = []  # [character id, mark]; the id is &"" for a gap
	for def: CharacterDef in cast:
		var mark := _mark(p, def.id)
		if mark == HAS and sure.size() < slots:
			sure.append(def.id)
			# On the manual page every character keeps its place.
			if mode == MANUAL:
				beside.append([&"", NONE])
		elif mark != NONE or mode == MANUAL:
			beside.append([def.id, mark])
	if mode == AUTO:
		# What they may have first, what they do not have after it.
		beside = beside.filter(func(entry: Array) -> bool: return entry[1] != NOT) \
				+ beside.filter(func(entry: Array) -> bool: return entry[1] == NOT)
	var slot_size := CardView.BASE * SLOT_SCALE
	for i: int in slots:
		var spot := at + Vector2(i * SLOT_STEP, CARDS_AT)
		var frame := Control.new()
		frame.position = spot - Vector2(PX, PX)
		frame.size = slot_size + Vector2(PX, PX) * 2.0
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# A card they no longer hold a place for: the slot is struck out.
		frame.draw.connect(_draw_slot.bind(frame, i >= p.cards.size()))
		_entries.add_child(frame)
		if i < sure.size():
			_put_card(p, sure[i], HAS, spot, SLOT_SCALE, PX)

	var room := ENTRY_WIDTH - slots * SLOT_STEP - 6.0
	var from := at + Vector2(slots * SLOT_STEP + 6.0, CARDS_AT)
	var side_size := CardView.BASE * SIDE_SCALE
	if (beside.size() - 1) * SIDE_STEP + side_size.x <= room:
		for i: int in beside.size():
			if beside[i][0] != &"":
				_put_card(p, beside[i][0], beside[i][1], from + Vector2(i * SIDE_STEP, slot_size.y - side_size.y), SIDE_SCALE, PX)
		return
	var across := ceili(beside.size() / 2.0)
	var step := minf(SMALL_STEP, (room - CardView.BASE.x * SMALL_SCALE) / maxi(across - 1, 1))
	for i: int in beside.size():
		if beside[i][0] != &"":
			var row := 1.0 if i >= across else 0.0
			_put_card(p, beside[i][0], beside[i][1], from + Vector2(floorf((i % across) * step), row * SMALL_ROW), SMALL_SCALE, 1.0)


func _put_card(p: PlayerState, id: StringName, mark: int, at: Vector2, card_scale: float, cell: float) -> void:
	var card := CardView.new(card_scale)
	card.position = at.round()
	card.lift = 2.0
	card.tips = false
	card.set_card(id, true)
	match mark:
		NONE:
			# Not marked yet (the manual page): there, but faint.
			card.modulate = Color(1, 1, 1, 0.5)
	if mode == MANUAL:
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.gui_input.connect(_on_card_input.bind(p, id))
	TipLayer.attach(card, _card_tip.bind(p, Content.character(id)))
	_entries.add_child(card)
	if mark == NONE:
		return
	# The mark, on the top right corner: over the card, not under its tint.
	var badge := _badge(mark, cell)
	var out := 3.0 * cell  # how far past the corner it hangs
	badge.position = card.position + Vector2(card.size.x - badge.size.x + out, -out).round()
	badge.z_index = 6
	_entries.add_child(badge)


## A mark in a round of paper, `cell` pixels to the block.
func _badge(mark: int, cell: float) -> Control:
	var badge := Control.new()
	badge.size = Vector2(9, 9) * cell
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.draw.connect(func() -> void:
		var extent := badge.size
		badge.draw_rect(Rect2(cell, 0, extent.x - cell * 2.0, extent.y), Desk.INK)
		badge.draw_rect(Rect2(0, cell, extent.x, extent.y - cell * 2.0), Desk.INK)
		badge.draw_rect(Rect2(cell, cell, extent.x - cell * 2.0, extent.y - cell * 2.0), Desk.PAPER_LIGHT)
		var rows: Array = GLYPHS[mark]
		for y: int in rows.size():
			var row: String = rows[y]
			for x: int in row.length():
				if row[x] == "#":
					badge.draw_rect(Rect2(Vector2(x + 1, y + 1) * cell, Vector2(cell, cell)), INKS[mark]))
	return badge


## An empty place for a card: a dashed outline in ink.
func _draw_slot(frame: Control, struck: bool) -> void:
	var extent := frame.size
	var ink := Color(Desk.INK_FADED, 0.35 if struck else 0.75)
	frame.draw_rect(Rect2(Vector2.ZERO, extent), Color(Desk.PAPER_SHADE, 0.3))
	for x: int in range(0, int(extent.x), 6):
		frame.draw_rect(Rect2(x, 0, 4, PX), ink)
		frame.draw_rect(Rect2(x, extent.y - PX, 4, PX), ink)
	for y: int in range(0, int(extent.y), 6):
		frame.draw_rect(Rect2(0, y, PX, 4), ink)
		frame.draw_rect(Rect2(extent.x - PX, y, PX, 4), ink)
	if struck:
		var steps := int(extent.x / PX)
		for i: int in steps:
			frame.draw_rect(Rect2(i * PX, floorf(i * extent.y / extent.x), PX, PX * 2.0), ink)


func _mark(p: PlayerState, id: StringName) -> int:
	if mode == MANUAL:
		return _manual.get(p.id, {}).get(id, NONE)
	return _auto.get(p.id, {}).get(id, {}).get("mark", NONE)


func _card_tip(p: PlayerState, def: CharacterDef) -> String:
	var text := "[b][color=%s]%s[/color][/b] [color=%s]· %s[/color]\n" % [UI.hex(UI.GOLD), def.display_name, UI.hex(UI.MUTED), p.name]
	if mode == MANUAL:
		return text + Loc.t(MARK_NAMES[_mark(p, def.id)])
	var entry: Dictionary = _auto.get(p.id, {}).get(def.id, {})
	var lines: Array = []
	if REASONS.has(entry.get("why", &"")):
		lines.append(Loc.t(REASONS[entry.why]) % entry.turn)
	var claims: int = entry.get("claims", 0)
	if claims == 1:
		lines.append(Loc.t("Claimed it once, on turn %d.") % entry.last)
	elif claims > 1:
		lines.append(Loc.t("Claimed it %d times, the last on turn %d.") % [claims, entry.last])
	if lines.is_empty():
		lines.append(Loc.t("Nothing on record."))
	return text + "\n".join(lines)


func _on_card_input(event: InputEvent, p: PlayerState, id: StringName) -> void:
	if mode != MANUAL or not (event is InputEventMouseButton and event.pressed):
		return
	var page := _page(_manual, p.id)
	if event.button_index == MOUSE_BUTTON_LEFT:
		page[id] = (page.get(id, NONE) + 1) % 4
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		page[id] = NONE
	else:
		return
	accept_event()
	marked.emit()
	_refresh()


func _on_wipe_pressed() -> void:
	_manual.clear()
	marked.emit()
	_refresh()


# === the book ==================================================================

## The cover, the two open pages and the ribbon, in blocks.
func _draw_book() -> void:
	var w := _book.size.x
	var top := TAB_RISE
	var bottom := _book.size.y
	var middle := w / 2.0
	_book.draw_rect(Rect2(6, top + 8.0, w, bottom - top), Color(0, 0, 0, 0.35))
	# The cover, with its corners cut and a row of stitches all round.
	_book.draw_rect(Rect2(PX, top, w - PX * 2.0, bottom - top), LEATHER_DARK)
	_book.draw_rect(Rect2(0, top + PX, w, bottom - top - PX * 2.0), LEATHER_DARK)
	_book.draw_rect(Rect2(PX, top + PX, w - PX * 2.0, bottom - top - PX * 2.0), LEATHER)
	_book.draw_rect(Rect2(PX, top + PX, w - PX * 2.0, PX), LEATHER_LIGHT)
	_book.draw_rect(Rect2(PX, top + PX, PX, bottom - top - PX * 2.0), LEATHER_LIGHT)
	for x: int in range(8, int(w) - 8, 8):
		_book.draw_rect(Rect2(x, top + 5.0, 4, 1), Color(STITCH, 0.7))
		_book.draw_rect(Rect2(x, bottom - 4.0, 4, 1), Color(STITCH, 0.7))
	for y: int in range(int(top) + 10, int(bottom) - 8, 8):
		_book.draw_rect(Rect2(4, y, 1, 4), Color(STITCH, 0.7))
		_book.draw_rect(Rect2(w - 5.0, y, 1, 4), Color(STITCH, 0.7))
	_book.draw_rect(Rect2(middle - 8.0, top + PX, 16, bottom - top - PX * 2.0), LEATHER_DARK)

	# The pages under the open ones show their edges at the foot.
	var page_top := top + COVER
	var page_bottom := page_top + _page_height
	for i: int in int(EDGES / PX):
		var inset := COVER + (i + 1) * PX
		_book.draw_rect(Rect2(inset, page_bottom + i * PX, w - inset * 2.0, PX), Desk.PAPER_SHADE if i % 2 == 0 else Desk.PAPER_DARK)
	_book.draw_rect(Rect2(COVER, page_top, w - COVER * 2.0, _page_height), Desk.DIM_PAPER)
	_book.draw_rect(Rect2(COVER, page_top, PX, _page_height), Desk.PAPER_DARK)
	_book.draw_rect(Rect2(w - COVER - PX, page_top, PX, _page_height), Desk.PAPER_DARK)
	_book.draw_rect(Rect2(COVER, page_bottom - PX, w - COVER * 2.0, PX), Desk.PAPER_DARK)
	# They dip into the spine: darker by steps, the last ones dithered.
	for i: int in 7:
		var shade := Color(Desk.INK, 0.05 + 0.045 * (6 - i))
		for side: float in [-1.0, 1.0]:
			var x := middle + side * (i * PX * 2.0) - (PX * 2.0 if side < 0.0 else 0.0)
			if i < 5:
				_book.draw_rect(Rect2(x, page_top, PX * 2.0, _page_height), shade)
			else:
				for y: int in range(0, int(_page_height), 4):
					_book.draw_rect(Rect2(x + (PX if (y + i * 4) % 8 == 0 else 0.0), page_top + y, PX, PX), shade)
	_book.draw_rect(Rect2(middle - 1.0, page_top, PX, _page_height), Color(Desk.INK, 0.6))
	# The rule under the title of each page.
	for x: float in [COVER + MARGIN, middle + GUTTER]:
		_book.draw_rect(Rect2(x, page_top + HEADER - 6.0, ENTRY_WIDTH, PX), Color(Desk.INK, 0.7))
		_book.draw_rect(Rect2(x, page_top + HEADER - 2.0, ENTRY_WIDTH, 1), Color(Desk.INK, 0.4))
	# The ribbon runs down the spine and hangs out of the foot, forked.
	var ribbon := middle + 2.0
	_book.draw_rect(Rect2(ribbon, page_top, 6, bottom - page_top + 14.0), RIBBON)
	_book.draw_rect(Rect2(ribbon, page_top, PX, bottom - page_top + 14.0), RIBBON.lightened(0.18))
	_book.draw_rect(Rect2(ribbon, bottom + 14.0, PX, 4), RIBBON)
	_book.draw_rect(Rect2(ribbon + 4.0, bottom + 14.0, PX, 4), RIBBON)


## The book is dragged by any part of it that is not a button or a card.
func _on_book_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		_book.position = _on_screen(_book.position + event.relative * _book.scale)


## A book taller than the screen (touch mode, a full table) can be dragged
## up to show its foot.
func _on_screen(at: Vector2) -> Vector2:
	var room := size - _extent()
	return at.clamp(room.min(Vector2.ZERO), room.max(Vector2.ZERO)).round()


## The size of the book on screen.
func _extent() -> Vector2:
	return _book.size * _book.scale
