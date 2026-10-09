extends Control
## The lobby of a room: who sits at the table, which characters and items are
## in the match, and the house rules.
##
## Everything here belongs to the host, who sets it and deals the cards. The
## others watch the same screen change as the host touches it, and the one
## thing they may edit is their own name. The seats and the rules live in the
## room (room.gd), so they are still there when a match ends and everyone
## comes back.

const Room := preload("res://scripts/net/room.gd")
const Jukebox := preload("res://scripts/ui/jukebox.gd")
const Transition := preload("res://scripts/ui/transition.gd")
const ROOM_SCENE := "res://scenes/room.tscn"
## Width of the character grid, and the most cards it shows in a single row.
const GRID_WIDTH := 690.0
const GRID_ROW := 10
const ANIM_SPEEDS := [50, 75, 100, 150, 200, 250, 300]  # percent
## Two arrows chasing each other clockwise (the reset buttons).
const CYCLE_ICON: Array[String] = [
	"..###....",
	".#...#...",
	"#...#####",
	"#....###.",
	"..#...#..",
	".###....#",
	"#####...#",
	"...#...#.",
	"....###..",
]
## The arrow beside the title of the house rules: folded away, and open.
const FOLDED_ICON: Array[String] = [
	"#...",
	"##..",
	"###.",
	"####",
	"###.",
	"##..",
	"#...",
]
const OPEN_ICON: Array[String] = [
	"#######",
	".#####.",
	"..###..",
	"...#...",
]
## The character being read, behind the text: its art in one colour, faint,
## melting into the panel at the edges.
const GHOST_SHADER := "shader_type canvas_item;

uniform vec3 tint : source_color = vec3(0.86, 0.68, 0.36);
uniform float strength = 0.3;

void fragment() {
	vec4 art = texture(TEXTURE, UV);
	float light = dot(art.rgb, vec3(0.299, 0.587, 0.114));
	float edge = smoothstep(0.0, 0.3, UV.x) * smoothstep(1.0, 0.8, UV.x)
			* smoothstep(0.0, 0.12, UV.y) * smoothstep(1.0, 0.6, UV.y);
	COLOR = vec4(tint * (0.25 + light * 1.1), art.a * strength * edge * COLOR.a);
}"

## Whether the house rules are unfolded. Folded away, their place is where
## the abilities of the characters are read. It is kept for the next time
## this screen opens (back from a match).
static var _rules_open := false

var _room: Node
var _host := false
var _config: GameConfig
var _seat_rows: Array = []  # {row, name, tag, remove}
var _seated: Array = []  # who was in each seat when the rows were last filled
var _seat_title: Label
var _add_bot: Button
var _random := true
var _picked: Array = []
var _items_on: Dictionary = {}
var _cards: Dictionary = {}  # character id -> CardView
var _item_views: Dictionary = {}
var _refreshers: Array = []  # Callables that redraw a stepper value
var _mode_random: Button
var _mode_picked: Button
var _count_row: Control
var _summary: Label
var _start: Button
var _resets: Array = []  # {button, is_default: Callable}
var _problem: Label
var _rules: VBoxContainer
var _rules_arrow: Control
## Where the abilities of a character are read, in the place of the rules.
var _reader: RichTextLabel
var _read: StringName  # the character in the reader
var _ghost: TextureRect
var _ghost_tween: Tween


func _ready() -> void:
	Settings.ensure_loaded()
	theme = UI.theme()
	Jukebox.play(Jukebox.LOBBY)
	Content.ensure_loaded()
	_room = Room.current
	if _room == null:
		# Nobody gets here without a room; the screen before this one opens it.
		get_tree().change_scene_to_file.call_deferred(ROOM_SCENE)
		return
	_host = _room.hosting
	_config = _room.config
	_read_config()

	var bg := TextureRect.new()
	# The table itself, before anyone sits down.
	bg.texture = UI.tex("res://assets/table.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.modulate = Color(0.5, 0.44, 0.42)
	add_child(bg)
	add_child(TipLayer.new())

	var title := UI.label("SET THE TABLE", 36, UI.GOLD, true)
	title.position = Vector2(26, 10)
	add_child(title)

	_build_address()
	_build_players(_panel(Rect2(24, 62, 372, 508)))
	_build_match(_panel(Rect2(408, 62, 720, 508)))

	var back := UI.button("LEAVE ROOM", UI.BORDER, 20)
	back.position = Vector2(24, 584)
	back.size = Vector2(170, 48)
	back.pressed.connect(_on_leave)
	if _host:
		TipLayer.attach(back, "Closes the room for everyone.")
	add_child(back)
	_start = UI.button("DEAL THE CARDS", UI.GOLD, 22)
	_start.position = Vector2(868, 584)
	_start.size = Vector2(260, 48)
	_start.pressed.connect(_on_start)
	_start.visible = _host
	add_child(_start)
	_problem = UI.label("", 14, UI.RED)
	_problem.position = Vector2(210, 598)
	_problem.size = Vector2(644, 20)
	_problem.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_problem)
	if not _host:
		var waiting := UI.label("Waiting for the host to deal...", 18, UI.MUTED, true)
		waiting.position = Vector2(728, 584)
		waiting.size = Vector2(400, 48)
		waiting.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		waiting.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(waiting)
	_room.changed.connect(_on_room_changed)
	_refresh()


