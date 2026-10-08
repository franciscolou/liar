extends Control
## The winner's hand, as the backdrop of the end screen. The screen starts
## dark, with only the winner's name on it; then the mirror breaks down the middle and, in the same blow, the two
## characters they were holding come up, one on each half. The crack is
## the divider, a jagged line from top to bottom; where
## the blow landed, halfway down it, a small web of splinters mixes up pieces
## of the two pictures.
##
## `revealed` tells the end screen when to bring its buttons in. Everything is
## one shader on one rectangle; nothing here is an asset but the sound.
##
## No class_name: use preload.

signal revealed

## The big paintings the cards were cut from. A character without one shows
## the art of its card, with no frame around it.
const PORTRAIT_DIR := "res://assets/prototype2/"
const SOUND := "res://assets/sounds/mirror_shatter.wav"
## Seconds: the dark before anything, the title coming up, the wait with
## only the title on the screen, the crack running to the edges and the
## pictures coming up with it.
const DARK := 0.4
const TITLE := 0.9
const SUSPENSE := 1.1
const CRACK := 0.45
const RISE := 0.9
const SCREEN := Vector2(1152, 648)

const SHADER := "
shader_type canvas_item;

uniform sampler2D left_art : filter_linear, repeat_disable;
uniform sampler2D right_art : filter_linear, repeat_disable;
// Width over height of each picture, and whether the right one is flipped.
uniform float left_aspect = 0.55;
uniform float right_aspect = 0.55;
uniform bool right_flipped = false;
uniform vec2 extent = vec2(1152.0, 648.0);
uniform vec2 impact = vec2(576.0, 300.0);
uniform float lit = 0.0;      // the pictures coming out of the dark; the cracks show without it
uniform float shatter = 0.0;  // how far the cracks have run, 0..1
uniform float flash = 0.0;
uniform float seed = 0.0;

const float SPOKES = 12.0;    // cracks leaving the impact; two of them are the divider
const float RINGS = 3.0;      // rows of splinters around it
const float WEB = 78.0;       // radius of the web, in pixels
const float REACH = 900.0;    // how far the longest cracks go
const float BLOCK = 2.0;      // the cracks are cut in blocks, like the rest of the game

float hash(vec2 v) {
	return fract(sin(dot(v, vec2(127.1, 311.7)) + seed * 17.0) * 43758.5453);
}

// Where spoke `k` leaves the impact, in turns. Spokes 0 and SPOKES / 2 point
// straight up and down: they are the divider.
float spoke(float k) {
	float m = mod(k, SPOKES);
	float jitter = (m == 0.0 || m == SPOKES * 0.5) ? 0.0 : (hash(vec2(m, 3.0)) - 0.5) * 0.7;
	return (k + jitter) / SPOKES;
}

// How far spoke `k` runs: the divider to the edges, a few others a good way
// out of the web, the rest die just past it.
float spoke_reach(float k) {
	float m = mod(k, SPOKES);
	if (m == 0.0 || m == SPOKES * 0.5) {
		return REACH;
	}
	float h = hash(vec2(m, 11.0));
	return h < 0.3 ? WEB * (2.0 + h * 4.0) : WEB * (1.1 + h * 0.6);
}

// A zigzag over (distance, direction), so no crack is a straight line.
float kink(float along, float turn) {
	vec2 at = vec2(along, turn * 8.0);
	vec2 cell = floor(at);
	vec2 f = fract(at);
	float a = hash(vec2(cell.x, mod(cell.y, 8.0)));
	float b = hash(vec2(cell.x + 1.0, mod(cell.y, 8.0)));
	float c = hash(vec2(cell.x, mod(cell.y + 1.0, 8.0)));
	float d = hash(vec2(cell.x + 1.0, mod(cell.y + 1.0, 8.0)));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y) - 0.5;
}

bool merged(float sector, float ring) {
	return hash(vec2(sector * 7.0 + 1.0, ring)) < 0.28;
}

// One of the two pictures at pixel `p`, each filling its half of the screen
// (cropped, the top of the picture kept).
vec3 picture(bool right, vec2 p) {
	float half_width = extent.x * 0.5;
	float aspect = right ? right_aspect : left_aspect;
	vec2 uv = vec2((p.x - (right ? half_width : 0.0)) / half_width, p.y / extent.y);
	float frame = half_width / extent.y;
	if (aspect < frame) {
		float shown = aspect / frame;
		uv.y = (1.0 - shown) * 0.12 + uv.y * shown;
	} else {
		float shown = frame / aspect;
		uv.x = (1.0 - shown) * 0.5 + uv.x * shown;
	}
	if (right && right_flipped) {
		uv.x = 1.0 - uv.x;
	}
	return right ? texture(right_art, uv).rgb : texture(left_art, uv).rgb;
}

