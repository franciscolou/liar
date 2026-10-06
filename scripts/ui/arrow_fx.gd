class_name ArrowFx
extends Control
## An arrow drawn across the table, from the actor of a play to its target.

var from := Vector2.ZERO
var to := Vector2.ZERO
var color := Color.WHITE
var progress := 0.0:
	set(value):
		progress = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if progress <= 0.0:
		return
	var tip := from.lerp(to, progress)
	var dir := (to - from).normalized()
	var side := Vector2(-dir.y, dir.x)
	draw_line(from, tip, Color(0, 0, 0, 0.55), 9.0)
	draw_line(from, tip, color, 5.0)
	draw_colored_polygon([tip + dir * 16, tip - dir * 6 + side * 13, tip - dir * 6 - side * 13], color)
	draw_circle(from, 7.0, color)
