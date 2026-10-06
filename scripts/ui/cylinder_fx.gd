class_name CylinderFx
extends Control
## The cylinder of a revolver seen from behind, one chamber loaded, drawn in
## chunky pixels so it sits with the rest of the art. The chamber at the top,
## under the hammer notch, is the one that fires.

const CHAMBERS := 6
const CELLS := 37  # the drawing is CELLS x CELLS pixels...
const CELL := 3.0  # ...each this many screen pixels wide
const RADIUS := 16.0  # of the cylinder, in cells

const OUTLINE := Color("120c0a")
const STEEL := Color("4a4e58")
const STEEL_LIGHT := Color("6c7280")
const STEEL_DARK := Color("32353d")
const HOLE := Color("1c1a1e")
const BRASS := Color("d9a840")
const BRASS_DARK := Color("8b6218")

## How far the cylinder has turned, in chambers.
var turn := 0.0:
	set(value):
		turn = value
		queue_redraw()
## The chamber holding the round, counted clockwise from the top at turn 0.
var loaded := 0
## 0..1: the muzzle flash over the chamber under the hammer.
var flash := 0.0:
	set(value):
		flash = value
		queue_redraw()


func _init() -> void:
	size = Vector2.ONE * CELLS * CELL
	pivot_offset = size / 2.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var middle := (CELLS - 1) / 2.0
	var chambers: Array[Vector2] = []
	var flutes: Array[Vector2] = []
	for i in CHAMBERS:
		var angle := TAU * (i + turn) / CHAMBERS - PI / 2.0
		chambers.append(Vector2.from_angle(angle) * RADIUS * 0.58)
		flutes.append(Vector2.from_angle(angle + PI / CHAMBERS))
	var muzzle := Vector2(0, -RADIUS * 0.58)
	for y in CELLS:
		for x in CELLS:
			var p := Vector2(x - middle, y - middle)
			var color := _cell(p, chambers, flutes)
			if flash > 0.0:
				var reach := p.distance_to(muzzle) / (RADIUS * (0.35 + 1.1 * flash))
				if reach < 1.0:
					color = Color.WHITE if reach < 0.45 else Color(1.0, 0.86, 0.4)
			if color.a > 0.0:
				draw_rect(Rect2(x * CELL, y * CELL, CELL, CELL), color)
	# The notch the hammer falls through.
	var top := Vector2(size.x / 2.0, 0)
	draw_colored_polygon([top + Vector2(-9, -16), top + Vector2(9, -16), top + Vector2(0, -3)], OUTLINE)
	draw_colored_polygon([top + Vector2(-6, -14), top + Vector2(6, -14), top + Vector2(0, -5)], BRASS)


## The colour of the pixel at `p`, measured in cells from the centre.
func _cell(p: Vector2, chambers: Array[Vector2], flutes: Array[Vector2]) -> Color:
	var r := p.length()
	if r > RADIUS + 1.0:
		return Color(0, 0, 0, 0)
	if r > RADIUS:
		return OUTLINE
	for i in CHAMBERS:
		var d := p.distance_to(chambers[i])
		if d < RADIUS * 0.2:
			if i != loaded:
				return HOLE
			return BRASS_DARK if d < RADIUS * 0.07 else BRASS
		if d < RADIUS * 0.27:
			return OUTLINE
	if r < RADIUS * 0.1:
		return STEEL_LIGHT
	if r < RADIUS * 0.18:
		return OUTLINE
	if r > RADIUS * 0.76:
		# The flutes cut into the rim between the chambers.
		for flute: Vector2 in flutes:
			if p.dot(flute) > 0.0 and absf(p.cross(flute)) < 1.5:
				return STEEL_DARK
	# Lit from the top left.
	var light := -(p.x + p.y) / (RADIUS * 2.0)
	if light > 0.35:
		return STEEL_LIGHT
	return STEEL_DARK if light < -0.45 else STEEL
