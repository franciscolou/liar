extends Control
## The ranked section: the house's own tables (see ranked_api.gd and the API
## in server/). Reached from the house's card on the room screen.
##
## The same desk as the room screen, with the house's things on it
## (house_props.gd): at the left the member's card, and the pocket watch with
## the slip of the queue beside it (or, for someone who is not a member, the
## membership form); at the right the ledger of the standings; under them
## the house's newspaper, folded, which opens the figures (ranked_stats.gd).
##
## Queueing is asking the house now and then whether a table is ready
## (`_poll`). Once it is, this machine joins the table's room with the ticket
## of its seat (Room.join_ranked) and waits here for the others to sit down;
## the room opens the table by itself when the cards are dealt.

const Desk := preload("res://scripts/ui/noir_desk.gd")
const House := preload("res://scripts/ui/house_props.gd")
const RankedApi := preload("res://scripts/net/ranked_api.gd")
const Room := preload("res://scripts/net/room.gd")
const Jukebox := preload("res://scripts/ui/jukebox.gd")
const Transition := preload("res://scripts/ui/transition.gd")
const ROOM_SCENE := "res://scenes/room.tscn"
const STATS_SCENE := "res://scenes/ranked_stats.tscn"
## How often the queue is asked about while waiting in it.
const POLL := 2.0
## The ledger: members on each page, and the height of a row (desktop, touch).
const PER_PAGE := 15
const TOUCH_PER_PAGE := 9
const ROW := 30.0
const TOUCH_ROW := 45.0
const ROWS_FROM := 66.0
## The columns of a page of the ledger, from its left: the rank, the name,
## the rating, wins of matches, the last places.
const COLUMNS: Array[float] = [36.0, 160.0, 214.0, 264.0]
const TOUCH_COLUMNS: Array[float] = [40.0, 172.0, 248.0, 0.0]

## Set before coming here to join the queue at once ("play again").
static var queue_on_open := false
## Which spread of the ledger is open.
static var _spread := 0

var _desk: Desk
var _things: Array = []
var _card: Control
var _card_box: Control
var _watch: Control
var _slip: Desk
var _queue_text: Label
var _queue_button: Button
var _queue_note: Label
var _form: Desk
var _ledger: Control
var _pages: Array = []  # the two Controls written on the pages
var _ledger_turn: Button
var _me: Dictionary = {}
var _standings: Array = []
## idle, waiting, matched (a table for us), seated (in its room), closed (no house).
var _state := &"idle"
var _since := 0.0
var _poll_left := 0.0
var _busy := false
var _touch := false


func _ready() -> void:
	Settings.ensure_loaded()
	theme = UI.theme()
	Jukebox.play(Jukebox.LOBBY)
	_touch = UI.touch
	_desk = Desk.desk()
	_desk.props = [
		{"kind": &"ring", "at": Vector2(366, 36)},
		{"kind": &"ashtray", "at": Vector2(318, 612), "turn": 0.5},
	]
	add_child(_desk)
	add_child(TipLayer.new())

	var plaque: Desk = Desk.make(Desk.Kind.PLAQUE, Rect2(20, 12, 300, 58) if _touch else Rect2(20, 12, 300, 46))
	add_child(plaque)
	var title := Desk.written("RANKED", 30, UI.INK, true)
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plaque.add_child(title)

	_lay_ledger()
	_lay_gazette()
	_lay_member()
	_lay_queue()
	_lay_form()

	var back := UI.button("BACK", UI.BORDER, 20)
	back.size = UI.grown(Vector2(150, 46))
	back.position = Vector2(24, 632 - back.size.y)
	Desk.brass(back)
	back.pressed.connect(_on_back)
	add_child(back)
	var settings := UI.button("SETTINGS", UI.BORDER, 20)
	settings.size = UI.grown(Vector2(170, 46))
	settings.position = Vector2(1128 - settings.size.x, 12)
	Desk.brass(settings)
	settings.pressed.connect(func(): add_child(SettingsPanel.new()))
	add_child(settings)
	_things = Desk.things(self, _desk)
	add_child(Desk.lamplight())
	if Transition.desk_bare():
		desk_slide(1.0)

	_show_member()
	_open_house()


