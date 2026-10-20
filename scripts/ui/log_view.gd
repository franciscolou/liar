extends ScrollContainer
## The table's log, told in pictures: one row per event, made of who did it
## (their name in the ink of their seat), small drawings for what happened (a
## mini card for a claim, the item, a coin and the amount, a broken heart, a
## "LIAR!" balloon, a tick or a cross, a skull...) and a golden chevron from
## whoever acted to whoever it was aimed at. The sentence that says all of it
## is the row's tooltip: the mouse over a row (a finger held on it) reads it.
##
## The glyphs are text bitmaps drawn in blocks of CELL, like the emotes, with
## their inks in INKS. The table hands each event over with its sentence
## (add_event); lines that are no event (the room, a hint) come in as text
## (add_line). No class name: preload it.

const CELL := 2.0
const ROW := 20.0
const NAME_CHARS := 7
## How many rows are kept: the oldest go first.
const KEPT := 260
## The ink of each seat's name, by player id.
const SEAT_INKS := [Color("e6bc4c"), Color("6cc3e0"), Color("ef7a64"), Color("8cc858"),
		Color("c99ae8"), Color("f0a858"), Color("72d6b8"), Color("ec8cb6")]
const GOOD := Color("8cd06a")
const BAD := Color("ef5a48")
const COIN := "res://assets/ui/coin.png"
const HEART := "res://assets/ui/heart.png"
const GUN := "res://assets/ui/clown_gun.png"

