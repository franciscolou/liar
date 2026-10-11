extends SubViewport
## The painting of the title screen, alive: the lantern flickers and lights the
## room, clouds drift past the moon, and the man breathes, blinks, looks around
## and now and then pulls on his cigar.
##
## Each behaviour runs on its own clock, with its own random pauses, and they
## only meet where they would fight: while he smokes he does not look around,
## and he does not blink while blowing the smoke out.
##
## It is drawn at the size of the painting (1672x941), in whole pixels and
## with nearest filtering, and the menu shows the result scaled down as it
## always showed the painting. Every layer is cut from assets/StartScreen.png
## by tools/gen_menu_layers.py; the positions here follow the ones there.
## At rest (`still`) the picture is the painting itself.

const DIR := "res://assets/menu/"
const PAINTING := Vector2i(1672, 941)
# Where the layers go in the painting (SKY, GLASS and LANTERN in the tool).
const SKY_AT := Vector2(1384, 40)
const MOON := Vector2(1540, 200)
const GLASS_AT := Vector2(84, 282)
const FLAME_FOOT := 348.0
# The flame stops here: above it is the cap of the lantern, not glass.
const FLAME_TOP := 292.0
# The smoke of the cigar: the stretch of wall it may rise through, and the
# tip of the cigar it leaves from.
const SMOKE_AREA := Rect2(300, 0, 440, 302)
const EMBER := Vector2(511, 291)
const TRAIL := 44
const TRAIL_STEP := 0.3
# The man. Where each sprite was cut from (the boxes the tool prints).
const TORSO_AT := Vector2(100, 340)
const HEAD_AT := Vector2(298, 156)
const HAND_AT := Vector2(421, 289)
const HAND_RIM_AT := Vector2(419, 287)
const FOREARM_AT := Vector2(518, 364)
const EYE_LEFT_AT := Vector2(364, 258)
const EYE_RIGHT_AT := Vector2(420, 246)
const MOUTH_AT := Vector2(402, 298)
const EMBER_AT := Vector2(496, 282)
# The chest rises whole above the first line and not at all below the second.
const CHEST := Vector2(400, 530)
# The joints of the arm that holds the cigar. The forearm lies along
# FOREARM_AXIS, from the wrist to the elbow resting on the chair; taking the
# cigar from the mouth is sliding the forearm down that line (it tips
# towards us), with a little turn at the elbow and at the wrist.
const SHOULDER := Vector2(640, 430)
const ELBOW := Vector2(700, 545)
const WRIST := Vector2(548, 396)
const FOREARM_AXIS := Vector2(0.72, 0.69)
const LIPS := Vector2(430, 307)
const BREATH_AREA := Rect2(330, 0, 800, 460)
const PUFFS := 40
# The frames of an eye.
enum Eye { OPEN, HALF, SHUT, LEFT, RIGHT }
# The pull on the cigar, in seconds from its start: the hand presses in, he
# draws, takes the cigar away, holds the smoke, blows it out, and after a
# moment brings the hand back.
const DRAW := Vector2(0.6, 2.3)
const AWAY := Vector2(2.3, 3.2)
const BLOW := Vector2(3.6, 5.5)
const BACK := Vector2(6.3, 7.6)
const PULL_ENDS := 7.8

const SKY_SHADER := "shader_type canvas_item;
// The still sky, with two sheets of cloud drifting over it. A cloud is
// brighter the closer it is to the moon, and veils the moon as it passes.

uniform sampler2D clouds : repeat_enable, filter_nearest;
uniform vec2 size;
uniform vec2 tile;
uniform vec2 moon;
uniform float far_shift;
uniform float near_shift;
uniform float near_drop = 22.0;