## The way in and out (Transition.DESK), as on the room screen.
func desk_slide(amount: float) -> void:
	Desk.slide(_desk, _things, amount)


# --- what lies on the desk -------------------------------------------------------

func _lay_member() -> void:
	_card = House.of(House.Look.MEMBER, Rect2(26, 76, 362, 178))
	_card.rotation = -0.012
	_card.medal_at = Vector2(66, 90)
	add_child(_card)
	var box := VBoxContainer.new()
	box.position = Vector2(118, 22)
	box.size = Vector2(_card.size.x - 140.0, _card.size.y - 40.0)
	box.add_theme_constant_override("separation", 0)
	_card.add_child(box)
	_card_box = box


func _lay_queue() -> void:
	_slip = Desk.make(Desk.Kind.SHEET, Rect2(188, 268, 204, 170))
	_slip.tone = Desk.TELEGRAM
	_slip.bordered = true
	_slip.rotation = 0.018
	add_child(_slip)
	var box := VBoxContainer.new()
	box.position = Vector2(48, 16)
	box.size = Vector2(_slip.size.x - 64.0, _slip.size.y - 30.0)
	box.add_theme_constant_override("separation", 4)
	_slip.add_child(box)
	box.add_child(Desk.written("THE QUEUE", 18, Desk.INK, true))
	_queue_text = Desk.written("", 13)
	_queue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_queue_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_queue_text)
	_queue_button = UI.button("FIND A MATCH", UI.BORDER, 15)
	_queue_button.custom_minimum_size = Vector2(0, 48 if _touch else 40)
	if _touch:
		_queue_button.add_theme_font_size_override("font_size", UI.px(12))
	Desk.stamp(_queue_button)
	_queue_button.pressed.connect(_on_queue_pressed)
	box.add_child(_queue_button)
	_queue_note = Desk.written("", 12, Desk.INK_RED)
	_queue_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_queue_note.hide()
	# The note goes over the desk under the slip: the slip has no room left.
	_queue_note.position = Vector2(24, _slip.size.y + 4.0)
	_queue_note.size = Vector2(_slip.size.x - 20.0, 30)
	Desk.ink(_queue_note, UI.RED)
	_queue_note.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_slip.add_child(_queue_note)
	# The watch lies over the edge of the slip, its chain running off left.
	_watch = House.of(House.Look.WATCH, Rect2(8, 262, 224, 190))
	add_child(_watch)


func _lay_form() -> void:
	_form = Desk.make(Desk.Kind.SHEET, Rect2(26, 74, 364, 364))
	_form.aged = true
	_form.tone = Desk.OLD_PAPER
	_form.rotation = -0.015
	_form.inked = [Vector3(330, 40, 3), Vector3(24, 300, 2), Vector3(200, 340, -70)]
	add_child(_form)


func _lay_ledger() -> void:
	_ledger = House.of(House.Look.LEDGER, Rect2(406, 68, 722, 556))
	_ledger.row = TOUCH_ROW if _touch else ROW
	_ledger.rows_from = ROWS_FROM
	var columns: Array[float] = []
	for x: float in (TOUCH_COLUMNS if _touch else COLUMNS):
		if x > 0.0:
			columns.append(x)
	_ledger.columns = columns
	add_child(_ledger)
	for index in 2:
		var page: Rect2 = _ledger.page(index)
		var sheet := Control.new()
		sheet.position = page.position
		sheet.size = page.size
		sheet.mouse_filter = Control.MOUSE_FILTER_PASS
		_ledger.add_child(sheet)
		_pages.append(sheet)
	_ledger_turn = UI.button("", UI.BORDER, 16)
	Desk.penned(_ledger_turn)
	_ledger_turn.size = UI.grown(Vector2(110, 30))
	var right: Rect2 = _ledger.page(1)
	_ledger_turn.position = Vector2(right.end.x - _ledger_turn.size.x - 6.0, right.end.y - _ledger_turn.size.y - 6.0)
	_ledger_turn.pressed.connect(func() -> void:
		_spread = (_spread + 1) % _spreads()
		_write_ledger())
	_ledger_turn.hide()
	_ledger.add_child(_ledger_turn)


