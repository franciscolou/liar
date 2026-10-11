extends Control
## The lobby of a room: who sits at the table, which characters and items are
## in the match, and the house rules.
##
## Everything here belongs to the host, who sets it and deals the cards. The
## others watch the same screen change as the host touches it, and the one
## thing they may edit is their own name. The seats and the rules live in the
## room (room.gd), so they are still there when a match ends and everyone
## comes back.
##
## The screen is the top of a desk (noir_desk.gd) and each section is a thing
## lying on it: the players sign a sheet on a clipboard, the house rules are a
## sheet of paper that doubles as the file of the character being read, the
## characters and the items are in an open briefcase lined with red velvet.

const Room := preload("res://scripts/net/room.gd")
const Jukebox := preload("res://scripts/ui/jukebox.gd")
const Transition := preload("res://scripts/ui/transition.gd")
const Desk := preload("res://scripts/ui/noir_desk.gd")
const ROOM_SCENE := "res://scenes/room.tscn"
## Width of the character grid, and the most cards it shows in a single row.
const GRID_WIDTH := 664.0
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
## The character being read, behind the text: its art printed on the paper
## in one faded ink (the dark of the picture is the ink, the light of it is
## the paper), melting away on the left, where the text is.
const GHOST_SHADER := "shader_type canvas_item;

uniform vec3 tint : source_color = vec3(0.3, 0.19, 0.1);
uniform float strength = 0.6;

void fragment() {
	vec4 art = texture(TEXTURE, UV);
	float light = dot(art.rgb, vec3(0.299, 0.587, 0.114));
	float edge = smoothstep(0.0, 0.35, UV.x) * smoothstep(0.0, 0.05, UV.y) * smoothstep(1.0, 0.95, UV.y);
	float dark = 1.0 - light;
	COLOR = vec4(tint, art.a * strength * edge * dark * dark * COLOR.a);
}"
## How long one ghost takes to give way to the next.
const GHOST_BLEND := 0.12
## Where each thing lies on the desk.
const CLIPBOARD := Rect2(20, 62, 376, 290)
## The lid of the case stands past the top of the screen.
const CASE := Rect2(408, -32, 724, 606)
## In the case: the ridge between the characters and the items, the title
## of the items and the row they lie in.
const CASE_RIDGE := 468.0
## How far the line about the deck is lifted off the ridge below it.
const SUMMARY_RISE := 3.0
const CASE_ITEMS := 502.0
## The switch of the book of suspicions: its size, and its knob in blocks.
const SWITCH := Vector2(42, 22)
const KNOB: Array[String] = [
	"..###..",
	".#o###.",
	"#o#####",
	"#######",
	"#####x#",
	".###x#.",
	"..###..",
]
## The sheet of the house rules: its sides, its foot, and where its top is
## while the rules are open. Folded away, it is pulled up over the lines of
## the clipboard nobody signed (see _place_file).
const FILE_SIDES := Vector2(36, 400)
const FILE_FOOT := 580.0
const FILE_TOP := 352.0
## From the top of the clipboard to the first line of its list, and from one
## line to the next.
const SEAT_LINES := 70.0
const SEAT_STEP := 26.0

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
var _book_switch: Button
var _book_knob := 1.0  # where the knob of the switch is: 0 = off, 1 = on
var _book_tween: Tween
var _summary: Label
var _start: Button
var _resets: Array = []  # {button, is_default: Callable}
var _problem: Label
var _address_line: Label
var _rules: VBoxContainer
var _rules_arrow: Control
## Where the abilities of a character are read, in the place of the rules.
var _reader: RichTextLabel
var _read: StringName  # the character in the reader
var _ghost: TextureRect
var _ghost_tween: Tween
## Holds the ghost and the ones before it that are still fading away.
var _ghosts: Control
var _ghost_look: ShaderMaterial
## The sheet the rules and the reader are on.
var _file: Desk
var _desk: Desk
var _things: Array = []
var _case: Desk
var _item_places: Array[Rect2] = []
var _file_tween: Tween
var _file_top := -1.0
## True while the widgets being built go on paper, not on felt.
var _on_paper := false


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

	_desk = Desk.desk()
	_desk.props = [{"kind": &"ring", "at": Vector2(700, 610)}]
	add_child(_desk)
	add_child(TipLayer.new())

	# The top right belongs to the lid of the case: the title and the
	# settings share the left.
	var plaque: Desk = Desk.make(Desk.Kind.PLAQUE, Rect2(20, 8, 236, 46))
	add_child(plaque)
	var title := Desk.written("SET THE TABLE", 24, UI.INK, true)
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plaque.add_child(title)

	_build_address()
	_build_players()
	_build_rules()
	_build_case()

	var back := UI.button("LEAVE ROOM", UI.BORDER, 20)
	back.position = Vector2(20, 590)
	back.size = Vector2(170, 46)
	Desk.brass(back)
	back.pressed.connect(_on_leave)
	if _host:
		TipLayer.attach(back, "Closes the room for everyone.")
	add_child(back)
	var settings := UI.button("SETTINGS", UI.BORDER, 15)
	settings.position = Vector2(264, 8)
	settings.size = Vector2(132, 46)
	Desk.brass(settings)
	settings.pressed.connect(func(): add_child(SettingsPanel.new()))
	add_child(settings)
	_start = UI.button("DEAL THE CARDS", UI.BORDER, 22)
	_start.position = Vector2(872, 590)
	_start.size = Vector2(260, 46)
	Desk.brass(_start, true)
	_start.pressed.connect(_on_start)
	_start.visible = _host
	add_child(_start)
	_problem = UI.label("", 14, UI.RED.lightened(0.25))
	_problem.position = Vector2(546, 590)
	_problem.size = Vector2(314, 46)
	_problem.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_problem.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_problem.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_problem)
	if not _host:
		var waiting := UI.label("Waiting for the host to deal...", 18, UI.CREAM, true)
		waiting.position = Vector2(732, 590)
		waiting.size = Vector2(400, 46)
		waiting.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		waiting.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(waiting)
	_things = Desk.things(self, _desk)
	add_child(Desk.lamplight())
	_room.changed.connect(_on_room_changed)
	_refresh()
	if Transition.desk_bare():
		desk_slide(1.0)