## One character per cell; "." is nothing. Inks below.
const GLYPHS := {
	&"chevron": ["o#o....", ".o##o..", "..o##o.", "...o##o", "..o##o.", ".o##o..", "o#o...."],
	&"hourglass": ["ooooooo", "o+###-o", ".o#-o..", "..o#o..", ".o+.-o.", "o+###-o", "ooooooo"],
	&"bag": ["..o-o..", "...o...", ".o###o.", "o##+##o", "o#+$##o", "o#####o", ".ooooo."],
	&"spark": ["...#...", "...#...", ".#.+.#.", "###+###", ".#.+.#.", "...#...", "...#..."],
	&"hand": [".o.o.o.", "o#o#o#o", "o#o#o#o", "o####oo", "o#####o", ".o###o.", "..ooo.."],
	&"trash": ["..ooo..", "ooooooo", "o#####o", ".o#-#o.", ".o#-#o.", ".o#-#o.", ".ooooo."],
	&"palette": [".ooooo.", "o#b#p#o", "o####oo", "o#y#o..", "o####oo", ".o####o", "..oooo."],
	&"crack": ["o..o...", ".o..o..", "..oo.o.", "...o..o", "..o.o..", ".o...o.", "o.....o"],
	&"ban": ["..ooo..", ".o...o.", "o..o..o", "o.o.o.o", "o..o..o", ".o...o.", "..ooo.."],
	&"liar": ["ooooooooo", "o#######o", "o#!#!#!#o", "o#######o", "oo##ooooo", ".o#o.....", ".oo......"],
	&"check": ["......o", ".....o#", "o...o#o", "#o.o#o.", "o#o#o..", ".o#o...", "..o...."],
	&"cross": ["o.....o", ".o...o.", "..o.o..", "...o...", "..o.o..", ".o...o.", "o.....o"],
	&"broken": [".oo.oo.", "o##o##o", "o#o##-o", "o##o#-o", ".o#o-o.", "..o#o..", "...o..."],
	&"skull": [".ooooo.", "o#####o", "o.#.#.o", "o#####o", ".o#.#o.", ".o###o.", "..ooo.."],
	&"card": ["ooooo..", "o-+-o..", "o+-+ooo", "o-+-o-o", "oooooo+", "..o-+-o", "..ooooo"],
	&"renew": ["..ooo..", ".o...o.", "o.....o", "o...o.o", "o..ooo.", ".o.....", "..ooo.."],
	&"bell": ["...o...", "..o#o..", ".o###o.", ".o###o.", "o#####o", "ooooooo", "...o..."],
	&"swap": ["..o....", ".oo####", "ooo....", ".......", "....ooo", "####oo.", "....o.."],
	&"eye": [".......", "..ooo..", ".o###o.", "o#o.o#o", ".o###o.", "..ooo..", "......."],
	&"puff": ["..oo...", ".o##o..", "o####oo", "o#####o", ".o####o", "..oooo.", "......."],
	&"info": ["..ooo..", ".o#+#o.", ".o#o#o.", ".o#+#o.", ".o#+#o.", ".o#+#o.", "..ooo.."],
	&"crown": ["#..#..#", "##.#.##", "#######", "#+#+#+#", "#######", "-------", "......."],
	&"deck": ["ooooo..", "o-+-o..", "o+-+o..", "o-+-o..", "ooooo..", "..o....", ".ooo..."],
	&"brush": [".....oo", "....o#o", "...o#o.", "..o#o..", ".ooo...", "opo....", "pp....."],
	&"dice": ["ooooooo", "o#...#o", "o..#..o", "o#...#o", "ooooooo", "......."],
	&"gavel": ["ooo....", "o#oo...", "oo#oo..", ".oo#o..", "...o#o.", "....o#o", ".....oo"],
	&"ha": ["#.#.###", "#.#.#.#", "###.###", "#.#.#.#", "#.#.#.#", ".......", "......."],
	&"down": ["..o#o..", "..o#o..", "..o#o..", "o.o#o.o", ".o###o.", "..o#o..", "...o..."],
}
const INKS := {
	&"chevron": {"o": Color("6e4a14"), "#": Color("f2c84b")},
	&"hourglass": {"o": Color("6e4a14"), "#": Color("e8d7a8"), "+": Color("fff3c4"), "-": Color("b89a6a")},
	&"bag": {"o": Color("3a2410"), "#": Color("a8743c"), "+": Color("cf9e60"), "-": Color("6e4222"), "$": Color("f2c84b")},
	&"spark": {"#": Color("6cc3e0"), "+": Color("ffffff")},
	&"hand": {"o": Color("3a2410"), "#": Color("e6b08a")},
	&"trash": {"o": Color("2a2a30"), "#": Color("8a8a94"), "-": Color("5a5a64")},
	&"palette": {"o": Color("3a2410"), "#": Color("b07a44"), "b": Color("4f8fe0"), "p": Color("e877b8"), "y": Color("f2cf3c")},
	&"crack": {"o": Color("ef5a48")},
	&"ban": {"o": Color("6cc3e0")},
	&"liar": {"o": Color("5c1210"), "#": Color("ef5a48"), "!": Color("fff0e0")},
	&"check": {"o": Color("2e5a1c"), "#": Color("8cd06a")},
	&"cross": {"o": Color("ef5a48")},
	&"broken": {"o": Color("4a0c0c"), "#": Color("e0443a"), "-": Color("9a1e1e")},
	&"skull": {"o": Color("2a2420"), "#": Color("ece2cc")},
	&"card": {"o": Color("3a2410"), "-": Color("8a5a24"), "+": Color("e6bc4c")},
	&"renew": {"o": Color("8cd06a")},
	&"bell": {"o": Color("5a3a10"), "#": Color("e6bc4c")},
	&"swap": {"o": Color("c99ae8"), "#": Color("c99ae8")},
	&"eye": {"o": Color("2a2440"), "#": Color("c9d2e0")},
	&"puff": {"o": Color("4a4458"), "#": Color("9a94a8")},
	&"info": {"o": Color("1c3a4a"), "#": Color("6cc3e0"), "+": Color("ffffff")},
	&"crown": {"#": Color("f2c84b"), "+": Color("ef5a48"), "-": Color("8a6a1a")},
	&"deck": {"o": Color("3a2410"), "-": Color("8a5a24"), "+": Color("e6bc4c")},
	&"brush": {"o": Color("6a2e1c"), "#": Color("94482a"), "p": Color("e877b8")},
	&"dice": {"o": Color("e8e0d0"), "#": Color("2a2020")},
	&"gavel": {"o": Color("3a2410"), "#": Color("a8743c")},
	&"ha": {"#": Color("f2cf3c")},
	&"down": {"o": Color("3a2410"), "#": Color("e6bc4c")},
}

