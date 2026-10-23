extends Node
## The mouse cursor of the whole game, in its look: brass, cream and ink in
## blocks of 2 px, drawn here from text bitmaps (`ARROW`, `POINT`...), with a
## shadow one block down and to the right. Each Godot cursor shape the game
## uses has one (`SHAPES`); a control picks it with `mouse_default_cursor_shape`
## as always:
##   - ARROW: a fat brass dart: two barbs of the same shape, one to the
##     right and one down, each the mirror of the other across the diagonal
##     (the user wanted it symmetric), with a barely hollow back between
##     them. The barb on the right is lit, the one below in shade. The front
##     edges step two blocks across per block down, so they stay straight;
##   - POINTING_HAND: the white cartoon glove (the one of `GloveFx`) on a
##     brass cuff, for anything that can be clicked;
##   - CROSS: a brass gunsight, on the seats while a target is being chosen;
##   - FORBIDDEN: a red no-entry disc. A button showing the glove shows this
##     instead while it is disabled (`_input`), so a control that has to wait
##     says so before it is clicked;
##   - CAN_DROP / DRAG / MOVE: the glove open, and closed on what it holds
##     (the suspect book, dragged);
##   - IBEAM, WAIT, BUSY, VSIZE, HSIZE: a brass I-beam, a brass hourglass with
##     sand, the arrow with a small hourglass, and double arrows.
##
## The cursor is not stretched with the window, so the bitmaps are painted
## again whenever the window changes size (`_paint`), with blocks of `CELL`
## px of the 1152x648 layout (the user found 2 px, as everything else, too
## big, and 1.25 too small). A block that does not come out a whole number of
## screen pixels is painted at the next whole size and scaled down. Hung at the root as
## `/root/Cursors` by `Settings.ensure_loaded`; nothing is set on a phone.

const NODE_NAME := "Cursors"

## Block size on a 1152x648 window: 2.5 px on a 1920x1080 screen.
const CELL := 1.5
## How dark the shadow under a cursor is.
const SHADOW := 0.35

const INKS := {
	"o": Color("160c08"),
	"1": Color("7d5616"), "2": Color("b48c2f"), "3": Color("e6bc4c"), "4": Color("f5d983"), "5": Color("fff4cf"),
	"c": Color("f1e3c0"), "C": Color("c9b38a"), "w": Color("fffbee"),
	"r": Color("c8402f"), "R": Color("8a241a"), "p": Color("e86a52"),
	"y": Color("e0a83c"), "Y": Color("a87222"), "g": Color(0.945, 0.89, 0.753, 0.27),
}

