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
const Sounds := preload("res://scripts/ui/sounds.gd")
const LogView := preload("res://scripts/ui/log_view.gd")
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
## Touch mode: the characters are big cards, this many to a row, in a column
## the finger scrolls (the next row peeks out under the first).
const TOUCH_CARDS_PER_ROW := 3
const TOUCH_CARD_GAP := 22.0
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

## Touch mode: a phone has no room for everything at once, so the whole
## screen is one big case, its sections behind tabs. All of these are in the
## case's own coordinates. The lid carries the title on the maker's plate,
## the way out and the settings on the left and dealing on the right.
const TOUCH_CASE := Rect2(4, -12, 1144, 660)
const TOUCH_LID_MIDDLE := 56.0
const TOUCH_PLAQUE := Rect2(454, 25, 236, 62)
## The tabs stand on a ridge at the top of the well; each page is under it,
## in two halves.
const TOUCH_TABS := Rect2(34, 128, 1076, 48)
const TOUCH_TAB_GAP := 8.0
const TOUCH_LEFT := Rect2(34, 192, 528, 418)
const TOUCH_RIGHT := Rect2(582, 192, 528, 418)
## The lines of the clipboard are further apart under a finger.
const TOUCH_SEAT_STEP := 32.0
## The items page: hollows four to a row, the ones always on sale on a row
## of their own above a ridge.
const TOUCH_ITEM_SCALE := 1.2
const TOUCH_ITEM_COLUMNS := 4
const TOUCH_ITEM_ROW := 120.0
## The picture of the item being read, clipped to its sheet.
const TOUCH_ITEM_PHOTO := 2.0
## The pages, in the order of their tabs.
const TOUCH_PAGES := ["CHARACTERS", "ITEMS", "PLAYERS AND RULES"]

## Whether the house rules are unfolded. Folded away, their place is where
## the abilities of the characters are read. It is kept for the next time
## this screen opens (back from a match).
static var _rules_open := false
## Touch mode: the page that is open, kept the same way.
static var _page := 0

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
## A press on a character card, held (desktop): the button, the card it began
## on, and whether it has moved on to other cards (a sweep: the left button
## puts every card it passes in the match, the right one takes them out).
var _sweep_button := MOUSE_BUTTON_NONE
var _sweep_from: StringName = &""
var _sweeping := false
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
## From one line of the clipboard to the next.
var _seat_step := SEAT_STEP
## Touch mode: the tabs, the pages under them, and what the case shows in
## its well for each page ({sockets, ridges}).
var _tabs: Array[Button] = []
var _pages: Array[Control] = []
var _page_looks: Array[Dictionary] = []
## Touch mode: the items page reads an item the way the characters page
## reads a character.
var _item_cells: Dictionary = {}  # item id -> ItemView, the fixed ones too
var _item_read: StringName
var _item_title: Label
var _item_photo: TextureRect
var _item_head: Control
var _item_name: Label
var _item_kind: Label
var _item_price: Label
var _item_state: Label
var _item_text: RichTextLabel
## The rows are being given to other people (someone came or went): a name
## line losing the cursor then is not the player leaving it.
var _seats_moving := false


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
	if not UI.touch:
		_desk.props = [{"kind": &"ring", "at": Vector2(700, 610)}]
	add_child(_desk)
	add_child(TipLayer.new())
	if UI.touch:
		_build_touch()
	else:
		_build_desktop()
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


## The desk with everything lying on it, for a mouse.
func _build_desktop() -> void:
	# The top right belongs to the lid of the case: the title and the
	# settings share the left.
	var plaque: Desk = Desk.make(Desk.Kind.PLAQUE, Rect2(20, 8, 236, 46))
	add_child(plaque)
	plaque.add_child(_plaque_title())

	_build_address(self, Rect2(204, 590, 330, 46))
	_build_players(self, CLIPBOARD)
	_build_rules()
	_build_case()

	var made := _build_buttons(self)
	var back: Button = made.back
	back.position = Vector2(20, 636 - back.size.y)
	var settings: Button = made.settings
	settings.position = Vector2(264, 8)
	_start.position = Vector2(1132 - _start.size.x, 636 - _start.size.y)
	_problem.size = Vector2(314, _start.size.y)
	_problem.position = _start.position - Vector2(_problem.size.x + 12.0, 0)
	if made.waiting != null:
		var waiting: Label = made.waiting
		waiting.size = Vector2(400, _start.size.y)
		waiting.position = Vector2(732, _start.position.y)


func _plaque_title() -> Label:
	var title := Desk.written("SET THE TABLE", 24, UI.INK, true)
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return title


## The way out, the settings, dealing the cards and why they can't be dealt
## yet, on `parent`; the caller puts them in their places.
func _build_buttons(parent: Control) -> Dictionary:
	var back := UI.button("LEAVE ROOM", UI.BORDER, 20)
	back.size = UI.grown(Vector2(170, 46))
	Desk.brass(back)
	back.pressed.connect(_on_leave)
	if _host:
		TipLayer.attach(back, "Leaves the room, which passes to another player.")
	parent.add_child(back)
	var settings := UI.button("SETTINGS", UI.BORDER, 15)
	settings.size = UI.grown(Vector2(132, 46))
	Desk.brass(settings)
	settings.pressed.connect(func(): add_child(SettingsPanel.new()))
	parent.add_child(settings)
	_start = UI.button("DEAL THE CARDS", UI.BORDER, 22)
	_start.size = UI.grown(Vector2(260, 46))
	Desk.brass(_start, true)
	_start.pressed.connect(_on_start)
	_start.visible = _host
	parent.add_child(_start)
	_problem = UI.label("", 13 if UI.touch else 14, UI.RED.lightened(0.25))
	_problem.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_problem.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_problem.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(_problem)
	var waiting: Label = null
	if not _host:
		waiting = UI.label("Waiting for the host to deal...", 18, UI.CREAM, true)
		waiting.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		waiting.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		parent.add_child(waiting)
	return {"back": back, "settings": settings, "waiting": waiting}