func _lay_gazette() -> void:
	var paper: Control = House.of(House.Look.GAZETTE, Rect2(34, 450, 348, 128))
	paper.rotation = -0.025
	paper.lifts = true
	add_child(paper)
	var mast := UI.label("THE HOUSE GAZETTE", 20, House.NEWS_INK, true)
	Desk.ink(mast, House.NEWS_INK)
	mast.position = Vector2(12, 18)
	mast.size = Vector2(paper.size.x - 24.0, 26)
	mast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	paper.add_child(mast)
	var headline := Desk.written("WHO LIES BEST?", 14, House.NEWS_INK, true)
	headline.position = Vector2(96, 66)
	headline.size = Vector2(paper.size.x - 110.0, 20)
	paper.add_child(headline)
	# The whole paper is the button.
	var open := Button.new()
	open.flat = true
	open.set_anchors_preset(Control.PRESET_FULL_RECT)
	open.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		open.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	open.pressed.connect(_on_gazette)
	paper.add_child(open)
	TipLayer.attach(open, "The house's figures: who bluffs, who gets caught, what wins. And your own file." if not _touch
			else "The house's figures, and your own file.")


# --- the member ----------------------------------------------------------------

## The card of a member, the form of someone who is not one, or the notice
## of a house that is not there.
func _show_member() -> void:
	var member := RankedApi.signed_in() and RankedApi.configured()
	_card.visible = member
	_slip.visible = member
	_watch.visible = member
	_form.visible = not member
	UI.clear(_form)
	if not RankedApi.configured():
		_state = &"closed"
		var box := _write_on(_form, "THE HOUSE IS CLOSED")
		box.add_child(_text("Ranked matches are played on the house's own server, and it has not opened its doors yet.\n\nRooms among friends are played as always, from the room screen."))
		return
	if not member:
		_write_form()
		return
	_write_card()


func _write_card() -> void:
	UI.clear(_card_box)
	var rating: int = int(_me.get("rating", 1000))
	var matches: int = int(_me.get("matches", 0))
	var index := House.tier_of(rating, matches)
	_card.tier = index
	var head := UI.label("MEMBER OF THE HOUSE", 11, House.FOIL)
	_card_box.add_child(head)
	var who := UI.label(str(_me.get("name", Settings.ranked_name)), 28, House.FOIL_LIGHT, true)
	who.clip_text = true
	# A name, not a text to translate.
	who.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_card_box.add_child(who)
	_card_box.add_child(UI.label(Loc.t(House.tier_name(index)), 15, House.FOIL))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	_card_box.add_child(gap)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	# Digits are never bold: the font closes their holes (6, 8 and 9 alike).
	var number := UI.label(str(rating) if matches > 0 else "—", 32, UI.CREAM)
	line.add_child(number)
	var said := Loc.t("rating, #%d") % int(_me.rank) if _me.get("rank") != null else Loc.t("rating, unplaced")
	if _touch:
		said = "#%d" % int(_me.rank) if _me.get("rank") != null else ""
	var what := UI.label(said, 13, House.FOIL)
	what.size_flags_vertical = Control.SIZE_SHRINK_END
	line.add_child(what)
	_card_box.add_child(line)
	if not _touch:
		var record := UI.label(Loc.t("%d wins in %d matches") % [int(_me.get("wins", 0)), matches] if matches > 0 else Loc.t("No match played yet."), 13, UI.CREAM)
		_card_box.add_child(record)
	# Out of the house: a word in foil, small, at the corner.
	var out := UI.button("SIGN OUT", UI.BORDER, 11)
	out.flat = true
	out.add_theme_color_override("font_color", Color(House.FOIL, 0.7))
	out.add_theme_color_override("font_hover_color", House.FOIL_LIGHT)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		out.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	out.size = UI.grown(Vector2(80, 20))
	out.position = Vector2(_card.size.x - out.size.x - 40.0, 18.0)
	out.pressed.connect(_on_sign_out)
	_card.add_child(out)
	_card.set_meta(&"out", out)