const ARROW: Array[String] = [
	"oooo................",
	"o35ooo..............",
	"o2354ooo............",
	"oo23544ooo..........",
	".o1235444ooo........",
	".oo12354444ooo......",
	"..o1123544444ooo....",
	"..oo11235444444ooo..",
	"...o1112354444444oo.",
	"...oo1112354444444oo",
	"....o11112oo4444444o",
	"....oo1111oooooooooo",
	".....o11111o........",
	".....oo1111o........",
	"......o1111o........",
	"......oo111o........",
	".......o111o........",
	".......oo11o........",
	"........oo1o........",
	".........ooo........",
]
const POINT: Array[String] = [
	".....oo.........",
	"....owco........",
	"....occo........",
	"....occo........",
	"....occooo......",
	"....occowcoo....",
	"....occoccowoo..",
	".oo.occoccocowo.",
	"owcoocccccccocCo",
	"owcCocccccccccCo",
	".owccccccccccCCo",
	"..owcccccccccCCo",
	"..occcccccccccCo",
	"...occcccccccCo.",
	"....occcccccCo..",
	"....o4444443o...",
	"....o3332333o...",
	"....o2222221o...",
	"....oooooooo....",
]
const GRAB: Array[String] = [
	"................",
	"................",
	"................",
	"................",
	".....oo.oo.oo...",
	"....owcowcowco..",
	"...ooccoccoccCo.",
	"..owcccCccCccCo.",
	".owccccccccccCo.",
	".occcccccccccCCo",
	".owccccccccccCCo",
	"..owcccccccccCCo",
	"..occcccccccccCo",
	"...occcccccccCo.",
	"....occcccccCo..",
	"....o4444443o...",
	"....o3332333o...",
	"....o2222221o...",
	"....oooooooo....",
]
const OPEN: Array[String] = [
	"......oo.oo.....",
	".....owcowco.oo.",
	".....occoccoowco",
	".....occoccoocCo",
	".oo..occoccoocCo",
	"owco.occoccoocCo",
	"occo.occoccooccC",
	".occooccccccccCo",
	".owcccccccccccCo",
	"..owccccccccccCo",
	"..occccccccccCCo",
	"...occcccccccCo.",
	"...occcccccccCo.",
	"....occcccccCo..",
	"....occcccccCo..",
	"....o4444443o...",
	"....o3332333o...",
	"....o2222221o...",
	"....oooooooo....",
]
const IBEAM: Array[String] = [
	"ooo.ooo",
	"o5ooo3o",
	"ooo4ooo",
	"..o4o..",
	"..o4o..",
	"..o4o..",
	"..o4o..",
	"..o4o..",
	"..o3o..",
	"..o3o..",
	"..o3o..",
	"..o3o..",
	"..o3o..",
	"..o3o..",
	"ooo3ooo",
	"o4ooo2o",
	"ooo.ooo",
]
const WAIT: Array[String] = [
	"ooooooooooo",
	"o554443322o",
	"ooooooooooo",
	".owggggggo.",
	".oyyyyyyyo.",
	"..oYyyyYo..",
	"...oYyYo...",
	"....oyo....",
	"...ogyCo...",
	"..oggyggo..",
	".oggyyyggo.",
	".ogyyyyyCo.",
	".oYyyyyyYo.",
	"ooooooooooo",
	"o554443322o",
	"ooooooooooo",
]
const BUSY: Array[String] = [
	"oooo................",
	"o35ooo..............",
	"o2354ooo............",
	"oo23544ooo..........",
	".o1235444ooo........",
	".oo12354444ooo......",
	"..o1123544444ooo....",
	"..oo11235444444ooo..",
	"...o1112354444444oo.",
	"...oo1112354444444oo",
	"....o11112oo4444444o",
	"....oo1111oooooooooo",
	".....o11111o.ooooooo",
	".....oo1111o.o54432o",
	"......o1111o.ooooooo",
	"......oo111o..oyyyo.",
	".......o111o...oyo..",
	".......oo11o..ogygo.",
	"........oo1o..oyyyo.",
	".........ooo.ooooooo",
	".............o54432o",
	".............ooooooo",
]
const FORBIDDEN: Array[String] = [
	"....ooooooo....",
	"..ooopppppooo..",
	".oorpppppprroo.",
	".orrrooooorrro.",
	"ooprrroo.oorroo",
	"opporrroo.oorRo",
	"oppoorrroo.oRRo",
	"oppooorrroooRRo",
	"oppo.oorrrooRRo",
	"oppoo.oorRRoRRo",
	"oorroo.ooRRRRoo",
	".orrroooooRRRo.",
	".oorrrRRRRRRoo.",
	"..oooRRRRRooo..",
	"....ooooooo....",
]
const SIGHT: Array[String] = [
	"........ooo........",
	"........o3o........",
	"......ooo3ooo......",
	"....ooo44344ooo....",
	"...oo44oo3oo44oo...",
	"...o44ooo3ooo22o...",
	"..oo4oo.o3o.oo2oo..",
	"..o4oo..ooo..oo2o..",
	"ooo4ooooooooooo2ooo",
	"o333333ooroo333333o",
	"ooo4ooooooooooo2ooo",
	"..o4oo..ooo..oo2o..",
	"..oo4oo.o3o.oo2oo..",
	"...o42ooo3ooo22o...",
	"...oo22oo3oo22oo...",
	"....ooo22322ooo....",
	"......ooo3ooo......",
	"........o3o........",
	"........ooo........",
]
const VSIZE: Array[String] = [
	"....o....",
	"...o5o...",
	"..o543o..",
	".o54332o.",
	"ooo43oooo",
	"...o3o...",
	"...o3o...",
	"...o3o...",
	"...o3o...",
	"...o3o...",
	"ooo42oooo",
	".o5432o..",
	"..o432o..",
	"...o2o...",
	"....o....",
]