void fragment() {
	vec2 px = floor(UV * size);
	vec3 sky = texture(TEXTURE, UV).rgb;
	float far = texture(clouds, (vec2(px.x - floor(far_shift), px.y) + 0.5) / tile).r;
	float near = texture(clouds, (vec2(-px.x + floor(near_shift), px.y + near_drop) + 0.5) / tile).r;
	near *= step(px.y + near_drop, tile.y - 1.0);
	float lit = smoothstep(74.0, 6.0, distance(px, moon));
	vec3 tone = mix(vec3(0.026, 0.026, 0.034), vec3(0.105, 0.092, 0.078), lit);
	float cover = far + near * 0.6;
	vec3 colour = sky + tone * cover;
	if (dot(sky, vec3(0.3, 0.59, 0.11)) > 0.3) {
		colour = sky * (1.0 - 0.3 * min(cover, 1.0));
	}
	COLOR = vec4(colour, 1.0);
}"

const FLAME_SHADER := "shader_type canvas_item;
render_mode blend_add;
// The flame is the light the painting has above the glow of the glass. Its
// rows slide sideways, more the higher they are, and it stretches from the
// wick: the pixels are the painting's, only moved.

uniform vec2 size;
uniform float foot;
uniform float top;
uniform float sway;
uniform float stretch;
uniform float power = 1.0;
uniform float time_s;

void fragment() {
	vec2 px = floor(UV * size);
	float up = clamp((foot - px.y) / 60.0, 0.0, 1.0);
	float lick = sin(px.y * 0.33 + time_s * 9.0) * 0.8 + sin(px.y * 0.19 + time_s * 5.3) * 0.7;
	float slide = floor(sway * 4.0 * up * up + lick * up * 1.3 + 0.5);
	float y = floor(foot - (foot - px.y) / (1.0 + stretch * up) + 0.5);
	vec2 from = (vec2(px.x - slide, min(y, size.y - 1.0)) + 0.5) / size;
	// It thins out to nothing under the cap, however tall it gets.
	float under = smoothstep(top, top + 9.0, px.y);
	COLOR = vec4(texture(TEXTURE, from).rgb * power * under, 1.0);
}"

const SMOKE_SHADER := "shader_type canvas_item;
// The thread of smoke off the tip of the cigar, in the blocks and the few
// tones of the painting. The scene lets go of a bit of smoke at the tip every
// moment and each one rises on its own (trail: x, y, age and how much smoke
// it was let go with, newest first); the thread is drawn through them. So
// when the hand moves, or the tip smokes less for a while, the smoke already
// in the air stays as it was: only what comes next is different. Each bit
// keeps the sideways push it was born with, so the curls travel up with it.
// Low down it is a tight thread; as it climbs it opens into a loose, thin
// cloud that breaks up into scattered pixels and is gone.

uniform vec2 size;
uniform float time_s;
uniform float life = 13.0;
uniform float cell = 2.0;
uniform vec4 trail[44];
uniform vec3 tone : source_color = vec3(0.6, 0.45, 0.35);

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
		3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float strand(vec2 px, float from, float age, float born, float seed, float girth) {
	float old = clamp(age / life, 0.0, 1.0);
	float push = sin(born * 1.9 + seed) * 0.55 + sin(born * 1.1 + seed * 2.3) * 0.5
			+ sin(born * 3.1 + seed * 0.7) * 0.22;
	float reach = 2.0 + 44.0 * sqrt(old);
	float middle = from + push * reach * smoothstep(0.0, 0.5, age)
			+ sin(age * 1.4 + time_s * 0.35 + seed) * 9.0 * old;
	float wide = (2.2 + 16.0 * old + 70.0 * old * old) * girth;
	// The same smoke over a wider stretch is thinner.
	float spread = mix(1.0, 0.5, smoothstep(0.25, 1.0, old));
	return (1.0 - smoothstep(wide * 0.3, wide, abs(px.x - middle))) * spread;
}