func _write_form() -> void:
	var box := _write_on(_form, "MEMBERSHIP")
	box.add_child(_text("The house keeps a ledger of every member: their rating, their wins and their lies. Sign in, or become a member with a name and a password." if not _touch
			else "Sign in, or become a member with a name and a password."))
	var name_line := _field(Settings.ranked_name if Settings.ranked_name != "" else Settings.player_name, "Name", 12)
	box.add_child(Desk.written("NAME", 12, Desk.INK_FADED))
	box.add_child(name_line)
	var password := _field("", "Password", 64)
	password.secret = true
	box.add_child(Desk.written("PASSWORD", 12, Desk.INK_FADED))
	box.add_child(password)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var sign_in := UI.button("SIGN IN", UI.BORDER, 19)
	sign_in.custom_minimum_size = Vector2(0, 56 if _touch else 46)
	sign_in.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Desk.stamp(sign_in)
	row.add_child(sign_in)
	var join := UI.button("JOIN", UI.BORDER, 19)
	join.custom_minimum_size = sign_in.custom_minimum_size
	join.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Desk.stamp(join, Desk.INK_BLUE)
	row.add_child(join)
	box.add_child(row)
	var note := Desk.written("", 13, Desk.INK_RED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)
	var enter := func(new_member: bool) -> void:
		if _busy:
			return
		_busy = true
		Desk.ink(note, Desk.INK_FADED)
		note.text = Loc.t("Knocking on the house's door...")
		var answer: Dictionary = await RankedApi.enter(name_line.text.strip_edges(), password.text, new_member)
		_busy = false
		if not is_instance_valid(note):
			return
		if not answer.ok:
			Desk.ink(note, Desk.INK_RED)
			note.text = Loc.t(answer.error)
			UI.shake(_form, 6.0)
			return
		_me = answer.data.get("me", {})
		_show_member()
		_open_house()
	sign_in.pressed.connect(enter.bind(false))
	join.pressed.connect(enter.bind(true))
	password.text_submitted.connect(func(_t: String) -> void: enter.call(false))


