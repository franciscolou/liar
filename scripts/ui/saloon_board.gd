extends RefCounted
## The look of the panels that open over a screen (settings, how to play, the
## pause menu, the menus of the table): the case of a player's seat (see
## SeatView._draw_case), at any size. A dark board in a thin frame lit from
## the top left, an inlay just inside it, a small brass bracket on every
## corner and three studs at the foot. The board itself is the wood of
## the desk of the room and lobby screens (Transition.WOOD, see
## WOOD_SHADER), toned down. It was once a wall of planks drawn here with
## grain and knots in a moulding (found to be too much wood), then one flat
## colour (too plain), then boards in two flat tones (the change from one
## to the next was found too hard). With `hung`,
## it is a sign hanging from two chains that go up out of the screen: only
## for the large ones (how to play); on the small ones it looked forced.
## Nothing here is a node: `frame` and `inset` dress a panel that already
## exists (they draw on its `draw` signal), and the other statics dress or
## make the widgets that go on it. No class name: preload it.

const Transition := preload("res://scripts/ui/transition.gd")

const PX := 2.0
## The board: the planks of the desk, lying across it, each with its own
## tone and grain, drawn towards the colour of the panels so that what is
## written on them stays easy to read, under a light that falls off from
## the upper middle in dithered steps (as the lamp does on the desk).
const WOOD_SHADER := "
uniform vec2 extent = vec2(400.0, 300.0);
const float PX = 2.0;
// Cells across each plank, and how much of the wood shows.
const float PLANK = 31.0;
const float SHOWN = 0.62;
const vec3 PANEL = vec3(0.165, 0.094, 0.063);

void fragment() {
	vec2 cell = floor(UV * extent / PX);
	vec3 wood = mix(PANEL, tone(planks(vec2(cell.y + 9.0, cell.x), PLANK, 0.0)), SHOWN);
	vec2 off = (UV - vec2(0.5, 0.3)) * vec2(1.0, 1.25);
	float level = (1.0 - smoothstep(0.1, 0.85, length(off))) * 6.0;
	float low = floor(level);
	float edge = mod(cell.x + cell.y, 2.0) < 1.0 ? 0.3 : 0.7;
	level = (low + (level - low > edge ? 1.0 : 0.0)) / 6.0;
	COLOR = vec4(wood * mix(0.7, 1.12, level), 1.0);
}
"

const INK := Color("160c08")
const SEAM := Color("150b07")
const FRAME := Color("4a2e1a")
const FRAME_DARK := Color("2e1b0e")
const BRASS := Color("b98a2e")
const BRASS_LIGHT := Color("e6bc4c")
const BRASS_DARK := Color("7d5616")
const IRON := Color("6f6a64")
const IRON_LIGHT := Color("a39c92")
const IRON_DARK := Color("26221f")
const RED_WOOD := Color("5e2018")
## How far in from each end of the top the chains of a hung sign are, and
## how far up they go (past the top of any screen).
const CHAIN_IN := 34.0
const CHAIN_UP := 700.0
## A corner bracket, as seen in the top left corner: brass, with a rivet.
const BRACKET := [
	"#####",
	"#o##.",
	"##...",
	"##...",
	"#....",
]


static var _wood: Shader


## Makes `panel` (a Panel or a PanelContainer) a board. `accent` is the inlay
## of the frame, `margin` the room left around what goes on it.
static func frame(panel: Control, accent: Color = UI.GOLD, margin := 22, hung := false) -> void:
	var none := StyleBoxEmpty.new()
	none.set_content_margin_all(margin)
	panel.add_theme_stylebox_override("panel", none)
	panel.draw.connect(func(): _board(panel, accent, hung))
	# The wood is a shader on a rectangle under everything the panel draws.
	# It hangs from a Node2D so that a container does not lay it out.
	var under := Node2D.new()
	under.show_behind_parent = true
	var wood := ColorRect.new()
	wood.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _wood == null:
		_wood = Shader.new()
		_wood.code = "shader_type canvas_item;\n" + Transition.WOOD + WOOD_SHADER
	var look := ShaderMaterial.new()
	look.shader = _wood
	wood.material = look
	under.add_child(wood)
	panel.add_child(under)
	# (Fitted on every draw: a panel sized before it is in the tree never
	# says it was resized.)
	panel.draw.connect(func():
		if wood.size != panel.size:
			wood.size = panel.size
			look.set_shader_parameter("extent", panel.size))