var engine: GameEngine
var viewer: PlayerState
var _list: VBoxContainer


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	follow_focus = false
	# A finger drags it up and down (see TouchMode).
	add_to_group(&"touch_scroll")
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 1)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_list)


## Writes `e` down in pictures; `line` is the sentence for its tooltip.
func add_event(e: GameEvent, line: String) -> void:
	var row := _row(line)
	var built := _build(e, row)
	if not built:
		row.add_child(_fill(_text(line, UI.CREAM)))
	_append(row, e.type == &"turn_started")


## A line that is no event: the room, a hint for the viewer.
func add_line(line: String, color: Color) -> void:
	var row := _row(line)
	row.add_child(_glyph(&"info"))
	row.add_child(_fill(_text(line, color)))
	_append(row, false)


func _append(row: Control, header: bool) -> void:
	if header:
		row.set_meta(&"header", true)
	var follow := scroll_vertical >= int(get_v_scroll_bar().max_value - size.y) - 4
	_list.add_child(row)
	while _list.get_child_count() > KEPT:
		var old := _list.get_child(0)
		_list.remove_child(old)
		old.queue_free()
	if follow:
		_to_bottom.call_deferred()


func _to_bottom() -> void:
	await get_tree().process_frame
	scroll_vertical = int(get_v_scroll_bar().max_value)


# --- what each event looks like --------------------------------------------------