func _write_on(sheet: Desk, heading: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.position = Vector2(28, 26)
	box.size = sheet.size - Vector2(56, 52)
	box.add_theme_constant_override("separation", 6)
	sheet.add_child(box)
	box.add_child(Desk.written(heading, 24, Desk.INK, true))
	for weight: int in [2, 1]:
		var rule := ColorRect.new()
		rule.color = Desk.INK if weight == 2 else Desk.INK_FADED
		rule.custom_minimum_size = Vector2(0, weight)
		rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(rule)
	return box


func _text(text: String) -> Label:
	var l := Desk.written(text, 15)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _field(text: String, hint: String, length: int) -> LineEdit:
	var edit := LineEdit.new()
	edit.text = text
	edit.placeholder_text = hint
	edit.max_length = length
	edit.add_theme_font_size_override("font_size", UI.grow(20))
	edit.custom_minimum_size = Vector2(0, 40 if _touch else 32)
	Desk.line(edit)
	return edit


# --- talking to the house ------------------------------------------------------

## Asks the house for the member, the queue and the standings.
func _open_house() -> void:
	if not RankedApi.configured():
		_write_ledger()
		return
	if RankedApi.signed_in():
		var mine: Dictionary = await RankedApi.get_json("/v1/me")
		if not is_inside_tree():
			return
		if mine.ok and mine.data is Dictionary:
			_me = mine.data.get("me", {})
			_write_card()
			_take(mine.data.get("queue", {}))
		elif mine.status == 401:
			_show_member()
		else:
			_tell(mine.error)
	var board: Dictionary = await RankedApi.get_json("/v1/standings?limit=60", false)
	if not is_inside_tree():
		return
	if board.ok and board.data is Dictionary:
		_standings = board.data.get("players", [])
	elif not board.ok:
		_tell(board.error)
	_write_ledger()
	# Why the last table ended, if that is how the member got here.
	if Room.notice != "":
		_tell(Room.notice)
		Room.notice = ""
	if queue_on_open and RankedApi.signed_in() and _state == &"idle":
		queue_on_open = false
		_on_queue_pressed()
	_show_queue()


## What the house said of this member's place in the queue.
func _take(queue: Dictionary) -> void:
	match str(queue.get("state", "idle")):
		"waiting":
			_state = &"waiting"
			_since = Time.get_unix_time_from_system() - float(queue.get("waited", 0))
			_queue_text.set_meta(&"waiting", queue)
		"matched":
			if _state == &"waiting":
				# Found while waiting for it: straight to the table.
				_state = &"matched"
				_sit(queue.get("match", {}))
			elif _state != &"seated":
				# A table dealt before (the member left it): it waits for them.
				_state = &"matched"
				_queue_text.set_meta(&"match", queue.get("match", {}))
		_:
			if _state in [&"waiting", &"matched"]:
				_state = &"idle"
	_show_queue()


func _process(delta: float) -> void:
	if _state == &"waiting":
		_watch.stopwatch = Time.get_unix_time_from_system() - _since
		_poll_left -= delta
		if _poll_left <= 0.0 and not _busy:
			_poll_left = POLL
			_poll()
	elif _watch.stopwatch != null and _state != &"seated":
		_watch.stopwatch = null


func _poll() -> void:
	_busy = true
	var answer: Dictionary = await RankedApi.get_json("/v1/queue")
	_busy = false
	if not is_inside_tree() or _state != &"waiting":
		return
	if answer.ok and answer.data is Dictionary:
		_take(answer.data)
	else:
		_tell(answer.error)


func _on_queue_pressed() -> void:
	if _busy:
		return
	match _state:
		&"idle":
			_busy = true
			_tell("")
			var answer: Dictionary = await RankedApi.post_json("/v1/queue", {"build": _build()})
			_busy = false
			if not is_inside_tree():
				return
			if answer.ok and answer.data is Dictionary:
				_since = Time.get_unix_time_from_system()
				_poll_left = POLL
				_take(answer.data)
			else:
				_tell(answer.error)
		&"waiting":
			_state = &"idle"
			_show_queue()
			RankedApi.delete_json("/v1/queue")
		&"matched":
			_sit(_queue_text.get_meta(&"match", {}))


## Takes the seat the house dealt this member, at the table's own room.
func _sit(table: Dictionary) -> void:
	_queue_text.set_meta(&"match", table)
	if table.is_empty():
		return
	if Room.current != null and Room.current.ranked:
		return
	var problem: String = Room.join_ranked(str(table.get("address", "")), int(table.get("port", 0)), str(table.get("ticket", "")), str(_me.get("name", Settings.ranked_name)))
	if problem != "":
		_tell(problem)
		_state = &"matched"
		_show_queue()
		return
	_state = &"seated"
	_watch.stopwatch = 0.0
	_since = Time.get_unix_time_from_system()
	Room.current.changed.connect(_show_queue)
	_show_queue()


## The build this machine plays (the house only seats equal builds together).
func _build() -> int:
	return Room.new()._build()


func _show_queue() -> void:
	if not is_instance_valid(_queue_text):
		return
	_queue_button.disabled = false
	match _state:
		&"idle":
			_queue_text.text = Loc.t("Tables of %d to %d players. The watch runs while you wait." if not _touch else "Tables of %d to %d players.") % [3, 5]
			_queue_button.text = "FIND A MATCH"
		&"waiting":
			var queue: Dictionary = _queue_text.get_meta(&"waiting", {})
			_queue_text.text = Loc.t("Looking for a table... %d in the queue." if not _touch else "In the queue: %d.") % int(queue.get("waiting", 1))
			_queue_button.text = "LEAVE THE QUEUE"
		&"matched":
			_queue_text.text = Loc.t("Your table is waiting for you.")
			_queue_button.text = "TAKE MY SEAT"
		&"seated":
			var room: Node = Room.current
			if room != null and room.ranked and not room.seats.is_empty():
				var sat: int = room.seats.filter(func(seat: Dictionary) -> bool: return seat.peer > 0).size()
				_queue_text.text = Loc.t("Seated: %d of %d. The cards are dealt when everyone sits down." if not _touch else "Seated: %d of %d.") % [sat, room.seats.size()]
			else:
				_queue_text.text = Loc.t("A table is ready. Taking your seat...")
			_queue_button.text = "TAKE MY SEAT"
			_queue_button.disabled = true
		&"closed":
			_queue_button.disabled = true


func _tell(text: String) -> void:
	if not is_instance_valid(_queue_note):
		return
	_queue_note.text = Loc.t(text) if text != "" else ""
	_queue_note.visible = text != "" and _slip.visible


func _on_sign_out() -> void:
	if _state in [&"waiting"]:
		RankedApi.delete_json("/v1/queue")
	_state = &"idle"
	await RankedApi.sign_out()
	_me = {}
	if is_inside_tree():
		_show_member()
		_write_ledger()


# --- the ledger ----------------------------------------------------------------

func _per_page() -> int:
	return TOUCH_PER_PAGE if _touch else PER_PAGE


func _spreads() -> int:
	return maxi(1, ceili(_standings.size() / float(_per_page() * 2)))


func _write_ledger() -> void:
	for sheet: Control in _pages:
		UI.clear(sheet)
	var marked: Array[Vector2i] = []
	_spread = mini(_spread, _spreads() - 1)
	var per := _per_page()
	var row: float = _ledger.row
	var columns: Array[float] = _ledger.columns
	var mine := int(_me.get("id", -1))
	for index in 2:
		var sheet: Control = _pages[index]
		if index == 0:
			var heading := Desk.written("STANDINGS", 22, Desk.INK, true)
			heading.position = Vector2(14, 10)
			sheet.add_child(heading)
		else:
			var heading := Desk.written("OF THE HOUSE", 22, Desk.INK, true)
			heading.position = Vector2(14, 10)
			sheet.add_child(heading)
		var heads := ["#", "MEMBER", "RATING", "W / M", "LAST"] if not _touch else ["#", "MEMBER", "RATING", "W / M"]
		var starts := [0.0] + Array(columns)
		for c in heads.size():
			var head := Desk.written(heads[c], 11, Desk.INK_FADED)
			var x: float = starts[c] + 6.0 if c < starts.size() else 0.0
			head.position = Vector2(x, ROWS_FROM - 20.0)
			sheet.add_child(head)
		for r in per:
			var at := (_spread * 2 + index) * per + r
			if at >= _standings.size():
				break
			var entry: Dictionary = _standings[at]
			if int(entry.get("id", -2)) == mine:
				marked.append(Vector2i(index, r))
			_write_row(sheet, entry, ROWS_FROM + r * row, row, starts)
	if _standings.is_empty():
		var empty := Desk.written("Nobody has played at the house yet. The first names in this ledger are still to be written." if RankedApi.configured()
				else "The ledger is empty: the house has not opened yet.", 15, Desk.INK_FADED)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.position = Vector2(30, ROWS_FROM + row * 2.0)
		empty.size = Vector2((_pages[0] as Control).size.x - 60.0, 100)
		_pages[0].add_child(empty)
	_ledger.marked = marked
	_ledger_turn.visible = _spreads() > 1
	_ledger_turn.text = Loc.t("Next page") if _spread < _spreads() - 1 else Loc.t("First page")


func _write_row(sheet: Control, entry: Dictionary, y: float, row: float, starts: Array) -> void:
	var rank := int(entry.get("rank", 0))
	var middle := y + row / 2.0
	var size := 16 if not _touch else 15
	if rank <= 3:
		var mark := MedalMark.new()
		mark.place = rank
		mark.position = Vector2(starts[0] + 17.0, middle)
		sheet.add_child(mark)
	else:
		var number := Desk.written(str(rank), size, Desk.INK)
		number.position = Vector2(4, middle - 11.0)
		number.size = Vector2(30, 22)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sheet.add_child(number)
	var who := Desk.written(str(entry.get("name", "")), size + 1, Desk.INK_BLUE)
	who.position = Vector2(starts[1] + 6.0, middle - 12.0)
	who.size = Vector2(starts[2] - starts[1] - 10.0, 24)
	who.clip_text = true
	who.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	sheet.add_child(who)
	var rating := Desk.written(str(int(entry.get("rating", 0))), size + 1, Desk.INK)
	rating.position = Vector2(starts[2] + 4.0, middle - 11.0)
	rating.size = Vector2(starts[3] - starts[2] - 10.0, 22)
	rating.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sheet.add_child(rating)
	var record := Desk.written("%d / %d" % [int(entry.get("wins", 0)), int(entry.get("matches", 0))], size - 2, Desk.INK_FADED)
	record.position = Vector2(starts[3] + 4.0, middle - 10.0)
	var right_of: float = starts[4] if starts.size() > 4 else sheet.size.x
	record.size = Vector2(right_of - starts[3] - 8.0, 20)
	record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sheet.add_child(record)
	if starts.size() > 4:
		var form := House.Form.new()
		form.places = entry.get("form", []).map(func(place: Variant) -> int: return int(place))
		form.position = Vector2(starts[4] + 4.0, middle - 9.0)
		form.size = Vector2(sheet.size.x - starts[4] - 6.0, 18)
		sheet.add_child(form)
	TipLayer.attach(who, Loc.t("%s: best rating %d.") % [entry.get("name", ""), int(entry.get("peak", 0))])
	who.mouse_filter = Control.MOUSE_FILTER_PASS


## The medal of the first three places, by the name in the ledger.
class MedalMark extends Control:
	const METALS := [Color("e0b04a"), Color("c9ccd2"), Color("b8743a")]
	var place := 1

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var metal: Color = METALS[clampi(place - 1, 0, 2)]
		var r := 10.0
		House._disc_on(self, Vector2(2, 3), r, Color(0, 0, 0, 0.35))
		House._disc_on(self, Vector2.ZERO, r, metal.darkened(0.45))
		House._disc_on(self, Vector2(-2, -2), r - 2.0, metal.lightened(0.3))
		House._disc_on(self, Vector2.ZERO, r - 2.0, metal)
		var font := UI.font()
		var s := UI.px(14)
		draw_string(font, Vector2(-10, s * 0.36), str(place), HORIZONTAL_ALIGNMENT_CENTER, 20, s, metal.darkened(0.6))


# --- leaving -------------------------------------------------------------------

func _on_gazette() -> void:
	_leave_queue()
	Transition.go(STATS_SCENE, Transition.DESK)


func _on_back() -> void:
	_leave_queue()
	Transition.go(ROOM_SCENE, Transition.DESK)


func _leave_queue() -> void:
	if _state == &"waiting":
		RankedApi.delete_json("/v1/queue")
	if Room.current != null and Room.current.ranked and not Room.current.in_match:
		Room.current.leave()
	_state = &"idle"


func _unhandled_key_input(event: InputEvent) -> void:
	UI.handle_fullscreen_key(event, get_window())
