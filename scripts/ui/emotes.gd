extends Control
## The emotes of the table: a button with a face on it that sits above the log
## and opens a column of faces to pick from, and (Bubble) the balloon a
## player's emote is shown in. Everything is drawn in code, in blocks.
## An emote is only talk: it never reaches the engine.

signal picked(kind: int)
## The player typed something to say (see Speech): at most SAY_LENGTH letters.
signal said(text: String)

## What can be said, in the order of the column (top to bottom) and of the
## number keys. `id` names the sound ("emote_<id>"); `name` is a translation key.
const KINDS := [
	{"id": "laugh", "name": "Laugh"},
	{"id": "sad", "name": "Sad"},
	{"id": "angry", "name": "Angry"},
	{"id": "mystery", "name": "Mysterious"},
	{"id": "handshake", "name": "Handshake"},
	{"id": "flex", "name": "Show off"},
]
const LAUGH := 0
const SAD := 1
const ANGRY := 2
const MYSTERY := 3
const HANDSHAKE := 4
const FLEX := 5
## The button, each face of the column and from one face to the next.
const BUTTON := Vector2(24, 24)  # the size of the folded log under it
const OPTION := Vector2(32, 32)
const STEP := 34.0
const COLUMN_X := -4.0  # the faces are wider than the button: centred on it
## What a player may type to the table: how long it can be, and the line it
## is typed on, to the right of the button.
const SAY_LENGTH := 60
const SAY_LINE := Vector2(204, 24)
## Touch mode: the buttons and the faces are made bigger whole, and the line
## to type on opens high on the screen, where the phone's keyboard, which
## comes up from below, leaves it in sight.
const TOUCH_SCALE := 1.65
const TOUCH_LINE := Rect2(276, 64, 600, 52)
## The face on the button that opens the column.
const FACE := [
	"..#####..",
	".#.....#.",
	"#.......#",
	"#.#...#.#",
	"#.......#",
	"#.#...#.#",
	"#..###..#",
	".#.....#.",
	"..#####..",
]
const OPEN_TIME := 0.14
## The faces, one text bitmap each, all GRID cells square.
const GRID := 13
const INKS := {
	"k": Color("160c08"), "y": Color("f0c64c"), "o": Color("c8922e"), "w": Color("fbf6e6"),
	"r": Color("d6503c"), "m": Color("a03426"), "b": Color("4f7fd0"), "g": Color("3a3340"),
	"d": Color("241c2a"), "p": Color("9a62c4"), "s": Color("e8b98a"), "u": Color("b07a4e"),
}
const ICONS := [
	[
		"....kkkkk....",
		"..kkyyyyykk..",
		".kyyyyyyyyyk.",
		".kyykyyykyyk.",
		"kyykykykykyyk",
		"kyyyyyyyyyyyk",
		"kykkkkkkkkkyk",
		"kykwwwwwwwkyk",
		"kyykrrrrrkyyk",
		".kyykrrrkyyk.",
		".kyyykkkyyok.",
		"..kkyyyyokk..",
		"....kkkkk....",
	],
	[
		"....kkkkk....",
		"..kkyyyyykk..",
		".kyyyyyyyyyk.",
		".kyyykykyyyk.",
		"kyykkyyykkyyk",
		"kyyyyyyyyyyyk",
		"kyykkyyykkyyk",
		"kyyyyyyyyyyyk",
		"kyyyykkkyyyyk",
		".kyykyyykyyk.",
		".kyyyyyyyyok.",
		"..kkyyyyokk..",
		"....kkkkk....",
	],
	[
		"....kkkkk....",
		"..kkrrrrrkk..",
		".krrrrrrrrrk.",
		".krkkrrrkkrk.",
		"krrrrkrkrrrrk",
		"krrwkrrrkwrrk",
		"krrrrrrrrrrrk",
		"krrkkkkkkkrrk",
		"krrkwkwkwkrrk",
		".krkkkkkkkrk.",
		".krrrrrrrrmk.",
		"..kkrrrrmkk..",
		"....kkkkk....",
	],
	[
		"....kkkkk....",
		"...kdddddk...",
		"...kdddddk...",
		"...kpppppk...",
		"kkkkkkkkkkkkk",
		".kgggggggggk.",
		".kgwwgggwwgk.",
		".kgggggggggk.",
		".kgggggggggk.",
		"..kgggggggk..",
		"..kkgggggkk..",
		"....kkkkk....",
		".............",
	],
	[
		".............",
		".............",
		"....kkkkk....",
		"...ksssuuk...",
		"kkkksssuukkkk",
		"kbbwsssuuwrrk",
		"kbbwssuuuwrrk",
		"kbbwsssuuwrrk",
		"kbbwssuuuwrrk",
		"kkkksssuukkkk",
		"...kkkkkkk...",
		".............",
		".............",
	],
	[
		"....kkkkk....",
		"..kkyyyyykk..",
		".kyyyyyyyyyk.",
		".kyyyyyyyyyk.",
		"kkkkkkkkkkkkk",
		"kykwkkykwkkyk",
		"kyykkyyykkyyk",
		"kyyyyyyyyyyyk",
		"kyyyyyyyykyyk",
		"kyykkkkkkyyyk",
		".kyyyyyyyyok.",
		"..kkyyyyokk..",
		"....kkkkk....",
	],
]
## The speech balloon on the button that opens the line to type on: an
## outline with three dots in it.
const GLYPH := [
	".#######.",
	"#.......#",
	"#.#.#.#.#",
	"#.......#",
	".#######.",
	"..##.....",
	"..#......",
]

