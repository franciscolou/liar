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
const TouchMode := preload("res://scripts/ui/touch_mode.gd")
const ROOM_SCENE := "res://scenes/room.tscn"
## Width of the character grid, and the most cards it shows in a single row.
const GRID_WIDTH := 664.0
const GRID_ROW := 10
const ANIM_SPEEDS := [50, 75, 100, 150, 200, 250, 300]  # percent
## The seconds a turn may be given (GameConfig.turn_seconds), 0 for no clock,
## and how each is written.
const TURN_TIMES := [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60]
## No limit is the sign of infinity, drawn in blocks: the font has none.
const INFINITY: Array[String] = [
	".###...###.",
	"#...#.#...#",
	"#....#....#",
	"#...#.#...#",
	".###...###.",
]
const TURN_TIME_NAMES := [INFINITY, "5 s", "10 s", "15 s", "20 s", "25 s", "30 s", "35 s", "40 s", "45 s", "50 s", "55 s", "60 s"]
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
## The gap between the items that are always on sale and the others, in
## item places.
const ITEMS_PARTING := 0.5
## The switch of the book of suspicions: its size, and its knob in blocks.
const SWITCH := Vector2(42, 22)
## Touch mode: the switch is drawn this much bigger, and the small buttons of
## the sheet and the case get at least this much room for a finger.
const TOUCH_SWITCH := 1.6
const TOUCH_STEP_BUTTON := Vector2(48, 36)
## Touch mode: the case has no more height for the bigger rows, so the cards
## of a cast in two rows are smaller, with room for bigger names under them.
const TOUCH_GRID_SCALE := 0.74
const TOUCH_CAPTION := 22.0
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
## How high and how low the top of the open sheet may be dragged, and how far
## the mouse has to go before a press on its title is a drag and not a click.
const FILE_REACH := Vector2(60, 540)
const FILE_GRIP := 4.0
## How much of the top of the sheet it is held by: the strip and the title.
const FILE_BAND := 38.0
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
var _draw_row: Control  # how many of the hand-picked ones are drawn
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
var _file_box: VBoxContainer  # what is written on it
var _desk: Desk
var _things: Array = []
var _case: Desk
var _item_places: Array[Rect2] = []
var _file_tween: Tween
var _file_rest := Vector2(-1, -1)  # where its top was last put, and how tall
## How far the player has dragged the open sheet from where it lies by
## itself. Only this screen knows: the room never hears of it.
var _file_pull := 0.0
var _file_grip: Control  # the strip above the title, to hold it by
var _file_hint := 0.0  # how much of the grip marks shows: 0 = none, 1 = all
var _file_hint_tween: Tween
var _file_held := false
var _file_dragged := false
var _file_grab := 0.0  # where the mouse took hold of it, less the pull it had
## True while the widgets being built go on paper, not on felt.
var _on_paper := false


