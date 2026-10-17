extends Node
## Whether the game is played by touch (a phone, a tablet) or by mouse and
## keyboard. The flag itself is `UI.touch`, read by any widget that behaves
## differently under a finger; this node decides it and switches it.
##
## Decided once, when the first screen loads its settings (`decide`):
##   - `--touch` / `--desktop` on the command line win (Debug → Customize Run
##     Instances, or after `--` on a plain command line);
##   - otherwise the `touch` feature tag (the Android export preset carries it,
##     and a run instance can be given it too) or a mobile platform turn it on.
## On a computer, touch mode also makes the mouse act as a finger
## (`Input.emulate_touch_from_mouse`) and shapes the window like a phone
## (`PHONE`), so the touch code paths can be tried without a device.
##
## In a debug build on a computer, F10 switches between the two modes while the
## game runs. Screens that can rebuild themselves for the other mode answer
## `touch_changed()`; any other screen except the match is reloaded. The match
## is never reloaded (the engine is a coroutine): input checks switch at once,
## and its layout waits for the next screen.
##
## Gestures, in touch mode. A finger has no hover and no right button, and the
## widgets of this game act on the press of the left button. So the press is
## held back here until the finger says what it meant:
##   - a tap (let go where it went down, before `HOLD_MS`): the press and the
##     release go on to the screen together, untouched (a double tap keeps
##     its `double_click`);
##   - a drag (moved more than `SLOP` px): the press goes on, then the moves,
##     so sliders, the suspect book and the house rules sheet still drag;
##   - a hold (still for `HOLD_MS`): no click at all. The control under the
##     finger gets the mouse over it and shows its tooltip until the finger
##     lets go (`TipLayer.explain`), and `held` says which control it was, for
##     a screen that gives the hold a meaning of its own (the lobby reads a
##     character with it, as with a right click).
## The right button is ignored in touch mode, so a computer does not hide what
## a phone cannot do. All of this works on mouse events: a phone makes them
## from its touches, and a computer in touch mode has them already.
##
## The phone's back button acts as Esc (`ui_cancel`).
##
## Nothing here touches the rules, the bots or the room: a touch machine and a
## desktop one play the same match.
##
## No class_name: use preload.

const NODE_NAME := "TouchMode"
## The window touch mode gives a computer: a 19.5:9 phone on its side.
const PHONE := Vector2i(1170, 540)
## The debug key that switches modes. Not F9: a game run from the editor
## stops in the debugger on it.
const SWITCH_KEY := KEY_F10
## The scene that is never reloaded on a switch.
const MATCH_SCENE := "res://scenes/main.tscn"
## Seconds the note saying which mode is on stays up.
const NOTE_TIME := 1.6
## Milliseconds a still finger takes to become a hold.
const HOLD_MS := 450
## How far a finger may wander (viewport px) and still be a tap or a hold.
const SLOP := 10.0

## A finger held still on `control` (the one under it, or null).
signal held(control: Control)

static var _decided := false

var _desktop_size := Vector2i.ZERO
var _note: Label
var _note_tween: Tween
## The press of the finger that is down, held back until it is a tap, a drag or
## a hold; null when there is none waiting.
var _pending: InputEventMouseButton
var _pressed_at := 0
## The finger that is down was a hold: its release is swallowed.
var _holding := false
## This node is sending an event on itself: it goes through untouched.
var _replaying := false


## Decides the mode, once. Called by `Settings.ensure_loaded`.
static func decide() -> void:
	if _decided:
		return
	_decided = true
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	var on := OS.has_feature("touch") or OS.has_feature("mobile")
	if args.has("--touch"):
		on = true
	elif args.has("--desktop"):
		on = false
	var root := (Engine.get_main_loop() as SceneTree).root
	var box: Node = new()
	box.name = NODE_NAME
	# The root is busy while the first scene is on its way in.
	root.add_child.call_deferred(box)
	_apply(on)


## Whether F10 may switch modes here: never on a real phone, never in a release.
static func can_switch() -> bool:
	return OS.is_debug_build() and not OS.has_feature("mobile")


## The node, for connecting to `held`; null before the first screen loads.
static func node() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node_or_null(NODE_NAME)


## Switches to `on`, rebuilding (or reloading) the screen.
static func set_touch(on: bool) -> void:
	if on == UI.touch:
		return
	var box: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null(NODE_NAME)
	if box != null:
		box._switch(on)
	else:
		_apply(on)


static func _apply(on: bool) -> void:
	UI.touch = on
	if not OS.has_feature("mobile"):
		Input.emulate_touch_from_mouse = on


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Input goes to the last child of the root first, and every scene that
	# comes in is put after this node: it has to stay last to see the press
	# before any screen does.
	get_tree().node_added.connect(func(added: Node) -> void:
		if added != self and added.get_parent() == get_parent():
			get_parent().move_child.call_deferred(self, -1))
	if UI.touch and not OS.has_feature("mobile"):
		_shape_window.call_deferred(true)