## The way in from the room screen and back (Transition.DESK): everything
## on the desk is dragged off it to the sides as `amount` goes to 1.
func desk_slide(amount: float) -> void:
	Desk.slide(_desk, _things, amount)


func _exit_tree() -> void:
	Settings.save()


## The language was changed in the settings: the lines this screen writes
## itself are written again.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and _summary != null:
		_write_address()
		_redraw()


## A slip of paper beside the button that leaves: where the others find this
## room, or whose rules these are.
func _build_address() -> void:
	var slip: Desk = Desk.make(Desk.Kind.SHEET, Rect2(204, 590, 330, 46))
	slip.rotation = -0.012
	slip.dog_ear = false
	slip.tone = Desk.DIM_PAPER
	add_child(slip)
	var line := Desk.written("Only the host changes the table. You may change your name.", 14, Desk.INK_FADED)
	# Wrapping first: until then the label is as wide as its text.
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.position = Vector2(10, 2)
	line.size = slip.size - Vector2(20, 4)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slip.add_child(line)
	_address_line = line
	if not _host:
		return
	var addresses: Array = Room.addresses()
	Desk.ink(line, Desk.INK)
	line.add_theme_font_size_override("font_size", roundi(16 * UI.FONT_SCALE))
	line.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_write_address()
	if addresses.is_empty():
		return
	line.mouse_filter = Control.MOUSE_FILTER_PASS
	TipLayer.attach(line, func() -> String:
		var tip := Loc.t("What your friends type to join. With Radmin VPN it is the address that starts with 26.")
		if addresses.size() > 1:
			tip += "\n" + Loc.t("This computer also answers at: %s") % ", ".join(addresses.slice(1))
		return tip + "\n" + Loc.t("If nobody gets in, allow the game through the firewall (UDP port %d).") % Room.PORT)


## The host's line is formatted here, so it does not translate itself.
func _write_address() -> void:
	if not _host:
		return
	var addresses: Array = Room.addresses()
	if addresses.is_empty():
		_address_line.text = Loc.t("This computer has no network address to share.")
	else:
		_address_line.text = Loc.t("ROOM ADDRESS:  %s") % addresses[0]