## Touch mode: one big case over the whole screen. The lid holds the title
## and the buttons, and the well three pages behind tabs: the characters
## with the file of the one being read, the items with the file of theirs,
## and the clipboard of players beside the house rules.
func _build_touch() -> void:
	_case = Desk.make(Desk.Kind.CASE, TOUCH_CASE)
	add_child(_case)
	var plaque: Desk = Desk.make(Desk.Kind.PLAQUE, TOUCH_PLAQUE)
	_case.add_child(plaque)
	plaque.add_child(_plaque_title())
	var made := _build_buttons(_case)
	var back: Button = made.back
	back.position = Vector2(26, roundf(TOUCH_LID_MIDDLE - back.size.y / 2.0))
	var settings: Button = made.settings
	settings.position = Vector2(back.position.x + back.size.x + 10.0, roundf(TOUCH_LID_MIDDLE - settings.size.y / 2.0))
	_start.position = Vector2(TOUCH_CASE.size.x - 26.0 - _start.size.x, roundf(TOUCH_LID_MIDDLE - _start.size.y / 2.0))
	if made.waiting != null:
		var waiting: Label = made.waiting
		waiting.size = Vector2(400, _start.size.y)
		waiting.position = Vector2(_start.position.x + _start.size.x - waiting.size.x, _start.position.y)

	# The tabs, and why the cards can't be dealt yet at the end of their row.
	# A row that lays itself out: a tab is only as wide as its text once the
	# text is translated, which happens after it is built.
	var row := HBoxContainer.new()
	row.position = TOUCH_TABS.position
	row.size = TOUCH_TABS.size
	row.add_theme_constant_override("separation", int(TOUCH_TAB_GAP))
	_case.add_child(row)
	for index in TOUCH_PAGES.size():
		var tab := _tab_button(TOUCH_PAGES[index], index)
		row.add_child(tab)
		_tabs.append(tab)
	_problem.get_parent().remove_child(_problem)
	_problem.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_problem.custom_minimum_size = Vector2(120, TOUCH_TABS.size.y)
	row.add_child(_problem)

	for index in TOUCH_PAGES.size():
		var page := Control.new()
		page.mouse_filter = Control.MOUSE_FILTER_IGNORE
		page.size = TOUCH_CASE.size
		_case.add_child(page)
		_pages.append(page)
		_page_looks.append({"sockets": [] as Array[Rect2], "ridges": [TOUCH_TABS.end.y] as Array[float]})
	_build_touch_characters(_pages[0])
	_build_touch_items(_pages[1])
	_build_address(_pages[2], Rect2(TOUCH_LEFT.position.x, TOUCH_LEFT.end.y - 50.0, TOUCH_LEFT.size.x, 50))
	_build_players(_pages[2], Rect2(TOUCH_LEFT.position, Vector2(TOUCH_LEFT.size.x, TOUCH_LEFT.size.y - 60.0)))
	_build_touch_rules(_pages[2], TOUCH_RIGHT)
	_show_page(_page)


## A tab of the case: a flap of the lining rimmed in gold thread. The open
## one is lit and runs down over the ridge into its page.
func _tab_button(text: String, index: int) -> Button:
	var tab := Button.new()
	tab.text = text
	tab.focus_mode = Control.FOCUS_NONE
	tab.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tab.add_theme_font_override("font", UI.bold())
	tab.add_theme_font_size_override("font_size", UI.px(17))
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var box := StyleBoxEmpty.new()
		box.content_margin_left = 24
		box.content_margin_right = 24
		tab.add_theme_stylebox_override(state, box)
	tab.custom_minimum_size = Vector2(150, TOUCH_TABS.size.y)
	var back := Control.new()
	back.show_behind_parent = true
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# As wide as the tab turns out to be, whatever its text says.
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.draw.connect(_draw_tab.bind(back, index))
	tab.add_child(back)
	tab.pressed.connect(_show_page.bind(index))
	return tab


func _draw_tab(back: Control, index: int) -> void:
	var on := index == _page
	var w := back.size.x
	# The open one hangs down over the ridge, into the page.
	var h := back.size.y + (8.0 if on else 0.0)
	var rim := UI.GOLD if on else Desk.BRASS_DARK
	var fill := Desk.VELVET_LIGHT if on else Desk.VELVET_DEEP
	back.draw_rect(Rect2(4, 0, w - 8.0, 2), rim)
	back.draw_rect(Rect2(2, 2, w - 4.0, 2), rim)
	back.draw_rect(Rect2(0, 4, w, h - 4.0), rim)
	back.draw_rect(Rect2(4, 2, w - 8.0, 2), fill)
	back.draw_rect(Rect2(2, 4, w - 4.0, h - (4.0 if on else 6.0)), fill)
	# The lamp catches the top of the pile, and the shut ones sit in shade.
	back.draw_rect(Rect2(4, 4, w - 8.0, 2), Desk.VELVET_SHEEN if on else Desk.VELVET)
	if not on:
		back.draw_rect(Rect2(2, h - 8.0, w - 4.0, 6), Color(0, 0, 0, 0.3))


func _show_page(index: int) -> void:
	_page = index
	for i in _pages.size():
		_pages[i].visible = i == index
		_tabs[i].add_theme_color_override("font_color", UI.GOLD if i == index else UI.CREAM.darkened(0.3))
		_tabs[i].add_theme_color_override("font_hover_color", UI.GOLD if i == index else UI.CREAM)
		_tabs[i].add_theme_color_override("font_pressed_color", UI.GOLD)
		_tabs[i].get_child(0).queue_redraw()
	_case.sockets = _page_looks[index].sockets
	_case.ridges = _page_looks[index].ridges
	if TipLayer.current != null:
		TipLayer.current.hide_all()


