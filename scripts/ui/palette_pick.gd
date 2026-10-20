extends Control
## The Painter's All Is Color (painter.gd), not a menu: the table goes dark
## and his palette lies in the middle of it, wood and three gobs of paint,
## with his coins on it. What he holds stands on the left, each with what it
## would fetch; what the shop has stands on the right, with its price. A click
## on the left turns the item into coins, on the right buys it; "Done" ends
## the go. Each trade is one answer: the engine asks again after it, and a
## pick asked again (`context.again`) comes up at once, with no entrance.
##
## Options: [{does: &"sell"|&"buy", item, coins | price, disabled, reason}]
## from painter.gd. No class name: preload it.

signal picked(index: int)
## A sound for the table to play.
signal sounded(sound: String)

const SIZE := Vector2(1152, 648)
const PX := 2.0
const VEIL := Color(0.05, 0.03, 0.06, 0.86)
const PALETTE_AT := Vector2(576, 330)
const PALETTE_REACH := Vector2(190, 118)
const ITEM_SCALE := 1.35
const COLUMN_STEP := Vector2(104, 128)
const SELL_AT := Vector2(70, 170)
const BUY_AT := Vector2(778, 170)
const PER_ROW := 3
const WOOD := [Color("4a2a12"), Color("6e4222"), Color("8f5a30"), Color("b07a44"), Color("cf9e60")]
const PAINTS := [Color("4f8fe0"), Color("e877b8"), Color("f2cf3c")]
const OUTLINE := Color("1b0f14")

var _views: Array = []
var _palette: Control
static var _wood: ImageTexture
var _time := 0.0
## How much of each gob of paint is lit up: the side the mouse is on.
var _glow := 0.0
var _glow_to := 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func setup(d: Decision) -> void:
	var again: bool = d.context.get("again", false)
	var veil := ColorRect.new()
	veil.color = Color(VEIL, VEIL.a if again else 0.0)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.show_behind_parent = true
	add_child(veil)
	if not again:
		create_tween().tween_property(veil, "color:a", VEIL.a, 0.25)

	var title := UI.label(d.prompt, 22, UI.CREAM, true)
	title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	title.position = Vector2(0, 40)
	title.size = Vector2(SIZE.x, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var hint := UI.label("Tap what you hold to turn it into coins, and what is on the shelf to buy it." if UI.touch
			else "Click what you hold to turn it into coins, and what is on the shelf to buy it.", 14, UI.MUTED)
	hint.position = Vector2(0, 72)
	hint.size = Vector2(SIZE.x, 20)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)

	_palette = Control.new()
	_palette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_palette.position = PALETTE_AT
	_palette.draw.connect(_draw_palette)
	add_child(_palette)
	var purse := UI.coins(d.player.coins, 30)
	purse.position = PALETTE_AT + Vector2(-34, -6)
	purse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(purse)
	TipLayer.attach(purse, Loc.t("What you have to paint with."))

	var sells: Array = []
	var buys: Array = []
	for i: int in d.options.size():
		(sells if d.options[i].does == &"sell" else buys).append(i)
	_column(d, sells, SELL_AT, "WHAT YOU HOLD", again)
	_column(d, buys, BUY_AT, "THE SHELF", again)
	# What was bought in this go is held but not for sale: shown, dimmed.
	var offered := sells.map(func(i: int) -> ItemInstance: return d.options[i].instance)
	var fresh := d.player.items.filter(func(instance: ItemInstance) -> bool: return not offered.has(instance))
	for n: int in fresh.size():
		var at := sells.size() + n
		var view := ItemView.new(ITEM_SCALE)
		view.set_item(fresh[n].def)
		view.set_enabled(false)
		view.note = Loc.t("Bought in this go: not for sale until it is over.")
		@warning_ignore("integer_division")
		view.position = SELL_AT + Vector2((at % PER_ROW) * COLUMN_STEP.x, 34 + (at / PER_ROW) * COLUMN_STEP.y)
		add_child(view)

	var done := UI.button("Done", UI.GOLD, 16)
	done.custom_minimum_size = UI.grown(Vector2(140, 36))
	done.position = Vector2(SIZE.x / 2.0 - done.get_combined_minimum_size().x / 2.0, 470)
	done.pressed.connect(func() -> void: picked.emit(-1))
	add_child(done)


