extends "res://scripts/ui/noir_desk.gd"
## The things of the house (the ranked screens) that lie on the desk, drawn
## like the rest of it (noir_desk.gd, whose brushes this borrows) in blocks
## of 2 px. `look` says which one a node is:
##
## - INVITE: the house's card on the room screen, black stock with a frame of
##   gold foil, a wax seal and its ribbons at the foot;
## - MEMBER: the member's card of the ranked screen, the same stock and foil,
##   with the medal of their rank (`tier`) struck at `medal_at`;
## - WATCH: a gold pocket watch with its chain, which keeps the time of the
##   queue (`stopwatch`) or the time of day;
## - LEDGER: an open ledger, green cloth with red leather corners, its pages
##   ruled for the standings (`rows_from`, `row`, `columns`);
## - GAZETTE: the house's newspaper, folded on the desk (ranked screen);
## - NEWSPAPER: the same newspaper opened out (the figures screen), with its
##   masthead rules (`mast`), column rules (`columns`) and print (`print`);
## - FOLDER: a manila folder with a tab (`tab`), the member's file, with a
##   typed sheet clipped inside it;
## - BADGE: a little card of the same stock, a fine line of foil round it,
##   that turns a room of the lobby ranked (setup_screen.gd); its foil `lit`
##   (the desk's own flag) when it is.
##
## Like the rest of the desk, they are only backdrops: the screens put the
## words on them. The charts (`Bar`, `Chart`, `Places`, `Form`) and the stamp
## (`Stamp`) are classes of their own at the end. No class name: preload it.

enum Look { NONE, INVITE, MEMBER, WATCH, LEDGER, GAZETTE, NEWSPAPER, FOLDER, BADGE }

const STOCK := Color("16110d")
const STOCK_LIGHT := Color("251b14")
const FOIL := Color("d6a63e")
const FOIL_LIGHT := Color("f6dc86")
const FOIL_DARK := Color("8a6420")
const WAX := Color("8a1716")
const WAX_LIGHT := Color("bb3428")
const WAX_DARK := Color("4a0a0a")
const SILK := Color("7a1418")
const SILK_LIGHT := Color("a8262a")
const CLOTH := Color("23402c")
const CLOTH_LIGHT := Color("355a3f")
const CLOTH_DARK := Color("142619")
const CORNER := Color("6a1a14")
const CORNER_LIGHT := Color("8e2a1e")
const NEWSPRINT := Color("d8d0b6")
const NEWSPRINT_DARK := Color("b9af92")
const NEWS_INK := Color("1d1915")
const NEWS_GREY := Color(0.11, 0.1, 0.08, 0.32)
const MANILA := Color("cfa863")
const MANILA_LIGHT := Color("e2c283")
const MANILA_DARK := Color("9d7a3c")
const ENAMEL := Color("efe6cf")
const ENAMEL_SHADE := Color("d4c7a6")
const BLUED := Color("1f2a44")
const HIGHLIGHT := Color(0.98, 0.86, 0.2, 0.42)

## The ranks of the house, from the bottom: the rating each starts at, its
## name, and the metal and the enamel of its medal. A member who has not
## played yet is a newcomer, whatever their rating.
const TIERS := [
	{"from": -INF, "name": "Drifter", "metal": Color("8e949a"), "enamel": Color("3c4148"), "glyph": "shoe"},
	{"from": 900.0, "name": "Card Sharp", "metal": Color("b8743a"), "enamel": Color("3a1f14"), "glyph": "spade"},
	{"from": 1100.0, "name": "High Roller", "metal": Color("c9ccd2"), "enamel": Color("1d3150"), "glyph": "die"},
	{"from": 1300.0, "name": "Kingpin", "metal": Color("e0b04a"), "enamel": Color("4a0f14"), "glyph": "crown"},
	{"from": 1500.0, "name": "Legend", "metal": Color("f3d573"), "enamel": Color("101010"), "glyph": "star"},
]
const NEWCOMER := {"name": "Newcomer", "metal": Color("9a8a6a"), "enamel": Color("2a2218"), "glyph": "ask"}
## The pictures struck in the medals, a block each.
const GLYPHS := {
	"shoe": ["#.....#", "#.....#", "#.....#", "##...##", ".#####.", "..###.."],
	"spade": ["...#...", "..###..", ".#####.", "#######", "#######", ".#.#.#.", "...#...", "..###.."],
	"die": ["#######", "#.....#", "#.#.#.#", "#.....#", "#.#.#.#", "#.....#", "#######"],
	"crown": ["#..#..#", "##.#.##", "#######", "#######", ".#####."],
	"star": ["...#...", "...#...", "#######", ".#####.", "..###..", ".##.##.", "#.....#"],
	"ask": [".###.", "#...#", "...#.", "..#..", ".....", "..#.."],
}
## The crown pressed into the wax of the invitation.
const SEAL_CROWN := ["#...#...#", "##.###.##", "#########", "#########", ".#######."]

var look := Look.NONE
## MEMBER: where the medal is, and which rank (an index of TIERS, -1 a newcomer).
var medal_at := Vector2.ZERO
var tier := -1:
	set(value):
		tier = value
		queue_redraw()
## WATCH: how many seconds the stopwatch has run (null: it shows the time of day).
var stopwatch: Variant = null
## LEDGER: where the first rule of each page is, the height of a row, and the
## columns ruled in red, from the left of each page.
var rows_from := 70.0
var row := 30.0
var columns: Array[float] = []
## LEDGER: rows to mark with a highlighter: [page, row].
var marked: Array[Vector2i] = []:
	set(value):
		marked = value
		queue_redraw()
## NEWSPAPER: the y of the masthead's rules; the column rules, as
## Vector4(x, top, x, bottom); and the blocks filled with print nobody reads,
## as Rect2s.
var mast := 0.0
var rules: Array[Vector4] = []
var print_at: Array[Rect2] = []
## INVITE: the y of the rule of foil under the heading.
var parting := 92.0:
	set(value):
		parting = value
		queue_redraw()