var _toggle: Button
var _say: Button
var _line: LineEdit
var _options: Array = []
var _open := false
var _amount := 0.0  # 0 = shut, 1 = the column fully out
var _tween: Tween
var _s := 1.0  # how much bigger the buttons are drawn (TOUCH_SCALE in touch mode)


func _init() -> void:
	_s = TOUCH_SCALE if UI.touch else 1.0
	size = BUTTON * _s
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toggle = _bare_button(BUTTON)
	_toggle.draw.connect(_draw_toggle)
	_toggle.pressed.connect(func() -> void: _set_open(not _open))
	TipLayer.attach(_toggle, "[b]Emotes[/b]\nShow the table how you feel (keys 1 to 6).")
	add_child(_toggle)
	_say = _bare_button(BUTTON)
	_say.position = Vector2(BUTTON.x * _s + 4.0, 0)
	_say.draw.connect(_draw_say)
	_say.pressed.connect(func() -> void: open_line(not typing()))
	TipLayer.attach(_say, "[b]Say something[/b] (T)\nType a line for the whole table to see.")
	add_child(_say)
	_line = LineEdit.new()
	_line.position = Vector2(BUTTON.x * 2.0 + 8.0, 0)
	_line.size = SAY_LINE
	_line.max_length = SAY_LENGTH
	_line.placeholder_text = "Say something..."
	_line.context_menu_enabled = false
	_line.caret_blink = true
	_line.add_theme_font_size_override("font_size", UI.px(14))
	if UI.touch:
		_line.top_level = true
	_line.add_theme_color_override("font_color", UI.CREAM)
	_line.add_theme_color_override("font_placeholder_color", UI.MUTED.darkened(0.2))
	for state: String in ["normal", "focus", "read_only"]:
		var box := UI.box(Color(UI.INK, 0.9), UI.GOLD if state == "focus" else UI.BORDER.darkened(0.3), 2, 4, 4)
		box.content_margin_top = 0
		box.content_margin_bottom = 0
		_line.add_theme_stylebox_override(state, box)
	_line.visible = false
	_line.text_submitted.connect(_on_line_submitted)
	_line.focus_exited.connect(func() -> void: open_line(false))
	add_child(_line)
	for kind in KINDS.size():
		var option := _bare_button(OPTION)
		option.position = Vector2(COLUMN_X * _s, 0)
		option.visible = false
		option.draw.connect(_draw_option.bind(option, kind))
		option.pressed.connect(pick.bind(kind))
		TipLayer.attach(option, func() -> String: return "[b]%s[/b] (%d)" % [Loc.t(KINDS[kind].name), kind + 1])
		add_child(option)
		_options.append(option)