void fragment() {
	vec2 at = floor(UV * size / cell);
	vec2 px = (at + 0.5) * cell;
	// Higher up the air stirs it.
	float height = clamp((trail[0].y - px.y) / 300.0, 0.0, 1.0);
	vec2 air = px * 0.03 + vec2(0.0, time_s * 0.25);
	vec2 stirred = px + (vec2(noise(air), noise(air + 31.0)) - 0.5) * 34.0 * height * height;
	float thick = 0.0;
	for (int i = 0; i < 43; i++) {
		vec4 low = trail[i];
		vec4 high = trail[i + 1];
		float span = low.y - high.y;
		float along = (low.y - stirred.y) / (abs(span) < 0.01 ? 0.01 : span);
		if (along < 0.0 || along >= 1.0) {
			continue;
		}
		// Ease from one bit to the next, so the thread bends instead of
		// breaking at each of them.
		float from = mix(low.x, high.x, smoothstep(0.0, 1.0, along));
		float age = mix(low.z, high.z, along);
		float born = time_s - age;
		float old = clamp(age / life, 0.0, 1.0);
		float here = max(strand(stirred, from, age, born, 0.0, 1.0), strand(stirred, from, age, born, 2.6, 0.7) * 0.75);
		float torn = noise(vec2(stirred.x * 0.07, born * 1.5 + stirred.y * 0.01));
		here *= mix(1.0, torn * 1.9, sqrt(old));
		here *= (1.0 - smoothstep(0.45, 1.0, old)) * smoothstep(0.0, 0.1, age) * mix(low.w, high.w, along);
		thick = max(thick, here);
	}
	// Hard steps low down, where it is a thread; dithered ones higher, so
	// it thins out instead of ending.
	float step_at = BAYER[int(mod(at.y, 4.0)) * 4 + int(mod(at.x, 4.0))] / 16.0 - 0.5;
	thick += step_at * 0.22 * smoothstep(0.15, 0.6, height) * step(0.03, thick);
	float veil = thick > 0.55 ? 0.46 : thick > 0.3 ? 0.28 : thick > 0.1 ? 0.13 : 0.0;
	COLOR = vec4(tone, veil);
}"

const BREATH_SHADER := "shader_type canvas_item;
// The body, breathing: every row is drawn a few whole pixels higher, the
// shoulders the most and the waist not at all.

uniform vec2 size;
uniform float lift;
uniform float full;
uniform float none;

void fragment() {
	vec2 px = floor(UV * size);
	float share = clamp((none - px.y) / (none - full), 0.0, 1.0);
	float up = floor(lift * share + 0.5);
	COLOR = texture(TEXTURE, (vec2(px.x, min(px.y + up, size.y - 1.0)) + 0.5) / size);
}"

const PUFF_SHADER := "shader_type canvas_item;
// The smoke he blows out: round puffs (x, y, radius, strength) that the scene
// moves, melted together into one cloud. The air the cloud is in is not
// still: every pixel is pushed around by a slow noise that climbs with the
// smoke, which is what gives it its billows. Same blocks and tones as the
// smoke of the tip, but the steps between tones are dithered, so that the
// cloud thins out into scattered pixels instead of going out at once.

uniform vec2 size;
uniform float time_s;
uniform float cell = 2.0;
uniform int count = 0;
uniform vec4 puffs[40];
uniform vec3 tone : source_color = vec3(0.6, 0.45, 0.35);

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
		3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 at = floor(UV * size / cell);
	vec2 px = (at + 0.5) * cell;
	vec2 air = px * 0.022 + vec2(0.0, time_s * 0.22);
	vec2 pushed = px + (vec2(noise(air), noise(air + 31.0)) - 0.5) * 46.0
			+ (vec2(noise(air * 2.7 + 7.0), noise(air * 2.7 + 19.0)) - 0.5) * 16.0;
	float thick = 0.0;
	for (int i = 0; i < count; i++) {
		vec4 puff = puffs[i];
		thick += puff.w * (1.0 - smoothstep(0.15, 1.0, distance(pushed, puff.xy) / puff.z));
	}
	float torn = noise(px * 0.09 + vec2(time_s * 0.1, time_s * 0.4));
	thick *= 0.6 + torn * 0.8;
	float step_at = BAYER[int(mod(at.y, 4.0)) * 4 + int(mod(at.x, 4.0))] / 16.0;
	float level = floor(min(thick, 1.0) * 3.0 + 0.2 + step_at * 0.6);
	float veil = level >= 3.0 ? 0.44 : level >= 2.0 ? 0.29 : level >= 1.0 ? 0.14 : 0.0;
	COLOR = vec4(tone, veil);
}"