void fragment() {
	vec2 p = UV * extent;
	vec2 q = floor(p / BLOCK) * BLOCK + BLOCK * 0.5;
	vec2 d = q - impact;
	float r = max(length(d), 1.0);
	// Turns clockwise from straight up, bent by the zigzag.
	float turn = fract(atan(d.x, -d.y) / TAU);
	float bend = kink(r / 30.0, turn) * 14.0;
	// Out of the web the cracks wander more: the divider is a bolt, not a ruler.
	bend += kink(r / 85.0 + 31.0, turn) * 70.0 * smoothstep(WEB * 0.8, WEB * 2.5, r);
	turn += bend / (TAU * max(r, 24.0));
	float front = shatter * REACH;

	// The sector between two spokes.
	float k = floor(turn * SPOKES);
	float low = spoke(k);
	if (turn < low) {
		k -= 1.0;
		low = spoke(k);
	}
	float high = spoke(k + 1.0);
	if (turn >= high) {
		k += 1.0;
		low = high;
		high = spoke(k + 1.0);
	}
	float sector = mod(k, SPOKES);
	bool right = sector < SPOKES * 0.5;

	// The cracks along the two spokes.
	float crack = 99.0;
	float wide = 0.0;
	float near_low = (turn - low) * TAU * r;
	float near_high = (high - turn) * TAU * r;
	if (r < min(spoke_reach(k), front)) {
		crack = near_low;
		wide = mod(k, SPOKES * 0.5) == 0.0 ? 1.0 : 0.0;
	}
	if (r < min(spoke_reach(k + 1.0), front) && near_high < crack) {
		crack = near_high;
		wide = mod(k + 1.0, SPOKES * 0.5) == 0.0 ? 1.0 : 0.0;
	}

	// The rows of splinters: straight chords from spoke to spoke.
	float middle = (low + high) * 0.5;
	float chord = r * cos((turn - middle) * TAU) / cos((high - low) * 0.5 * TAU);
	float row = pow(chord / WEB, 0.8) * RINGS + (hash(vec2(sector, 5.0)) - 0.5) * 0.7;
	float ring = max(floor(row), 0.0);
	float shard = merged(sector, ring) ? ring + 1.0 : ring;
	bool splinter = shard < RINGS && r < front;
	if (r < front && ring < RINGS) {
		float step_px = WEB / RINGS;
		if (ring > 0.0 && !merged(sector, ring - 1.0)) {
			crack = min(crack, fract(row) * step_px);
		}
		if (!merged(sector, ring)) {
			crack = min(crack, (1.0 - fract(row)) * step_px);
		}
	}

	// What this piece of glass shows.
	vec3 color;
	if (splinter) {
		// The closer to the impact, the more the two pictures trade places.
		float trade = 0.12 + 0.4 * (1.0 - shard / RINGS);
		vec2 nudge = (vec2(hash(vec2(sector, shard + 20.0)), hash(vec2(sector, shard + 40.0))) - 0.5) * 18.0;
		vec2 at = p + nudge;
		bool other = hash(vec2(sector + 60.0, shard)) < trade;
		if (other) {
			// The other picture, as that side of the mirror would show it.
			at.x = extent.x - at.x;
			right = !right;
		}
		at.x = right ? max(at.x, extent.x * 0.5) : min(at.x, extent.x * 0.5);
		color = picture(right, at) * (0.82 + 0.4 * hash(vec2(sector, shard + 80.0)));
	} else if (r < front) {
		color = picture(right, p);
	} else {
		// Not broken yet: the two pictures meet at a soft seam.
		float seam = smoothstep(-26.0, 26.0, p.x - extent.x * 0.5);
		color = mix(picture(false, min(p, vec2(extent.x * 0.5, extent.y))),
				picture(true, max(p, vec2(extent.x * 0.5, 0.0))), seam);
		color *= 1.0 - 0.55 * (1.0 - abs(seam * 2.0 - 1.0));
	}

	// The cracks: a dark gap with a bright lip, thicker along the divider.
	float width = BLOCK * (1.0 + wide);
	color *= 1.0 - 0.55 * (1.0 - smoothstep(width, width + 7.0, crack));
	// The edges of the room stay dark.
	vec2 centred = UV - 0.5;
	color *= lit * (1.0 - 0.9 * dot(centred, centred));
	float lip = 1.0 - step(width, crack);
	float glint = 0.35 + 0.65 * hash(floor(q / 6.0));
	float shine = 0.5 + 0.5 * lit;
	color = mix(color, vec3(0.78, 0.9, 1.0) * glint * shine, lip * 0.85);
	// The impact: glass ground to powder.
	float powder = (1.0 - smoothstep(3.0, 13.0, r)) * step(r, front);
	color = mix(color, vec3(0.85, 0.93, 1.0) * (0.4 + 0.6 * hash(floor(q / BLOCK))) * shine, powder);

	color += vec3(0.9, 0.95, 1.0) * flash * (1.0 - smoothstep(0.0, 520.0, r));
	COLOR = vec4(color, 1.0);
}
"