## The page of the characters: how they are chosen along the top, the
## cards on the left and the file of the one being read on the right, with
## how many there are and how many copies of each under it.
func _build_touch_characters(page: Control) -> void:
	var head := _mode_row()
	head.position = TOUCH_LEFT.position
	head.size = Vector2(TOUCH_LEFT.size.x, 40)
	page.add_child(head)

	# The cards are too big for the case: they scroll under the finger
	# (TouchMode drags any ScrollContainer in its group).
	var scroll := ScrollContainer.new()
	scroll.position = TOUCH_LEFT.position + Vector2(0, 48)
	scroll.size = Vector2(TOUCH_LEFT.size.x, TOUCH_LEFT.size.y - 48.0 - 24.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.add_to_group(TouchMode.SCROLLS)
	page.add_child(scroll)
	var grid := Control.new()
	grid.size = Vector2(scroll.size.x, 0)
	scroll.add_child(grid)
	var count := Content.character_list().size()
	var per_row := TOUCH_CARDS_PER_ROW
	var step := grid.size.x / per_row
	var card_scale := floorf((step - TOUCH_CARD_GAP) / CardView.BASE.x * 10.0) / 10.0
	_fill_grid(grid, per_row, card_scale, TOUCH_CAPTION, 6.0)
	var rows := ceili(count / float(per_row))
	grid.custom_minimum_size = Vector2(scroll.size.x, 6.0 + rows * (CardView.BASE.y * card_scale + TOUCH_CAPTION) + 10.0)

	# A long line under the cards: it keeps its desktop size to fit.
	_summary = UI.native(func() -> Label: return UI.label("", 13, UI.CREAM.darkened(0.25)))
	_summary.position = Vector2(TOUCH_LEFT.position.x, TOUCH_LEFT.end.y - 16.0)
	_summary.size = Vector2(TOUCH_LEFT.size.x, 24)
	_summary.clip_text = true
	page.add_child(_summary)

	var sheet := _build_reader(page, Rect2(TOUCH_RIGHT.position, Vector2(TOUCH_RIGHT.size.x, TOUCH_RIGHT.size.y - 94.0)))
	sheet.rotation = 0.006
	var steppers := VBoxContainer.new()
	steppers.add_theme_constant_override("separation", 6)
	steppers.position = Vector2(TOUCH_RIGHT.position.x, TOUCH_RIGHT.end.y - 82.0)
	steppers.size = Vector2(TOUCH_RIGHT.size.x, 82)
	page.add_child(steppers)
	_build_count_rows()
	steppers.add_child(_count_row)
	steppers.add_child(_draw_row)
	steppers.add_child(_copies_row())


## The page of the items: a hollow in the foam for each, the ones always on
## sale on a row of their own above a ridge, and the file of the one being
## read on the right.
func _build_touch_items(page: Control) -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.position = TOUCH_LEFT.position
	head.size = Vector2(TOUCH_LEFT.size.x, 40)
	page.add_child(head)
	_item_title = UI.label("", 18, UI.GOLD, true)
	_item_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_item_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(_item_title)
	head.add_child(_reset_button(_reset_items, _items_default))

	var defs := Content.item_list()
	var fixed := defs.filter(func(def: ItemDef) -> bool: return def.fixed)
	var others := defs.filter(func(def: ItemDef) -> bool: return not def.fixed)
	var step := TOUCH_LEFT.size.x / TOUCH_ITEM_COLUMNS
	var top := TOUCH_LEFT.position.y + 48.0
	var hollows: Array[Rect2] = []
	var ridges: Array[float] = [TOUCH_TABS.end.y]
	if not fixed.is_empty():
		for i in fixed.size():
			hollows.append(_item_cell(page, fixed[i], Vector2(TOUCH_LEFT.position.x + i * step, top), step))
		var note := UI.label("Always on sale, outside the shop slots. Can't be banned.", 13, UI.CREAM.darkened(0.2))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.position = Vector2(TOUCH_LEFT.position.x + fixed.size() * step + 8.0, top)
		note.size = Vector2(TOUCH_LEFT.end.x - note.position.x, TOUCH_ITEM_ROW - 24.0)
		note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		page.add_child(note)
		top += TOUCH_ITEM_ROW
		ridges.append(top - 6.0)
		top += 12.0
	for i in others.size():
		var at := Vector2(TOUCH_LEFT.position.x + (i % TOUCH_ITEM_COLUMNS) * step, top + floorf(i / float(TOUCH_ITEM_COLUMNS)) * TOUCH_ITEM_ROW)
		hollows.append(_item_cell(page, others[i], at, step))
	_page_looks[1].sockets = hollows
	_page_looks[1].ridges = ridges
	_build_item_reader(page, TOUCH_RIGHT)


## One item in its hollow at `at`, `wide` across, with its name under it.
## Returns the hollow.
func _item_cell(page: Control, def: ItemDef, at: Vector2, wide: float) -> Rect2:
	var view := ItemView.new(TOUCH_ITEM_SCALE)
	view.position = Vector2(roundf(at.x + (wide - view.size.x) / 2.0), at.y + 6.0)
	view.set_item(def)
	page.add_child(view)
	_item_cells[def.id] = view
	var caption := UI.label(def.display_name, 11, UI.GOLD if def.fixed else UI.CREAM.darkened(0.15))
	caption.clip_text = true
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.position = Vector2(at.x, view.position.y + view.size.y + 6.0)
	caption.size = Vector2(wide, TOUCH_CAPTION)
	page.add_child(caption)
	view.clicked.connect(_read_item.bind(def.id))
	if def.fixed:
		view.clicked.connect(_refuse.bind(view))
	else:
		_item_views[def.id] = view
		if _host:
			view.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			view.clicked.connect(func():
				_items_on[def.id] = not _items_on[def.id]
				_refresh())
	return Rect2(view.position, view.size).grow(3.0)


## A sheet where the item being read is written up: its picture clipped to
## the corner, name, price and kind beside it, what it does under them.
func _build_item_reader(page: Control, rect: Rect2) -> void:
	var sheet: Desk = Desk.make(Desk.Kind.SHEET, rect)
	sheet.dog_ear = false
	sheet.tone = Desk.DIM_PAPER
	sheet.browned = true
	sheet.rotation = -0.006
	page.add_child(sheet)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 0)
	box.offset_left = 18
	box.offset_top = 16
	box.offset_right = -18
	box.offset_bottom = -12
	box.add_theme_constant_override("separation", 10)
	sheet.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	box.add_child(head)
	_item_head = head
	var photo := Control.new()
	photo.custom_minimum_size = ItemView.BASE * TOUCH_ITEM_PHOTO + Vector2(12, 12)
	photo.draw.connect(func():
		var frame := Rect2(Vector2.ZERO, photo.size)
		photo.draw_rect(Rect2(frame.position + Vector2(3, 3), frame.size), Color(0, 0, 0, 0.25))
		photo.draw_rect(frame, Desk.INK_FADED)
		photo.draw_rect(frame.grow(-2.0), Desk.PAPER_DARK))
	head.add_child(photo)
	_item_photo = TextureRect.new()
	_item_photo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_item_photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_item_photo.stretch_mode = TextureRect.STRETCH_SCALE
	_item_photo.position = Vector2(6, 6)
	_item_photo.size = ItemView.BASE * TOUCH_ITEM_PHOTO
	photo.add_child(_item_photo)
	# The clip holds the picture to the sheet.
	sheet.clip_at = box.offset_left + photo.custom_minimum_size.x / 2.0 - 10.0
	var lines := VBoxContainer.new()
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.add_theme_constant_override("separation", 4)
	head.add_child(lines)
	_item_name = Desk.written("", 22, Desk.INK, true)
	_item_name.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_item_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lines.add_child(_item_name)
	# The price is the coin and the amount, then the kind of item.
	var kind_row := HBoxContainer.new()
	kind_row.add_theme_constant_override("separation", 3)
	kind_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(kind_row)
	var coin := TextureRect.new()
	coin.texture = UI.tex(UI.COIN_ICON)
	coin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.custom_minimum_size = Vector2.ONE * UI.coin_side(15)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kind_row.add_child(coin)
	_item_price = Desk.written("", 15, Desk.INK, true)
	_item_price.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	kind_row.add_child(_item_price)
	_item_kind = Desk.written("", 15, Desk.INK_FADED)
	_item_kind.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	kind_row.add_child(_item_kind)
	_item_state = Desk.written("", 15, Desk.INK_RED, true)
	_item_state.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_item_state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lines.add_child(_item_state)
	_item_text = RichTextLabel.new()
	_item_text.bbcode_enabled = true
	_item_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_item_text.add_theme_color_override("default_color", Desk.INK)
	_item_text.add_theme_font_size_override("normal_font_size", UI.grow(15))
	_item_text.add_theme_font_size_override("bold_font_size", UI.grow(15))
	box.add_child(_item_text)


## An item was tapped or held: its file goes on the sheet.
func _read_item(item_id: StringName) -> void:
	_item_read = item_id
	_redraw_item_reader()