## FOLDER: how wide its tab is.
var tab := 150.0

var _ticks := 0.0


## One of the things above, as large as `rect` and where it says.
static func of(what: Look, rect: Rect2):
	var thing = load("res://scripts/ui/house_props.gd").new()
	thing.look = what
	thing.kind = Kind.SHEET
	thing.dog_ear = false
	thing.position = rect.position
	thing.size = rect.size
	thing.pivot_offset = rect.size / 2.0
	return thing


## The rank of a member with `rating` who has played `matches` (an index of
## TIERS, -1 for a newcomer).
static func tier_of(rating: float, matches: int) -> int:
	if matches <= 0:
		return -1
	var found := 0
	for i in TIERS.size():
		if rating >= TIERS[i].from:
			found = i
	return found


static func tier_name(index: int) -> String:
	return NEWCOMER.name if index < 0 else TIERS[index].name


func _ready() -> void:
	super()
	if look == Look.WATCH:
		set_process(true)


func _process(delta: float) -> void:
	if look != Look.WATCH:
		super(delta)
		return
	# A pocket watch beats five times a second.
	_ticks += delta
	if _ticks >= 0.2:
		_ticks = fmod(_ticks, 0.2)
		queue_redraw()


func _draw() -> void:
	match look:
		Look.NONE:
			super()
		Look.INVITE:
			_invite()
		Look.MEMBER:
			_member()
		Look.WATCH:
			_watch()
		Look.LEDGER:
			_ledger()
		Look.GAZETTE:
			_gazette()
		Look.NEWSPAPER:
			_newspaper()
		Look.FOLDER:
			_folder()
		Look.BADGE:
			_badge()


# --- black stock and gold foil -------------------------------------------------

## A block of foil: it catches the lamp in a band running across the card.
func _foil(x: float, y: float, w := PX, h := PX, dim := false) -> void:
	var band := fposmod(x * 0.7 + y - size.x * 0.4, 260.0)
	var color := FOIL
	if band < 18.0:
		color = FOIL_LIGHT
	elif band < 40.0 or band > 250.0:
		color = FOIL.lerp(FOIL_LIGHT, 0.45)
	elif band > 150.0 and band < 200.0:
		color = FOIL.lerp(FOIL_DARK, 0.4)
	if dim:
		color = color.lerp(FOIL_DARK, 0.5)
	_b(x, y, w, h, color)


## A line of foil, block by block, so that the sheen runs along it.
func _foil_line(from: Vector2, to: Vector2, dim := false) -> void:
	var steps := int(maxf(absf(to.x - from.x), absf(to.y - from.y)) / PX)
	for i in steps + 1:
		var at := (from.lerp(to, float(i) / maxf(steps, 1)) / PX).floor() * PX
		_foil(at.x, at.y, PX, PX, dim)


func _stock(rect: Rect2) -> void:
	_shadow(rect, Vector2(4, 6) + Vector2(_lift, _lift) * 1.5)
	draw_rect(rect, STOCK)
	# The stock has a tooth to it.
	var salt := int(roundf(rect.size.x) * 5.0 + roundf(rect.size.y) * 3.0)
	for speck in int(rect.size.x * rect.size.y / 260.0):
		var x := rect.position.x + floorf(_roll(salt + speck * 2) * (rect.size.x - PX) / PX) * PX
		var y := rect.position.y + floorf(_roll(salt + speck * 2 + 1) * (rect.size.y - PX) / PX) * PX
		_b(x, y, PX, PX, STOCK_LIGHT if speck % 3 else Color(0, 0, 0, 0.4))
	_b(rect.position.x, rect.position.y, rect.size.x, PX, STOCK_LIGHT.lightened(0.1))
	_b(rect.position.x, rect.position.y, PX, rect.size.y, STOCK_LIGHT)
	_b(rect.end.x - PX, rect.position.y, PX, rect.size.y, Color("0a0806"))
	_b(rect.position.x, rect.end.y - PX, rect.size.x, PX, Color("0a0806"))


## The frame of an art deco card: a line of foil, a finer one inside it, fans
## in the corners and a sunburst at the head and the foot.
func _deco(rect: Rect2, bursts := true) -> void:
	var outer := rect.grow(-8.0)
	var inner := rect.grow(-14.0)
	for r: Rect2 in [outer]:
		_foil_line(r.position, Vector2(r.end.x - PX, r.position.y))
		_foil_line(Vector2(r.position.x, r.end.y - PX), r.end - Vector2(PX, PX))
		_foil_line(r.position, Vector2(r.position.x, r.end.y - PX))
		_foil_line(Vector2(r.end.x - PX, r.position.y), r.end - Vector2(PX, PX))
	var gap := 30.0
	# The inner line stops short of the corners, where the fans are.
	_foil_line(inner.position + Vector2(gap, 0), Vector2(inner.end.x - gap, inner.position.y), true)
	_foil_line(Vector2(inner.position.x + gap, inner.end.y - PX), Vector2(inner.end.x - gap, inner.end.y - PX), true)
	_foil_line(inner.position + Vector2(0, gap), Vector2(inner.position.x, inner.end.y - gap), true)
	_foil_line(Vector2(inner.end.x - PX, inner.position.y + gap), Vector2(inner.end.x - PX, inner.end.y - gap), true)
	for corner in 4:
		var right := corner % 2 == 1
		var low := corner >= 2
		var at := Vector2(inner.end.x - PX if right else inner.position.x, inner.end.y - PX if low else inner.position.y)
		var way := Vector2(-1 if right else 1, -1 if low else 1)
		# Quarter rings, stepped, round the corner.
		for radius: float in [10.0, 18.0, 26.0]:
			var steps := int(radius * 1.6 / PX)
			for i in steps + 1:
				var a := i / float(steps) * PI / 2.0
				var p := at + Vector2(cos(a), sin(a)) * radius * way
				p = (p / PX).floor() * PX
				_foil(p.x, p.y, PX, PX, radius > 20.0)
		# A diamond in the corner itself.
		for d in 3:
			_foil(at.x + way.x * (4 + d * PX) - (PX if way.x < 0 else 0.0), at.y + way.y * 4, PX, PX)
			_foil(at.x + way.x * 4, at.y + way.y * (4 + d * PX) - (PX if way.y < 0 else 0.0), PX, PX)
	if not bursts:
		return
	# The sunburst, its rays fanning from just inside the frame.
	for foot in 2:
		var base := Vector2(roundf(rect.size.x / 2.0 / PX) * PX + rect.position.x, inner.position.y + 4.0 if foot == 0 else inner.end.y - 6.0)
		var down := 1.0 if foot == 0 else -1.0
		for ray in 9:
			var angle := lerpf(-1.05, 1.05, ray / 8.0)
			var length := 22.0 if ray % 2 == 0 else 13.0
			var tip := base + Vector2(sin(angle), cos(angle) * down) * length
			_foil_line(base + Vector2(sin(angle), cos(angle) * down) * 5.0, tip, ray % 2 == 1)
		_foil(base.x - PX, base.y - (PX if down < 0 else 0.0), PX * 2.0, PX * 2.0)


