extends Control
## The choice of a Counterfeit: not a menu. The lights go down, every item
## that can be copied floats up out of the box of whoever holds it, turning
## in the air with sparks about it and its price under it, and the
## Magician's wand comes up over the counter and points at the one the
## player is on. A click on an item picks it.

signal picked(index: int)

const SIZE := Vector2(1152, 648)
const PIXEL := 2.0
const GLOW := Color("ffd84a")
const VEIL := Color(0.03, 0.02, 0.07, 0.62)
const COIN_ART := "res://assets/ui/coin.png"
## How big a floating item is next to its art, and how long it takes to
## come up out of its box (and how much later each one starts).
const SHOWN := 0.75
const RISE := 0.4
const RISE_STAGGER := 0.05
## Where the wand comes up from, and how fast it turns (the bigger the snappier).
const HELD := Vector2(576, 476)
const TURN := 11.0
const SPARKS := 9

var _views: Array[ItemView] = []
var _from: Array[Vector2] = []
var _to: Array[Vector2] = []
var _prices: Array[int] = []
var _choice: Array[int] = []  # the option each floating item stands for
var _out := PackedFloat32Array()
var _time := 0.0
var _hovered := -1
var _wand: PlayFx.WandFx
var _name: Label
var _ink := GLOW
var _coin: Texture2D


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Lays out the options of `d` ([{item, price, ...}]). `spots` says where
## each copy of them lies and where it floats to: [{option, from, to}], in
## the order the keyboard walks them. Prices are written in `ink`.
func setup(d: Decision, spots: Array, ink: Color) -> void:
	_ink = ink
	_coin = UI.tex(COIN_ART)
	var veil := ColorRect.new()
	veil.color = Color(VEIL, 0.0)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.show_behind_parent = true
	add_child(veil)
	create_tween().tween_property(veil, "color:a", VEIL.a, 0.25)

	var title := UI.label(d.prompt, 22, UI.CREAM, true)
	title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	title.position = Vector2(0, 252)
	title.size = Vector2(SIZE.x, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	_name = UI.label("", 16, GLOW, true)
	_name.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_name.position = Vector2(0, 284)
	_name.size = Vector2(SIZE.x, 22)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_name)

	_out.resize(spots.size())
	for i in spots.size():
		var spot: Dictionary = spots[i]
		var option: Dictionary = d.options[spot.option]
		var price: int = option.get("price", 0)
		var view := ItemView.new(SHOWN)
		view.set_item(option.item)
		view.note = Loc.t("Copy it for %d coins.") % price if price > 0 else Loc.t("Copy it for free.")
		view.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		view.clicked.connect(_pick.bind(spot.option))
		view.picked.connect(_pick.bind(spot.option))
		view.mouse_entered.connect(_hover.bind(i))
		view.mouse_exited.connect(_unhover.bind(i))
		view.modulate.a = 0.0
		add_child(view)
		_views.append(view)
		_from.append(spot.from)
		_to.append(spot.to)
		_prices.append(price)
		_choice.append(spot.option)
		create_tween().tween_method(_rise.bind(i), 0.0, 1.0, RISE).set_delay(0.1 + i * RISE_STAGGER) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_wand = PlayFx.WandFx.new()
	_wand.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_wand.rest = HELD
	_wand.way = Vector2.UP
	_wand.rotation = -PI / 2.0
	_wand.out = 0.0
	add_child(_wand)
	create_tween().tween_property(_wand, "out", 1.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if d.cancellable:
		var back := UI.button("Cancel", UI.BORDER, 14)
		back.size = UI.grown(Vector2(120, 30))
		back.position = Vector2(SIZE.x / 2.0 - back.size.x / 2.0, 318)
		back.pressed.connect(_pick.bind(-1))
		add_child(back)
	_place()


## The floating items, in the order the keyboard walks them.
func views() -> Array[ItemView]:
	return _views


func _pick(index: int) -> void:
	picked.emit(index)


func _hover(index: int) -> void:
	_hovered = index


func _unhover(index: int) -> void:
	if _hovered == index:
		_hovered = -1


func _rise(amount: float, index: int) -> void:
	_out[index] = amount


func _process(delta: float) -> void:
	_time += delta
	_place()
	# The wand is all out before it turns: what is behind the counter is cut
	# along its own length.
	if _wand.out >= 1.0:
		var aim := -PI / 2.0 + sin(_time * 1.6) * 0.1
		if _hovered >= 0:
			aim = (_spot(_hovered) - _wand.position).angle()
		_wand.rotation = lerp_angle(_wand.rotation, aim, 1.0 - exp(-TURN * delta))
		_wand.charge = move_toward(_wand.charge, 1.0 if _hovered >= 0 else 0.0, delta * 6.0)
	queue_redraw()


## Where the middle of floating item `index` is now.
func _spot(index: int) -> Vector2:
	var out := _out[index]
	var bob := Vector2(0, sin(_time * 1.5 + index * 1.9) * 3.0)
	return _from[index].lerp(_to[index], out) + bob * out


func _place() -> void:
	for i in _views.size():
		var view := _views[i]
		view.position = (_spot(i) - view.size / 2.0).round()
		view.modulate.a = clampf(_out[i] * 2.5, 0.0, 1.0)
	_name.text = _views[_hovered].def.display_name.to_upper() if _hovered >= 0 else ""


func _draw() -> void:
	for i in _views.size():
		var out := _out[i]
		if out <= 0.0:
			continue
		var at := _spot(i)
		var lit := i == _hovered
		# A thread of light back to where the real one lies.
		var thread := at - _from[i]
		var steps := int(thread.length() / 6.0)
		for s: int in steps:
			if (s + int(_time * 6.0)) % 3 == 0:
				continue
			_dot(_from[i] + thread * (float(s) / maxi(steps, 1)), Color(GLOW, (0.5 if lit else 0.22) * out), 1)
		# Sparks about it, each blinking in its own time.
		for k: int in 5:
			var seed_ := i * 2.4 + k * 1.31
			var blink := fposmod(_time * (0.7 + 0.13 * k) + seed_, 1.0)
			var far := 30.0 + 5.0 * (k % 3) + (4.0 if lit else 0.0)
			var where := at + Vector2.from_angle(seed_ * 2.1 + _time * 0.35) * Vector2(far, far * 0.8)
			_star(where, Color(Color.WHITE if k % 2 == 0 else GLOW, sin(PI * blink) * out * (1.0 if lit else 0.6)), 2 if blink > 0.35 and blink < 0.65 else 1)
		# What the copy costs, under it.
		var tag := at + Vector2(-15, _views[i].size.y / 2.0 + 4.0)
		draw_texture_rect(_coin, Rect2(tag.round(), Vector2(14, 14)), false, Color(1, 1, 1, out))
		draw_string(UI.bold(), (tag + Vector2(17, 12)).round(), str(_prices[i]), HORIZONTAL_ALIGNMENT_LEFT, -1,
				UI.px(15), Color(_ink, out))
	if _hovered < 0 or _wand.charge <= 0.0:
		return
	# The wand has it: sparks run from its tip to the item.
	var tip := _wand.tip()
	var reach := _spot(_hovered) - tip
	var side := reach.orthogonal().normalized()
	for k: int in SPARKS:
		var along := fposmod(_time * 1.3 + float(k) / SPARKS, 1.0)
		var sway := sin(along * TAU * 1.5 + _time * 5.0 + k) * 5.0 * sin(PI * along)
		_dot(tip + reach * along + side * sway, Color(Color.WHITE if k % 3 == 0 else GLOW, sin(PI * along) * _wand.charge), 2 if k % 3 == 0 else 1)


func _dot(at: Vector2, ink: Color, cells: int) -> void:
	draw_rect(Rect2((at / PIXEL).floor() * PIXEL, Vector2(PIXEL, PIXEL) * cells), ink)


## A spark with four points, `arm` cells long.
func _star(at: Vector2, ink: Color, arm: int) -> void:
	var cell := (at / PIXEL).floor() * PIXEL
	draw_rect(Rect2(cell - Vector2(arm * PIXEL, 0), Vector2((arm * 2 + 1) * PIXEL, PIXEL)), ink)
	draw_rect(Rect2(cell - Vector2(0, arm * PIXEL), Vector2(PIXEL, (arm * 2 + 1) * PIXEL)), ink)