## The players sign in on the sheet of a clipboard, one to a line.
func _build_players() -> void:
	_on_paper = true
	var board: Desk = Desk.make(Desk.Kind.CLIPBOARD, CLIPBOARD)
	board.tone = Desk.DIM_PAPER
	board.browned = true
	board.ruled = SEAT_STEP
	board.ruled_from = SEAT_LINES + SEAT_STEP - Desk.SHEET_AT.y - 1.0
	add_child(board)
	var box := VBoxContainer.new()
	box.position = Vector2(22, SEAT_LINES - 35.0)
	box.size = Vector2(CLIPBOARD.size.x - 44.0, 0)
	box.add_theme_constant_override("separation", 5)
	board.add_child(box)
	var head := HBoxContainer.new()
	head.custom_minimum_size = Vector2(0, 30)
	_seat_title = Desk.written("", 18, Desk.INK, true)
	_seat_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_seat_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_seat_title)
	_add_bot = UI.button("ADD BOT", UI.BORDER, 14)
	_add_bot.custom_minimum_size = Vector2(96, 26)
	_add_bot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	Desk.penned(_add_bot)
	_add_bot.pressed.connect(func(): _room.add_bot())
	_add_bot.visible = _host
	head.add_child(_add_bot)
	box.add_child(head)
	# One line of the sheet to each seat: the rule of the paper is under the name.
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", int(SEAT_STEP) - 24)
	box.add_child(list)
	for i in Room.MAX_SEATS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var number := Desk.written(str(i + 1), 16, Desk.INK_FADED, true)
		number.custom_minimum_size = Vector2(16, 0)
		row.add_child(number)
		var name_edit := LineEdit.new()
		name_edit.max_length = Room.NAME_LENGTH
		name_edit.custom_minimum_size = Vector2(170, 24)
		Desk.line(name_edit, Desk.INK_BLUE, false)
		_slim(name_edit, [&"normal", &"focus", &"read_only"])
		name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_edit.text_changed.connect(_on_renamed.bind(i))
		row.add_child(name_edit)
		var tag := Desk.written("", 14, Desk.INK_FADED, true)
		tag.custom_minimum_size = Vector2(58, 0)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(tag)
		var remove := UI.button("X", UI.BORDER, 13)
		remove.custom_minimum_size = Vector2(30, 22)
		remove.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		Desk.penned(remove, Desk.INK_RED)
		_slim(remove, [&"normal", &"hover", &"pressed"])
		remove.pressed.connect(func(): _room.remove_bot(i))
		TipLayer.attach(remove, "Take this bot out of the room.")
		row.add_child(remove)
		list.add_child(row)
		_seat_rows.append({"row": row, "name": name_edit, "tag": tag, "remove": remove})
	_on_paper = false


## The house rules are a sheet of paper lying over the foot of the clipboard.
## Folded away, the same sheet is the file of the character being read.
func _build_rules() -> void:
	_on_paper = true
	_file = Desk.make(Desk.Kind.SHEET, Rect2(FILE_SIDES.x, FILE_TOP, FILE_SIDES.y - FILE_SIDES.x, FILE_FOOT - FILE_TOP))
	_file.dog_ear = false
	_file.tone = Desk.DIM_PAPER
	_file.browned = true
	_file.clip_at = _file.size.x - 56.0
	add_child(_file)
	# Before the text, so that the text is written over it.
	_ghosts = Control.new()
	_ghosts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_file.add_child(_ghosts)
	_ghost_look = ShaderMaterial.new()
	_ghost_look.shader = Shader.new()
	_ghost_look.shader.code = GHOST_SHADER
	_ghost = _new_ghost()
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 0)
	box.offset_left = 14
	box.offset_top = 10
	box.offset_right = -14
	box.offset_bottom = -10
	box.add_theme_constant_override("separation", 4)
	_file.add_child(box)
	box.add_child(_rules_header())
	_rules = VBoxContainer.new()
	_rules.add_theme_constant_override("separation", 2)
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
	_reader.add_theme_color_override("default_color", Desk.INK)
	_reader.add_theme_font_size_override("normal_font_size", 15)
	_reader.add_theme_font_size_override("bold_font_size", 15)
	box.add_child(_reader)
	_file.resized.connect(_place_ghost)
	_place_ghost()
	_on_paper = false