const LIGHT_SHADER := "shader_type canvas_item;
// What the light of the room does to the finished picture. The mask says,
// pixel by pixel, how much of the lantern gets there (r), which metal
// glints on its own (g) and where the lit windows far away are (b).

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform sampler2D mask : filter_nearest;
uniform float lantern;
uniform float windows;
uniform float glint;
uniform float time_s;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 colour = texture(screen, SCREEN_UV).rgb;
	vec3 m = texture(mask, UV).rgb;
	// Each piece of metal gleams in its own time.
	float turn = hash(floor(UV * vec2(1672.0, 941.0) / 14.0));
	float gleam = pow(max(sin(time_s * (0.5 + turn * 0.7) + turn * 40.0), 0.0), 8.0);
	colour *= 1.0 + m.r * lantern + m.g * gleam * glint + m.b * windows;
	COLOR = vec4(colour, 1.0);
}"

## Shows the painting as it is: nothing moves and no smoke is drawn.
@export var still := false

@export_group("Lantern")
## How fast the flame flickers.
@export var flame_speed := 1.0
## How much the flame sways and stretches.
@export var flame_unrest := 1.0
## How much the light of the room follows the flame (0.3 = up to 30% at the
## glass, about half of that on his face).
@export var lantern_light := 0.32
## Seconds between two gusts that bend the flame (min, max).
@export var gust_every := Vector2(3.5, 11.0)
## How much the metal in the room glints on its own.
@export var glint := 0.35

@export_group("Night")
## Pixels per second of the far and of the near sheet of cloud.
@export var cloud_speed := Vector2(1.1, 2.4)
## How much the lit windows of the house waver.
@export var window_light := 0.12

@export_group("Cigar smoke")
## How much smoke the tip gives off while resting.
@export var smoke_amount := 1.0
## Pixels per second the smoke climbs.
@export var smoke_rise := 24.0

@export_group("Breathing")
## Seconds of one breath; each one comes out a little shorter or longer.
@export var breath_seconds := 4.4
## Pixels of the painting the shoulders rise.
@export var breath_depth := 2.0
## Pixels the head rises over the shoulders.
@export var head_rise := 1.0

@export_group("Eyes")
## Seconds between two blinks (min, max).
@export var blink_every := Vector2(2.2, 6.5)
## Chance of a second blink right after one.
@export_range(0.0, 1.0) var double_blink := 0.2
## Seconds between two glances to the side (min, max).
@export var glance_every := Vector2(4.0, 10.0)
## Seconds a glance lasts (min, max).
@export var glance_lasts := Vector2(1.2, 3.2)

@export_group("Cigar")
## Seconds between two pulls on the cigar (min, max).
@export var pull_every := Vector2(14.0, 30.0)
## How fast the whole pull goes.
@export var pull_speed := 1.0
## Pixels the hand comes away from the mouth, along the forearm.
@export var hand_reach := 30.0
## Degrees the elbow and the wrist turn as the hand comes away.
@export var elbow_turn := 1.0
@export var wrist_turn := 4.0

var _clock := 0.0
var _noise := FastNoiseLite.new()
var _gust := 0.0
var _gust_in := 0.0
var _sky: ShaderMaterial
var _flame: ShaderMaterial
var _smoke: ShaderMaterial
var _light: ShaderMaterial
var _trail := PackedVector4Array()
var _hand_rim: Sprite2D
var _trail_in := 0.0
var _drift := Vector2.ZERO
var _torso: ShaderMaterial
var _head: Node2D
var _eyes: Array[Sprite2D] = []
var _mouth: Sprite2D
var _shoulder: Node2D
var _elbow: Node2D
var _wrist: Node2D
var _ember: Sprite2D
var _ember_glow: Sprite2D
var _breath: ShaderMaterial
var _puffs: Array[Dictionary] = []
var _puff_in := 0.0
var _breathing := 0.0
var _breath_pace := 1.0
var _head_follows := 0.0
var _blink := -1.0
var _blink_in := 3.0
var _blinked_twice := false
var _glance := 0
var _glance_in := 5.0
var _pull := -1.0
var _pull_in := 8.0