func _ready() -> void:
	Settings.ensure_loaded()
	theme = UI.theme()
	Jukebox.play(Jukebox.LOBBY)
	var touch := TouchMode.node()
	if touch != null:
		touch.held.connect(_on_held)
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
	back.size = UI.grown(Vector2(170, 46))
	back.position = Vector2(20, 636 - back.size.y)
	Desk.brass(back)
	back.pressed.connect(_on_leave)
	if _host:
		TipLayer.attach(back, "Leaves the room, which passes to another player.")
	add_child(back)
	# Between the plaque and the case there is no more room in touch mode:
	# the word keeps its size.
	var settings: Button = UI.native(func() -> Button: return UI.button("SETTINGS", UI.BORDER, 15))
	settings.position = Vector2(264, 8)
	settings.size = Vector2(132, 46)
	Desk.brass(settings)
	settings.pressed.connect(func(): add_child(SettingsPanel.new()))
	add_child(settings)
	_start = UI.button("DEAL THE CARDS", UI.BORDER, 22)
	_start.size = UI.grown(Vector2(260, 46))
	_start.position = Vector2(1132 - _start.size.x, 636 - _start.size.y)
	Desk.brass(_start, true)
	_start.pressed.connect(_on_start)
	_start.visible = _host
	add_child(_start)
	_problem = UI.label("", 14, UI.RED.lightened(0.25))
	# In touch mode it shares the foot with the bigger buttons and the slip.
	_problem.size = Vector2(220 if UI.touch else 314, _start.size.y)
	_problem.position = _start.position - Vector2(_problem.size.x + 12.0, 0)
	_problem.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_problem.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_problem.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_problem)
	if not _host:
		var waiting := UI.label("Waiting for the host to deal...", 18, UI.CREAM, true)
		waiting.size = Vector2(400, _start.size.y)
		waiting.position = Vector2(732, _start.position.y)
		waiting.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		waiting.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(waiting)
	_things = Desk.things(self, _desk)
	add_child(Desk.lamplight())
	_room.changed.connect(_on_room_changed)
	# The host left and the room passed to this machine: the screen is the
	# host's now.
	_room.host_changed.connect(func() -> void:
		if _room.hosting != _host:
			get_tree().reload_current_scene())
	_room.reach_checked.connect(_on_reach_checked)
	if not _room.reachable:
		_on_reach_checked(false)
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
	# Beside the button to leave, which is bigger in touch mode.
	var slip: Desk = Desk.make(Desk.Kind.SHEET, Rect2(256, 582, 290, 54) if UI.touch else Rect2(204, 590, 330, 46))
	slip.rotation = -0.012
	slip.dog_ear = false
	slip.tone = Desk.DIM_PAPER
	add_child(slip)
	var line: Label = UI.native(func() -> Label: return Desk.written("Only the host changes the table. You may change your name.", 14, Desk.INK_FADED))
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
	# The slip is no wider in touch mode: the address keeps its size.
	line.add_theme_font_size_override("font_size", roundi(16 * UI.FONT_SCALE) if UI.touch else UI.px(16))
	line.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_write_address()
	if addresses.is_empty():
		return
	line.mouse_filter = Control.MOUSE_FILTER_PASS
	TipLayer.attach(line, func() -> String:
		var tip := Loc.t("What your friends type to join. With Radmin VPN it is the address that starts with 26.")
		if addresses.size() > 1:
			tip += "\n" + Loc.t("This computer also answers at: %s") % ", ".join(addresses.slice(1).map(func(ip: String) -> String: return _room.address_at(ip)))
		return tip + "\n" + Loc.t("If nobody gets in, allow the game through the firewall (UDP port %d).") % _room.port)


## Whether the room could pass to this machine if the host left (see
## Room.reachable): a guest's slip says so when it could not.
func _on_reach_checked(ok: bool) -> void:
	if _host or _address_line == null:
		return
	if ok:
		_address_line.text = "Only the host changes the table. You may change your name."
		Desk.ink(_address_line, Desk.INK_FADED)
		return
	_address_line.text = "If the host leaves, the room cannot pass to you: let the game through the firewall."
	Desk.ink(_address_line, Desk.INK_RED)
	if not _address_line.has_meta("warned"):
		_address_line.set_meta("warned", true)
		_address_line.mouse_filter = Control.MOUSE_FILTER_PASS
		TipLayer.attach(_address_line, func() -> String:
			return Loc.t("The others could not get through to this computer. If the host leaves, the room passes to someone else, or closes.") \
					+ "\n" + Loc.t("In the Windows firewall, allow the game on private and public networks (with Radmin VPN, the network is often public)."))