## Makes `panel` a place sunk into the board, lined in `fill`: the felt of a
## table, a tray. The colours can be changed later with the metas
## `board_fill` and `board_edge` and a redraw.
static func inset(panel: Control, fill: Color, edge: Color = FRAME_DARK, margin := 0) -> void:
	var none := StyleBoxEmpty.new()
	none.set_content_margin_all(margin)
	panel.add_theme_stylebox_override("panel", none)
	panel.draw.connect(func():
		var lining: Color = panel.get_meta(&"board_fill", fill)
		var rim: Color = panel.get_meta(&"board_edge", edge)
		var w := panel.size.x
		var h := panel.size.y
		panel.draw_rect(Rect2(0, 0, w, h), rim)
		panel.draw_rect(Rect2(PX, PX, w - PX * 2.0, h - PX * 2.0), lining)
		# Lit from the top left: the near walls throw a shadow in.
		panel.draw_rect(Rect2(PX, PX, w - PX * 2.0, PX * 2.0), Color(0, 0, 0, 0.4))
		panel.draw_rect(Rect2(PX, PX, PX * 2.0, h - PX * 2.0), Color(0, 0, 0, 0.4))
		panel.draw_rect(Rect2(PX, PX * 3.0, w - PX * 2.0, PX), Color(0, 0, 0, 0.18))
		panel.draw_rect(Rect2(PX * 2.0, h - PX * 2.0, w - PX * 3.0, PX), Color(1, 1, 1, 0.08))
		panel.draw_rect(Rect2(w - PX * 2.0, PX * 2.0, PX, h - PX * 3.0), Color(1, 1, 1, 0.08)))


## The title of a board: the words, over a rule with a mark at each end
## (the plate of a seat's name).
static func plaque(text: String, size := 26) -> PanelContainer:
	var plate := PanelContainer.new()
	var none := StyleBoxEmpty.new()
	none.content_margin_left = 18
	none.content_margin_right = 18
	none.content_margin_bottom = 8
	plate.add_theme_stylebox_override("panel", none)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.draw.connect(func():
		var w := plate.size.x
		var y := plate.size.y - PX * 3.0
		plate.draw_rect(Rect2(0, y, w, PX), Color(UI.BORDER, 0.55))
		plate.draw_rect(Rect2(0, y + PX, w, PX), Color(0, 0, 0, 0.3))
		for x: float in [0.0, w - PX * 2.0]:
			plate.draw_rect(Rect2(x, y - PX, PX * 2.0, PX * 3.0), Color(UI.GOLD, 0.8)))
	var words := UI.label(text, size, UI.GOLD, true)
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate.add_child(words)
	return plate


