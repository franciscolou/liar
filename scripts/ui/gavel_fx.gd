class_name GavelFx
extends Control
## A judge's gavel in chunky pixels. The node's origin is the hand holding the
## end of the handle; at rotation 0 the handle lies to the left and the head
## stands at its far end, striking face down. A positive rotation raises it.

const CELL := 4.0
const HANDLE := 20  # length of the handle, in cells
const HEAD := Vector2i(8, 18)  # width and height of the head, in cells

const OUTLINE := Color("120c0a")
const WOOD := Color("7a4a26")
const WOOD_LIGHT := Color("a06a3a")
const WOOD_DARK := Color("54301a")
const BRASS := Color("d9a840")
const BRASS_DARK := Color("8b6218")


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Where the node must sit for the striking face to land on `point`.
static func origin_for(point: Vector2) -> Vector2:
	return point - Vector2(-HANDLE, HEAD.y / 2.0) * CELL


func _draw() -> void:
	var half := HEAD.y / 2
	var left := -HANDLE - HEAD.x / 2
	# Outlines first, one cell bigger all around.
	_cells(-HANDLE, -2, HANDLE + 1, 4, OUTLINE)
	_cells(left - 1, -half - 1, HEAD.x + 2, HEAD.y + 2, OUTLINE)
	# The handle, turned thinner near the head, with a brass cap at the hand.
	_cells(-HANDLE, -1, HANDLE, 2, WOOD)
	_cells(-HANDLE, -1, HANDLE, 1, WOOD_LIGHT)
	_cells(-2, -1, 2, 2, BRASS)
	_cells(-2, 0, 2, 1, BRASS_DARK)
	# The head: a barrel standing on end, lit from the left, banded in brass.
	_cells(left, -half, HEAD.x, HEAD.y, WOOD)
	_cells(left, -half, 2, HEAD.y, WOOD_LIGHT)
	_cells(left + HEAD.x - 2, -half, 2, HEAD.y, WOOD_DARK)
	for band: int in [-half + 2, half - 4]:
		_cells(left, band, HEAD.x, 2, BRASS)
		_cells(left + HEAD.x - 2, band, 2, 2, BRASS_DARK)
	# The striking faces, a shade darker.
	_cells(left, -half, HEAD.x, 1, WOOD_DARK)
	_cells(left, half - 1, HEAD.x, 1, WOOD_DARK)


func _cells(x: int, y: int, w: int, h: int, color: Color) -> void:
	draw_rect(Rect2(Vector2(x, y) * CELL, Vector2(w, h) * CELL), color)