func _invite() -> void:
	var card := Rect2(Vector2.ZERO, size - Vector2(0, 16))
	_stock(card)
	_deco(card)
	# A rule of foil under the heading, with a diamond in it.
	var mid := roundf(size.x / 2.0 / PX) * PX
	var y := roundf(parting / PX) * PX
	_foil_line(Vector2(42, y), Vector2(mid - 10, y), true)
	_foil_line(Vector2(mid + 10, y), Vector2(size.x - 44, y), true)
	for d in 3:
		_foil(mid - PX * (d + 1), y - PX * (2 - d), PX * (d + 1) * 2.0, PX)
		_foil(mid - PX * (d + 1), y + PX * (2 - d), PX * (d + 1) * 2.0, PX)
	# Sealed at the corner, as a certificate is.
	_seal((Vector2(size.x - 62.0, card.end.y - 10.0) / PX).floor() * PX)


func _badge() -> void:
	var card := Rect2(Vector2.ZERO, size)
	_stock(card)
	var r := card.grow(-6.0)
	_foil_line(r.position, Vector2(r.end.x - PX, r.position.y), not lit)
	_foil_line(Vector2(r.position.x, r.end.y - PX), r.end - Vector2(PX, PX), not lit)
	_foil_line(r.position, Vector2(r.position.x, r.end.y - PX), not lit)
	_foil_line(Vector2(r.end.x - PX, r.position.y), r.end - Vector2(PX, PX), not lit)
	# A diamond of foil at each corner, over the line.
	for corner in 4:
		var at := Vector2(r.end.x - PX if corner % 2 else r.position.x, r.end.y - PX if corner >= 2 else r.position.y)
		_foil(at.x - PX, at.y, PX * 3.0, PX)
		_foil(at.x, at.y - PX, PX, PX * 3.0)


## The wax seal at the foot of the card, on two tails of silk.
func _seal(at: Vector2) -> void:
	for side in 2:
		var lean := -1.0 if side == 0 else 1.0
		for step in 15:
			var x := at.x + lean * (6.0 + step * 1.4)
			var y := at.y + 6.0 + step * PX
			var cut := 0.0 if step < 12 else (step - 11) * PX * 1.5
			_b(x - 7.0 + (cut if lean > 0 else 0.0), y + 2.0, 14.0 - cut, PX, Color(0, 0, 0, 0.3))
			_b(x - 8.0 + (cut if lean > 0 else 0.0), y, 14.0 - cut, PX, SILK if step % 4 else SILK_LIGHT)
			_b(x - 8.0, y, PX, PX, SILK_LIGHT)
	var r := 26.0
	_disc(at + Vector2(4, 6), r, Color(0, 0, 0, 0.4))
	# Wax is never quite round: it spread where it was poured.
	for lobe in 7:
		var way := Vector2.from_angle(lobe * TAU / 7.0 + 0.3)
		_disc(((at + way * (r - 6.0)) / PX).floor() * PX, 8.0 + _roll(lobe + 70) * 4.0, WAX_DARK)
	_disc(at, r, WAX_DARK)
	_disc(at + Vector2(-PX, -PX), r - PX, WAX)
	_disc(at, r - 7.0, WAX_DARK)
	_disc(at + Vector2(PX, PX), r - 8.0, WAX_LIGHT)
	_disc(at, r - 8.0, WAX)
	# The crown, raised: lit along the top and the left.
	var origin := at - Vector2(9, 5) * PX / 2.0 - Vector2(0, 2)
	for row in SEAL_CROWN.size():
		var line: String = SEAL_CROWN[row]
		for column in line.length():
			if line[column] != "#":
				continue
			var cell := origin + Vector2(column, row) * PX
			_b(cell.x + PX, cell.y + PX, PX, PX, WAX_DARK)
			_b(cell.x, cell.y, PX, PX, WAX_LIGHT)
	_b(at.x - 10, at.y + 8, 20, PX, WAX_DARK)
	_b(at.x - 10, at.y + 7, 20, 1, WAX_LIGHT)
	# The lamp in the wax.
	_b(at.x - 16, at.y - 16, 6, PX, Color(1, 0.8, 0.7, 0.6))
	_b(at.x - 18, at.y - 12, PX, 4, Color(1, 0.8, 0.7, 0.6))


func _member() -> void:
	var card := Rect2(Vector2.ZERO, size)
	_stock(card)
	_deco(card, false)
	medal(self, medal_at, tier, 30.0)