var _winner := ""
var _cards: Array = []
var _glass: ColorRect
var _look: ShaderMaterial
var _captions: Control


## `cards`: the character ids of the winner's hand; the first two are shown.
func _init(winner: String, cards: Array) -> void:
	_winner = winner
	_cards = cards


func _ready() -> void:
	size = SCREEN
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dark := ColorRect.new()
	dark.color = Color.BLACK
	dark.size = SCREEN
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dark)

	var left: CharacterDef = Content.character(_cards[0])
	# A hand of one card faces its own reflection.
	var right: CharacterDef = Content.character(_cards[1]) if _cards.size() > 1 else left
	var shader := Shader.new()
	shader.code = SHADER
	_look = ShaderMaterial.new()
	_look.shader = shader
	_show(left, "left")
	_show(right, "right")
	_look.set_shader_parameter("right_flipped", _cards.size() < 2)
	_look.set_shader_parameter("extent", SCREEN)
	_look.set_shader_parameter("impact", SCREEN * Vector2(0.5, 0.5))
	_look.set_shader_parameter("seed", randf())
	_glass = ColorRect.new()
	_glass.size = SCREEN
	_glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glass.material = _look
	add_child(_glass)

	_captions = Control.new()
	_captions.size = SCREEN
	_captions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_captions.modulate.a = 0.0
	add_child(_captions)
	_caption(Loc.t("%s WINS") % _winner.to_upper(), 46, UI.GOLD, Rect2(0, 22, SCREEN.x, 56), HORIZONTAL_ALIGNMENT_CENTER)
	_caption("Carcaj has a new boss", 18, UI.CREAM, Rect2(0, 76, SCREEN.x, 26), HORIZONTAL_ALIGNMENT_CENTER)
	_run()


func _run() -> void:
	var title := create_tween()
	title.tween_interval(DARK)
	title.tween_property(_captions, "modulate:a", 1.0, TITLE)
	title.tween_interval(SUSPENSE)
	await title.finished
	_strike()
	var blow := create_tween().set_parallel()
	blow.tween_method(_tune.bind("shatter"), 0.0, 1.0, CRACK).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	blow.tween_method(_tune.bind("flash"), 0.9, 0.0, 0.5)
	blow.tween_method(_tune.bind("lit"), 0.0, 1.0, RISE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	UI.shake(_glass, 9.0, 0.35)
	await blow.finished
	revealed.emit()


func _tune(value: float, uniform: String) -> void:
	_look.set_shader_parameter(uniform, value)


func _show(character: CharacterDef, side: String) -> void:
	var file := character.texture_path.get_file()
	var art := UI.tex(PORTRAIT_DIR + file)
	if art == null and UI.CARD_ART_DIR != "":
		art = UI.tex(UI.CARD_ART_DIR + file)
	if art == null:
		art = UI.tex(character.texture_path)
	_look.set_shader_parameter(side + "_art", art)
	_look.set_shader_parameter(side + "_aspect", art.get_size().aspect())


func _strike() -> void:
	var stream: AudioStream = null
	if ResourceLoader.exists(SOUND):
		stream = load(SOUND)
	elif FileAccess.file_exists(SOUND):
		# Not imported yet (the editor has not rescanned): read the file directly.
		stream = AudioStreamWAV.load_from_file(SOUND)
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = Settings.SFX_BUS
	add_child(player)
	player.play()


func _caption(text: String, font_size: int, color: Color, box: Rect2, align: HorizontalAlignment) -> void:
	var caption := UI.label(text, font_size, color, true)
	caption.position = box.position
	caption.size = box.size
	caption.horizontal_alignment = align
	caption.add_theme_constant_override("outline_size", 8)
	caption.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_captions.add_child(caption)