## The host's line is formatted here, so it does not translate itself.
func _write_address() -> void:
	if not _host:
		return
	var addresses: Array = Room.addresses()
	if addresses.is_empty():
		_address_line.text = Loc.t("This computer has no network address to share.")
	else:
		_address_line.text = Loc.t("ROOM ADDRESS:  %s") % _room.address_at(addresses[0])


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
	_add_bot.custom_minimum_size = Vector2(130, 30) if UI.touch else Vector2(96, 26)
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
		name_edit.text_submitted.connect(func(_text: String): name_edit.release_focus())
		row.add_child(name_edit)
		var tag := Desk.written("", 14, Desk.INK_FADED, true)
		tag.custom_minimum_size = Vector2(58, 0)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(tag)
		var remove := UI.button("X", UI.BORDER, 13)
		remove.custom_minimum_size = Vector2(44, 24) if UI.touch else Vector2(30, 22)
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
	_file_box = box
	_file_grip = Control.new()
	_file_grip.size = Vector2(_file.size.x, 10)
	_file_grip.mouse_default_cursor_shape = Control.CURSOR_VSIZE
	_file_grip.gui_input.connect(_on_file_held.bind(false))
	_file_grip.draw.connect(_draw_file_grip)
	_file_grip.mouse_entered.connect(_hint_file.bind(true))
	_file_grip.mouse_exited.connect(_hint_file.bind(false))
	_file.add_child(_file_grip)
	box.add_child(_rules_header())
	_rules = VBoxContainer.new()
	_rules.add_theme_constant_override("separation", 0)
	box.add_child(_rules)
	_rules.add_child(_stepper("Starting Morale", "Lose it all and you are out.",
			func(): return _config.start_morale, func(v): _config.start_morale = v, 1, 5))
	_rules.add_child(_stepper("Starting coins", "",
			func(): return _config.start_coins, func(v): _config.start_coins = v, 0, 10))
	_rules.add_child(_stepper("Income per turn", "",
			func(): return _config.income, func(v): _config.income = v, 0, 5))
	_rules.add_child(_stepper("Cost of a wrong LIAR!", "Coins you lose when you doubt someone who was telling the truth.",
			func(): return _config.doubt_cost, func(v): _config.doubt_cost = v, 0, 6))
	_rules.add_child(_stepper("Reward for a right LIAR!", "Coins you gain when you doubt someone who was lying.",
			func(): return _config.doubt_reward, func(v): _config.doubt_reward = v, 0, 6))
	_rules.add_child(_stepper("Turn timer", "How long each player has for their turn. When it runs out, the turn ends. The clock is the outline round the player's box, and it only runs while the table is waiting for them.",
			_turn_time_index, func(v): _config.turn_seconds = TURN_TIMES[v],
			0, TURN_TIMES.size() - 1, false, 1, "%s", TURN_TIME_NAMES))
	_rules.add_child(_stepper("Shop slots", "",
			func(): return _config.shop_slots, func(v): _config.shop_slots = v, 1, 4))
	_rules.add_child(_stepper("Animation speed", "",
			_anim_speed_index, func(v): _config.anim_speed = ANIM_SPEEDS[v] / 100.0,
			0, ANIM_SPEEDS.size() - 1, false, 1, "%d%%", ANIM_SPEEDS))
	_reader = RichTextLabel.new()
	_reader.bbcode_enabled = true
	_reader.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_reader.add_theme_color_override("default_color", Desk.INK)
	_reader.add_theme_font_size_override("normal_font_size", UI.grow(15))
	_reader.add_theme_font_size_override("bold_font_size", UI.grow(15))
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


## Open, the rules lie under the clipboard, and the player may drag the sheet
## up and down by its top (_file_pull). Folded away, the sheet is pulled up
## over the lines nobody signed, so there is more of it to read.
func _place_file(at_once := false) -> void:
	var top := _file_home()
	var rest := Vector2(top, FILE_FOOT - top)
	if _rules_open:
		# The whole sheet goes with the hand: it keeps its height.
		_file_pull = clampf(top + _file_pull, FILE_REACH.x, maxf(FILE_REACH.y, top)) - top
		rest.x = top + _file_pull
	if rest == _file_rest:
		return
	at_once = at_once or _file_rest.x < 0.0
	_file_rest = rest
	if _file_tween != null:
		_file_tween.kill()
	if at_once:
		_file.position.y = rest.x
		_file.size.y = rest.y
		return
	_file_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_file_tween.tween_property(_file, "position:y", rest.x, 0.18)
	_file_tween.tween_property(_file, "size:y", rest.y, 0.18)


## Where the top of the sheet lies when nobody has moved it.
func _file_home() -> float:
	if _rules_open:
		# As far up as the rules need, and no further: the sheet lies over
		# the foot of the clipboard.
		return minf(FILE_TOP, FILE_FOOT - _file_box.get_combined_minimum_size().y - 20.0)
	return minf(FILE_TOP, CLIPBOARD.position.y + SEAT_LINES + _room.seats.size() * SEAT_STEP + 8.0)


## The mouse is on the top of the open sheet, or has left it: a few grip
## marks fade in at the edge, to say that it can be taken from there.
func _hint_file(on: bool) -> void:
	if _file_hint_tween != null:
		_file_hint_tween.kill()
	_file_hint_tween = create_tween()
	_file_hint_tween.tween_method(func(amount: float):
		_file_hint = amount
		_file_grip.queue_redraw(), _file_hint, 1.0 if on or _file_held else 0.0, 0.15)