func _redraw_item_reader() -> void:
	if _item_text == null:
		return
	var def: ItemDef = Content.items.get(_item_read) if _item_read != &"" else null
	_item_head.visible = def != null
	var count := _items_on.values().count(true)
	_item_title.text = "%s  %d/%d" % [Loc.t("ITEMS IN THE SHOP"), count, _items_on.size()]
	if def == null:
		_item_text.text = "[color=%s]%s[/color]" % [UI.hex(Desk.INK_FADED), Loc.t("Tap an item to read what it does here.")]
		return
	_item_photo.texture = UI.tex(def.texture_path)
	_item_name.text = def.display_name.to_upper()
	_item_price.text = str(def.price)
	_item_kind.text = "  ·  %s" % def.kind_label()
	var state := "Always on sale."
	var ink := Desk.INK_GREEN
	if not def.fixed:
		state = "On sale in this match." if _items_on[def.id] else "Banned from this match."
		ink = Desk.INK_GREEN if _items_on[def.id] else Desk.INK_RED
	_item_state.text = Loc.t(state)
	Desk.ink(_item_state, ink)
	var text := def.description
	if _host and not def.fixed:
		text += "\n\n[color=%s]%s[/color]" % [UI.hex(UI.MUTED), Loc.t("Tap to allow or ban it.")]
	text = Desk.in_ink(text)
	if _item_text.text != text:
		_item_text.text = text


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
func _build_address(parent: Control, rect: Rect2) -> void:
	var slip: Desk = Desk.make(Desk.Kind.SHEET, rect)
	slip.rotation = -0.012
	slip.dog_ear = false
	slip.tone = Desk.DIM_PAPER
	parent.add_child(slip)
	var line: Label = Desk.written("Only the host changes the table. You may change your name.", 14, Desk.INK_FADED)
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
	line.add_theme_font_size_override("font_size", UI.px(16))
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
func _build_players(parent: Control, rect: Rect2) -> void:
	_on_paper = true
	if UI.touch:
		_seat_step = TOUCH_SEAT_STEP
	var board: Desk = Desk.make(Desk.Kind.CLIPBOARD, rect)
	board.tone = Desk.DIM_PAPER
	board.browned = true
	board.ruled = _seat_step
	board.ruled_from = SEAT_LINES + _seat_step - Desk.SHEET_AT.y - 1.0
	parent.add_child(board)
	var box := VBoxContainer.new()
	box.position = Vector2(22, SEAT_LINES - 35.0)
	box.size = Vector2(rect.size.x - 44.0, 0)
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
	var line_height := _seat_step - 4.0 if UI.touch else 24.0
	list.add_theme_constant_override("separation", int(_seat_step - line_height))
	box.add_child(list)
	for i in Room.MAX_SEATS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var number := Desk.written(str(i + 1), 16, Desk.INK_FADED, true)
		number.custom_minimum_size = Vector2(16, 0)
		row.add_child(number)
		var name_edit := LineEdit.new()
		name_edit.max_length = Room.NAME_LENGTH
		name_edit.custom_minimum_size = Vector2(170, line_height)
		Desk.line(name_edit, Desk.INK_BLUE, false)
		_slim(name_edit, [&"normal", &"focus", &"read_only"])
		name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_edit.text_changed.connect(_on_renamed.bind(i))
		name_edit.text_submitted.connect(func(_text: String): _leave_name(name_edit, i))
		name_edit.focus_exited.connect(_on_name_left.bind(name_edit, i))
		row.add_child(name_edit)
		var tag := Desk.written("", 14, Desk.INK_FADED, true)
		tag.custom_minimum_size = Vector2(58, 0)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(tag)
		var remove := Cross.new()
		remove.custom_minimum_size = Vector2(44, 28) if UI.touch else Vector2(26, 22)
		remove.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		remove.pressed.connect(_cross_off.bind(i))
		TipLayer.attach(remove, func() -> String:
			var bot: bool = i < _room.seats.size() and _room.seats[i].bot
			return Loc.t("Take this bot out of the room." if bot else "Take this player out of the room."))
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
	_build_ghosts(_file)
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
	_add_rules(_rules)
	_reader = _new_reader()
	box.add_child(_reader)
	_file.resized.connect(_place_ghost)
	_place_ghost()
	_on_paper = false


## The house rules, one to a line, into `box`, written like the lines of a
## ledger: a short name, a dotted leader and the value in a column of its own
## on the right, between two ink arrows. Where a picture says it better the
## number is the picture: Morale is hearts picked like a rating (with the
## starting coins beside them, as the table shows a player), and the shop is
## its slots.
func _add_rules(box: Container) -> void:
	var start := _rule_row("Start with", "")
	var hearts := _pips(5, Vector2(9, 9) * (3.0 if UI.touch else 2.0), 2.0, _paint_heart,
			func(): return _config.start_morale - 1, func(v): _config.start_morale = v + 1)
	TipLayer.attach(hearts, func() -> String:
		return "%s: %d. %s" % [Loc.t("Starting Morale"), _config.start_morale, Loc.t("Lose it all and you are out.")])
	start.add_child(hearts)
	start.add_child(_rule_spinner("Starting coins", func(): return _config.start_coins,
			func(v): _config.start_coins = v, 0, 10, func(v: int) -> Variant: return str(v), Desk.INK, true))
	box.add_child(start)
	var income := _rule_row("Income", "Coins everyone gains at the start of each of their turns.")
	income.add_child(_rule_spinner("", func(): return _config.income,
			func(v): _config.income = v, 0, 5, func(v: int) -> Variant: return "+%d" % v, Desk.INK_GREEN, true, true))
	box.add_child(income)
	var wrong := _rule_row("Wrong LIAR!", "Coins you lose when you doubt someone who was telling the truth.")
	wrong.add_child(_rule_spinner("", func(): return _config.doubt_cost,
			func(v): _config.doubt_cost = v, 0, 6, func(v: int) -> Variant: return "-%d" % v, Desk.INK_RED, true))
	box.add_child(wrong)
	var right := _rule_row("Right LIAR!", "Coins you gain when you doubt someone who was lying.")
	right.add_child(_rule_spinner("", func(): return _config.doubt_reward,
			func(v): _config.doubt_reward = v, 0, 6, func(v: int) -> Variant: return "+%d" % v, Desk.INK_GREEN, true))
	box.add_child(right)
	# No clock at all comes after the longest, not before the shortest.
	var marks := TURN_TIMES.size()
	var timer := _rule_row("Turn timer", "How long each player has for their turn. When it runs out, the turn ends. The clock is the outline round the player's box, and it only runs while the table is waiting for them.")
	timer.add_child(_rule_spinner("", func(): return (_turn_time_index() + marks - 1) % marks,
			func(v): _config.turn_seconds = TURN_TIMES[(v + 1) % marks], 0, marks - 1,
			func(v: int) -> Variant: return TURN_TIME_NAMES[(v + 1) % marks], Desk.INK))
	box.add_child(timer)
	var slots := _rule_row("Shop slots", "")
	var shelf := _pips(4, Vector2(16, 16) * _rule_scale(), 4.0, _paint_slot,
			func(): return _config.shop_slots - 1, func(v): _config.shop_slots = v + 1)
	TipLayer.attach(shelf, func() -> String:
		return Loc.t("%d items on the shelf of the shop, besides the ones always on sale.") % _config.shop_slots)
	slots.add_child(_rule_column(shelf))
	box.add_child(slots)
	var speed := _rule_row("Animation speed", "")
	speed.add_child(_rule_spinner("", _anim_speed_index, func(v): _config.anim_speed = ANIM_SPEEDS[v] / 100.0,
			0, ANIM_SPEEDS.size() - 1, func(v: int) -> Variant: return "%d%%" % ANIM_SPEEDS[v], Desk.INK))
	box.add_child(speed)


