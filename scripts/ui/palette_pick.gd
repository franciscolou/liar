extends Control
## The Painter's All Is Color (painter.gd), not a menu: the table goes dark
## and his palette is thrown up into the middle of it, spinning, and lands
## with its gobs of paint splashing onto the wood; his coins sit on it.
## What he holds flies in from the left, each with what it would fetch; what
## the shop has flies in from the right, with its price.
##
## A click on the left turns the item into coins: it is squeezed into a gob
## of gouache of its own colour that splats on the palette, and the coins
## come out of the splat into the purse. A click on the right buys: the coins
## sink into the paint, a gob of the item's colour leaps over to what he
## holds, splats there, and the item comes up out of the splat. Each trade is
## one answer and the engine asks again after it, but the screen stays: the table keeps it open (meta
## `linger`) and hands it the next question (refresh), and what moved slides
## to its new place. "Done" ends the go, and it all falls away (close).
##
## Options: [{does: &"sell"|&"buy", item, instance, coins | price, disabled,
## reason}] from painter.gd. No class name: preload it.

signal picked(index: int)
## A sound for the table to play.
signal sounded(sound: String)

const SIZE := Vector2(1152, 648)
const PX := 2.0
const VEIL := Color(0.05, 0.03, 0.06, 0.86)
const PALETTE_AT := Vector2(576, 330)
const PALETTE_REACH := Vector2(170, 108)
const ITEM_SCALE := 1.35
const COLUMN_STEP := Vector2(104, 128)
const SELL_AT := Vector2(44, 170)
const BUY_AT := Vector2(806, 170)
const PER_ROW := 3
const WOOD := [Color("4a2a12"), Color("6e4222"), Color("8f5a30"), Color("b07a44"), Color("cf9e60")]
const PAINTS := [Color("4f8fe0"), Color("e877b8"), Color("f2cf3c"), Color("5fbf5a")]
const OUTLINE := Color("1b0f14")
const COIN := "res://assets/ui/coin.png"
## The entrance: the palette's throw, and when each gob lands on it.
const THROW := 0.55
const GOB_LANDS := [0.5, 0.6, 0.7, 0.8]
## A trade: the leap of a sold item onto the palette, the coins' flight.
const LEAP := 0.42
const COIN_FLIGHT := 0.4
## How long a gob of paint is in the air.
const MELT_FLIGHT := 0.38
## The block the paint effects are drawn in.
const PAINT_CELL := 3.0

var _views: Array = []
var _palette: Control
static var _wood: ImageTexture
var _purse: HBoxContainer
var _purse_shown := 0.0
var _content: Control  # the two columns, made again on every refresh
var _done: Button
var _title: Label
var _hint: Label
var _veil: ColorRect
## Where each thing stood on the last question, to slide it from there:
## an ItemInstance or a shop slot -> position.
var _spots := {}
var _time := 0.0
## How much the gobs swell: the mouse on something to trade.
var _glow := 0.0
var _glow_to := 0.0
## Each gob's size, 0 before it has landed.
var _gobs := [0.0, 0.0, 0.0, 0.0]
## Drops of paint flying over the palette: {p, v, c, life}.
var _drops: Array = []
## Waiting for the engine to ask again after a trade: clicks do nothing.
var _busy := false
## Gouache in flight and splats on the way (see _fling, _splat_at).
var _paints: Array = []
## The colour of each item's art, worked out once (_tone_of).
var _tones := {}
var _dust: Control
## Where a bought item is being made of paint, and for how much longer: its
## view stays clear until then.
var _forming_at := Vector2.INF
## Coins of a sale still flying to the purse: it is not to be set before.
var _purse_pending := false
var _forming_left := 0.0
var _closing := false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_meta(&"linger", true)