## The whole top band of the sheet, title and all, takes a light wash of
## ink, with two short rows of dots in the middle of the top edge. (The dots
## alone were too faint to notice.)
func _draw_file_grip() -> void:
	if _file_hint <= 0.0:
		return
	_file_grip.draw_rect(Rect2(2, 2, _file_grip.size.x - 4.0, FILE_BAND - 2.0), Color(Desk.INK, 0.12 * _file_hint))
	var ink := Color(Desk.INK, 0.55 * _file_hint)
	var left := roundf(_file_grip.size.x / 2.0) - 13.0
	for row in 2:
		for dot in 7:
			_file_grip.draw_rect(Rect2(left + dot * 4.0, 3.0 + row * 4.0, 2, 2), ink)


## The mouse on the top of the sheet: the open sheet is dragged up and down
## by it. A press that goes nowhere is a click, which `folds` says whether to
## answer by folding the rules (the title) or not (the strip above it).
func _on_file_held(event: InputEvent, folds: bool) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_file_held = true
			_file_dragged = false
			_file_grab = event.global_position.y - _file_pull
		elif _file_held:
			_file_held = false
			var at: Vector2 = _file.get_local_mouse_position()
			_hint_file(_rules_open and Rect2(0, 0, _file.size.x, FILE_BAND).has_point(at))
			if folds and not _file_dragged:
				_set_rules_open(not _rules_open)
	elif event is InputEventMouseMotion and _file_held and _rules_open:
		var pull: float = event.global_position.y - _file_grab
		if not _file_dragged and absf(pull - _file_pull) < FILE_GRIP:
			return
		if not _file_dragged and TipLayer.current != null:
			TipLayer.current.hide_all()
		_file_dragged = true
		_file_pull = pull
		_place_file(true)
		# Clamped: the hand does not run ahead of the sheet.
		_file_grab = event.global_position.y - _file_pull if pull != _file_pull else _file_grab


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
	row.mouse_entered.connect(func():
		title.add_theme_color_override("font_color", Desk.INK_RED)
		_hint_file(true))
	row.mouse_exited.connect(func():
		title.add_theme_color_override("font_color", Desk.INK)
		_hint_file(false))
	row.gui_input.connect(_on_file_held.bind(true))
	TipLayer.attach(row, func() -> String:
		return "" if _rules_open else Loc.t("Click to show the rules."))
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


## A finger held on a card does what a right click does.
func _on_held(control: Control) -> void:
	for id: StringName in _cards:
		if _cards[id] == control:
			_read_character(id, true)
			return


func _on_card_input(event: InputEvent, character_id: StringName) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_read_character(character_id, true)