func _rule_scale() -> float:
	return 1.35 if UI.touch else 1.0


## The width of the column the values of the house rules are written in.
func _rule_width() -> float:
	return 124.0 * _rule_scale()


## A line of the house rules: the name in ink and a dotted leader up to what
## sets it, which is added after.
func _rule_row(text: String, tip: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.custom_minimum_size = Vector2(0, 38 if UI.touch else 25)
	var l := Desk.ink(UI.label(text, 14, UI.CREAM))
	row.add_child(l)
	if tip != "":
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		TipLayer.attach(l, tip)
	var leader := Control.new()
	leader.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	leader.draw.connect(func():
		var y := roundf(leader.size.y / 2.0 + 4.0 * _rule_scale())
		var x := 2.0
		while x + 2.0 <= leader.size.x - 2.0:
			leader.draw_rect(Rect2(x, y, 2, 2), Color(Desk.INK_FADED, 0.45))
			x += 6.0)
	row.add_child(leader)
	return row


## `content` in the middle of the column of values.
func _rule_column(content: Control) -> Control:
	var column := CenterContainer.new()
	column.custom_minimum_size = Vector2(_rule_width(), 0)
	column.add_child(content)
	return column


## A value of the house rules in its column: what `show` makes of it (a text,
## or a bitmap of text rows such as INFINITY), in `ink`, with the coin after it
## (`coin`) and the hourglass of "every turn" (`per_turn`), between two ink
## arrows that step it. The wheel over it steps it too.
func _rule_spinner(tip: String, getter: Callable, setter: Callable, low: int, high: int, show: Callable, ink: Color, coin := false, per_turn := false) -> Control:
	var grown := _rule_scale()
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(_rule_width(), 0)
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	var less := _rule_arrow(true)
	var more := _rule_arrow(false)
	var sum := HBoxContainer.new()
	sum.alignment = BoxContainer.ALIGNMENT_CENTER
	sum.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sum.add_theme_constant_override("separation", 3)
	sum.mouse_filter = Control.MOUSE_FILTER_PASS
	if tip != "":
		TipLayer.attach(sum, tip)
	var value := Desk.ink(UI.label("", 15, UI.GOLD, true), ink)
	# With a coin the number is right-aligned in a fixed width, and the place
	# of the hourglass is kept where there is none: the coins of every line
	# fall in one column.
	var number := Vector2(24.0 * grown, 0) if coin else Vector2.ZERO
	value.custom_minimum_size = number
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.draw.connect(func():
		if value.has_meta(&"bits"):
			var bits: Array[String] = value.get_meta(&"bits")
			var cell := 2.0
			var origin := ((value.size - Vector2(bits[0].length(), bits.size()) * cell) / 2.0).round()
			for y in bits.size():
				for x in bits[y].length():
					if bits[y][x] == "#":
						value.draw_rect(Rect2(origin + Vector2(x, y) * cell, Vector2(cell, cell)), ink))
	sum.add_child(value)
	if coin:
		var icon := TextureRect.new()
		icon.texture = UI.tex(UI.COIN_ICON)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2.ONE * 14.0 * grown
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sum.add_child(icon)
	if per_turn:
		sum.add_child(_rule_glyph(&"hourglass"))
	elif coin:
		var room := Control.new()
		var glass: Array = LogView.GLYPHS[&"hourglass"]
		room.custom_minimum_size = Vector2(glass[0].length(), glass.size()) * 2.0 * grown
		room.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sum.add_child(room)
	row.add_child(less)
	row.add_child(sum)
	row.add_child(more)
	var change := func(delta: int):
		var next := clampi(getter.call() + delta, low, high)
		if not _host or next == getter.call():
			return
		setter.call(next)
		UI.pop(value, 1.3, 0.2)
		_play_sfx("ui_key")
		_refresh()
	less.pressed.connect(change.bind(-1))
	more.pressed.connect(change.bind(1))
	sum.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				change.call(1)
				sum.accept_event()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				change.call(-1)
				sum.accept_event())
	_refreshers.append(func():
		var current: int = getter.call()
		var shown: Variant = show.call(current)
		if shown is Array:
			var bits: Array[String] = shown
			value.text = ""
			value.custom_minimum_size = Vector2(bits[0].length() * 2.0, 0)
			value.set_meta(&"bits", bits)
		else:
			value.text = shown
			value.custom_minimum_size = number
			value.remove_meta(&"bits")
		value.queue_redraw()
		less.disabled = current <= low
		more.disabled = current >= high
		less.visible = _host
		more.visible = _host)
	return row


## A small triangle of ink that steps a rule down (`left`) or up: faded until
## the mouse is on it, and gone where the rule cannot go further.
const ARROW_LEFT: Array[String] = ["...#", "..##", ".###", "####", ".###", "..##", "...#"]
const ARROW_RIGHT: Array[String] = ["#...", "##..", "###.", "####", "###.", "##..", "#..."]


func _rule_arrow(left: bool) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(44, 40) if UI.touch else Vector2(26, 26)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.mouse_entered.connect(b.queue_redraw)
	b.mouse_exited.connect(b.queue_redraw)
	b.draw.connect(func():
		if b.disabled:
			return
		var bits: Array[String] = ARROW_LEFT if left else ARROW_RIGHT
		var cell := 3.0 if UI.touch else 2.0
		var origin := ((b.size - Vector2(bits[0].length(), bits.size()) * cell) / 2.0).round()
		var ink := Desk.INK if b.is_hovered() else Color(Desk.INK_FADED, 0.7)
		for y in bits.size():
			for x in bits[y].length():
				if bits[y][x] == "#":
					b.draw_rect(Rect2(origin + Vector2(x, y) * cell, Vector2(cell, cell)), ink))
	return b


## Inks of the log's pictures that are too pale for paper.
const PAPER_INKS := {
	&"hourglass": {"o": Desk.INK, "#": Desk.INK_FADED, "+": Color("b89a6a"), "-": Desk.INK_FADED},
}


## One of the log's pictures (LogView.GLYPHS), in its 2 px blocks.
func _rule_glyph(id: StringName) -> Control:
	var rows: Array = LogView.GLYPHS[id]
	var inks: Dictionary = PAPER_INKS.get(id, LogView.INKS[id])
	var cell := 2.0 * _rule_scale()
	var glyph := Control.new()
	glyph.custom_minimum_size = Vector2(rows[0].length(), rows.size()) * cell
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.draw.connect(func():
		for y in rows.size():
			for x in rows[y].length():
				var ink: Variant = inks.get(rows[y][x])
				if ink != null:
					glyph.draw_rect(Rect2(Vector2(x, y) * cell, Vector2(cell, cell)), ink))
	return glyph


## Marks picked like a rating (see Pips), kept in step with the config.
func _pips(count: int, mark: Vector2, gap: float, painter: Callable, getter: Callable, setter: Callable) -> Pips:
	var pips := Pips.new(count, mark, gap, painter)
	pips.picked.connect(func(index: int):
		if not _host or index == getter.call():
			return
		setter.call(index)
		_play_sfx("ui_key")
		_refresh())
	_refreshers.append(func():
		pips.value = getter.call()
		pips.live = _host
		pips.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _host else Control.CURSOR_ARROW
		pips.queue_redraw())
	return pips