func _ready() -> void:
	size = PAINTING
	disable_3d = true
	canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	snap_2d_transforms_to_pixel = true
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	_noise.seed = randi()
	_clock = randf() * 100.0
	_gust_in = randf_range(gust_every.x, gust_every.y)
	_blink_in = randf_range(blink_every.x, blink_every.y)
	_glance_in = randf_range(glance_every.x, glance_every.y)
	_pull_in = randf_range(pull_every.x, pull_every.y) * 0.5

	var sky := _sprite("sky.png", SKY_AT)
	_sky = _shade(sky, SKY_SHADER)
	var clouds := UI.tex(DIR + "clouds.png")
	_sky.set_shader_parameter("clouds", clouds)
	_sky.set_shader_parameter("size", sky.texture.get_size())
	_sky.set_shader_parameter("tile", clouds.get_size())
	_sky.set_shader_parameter("moon", MOON - SKY_AT)

	_sprite("plate.png", Vector2.ZERO)

	var flame := _sprite("flame.png", GLASS_AT)
	_flame = _shade(flame, FLAME_SHADER)
	_flame.set_shader_parameter("size", flame.texture.get_size())
	_flame.set_shader_parameter("foot", FLAME_FOOT - GLASS_AT.y)
	_flame.set_shader_parameter("top", FLAME_TOP - GLASS_AT.y)

	_build_man()

	var smoke := ColorRect.new()
	smoke.position = SMOKE_AREA.position
	smoke.size = SMOKE_AREA.size
	add_child(smoke)
	_smoke = _shade(smoke, SMOKE_SHADER)
	_smoke.set_shader_parameter("size", SMOKE_AREA.size)
	var tip := _tip()
	for i in TRAIL:
		_trail.append(Vector4(tip.x, tip.y - smoke_rise * TRAIL_STEP * i, TRAIL_STEP * i, smoke_amount))

	var light := ColorRect.new()
	light.size = PAINTING
	add_child(light)
	_light = _shade(light, LIGHT_SHADER)
	_light.set_shader_parameter("mask", UI.tex(DIR + "light.png"))
	_step(0.0)


func _process(delta: float) -> void:
	_step(delta)


## Runs the scene `seconds` ahead at once (to look at a later moment of it).
func skip(seconds: float) -> void:
	for i in int(seconds * 60.0):
		_step(1.0 / 60.0)


func _step(delta: float) -> void:
	if not still:
		_clock += delta
	var t := _clock

	# The flame: a restless flicker, and now and then a gust that bends it.
	_gust_in -= delta
	if _gust_in <= 0.0:
		_gust_in = randf_range(gust_every.x, gust_every.y)
		_gust = randf_range(0.5, 1.0) * (1.0 if randf() < 0.5 else -1.0)
	_gust = move_toward(_gust, 0.0, delta * 1.6)
	var quick := t * flame_speed
	# A slow swell with a quick tremble on it, from -1 to 1.
	var flicker := clampf(_noise.get_noise_1d(quick * 1.6) * 1.5 + _noise.get_noise_1d(quick * 7.1 + 50.0) * 0.6, -1.0, 1.0)
	var glow := clampf(flicker - absf(_gust) * 0.9, -1.0, 1.0)
	var sway := (_noise.get_noise_1d(quick * 1.1 + 200.0) * 0.5 + _gust) * flame_unrest
	var stretch := (_noise.get_noise_1d(quick * 3.0 + 300.0) * 0.1 - absf(_gust) * 0.12) * flame_unrest
	if still:
		glow = 0.0
		sway = 0.0
		stretch = 0.0
	_flame.set_shader_parameter("time_s", t)
	_flame.set_shader_parameter("sway", sway)
	_flame.set_shader_parameter("stretch", stretch)
	_flame.set_shader_parameter("power", 1.0 + glow * 0.22)
	_light.set_shader_parameter("time_s", t)
	_light.set_shader_parameter("lantern", glow * lantern_light)
	_light.set_shader_parameter("glint", 0.0 if still else glint)
	_light.set_shader_parameter("windows",
			0.0 if still else _noise.get_noise_1d(t * 1.7 + 400.0) * window_light)

	# The clouds. The painting has them where a shift of zero puts the far sheet.
	if not still:
		_drift += cloud_speed * delta
	_sky.set_shader_parameter("far_shift", _drift.x)
	_sky.set_shader_parameter("near_shift", _drift.y)

	_move_man(delta)

	# The smoke, and where the tip of the cigar has been.
	# Every bit of smoke already in the air climbs on its own, with the
	# amount of smoke it left with; the newest one is still at the tip, and
	# now and then it is let go and another begins. Drawn on, the tip smokes
	# less; let go, it smokes more for a while: that only changes what
	# leaves from then on.
	var moved := 0.0 if still else delta
	for i in range(1, TRAIL):
		_trail[i] += Vector4(0.9 * moved, -smoke_rise * moved, moved, 0.0)
	_trail_in -= moved
	if _trail_in <= 0.0:
		_trail_in = TRAIL_STEP
		_trail.insert(1, _trail[0])
		_trail.resize(TRAIL)
	var drawing := _span(DRAW.x, DRAW.x + 0.4) * (1.0 - _span(AWAY.x, AWAY.y))
	var after := _span(AWAY.x, AWAY.y) * (1.0 - _span(BLOW.y, PULL_ENDS))
	var tip := _tip()
	_trail[0] = Vector4(tip.x, tip.y, 0.0,
			0.0 if still else smoke_amount * (1.0 - drawing * 0.7 + after * 0.6))
	if still:
		for i in TRAIL:
			_trail[i].w = 0.0
	_smoke.set_shader_parameter("time_s", t)
	_smoke.set_shader_parameter("trail", _trail)