func _exit_tree() -> void:
	Settings.save()


## Top right: where the others find this room, or whose rules these are.
func _build_address() -> void:
	var line := UI.label("Only the host changes the table. You may change your name.", 16, UI.MUTED)
	line.position = Vector2(408, 22)
	line.size = Vector2(720, 28)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(line)
	if not _host:
		return
	var addresses: Array = Room.addresses()
	line.add_theme_color_override("font_color", UI.CREAM)
	line.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	if addresses.is_empty():
		line.text = Loc.t("This computer has no network address to share.")
		return
	line.text = Loc.t("ROOM ADDRESS:  %s") % addresses[0]
	line.mouse_filter = Control.MOUSE_FILTER_PASS
	var tip := Loc.t("What your friends type to join. With Radmin VPN it is the address that starts with 26.")
	if addresses.size() > 1:
		tip += "\n" + Loc.t("This computer also answers at: %s") % ", ".join(addresses.slice(1))
	tip += "\n" + Loc.t("If nobody gets in, allow the game through the firewall (UDP port %d).") % Room.PORT
	TipLayer.attach(line, tip)


func _panel(rect: Rect2) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel", UI.box(Color(UI.INK, 0.93), UI.BORDER, 2, 6, 14))
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)
	return box


func _build_players(box: VBoxContainer) -> void:
	var head := HBoxContainer.new()
	head.custom_minimum_size = Vector2(0, 30)
	_seat_title = UI.label("", 18, UI.GOLD, true)
	_seat_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_seat_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_seat_title)
	_add_bot = UI.button("ADD BOT", UI.BORDER, 14)
	_add_bot.custom_minimum_size = Vector2(96, 28)
	_add_bot.pressed.connect(func(): _room.add_bot())
	_add_bot.visible = _host
	head.add_child(_add_bot)
	box.add_child(head)
	for i in Room.MAX_SEATS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var number := UI.label(str(i + 1), 16, UI.MUTED, true)
		number.custom_minimum_size = Vector2(16, 0)
		row.add_child(number)
		var name_edit := LineEdit.new()
		name_edit.max_length = Room.NAME_LENGTH
		name_edit.custom_minimum_size = Vector2(170, 28)
		name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_edit.text_changed.connect(_on_renamed.bind(i))
		row.add_child(name_edit)
		var tag := UI.label("", 14, UI.MUTED, true)
		tag.custom_minimum_size = Vector2(58, 0)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(tag)
		var remove := UI.button("X", UI.RED, 13)
		remove.custom_minimum_size = Vector2(30, 28)
		remove.pressed.connect(func(): _room.remove_bot(i))
		TipLayer.attach(remove, "Take this bot out of the room.")
		row.add_child(remove)
		box.add_child(row)
		_seat_rows.append({"row": row, "name": name_edit, "tag": tag, "remove": remove})

	box.add_child(HSeparator.new())
	box.add_child(_rules_header())
	_rules = VBoxContainer.new()
	_rules.add_theme_constant_override("separation", 5)
	box.add_child(_rules)
	_rules.add_child(_stepper("Starting Morale", "Lose it all and you are out.",
			func(): return _config.start_morale, func(v): _config.start_morale = v, 1, 5))
	_rules.add_child(_stepper("Starting coins", "",
			func(): return _config.start_coins, func(v): _config.start_coins = v, 0, 10))
	_rules.add_child(_stepper("Income per turn", "",
			func(): return _config.income, func(v): _config.income = v, 0, 5))
	_rules.add_child(_stepper("Cost of a wrong LIAR!", "Coins you lose when you doubt someone who was telling the truth.",
			func(): return _config.doubt_cost, func(v): _config.doubt_cost = v, 0, 6))
	_rules.add_child(_stepper("Shop slots", "",
			func(): return _config.shop_slots, func(v): _config.shop_slots = v, 1, 4))
	_rules.add_child(_stepper("Animation speed", "",
			_anim_speed_index, func(v): _config.anim_speed = ANIM_SPEEDS[v] / 100.0,
			0, ANIM_SPEEDS.size() - 1, false, 1, "%d%%", ANIM_SPEEDS))
	_reader = RichTextLabel.new()
	_reader.bbcode_enabled = true
	_reader.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_reader.add_theme_font_size_override("normal_font_size", 15)
	_reader.add_theme_font_size_override("bold_font_size", 15)
	box.add_child(_reader)
	_ghost = TextureRect.new()
	_ghost.show_behind_parent = true
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# The right side of the reader, where the lines of text end.
	_ghost.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ghost.anchor_left = 0.56
	var look := ShaderMaterial.new()
	look.shader = Shader.new()
	look.shader.code = GHOST_SHADER
	_ghost.material = look
	_reader.add_child(_ghost)