## How a mark of a rating is drawn: chosen, chosen only under the mouse,
## about to be let go (the mouse is on a lower one), or not chosen.
func _rating_tone(pips: Pips, i: int) -> Color:
	var shown := pips.shown()
	if i <= shown:
		return Color.WHITE if i <= pips.value else Color(1, 1, 1, 0.55)
	if i <= pips.value:
		return Color(Desk.INK, 0.45)
	return Color(Desk.INK, 0.2)


## heart.png is 9 x 9 blocks of 3 px: drawn at a whole number of pixels per
## block, or rows of it would be dropped.
func _paint_heart(pips: Pips, i: int, rect: Rect2) -> void:
	var tone := _rating_tone(pips, i)
	# Not chosen: the heart in faded ink.
	var tint := Color(0.16, 0.12, 0.09, tone.a) if tone.r < 0.5 else tone
	pips.draw_texture_rect(UI.tex(LogView.HEART), rect, false, tint)


func _paint_slot(pips: Pips, i: int, rect: Rect2) -> void:
	var tone := _rating_tone(pips, i)
	var cell := 2.0 * _rule_scale()
	var on := tone.r > 0.5
	var ink := Color(Desk.INK_FADED, tone.a if on else 0.4)
	# A hollow of the shelf: a frame of ink, and for a slot in use a box on it.
	pips.draw_rect(Rect2(rect.position, Vector2(rect.size.x, cell)), ink)
	pips.draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - cell), Vector2(rect.size.x, cell)), ink)
	pips.draw_rect(Rect2(rect.position, Vector2(cell, rect.size.y)), ink)
	pips.draw_rect(Rect2(rect.position + Vector2(rect.size.x - cell, 0), Vector2(cell, rect.size.y)), ink)
	if on:
		var inner := rect.grow(-cell * 2.0)
		pips.draw_rect(inner, Color(Desk.INK_FADED, 0.55 * tone.a))


## Where a character's abilities are read: ink on the sheet.
func _new_reader() -> RichTextLabel:
	var reader := RichTextLabel.new()
	reader.bbcode_enabled = true
	reader.size_flags_vertical = Control.SIZE_EXPAND_FILL
	reader.add_theme_color_override("default_color", Desk.INK)
	reader.add_theme_font_size_override("normal_font_size", UI.grow(15))
	reader.add_theme_font_size_override("bold_font_size", UI.grow(15))
	return reader


## Touch mode: the file of the character being read is a sheet of its own,
## at `rect` on `page`, with the ghost of the character behind the text.
func _build_reader(page: Control, rect: Rect2) -> Desk:
	var sheet: Desk = Desk.make(Desk.Kind.SHEET, rect)
	sheet.dog_ear = false
	sheet.tone = Desk.DIM_PAPER
	sheet.browned = true
	sheet.clip_at = sheet.size.x - 56.0
	page.add_child(sheet)
	_build_ghosts(sheet)
	_reader = _new_reader()
	_reader.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 0)
	_reader.offset_left = 16
	_reader.offset_top = 14
	_reader.offset_right = -16
	_reader.offset_bottom = -12
	sheet.add_child(_reader)
	sheet.resized.connect(_place_ghost)
	_place_ghost()
	return sheet


## Touch mode: the house rules on a sheet of their own, always open, with
## the switch of the book of suspicions at the foot.
func _build_touch_rules(page: Control, rect: Rect2) -> void:
	_on_paper = true
	var sheet: Desk = Desk.make(Desk.Kind.SHEET, rect)
	sheet.dog_ear = false
	sheet.tone = Desk.DIM_PAPER
	sheet.browned = true
	sheet.rotation = 0.005
	page.add_child(sheet)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 0)
	box.offset_left = 18
	box.offset_top = 12
	box.offset_right = -18
	box.offset_bottom = -10
	box.add_theme_constant_override("separation", 4)
	sheet.add_child(box)
	var head := HBoxContainer.new()
	head.custom_minimum_size = Vector2(0, 30)
	var title := Desk.written("HOUSE RULES", 16, Desk.INK, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_reset_button(_reset_rules, _rules_default))
	box.add_child(head)
	_rules = VBoxContainer.new()
	_rules.add_theme_constant_override("separation", 5)
	box.add_child(_rules)
	_add_rules(_rules)
	_rules.add_child(_book_row())
	_on_paper = false


## Before the text, so that the text is written over it.
func _build_ghosts(sheet: Control) -> void:
	_ghosts = Control.new()
	_ghosts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(_ghosts)
	_ghost_look = ShaderMaterial.new()
	_ghost_look.shader = Shader.new()
	_ghost_look.shader.code = GHOST_SHADER
	_ghost = _new_ghost()


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
	var sheet := _ghosts.get_parent() as Control
	var height := sheet.size.y - 4.0
	var width := height * CardView.BASE.x / CardView.BASE.y
	for ghost: TextureRect in _ghosts.get_children():
		ghost.position = Vector2(sheet.size.x - 2.0 - width, 2.0)
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
	return minf(FILE_TOP, CLIPBOARD.position.y + SEAT_LINES + _room.seats.size() * _seat_step + 8.0)


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
	# In touch mode the rules have a page of their own: nothing to fold.
	var folds := _rules_open and not UI.touch
	if folds and not asked:
		return
	_read = character_id
	if folds:
		_set_rules_open(false)
	else:
		_redraw_reader()


## A finger held on a card does what a right click does; on an item, it
## reads the item without allowing or banning it.
func _on_held(control: Control) -> void:
	for id: StringName in _cards:
		if _cards[id] == control:
			_read_character(id, true)
			return
	for id: StringName in _item_cells:
		if _item_cells[id] == control:
			_read_item(id)
			return


func _on_card_input(event: InputEvent, character_id: StringName) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_read_character(character_id, true)