## A column of items under its heading, three to a row, each with what
## trading it does to the purse.
func _column(d: Decision, indices: Array, at: Vector2, heading: String, again: bool) -> void:
	var head := UI.label(heading, 15, UI.GOLD, true)
	head.position = at + Vector2(0, 0)
	head.size = Vector2(COLUMN_STEP.x * PER_ROW - 20, 20)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(head)
	for n: int in indices.size():
		var index: int = indices[n]
		var option: Dictionary = d.options[index]
		var view := ItemView.new(ITEM_SCALE)
		view.set_item(option.item)
		var open: bool = not option.get("disabled", false)
		view.set_enabled(open)
		if not open:
			view.note = option.get("reason", "")
		@warning_ignore("integer_division")
		var spot := at + Vector2((n % PER_ROW) * COLUMN_STEP.x, 34 + (n / PER_ROW) * COLUMN_STEP.y)
		view.position = spot
		view.clicked.connect(_on_clicked.bind(index, view, open))
		view.picked.connect(_on_clicked.bind(index, view, open))
		view.mouse_entered.connect(func() -> void: _glow_to = 1.0 if option.does == &"sell" else -1.0)
		view.mouse_exited.connect(func() -> void: _glow_to = 0.0)
		add_child(view)
		if open:
			_views.append(view)
		# What it does to the purse, under it: coins in, or its price out.
		var selling: bool = option.does == &"sell"
		var amount: int = option.get("coins", 0) if selling else option.get("price", 0)
		var tag := UI.coins(amount, 16, UI.GREEN.lightened(0.2) if selling else (UI.GOLD if open else UI.RED.lightened(0.15)))
		var sign := UI.label("+" if selling else "-", 16, UI.GREEN.lightened(0.2) if selling else UI.GOLD, true)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 2)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(sign)
		row.add_child(tag)
		row.position = spot + Vector2(0, ItemView.BASE.y * ITEM_SCALE + 4)
		row.size = Vector2(ItemView.BASE.x * ITEM_SCALE, 20)
		add_child(row)
		if not again:
			view.modulate.a = 0.0
			row.modulate.a = 0.0
			var rise := view.create_tween().set_parallel()
			rise.tween_property(view, "modulate:a", 1.0, 0.25).set_delay(0.08 + 0.05 * n)
			rise.tween_property(row, "modulate:a", 1.0, 0.25).set_delay(0.08 + 0.05 * n)
			rise.tween_property(view, "position:y", spot.y, 0.3).from(spot.y + 24.0) \
					.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(0.08 + 0.05 * n)


## The items that can be traded, for the keyboard.
func views() -> Array:
	return _views


func _on_clicked(index: int, view: ItemView, open: bool) -> void:
	if not open:
		UI.shake(view, 4.0, 0.2)
		sounded.emit("cancel")
		return
	picked.emit(index)


func _process(delta: float) -> void:
	_time += delta
	_glow = move_toward(_glow, _glow_to, delta * 4.0)
	_palette.queue_redraw()


## The palette, in cells: a kidney of wood with the thumb hole on the right,
## lit from the top left, and three gobs of paint that breathe a little and
## swell while the mouse is on something to trade.
func _draw_palette() -> void:
	if _wood == null:
		_wood = _paint_wood()
	_palette.draw_texture_rect(_wood, Rect2(-PALETTE_REACH, PALETTE_REACH * 2.0), false)
	var rx := PALETTE_REACH.x
	var ry := PALETTE_REACH.y
	var gobs := [Vector2(-rx * 0.62, -ry * 0.3), Vector2(-rx * 0.2, -ry * 0.58), Vector2(rx * 0.25, -ry * 0.55)]
	for i: int in 3:
		var r := 15.0 + 1.5 * sin(_time * 2.0 + i) + 4.0 * absf(_glow)
		_blob(gobs[i], r, PAINTS[i])
	# Smears where they were mixed.
	for i: int in 9:
		var at := Vector2(-rx * 0.62 + i * 14.0, ry * 0.52 + 6.0 * sin(i * 1.3))
		_palette.draw_rect(Rect2(at.snapped(Vector2(PX, PX)), Vector2(8, 4)), Color(PAINTS[i % 3], 0.65))


## The wood of the palette, painted once: one pixel of the image per cell.
static func _paint_wood() -> ImageTexture:
	var cells := Vector2i(PALETTE_REACH * 2.0 / PX)
	var image := Image.create(cells.x, cells.y, false, Image.FORMAT_RGBA8)
	var rx := PALETTE_REACH.x
	var ry := PALETTE_REACH.y
	var hole := Vector2(rx * 0.55, ry * 0.32)
	var notch := Vector2(rx * 0.92, ry * 0.18)
	for cy: int in cells.y:
		for cx: int in cells.x:
			var x := cx * PX - rx
			var y := cy * PX - ry
			var u := x / rx
			var v := y / ry
			var round_ := u * u + v * v
			var from_notch := (Vector2(x, y) - notch).length() - ry * 0.42
			var from_hole := (Vector2(x, y) - hole).length() - 15.0
			if round_ > 1.0 or from_notch < 0.0 or from_hole < 0.0:
				continue
			var light := clampf(0.62 - u * 0.2 - v * 0.3, 0.0, 0.999)
			var shade := int(light * WOOD.size())
			# The grain: long dark lines along the board, a little wavy.
			if fposmod(y * 0.9 + x * 0.12 + 3.0 * sin(x * 0.03), 13.0) < 1.6:
				shade = maxi(shade - 1, 0)
			var color: Color = WOOD[shade]
			if round_ > 0.94 or from_notch < 3.0 or from_hole < 3.0:
				color = OUTLINE
			image.set_pixel(cx, cy, color)
	return ImageTexture.create_from_image(image)


func _blob(at: Vector2, r: float, color: Color) -> void:
	var y := -r
	while y <= r:
		var x := -r
		while x <= r:
			var d := Vector2(x, y).length() / r
			if d <= 1.0:
				var lit := Vector2(x, y).normalized().dot(Vector2(-0.6, -0.8)) * d
				var c := color.lightened(0.35) if lit > 0.45 else (color.darkened(0.3) if lit < -0.35 or d > 0.88 else color)
				_palette.draw_rect(Rect2((at + Vector2(x, y)).snapped(Vector2(PX, PX)), Vector2(PX, PX)), c)
			x += PX
		y += PX