## The title of the house rules, which folds them away and brings them back.
func _rules_header() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 26)
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_rules_arrow = Control.new()
	_rules_arrow.custom_minimum_size = Vector2(14, 0)
	_rules_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rules_arrow.draw.connect(func():
		_draw_bits(_rules_arrow, OPEN_ICON if _rules_open else FOLDED_ICON, UI.GOLD))
	row.add_child(_rules_arrow)
	var title := UI.label("HOUSE RULES", 16, UI.GOLD, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	row.add_child(_reset_button(_reset_rules, _rules_default))
	row.mouse_entered.connect(func(): title.add_theme_color_override("font_color", UI.CREAM))
	row.mouse_exited.connect(func(): title.add_theme_color_override("font_color", UI.GOLD))
	row.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_set_rules_open(not _rules_open))
	TipLayer.attach(row, func() -> String:
		return Loc.t("Click to fold the rules away. While they are open, right-click a character to read its abilities here."
				if _rules_open else "Click to show the rules."))
	return row


func _set_rules_open(open: bool) -> void:
	_rules_open = open
	if TipLayer.current != null:
		TipLayer.current.hide_all()
	_redraw_reader()


## A card of the grid was hovered (`asked` false) or right-clicked. Hovering
## only reaches the reader while the rules are folded away; asking for it
## folds them.
func _read_character(character_id: StringName, asked: bool) -> void:
	if _rules_open and not asked:
		return
	_read = character_id
	if _rules_open:
		_set_rules_open(false)
	else:
		_redraw_reader()


func _on_card_input(event: InputEvent, character_id: StringName) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_read_character(character_id, true)


func _redraw_reader() -> void:
	_rules.visible = _rules_open
	_rules_arrow.queue_redraw()
	_reader.visible = not _rules_open
	var def := Content.character(_read) if _read != &"" else null
	var text := "[color=%s]%s[/color]" % [UI.hex(UI.MUTED), Loc.t("Hover a character to read its abilities here.")]
	if def != null:
		text = UI.character_tip(def, _cards[_read].note)
	# Left alone when nothing changed, so a long text stays where it was scrolled to.
	if _reader.text != text:
		_reader.text = text
	var art := UI.card_art(def.texture_path) if def != null else null
	if _ghost.texture != art:
		_ghost.texture = art
		_ghost.texture_filter = UI.card_filter(art)
		if _ghost_tween != null:
			_ghost_tween.kill()
		_ghost.modulate.a = 0.0
		_ghost_tween = _ghost.create_tween()
		_ghost_tween.tween_property(_ghost, "modulate:a", 1.0, 0.25)