func _new_ghost() -> TextureRect:
	var ghost := TextureRect.new()
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ghost.material = _ghost_look
	_ghosts.add_child(ghost)
	return ghost


## The ghost fills the right side of the sheet, from top to bottom.
func _place_ghost() -> void:
	var height := _file.size.y - 4.0
	var width := height * CardView.BASE.x / CardView.BASE.y
	for ghost: TextureRect in _ghosts.get_children():
		ghost.position = Vector2(_file.size.x - 2.0 - width, 2.0)
		ghost.size = Vector2(width, height)


## Open, the rules lie under the clipboard. Folded away, the sheet is pulled
## up over the lines nobody signed, so there is more of it to read.
func _place_file(at_once := false) -> void:
	var top := FILE_TOP
	if not _rules_open:
		top = minf(top, CLIPBOARD.position.y + SEAT_LINES + _room.seats.size() * SEAT_STEP + 8.0)
	if top == _file_top:
		return
	at_once = at_once or _file_top < 0.0
	_file_top = top
	if _file_tween != null:
		_file_tween.kill()
	if at_once:
		_file.position.y = top
		_file.size.y = FILE_FOOT - top
		return
	_file_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_file_tween.tween_property(_file, "position:y", top, 0.18)
	_file_tween.tween_property(_file, "size:y", FILE_FOOT - top, 0.18)