func _redraw_reader() -> void:
	_rules.visible = _rules_open
	_rules_arrow.queue_redraw()
	_file_grip.visible = _rules_open
	_reader.visible = not _rules_open
	_ghosts.visible = not _rules_open
	_place_file()
	var def := Content.character(_read) if _read != &"" else null
	var text := "[color=%s]%s[/color]" % [UI.hex(UI.MUTED), Loc.t("Tap a character to read its abilities here." if UI.touch else "Hover a character to read its abilities here.")]
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
	_mode_random.custom_minimum_size = Vector2(148, 36) if UI.touch else Vector2(110, 32)
	_mode_random.pressed.connect(_set_random.bind(true))
	TipLayer.attach(_mode_random, "Draw the characters of the match at random.")
	head.add_child(_mode_random)
	_mode_picked = UI.button("Hand-picked", UI.BORDER, 15)
	_mode_picked.custom_minimum_size = Vector2(172, 36) if UI.touch else Vector2(130, 32)
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
	_book_switch.custom_minimum_size = SWITCH * (TOUCH_SWITCH if UI.touch else 1.0)
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
	# Hand-picked, the same place says how many of the chosen ones are drawn:
	# all of them, unless the host wants the match to hide which.
	_draw_row = _stepper("Quantos personagens", "How many of the characters you picked are in the match, drawn at random. Nobody knows which until they show up.",
			_drawn_count, func(v): _config.pool_draw = 0 if v >= _picked.size() else v,
			3, func() -> int: return maxi(_picked.size(), 3))
	_draw_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(_draw_row.get_child(0) as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	options.add_child(_draw_row)
	options.custom_minimum_size.y = _count_row.get_combined_minimum_size().y

	# One row while the cast fits in it, two rows of smaller cards after that.
	var defs := Content.character_list()
	var rows := 1 if defs.size() <= GRID_ROW else 2
	var per_row := ceili(defs.size() / float(rows))
	var card_scale := 1.15 if rows == 1 else TOUCH_GRID_SCALE if UI.touch else 0.9
	var card_height := CardView.BASE.y * card_scale
	var caption_height := TOUCH_CAPTION if UI.touch else 16.0
	var row_height := card_height + caption_height
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
		if UI.touch:
			# No hover: a tap reads the character too.
			card.clicked.connect(_read_character.bind(def.id, false))
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
		caption.size = Vector2(step, caption_height)
		grid.add_child(caption)

	box.add_child(_stepper("Copies of each character", "More copies make every claim more believable.",
			func(): return maxi(_config.copies_per_character, _min_copies()),
			func(v): _config.copies_per_character = v, 2, 6))
	# Held a little above its own line, clear of the ridge of the case.
	var foot := Control.new()
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Over the ridge there is no room for it to grow in touch mode.
	_summary = UI.native(func() -> Label: return UI.label("", 13, UI.CREAM.darkened(0.25)))
	_summary.position = Vector2(0, -SUMMARY_RISE)
	foot.custom_minimum_size = Vector2(0, _summary.get_combined_minimum_size().y - SUMMARY_RISE)
	foot.add_child(_summary)
	box.add_child(foot)
	_build_items()



## The items lie in the lower compartment of the case.
func _build_items() -> void:
	# What is on sale in every match comes first, parted from what the host
	# can ban, as in the shop of the table.
	var defs := Content.item_list()
	var fixed := defs.filter(func(def: ItemDef) -> bool: return def.fixed)
	defs = fixed + defs.filter(func(def: ItemDef) -> bool: return not def.fixed)
	var parted := not fixed.is_empty() and fixed.size() < defs.size()
	var step := (CASE.size.x - 60.0) / maxf(defs.size() + (ITEMS_PARTING if parted else 0.0), 1.0)
	var lead := roundf((fixed.size() + ITEMS_PARTING) * step) if parted else 0.0
	if parted:
		var divider := ColorRect.new()
		divider.color = Color(UI.GOLD.darkened(0.35), 0.7)
		divider.position = Vector2(roundf(30.0 + lead - ITEMS_PARTING * step / 2.0) - 1.0, CASE_ITEMS - 3.0)
		divider.size = Vector2(2, roundf(ItemView.BASE.y * 0.88) + 6.0)
		divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_case.add_child(divider)
	var title := UI.label("ITEMS IN THE SHOP", 18, UI.GOLD, true)
	title.position = Vector2(30, CASE_RIDGE + 7.0)
	title.size = Vector2(400, 24)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_case.add_child(title)
	var reset := _reset_button(_reset_items, _items_default)
	reset.position = Vector2(CASE.size.x - 60.0, CASE_RIDGE + 7.0)
	reset.size = Vector2(30, 26)
	_case.add_child(reset)
	for i in defs.size():
		var def: ItemDef = defs[i]
		var view := ItemView.new(0.88)
		var slot := i + (ITEMS_PARTING if parted and not def.fixed else 0.0)
		view.position = Vector2(roundf(30.0 + slot * step + (step - view.size.x) / 2.0), CASE_ITEMS)
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


## Position in TURN_TIMES of the time closest to the configured one.
func _turn_time_index() -> int:
	var best := 0
	for i in TURN_TIMES.size():
		if absi(TURN_TIMES[i] - _config.turn_seconds) < absi(TURN_TIMES[best] - _config.turn_seconds):
			best = i
	return best


## How many of the hand-picked characters are drawn for the match.
func _drawn_count() -> int:
	return _config.pool_draw if _config.pool_draw > 0 and _config.pool_draw < _picked.size() else _picked.size()


## A labelled "- value +" row bound to a getter and a setter. With `shown`,
## the value is an index into it and the entry is what gets displayed: a text,
## or a bitmap of text rows to draw in its place (INFINITY). `high` is the top
## of the range, or a Callable that says what it is right now.
func _stepper(text: String, tip: String, getter: Callable, setter: Callable, low: int, high: Variant, big := false, step := 1, format := "%d", shown: Array = []) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var paper := _on_paper
	# The sheet of house rules is no wider in touch mode: there the words keep
	# their size, and a long one wraps.
	var narrow := paper and UI.touch
	var l: Label = UI.native(func() -> Label: return UI.label(text, 18 if big else 14, UI.GOLD if big else UI.CREAM, big)) if narrow \
			else UI.label(text, 18 if big else 14, UI.GOLD if big else UI.CREAM, big)
	if narrow:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 120
	if paper:
		Desk.ink(l)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	if tip != "":
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		TipLayer.attach(l, tip)
	var minus := UI.button("-", UI.BORDER, 15)
	minus.custom_minimum_size = TOUCH_STEP_BUTTON if UI.touch else Vector2(34, 26)
	var value := UI.label("", 16, UI.GOLD, true)
	value.custom_minimum_size = Vector2(40 if narrow else 52, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var plus := UI.button("+", UI.BORDER, 15)
	plus.custom_minimum_size = TOUCH_STEP_BUTTON if UI.touch else Vector2(34, 26)
	if paper:
		Desk.ink(value, Desk.INK_RED)
	for b: Button in [minus, plus]:
		if paper:
			b.custom_minimum_size = Vector2(40, 34) if narrow else Vector2(b.custom_minimum_size.x, 24)
			Desk.penned(b)
		else:
			Desk.velvet(b)
	row.add_child(minus)
	row.add_child(value)
	row.add_child(plus)
	var top := func() -> int: return high.call() if high is Callable else high
	var change := func(delta: int):
		setter.call(clampi(getter.call() + delta, low, top.call()))
		UI.pop(value, 1.4, 0.2)
		_refresh()
	minus.pressed.connect(change.bind(-step))
	plus.pressed.connect(change.bind(step))
	var ink := Desk.INK_RED if paper else UI.GOLD
	value.draw.connect(func():
		if value.has_meta(&"bits"):
			_draw_bits(value, value.get_meta(&"bits"), ink))
	_refreshers.append(func():
		var current: int = getter.call()
		var entry: Variant = current if shown.is_empty() else shown[current]
		if entry is Array:
			value.text = ""
			value.set_meta(&"bits", entry)
		else:
			value.text = format % entry
			value.remove_meta(&"bits")
		value.queue_redraw()
		minus.disabled = not _host or current <= low
		plus.disabled = not _host or current >= top.call())
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
	return _config.character_count if _random else _drawn_count()


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
	# Drawing all of them is no draw at all.
	if _random or _config.pool_draw >= _picked.size():
		_config.pool_draw = 0
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
		# Nobody writes a name but their own.
		var mine: bool = not seat.bot and seat.peer == me
		edit.editable = mine
		edit.focus_mode = Control.FOCUS_ALL if mine else Control.FOCUS_NONE
		edit.mouse_filter = Control.MOUSE_FILTER_STOP if mine else Control.MOUSE_FILTER_IGNORE
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
	_draw_row.visible = not _random
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
	_summary.text = Loc.t("%s  |  Deck of %d cards (%d characters x %d copies) | %d dealt") % [
		Loc.t("%d drawn at random") % count if _random else (Loc.t("%d hand-picked") % count if count >= _picked.size()
				else Loc.t("%d drawn from %d hand-picked") % [count, _picked.size()]),
		count * copies, count, copies, _room.seats.size() * mini(_config.hand_size, _config.start_morale)]
	var problem := ""
	if count < 3 or (not _random and _picked.size() < 3):
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
	if UI.touch:
		b.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * TOUCH_SWITCH)
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
	b.custom_minimum_size = Vector2(42, 36) if UI.touch else Vector2(30, 26)
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
			and _config.doubt_reward == base.doubt_reward
			and _config.turn_seconds == base.turn_seconds
			and _config.shop_slots == base.shop_slots
			and is_equal_approx(_config.anim_speed, base.anim_speed))


func _reset_rules() -> void:
	var base := GameConfig.new()
	_config.start_morale = base.start_morale
	_config.start_coins = base.start_coins
	_config.income = base.income
	_config.doubt_cost = base.doubt_cost
	_config.doubt_reward = base.doubt_reward
	_config.turn_seconds = base.turn_seconds
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
	_config.pool_draw = 0
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


## A click anywhere but on the name being written, or Esc, puts the pen down.
func _input(event: InputEvent) -> void:
	var clicked: bool = event is InputEventMouseButton and event.pressed
	if not clicked and not event.is_action_pressed(&"ui_cancel"):
		return
	for row: Dictionary in _seat_rows:
		var edit: LineEdit = row.name
		if edit.has_focus() and not (clicked and edit.get_global_rect().has_point(event.global_position)):
			edit.release_focus()


func _unhandled_key_input(event: InputEvent) -> void:
	UI.handle_fullscreen_key(event, get_window())