func _build_match(box: VBoxContainer) -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var title := UI.label("CHARACTERS", 20, UI.GOLD, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_reset_button(_reset_characters, _characters_default))
	_mode_random = UI.button("Random", UI.BORDER, 15)
	_mode_random.custom_minimum_size = Vector2(110, 32)
	_mode_random.pressed.connect(_set_random.bind(true))
	TipLayer.attach(_mode_random, "Draw the characters of the match at random.")
	head.add_child(_mode_random)
	_mode_picked = UI.button("Hand-picked", UI.BORDER, 15)
	_mode_picked.custom_minimum_size = Vector2(130, 32)
	_mode_picked.pressed.connect(_set_random.bind(false))
	TipLayer.attach(_mode_picked, "Choose exactly which characters are in the match.")
	head.add_child(_mode_picked)
	box.add_child(head)

	_count_row = _stepper("How many characters", "", func(): return _config.character_count,
			func(v): _config.character_count = v, 3, Content.characters.size())
	box.add_child(_count_row)

	# One row while the cast fits in it, two rows of smaller cards after that.
	var defs := Content.character_list()
	var rows := 1 if defs.size() <= GRID_ROW else 2
	var per_row := ceili(defs.size() / float(rows))
	var card_scale := 1.15 if rows == 1 else 0.9
	var card_height := CardView.BASE.y * card_scale
	var row_height := card_height + 22.0
	var step := GRID_WIDTH / per_row
	var grid := Control.new()
	grid.custom_minimum_size = Vector2(GRID_WIDTH, rows * row_height + 6.0)
	box.add_child(grid)
	for i in defs.size():
		var def: CharacterDef = defs[i]
		var column := i % per_row
		var top := 6.0 + floorf(i / float(per_row)) * row_height
		var card := CardView.new(card_scale)
		card.position = Vector2(roundf(column * step + (step - card.size.x) / 2.0), top)
		card.set_card(def.id, true)
		# The abilities are read in the place of the house rules, not over the cards.
		card.tips = false
		card.mouse_entered.connect(_read_character.bind(def.id, false))
		card.gui_input.connect(_on_card_input.bind(def.id))
		if _host:
			card.clicked.connect(_toggle_character.bind(def.id))
		grid.add_child(card)
		_cards[def.id] = card
		var caption := UI.label(def.display_name, 11, UI.MUTED)
		# Clipping comes before the size: until then the label refuses to be
		# narrower than its text, and a long name would be centred in a wider box.
		caption.clip_text = true
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.position = Vector2(column * step, top + card_height + 3.0)
		caption.size = Vector2(step, 16)
		grid.add_child(caption)

	box.add_child(_stepper("Copies of each character", "More copies make every claim more believable.",
			func(): return maxi(_config.copies_per_character, _min_copies()),
			func(v): _config.copies_per_character = v, 2, 6))
	_summary = UI.label("", 13, UI.MUTED)
	box.add_child(_summary)

	box.add_child(HSeparator.new())
	box.add_child(_header("ITEMS IN THE SHOP", 20, _reset_items, _items_default))
	var items := HBoxContainer.new()
	items.add_theme_constant_override("separation", 12)
	box.add_child(items)
	for def: ItemDef in Content.item_list():
		var view := ItemView.new(0.95)
		view.set_item(def)
		if def.fixed:
			# Part of every match: on sale outside the slots, nothing to toggle.
			view.note = "Always on sale, outside the shop slots. Can't be banned."
			view.clicked.connect(_refuse.bind(view))
			items.add_child(view)
			continue
		if _host:
			view.note = "Click to allow or ban it."
			view.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			view.clicked.connect(func():
				_items_on[def.id] = not _items_on[def.id]
				_refresh())
		items.add_child(view)
		_item_views[def.id] = view


## A "no" wobble for something that can't be toggled. It rotates instead of
## moving so the container layout is left alone.
func _refuse(view: Control) -> void:
	var tween := view.create_tween()
	for angle: float in [0.22, -0.2, 0.14, -0.1, 0.05]:
		tween.tween_property(view, "rotation", angle, 0.045)
	tween.tween_property(view, "rotation", 0.0, 0.045)


## Position in ANIM_SPEEDS of the speed closest to the configured one.
func _anim_speed_index() -> int:
	var percent := _config.anim_speed * 100.0
	var best := 0
	for i in ANIM_SPEEDS.size():
		if absf(ANIM_SPEEDS[i] - percent) < absf(ANIM_SPEEDS[best] - percent):
			best = i
	return best