## The tip of the cigar, inside the area the smoke is drawn in.
func _tip() -> Vector2:
	var tip := EMBER
	if _wrist != null:
		tip = _wrist.global_transform * (EMBER - WRIST)
	return tip - SMOKE_AREA.position


## Starts a pull on the cigar now (it happens by itself every `pull_every`).
func pull() -> void:
	if _pull < 0.0:
		_pull = 0.0


func _build_man() -> void:
	var torso := _sprite("torso.png", TORSO_AT)
	_torso = _shade(torso, BREATH_SHADER)
	_torso.set_shader_parameter("size", torso.texture.get_size())
	_torso.set_shader_parameter("full", CHEST.x - TORSO_AT.y)
	_torso.set_shader_parameter("none", CHEST.y - TORSO_AT.y)

	_head = Node2D.new()
	add_child(_head)
	_sprite("head.png", HEAD_AT, _head)
	_eyes = [_sprite("eye_left.png", EYE_LEFT_AT, _head, 5), _sprite("eye_right.png", EYE_RIGHT_AT, _head, 5)]
	_mouth = _sprite("mouth.png", MOUTH_AT, _head, 2)

	# Shoulder > elbow > forearm, and elbow > wrist > hand with the cigar.
	# The forearm is drawn over the hand: the watch hides the wrist turning.
	_shoulder = Node2D.new()
	_shoulder.position = SHOULDER
	add_child(_shoulder)
	_elbow = Node2D.new()
	_shoulder.add_child(_elbow)
	_wrist = Node2D.new()
	_wrist.position = WRIST - ELBOW
	_elbow.add_child(_wrist)
	_sprite("hand.png", HAND_AT - WRIST, _wrist)
	# The blended edge of the hand, for as long as the hand is where it was
	# painted (it would drag a line of his face along if it went with it).
	_hand_rim = _sprite("hand_rim.png", HAND_RIM_AT - WRIST, _wrist)
	_ember = _sprite("ember.png", EMBER_AT - WRIST, _wrist, 3)
	_ember_glow = _sprite("ember_glow.png", EMBER - WRIST - Vector2(32, 32), _wrist)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_ember_glow.material = add
	_sprite("forearm.png", FOREARM_AT - ELBOW, _elbow)

	var breath := ColorRect.new()
	breath.position = BREATH_AREA.position
	breath.size = BREATH_AREA.size
	add_child(breath)
	_breath = _shade(breath, PUFF_SHADER)
	_breath.set_shader_parameter("size", BREATH_AREA.size)


