extends Control
## The choice of a Materialize (a PICK decision with `context.look` set to
## &"cosmos"): no window. The table dims under a faint night sky and the
## items hang over it, on one orbit round the Morale that is about to be given up.
##
## What an item does to the purse is not written on it: it goes round it. A
## coin in orbit is a coin of change that comes back with the item; a dark
## coin, eclipsed, going round the other way, is a coin the Morale does not
## cover. An item with nothing round it is an even trade. The words are in
## the tooltip of each item, for whoever wants them.
##
## Everything but the items themselves (ItemView) is drawn in code.
##
## No class_name: use preload.

signal picked(index: int)

const SIZE := Vector2(1152, 648)
const CENTRE := Vector2(576, 300)
## The orbit the items are on, seen from a little above.
const ORBIT := Vector2(372, 184)
const PIXEL := 2.0
const COSMOS := Color("9b6bff")
const STARLIGHT := Color("d9d2ff")
const HEART_ART := "res://assets/ui/heart.png"
const COIN_ART := "res://assets/ui/coin.png"
const HEART_SIZE := 54.0
## The three images of the heart, a little apart (the Entity's look).
const PRISM := [[Color(1.0, 0.25, 0.3, 0.55), Vector2(-3, 0)], [Color(0.2, 0.95, 1.0, 0.55), Vector2(3, 0)], [Color.WHITE, Vector2.ZERO]]
## The coins round an item: how wide their orbit is, how big they are, how
## fast they go round.
const MOON_ORBIT := Vector2(46, 15)
const MOON := 16.0
const MOON_PACE := 1.5
const ECLIPSED := Color(0.2, 0.08, 0.3)
## Brighter than the picture: it is multiplied into the gold of the coin.
const ECLIPSE_RIM := Color(1.9, 0.45, 0.6)
## Seconds the items take to come out of the heart, and from one to the next.
const EMERGE := 0.4
const EMERGE_STAGGER := 0.045
## How dark the sky is over the table, which shows through it: the user
## found a closed night sky too far from the rest of the game.
const VEIL := 0.66
const SKY_SHADER := "shader_type canvas_item;

uniform float open = 1.0;
uniform vec2 centre = vec2(576.0, 300.0);
uniform float veil = 0.66;
const vec2 SCREEN = vec2(1152.0, 648.0);
const float PX = 2.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float cloud(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 cell = floor(UV * SCREEN / PX);
	vec2 off = (cell * PX - centre) / vec2(1.7, 1.0);
	float far = length(off);
	// The nebula turns slowly about the heart.
	float turn = TIME * 0.03 + far * 0.004;
	vec2 swirl = vec2(off.x * cos(turn) - off.y * sin(turn), off.x * sin(turn) + off.y * cos(turn)) / PX;
	float gas = cloud(swirl / 44.0) * 0.62 + cloud(swirl / 15.0 + 31.0) * 0.38;
	// Only a breath of it, and only near the heart: the table is still there.
	float level = clamp(gas * 0.9 + exp(-far / 150.0) * 0.6 - 0.62, 0.0, 1.0) * 4.0;
	// In a few tones, stippled where one gives way to the next.
	float low = floor(level);
	float edge = mod(cell.x + cell.y, 2.0) < 1.0 ? 0.3 : 0.7;
	level = (low + (level - low > edge ? 1.0 : 0.0)) / 4.0;
	vec3 tint = mix(vec3(0.34, 0.17, 0.62), vec3(0.08, 0.36, 0.5), cloud(swirl / 90.0 + 7.0));
	vec3 color = vec3(0.03, 0.018, 0.04) + tint * level * 0.3;
	float cover = veil + level * 0.14;
	// A few stars, each twinkling at its own pace.
	float star = hash(cell + 3.0);
	if (star > 0.9991) {
		float twinkle = 0.5 + 0.5 * sin(TIME * (0.8 + 3.5 * hash(cell + 9.0)) + star * 900.0);
		color += vec3(0.82, 0.84, 1.0) * (0.2 + 0.6 * twinkle * twinkle);
		cover = 0.9;
	}
	COLOR = vec4(color, cover * open);
}
"