func _bare_button(extent: Vector2) -> Button:
	var b := Button.new()
	b.size = extent
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.mouse_entered.connect(b.queue_redraw)
	b.mouse_exited.connect(b.queue_redraw)
	b.scale = Vector2.ONE * _s
	return b


## How tall the buttons are on screen.
func height() -> float:
	return BUTTON.y * _s


## Sends `kind`. Nothing holds it back: as many, and as fast, as the player
## likes, and the column stays open for the next one.
func pick(kind: int) -> void:
	if kind >= 0 and kind < KINDS.size():
		picked.emit(kind)


## True while the player is typing a line: the keys are theirs, not the table's.
func typing() -> bool:
	return _line.visible


## Opens the line to type on, or puts it away with whatever was on it.
func open_line(open: bool) -> void:
	if open == _line.visible:
		return
	_line.visible = open
	_line.text = ""
	if open:
		# The line is as tall as its font needs, which is more than the
		# button: it is centred on it, not hung from its top.
		_line.size = SAY_LINE
		_line.position.y = roundf((BUTTON.y - _line.size.y) / 2.0)
		if UI.touch:
			_line.position = TOUCH_LINE.position
			_line.size = TOUCH_LINE.size
		_line.grab_focus()
		_line.edit()
	elif _line.has_focus():
		_line.release_focus()
	_say.queue_redraw()


func _on_line_submitted(text: String) -> void:
	var line := clean(text)
	open_line(false)
	if line != "":
		said.emit(line)


## `text` as it may be said: one line, no longer than SAY_LENGTH.
static func clean(text: String) -> String:
	return text.replace("\n", " ").replace("\r", " ").replace("\t", " ").strip_edges().left(SAY_LENGTH)


func _draw_say() -> void:
	var lit := _say.is_hovered() or typing()
	_frame(_say, BUTTON, 0.72, lit)
	var ink := UI.GOLD if lit else UI.CREAM
	for y in GLYPH.size():
		for x in GLYPH[y].length():
			if GLYPH[y][x] == "#":
				_say.draw_rect(Rect2(3 + x * 2, 5 + y * 2, 2, 2), ink)


func _input(event: InputEvent) -> void:
	# A click anywhere else puts the line away, and whatever was typed on it.
	if typing() and event is InputEventMouseButton and event.pressed \
			and not _line.get_global_rect().has_point(event.global_position) \
			and not _say.get_global_rect().has_point(event.global_position):
		open_line(false)
	# A click anywhere else puts the column away.
	if _open and event is InputEventMouseButton and event.pressed:
		var column := Rect2(global_position + Vector2(COLUMN_X, -STEP * _options.size()) * _s, Vector2(OPTION.x, STEP * _options.size() + BUTTON.y) * _s)
		if not column.has_point(event.global_position):
			_set_open(false)


func _set_open(open: bool) -> void:
	if open == _open:
		return
	_open = open
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_place, _amount, 1.0 if open else 0.0, OPEN_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_toggle.queue_redraw()


## The faces rise out of the button, the first of them the highest.
func _place(amount: float) -> void:
	_amount = amount
	for i in _options.size():
		var option: Button = _options[i]
		option.visible = amount > 0.0
		option.modulate.a = amount
		option.position.y = roundf(-STEP * _s * (_options.size() - i) * amount)


func _draw_toggle() -> void:
	var lit := _toggle.is_hovered() or _open
	_frame(_toggle, BUTTON, 0.72, lit)
	var ink := UI.GOLD if lit else UI.CREAM
	for y in FACE.size():
		for x in FACE[y].length():
			if FACE[y][x] == "#":
				_toggle.draw_rect(Rect2(3 + x * 2, 3 + y * 2, 2, 2), ink)


## The box of the log, which the button sits on top of: same fill, same
## border and the same rounded corners.
func _frame(canvas: Control, extent: Vector2, opacity: float, lit: bool) -> void:
	var edge := UI.GOLD if lit else UI.BORDER.darkened(0.3)
	UI.box(Color(UI.INK, opacity), edge, 2, 4, 0).draw(canvas.get_canvas_item(), Rect2(Vector2.ZERO, extent))