## Takes the padding above and below the text out of `control`, so that it
## can be as short as its row.
func _slim(control: Control, states: Array) -> void:
	for state: StringName in states:
		# The control is not in the tree yet: it cannot see the theme of the screen.
		var worn: StyleBox = control.get_theme_stylebox(state)
		if not control.has_theme_stylebox_override(state) and theme.has_stylebox(state, control.get_class()):
			worn = theme.get_stylebox(state, control.get_class())
		var box: StyleBox = worn.duplicate()
		box.content_margin_top = 1
		box.content_margin_bottom = 1
		control.add_theme_stylebox_override(state, box)


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
		_draw_bits(_rules_arrow, OPEN_ICON if _rules_open else FOLDED_ICON, Desk.INK))
	row.add_child(_rules_arrow)
	var title := Desk.written("HOUSE RULES", 16, Desk.INK, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	row.add_child(_reset_button(_reset_rules, _rules_default))
	row.mouse_entered.connect(func(): title.add_theme_color_override("font_color", Desk.INK_RED))
	row.mouse_exited.connect(func(): title.add_theme_color_override("font_color", Desk.INK))
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
	_ghosts.visible = not _rules_open
	_place_file()
	var def := Content.character(_read) if _read != &"" else null
	var text := "[color=%s]%s[/color]" % [UI.hex(UI.MUTED), Loc.t("Hover a character to read its abilities here.")]
	if def != null:
		text = UI.character_tip(def, _cards[_read].note)
	text = Desk.in_ink(text)
	# Left alone when nothing changed, so a long text stays where it was scrolled to.
	if _reader.text != text:
		_reader.text = text
	var art := UI.card_art(def.texture_path) if def != null else null
	if _ghost.texture != art:
		# One ink soaks in while the other fades: the ghost that was there
		# goes on from where it is, so pointing at card after card never
		# leaves the paper blank.
		if _ghost_tween != null:
			_ghost_tween.kill()
		var old := _ghost
		var fade := old.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		fade.tween_property(old, "modulate:a", 0.0, GHOST_BLEND)
		fade.tween_callback(old.queue_free)
		_ghost = _new_ghost()
		_ghost.texture = art
		_ghost.texture_filter = UI.card_filter(art)
		_ghost.modulate.a = 0.0
		_place_ghost()
		_ghost_tween = _ghost.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_ghost_tween.tween_property(_ghost, "modulate:a", 1.0, GHOST_BLEND)


## An open briefcase: the characters lie on the lining of its upper
## compartment and the items in hollows of the lower one.
func _build_case() -> void:
	_case = Desk.make(Desk.Kind.CASE, CASE)
	_case.ridges = [CASE_RIDGE]
	add_child(_case)
	var box := VBoxContainer.new()
	box.position = Vector2(30, 124)
	box.size = Vector2(CASE.size.x - 60.0, 0)
	box.add_theme_constant_override("separation", 5)
	_case.add_child(box)
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

	# One row for the switch of the book and for the number of characters,
	# which only shows while they are drawn at random: the row keeps its
	# height without it, or everything under it would move up.
	var options := HBoxContainer.new()
	options.add_theme_constant_override("separation", 10)
	options.custom_minimum_size = Vector2(0, 26)
	box.add_child(options)
	var book_tip := "Gives every player a book at the table to note down who they think holds each card: filled in by hand, or by the book itself."
	var book_label := UI.label("Suspicion book", 14, UI.CREAM)
	book_label.mouse_filter = Control.MOUSE_FILTER_PASS
	TipLayer.attach(book_label, book_tip)
	options.add_child(book_label)
	_book_switch = Button.new()
	_book_switch.toggle_mode = true
	_book_switch.focus_mode = Control.FOCUS_NONE
	_book_switch.custom_minimum_size = SWITCH
	_book_switch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		_book_switch.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_book_switch.draw.connect(_draw_book_switch)
	_book_switch.mouse_entered.connect(_book_switch.queue_redraw)
	_book_switch.mouse_exited.connect(_book_switch.queue_redraw)
	_book_switch.toggled.connect(func(on: bool) -> void:
		_config.suspect_book = on
		_refresh())
	TipLayer.attach(_book_switch, book_tip)
	options.add_child(_book_switch)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(24, 0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	options.add_child(gap)
	_count_row = _stepper("How many characters", "", func(): return _config.character_count,
			func(v): _config.character_count = v, 3, Content.characters.size())
	_count_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Next to its buttons, not adrift in the middle of the row.
	(_count_row.get_child(0) as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	options.add_child(_count_row)
	options.custom_minimum_size.y = _count_row.get_combined_minimum_size().y

	# One row while the cast fits in it, two rows of smaller cards after that.
	var defs := Content.character_list()
	var rows := 1 if defs.size() <= GRID_ROW else 2
	var per_row := ceili(defs.size() / float(rows))
	var card_scale := 1.15 if rows == 1 else 0.9
	var card_height := CardView.BASE.y * card_scale
	var row_height := card_height + 16.0
	var step := GRID_WIDTH / per_row
	var grid := Control.new()
	grid.custom_minimum_size = Vector2(GRID_WIDTH, rows * row_height + 2.0)
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
		var caption := UI.label(def.display_name, 11, UI.CREAM.darkened(0.15))
		# Clipping comes before the size: until then the label refuses to be
		# narrower than its text, and a long name would be centred in a wider box.
		caption.clip_text = true
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.position = Vector2(column * step, top + card_height + 1.0)
		caption.size = Vector2(step, 16)
		grid.add_child(caption)

	box.add_child(_stepper("Copies of each character", "More copies make every claim more believable.",
			func(): return maxi(_config.copies_per_character, _min_copies()),
			func(v): _config.copies_per_character = v, 2, 6))
	# Held a little above its own line, clear of the ridge of the case.
	var foot := Control.new()
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_summary = UI.label("", 13, UI.CREAM.darkened(0.25))
	_summary.position = Vector2(0, -SUMMARY_RISE)
	foot.custom_minimum_size = Vector2(0, _summary.get_combined_minimum_size().y - SUMMARY_RISE)
	foot.add_child(_summary)
	box.add_child(foot)
	_build_items()



## The items lie in the lower compartment of the case.
func _build_items() -> void:
	var title := UI.label("ITEMS IN THE SHOP", 18, UI.GOLD, true)
	title.position = Vector2(30, CASE_RIDGE + 7.0)
	title.size = Vector2(400, 24)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_case.add_child(title)
	var reset := _reset_button(_reset_items, _items_default)
	reset.position = Vector2(CASE.size.x - 60.0, CASE_RIDGE + 7.0)
	reset.size = Vector2(30, 26)
	_case.add_child(reset)
	var defs := Content.item_list()
	var step := (CASE.size.x - 60.0) / maxi(defs.size(), 1)
	for i in defs.size():
		var def: ItemDef = defs[i]
		var view := ItemView.new(0.88)
		view.position = Vector2(roundf(30.0 + i * step + (step - view.size.x) / 2.0), CASE_ITEMS)
		view.set_item(def)
		_case.add_child(view)
		_item_places.append(Rect2(view.position, view.size).grow(3.0))
		if def.fixed:
			# Part of every match: on sale outside the slots, nothing to toggle.
			view.note = "Always on sale, outside the shop slots. Can't be banned."
			view.clicked.connect(_refuse.bind(view))
			continue
		if _host:
			view.note = "Click to allow or ban it."
			view.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			view.clicked.connect(func():
				_items_on[def.id] = not _items_on[def.id]
				_refresh())
		_item_views[def.id] = view
	# Only the items lie in hollows of the foam: round the cards they read
	# as dark frames, and the user had them taken out.
	_case.sockets = _item_places


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
	var paper := _on_paper
	var l := UI.label(text, 18 if big else 14, UI.GOLD if big else UI.CREAM, big)
	if paper:
		Desk.ink(l)
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
	if paper:
		Desk.ink(value, Desk.INK_RED)
	for b: Button in [minus, plus]:
		if paper:
			b.custom_minimum_size.y = 24
			Desk.penned(b)
		else:
			Desk.velvet(b)
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
		row.tag.text = "BOT" if seat.bot else ("YOU" if seat.peer == me else ("HOST" if seat.peer == 1 else ""))
		row.tag.add_theme_color_override("font_color", Desk.INK_RED if seat.peer == me else Desk.INK_FADED)
		row.remove.visible = _host and seat.bot


func _redraw() -> void:
	for refresher: Callable in _refreshers:
		refresher.call()
	_redraw_seats()
	_style_toggle(_mode_random, _random)
	_style_toggle(_mode_picked, not _random)
	_count_row.visible = _random
	_book_switch.set_pressed_no_signal(_config.suspect_book)
	_book_switch.disabled = not _host
	_book_switch.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _host else Control.CURSOR_ARROW
	_slide_book_knob()
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


func _slide_book_knob() -> void:
	var to := 1.0 if _config.suspect_book else 0.0
	if is_equal_approx(_book_knob, to) or (_book_tween != null and _book_tween.is_running()):
		return
	_book_tween = create_tween()
	_book_tween.tween_method(_set_book_knob, _book_knob, to, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# The room may have changed its mind while the knob was on its way.
	_book_tween.tween_callback(_slide_book_knob)


func _set_book_knob(at: float) -> void:
	_book_knob = at
	_book_switch.queue_redraw()


## A switch for the velvet of the case: a groove in a red almost black,
## rimmed in gold thread, and a round gold knob that slides across it.
func _draw_book_switch() -> void:
	var b := _book_switch
	var on := _config.suspect_book
	var rim := UI.GOLD if on or (b.is_hovered() and _host) else Desk.BRASS
	var groove := Desk.VELVET_DEEP.lerp(Desk.VELVET_LIGHT, 0.55 * _book_knob)
	for layer in 2:
		var inset := 2.0 * layer
		var ink := rim if layer == 0 else groove
		b.draw_rect(Rect2(inset + 4.0, inset, SWITCH.x - inset * 2.0 - 8.0, SWITCH.y - inset * 2.0), ink)
		b.draw_rect(Rect2(inset + 2.0, inset + 2.0, SWITCH.x - inset * 2.0 - 4.0, SWITCH.y - inset * 2.0 - 4.0), ink)
		b.draw_rect(Rect2(inset, inset + 4.0, SWITCH.x - inset * 2.0, SWITCH.y - inset * 2.0 - 8.0), ink)
	var metal := Desk.BRASS_DARK.lerp(UI.GOLD, _book_knob)
	var at := Vector2(roundf(lerpf(4.0, SWITCH.x - 18.0, _book_knob) / 2.0) * 2.0, 4.0)
	for y in KNOB.size():
		for x in KNOB[y].length():
			var bit := KNOB[y][x]
			if bit != ".":
				var ink := metal.lightened(0.45) if bit == "o" else metal.darkened(0.3) if bit == "x" else metal
				b.draw_rect(Rect2(at + Vector2(x, y) * 2.0, Vector2(2, 2)), ink)


func _style_toggle(b: Button, on: bool) -> void:
	Desk.velvet(b, on)


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
	Transition.go(ROOM_SCENE, Transition.DESK)


func _unhandled_key_input(event: InputEvent) -> void:
	UI.handle_fullscreen_key(event, get_window())