## Fills `row` for `e`. False when there is no picture for it: the row then
## just carries the sentence.
func _build(e: GameEvent, row: Row) -> bool:
	var d := e.data
	match e.type:
		&"turn_started":
			row.header = true
			row.add_child(_glyph(&"hourglass"))
			row.add_child(_text(Loc.t("TURN %d") % engine.turn_count if engine != null else "", UI.MUTED))
			row.add_child(_who(d.player))
		&"coins":
			_coins(d, row)
		&"item_bought", &"service_bought":
			row.add_child(_who(d.player))
			row.add_child(_glyph(&"bag"))
			row.add_child(_item(d.item.def, d.item.hidden and d.player != viewer))
		&"shop_rerolled":
			row.add_child(_who(d.player))
			row.add_child(_glyph(&"bag"))
			row.add_child(_glyph(&"dice"))
		&"item_gained":
			row.add_child(_who(d.player))
			row.add_child(_glyph(&"spark"))
			row.add_child(_item(d.item.def, d.item.hidden and d.player != viewer))
		&"item_used":
			row.add_child(_who(d.player))
			row.add_child(_item(d.item.def))
			_aim(row, d.play)
		&"item_stolen":
			row.add_child(_who(d.thief))
			row.add_child(_glyph(&"hand"))
			row.add_child(_item(d.item.def, d.item.hidden and viewer != d.thief and viewer != d.victim))
			row.add_child(_chevron(true))
			row.add_child(_who(d.victim))
		&"item_missed":
			row.add_child(_who(d.thief))
			row.add_child(_glyph(&"hand"))
			row.add_child(_glyph(&"cross"))
			row.add_child(_who(d.victim))
		&"item_discarded":
			row.add_child(_who(d.player))
			row.add_child(_item(d.item.def, d.item.hidden and d.player != viewer))
			row.add_child(_glyph(&"trash"))
		&"item_sold":
			row.add_child(_who(d.player))
			row.add_child(_item(d.item.def))
			row.add_child(_glyph(&"palette"))
			row.add_child(_amount(d.amount, true))
		&"item_broken":
			row.add_child(_who(d.player))
			row.add_child(_item(d.item.def))
			row.add_child(_glyph(&"crack"))
		&"claim_declared":
			var play: Play = d.play
			row.add_child(_who(play.actor))
			row.add_child(_card(play.ability().character_id))
			row.add_child(_fill(_text(EventText.title(play), UI.BLUE.lightened(0.3), true)))
			_aim(row, play)
		&"claim_cancelled":
			row.add_child(_glyph(&"ban"))
			row.add_child(_card(d.play.ability().character_id) if d.play.is_claim() else _item(d.play.source))
			row.add_child(_who(d.play.actor))
		&"doubt_declared":
			row.add_child(_who(d.doubter))
			row.add_child(_glyph(&"liar"))
			row.add_child(_chevron(true))
			row.add_child(_who(d.play.actor))
		&"doubt_revealed":
			row.add_child(_who(d.play.actor))
			row.add_child(_card(d.play.ability().character_id))
			row.add_child(_glyph(&"check" if d.truthful else &"cross"))
			row.add_child(_text(Loc.t("TRUTH") if d.truthful else Loc.t("LIE"), GOOD if d.truthful else BAD, true))
		&"targeted":
			if not d.get("blocked", false) and not d.get("reflected", false):
				return false
			row.add_child(_who(d.target))
			var guard: Variant = d.get("guard")
			if guard is ItemInstance:
				row.add_child(_item(guard.def))
			row.add_child(_glyph(&"ban" if d.get("blocked", false) else &"renew"))
		&"morale_lost":
			row.add_child(_who(d.target))
			row.add_child(_glyph(&"broken"))
			row.add_child(_amount(-d.amount, false))
			if d.get("source") != null and d.source != d.target:
				row.add_child(_text("←", UI.MUTED))
				row.add_child(_who(d.source))
		&"morale_spent":
			row.add_child(_who(d.player))
			row.add_child(_icon(HEART))
			row.add_child(_amount(-d.amount, false))
			row.add_child(_glyph(&"spark"))
		&"morale_gained":
			row.add_child(_who(d.player))
			row.add_child(_icon(HEART))
			row.add_child(_amount(d.amount, true))
		&"player_eliminated":
			row.add_child(_glyph(&"skull"))
			row.add_child(_who(d.player))
			row.add_child(_text(Loc.t("OUT"), BAD, true))
		&"player_kicked":
			row.add_child(_glyph(&"cross"))
			row.add_child(_who(d.player))
		&"cards_changed":
			row.add_child(_who(d.player))
			if d.get("reason") == &"proven" and d.get("old") != null:
				row.add_child(_card(d.old))
			row.add_child(_glyph(&"card"))
			row.add_child(_glyph(&"renew"))
		&"card_lost":
			row.add_child(_who(d.player))
			row.add_child(_card(d.card))
			row.add_child(_glyph(&"down"))
			row.add_child(_glyph(&"deck"))
		&"card_drawn":
			row.add_child(_who(d.player))
			row.add_child(_glyph(&"deck"))
			row.add_child(_glyph(&"card"))
			row.add_child(_amount(1, true, false))
		&"cards_recalled":
			row.add_child(_who(d.player))
			row.add_child(_glyph(&"bell"))
			row.add_child(_card(d.card))
			row.add_child(_text("×%d" % d.hands.size(), UI.CREAM, true))
		&"hand_redrawn":
			row.add_child(_who(d.player))
			row.add_child(_glyph(&"card"))
			row.add_child(_text("×%d" % d.count, UI.CREAM, true))
			row.add_child(_glyph(&"renew"))
		&"gun_fired":
			row.add_child(_who(d.shooter))
			row.add_child(_icon(GUN, Vector2(22, 14)))
			row.add_child(_text(Loc.t("LOADED") if d.loaded else Loc.t("EMPTY"), BAD if d.loaded else GOOD, true))
			row.add_child(_chevron(d.loaded))
			row.add_child(_who(d.target))
			if d.ducked:
				row.add_child(_glyph(&"down"))
		&"coin_flipped":
			row.add_child(_who(d.player))
			row.add_child(_icon(COIN))
			row.add_child(_text(Loc.t("HEADS") if d.heads else Loc.t("TAILS"), UI.CREAM, true))
			row.add_child(_glyph(&"check" if d.won else &"cross"))
		&"note":
			var look := &"info"
			match d.get("tag", &""):
				&"paint_toll":
					look = &"brush"
				&"side_bet":
					look = &"check" if d.good else &"cross"
			row.add_child(_glyph(look))
			row.add_child(_fill(_text(Loc.t(d.text) % d.player.name, GOOD if d.good else UI.MUTED)))
		&"cards_swapped":
			row.add_child(_who(d.a))
			row.add_child(_glyph(&"swap"))
			row.add_child(_who(d.b))
		&"card_peeked":
			row.add_child(_who(d.viewer))
			row.add_child(_glyph(&"eye"))
			row.add_child(_chevron(false))
			row.add_child(_who(d.owner))
		&"hand_missed", &"items_missed":
			row.add_child(_who(d.owner))
			row.add_child(_glyph(&"puff"))
			row.add_child(_glyph(&"card" if e.type == &"hand_missed" else &"bag"))
		&"status_added", &"status_removed":
			row.add_child(_who(d.player))
			var was: Dictionary = d.get("was", {})
			var tint: Variant = was.get("tint")
			var color: Color = tint if tint is Color else UI.status_color(d.player, d.status)
			row.add_child(_pill(Loc.t(Content.statuses.get(d.status, {}).get("name", String(d.status))), color, e.type == &"status_removed"))
		&"counter_changed":
			row.add_child(_who(d.player))
			var def: Dictionary = Content.counters.get(d.counter, {})
			row.add_child(_text(Loc.t(def.get("name", String(d.counter))), UI.BLUE, true))
			row.add_child(_text(str(d.value), UI.CREAM, true))
		&"game_over":
			row.add_child(_glyph(&"crown"))
			if d.winner != null:
				row.add_child(_who(d.winner))
		_:
			return false
	return true