func _draw_option(option: Button, kind: int) -> void:
	var lit := option.is_hovered()
	_frame(option, OPTION, 0.86, lit)
	Bubble.icon(option, kind, Vector2(3, 2 if lit else 3), 2.0)


## The balloon an emote is said in. Its tail hangs from the bottom left
## corner, towards whoever says it; it pops out of there, plays the little
## scene of its kind and frees itself.
class Bubble extends Control:
	const BODY := Vector2(54, 50)
	const SIZE := Vector2(54, 56)  # with the tail
	const CELL := 3.0
	const LIFE := 2.6
	const POP := 0.16
	const FADE := 0.25
	const PAPER := Color("f1e3c0")
	const EDGE := Color("160c08")

	var kind := 0
	var _age := 0.0

	func _init(of_kind: int) -> void:
		kind = of_kind
		size = SIZE
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## Draws the face of `kind` on `canvas`, `cell` pixels to the block.
	static func icon(canvas: CanvasItem, of_kind: int, at: Vector2, cell: float) -> void:
		var rows: Array = ICONS[of_kind]
		for y in rows.size():
			var row: String = rows[y]
			for x in row.length():
				if row[x] != ".":
					canvas.draw_rect(Rect2(at + Vector2(x, y) * cell, Vector2(cell, cell)), INKS[row[x]])

	func _process(delta: float) -> void:
		_age += delta
		if _age >= LIFE:
			queue_free()
			return
		modulate.a = clampf((LIFE - _age) / FADE, 0.0, 1.0)
		queue_redraw()

	func _draw() -> void:
		# Out of the tip of the tail, a little too big and back.
		var grow := minf(_age / POP, 1.0)
		var swell := 0.4 + 0.6 * grow + 0.12 * sin(grow * PI)
		var tip := Vector2(4, SIZE.y)
		# The angry one cannot keep still.
		var fit := Vector2(roundf(sin(_age * 61.0)), 0) if kind == ANGRY and _age < 1.6 else Vector2.ZERO
		draw_set_transform(tip * (1.0 - swell) + fit, 0.0, Vector2(swell, swell))
		var fill := Color("f6cfc4") if kind == ANGRY else Color("cdbfe0") if kind == MYSTERY else Color("3a2414") if kind == FLEX else PAPER
		for layer in 2:
			var inset := 2.0 * layer
			var ink := EDGE if layer == 0 else fill
			for step in 3:
				var cut := Vector2(4 - 2 * step, 2 * step) if step < 2 else Vector2(0, 4)
				draw_rect(Rect2(Vector2(inset, inset) + cut, BODY - Vector2(inset, inset) * 2.0 - cut * 2.0), ink)
		for row in 3:
			var left := 8.0 - row * 2.0
			var right := 18.0 - row * 4.0
			draw_rect(Rect2(left, BODY.y + row * 2.0, right - left, 2), EDGE)
			if row < 2:
				draw_rect(Rect2(left + 2.0, BODY.y + row * 2.0, right - left - 4.0, 2), fill)
		draw_rect(Rect2(10, BODY.y - 2.0, 6, 2), fill)

		var at := ((BODY - Vector2(GRID, GRID) * CELL) / 2.0).round()
		var move := Vector2.ZERO
		match kind:
			LAUGH:
				move.y = -roundf(absf(sin(_age * 11.0)) * 3.0)
			SAD:
				move.y = minf(roundf(_age * 2.0), 2.0)
			MYSTERY:
				move.x = roundf(sin(_age * 2.2) * 2.0)
			HANDSHAKE:
				move.y = roundf(sin(_age * 13.0) * 3.0) if _age < 1.5 else 0.0
		icon(self, kind, at + move, CELL)
		match kind:
			SAD:
				# A tear that falls from the left eye, again and again.
				var fall := fmod(_age, 0.8) / 0.8
				draw_rect(Rect2(at + move + Vector2(3, 7 + floorf(fall * 4.0)) * CELL, Vector2(CELL, CELL)), Color(INKS["b"], 1.0 - fall * 0.6))
			ANGRY:
				# Steam off the top of the balloon, at both ends.
				for side: float in [0.0, 1.0]:
					var rise := fmod(_age * 1.7 + side * 0.4, 1.0)
					var puff := Vector2(10.0 + side * 30.0 + (side * 2.0 - 1.0) * rise * 3.0, -5.0 - roundf(rise * 8.0))
					draw_rect(Rect2(puff, Vector2(4, 4)), Color(1, 1, 1, 0.9 * (1.0 - rise)))
			MYSTERY:
				# The eyes shut for a moment, now and then.
				if fmod(_age, 1.3) > 1.12:
					draw_rect(Rect2(at + move + Vector2(3, 6) * CELL, Vector2(6, 1) * CELL), INKS["g"])
			FLEX:
				# Glints going off around the head, one after the other.
				for i in 4:
					var shine := sin(_age * 9.0 - i * 1.7)
					if shine > 0.2:
						var spark: Vector2 = [Vector2(7, 9), Vector2(46, 7), Vector2(44, 40), Vector2(9, 38)][i]
						var arm := 2.0 if shine < 0.7 else 4.0
						draw_rect(Rect2(spark - Vector2(arm, 1), Vector2(arm * 2.0, 2)), INKS["w"])
						draw_rect(Rect2(spark - Vector2(1, arm), Vector2(2, arm * 2.0)), INKS["w"])