## The medal of rank `index` (see TIERS) on `canvas`, `radius` across, its
## glyph struck in the middle. Static, for the ledger's rows too.
static func medal(canvas: CanvasItem, at: Vector2, index: int, radius: float) -> void:
	var look_of: Dictionary = NEWCOMER if index < 0 else TIERS[index]
	var metal: Color = look_of.metal
	var enamel: Color = look_of.enamel
	_disc_on(canvas, at + Vector2(3, 4), radius, Color(0, 0, 0, 0.45))
	_disc_on(canvas, at, radius, metal.darkened(0.45))
	_disc_on(canvas, at + Vector2(-PX, -PX), radius - PX, metal.lightened(0.3))
	_disc_on(canvas, at, radius - PX, metal)
	# A milled rim, then the enamel field.
	var notches := int(radius * 1.2)
	for n in notches:
		var p := ((at + Vector2.from_angle(n * TAU / notches) * (radius - 3.0)) / PX).floor() * PX
		canvas.draw_rect(Rect2(p, Vector2(PX, PX)), metal.darkened(0.3))
	_disc_on(canvas, at, radius - 6.0, metal.darkened(0.4))
	_disc_on(canvas, at, radius - 8.0, enamel)
	_disc_on(canvas, at + Vector2(-PX * 2.0, -PX * 2.0), (radius - 8.0) * 0.5, enamel.lightened(0.08))
	var rows: Array = GLYPHS[look_of.glyph]
	var cell := maxf(PX, floorf(radius / 9.0 / PX) * PX)
	var w: float = (rows[0] as String).length() * cell
	var origin := ((at - Vector2(w, rows.size() * cell) / 2.0) / PX).floor() * PX
	for r in rows.size():
		var line: String = rows[r]
		for c in line.length():
			if line[c] == "#":
				var p := origin + Vector2(c, r) * cell
				canvas.draw_rect(Rect2(p + Vector2(PX, PX), Vector2(cell, cell)), Color(0, 0, 0, 0.5))
				canvas.draw_rect(Rect2(p, Vector2(cell, cell)), metal.lightened(0.15))
	# The lamp on the rim.
	canvas.draw_rect(Rect2(at + Vector2(-radius * 0.62, -radius * 0.62), Vector2(PX * 3.0, PX)).abs(), Color(1, 1, 0.92, 0.8))


static func _disc_on(canvas: CanvasItem, centre: Vector2, radius: float, color: Color) -> void:
	var y := -radius
	while y < radius:
		var half := floorf(sqrt(maxf(radius * radius - (y + PX / 2.0) * (y + PX / 2.0), 0.0)) / PX) * PX
		if half > 0.0:
			canvas.draw_rect(Rect2(centre.x - half, centre.y + y, half * 2.0, PX), color)
		y += PX


# --- the pocket watch ----------------------------------------------------------

func _watch() -> void:
	var r := floorf(minf(size.x, size.y) * 0.5 / PX) * PX - 22.0
	var c := (Vector2(size.x - r - 14.0, size.y / 2.0 + 10.0) / PX).floor() * PX
	# The chain runs off across the desk, in a slack curve, to the left.
	var bow := c + Vector2(0, -r - 18.0)
	var end := Vector2(0, c.y + r * 0.4)
	var links := 30
	for i in links:
		var t := i / float(links - 1)
		var p := bow.lerp(end, t) + Vector2(0, sin(t * PI) * r * 0.9)
		p = (p / PX).floor() * PX
		_b(p.x + 3, p.y + 4, 6, 4, Color(0, 0, 0, 0.35))
		if i % 2 == 0:
			_b(p.x - 4, p.y - PX, 8, 4, FOIL_DARK)
			_b(p.x - 2, p.y, 4, PX, Color(0, 0, 0, 0.6))
			_b(p.x - 4, p.y - PX, 6, PX, FOIL_LIGHT)
		else:
			_b(p.x - PX, p.y - 4, 4, 8, FOIL_DARK)
			_b(p.x, p.y - PX, PX, 4, Color(0, 0, 0, 0.6))
			_b(p.x - PX, p.y - 4, PX, 6, FOIL)
	# The bow, and the crown that winds it.
	_ring(bow + Vector2(0, -2), 12.0, 7.0, FOIL_DARK)
	_ring(bow + Vector2(-PX, -4), 11.0, 8.0, FOIL)
	_b(bow.x - 6, bow.y + 6, 12, 10, FOIL_DARK)
	for g in 6:
		_b(bow.x - 6 + g * PX, bow.y + 6, PX - 1, 10, FOIL if g % 2 else FOIL_LIGHT)
	_b(bow.x - 8, bow.y + 14, 16, 4, FOIL_DARK)
	# The case: a heavy rim, lit from the top left.
	_disc(c + Vector2(6, 9), r + 2.0, Color(0, 0, 0, 0.4))
	_disc(c, r, FOIL_DARK)
	_disc(c + Vector2(-PX, -PX), r - PX, FOIL_LIGHT)
	_disc(c, r - PX, FOIL)
	_disc(c + Vector2(PX, PX), r - 6.0, FOIL_DARK)
	_disc(c, r - 7.0, FOIL.lerp(FOIL_LIGHT, 0.3))
	_disc(c, r - 10.0, ENAMEL_SHADE)
	_disc(c + Vector2(-PX, -PX), r - 12.0, ENAMEL)
	# The minutes in dots, the hours in bars, the twelve doubled.
	for m in 60:
		var a := m * TAU / 60.0 - PI / 2.0
		var way := Vector2(cos(a), sin(a))
		if m % 5 == 0:
			for k in 3:
				var p := ((c + way * (r - 16.0 - k * PX)) / PX).floor() * PX
				_b(p.x, p.y, PX, PX, NEWS_INK)
			if m == 0:
				for k in 3:
					var p := ((c + way * (r - 16.0 - k * PX) + Vector2(4, 0)) / PX).floor() * PX
					_b(p.x, p.y, PX, PX, NEWS_INK)
		else:
			var p := ((c + way * (r - 15.0)) / PX).floor() * PX
			_b(p.x, p.y, PX, PX, Color(NEWS_INK, 0.55))
	# The maker's name, a little arc of red.
	_b(c.x - 10, c.y + r * 0.35, 20, PX, Color(INK_RED, 0.7))
	var seconds: float
	var minutes: float
	var hours: float
	if stopwatch != null:
		# Started at noon, as a stopwatch is.
		seconds = floorf(float(stopwatch) * 5.0) / 5.0
		minutes = seconds / 60.0
		hours = minutes / 60.0
	else:
		var now := Time.get_time_dict_from_system()
		seconds = now.second + floorf(fmod(Time.get_unix_time_from_system(), 1.0) * 5.0) / 5.0
		minutes = now.minute + seconds / 60.0
		hours = now.hour + minutes / 60.0
	_hand(c, hours / 12.0 * TAU, r * 0.42, 4.0, BLUED)
	_hand(c, minutes / 60.0 * TAU, r * 0.66, PX, BLUED)
	_hand(c, seconds / 60.0 * TAU, r * 0.74, PX, INK_RED, true)
	_disc(c, 5.0, FOIL_DARK)
	_disc(c + Vector2(-1, -1), 3.0, FOIL_LIGHT)
	# The glass catches the lamp.
	for k in 5:
		var a := -2.4 + k * 0.12
		var p := ((c + Vector2(cos(a), sin(a)) * (r - 20.0)) / PX).floor() * PX
		_b(p.x, p.y, PX, PX, Color(1, 1, 1, 0.75))
	_b(c.x - r * 0.45, c.y - r * 0.5, PX * 2.0, PX, Color(1, 1, 1, 0.5))