## Each shape: its bitmap and the hot spot, in blocks (x.5 is the middle of
## a block). HSIZE is VSIZE on its side.
const SHAPES := {
	Input.CURSOR_ARROW: [ARROW, Vector2(0.5, 0.5)],
	Input.CURSOR_POINTING_HAND: [POINT, Vector2(5.5, 0)],
	Input.CURSOR_CROSS: [SIGHT, Vector2(9.5, 9.5)],
	Input.CURSOR_FORBIDDEN: [FORBIDDEN, Vector2(7.5, 7.5)],
	Input.CURSOR_CAN_DROP: [OPEN, Vector2(8, 9)],
	Input.CURSOR_DRAG: [GRAB, Vector2(8, 10)],
	Input.CURSOR_MOVE: [GRAB, Vector2(8, 10)],
	Input.CURSOR_IBEAM: [IBEAM, Vector2(3.5, 8.5)],
	Input.CURSOR_WAIT: [WAIT, Vector2(5.5, 8)],
	Input.CURSOR_BUSY: [BUSY, Vector2(0.5, 0.5)],
	Input.CURSOR_VSIZE: [VSIZE, Vector2(4.5, 7.5)],
	Input.CURSOR_HSIZE: [VSIZE, Vector2(7.5, 4.5)],
}

var _cell := 0.0


static func install() -> void:
	if OS.has_feature("mobile") or DisplayServer.get_name() == "headless":
		return
	var root := (Engine.get_main_loop() as SceneTree).root
	if root.has_node(NODE_NAME):
		return
	var node: Node = new()
	node.name = NODE_NAME
	root.add_child.call_deferred(node)


func _ready() -> void:
	get_viewport().size_changed.connect(_paint)
	_paint()


## Paints every cursor again in blocks the size the window shows a block of
## the layout at (never smaller than a pixel, never past Godot's 256 px).
func _paint() -> void:
	var stretch := get_viewport().get_final_transform().get_scale()
	var cell := clampf(snappedf(CELL * minf(stretch.x, stretch.y), 0.25), 1.0, 8.0)
	if cell == _cell:
		return
	_cell = cell
	var whole := ceili(cell)
	for shape: int in SHAPES:
		var rows: Array[String] = SHAPES[shape][0]
		var spot: Vector2 = SHAPES[shape][1]
		var image := _picture(rows, whole, shape == Input.CURSOR_HSIZE)
		if whole != cell:
			var fit := (Vector2(image.get_size()) * cell / whole).round()
			image.resize(int(fit.x), int(fit.y), Image.INTERPOLATE_BILINEAR)
		Input.set_custom_mouse_cursor(image, shape as Input.CursorShape, (spot * cell).floor())


## The bitmap in blocks of `cell` px, with its shadow; `sideways` turns it a
## quarter (rows become columns).
static func _picture(rows: Array[String], cell: int, sideways: bool) -> Image:
	var tall := rows.size()
	var wide := rows[0].length()
	var w := tall if sideways else wide
	var h := wide if sideways else tall
	var image := Image.create_empty((w + 1) * cell, (h + 1) * cell, false, Image.FORMAT_RGBA8)
	for layer in 2:
		for y in tall:
			for x in wide:
				var ink := rows[y][x]
				if ink == ".":
					continue
				var at := Vector2i(y, x) if sideways else Vector2i(x, y)
				var color: Color = Color(0, 0, 0, SHADOW) if layer == 0 else INKS[ink]
				if layer == 0:
					at += Vector2i.ONE
				image.fill_rect(Rect2i(at * cell, Vector2i(cell, cell)), color)
	return image


## A button that shows the glove shows the no-entry disc while it is disabled.
## Looked at on every move of the mouse, before the GUI picks the cursor.
func _input(event: InputEvent) -> void:
	if not event is InputEventMouseMotion:
		return
	var button := get_viewport().gui_get_hovered_control() as BaseButton
	if button == null:
		return
	if button.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND and button.disabled:
		button.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
		button.set_meta(&"cursor_refused", true)
	elif not button.disabled and button.has_meta(&"cursor_refused"):
		button.remove_meta(&"cursor_refused")
		if button.mouse_default_cursor_shape == Control.CURSOR_FORBIDDEN:
			button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