## How far the pull is between two of its moments, eased, from 0 to 1.
func _span(from: float, to: float) -> float:
	if _pull < 0.0:
		return 0.0
	return smoothstep(from, to, _pull)


## Moves the man for this frame.
func _move_man(delta: float) -> void:
	if still:
		delta = 0.0
	# The pull on the cigar, which the rest has to make room for.
	if _pull >= 0.0:
		_pull += delta * pull_speed
		if _pull >= PULL_ENDS:
			_pull = -1.0
			_pull_in = randf_range(pull_every.x, pull_every.y)
			_glance_in = maxf(_glance_in, 1.5)
	else:
		_pull_in -= delta
		if _pull_in <= 0.0 and not still:
			_pull = 0.0
	var pulling := _pull >= 0.0
	var drawing := _span(DRAW.x, DRAW.x + 0.5) * (1.0 - _span(AWAY.x - 0.2, AWAY.x + 0.3))
	var away := _span(AWAY.x, AWAY.y) * (1.0 - _span(BACK.x, BACK.y))
	var blowing := pulling and _pull > BLOW.x - 0.1 and _pull < BLOW.y + 0.15

	# Breathing: in a little faster than out, a pause, and no two the same.
	# Drawing on the cigar fills the chest; blowing empties it.
	_breathing += delta / (breath_seconds * _breath_pace)
	if _breathing >= 1.0:
		_breathing -= 1.0
		_breath_pace = randf_range(0.88, 1.18)
	var air := smoothstep(0.0, 0.4, _breathing) * (1.0 - smoothstep(0.45, 0.92, _breathing))
	if pulling:
		var filled := _span(DRAW.x, DRAW.y) * 1.4 * (1.0 - _span(BLOW.x, BLOW.y))
		var taken := _span(0.0, DRAW.x) * (1.0 - _span(BLOW.y, PULL_ENDS))
		air = lerpf(air, filled, taken)
		if _pull > BLOW.y:
			# Pick the breath up again from empty.
			_breathing = 0.0 if air < 0.05 else _breathing
	if still:
		air = 0.0
	_head_follows = lerpf(_head_follows, air, clampf(delta * 5.0, 0.0, 1.0)) if not still else 0.0
	var chest := roundf(air * breath_depth)
	var head := chest + roundf(_head_follows * head_rise)
	_torso.set_shader_parameter("lift", chest)
	_head.position = Vector2(0, -head)

	# The eyes. A blink is half shut, shut, half shut.
	var lid := Eye.OPEN
	if _blink >= 0.0:
		_blink += delta
		lid = Eye.HALF if _blink < 0.05 else Eye.SHUT if _blink < 0.13 else Eye.HALF
		if _blink >= 0.19:
			_blink = -1.0
			if not _blinked_twice and randf() < double_blink:
				_blinked_twice = true
				_blink_in = randf_range(0.1, 0.22)
			else:
				_blinked_twice = false
				_blink_in = randf_range(blink_every.x, blink_every.y)
	elif not still:
		_blink_in -= delta
		if _blink_in <= 0.0 and not blowing:
			_blink = 0.0
	# Glances: to one side for a while, then back; often with a blink.
	if pulling:
		_glance = 0
	elif not still:
		_glance_in -= delta
		if _glance_in <= 0.0:
			if _glance == 0:
				_glance = -1 if randf() < 0.5 else 1
				_glance_in = randf_range(glance_lasts.x, glance_lasts.y)
			else:
				_glance = 0
				_glance_in = randf_range(glance_every.x, glance_every.y)
			if _blink < 0.0 and randf() < 0.4:
				_blink = 0.0
	var eye := lid
	if eye == Eye.OPEN:
		# He narrows his eyes while he draws and while he blows.
		if drawing > 0.5 or blowing:
			eye = Eye.HALF
		elif _glance != 0:
			eye = Eye.LEFT if _glance < 0 else Eye.RIGHT
	if still:
		eye = Eye.OPEN
	for sprite in _eyes:
		sprite.frame = eye
	_mouth.frame = 1 if blowing else 0

	# The arm. At the mouth the hand goes with the head, so the cigar stays
	# on his lips; away from it, with the shoulders.
	var press := _span(0.0, DRAW.x) * (1.0 - _span(AWAY.x, AWAY.x + 0.3))
	var reach := away * hand_reach - press * 3.0
	_shoulder.position = SHOULDER + Vector2(0, -lerpf(head, chest, away))
	_elbow.position = ELBOW - SHOULDER + (FOREARM_AXIS.normalized() * reach).round()
	_elbow.rotation_degrees = away * elbow_turn
	_wrist.rotation_degrees = away * wrist_turn
	_hand_rim.visible = is_zero_approx(reach)

	# The tip: it brightens as he draws and cools slowly after.
	var heat := 0.0
	if pulling:
		heat = _span(DRAW.x, DRAW.x + 0.7) * (1.0 - 0.75 * _span(AWAY.x - 0.1, AWAY.y)) \
				* (1.0 - _span(BLOW.x, BACK.x))
		heat *= 1.0 + sin(_pull * 23.0) * 0.08
	var glow := heat + (0.0 if still else 0.06 + _noise.get_noise_1d(_clock * 2.0 + 700.0) * 0.05)
	_ember.frame = 0 if heat < 0.2 else 1 if heat < 0.65 else 2
	_ember_glow.modulate = Color(1, 1, 1, clampf(glow, 0.0, 1.0) * 0.8)

	# The smoke he blows. A puff leaves the lips fast, the air stops it, and
	# from then on it does what warm smoke does: climbs, wanders and keeps
	# spreading, thinner the wider it gets, until there is nothing to see.
	if blowing and _pull > BLOW.x and _pull < BLOW.y:
		_puff_in -= delta
		while _puff_in <= 0.0 and _puffs.size() < PUFFS:
			_puff_in += (BLOW.y - BLOW.x) / pull_speed / (PUFFS - 2)
			var strength := 1.0 - 0.5 * _span(BLOW.x, BLOW.y)
			_puffs.append({
				"at": LIPS + _head.position + Vector2(randf_range(-1, 1), randf_range(-1, 1)),
				"speed": Vector2(randf_range(190, 280), randf_range(-40, 10)) * strength,
				"climb": randf_range(14.0, 30.0),
				"turn": randf() * TAU,
				"age": 0.0,
				"life": randf_range(12.0, 17.0),
			})
	var packed := PackedVector4Array()
	for puff in _puffs:
		puff.age += delta
		puff.speed.x *= exp(-1.2 * delta)
		puff.speed.y = lerpf(puff.speed.y, -puff.climb, 1.0 - exp(-0.9 * delta))
		var wander := Vector2(sin(puff.age * 0.6 + puff.turn) * 11.0 + 7.0, cos(puff.age * 0.45 + puff.turn) * 5.0)
		puff.at += (puff.speed + wander * minf(puff.age * 0.5, 1.0)) * delta
		var old: float = puff.age / puff.life
		var wide := 4.0 + 96.0 * (1.0 - exp(-puff.age * 0.22))
		var there := (1.0 - smoothstep(0.35, 1.0, old)) * minf(puff.age / 0.12, 1.0)
		packed.append(Vector4(puff.at.x - BREATH_AREA.position.x, puff.at.y - BREATH_AREA.position.y,
				wide, there * clampf(26.0 / wide, 0.26, 0.9)))
	_puffs = _puffs.filter(func(puff: Dictionary) -> bool: return puff.age < puff.life)
	var sent := packed.size()
	packed.resize(PUFFS)
	_breath.set_shader_parameter("puffs", packed)
	_breath.set_shader_parameter("count", sent)
	_breath.set_shader_parameter("time_s", _clock)


func _sprite(file: String, at: Vector2, parent: Node = null, frames := 1) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = UI.tex(DIR + file)
	sprite.centered = false
	sprite.hframes = frames
	sprite.position = at
	(self if parent == null else parent).add_child(sprite)
	return sprite


func _shade(item: CanvasItem, code: String) -> ShaderMaterial:
	var look := ShaderMaterial.new()
	look.shader = Shader.new()
	look.shader.code = code
	item.material = look
	return look