func _hand(c: Vector2, angle: float, length: float, width: float, color: Color, tail := false) -> void:
	var way := Vector2(sin(angle), -cos(angle))
	var from := -length * 0.22 if tail else 0.0
	var d := from
	while d < length:
		var p := ((c + way * d) / PX).floor() * PX
		var w := width if d < length - 6.0 else PX
		_b(p.x - floorf(w / 2.0 / PX) * PX, p.y - floorf(w / 2.0 / PX) * PX, w, w, color)
		d += PX * 0.8


# --- the ledger ----------------------------------------------------------------

## The two pages of the ledger, in its own coordinates.
func page(index: int) -> Rect2:
	var cover := 16.0
	var half := floorf((size.x - cover * 2.0) / 2.0 / PX) * PX
	return Rect2(cover + index * half + (6.0 if index == 1 else 0.0), cover, half - 6.0, size.y - cover * 2.0 - 8.0)


func _ledger() -> void:
	var all := Rect2(Vector2.ZERO, size)
	_shadow(all, Vector2(6, 9))
	draw_rect(all, CLOTH)
	# Cloth: a fine weave.
	for speck in int(size.x * size.y / 160.0):
		var x := floorf(_roll(speck * 2 + 4000) * (size.x - PX) / PX) * PX
		var y := floorf(_roll(speck * 2 + 4001) * (size.y - PX) / PX) * PX
		_b(x, y, PX, PX, CLOTH_LIGHT if speck % 2 else CLOTH_DARK)
	_b(0, 0, size.x, PX, CLOTH_LIGHT)
	_b(0, 0, PX, size.y, CLOTH_LIGHT)
	_b(0, size.y - PX, size.x, PX, CLOTH_DARK.darkened(0.4))
	_b(size.x - PX, 0, PX, size.y, CLOTH_DARK.darkened(0.4))
	# The leaves under the two pages, edge on.
	for index in 2:
		var p := page(index)
		for leaf in 4:
			var tone_of := PAPER_SHADE if leaf % 2 == 0 else PAPER_DARK
			_b(p.position.x + (0.0 if index == 1 else -leaf * PX), p.end.y + leaf * PX, p.size.x + leaf * PX, PX, tone_of)
			var side := p.position.x - (leaf + 1) * PX if index == 0 else p.end.x + leaf * PX
			_b(side, p.position.y + PX * 2.0, PX, p.size.y, tone_of)
	for index in 2:
		_ledger_page(index)
	# The spine between them.
	var spine := page(1).position.x - 6.0
	_b(spine, 4.0, 6.0, size.y - 8.0, CLOTH_DARK)
	_b(spine + PX, 4.0, PX, size.y - 8.0, Color(0, 0, 0, 0.5))
	# Red leather on the corners, with a fold of it showing.
	for corner in 4:
		var right := corner % 2 == 1
		var low := corner >= 2
		var reach := 46.0
		for step in int(reach / PX):
			var long := reach - step * PX
			var y := (size.y - PX - step * PX) if low else step * PX
			var x := size.x - long if right else 0.0
			_b(x, y, long, PX, CORNER if step > 0 else CORNER_LIGHT)
			_b(x + (0.0 if right else long - PX), y, PX, PX, CORNER_LIGHT if not low else Color("3c0d09"))
	# The ribbon lies down the gutter and hangs out past the foot, cut in a V.
	var ribbon := spine - 2.0
	var from := int(size.y - 110.0)
	for y in range(from, int(size.y + 36.0), 2):
		var sway := roundf(sin((y - from) * 0.045) * 3.0 / PX) * PX
		var notch := y - int(size.y + 26.0)
		_b(ribbon + sway + 3.0, y + 3.0, 10.0, PX, Color(0, 0, 0, 0.28))
		if notch > 0:
			_b(ribbon + sway, y, 5.0 - notch * 0.5, PX, SILK)
			_b(ribbon + sway + 5.0 + notch * 0.5, y, 5.0 - notch * 0.5, PX, SILK)
		else:
			_b(ribbon + sway, y, 10.0, PX, SILK)
			_b(ribbon + sway, y, PX, PX, SILK_LIGHT)
			_b(ribbon + sway + 8.0, y, PX, PX, Color("4a0a0c"))