func setup(d: Decision) -> void:
	_veil = ColorRect.new()
	_veil.color = Color(VEIL, 0.0)
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.show_behind_parent = true
	add_child(_veil)
	create_tween().tween_property(_veil, "color:a", VEIL.a, 0.3)

	_title = UI.label(d.prompt, 22, UI.CREAM, true)
	_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_title.size = Vector2(SIZE.x, 30)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_title)
	_hint = UI.label("Tap what you hold to turn it into coins, and what is on the shelf to buy it." if UI.touch
			else "Click what you hold to turn it into coins, and what is on the shelf to buy it.", 14, UI.MUTED)
	_hint.position = Vector2(0, 72)
	_hint.size = Vector2(SIZE.x, 20)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.modulate.a = 0.0
	add_child(_hint)
	var heading := create_tween().set_parallel()
	heading.tween_property(_title, "position", Vector2(0, 40), 0.4).from(Vector2(0, -30)) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	heading.tween_property(_hint, "modulate:a", 1.0, 0.3).set_delay(0.3)

	# The palette is thrown up from under the table, spinning, and lands.
	_palette = Control.new()
	_palette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_palette.position = PALETTE_AT + Vector2(0, 420)
	_palette.rotation = -2.4
	_palette.scale = Vector2.ONE * 0.5
	_palette.draw.connect(_draw_palette)
	add_child(_palette)
	var throw := create_tween().set_parallel()
	throw.tween_property(_palette, "position", PALETTE_AT, THROW).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	throw.tween_property(_palette, "rotation", 0.0, THROW).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	throw.tween_property(_palette, "scale", Vector2.ONE, THROW).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i: int in PAINTS.size():
		throw.tween_callback(_gob_lands.bind(i)).set_delay(GOB_LANDS[i])

	_purse_shown = d.player.coins
	_purse = UI.coins(d.player.coins, 30)
	_purse.position = PALETTE_AT + Vector2(-34, -6)
	_purse.pivot_offset = Vector2(34, 16)
	_purse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_purse.modulate.a = 0.0
	add_child(_purse)
	TipLayer.attach(_purse, Loc.t("What you have to paint with."))
	var purse_in := create_tween()
	purse_in.tween_interval(GOB_LANDS.back() + 0.1)
	purse_in.tween_property(_purse, "modulate:a", 1.0, 0.15)
	purse_in.tween_callback(UI.pop.bind(_purse, 1.3, 0.25))

	_content = Control.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	_columns(d, true)

	_dust = Control.new()
	_dust.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dust.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dust.draw.connect(_draw_dust)
	add_child(_dust)

	_done = UI.button("Done", UI.GOLD, 16)
	_done.custom_minimum_size = UI.grown(Vector2(140, 36))
	var at := Vector2(SIZE.x / 2.0 - _done.get_combined_minimum_size().x / 2.0, 470)
	_done.pressed.connect(func() -> void:
		if not _busy and not _closing:
			picked.emit(-1))
	add_child(_done)
	_done.modulate.a = 0.0
	var done_in := _done.create_tween().set_parallel()
	done_in.tween_property(_done, "position", at, 0.35).from(at + Vector2(0, 40)) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.6)
	done_in.tween_property(_done, "modulate:a", 1.0, 0.2).set_delay(0.6)
	sounded.emit("fx_brush")


## The engine asked again after a trade: the columns are made anew, and what
## stood somewhere else before slides to its new place.
func refresh(d: Decision) -> void:
	_busy = false
	_title.text = d.prompt
	# Coins still on their way to the purse count themselves in as they land.
	if not _purse_pending:
		_set_purse(d.player.coins)
	for child: Node in _content.get_children():
		child.queue_free()
	_views.clear()
	_columns(d, false)