func _coins(d: Dictionary, row: Row) -> void:
	var gain: bool = d.delta > 0
	row.add_child(_who(d.player))
	row.add_child(_icon(COIN))
	row.add_child(_amount(d.delta, gain))
	match d.reason:
		&"income":
			row.add_child(_glyph(&"hourglass"))
		&"doubt":
			row.add_child(_glyph(&"liar"))
			row.add_child(_glyph(&"cross"))
		&"doubt_reward":
			row.add_child(_glyph(&"liar"))
			row.add_child(_glyph(&"check"))
		&"refund", &"blank":
			row.add_child(_glyph(&"renew"))
		&"stolen", &"hexed":
			row.add_child(_glyph(&"hand"))
			if d.other != null:
				row.add_child(_text("→", UI.MUTED))
				row.add_child(_who(d.other))
		&"swindle":
			row.add_child(_glyph(&"hand"))
			if d.other != null:
				row.add_child(_text("←", UI.MUTED))
				row.add_child(_who(d.other))
		&"laughter":
			row.add_child(_glyph(&"ha"))
		&"oath":
			row.add_child(_glyph(&"gavel"))
		&"shop":
			row.add_child(_glyph(&"bag"))
		&"cost":
			if d.get("play") != null and d.play.is_claim():
				row.add_child(_card(d.play.ability().character_id))
		&"sold":
			row.add_child(_glyph(&"palette"))
		&"paint", &"paint_toll":
			row.add_child(_glyph(&"brush"))


## The chevron and whoever `play` was aimed at, if anyone.
func _aim(row: Row, play: Play) -> void:
	if play == null:
		return
	var whom := play.aimed().whom()
	if whom == null or whom == play.actor:
		return
	var source := play.aimed().source
	row.add_child(_chevron(source.tags.has(&"damage") or source.tags.has(&"steal")))
	row.add_child(_who(whom))


# --- the pieces of a row --------------------------------------------------------

func _row(line: String) -> Row:
	var row := Row.new()
	row.custom_minimum_size = Vector2(0, ROW * (UI.TOUCH_TEXT if UI.touch else 1.0))
	if line != "":
		TipLayer.attach(row, line)
	return row


func _who(p: PlayerState) -> Label:
	if p == null:
		return _text("?", UI.MUTED)
	var name := p.name if p.name.length() <= NAME_CHARS else p.name.left(NAME_CHARS - 1) + "…"
	var ink: Color = SEAT_INKS[p.id % SEAT_INKS.size()]
	var l := _text(name, ink, true)
	return l