func _ledger_page(index: int) -> void:
	var p := page(index)
	draw_rect(p, DIM_PAPER)
	# Darker into the gutter, where the page bends down into the spine.
	for step in 9:
		var w := (9 - step) * PX * 2.0
		var deep := Color(OLD_STAIN, 0.035 + step * 0.012)
		if index == 0:
			_b(p.end.x - w, p.position.y, w, p.size.y, deep)
		else:
			_b(p.position.x, p.position.y, w, p.size.y, deep)
	var seed_of := index * 1000 + int(p.size.x)
	for speck in int(p.size.x * p.size.y / 900.0):
		var x := p.position.x + 6.0 + floorf(_roll(seed_of + speck * 2) * (p.size.x - 12.0) / PX) * PX
		var y := p.position.y + 6.0 + floorf(_roll(seed_of + speck * 2 + 1) * (p.size.y - 12.0) / PX) * PX
		_b(x, y, PX, PX, Color(PAPER_DARK, 0.6))
	_b(p.position.x, p.position.y, p.size.x, PX, PAPER_LIGHT)
	# The ruling of a ledger: blue lines across, red columns down, the first
	# rule doubled under the heading.
	var y := p.position.y + rows_from
	_b(p.position.x + 4.0, y - 4.0, p.size.x - 8.0, 1, Color(INK_RED, 0.55))
	while y < p.end.y - 6.0:
		_b(p.position.x + 4.0, y, p.size.x - 8.0, 1, Color(INK_BLUE, 0.3))
		y += row
	for x: float in columns:
		_b(p.position.x + x, p.position.y + rows_from - 26.0, 1, p.size.y - rows_from + 20.0, Color(INK_RED, 0.4))
		if x == columns[0]:
			_b(p.position.x + x + 3.0, p.position.y + rows_from - 26.0, 1, p.size.y - rows_from + 20.0, Color(INK_RED, 0.4))
	# A highlighter run over the rows marked, a little ragged at the ends.
	for mark: Vector2i in marked:
		if mark.x != index:
			continue
		var top := p.position.y + rows_from + mark.y * row + 3.0
		var left := p.position.x + 6.0
		var w := p.size.x - 12.0
		_b(left + PX * 2.0, top, w - PX * 4.0, row - 6.0, HIGHLIGHT)
		for k in int((row - 6.0) / PX):
			var bite := floorf(_roll(index * 31 + k * 3 + mark.y) * 3.0) * PX
			_b(left + bite, top + k * PX, PX * 2.0 - bite, PX, HIGHLIGHT)
			_b(left + w - PX * 2.0, top + k * PX, PX * 2.0 - floorf(_roll(index * 17 + k * 5 + mark.y) * 3.0) * PX, PX, HIGHLIGHT)


# --- the newspaper -------------------------------------------------------------

func _newsprint(rect: Rect2, salt: int) -> void:
	draw_rect(rect, NEWSPRINT)
	for speck in int(rect.size.x * rect.size.y / 300.0):
		var x := rect.position.x + floorf(_roll(salt + speck * 2) * (rect.size.x - PX) / PX) * PX
		var y := rect.position.y + floorf(_roll(salt + speck * 2 + 1) * (rect.size.y - PX) / PX) * PX
		_b(x, y, PX, PX, Color(NEWSPRINT_DARK, 0.7) if speck % 4 else Color(1, 1, 1, 0.25))
	# Yellowed towards the edges.
	for band: Array in [[16.0, 0.05], [8.0, 0.07], [3.0, 0.1]]:
		var deep: float = band[0]
		var brown := Color(OLD_STAIN, band[1])
		_b(rect.position.x, rect.position.y, rect.size.x, deep, brown)
		_b(rect.position.x, rect.end.y - deep, rect.size.x, deep, brown)
		_b(rect.position.x, rect.position.y + deep, deep, rect.size.y - deep * 2.0, brown)
		_b(rect.end.x - deep, rect.position.y + deep, deep, rect.size.y - deep * 2.0, brown)


## Print nobody is meant to read: lines of grey, ragged at the right, with a
## paragraph now and then.
func _print(rect: Rect2, salt: int) -> void:
	var y := rect.position.y
	var line := 0
	while y < rect.end.y - 3.0:
		var end := 1.0 if _roll(salt + line) > 0.12 else 0.35 + _roll(salt + line + 50) * 0.5
		var x := rect.position.x + (8.0 if line % 9 == 0 else 0.0)
		var right := rect.position.x + rect.size.x * end
		while x < right - 4.0:
			var word := PX * (2.0 + floorf(_roll(salt + line * 37 + int(x)) * 5.0))
			_b(x, y, minf(word, right - x), PX, NEWS_GREY)
			x += word + PX * 1.5
		y += 6.0
		line += 1


func _newspaper() -> void:
	var all := Rect2(Vector2.ZERO, size)
	_shadow(all, Vector2(5, 7))
	_newsprint(all, 77)
	# Folded in half once, across.
	var fold := roundf(size.y * 0.5 / PX) * PX
	_b(PX, fold, size.x - PX * 2.0, PX, Color(1, 1, 1, 0.3))
	_b(PX, fold + PX, size.x - PX * 2.0, 1, Color(OLD_STAIN, 0.22))
	if mast > 0.0:
		_b(16, mast, size.x - 32.0, 6, NEWS_INK)
		_b(16, mast + 9.0, size.x - 32.0, PX, NEWS_INK)
	for r: Vector4 in rules:
		if r.y == r.w:
			_b(r.x, r.y, r.z - r.x, 1, Color(NEWS_INK, 0.7))
		else:
			_b(r.x, r.y, 1, r.w - r.y, Color(NEWS_INK, 0.55))
	for i in print_at.size():
		_print(print_at[i], 300 + i * 91)


func _gazette() -> void:
	# Folded in four: the front page, and a little of the back of it showing
	# at the top where the fold is.
	var front := Rect2(Vector2(0, 14), size - Vector2(0, 14))
	_shadow(front, Vector2(4, 6) + Vector2(_lift, _lift) * 1.5)
	_newsprint(Rect2(Vector2(8, 0), Vector2(size.x - 16.0, 18)), 11)
	_b(8, 0, size.x - 16.0, PX, NEWSPRINT_DARK)
	_newsprint(front, 23)
	_b(0, front.position.y, size.x, PX, Color(1, 1, 1, 0.5))
	_b(0, front.position.y + PX, size.x, PX, Color(OLD_STAIN, 0.3))
	var y := front.position.y + 40.0
	_b(12, y, size.x - 24.0, 4, NEWS_INK)
	_b(12, y + 6.0, size.x - 24.0, 1, NEWS_INK)
	# A picture in halftone, and the print round it.
	var picture := Rect2(14, y + 14.0, 74, front.end.y - y - 24.0)
	_halftone(picture)
	draw_rect(picture, Color(NEWS_INK, 0.8), false, 1.0)
	# Room for a headline at the top of the column, then print.
	_print(Rect2(picture.end.x + 10.0, picture.position.y + 22.0, size.x - picture.end.x - 24.0, picture.size.y - 22.0), 41)