func _redraw_reader() -> void:
	if not UI.touch:
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
	var head := _mode_row()
	var title := UI.label("CHARACTERS", 20, UI.GOLD, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.move_child(title, 0)
	box.add_child(head)

	# One row for the switch of the book and for the number of characters,
	# which only shows while they are drawn at random: the row keeps its
	# height without it, or everything under it would move up.
	var options := _book_row()
	options.custom_minimum_size = Vector2(0, 26)
	box.add_child(options)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(24, 0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	options.add_child(gap)
	_build_count_rows()
	for row: Control in [_count_row, _draw_row]:
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Next to its buttons, not adrift in the middle of the row.
		(row.get_child(0) as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		options.add_child(row)
	options.custom_minimum_size.y = _count_row.get_combined_minimum_size().y

	# One row while the cast fits in it, two rows of smaller cards after that.
	var defs := Content.character_list()
	var rows := 1 if defs.size() <= GRID_ROW else 2
	var per_row := ceili(defs.size() / float(rows))
	var card_scale := 1.15 if rows == 1 else 0.9
	var caption_height := 16.0
	var grid := Control.new()
	grid.size.x = GRID_WIDTH
	grid.custom_minimum_size = Vector2(GRID_WIDTH, rows * (CardView.BASE.y * card_scale + caption_height) + 2.0)
	box.add_child(grid)
	_fill_grid(grid, per_row, card_scale, caption_height, 6.0)

	box.add_child(_copies_row())
	# Held a little above its own line, clear of the ridge of the case.
	var foot := Control.new()
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_summary = UI.label("", 13, UI.CREAM.darkened(0.25))
	_summary.position = Vector2(0, -SUMMARY_RISE)
	foot.custom_minimum_size = Vector2(0, _summary.get_combined_minimum_size().y - SUMMARY_RISE)
	foot.add_child(_summary)
	box.add_child(foot)
	_build_items()


## Random or hand-picked, and the reset of the characters.
func _mode_row() -> HBoxContainer:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
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
	return head


## The switch of the book of suspicions, with its name, on the velvet of the
## case or on the sheet of the rules (touch mode).
func _book_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var book_tip := "Gives every player a book at the table to note down who they think holds each card: filled in by hand, or by the book itself."
	var book_label := UI.label("Suspicion book", 14, UI.CREAM)
	if _on_paper:
		Desk.ink(book_label)
		book_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	book_label.mouse_filter = Control.MOUSE_FILTER_PASS
	TipLayer.attach(book_label, book_tip)
	row.add_child(book_label)
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
	row.add_child(_book_switch)
	if _on_paper:
		# Under the buttons of the steppers above it, not at the very edge.
		var pad := Control.new()
		pad.custom_minimum_size = Vector2(28, 0)
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(pad)
		row.custom_minimum_size.y = 44
	return row


## How many characters are drawn at random, and, hand-picked, how many of
## the chosen ones are drawn: all of them, unless the host wants the match
## to hide which. Only one of the two shows at a time (_redraw).
func _build_count_rows() -> void:
	_count_row = _stepper("How many characters", "", func(): return _config.character_count,
			func(v): _config.character_count = v, 3, Content.characters.size())
	_draw_row = _stepper("Quantos personagens", "How many of the characters you picked are in the match, drawn at random. Nobody knows which until they show up.",
			_drawn_count, func(v): _config.pool_draw = 0 if v >= _picked.size() else v,
			3, func() -> int: return maxi(_picked.size(), 3))


func _copies_row() -> Control:
	return _stepper("Copies of each character", "More copies make every claim more believable.",
			func(): return maxi(_config.copies_per_character, _min_copies()),
			func(v): _config.copies_per_character = v, 2, 6)


## The cards of the whole cast in `grid`, `per_row` to a row, each with its
## name under it, `top` below the top of the grid (room for a card to lift).
func _fill_grid(grid: Control, per_row: int, card_scale: float, caption_height: float, top: float) -> void:
	var defs := Content.character_list()
	var card_height := CardView.BASE.y * card_scale
	var row_height := card_height + caption_height
	var step := grid.size.x / per_row
	for i in defs.size():
		var def: CharacterDef = defs[i]
		var column := i % per_row
		var at := top + floorf(i / float(per_row)) * row_height
		var card := CardView.new(card_scale)
		card.position = Vector2(roundf(column * step + (step - card.size.x) / 2.0), at)
		card.set_card(def.id, true)
		# The abilities are read in the place of the house rules, not over the cards.
		card.tips = false
		card.mouse_entered.connect(_read_character.bind(def.id, false))
		card.gui_input.connect(_on_card_input.bind(def.id))
		if UI.touch:
			# No hover: a tap reads the character too.
			card.clicked.connect(_read_character.bind(def.id, false))
		if _host and UI.touch:
			# With a mouse, clicks and sweeps over the cards are _sweep_input's.
			card.clicked.connect(_toggle_character.bind(def.id))
		grid.add_child(card)
		_cards[def.id] = card
		var caption := UI.label(def.display_name, 11, UI.CREAM.darkened(0.15))
		# Clipping comes before the size: until then the label refuses to be
		# narrower than its text, and a long name would be centred in a wider box.
		caption.clip_text = true
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.position = Vector2(column * step, at + card_height + 1.0)
		caption.size = Vector2(step, caption_height)
		grid.add_child(caption)


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
	var l := UI.label(text, 18 if big else 14, UI.GOLD if big else UI.CREAM, big)
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
	value.custom_minimum_size = Vector2(52, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var plus := UI.button("+", UI.BORDER, 15)
	plus.custom_minimum_size = TOUCH_STEP_BUTTON if UI.touch else Vector2(34, 26)
	if paper:
		Desk.ink(value, Desk.INK_RED)
	for b: Button in [minus, plus]:
		if paper:
			b.custom_minimum_size = Vector2(44, 34) if UI.touch else Vector2(b.custom_minimum_size.x, 24)
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
		# Clicking a card while drawing at random keeps every character but
		# that one.
		if not _host:
			return
		_picked.clear()
		for def: CharacterDef in Content.character_list():
			if def.id != character_id:
				_picked.append(def.id)
		_set_random(false)
	elif _picked.has(character_id):
		_picked.erase(character_id)
	else:
		_picked.append(character_id)
	UI.pop(_cards[character_id], 1.15, 0.2)
	_refresh()


## The host's mouse on the character cards. A left click adds or removes a
## card, a right click leaves that card alone in the match (and reads it, by
## _on_card_input). Held and dragged onto other cards, the left button puts
## every card it passes in the match and the right one takes them out, the
## card it began on included; no box is drawn.
func _sweep_input(event: InputEvent) -> void:
	if not _host or UI.touch:
		return
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		if event.pressed:
			var id := _card_at(event.global_position)
			if id != &"" and _sweep_button == MOUSE_BUTTON_NONE:
				_sweep_button = event.button_index
				_sweep_from = id
				_sweeping = false
		elif event.button_index == _sweep_button:
			if not _sweeping and _card_at(event.global_position) == _sweep_from:
				if _sweep_button == MOUSE_BUTTON_LEFT:
					_toggle_character(_sweep_from)
				else:
					_pick_only(_sweep_from)
			_sweep_button = MOUSE_BUTTON_NONE
			_sweep_from = &""
			_sweeping = false
	elif event is InputEventMouseMotion and _sweep_button != MOUSE_BUTTON_NONE:
		var id := _card_at(event.global_position)
		if id == &"" or (id == _sweep_from and not _sweeping):
			return
		var adding := _sweep_button == MOUSE_BUTTON_LEFT
		if not _sweeping:
			_sweeping = true
			if _random:
				# Drawn at random every card is in: a sweep of the left button
				# starts from none, one of the right button from all of them.
				_random = false
				_picked.clear()
				if not adding:
					for def: CharacterDef in Content.character_list():
						_picked.append(def.id)
			_sweep_mark(_sweep_from, adding)
		_sweep_mark(id, adding)


## The character card under `point`, or &"".
func _card_at(point: Vector2) -> StringName:
	for id: StringName in _cards:
		var card: CardView = _cards[id]
		if card.is_visible_in_tree() and card.get_global_rect().has_point(point):
			return id
	return &""


func _sweep_mark(character_id: StringName, on: bool) -> void:
	if _picked.has(character_id) != on:
		if on:
			_picked.append(character_id)
		else:
			_picked.erase(character_id)
		UI.pop(_cards[character_id], 1.15, 0.2)
	_refresh()


## Every card out of the match but this one.
func _pick_only(character_id: StringName) -> void:
	_random = false
	_picked = [character_id]
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
	# Somebody else has that name: it shows in red and is not sent.
	var taken: bool = _room.name_taken(seat, text)
	_seat_rows[seat].name.add_theme_color_override("font_color", Desk.INK_RED if taken else Desk.INK_BLUE)
	if taken:
		return
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
			_seats_moving = true
			edit.release_focus()
			_seats_moving = false
		# The name being typed is ahead of what the room has heard of it.
		if not edit.has_focus() and edit.text != seat.name:
			edit.text = seat.name
		if not edit.has_focus():
			edit.add_theme_color_override("font_color", Desk.INK_BLUE)
		# Nobody writes a name but their own.
		var mine: bool = not seat.bot and seat.peer == me
		edit.editable = mine
		edit.focus_mode = Control.FOCUS_ALL if mine else Control.FOCUS_NONE
		edit.mouse_filter = Control.MOUSE_FILTER_STOP if mine else Control.MOUSE_FILTER_IGNORE
		row.tag.text = "BOT" if seat.bot else ("YOU" if seat.peer == me else ("HOST" if seat.peer == 1 else ""))
		row.tag.add_theme_color_override("font_color", Desk.INK_RED if seat.peer == me else Desk.INK_FADED)
		row.remove.visible = _host and (seat.bot or seat.peer > 1)


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
		if _random or not _host:
			card.note = ""
		elif UI.touch:
			card.note = "In the match. Tap to remove." if chosen else "Tap to add to the match."
		else:
			card.note = "In the match. Click to remove." if chosen else "Click to add to the match."
	for item_id: StringName in _item_views:
		_item_views[item_id].modulate = Color.WHITE if _items_on[item_id] else Color(0.3, 0.28, 0.28)
	_redraw_reader()
	_redraw_item_reader()

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
	_sweep_input(event)
	var clicked: bool = event is InputEventMouseButton and event.pressed
	if not clicked and not event.is_action_pressed(&"ui_cancel"):
		return
	for i: int in _seat_rows.size():
		var edit: LineEdit = _seat_rows[i].name
		if edit.has_focus() and not (clicked and edit.get_global_rect().has_point(event.global_position)):
			_leave_name(edit, i)


## Done with the name line (Enter, Esc, a click away): unless the name is
## somebody else's, then the line shakes and keeps the cursor.
func _leave_name(edit: LineEdit, seat: int) -> void:
	if _room.name_taken(seat, edit.text):
		_refuse_name(edit)
		return
	edit.release_focus()


## The focus went off the name line some other way (Tab): with a name that is
## somebody else's, it comes straight back.
func _on_name_left(edit: LineEdit, seat: int) -> void:
	if _seats_moving:
		return
	if edit.editable and edit.is_visible_in_tree() and seat < _room.seats.size() and _room.name_taken(seat, edit.text):
		edit.grab_focus.call_deferred()
		_refuse_name(edit)


func _refuse_name(edit: LineEdit) -> void:
	UI.shake(edit, 5.0, 0.25)
	_play_sfx("cancel")


## The host takes a bot or a guest out of the room, with the scratch of the pen.
func _cross_off(i: int) -> void:
	_play_sfx("ui_strike")
	_room.remove_seat(i)


func _play_sfx(sound: String) -> void:
	var stream := Sounds.stream(sound)
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = Settings.SFX_BUS
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


## A row of marks, one per value, picked like a rating: a click on a mark
## sets the value to it, dragging along the marks goes with the mouse, and
## the wheel steps it. Under the mouse the marks show what a click would
## make of them (`shown`). Every mark is drawn by `painter(pips, index, rect)`.
class Pips extends Control:
	signal picked(index: int)

	var count := 5
	var value := 0
	## The mark under the mouse, or -1.
	var hover := -1
	## Off for a guest: the marks only show the rule.
	var live := true
	var _mark := Vector2(18, 18)
	var _gap := 3.0
	var _painter: Callable
	var _held := false

	func _init(marks: int, mark: Vector2, gap: float, painter: Callable) -> void:
		count = marks
		_mark = mark
		_gap = gap
		_painter = painter
		custom_minimum_size = Vector2(count * mark.x + (count - 1) * gap, mark.y)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mouse_exited.connect(func() -> void:
			hover = -1
			queue_redraw())

	## The value to draw as chosen: the one under the mouse, if any.
	func shown() -> int:
		return hover if hover >= 0 else value

	func rect_of(i: int) -> Rect2:
		return Rect2(Vector2(i * (_mark.x + _gap), (size.y - _mark.y) / 2.0).round(), _mark)

	func _at(x: float) -> int:
		return clampi(int(x / (_mark.x + _gap)), 0, count - 1)

	func _gui_input(event: InputEvent) -> void:
		if not live:
			return
		if event is InputEventMouseMotion:
			# A finger shows no preview but while it is down.
			hover = _at(event.position.x) if _held or not UI.touch else -1
			if _held and hover != value:
				picked.emit(hover)
			queue_redraw()
		elif event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				_held = event.pressed
				if event.pressed:
					picked.emit(_at(event.position.x))
				elif UI.touch:
					hover = -1
				queue_redraw()
				accept_event()
			elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
				picked.emit(clampi(value + (1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1), 0, count - 1))
				accept_event()

	func _draw() -> void:
		for i in count:
			_painter.call(self, i, rect_of(i))


## The host's cross next to a bot's name: an X in red ink, two quick strokes
## in the 2 px blocks of the desk, darker and bigger under the mouse.
class Cross extends Button:
	func _init() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		button_down.connect(queue_redraw)
		button_up.connect(queue_redraw)

	func _draw() -> void:
		var over := is_hovered() and not disabled
		var half := (7.0 if UI.touch else 5.0) + (1.0 if over else 0.0)
		var middle := (size * 0.5).round()
		var ink := Color(Desk.INK_RED, 1.0 if over else 0.75)
		if disabled:
			ink = Color(Desk.INK_RED, 0.35)
		elif is_pressed():
			ink = Desk.INK_RED.darkened(0.25)
		# Each stroke starts heavy and runs a block past the other one, as a pen does.
		_stroke(middle + Vector2(-half, -half - 1.0), middle + Vector2(half + 1.0, half), ink)
		_stroke(middle + Vector2(half, -half), middle + Vector2(-half, half + 2.0), Color(ink, ink.a * 0.9))

	func _stroke(a: Vector2, b: Vector2, ink: Color) -> void:
		var steps := int(ceilf(a.distance_to(b) / 2.0))
		for k in steps + 1:
			var t := float(k) / maxf(steps, 1)
			var at := (a.lerp(b, t) / 2.0).round() * 2.0
			var weight := 4.0 if t < 0.25 else 2.0
			draw_rect(Rect2(at - Vector2(1.0, 1.0), Vector2(weight, 2.0 + (2.0 if t < 0.1 else 0.0))), ink)


func _unhandled_key_input(event: InputEvent) -> void:
	UI.handle_fullscreen_key(event, get_window())