func _process(_delta: float) -> void:
	if _pending != null and Time.get_ticks_msec() - _pressed_at >= HOLD_MS:
		_hold()


func _input(event: InputEvent) -> void:
	if _replaying:
		return
	if event is InputEventKey:
		if can_switch() and event.pressed and not event.echo and SWITCH_KEY in [event.keycode, event.physical_keycode]:
			get_viewport().set_input_as_handled()
			# Not while the key is still being handed around: the screen may reload.
			_switch.call_deferred(not UI.touch)
		return
	if not UI.touch:
		return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		# A Button presses on a touch of its own, and the finger also comes
		# as the mouse it is turned into (held back and sent on below): left
		# to reach the screen, every tap pressed a button twice (a stepper
		# went up by 2 on a phone). The mouse is the only way in.
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_finger(event)
	elif event is InputEventMouseMotion and (_pending != null or _holding):
		if _holding:
			get_viewport().set_input_as_handled()
		elif event.position.distance_to(_pending.position) > SLOP:
			# A drag: the press goes on first, then this move.
			get_viewport().set_input_as_handled()
			_send([_pending, event])
			_pending = null


func _finger(event: InputEventMouseButton) -> void:
	if event.pressed:
		get_viewport().set_input_as_handled()
		_pending = event
		_pressed_at = Time.get_ticks_msec()
		_holding = false
		return
	if _holding:
		get_viewport().set_input_as_handled()
		_holding = false
		if TipLayer.current != null:
			TipLayer.current.hide_all()
	elif _pending != null:
		# A tap: the press goes on, then this release.
		get_viewport().set_input_as_handled()
		_send([_pending, event])
		_pending = null


## Sends `events` on to the screen, in order, once the one being handed
## around now is done with.
func _send(events: Array) -> void:
	_push.call_deferred(events)


func _push(events: Array) -> void:
	_replaying = true
	for event: InputEvent in events:
		get_viewport().push_input(event, true)
	_replaying = false


func _hold() -> void:
	var at := _pending.position
	_pending = null
	_holding = true
	# The mouse goes over what the finger is on, the way a hover would.
	var over := InputEventMouseMotion.new()
	over.position = at
	over.global_position = at
	_push([over])
	var control := get_viewport().gui_get_hovered_control()
	TipLayer.explain(control)
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(15)
	held.emit(control)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		for pressed: bool in [true, false]:
			var back := InputEventAction.new()
			back.action = &"ui_cancel"
			back.pressed = pressed
			Input.parse_input_event(back)


func _switch(on: bool) -> void:
	_pending = null
	_holding = false
	_apply(on)
	_shape_window(on)
	_tell("TOUCH MODE" if on else "DESKTOP MODE")
	var scene := get_tree().current_scene
	if scene == null:
		return
	if scene.has_method(&"touch_changed"):
		scene.touch_changed()
	elif scene.scene_file_path != MATCH_SCENE:
		get_tree().reload_current_scene()


## A phone-shaped window in touch mode, the old one back on leaving it.
## Does nothing in fullscreen, or with the game embedded in the editor.
func _shape_window(on: bool) -> void:
	var window := get_window()
	if window.mode != Window.MODE_WINDOWED or Engine.is_embedded_in_editor():
		return
	if on:
		_desktop_size = window.size
		var screen := DisplayServer.screen_get_usable_rect(window.current_screen)
		var fit := minf(1.0, minf(screen.size.x * 0.9 / PHONE.x, screen.size.y * 0.9 / PHONE.y))
		window.size = Vector2i(Vector2(PHONE) * fit)
	elif _desktop_size != Vector2i.ZERO:
		window.size = _desktop_size
	else:
		return
	window.move_to_center()


func _tell(text: String) -> void:
	if _note == null:
		var layer := CanvasLayer.new()
		layer.layer = 128
		add_child(layer)
		_note = UI.label("", 22, UI.GOLD)
		_note.add_theme_color_override("font_outline_color", UI.INK)
		_note.add_theme_constant_override("outline_size", 6)
		_note.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		_note.position.y = 12
		_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(_note)
	_note.text = text
	_note.reset_size()
	_note.position.x = (get_viewport().get_visible_rect().size.x - _note.size.x) / 2.0
	_note.modulate.a = 1.0
	if _note_tween != null:
		_note_tween.kill()
	_note_tween = create_tween()
	_note_tween.tween_interval(NOTE_TIME)
	_note_tween.tween_property(_note, "modulate:a", 0.0, 0.4)