## The balloon a typed line is said in: paper like an emote's, as wide as the
## words need (wrapped past WIDTH), its tail at the bottom left. It lasts
## longer the more there is to read, then frees itself. The words are drawn,
## not a Label: the balloon has to know its size the moment it is put up.
class Speech extends Control:
	const WIDTH := 168.0
	const PAD := Vector2(8, 4)
	const TAIL := 6.0
	const FONT := 14
	const POP := 0.16
	const FADE := 0.3
	const PAPER := Color("f1e3c0")
	const EDGE := Color("160c08")

	var text := ""
	var _age := 0.0
	var _life := 3.0
	var _font: Font
	var _font_size := FONT
	var _across := WIDTH

	func _init(words: String) -> void:
		text = words
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_life = 2.6 + text.length() * 0.06

	## The size is only known here, with the font of the screen: whoever puts
	## the balloon up places it after adding it.
	func _ready() -> void:
		_font = get_theme_font("font", "Label")
		_font_size = UI.px(FONT)
		# One line if it fits, wrapped at WIDTH if not.
		var wide := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x
		_across = minf(ceilf(wide) + 2.0, WIDTH)
		var tall := _font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, _across, _font_size).y
		size = Vector2(_across, ceilf(tall)) + PAD * 2.0 + Vector2(0, TAIL)
		pivot_offset = Vector2(4, size.y)

	func _process(delta: float) -> void:
		_age += delta
		if _age >= _life:
			queue_free()
			return
		modulate.a = clampf((_life - _age) / FADE, 0.0, 1.0)
		var grow := minf(_age / POP, 1.0)
		scale = Vector2.ONE * (0.4 + 0.6 * grow + 0.1 * sin(grow * PI))

	func _draw() -> void:
		var body := Vector2(size.x, size.y - TAIL)
		for layer in 2:
			var inset := 2.0 * layer
			var ink := EDGE if layer == 0 else PAPER
			draw_rect(Rect2(inset + 2.0, inset, body.x - inset * 2.0 - 4.0, body.y - inset * 2.0), ink)
			draw_rect(Rect2(inset, inset + 2.0, body.x - inset * 2.0, body.y - inset * 2.0 - 4.0), ink)
		for row in 3:
			var left := 8.0 - row * 2.0
			var right := 18.0 - row * 4.0
			draw_rect(Rect2(left, body.y + row * 2.0, right - left, 2), EDGE)
			if row < 2:
				draw_rect(Rect2(left + 2.0, body.y + row * 2.0, right - left - 4.0, 2), PAPER)
		draw_rect(Rect2(10, body.y - 2.0, 6, 2), PAPER)
		if _font != null:
			draw_multiline_string(_font, PAD + Vector2(0, _font.get_ascent(_font_size)), text,
					HORIZONTAL_ALIGNMENT_LEFT, _across, _font_size, -1, EDGE)