## A button on a board: a block standing out of it, pushed in when pressed.
## A gold `accent` makes it a brass plate (the one to press), a red one a
## red block (the one to think twice about). With `on` it stays
## pushed in and lit: the chosen one of a row.
static func plank(b: Button, accent: Color = UI.BORDER, on := false) -> void:
	var body := UI.PANEL_LIGHT
	var ink := UI.CREAM
	var lit := UI.GOLD
	var rim := SEAM
	if accent == UI.GOLD and not on:
		body = BRASS
		ink = INK
		lit = INK
		rim = BRASS_DARK.darkened(0.35)
	elif accent == UI.RED:
		body = RED_WOOD
		lit = Color("ffb9a8")
	elif accent == UI.GREEN:
		ink = UI.GREEN
	if on:
		body = UI.PANEL.darkened(0.25)
		ink = UI.GOLD
		rim = BRASS_DARK
	# state: fill, extra border on top, extra border underneath
	var looks := {
		"normal": [body, 4, 0] if on else [body, 0, 4],
		"hover": [body.lightened(0.06), 4, 0] if on else [body.lightened(0.14), 0, 4],
		"pressed": [body.darkened(0.2), 4, 0],
		"disabled": [UI.PANEL.darkened(0.25), 0, 4],
	}
	for state: String in looks:
		var box := UI.box(looks[state][0], rim, 2, 2, 6)
		box.border_width_top = 2 + looks[state][1]
		box.border_width_bottom = 2 + looks[state][2]
		b.add_theme_stylebox_override(state, box)
	b.add_theme_color_override("font_color", ink)
	for state: String in ["font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, lit)
	if body == BRASS:
		b.add_theme_font_override("font", UI.bold())
	else:
		b.remove_theme_font_override("font")


## A slider on a board: a groove cut into it, filled with brass up to
## a brass knob.
static func rail(slider: HSlider) -> void:
	var groove := UI.box(INK, FRAME, 2, 0, 4)
	slider.add_theme_stylebox_override("slider", groove)
	for state: String in ["grabber_area", "grabber_area_highlight"]:
		var fill := UI.box(BRASS if state == "grabber_area" else BRASS_LIGHT, BRASS_DARK.darkened(0.3), 2, 0, 4)
		slider.add_theme_stylebox_override(state, fill)
	slider.add_theme_icon_override("grabber", _knob(BRASS))
	slider.add_theme_icon_override("grabber_highlight", _knob(BRASS_LIGHT))


static func _knob(metal: Color) -> ImageTexture:
	var image := Image.create(14, 24, false, Image.FORMAT_RGBA8)
	image.fill_rect(Rect2i(2, 0, 10, 24), INK)
	image.fill_rect(Rect2i(0, 2, 14, 20), INK)
	image.fill_rect(Rect2i(2, 2, 10, 20), metal)
	image.fill_rect(Rect2i(2, 2, 2, 18), metal.lightened(0.35))
	image.fill_rect(Rect2i(2, 2, 10, 2), metal.lightened(0.35))
	image.fill_rect(Rect2i(10, 4, 2, 18), metal.darkened(0.35))
	image.fill_rect(Rect2i(4, 20, 8, 2), metal.darkened(0.35))
	# The grip: three notches across it.
	for y: int in [8, 12, 16]:
		image.fill_rect(Rect2i(4, y, 6, 2), metal.darkened(0.45))
	return ImageTexture.create_from_image(image)


static func _board(c: Control, accent: Color, hung: bool) -> void:
	var w := c.size.x
	var h := c.size.y
	if hung:
		for x: float in [CHAIN_IN, w - CHAIN_IN]:
			_chain(c, snappedf(x, PX))
	# The frame, lit from the top left, and the inlay.
	for edge: Rect2 in [Rect2(0, 0, w, PX), Rect2(0, 0, PX, h)]:
		c.draw_rect(edge, accent)
	for edge: Rect2 in [Rect2(0, h - PX, w, PX), Rect2(w - PX, 0, PX, h)]:
		c.draw_rect(edge, accent.darkened(0.3))
	var inlay := Color(accent.darkened(0.45), 0.9)
	var gap := PX * 2.0
	for edge: Rect2 in [Rect2(gap, gap, w - gap * 2.0, PX / 2.0), Rect2(gap, h - gap - PX / 2.0, w - gap * 2.0, PX / 2.0),
			Rect2(gap, gap, PX / 2.0, h - gap * 2.0), Rect2(w - gap - PX / 2.0, gap, PX / 2.0, h - gap * 2.0)]:
		c.draw_rect(edge, inlay)
	# Three studs at the foot of the board.
	for i in 3:
		c.draw_rect(Rect2(snappedf(w / 2.0, PX) - 7.0 + i * 6.0, h - gap - 5.0, PX, PX), Color(accent, 0.45))
	for corner in 4:
		_bracket(c, Vector2(w if corner % 2 == 1 else 0.0, h if corner >= 2 else 0.0),
				Vector2(-1 if corner % 2 == 1 else 1, -1 if corner >= 2 else 1))
	if hung:
		# The eyes the chains are hooked into.
		for x: float in [CHAIN_IN, w - CHAIN_IN]:
			var at := snappedf(x, PX)
			c.draw_rect(Rect2(at - PX * 3.0, 0, PX * 6.0, PX * 3.0), BRASS_DARK.darkened(0.3))
			c.draw_rect(Rect2(at - PX * 2.0, PX, PX * 4.0, PX), BRASS)
			c.draw_rect(Rect2(at - PX, PX, PX * 2.0, PX), INK)


## A corner bracket with its corner at `at`, opening towards `way`.
static func _bracket(c: Control, at: Vector2, way: Vector2) -> void:
	for y: int in BRACKET.size():
		var row: String = BRACKET[y]
		for x: int in row.length():
			if row[x] == ".":
				continue
			var cell := at + Vector2(x, y) * PX * way
			# A pixel that grows away from `at` starts one pixel short of it.
			cell -= Vector2(PX if way.x < 0.0 else 0.0, PX if way.y < 0.0 else 0.0)
			var outer := x == 0 or y == 0
			var metal := BRASS_DARK if outer else (UI.CREAM if row[x] == "o" else UI.GOLD.darkened(0.25))
			c.draw_rect(Rect2(cell, Vector2(PX, PX)), metal)


## A chain going straight up from the top of the board at `x`: links seen
## face on and edge on by turns.
static func _chain(c: Control, x: float) -> void:
	var y := PX
	var link := 0
	while y > -CHAIN_UP:
		if link % 2 == 0:
			# Face on: a ring.
			c.draw_rect(Rect2(x - PX * 3.0, y - PX * 7.0, PX * 6.0, PX * 7.0), IRON_DARK)
			c.draw_rect(Rect2(x - PX * 2.0, y - PX * 6.0, PX * 4.0, PX * 5.0), IRON)
			c.draw_rect(Rect2(x - PX * 2.0, y - PX * 6.0, PX, PX * 5.0), IRON_LIGHT)
			c.draw_rect(Rect2(x - PX, y - PX * 5.0, PX * 2.0, PX * 3.0), IRON_DARK)
			y -= PX * 5.0
		else:
			# Edge on: a bar through the two rings.
			c.draw_rect(Rect2(x - PX * 2.0, y - PX * 6.0, PX * 4.0, PX * 8.0), IRON_DARK)
			c.draw_rect(Rect2(x - PX, y - PX * 5.0, PX * 2.0, PX * 6.0), IRON)
			c.draw_rect(Rect2(x - PX, y - PX * 5.0, PX, PX * 6.0), IRON_LIGHT)
			y -= PX * 5.0
		link += 1