func _text(text: String, color: Color, bold := false) -> Label:
	var l := UI.label(text, 12, color, bold)
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


## A label that takes whatever room the row has left, cut short with an
## ellipsis where it does not fit (the tooltip has it all).
func _fill(l: Label) -> Label:
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _amount(delta: int, good: bool, signed := true) -> Label:
	return _text(("%+d" % delta) if signed else ("+%d" % delta), GOOD if good else BAD, true)


func _icon(path: String, at := Vector2(14, 14)) -> TextureRect:
	var t := TextureRect.new()
	t.texture = UI.tex(path)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.custom_minimum_size = at
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _item(def: ItemDef, hidden := false) -> TextureRect:
	return _icon(UI.ITEM_BACK if hidden or def == null else def.texture_path, Vector2(17, 18))


## A small picture of the character's card: its art, framed in gold.
func _card(character_id: StringName) -> Control:
	var def := Content.character(character_id)
	var holder := PanelContainer.new()
	holder.add_theme_stylebox_override("panel", UI.box(UI.INK, UI.GOLD.darkened(0.2), 1, 1, 0))
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art := TextureRect.new()
	art.texture = UI.card_art(def.texture_path) if def != null else null
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	art.custom_minimum_size = Vector2(10, 17)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(art)
	return holder


func _pill(text: String, color: Color, ended: bool) -> PanelContainer:
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", UI.box(color.darkened(0.55), color, 1, 3, 3))
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _text(text.to_upper(), color.lightened(0.3) if not ended else UI.MUTED, true)
	l.add_theme_font_size_override("font_size", UI.px(10))
	pill.add_child(l)
	if ended:
		pill.modulate.a = 0.65
		pill.draw.connect(func() -> void:
			pill.draw_line(Vector2(2, pill.size.y / 2.0), Vector2(pill.size.x - 2, pill.size.y / 2.0), UI.CREAM, 1.0))
	return pill


func _glyph(id: StringName) -> Glyph:
	var g := Glyph.new()
	g.rows = GLYPHS.get(id, GLYPHS[&"info"])
	g.inks = INKS.get(id, INKS[&"info"])
	return g


## The chevron of a play, small: red-cored when it hurts or takes.
func _chevron(hostile: bool) -> Glyph:
	var g := _glyph(&"chevron")
	if hostile:
		g.inks = {"o": Color("6e1a14"), "#": Color("f2c84b").lerp(BAD, 0.45)}
	return g


## A row of the log: lights up under the mouse; a turn's first row is a
## header with a rule above it.
class Row extends HBoxContainer:
	var header := false
	var _hot := false

	func _init() -> void:
		add_theme_constant_override("separation", 3)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_entered.connect(func() -> void:
			_hot = true
			queue_redraw())
		mouse_exited.connect(func() -> void:
			_hot = false
			queue_redraw())

	func _draw() -> void:
		if header:
			draw_rect(Rect2(0, 0, size.x, 1), Color(UI.GOLD, 0.45))
			draw_rect(Rect2(0, 1, size.x, size.y - 1), Color(UI.GOLD, 0.07))
		if _hot:
			draw_rect(Rect2(Vector2.ZERO, size), Color(UI.CREAM, 0.1))


## A text bitmap drawn in blocks of CELL.
class Glyph extends Control:
	var rows: Array = []
	var inks: Dictionary = {}

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _ready() -> void:
		var cell := CELL * (1.5 if UI.touch else 1.0)
		var width := 0
		for row: String in rows:
			width = maxi(width, row.length())
		custom_minimum_size = Vector2(width, rows.size()) * cell

	func _draw() -> void:
		var cell := custom_minimum_size.y / maxf(rows.size(), 1.0)
		for y: int in rows.size():
			var row: String = rows[y]
			for x: int in row.length():
				if inks.has(row[x]):
					draw_rect(Rect2(Vector2(x, y) * cell, Vector2(cell, cell)), inks[row[x]])