## A labelled "- value +" row bound to a getter and a setter. With `shown`,
## the value is an index into it and the entry is what gets displayed.
func _stepper(text: String, tip: String, getter: Callable, setter: Callable, low: int, high: int, big := false, step := 1, format := "%d", shown: Array = []) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var l := UI.label(text, 18 if big else 14, UI.GOLD if big else UI.CREAM, big)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	if tip != "":
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		TipLayer.attach(l, tip)
	var minus := UI.button("-", UI.BORDER, 15)
	minus.custom_minimum_size = Vector2(34, 26)
	var value := UI.label("", 16, UI.GOLD, true)
	value.custom_minimum_size = Vector2(52, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var plus := UI.button("+", UI.BORDER, 15)
	plus.custom_minimum_size = Vector2(34, 26)
	row.add_child(minus)
	row.add_child(value)
	row.add_child(plus)
	var change := func(delta: int):
		setter.call(clampi(getter.call() + delta, low, high))
		UI.pop(value, 1.4, 0.2)
		_refresh()
	minus.pressed.connect(change.bind(-step))
	plus.pressed.connect(change.bind(step))
	_refreshers.append(func():
		var current: int = getter.call()
		value.text = format % (current if shown.is_empty() else shown[current])
		minus.disabled = not _host or current <= low
		plus.disabled = not _host or current >= high)
	return row


func _set_random(value: bool) -> void:
	if not _host:
		return
	_random = value
	if not _random and _picked.is_empty():
		for def: CharacterDef in Content.character_list().slice(0, _config.character_count):
			_picked.append(def.id)
	_refresh()


func _toggle_character(character_id: StringName) -> void:
	if _random:
		_set_random(false)
		return
	if _picked.has(character_id):
		_picked.erase(character_id)
	else:
		_picked.append(character_id)
	UI.pop(_cards[character_id], 1.15, 0.2)
	_refresh()


func _character_count() -> int:
	return _config.character_count if _random else _picked.size()


func _min_copies() -> int:
	var probe := GameConfig.new()
	probe.seats.resize(_room.seats.size())
	return probe.min_copies(_character_count())


## The host changed something: it goes into the room's config and from there
## to everyone, this screen included (_on_room_changed).
func _refresh() -> void:
	if not _host:
		_redraw()
		return
	_write_config()
	_room.push()


func _on_room_changed() -> void:
	if not _host:
		_config = _room.config
		_read_config()
	_redraw()


## What the config says about the characters and items, as this screen keeps it.
func _read_config() -> void:
	_random = _config.character_ids.is_empty()
	_picked = _config.character_ids.duplicate()
	for def: ItemDef in Content.item_list():
		if not def.fixed:
			_items_on[def.id] = _config.item_ids.is_empty() or _config.item_ids.has(def.id)


func _write_config() -> void:
	_config.character_ids = [] if _random else _picked.duplicate()
	_config.item_ids = []
	if _items_on.values().has(false):
		for item_id: StringName in _items_on:
			if _items_on[item_id]:
				_config.item_ids.append(item_id)
		if _config.item_ids.is_empty():
			_config.item_ids = [&"none"]


func _on_renamed(text: String, seat: int) -> void:
	if seat < _room.seats.size() and _room.seats[seat].peer == _room.my_peer():
		var player_name: String = Room.clean_name(text)
		Settings.player_name = player_name if player_name != "" else "Player"
	_room.rename(seat, text)


func _redraw_seats() -> void:
	var seats: Array = _room.seats
	var me: int = _room.my_peer()
	var seated := seats.map(func(seat: Dictionary) -> int: return seat.peer)
	# Someone came or went: the rows no longer stand for the same people.
	var moved := seated != _seated
	_seated = seated
	_seat_title.text = "%s  %d/%d" % [Loc.t("PLAYERS"), seats.size(), Room.MAX_SEATS]
	_add_bot.disabled = seats.size() >= Room.MAX_SEATS
	for i in _seat_rows.size():
		var row: Dictionary = _seat_rows[i]
		row.row.visible = i < seats.size()
		if i >= seats.size():
			continue
		var seat: Dictionary = seats[i]
		var edit: LineEdit = row.name
		if moved and edit.has_focus():
			edit.release_focus()
		# The name being typed is ahead of what the room has heard of it.
		if not edit.has_focus() and edit.text != seat.name:
			edit.text = seat.name
		edit.editable = _host or seat.peer == me
		edit.modulate = Color.WHITE if edit.editable else Color(0.72, 0.7, 0.68)
		row.tag.text = "BOT" if seat.bot else ("YOU" if seat.peer == me else ("HOST" if seat.peer == 1 else ""))
		row.tag.add_theme_color_override("font_color", UI.GOLD if seat.peer == me else UI.MUTED)
		row.remove.visible = _host and seat.bot


func _redraw() -> void:
	for refresher: Callable in _refreshers:
		refresher.call()
	_redraw_seats()
	_style_toggle(_mode_random, _random)
	_style_toggle(_mode_picked, not _random)
	_count_row.visible = _random
	for character_id: StringName in _cards:
		var card: CardView = _cards[character_id]
		var chosen: bool = not _random and _picked.has(character_id)
		card.highlight(UI.GOLD if chosen else null)
		card.modulate = Color.WHITE if chosen or _random else Color(0.4, 0.38, 0.38)
		card.note = "" if _random or not _host else ("In the match. Click to remove." if chosen else "Click to add to the match.")
	for item_id: StringName in _item_views:
		_item_views[item_id].modulate = Color.WHITE if _items_on[item_id] else Color(0.3, 0.28, 0.28)
	_redraw_reader()

	var count := _character_count()
	var copies := maxi(_config.copies_per_character, _min_copies())
	_summary.text = Loc.t("%s  ·  deck of %d cards (%d characters x %d copies), %d dealt.") % [
		Loc.t("%d drawn at random") % count if _random else Loc.t("%d hand-picked") % count,
		count * copies, count, copies, _room.seats.size() * mini(_config.hand_size, _config.start_morale)]
	var problem := ""
	if count < 3:
		problem = "Pick at least 3 characters."
	elif _room.seats.size() < 2:
		problem = "A table needs at least 2 players. Add a bot or wait for someone to join."
	_problem.text = problem if _host else ""
	_start.disabled = problem != ""
	for reset: Dictionary in _resets:
		reset.button.visible = _host and not reset.is_default.call()


func _style_toggle(b: Button, on: bool) -> void:
	var accent := UI.GOLD if on else UI.BORDER.darkened(0.3)
	b.add_theme_stylebox_override("normal", UI.box(accent.darkened(0.6) if on else UI.PANEL, accent, 2, 4, 6))
	b.add_theme_color_override("font_color", UI.GOLD if on else UI.MUTED)


## A section title with its reset button at the right end.
func _header(text: String, size: int, action: Callable, is_default: Callable) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 26)
	var title := UI.label(text, size, UI.GOLD, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	row.add_child(_reset_button(action, is_default))
	return row


## Red "cycling arrows" button that puts one section back to its defaults.
## It only shows while `is_default` says the section was changed.
func _reset_button(action: Callable, is_default: Callable) -> Button:
	var b := UI.button("", UI.RED, 14)
	b.custom_minimum_size = Vector2(30, 26)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	TipLayer.attach(b, "Reset")
	var icon := Control.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(_draw_bits.bind(icon, CYCLE_ICON, UI.CREAM))
	b.add_child(icon)
	b.pressed.connect(func():
		action.call()
		_refresh())
	_resets.append({"button": b, "is_default": is_default})
	return b


## A bitmap of text rows, drawn as square pixels to match the pixel art.
func _draw_bits(icon: Control, bits: Array[String], color: Color) -> void:
	var cell := 2.0
	var origin := ((icon.size - Vector2(bits[0].length(), bits.size()) * cell) / 2.0).round()
	for y in bits.size():
		for x in bits[y].length():
			if bits[y][x] == "#":
				icon.draw_rect(Rect2(origin + Vector2(x, y) * cell, Vector2(cell, cell)), color)


func _rules_default() -> bool:
	var base := GameConfig.new()
	return (_config.start_morale == base.start_morale
			and _config.start_coins == base.start_coins
			and _config.income == base.income
			and _config.doubt_cost == base.doubt_cost
			and _config.shop_slots == base.shop_slots
			and is_equal_approx(_config.anim_speed, base.anim_speed))


func _reset_rules() -> void:
	var base := GameConfig.new()
	_config.start_morale = base.start_morale
	_config.start_coins = base.start_coins
	_config.income = base.income
	_config.doubt_cost = base.doubt_cost
	_config.shop_slots = base.shop_slots
	_config.anim_speed = base.anim_speed


func _characters_default() -> bool:
	var base := GameConfig.new()
	return (_random and _config.character_count == base.character_count
			and _config.copies_per_character == base.copies_per_character)


func _reset_characters() -> void:
	var base := GameConfig.new()
	_random = true
	_picked.clear()
	_config.character_count = base.character_count
	_config.copies_per_character = base.copies_per_character


func _items_default() -> bool:
	return not _items_on.values().has(false)


func _reset_items() -> void:
	for item_id: StringName in _items_on:
		_items_on[item_id] = true


func _on_start() -> void:
	_write_config()
	_room.start()


func _on_leave() -> void:
	_room.leave()
	Transition.go(ROOM_SCENE, Transition.KEYHOLE)


func _unhandled_key_input(event: InputEvent) -> void:
	UI.handle_fullscreen_key(event, get_window())
