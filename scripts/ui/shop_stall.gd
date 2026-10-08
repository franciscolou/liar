extends Control
## The shop's backdrop: a display case built into the saloon wall. A beam
## across the top carries the titles, the goods stand on shelves in front of
## a back wall of planks, and the deck lies in a felt-lined tray at the right
## end. It is drawn to whatever size it is given (the shop folds and opens)
## and anchored to its right edge, so the tray never moves. No class name:
## preload it (see table.gd).

const PX := 2.0
## Height of the beam the titles are painted on, and width of the frame on
## the other three sides.
const BEAM := 16.0
const EDGE := 6.0

const INK := Color("160c08")
const WALL: Array[Color] = [Color("3b2216"), Color("331c12")]
const SEAM := Color("1e100a")
const GRAIN := Color("2a160d")
const FRAME := Color("4a2e1a")
const FRAME_LIGHT := Color("6b4526")
const FRAME_DARK := Color("2e1b0e")
const SHELF_TOP := Color("a06e3c")
const SHELF_FRONT := Color("6a4324")
const FELT := Color("1f3a2c")
const FELT_LIGHT := Color("2a4c3a")
const FELT_DARK := Color("12241b")
const BRASS_DARK := Color("7d5616")
## A corner bracket, as seen in the top left corner: brass, with a rivet.
const BRACKET := [
	"######",
	"#o####",
	"###...",
	"##....",
	"##....",
	"##....",
]

## Clicked to stay open: the inlay of the frame lights up.
var pinned := false:
	set(value):
		pinned = value
		queue_redraw()
## Where the top of each shelf is, from the top of the case.
var shelves: Array[float] = []:
	set(value):
		shelves = value
		queue_redraw()
## How much of the right end is the tray of the deck.
var tray := 0.0:
	set(value):
		tray = value
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(0, 0, w, h), INK)

	# The back wall: planks counted from the right, so that they stay put
	# while the left edge slides.
	var plank := 0
	var right := w - PX
	while right > PX:
		var left := maxf(right - 18.0, PX)
		draw_rect(Rect2(left, PX, right - left, h - PX * 2.0), WALL[plank % 2])
		draw_rect(Rect2(left, PX, PX, h - PX * 2.0), SEAM)
		# The grain: a few strokes, always the same ones on the same plank.
		for stroke in 3:
			var mark := plank * 7 + stroke * 13
			var x := right - 4.0 - (mark * 5 % 6) * PX
			var y := BEAM + 6.0 + (mark * 11 % 30) * PX
			if x > left + PX:
				draw_rect(Rect2(x, y, PX, 6.0 + (mark % 4) * 4.0), GRAIN)
		right = left
		plank += 1

	var shelf_end := w - EDGE
	if tray > 0.0:
		# The tray: felt, sunk into the case, lit from the top left.
		var felt := Rect2(w - tray + 6.0, BEAM + PX, tray - 14.0, h - BEAM - PX - 8.0)
		draw_rect(felt.grow(PX), FRAME_DARK)
		draw_rect(felt, FELT)
		draw_rect(Rect2(felt.position, Vector2(felt.size.x, PX)), FELT_DARK)
		draw_rect(Rect2(felt.position, Vector2(PX, felt.size.y)), FELT_DARK)
		draw_rect(Rect2(felt.position.x + PX, felt.end.y - PX, felt.size.x - PX, PX), FELT_LIGHT)
		draw_rect(Rect2(felt.end.x - PX, felt.position.y + PX, PX, felt.size.y - PX), FELT_LIGHT)
		# The post between the shelves and the tray.
		shelf_end = w - tray - PX
		draw_rect(Rect2(shelf_end, BEAM, 4.0, h - BEAM - EDGE), FRAME)
		draw_rect(Rect2(shelf_end, BEAM, PX, h - BEAM - EDGE), FRAME_LIGHT)

	for top: float in shelves:
		if shelf_end - EDGE < 8.0:
			break
		draw_rect(Rect2(EDGE, top, shelf_end - EDGE, PX), SHELF_TOP)
		draw_rect(Rect2(EDGE, top + PX, shelf_end - EDGE, PX), SHELF_FRONT)
		draw_rect(Rect2(EDGE, top + PX * 2.0, shelf_end - EDGE, PX), Color(0, 0, 0, 0.45))
		draw_rect(Rect2(EDGE, top + PX * 3.0, shelf_end - EDGE, PX), Color(0, 0, 0, 0.2))
	if not shelves.is_empty() and shelf_end - EDGE >= 8.0:
		# Under the last shelf it is the front of the counter: darker, for
		# the price tags to stand out on.
		var under: float = shelves.max() + PX * 2.0
		draw_rect(Rect2(EDGE, under, shelf_end - EDGE, h - EDGE - under), Color(0, 0, 0, 0.28))

	# The frame: a beam across the top and a narrow moulding round the rest.
	draw_rect(Rect2(PX, PX, w - PX * 2.0, BEAM - PX * 2.0), FRAME)
	draw_rect(Rect2(PX, PX, w - PX * 2.0, PX), FRAME_LIGHT)
	draw_rect(Rect2(PX, BEAM - PX * 2.0, w - PX * 2.0, PX), FRAME_DARK)
	draw_rect(Rect2(PX, BEAM + PX, w - PX * 2.0, PX), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(PX, BEAM, PX, h - BEAM - PX), FRAME_LIGHT)
	draw_rect(Rect2(w - PX * 2.0, BEAM, PX, h - BEAM - PX), FRAME_DARK)
	draw_rect(Rect2(PX, h - PX * 2.0, w - PX * 2.0, PX), FRAME_DARK)
	# The inlay, just inside it.
	var inlay := UI.GOLD if pinned else UI.BORDER
	draw_rect(Rect2(PX * 2.0, BEAM - PX, w - PX * 4.0, PX), inlay)
	draw_rect(Rect2(PX * 2.0, h - PX * 3.0, w - PX * 4.0, PX), inlay)
	draw_rect(Rect2(PX * 2.0, BEAM - PX, PX, h - BEAM - PX), inlay)
	draw_rect(Rect2(w - PX * 3.0, BEAM - PX, PX, h - BEAM - PX), inlay)

	var brass := UI.GOLD if pinned else UI.GOLD.darkened(0.2)
	for corner in 4:
		_bracket(Vector2(w if corner % 2 == 1 else 0.0, h if corner >= 2 else 0.0),
				Vector2(-1 if corner % 2 == 1 else 1, -1 if corner >= 2 else 1), brass)


## A corner bracket with its corner at `at`, opening towards `way`.
func _bracket(at: Vector2, way: Vector2, brass: Color) -> void:
	for y: int in BRACKET.size():
		var row: String = BRACKET[y]
		for x: int in row.length():
			if row[x] == ".":
				continue
			var cell := at + Vector2(x, y) * PX * way
			# A pixel that grows away from `at` starts one pixel short of it.
			cell -= Vector2(PX if way.x < 0.0 else 0.0, PX if way.y < 0.0 else 0.0)
			var outer := x == 0 or y == 0
			draw_rect(Rect2(cell, Vector2(PX, PX)), BRASS_DARK if outer else (UI.CREAM if row[x] == "o" else brass))