## The picture every paper runs: a man in a hat, in a halftone of dots on a
## grid of 4 px, each dot as big as the picture is dark there.
func _halftone(picture: Rect2) -> void:
	draw_rect(picture, NEWSPRINT.darkened(0.06))
	var cells := (picture.size / 4.0).floor()
	for gy in int(cells.y):
		for gx in int(cells.x):
			var u := (gx + 0.5) / cells.x
			var v := (gy + 0.5) / cells.y
			var dark := 0.18 + 0.3 * v
			var head := Vector2(u - 0.5, (v - 0.43) * 1.25).length() < 0.17
			var brim := v > 0.24 and v < 0.29 and absf(u - 0.5) < 0.34
			var crown := v > 0.08 and v <= 0.24 and absf(u - 0.5) < 0.2
			var body := v > 0.62 and absf(u - 0.5) < 0.16 + (v - 0.62) * 1.1
			if brim or crown or body:
				dark = 0.95
			elif head:
				dark = 0.5
			var at := picture.position + Vector2(gx, gy) * 4.0
			if dark > 0.75:
				_b(at.x, at.y, 4, 4, NEWS_INK)
			elif dark > 0.4:
				_b(at.x + 1, at.y + 1, PX, PX, NEWS_INK)
				_b(at.x + 2, at.y + 2, PX, 1, Color(NEWS_INK, 0.5))
			elif (gx + gy) % 2 == 0:
				_b(at.x + 1, at.y + 1, PX, PX, Color(NEWS_INK, 0.7))


# --- the file ------------------------------------------------------------------

func _folder() -> void:
	var back := Rect2(0, 22, size.x, size.y - 22)
	_shadow(back, Vector2(5, 7))
	# The tab stands up from the back cover, at the left.
	_b(14, 0, tab, 26, MANILA_DARK)
	_b(16, PX, tab - 4.0, 24, MANILA)
	_b(16, PX, tab - 4.0, PX, MANILA_LIGHT)
	draw_rect(back, MANILA_DARK)
	draw_rect(Rect2(back.position + Vector2(PX, PX), back.size - Vector2(PX * 2.0, PX * 2.0)), MANILA)
	for speck in int(size.x * size.y / 500.0):
		var x := floorf(_roll(speck * 2 + 9100) * (size.x - 4.0) / PX) * PX + PX
		var y := back.position.y + floorf(_roll(speck * 2 + 9101) * (back.size.y - 4.0) / PX) * PX + PX
		_b(x, y, PX, PX, MANILA_DARK if speck % 3 else MANILA_LIGHT)
	# The sheet inside, a little crooked, and the cover folded back under it.
	var sheet := Rect2(18, 38, size.x - 34.0, size.y - 52.0)
	_b(sheet.position.x + 4, sheet.position.y + 5, sheet.size.x, sheet.size.y, Color(0, 0, 0, 0.25))
	_b(sheet.position.x, sheet.position.y, sheet.size.x, sheet.size.y, PAPER_LIGHT.darkened(0.04))
	_b(sheet.position.x, sheet.position.y, sheet.size.x, PX, Color.WHITE.darkened(0.05))
	_b(sheet.end.x - PX, sheet.position.y, PX, sheet.size.y, PAPER_DARK)
	_b(sheet.position.x, sheet.end.y - PX, sheet.size.x, PX, PAPER_DARK)
	for speck in int(sheet.size.x * sheet.size.y / 1200.0):
		var x := sheet.position.x + 4.0 + floorf(_roll(speck * 2 + 9300) * (sheet.size.x - 8.0) / PX) * PX
		var y := sheet.position.y + 4.0 + floorf(_roll(speck * 2 + 9301) * (sheet.size.y - 8.0) / PX) * PX
		_b(x, y, PX, PX, Color(PAPER_DARK, 0.5))
	# A clip holds it to the folder.
	var at := Vector2(sheet.end.x - 46.0, sheet.position.y - CLIP_OUT * PX)
	for r in CLIP.size():
		var line: String = CLIP[r]
		for column in line.length():
			if line[column] == "#":
				var cell := at + Vector2(column, r) * PX
				_b(cell.x + PX, cell.y + PX, PX, PX, Color(0, 0, 0, 0.28))
				_b(cell.x, cell.y, PX, PX, STEEL_LIGHT if column == 1 or r == 0 else STEEL)


# --- charts in ink ---------------------------------------------------------------

## A bar printed in ink: a dotted track, and the filled part in a halftone
## with solid edges. `value` from 0 to 1 (null: no figure, only the track).
class Bar extends Control:
	var value: Variant = 0.0:
		set(v):
			value = v
			queue_redraw()
	var ink := NEWS_INK
	var thick := 10.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _draw() -> void:
		var y := floorf((size.y - thick) / 2.0 / PX) * PX
		var x := 0.0
		while x < size.x:
			draw_rect(Rect2(x, y + thick / 2.0 - 1.0, PX, PX), Color(ink, 0.25))
			x += PX * 3.0
		if value == null:
			return
		var fill := floorf(clampf(float(value), 0.0, 1.0) * size.x / PX) * PX
		if fill <= 0.0:
			return
		draw_rect(Rect2(0, y, fill, PX), ink)
		draw_rect(Rect2(0, y + thick - PX, fill, PX), ink)
		draw_rect(Rect2(fill - PX, y, PX, thick), ink)
		var gy := y + PX
		var line := 0
		while gy < y + thick - PX:
			var gx := PX * (line % 2)
			while gx < fill - PX:
				draw_rect(Rect2(gx, gy, PX, PX), Color(ink, 0.85))
				gx += PX * 2.0
			gy += PX
			line += 1