var _decision: Decision
var _views: Array[ItemView] = []
var _homes: Array[Vector2] = []
var _coins: Array[int] = []
var _out := PackedFloat32Array()  # how far out of the heart each item is, 0 to 1
var _time := 0.0
var _hovered := -1
var _sky: ColorRect
var _front: Control
var _name: Label
var _heart: Texture2D
var _coin: Texture2D


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Lays out the options of `d`: [{item, coins, ...}].
func setup(d: Decision) -> void:
	_decision = d
	_heart = UI.tex(HEART_ART)
	_coin = UI.tex(COIN_ART)
	_sky = ColorRect.new()
	_sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky.show_behind_parent = true
	var look := ShaderMaterial.new()
	look.shader = Shader.new()
	look.shader.code = SKY_SHADER
	look.set_shader_parameter("open", 0.0)
	look.set_shader_parameter("centre", CENTRE)
	look.set_shader_parameter("veil", VEIL)
	_sky.material = look
	add_child(_sky)
	create_tween().tween_method(func(open: float) -> void: look.set_shader_parameter("open", open), 0.0, 1.0, 0.3)

	var title := UI.label(d.prompt, 22, STARLIGHT, true)
	title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	title.position = Vector2(0, 26)
	title.size = Vector2(SIZE.x, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

	var count: int = d.options.size()
	_out.resize(count)
	for i in count:
		var option: Dictionary = d.options[i]
		# Round the orbit from the top; a single item stands over the heart.
		var angle: float = -PI / 2.0 + TAU * i / maxi(count, 1)
		var home := CENTRE + Vector2(cos(angle), sin(angle)) * ORBIT
		var coins: int = option.get("coins", 0)
		var view := ItemView.new(1.0)
		view.set_item(option.item)
		view.note = _purse_note(coins)
		view.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		view.clicked.connect(_pick.bind(i))
		view.picked.connect(_pick.bind(i))
		view.mouse_entered.connect(_hover.bind(i))
		view.mouse_exited.connect(_unhover.bind(i))
		view.modulate.a = 0.0
		add_child(view)
		_views.append(view)
		_homes.append(home)
		_coins.append(coins)
		create_tween().tween_method(_emerge.bind(i), 0.0, 1.0, EMERGE).set_delay(0.12 + i * EMERGE_STAGGER) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# The coins that are on the near side of their item, over it.
	_front = Control.new()
	_front.set_anchors_preset(Control.PRESET_FULL_RECT)
	_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_front.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_front.draw.connect(_draw_moons.bind(_front, true))
	add_child(_front)
	_name = UI.label("", 18, STARLIGHT, true)
	_name.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_name.size = Vector2(240, 24)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name.hide()
	add_child(_name)

	if d.cancellable:
		var back := UI.button("Cancel", UI.BORDER, 15)
		back.size = Vector2(150, 34)
		back.position = Vector2(CENTRE.x - 75.0, SIZE.y - 46.0)
		# A word in the dark, with a thin line under it: no plate.
		for state: String in ["normal", "hover", "pressed", "focus"]:
			var line := StyleBoxFlat.new()
			line.bg_color = Color(COSMOS, 0.16 if state == "hover" else 0.0)
			line.border_color = Color(COSMOS, 0.9 if state == "hover" else 0.45)
			line.border_width_bottom = 2
			back.add_theme_stylebox_override(state, line)
		for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			back.add_theme_color_override(state, STARLIGHT)
		back.pressed.connect(_pick.bind(-1))
		add_child(back)
	_place()


## What an item does to the purse, in words, for its tooltip.
func _purse_note(coins: int) -> String:
	if coins > 0:
		return Loc.t("Comes with %d coins of change.") % coins
	if coins < 0:
		return Loc.t("Asks %d coins more than the Morale is worth.") % -coins
	return Loc.t("An even trade for the Morale.")


func _pick(index: int) -> void:
	picked.emit(index)


func _hover(index: int) -> void:
	_hovered = index


func _unhover(index: int) -> void:
	if _hovered == index:
		_hovered = -1


func _emerge(amount: float, index: int) -> void:
	_out[index] = amount


func _process(delta: float) -> void:
	_time += delta
	_place()
	queue_redraw()
	_front.queue_redraw()


## Where the middle of item `index` is now: on its way out of the heart, or
## in its place, bobbing.
func _spot(index: int) -> Vector2:
	var out := _out[index]
	var bob := Vector2(0, sin(_time * 1.3 + index * 1.7) * 4.0)
	return CENTRE.lerp(_homes[index], out) + bob * out


func _place() -> void:
	for i in _views.size():
		var view := _views[i]
		view.position = (_spot(i) - view.size / 2.0).round()
		view.modulate.a = clampf(_out[i] * 2.0, 0.0, 1.0)
	_name.visible = _hovered >= 0
	if _hovered >= 0:
		_name.text = _views[_hovered].def.display_name
		var at := _spot(_hovered)
		# Away from the heart: over the items of the upper half, under the rest.
		var below := at.y >= CENTRE.y
		_name.position = (Vector2(at.x - _name.size.x / 2.0, at.y + (44.0 if below else -68.0))).round()


func _draw() -> void:
	# The orbit: a ring of dust that drifts along it.
	var grains := 120
	for i in grains:
		var angle := TAU * i / grains + _time * 0.05
		var at := CENTRE + Vector2(cos(angle), sin(angle)) * ORBIT
		var bright := 0.16 + 0.2 * (0.5 + 0.5 * sin(angle * 5.0 - _time * 1.4))
		_dot(self, at, Color(STARLIGHT, bright), 1 if i % 3 > 0 else 2)
	# A line of stars from the heart to the item the mouse is on.
	if _hovered >= 0 and _out[_hovered] > 0.9:
		var to := _spot(_hovered)
		var steps := int(CENTRE.distance_to(to) / 12.0)
		for i in range(3, steps - 2):
			var glow := 0.35 + 0.65 * (0.5 + 0.5 * sin(i * 0.9 - _time * 7.0))
			_dot(self, CENTRE.lerp(to, float(i) / steps), Color(COSMOS.lightened(0.35), glow), 2)
	# The Morale itself, beating, in its three images.
	var beat := 1.0 + 0.07 * maxf(sin(_time * 3.2), 0.0) + 0.04 * maxf(sin(_time * 3.2 - 0.9), 0.0)
	var extent := Vector2.ONE * HEART_SIZE * beat
	for ring in 3:
		var radius := 46.0 + ring * 13.0 + fposmod(_time * 9.0, 13.0)
		var fade := 1.0 - (radius - 46.0) / 39.0
		for i in 28:
			var angle := TAU * i / 28.0 + ring * 0.4
			_dot(self, CENTRE + Vector2(cos(angle), sin(angle) * 0.62) * radius, Color(COSMOS, 0.5 * fade), 1)
	for image: Array in PRISM:
		var sway: Vector2 = image[1] * (1.0 + 0.6 * sin(_time * 2.1))
		draw_texture_rect(_heart, Rect2(CENTRE - extent / 2.0 + sway, extent), false, image[0])
	_draw_moons(self, false)


## The coins going round each item: those on the far side of it (`near`
## false: drawn before the items) or on the near side (drawn over them).
func _draw_moons(on: Control, near: bool) -> void:
	for i in _views.size():
		var coins := _coins[i]
		if coins == 0 or _out[i] < 0.95:
			continue
		var owed := coins < 0
		var count := absi(coins)
		var centre := _spot(i) + Vector2(0, 2)
		var lit := _hovered == i
		# Change goes round one way; what is owed, the other, and closer in.
		var pace := -MOON_PACE * 0.7 if owed else MOON_PACE
		var orbit := MOON_ORBIT * (0.88 if owed else 1.0) * (1.12 if lit else 1.0)
		for k in count:
			var angle := _time * pace + TAU * k / count + i * 0.8
			# sin > 0: the half of the orbit that is on our side.
			if (sin(angle) > 0.0) != near:
				continue
			var at := centre + Vector2(cos(angle), sin(angle)) * orbit
			var extent := Vector2.ONE * MOON * (1.0 + 0.16 * sin(angle))
			var box := Rect2((at - extent / 2.0).round(), extent.round())
			if owed:
				# Eclipsed: a dark disc with a thin red limb.
				on.draw_texture_rect(_coin, box.grow(PIXEL), false, Color(ECLIPSE_RIM, 1.0 if lit else 0.8))
				on.draw_texture_rect(_coin, box, false, ECLIPSED)
			else:
				on.draw_texture_rect(_coin, box, false, Color.WHITE if near else Color(0.72, 0.68, 0.8))
				if near and fposmod(angle, TAU) < 0.5:
					_dot(on, at + Vector2(-4, -4), Color.WHITE, 1)


func _dot(on: Control, at: Vector2, ink: Color, cells: int) -> void:
	var side := cells * PIXEL
	on.draw_rect(Rect2((at / PIXEL).round() * PIXEL - Vector2(side, side) / 2.0, Vector2(side, side)), ink)