## The go is over: the items fly back where they came from, the palette
## drops away and the table comes back.
func close() -> void:
	if _closing:
		return
	_closing = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var out := create_tween().set_parallel()
	for view: Node in _content.get_children():
		if view is Control:
			var side := -1.0 if (view as Control).position.x < SIZE.x / 2.0 else 1.0
			out.tween_property(view, "position:x", (view as Control).position.x + 500.0 * side, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			out.tween_property(view, "modulate:a", 0.0, 0.3)
	out.tween_property(_palette, "position:y", PALETTE_AT.y + 460.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	out.tween_property(_palette, "rotation", 1.6, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for node: Control in [_purse, _title, _hint, _done]:
		out.tween_property(node, "modulate:a", 0.0, 0.2)
	out.tween_property(_veil, "color:a", 0.0, 0.35).set_delay(0.15)
	out.chain().tween_callback(queue_free)


func closing() -> bool:
	return _closing


## The items that can be traded, for the keyboard.
func views() -> Array:
	return _views


# --- the columns ----------------------------------------------------------------

func _columns(d: Decision, entering: bool) -> void:
	var sells: Array = []
	var buys: Array = []
	for i: int in d.options.size():
		(sells if d.options[i].does == &"sell" else buys).append(i)
	_heading("WHAT YOU HOLD", SELL_AT, entering)
	_heading("THE SHELF", BUY_AT, entering)
	var spots := {}
	for n: int in sells.size():
		_item(d, sells[n], _spot(SELL_AT, n), entering, -1.0, n, spots)
	for n: int in buys.size():
		_item(d, buys[n], _spot(BUY_AT, n), entering, 1.0, n, spots)
	# What was bought in this go is held but not for sale: shown, dimmed.
	var offered := sells.map(func(i: int) -> ItemInstance: return d.options[i].instance)
	var fresh := d.player.items.filter(func(instance: ItemInstance) -> bool: return not offered.has(instance))
	for n: int in fresh.size():
		var view := ItemView.new(ITEM_SCALE)
		view.set_item(fresh[n].def)
		view.set_enabled(false)
		view.note = Loc.t("Bought in this go: not for sale until it is over.")
		var spot := _spot(SELL_AT, sells.size() + n)
		_arrive(view, spot, fresh[n], entering, -1.0, n)
		if spot == _forming_at and _forming_left > 0.0:
			# Still a gob of paint on its way: it comes up out of the splat.
			view.modulate.a = 0.0
			view.pivot_offset = view.size / 2.0
			view.scale = Vector2(1.4, 0.2)
			var rise := view.create_tween().set_parallel()
			rise.tween_property(view, "modulate:a", 1.0, 0.1).set_delay(_forming_left)
			rise.tween_property(view, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(_forming_left)
		spots[fresh[n]] = spot
		_content.add_child(view)
	_spots = spots


func _heading(text: String, at: Vector2, entering: bool) -> void:
	var head := UI.label(text, 15, UI.GOLD, true)
	head.position = at
	head.size = Vector2(COLUMN_STEP.x * PER_ROW - 20, 20)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(head)
	if entering:
		head.modulate.a = 0.0
		head.create_tween().tween_property(head, "modulate:a", 1.0, 0.3).set_delay(0.35)


func _spot(at: Vector2, n: int) -> Vector2:
	@warning_ignore("integer_division")
	return at + Vector2((n % PER_ROW) * COLUMN_STEP.x, 34 + (n / PER_ROW) * COLUMN_STEP.y)


## One item, with what trading it does to the purse under it.
func _item(d: Decision, index: int, spot: Vector2, entering: bool, side: float, n: int, spots: Dictionary) -> void:
	var option: Dictionary = d.options[index]
	var selling: bool = option.does == &"sell"
	var view := ItemView.new(ITEM_SCALE)
	view.set_item(option.item)
	var open: bool = not option.get("disabled", false)
	view.set_enabled(open)
	if not open:
		view.note = option.get("reason", "")
	var key: Variant = option.instance if selling else option.slot
	_arrive(view, spot, key, entering, side, n)
	spots[key] = spot
	view.clicked.connect(_on_clicked.bind(index, view, option))
	view.picked.connect(_on_clicked.bind(index, view, option))
	view.mouse_entered.connect(func() -> void: _glow_to = 1.0)
	view.mouse_exited.connect(func() -> void: _glow_to = 0.0)
	_content.add_child(view)
	if open:
		_views.append(view)
	var amount: int = option.get("coins", 0) if selling else option.get("price", 0)
	var ink: Color = UI.GREEN.lightened(0.2) if selling else (UI.GOLD if open else UI.RED.lightened(0.15))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(UI.label("+" if selling else "-", 16, ink, true))
	row.add_child(UI.coins(amount, 16, ink))
	row.size = Vector2(ItemView.BASE.x * ITEM_SCALE, 20)
	row.position = Vector2(0, ItemView.BASE.y * ITEM_SCALE + 4)
	view.add_child(row)


## Puts `view` at `spot`: flying in from its side of the screen on the way in,
## sliding over from where it stood on the last question, or just there.
func _arrive(view: Control, spot: Vector2, key: Variant, entering: bool, side: float, n: int) -> void:
	if entering:
		view.position = Vector2(spot.x + 520.0 * side, spot.y - 60.0)
		view.rotation = 1.2 * side
		view.modulate.a = 0.0
		var fly := view.create_tween().set_parallel()
		var delay := 0.3 + 0.07 * n
		fly.tween_property(view, "position", spot, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
		fly.tween_property(view, "rotation", 0.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(delay)
		fly.tween_property(view, "modulate:a", 1.0, 0.15).set_delay(delay)
		return
	var was: Variant = _spots.get(key)
	if was is Vector2 and was != spot:
		view.position = was
		view.create_tween().tween_property(view, "position", spot, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		view.position = spot


# --- trades ---------------------------------------------------------------------

func _on_clicked(index: int, view: ItemView, option: Dictionary) -> void:
	if _busy or _closing:
		return
	if option.get("disabled", false):
		UI.shake(view, 4.0, 0.2)
		sounded.emit("cancel")
		return
	_busy = true
	if option.does == &"sell":
		_sell(view, option.coins)
	else:
		_buy(view, option.price)
	picked.emit(index)


## The item is squeezed, goes soft and turns into a fat gob of gouache in its
## own colour, which is flung onto the palette and splats there; out of the
## splat come the coins.
func _sell(view: ItemView, amount: int) -> void:
	sounded.emit("fx_paint_dip")
	_purse_pending = true
	var tone := _tone_of(view.def)
	var centre := view.position + view.size / 2.0
	var land := PALETTE_AT + Vector2(randf_range(-70.0, 10.0), randf_range(-6.0, 26.0))
	# What melts is a picture of it of the screen's own: the columns are made
	# anew as soon as the engine asks again, and the view goes with them.
	var stand_in := TextureRect.new()
	stand_in.texture = UI.tex(view.def.texture_path)
	stand_in.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stand_in.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stand_in.size = view.size
	stand_in.position = view.position
	stand_in.pivot_offset = view.size / 2.0
	stand_in.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stand_in)
	move_child(stand_in, _dust.get_index())
	view.visible = false
	var melt := stand_in.create_tween()
	# A squeeze, a wobble, and it slumps into paint.
	melt.tween_property(stand_in, "scale", Vector2(1.25, 0.8), 0.1)
	melt.tween_property(stand_in, "scale", Vector2(0.85, 1.15), 0.08)
	melt.tween_property(stand_in, "scale", Vector2(1.5, 0.25), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	melt.parallel().tween_property(stand_in, "modulate", Color(tone, 0.0), 0.14)
	melt.tween_callback(func() -> void:
		_fling(centre, land, tone, 26.0, MELT_FLIGHT, func() -> void:
			_splat_at(land, tone, 40.0)
			sounded.emit("fx_palette")
			_coins_to_purse(land, amount)))
	melt.tween_callback(stand_in.queue_free)


## The coins sink into the paint, and a gob of the item's colour leaps off the
## palette to what he holds, splats there and the item comes up out of it.
func _buy(view: ItemView, price: int) -> void:
	sounded.emit("spend")
	var tone := _tone_of(view.def)
	var purse := _purse.global_position + Vector2(16, 16)
	var into := PALETTE_AT + Vector2(-30, 10)
	for i: int in mini(price, 8):
		var coin := _coin(purse)
		var fly := coin.create_tween()
		fly.tween_property(coin, "position", into - coin.size / 2.0, COIN_FLIGHT) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(0.05 * i)
		fly.tween_property(coin, "scale", Vector2.ZERO, 0.1)
		fly.tween_callback(coin.queue_free)
	_set_purse(int(_purse_shown) - price)
	view.create_tween().tween_property(view, "modulate:a", 0.3, 0.3)
	# The next free place among what is held.
	var spot := _spot(SELL_AT, _spots.keys().filter(func(key: Variant) -> bool: return key is ItemInstance).size())
	var target := spot + ItemView.BASE * ITEM_SCALE / 2.0
	var start := COIN_FLIGHT + 0.12
	_forming_at = spot
	_forming_left = start + MELT_FLIGHT + 0.1
	var mix := create_tween()
	mix.tween_interval(start)
	mix.tween_callback(func() -> void:
		# The coins went in: the paint stirs and a gob of the new colour comes up.
		_splat_at(into, tone, 24.0)
		sounded.emit("fx_paint_dip")
		_fling(into, target, tone, 30.0, MELT_FLIGHT, func() -> void:
			_splat_at(target, tone, 46.0)
			sounded.emit("fx_splat")
			sounded.emit("item_get")))


## The colour an item reads as: the average of the bright, saturated pixels
## of its art (the outline and the shadows left out).
func _tone_of(def: ItemDef) -> Color:
	if def == null:
		return PAINTS[0]
	if _tones.has(def.id):
		return _tones[def.id]
	var tone: Color = PAINTS[0]
	var texture := UI.tex(def.texture_path)
	var image := texture.get_image() if texture != null else null
	if image != null:
		if image.is_compressed():
			image.decompress()
		var sum := Vector3.ZERO
		var weight := 0.0
		for y: int in range(0, image.get_height(), 2):
			for x: int in range(0, image.get_width(), 2):
				var c := image.get_pixel(x, y)
				if c.a < 0.5 or c.v < 0.25:
					continue
				var w := 0.2 + c.s
				sum += Vector3(c.r, c.g, c.b) * w
				weight += w
		if weight > 0.0:
			sum /= weight
			tone = Color(sum.x, sum.y, sum.z)
			# Gouache is thick and bright: a little more colour than the art.
			tone.s = minf(tone.s * 1.25, 1.0)
			tone.v = clampf(tone.v * 1.1, 0.35, 0.95)
	_tones[def.id] = tone
	return tone


## A gob of paint thrown from `from` to `to` in an arc, stretched along the
## way it flies; `landed` once it gets there.
func _fling(from: Vector2, to: Vector2, tone: Color, radius: float, time: float, landed: Callable) -> void:
	var gob := {"kind": &"gob", "at": from, "was": from, "r": radius, "c": tone, "phase": randf() * TAU}
	_paints.append(gob)
	var lift := clampf(from.distance_to(to) * 0.35, 50.0, 160.0)
	var fly := create_tween()
	fly.tween_method(func(t: float) -> void:
		gob.was = gob.at
		gob.at = from.lerp(to, t) + Vector2(0, -lift * sin(t * PI))
		gob.r = radius * (1.0 - 0.25 * sin(t * PI)), 0.0, 1.0, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	fly.tween_callback(func() -> void:
		_paints.erase(gob)
		landed.call())


## Paint hitting something, hard: a ragged pool bursts out and shrinks back,
## a spray of drops of every size flies off every way, falls and bounces,
## and smaller bursts go off round the first a moment later. All of it in
## blocks of PAINT_CELL, a little lighter or darker here and there.
func _splat_at(at: Vector2, tone: Color, radius: float, bursts := 2) -> void:
	_paints.append({"kind": &"pool", "at": at, "r": radius, "c": tone, "age": 0.0, "life": 0.55, "seed": randi()})
	for i: int in int(radius * 1.3):
		var angle := randf() * TAU
		var speed := randf_range(120.0, 520.0) * (radius / 40.0)
		_paints.append({
			"kind": &"drop", "p": at + Vector2.from_angle(angle) * randf() * radius * 0.4,
			"v": Vector2.from_angle(angle) * speed + Vector2(0, -randf_range(60.0, 220.0)),
			"size": PAINT_CELL * randi_range(1, 3), "c": _shade(tone), "age": 0.0,
			"life": randf_range(0.5, 1.1), "floor": at.y + randf_range(10.0, 60.0),
		})
	# Splashes off the splash, a moment later.
	for i: int in bursts:
		var off := Vector2.from_angle(randf() * TAU) * randf_range(radius * 0.6, radius * 1.3)
		var later := create_tween()
		later.tween_interval(randf_range(0.06, 0.18))
		later.tween_callback(_splat_at.bind(at + off, tone, radius * randf_range(0.35, 0.55), 0))
	if bursts > 0:
		UI.shake(_palette, 5.0, 0.2)


## A paint a little off `tone`, as thick paint is never one colour.
func _shade(tone: Color) -> Color:
	var roll := randf()
	if roll < 0.25:
		return tone.lightened(randf_range(0.15, 0.35))
	if roll < 0.45:
		return tone.darkened(randf_range(0.15, 0.3))
	return tone


func _coins_to_purse(from: Vector2, amount: int) -> void:
	var purse := _purse.global_position + Vector2(16, 16)
	var shown := mini(amount, 8)
	for i: int in shown:
		var coin := _coin(from)
		var out := from + Vector2.from_angle(-PI / 2.0 + randf_range(-1.1, 1.1)) * randf_range(30.0, 60.0)
		var fly := coin.create_tween()
		fly.tween_property(coin, "position", out - coin.size / 2.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		fly.tween_property(coin, "position", purse - coin.size / 2.0, COIN_FLIGHT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(0.04 * i)
		fly.tween_callback(func() -> void:
			sounded.emit("coin_%d" % (i % 3 + 1))
			UI.pop(_purse, 1.15, 0.12))
		fly.tween_callback(coin.queue_free)
	var target := int(_purse_shown) + amount
	var count := create_tween()
	count.tween_interval(0.18 + COIN_FLIGHT)
	count.tween_callback(func() -> void:
		_purse_pending = false
		_set_purse(target))


func _coin(at: Vector2) -> TextureRect:
	var coin := TextureRect.new()
	coin.texture = UI.tex(COIN)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.size = Vector2(20, 20)
	coin.position = at - coin.size / 2.0
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(coin)
	return coin


func _set_purse(coins: int) -> void:
	if int(_purse_shown) == coins:
		return
	_purse_shown = coins
	var fresh := UI.coins(coins, 30)
	fresh.position = _purse.position
	fresh.pivot_offset = _purse.pivot_offset
	fresh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fresh)
	move_child(fresh, _purse.get_index())
	TipLayer.attach(fresh, Loc.t("What you have to paint with."))
	_purse.queue_free()
	_purse = fresh
	UI.pop(_purse, 1.3, 0.2)


## Drops of the three paints thrown out from `at`, over the palette.
func _splash(at: Vector2, count: int) -> void:
	for i: int in count:
		_drops.append({
			"p": at - PALETTE_AT, "v": Vector2.from_angle(randf() * TAU) * randf_range(60.0, 200.0),
			"c": PAINTS[i % PAINTS.size()].lightened(randf_range(-0.1, 0.2)), "life": randf_range(0.4, 0.7),
		})


func _gob_lands(i: int) -> void:
	var tween := create_tween()
	tween.tween_method(func(v: float) -> void: _gobs[i] = v, 0.0, 1.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_splash(PALETTE_AT + _gob_at(i), 8)
	sounded.emit("fx_splat")


func _gob_at(i: int) -> Vector2:
	var rx := PALETTE_REACH.x
	var ry := PALETTE_REACH.y
	return [Vector2(-rx * 0.62, -ry * 0.3), Vector2(-rx * 0.2, -ry * 0.58), Vector2(rx * 0.25, -ry * 0.55),
			Vector2(-rx * 0.7, ry * 0.18)][i]


func _process(delta: float) -> void:
	_time += delta
	_glow = move_toward(_glow, _glow_to, delta * 4.0)
	for drop: Dictionary in _drops:
		drop.p += drop.v * delta
		drop.v.y += 500.0 * delta
		drop.life -= delta
	_drops = _drops.filter(func(drop: Dictionary) -> bool: return drop.life > 0.0)
	if _forming_left > 0.0:
		_forming_left = maxf(_forming_left - delta, 0.0)
	# Gobs in flight shed drips behind them.
	var shed: Array = []
	for paint: Dictionary in _paints:
		if paint.kind == &"gob" and randf() < 0.6:
			var way: Vector2 = (paint.at - paint.was).normalized()
			shed.append({
				"kind": &"drop", "p": paint.at - way * paint.r, "v": -way * randf_range(20.0, 80.0) + Vector2(randf_range(-30, 30), 0),
				"size": PAINT_CELL * randi_range(1, 2), "c": _shade(paint.c), "age": 0.0,
				"life": randf_range(0.3, 0.6), "floor": INF,
			})
	_paints.append_array(shed)
	for paint: Dictionary in _paints:
		if paint.kind == &"drop":
			paint.age += delta
			paint.v *= 1.0 - 1.8 * delta
			paint.v.y += 900.0 * delta
			paint.p += paint.v * delta
			# They land and bounce once, losing most of it.
			if paint.p.y > paint.floor and paint.v.y > 0.0:
				paint.p.y = paint.floor
				paint.v = Vector2(paint.v.x * 0.5, -paint.v.y * 0.3)
		elif paint.kind == &"pool":
			paint.age += delta
	_paints = _paints.filter(func(paint: Dictionary) -> bool: return paint.kind == &"gob" or paint.age < paint.life)
	_palette.queue_redraw()
	_dust.queue_redraw()


## The gouache, in blocks of PAINT_CELL: gobs in the air shedding drips,
## pools bursting where they land and the drops thrown off them.
func _draw_dust() -> void:
	for paint: Dictionary in _paints:
		match paint.kind:
			&"gob":
				_draw_gob(paint)
			&"pool":
				_draw_pool(paint)
			&"drop":
				var fade := 1.0 - smoothstep(0.7, 1.0, paint.age / paint.life)
				var size: float = paint.size
				_dust.draw_rect(Rect2((paint.p as Vector2).snapped(Vector2(PAINT_CELL, PAINT_CELL)), Vector2(size, size)), Color(paint.c, fade))


## A gob in flight: a lumpy block of paint, stretched along the way it goes,
## a lighter block on top for the shine, and drips falling off behind it.
func _draw_gob(gob: Dictionary) -> void:
	var at: Vector2 = gob.at
	var way: Vector2 = at - gob.was
	var along := way.normalized() if way.length() > 0.01 else Vector2.RIGHT
	var stretch := clampf(way.length() / 10.0, 0.0, 1.2)
	var r: float = gob.r
	var tone: Color = gob.c
	var cell := PAINT_CELL
	var reach := int(r * (1.0 + stretch) / cell) + 1
	for y: int in range(-reach, reach + 1):
		for x: int in range(-reach, reach + 1):
			var offset := Vector2(x, y) * cell
			# Squashed across its flight, stretched along it, lumpy at the edge.
			var a := offset.dot(along) / (1.0 + stretch)
			var b := offset.dot(along.orthogonal()) * (1.0 + stretch * 0.4)
			var lump := 1.0 + 0.18 * sin(offset.angle() * 4.0 + gob.phase + _time * 9.0)
			var d := Vector2(a, b).length() / (r * lump)
			if d > 1.0:
				continue
			var ink := tone
			if d > 0.82 or offset.y > r * 0.45:
				ink = tone.darkened(0.3)
			elif offset.x < -r * 0.2 and offset.y < -r * 0.2:
				ink = tone.lightened(0.3)
			_dust.draw_rect(Rect2((at + offset).snapped(Vector2(cell, cell)), Vector2(cell, cell)), ink)
	_dust.draw_rect(Rect2((at + Vector2(-r * 0.4, -r * 0.45)).snapped(Vector2(cell, cell)), Vector2(cell, cell)), Color.WHITE)


## The pool where paint hits: it bursts out ragged at once and draws back as
## it soaks in, every block of it a little off the colour, its edge torn.
func _draw_pool(pool: Dictionary) -> void:
	var t: float = pool.age / pool.life
	var grow := ease(minf(t * 4.0, 1.0), 0.3) * (1.0 - 0.6 * smoothstep(0.4, 1.0, t))
	var r: float = pool.r * grow
	var alpha := 1.0 - smoothstep(0.6, 1.0, t)
	if r < PAINT_CELL:
		return
	var at: Vector2 = pool.at
	var rng := RandomNumberGenerator.new()
	rng.seed = pool.seed
	var cell := PAINT_CELL
	var reach := int(r * 1.5 / cell) + 1
	for y: int in range(-reach, reach + 1):
		for x: int in range(-reach, reach + 1):
			var offset := Vector2(x, y) * cell
			var edge := r * (0.8 + 0.35 * absf(sin(offset.angle() * 5.0 + pool.seed % 7)) + 0.15 * sin(offset.angle() * 11.0 + pool.seed % 5) + rng.randf_range(-0.05, 0.05))
			var d := offset.length()
			if d > edge:
				continue
			var ink: Color = pool.c
			var roll := rng.randf()
			if d > edge - cell:
				ink = ink.darkened(0.35)
			elif offset.x + offset.y < -r * 0.5 and d < r * 0.7:
				# The wet shine, up on the side the light comes from.
				ink = ink.lightened(0.3)
			elif roll < 0.05:
				ink = ink.darkened(0.15)
			_dust.draw_rect(Rect2((at + offset).snapped(Vector2(cell, cell)), Vector2(cell, cell)), Color(ink, alpha))


# --- the palette ----------------------------------------------------------------

## The palette, in cells: a kidney of wood with the thumb hole on the right,
## lit from the top left, and four gobs of paint that breathe a little and
## swell while the mouse is on something to trade.
func _draw_palette() -> void:
	if _wood == null:
		_wood = _paint_wood()
	_palette.draw_texture_rect(_wood, Rect2(-PALETTE_REACH, PALETTE_REACH * 2.0), false)
	for i: int in PAINTS.size():
		if _gobs[i] > 0.0:
			var r: float = (15.0 + 1.5 * sin(_time * 2.0 + i) + 4.0 * _glow) * _gobs[i]
			_blob(_gob_at(i), r, PAINTS[i])
	# Smears where they were mixed.
	var rx := PALETTE_REACH.x
	var ry := PALETTE_REACH.y
	for i: int in 9:
		var at := Vector2(-rx * 0.62 + i * 14.0, ry * 0.52 + 6.0 * sin(i * 1.3))
		_palette.draw_rect(Rect2(at.snapped(Vector2(PX, PX)), Vector2(8, 4)), Color(PAINTS[i % PAINTS.size()], 0.65 * _gobs[i % PAINTS.size()]))
	for drop: Dictionary in _drops:
		_palette.draw_rect(Rect2((drop.p as Vector2).snapped(Vector2(PX, PX)), Vector2(4, 4)), Color(drop.c, clampf(drop.life * 3.0, 0.0, 1.0)))


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