## A rating over the last matches: ruled faintly, the line in ink from point
## to point, each point a dot, the last one ringed in red.
class Chart extends Control:
	var values: Array = []:
		set(v):
			values = v
			queue_redraw()
	var ink := INK

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for k in 4:
			var y := floorf(k * (size.y - PX) / 3.0 / PX) * PX
			var x := 0.0
			while x < size.x:
				draw_rect(Rect2(x, y, PX, 1), Color(INK_BLUE, 0.3))
				x += PX * 2.0
		if values.size() < 2:
			return
		var low: float = values.min()
		var high: float = values.max()
		if high - low < 20.0:
			var mid := (high + low) / 2.0
			low = mid - 10.0
			high = mid + 10.0
		var points := []
		for i in values.size():
			var x := i / float(values.size() - 1) * (size.x - PX * 4.0) + PX * 2.0
			var y := (1.0 - (float(values[i]) - low) / (high - low)) * (size.y - PX * 6.0) + PX * 3.0
			points.append((Vector2(x, y) / PX).floor() * PX)
		for i in points.size() - 1:
			var a: Vector2 = points[i]
			var b: Vector2 = points[i + 1]
			var steps := int(maxf(absf(b.x - a.x), absf(b.y - a.y)) / PX)
			for s in steps + 1:
				var p := (a.lerp(b, s / float(maxi(steps, 1))) / PX).floor() * PX
				draw_rect(Rect2(p, Vector2(PX, PX)), ink)
		for p: Vector2 in points:
			draw_rect(Rect2(p - Vector2(PX, PX) / 2.0, Vector2(PX * 2.0, PX * 2.0)), ink)
		var last: Vector2 = points.back()
		for a in 16:
			var q := ((last + Vector2.from_angle(a * TAU / 16.0) * 7.0) / PX).floor() * PX
			draw_rect(Rect2(q, Vector2(PX, PX)), INK_RED)
		var font := UI.font()
		var small := UI.px(11)
		draw_string(font, Vector2(0, size.y + small + 2.0), str(roundi(values.front())), HORIZONTAL_ALIGNMENT_LEFT, -1, small, INK_FADED)
		draw_string(font, Vector2(size.x - 40.0, size.y + small + 2.0), str(roundi(values.back())), HORIZONTAL_ALIGNMENT_RIGHT, 40.0, small, INK_RED)


## How often a member finished in each place: columns in ink, the first in red.
class Places extends Control:
	var counts: Array = []:
		set(v):
			counts = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var shown := 0
		for i in counts.size():
			if counts[i] > 0:
				shown = i + 1
		shown = clampi(shown, 3, counts.size())
		var most := 1
		for i in shown:
			most = maxi(most, counts[i])
		var font := UI.font()
		var small := UI.px(11)
		var step := floorf(size.x / shown / PX) * PX
		var tall := size.y - small - 6.0
		for i in shown:
			var h := floorf(counts[i] / float(most) * (tall - small - 4.0) / PX) * PX
			var x := i * step + PX * 2.0
			var w := step - PX * 4.0
			var ink: Color = INK_RED if i == 0 else INK
			draw_rect(Rect2(x, tall - PX, w, PX), Color(INK, 0.4))
			if h > 0.0:
				var y := tall - h
				draw_rect(Rect2(x, y, w, h), Color(ink, 0.18))
				draw_rect(Rect2(x, y, w, PX), ink)
				draw_rect(Rect2(x, y, PX, h), ink)
				draw_rect(Rect2(x + w - PX, y, PX, h), ink)
			draw_string(font, Vector2(x, tall - h - 4.0), str(counts[i]), HORIZONTAL_ALIGNMENT_CENTER, w, small, ink)
			draw_string(font, Vector2(x, size.y), Loc.t(["1st", "2nd", "3rd", "4th", "5th", "6th", "7th", "8th"][i]), HORIZONTAL_ALIGNMENT_CENTER, w, small, INK_FADED)


## The last places of a member, latest first, as a ledger writes them: a
## win in red, struck under, the rest in ink, fainter the further down.
class Form extends Control:
	var places: Array = []:
		set(v):
			places = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var font := UI.font()
		var small := UI.px(13)
		var step := 15.0
		var base := size.y / 2.0 + small * 0.34
		for i in mini(places.size(), int(size.x / step)):
			var x := i * step
			var won: bool = places[i] == 1
			var ink: Color = INK_RED if won else (INK if places[i] <= 2 else INK_FADED)
			draw_string(font, Vector2(x, base), str(places[i]), HORIZONTAL_ALIGNMENT_CENTER, 12.0, small, ink)
			if won:
				draw_rect(Rect2(x + 2.0, base + 2.0, 8.0, PX), Color(INK_RED, 0.85))


## A rubber stamp, struck a little crooked: a box with a double rule and the
## word inside, in an ink that did not take everywhere.
class Stamp extends Control:
	var text := ""
	var ink := INK_RED
	var label: Label

	func _init(word := "", color: Color = INK_RED, font_size := 22) -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		text = word
		ink = color
		label = Label.new()
		label.text = word
		label.add_theme_font_override("font", UI.bold())
		label.add_theme_font_size_override("font_size", UI.px(font_size))
		label.add_theme_color_override("font_color", Color(color, 0.85))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(label)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		for edge in [r, r.grow(-5.0)]:
			var e: Rect2 = edge
			var x := e.position.x
			while x < e.end.x:
				var gap := fposmod(sin(x * 0.7) * 43758.5, 1.0) < 0.12
				if not gap:
					draw_rect(Rect2(x, e.position.y, PX, PX), Color(ink, 0.8))
					draw_rect(Rect2(x, e.end.y - PX, PX, PX), Color(ink, 0.8))
				x += PX
			var y := e.position.y
			while y < e.end.y:
				if fposmod(sin(y * 1.3) * 43758.5, 1.0) > 0.1:
					draw_rect(Rect2(e.position.x, y, PX, PX), Color(ink, 0.8))
					draw_rect(Rect2(e.end.x - PX, y, PX, PX), Color(ink, 0.8))
				y += PX
