extends Control
## Shown when the match ends: who took the crown, then play again, go back
## to the lobby or leave. After a win the backdrop is the winner's hand in a
## broken mirror, with the three plates in a row under it; with nobody left
## standing it is the painted artwork, plates and all.

# The look of the plates painted on the artwork.
const PLATE := Color("1d0a08")
const PLATE_BORDER := Color("4a1c16")
const PLATE_INK := Color("d9935c")
# The row of plates under the mirror.
const ROW := Vector2(247, 578)
const ROW_PLATE := Vector2(210, 48)
const ROW_GAP := 14.0

const Room := preload("res://scripts/net/room.gd")
const Jukebox := preload("res://scripts/ui/jukebox.gd")
const Transition := preload("res://scripts/ui/transition.gd")
const Mirror := preload("res://scripts/ui/shattered_mirror.gd")
const ROOM_SCENE := "res://scenes/room.tscn"
const LOBBY_SCENE := "res://scenes/setup.tscn"
const MENU_SCENE := "res://scenes/menu.tscn"

@onready var again_button: Button = $Again
@onready var back_button: Button = $Back
## The third plate, above the two painted ones. It is not on the artwork, so
## it is always drawn.
var lobby_button: Button
## The backdrop after a win, or null.
var _mirror: Control
var _plates: Array = []  # what waits for the mirror to show the hand


func _ready() -> void:
	Settings.ensure_loaded()
	theme = UI.theme()
	Jukebox.play(Jukebox.ENDING, 1.5)
	var winner := GameConfig.last_winner
	var hand := GameConfig.last_winner_cards
	GameConfig.last_winner_cards = []
	if not hand.is_empty():
		Content.ensure_loaded()
		_mirror = Mirror.new(winner, hand)
		add_child(_mirror)
		move_child(_mirror, 0)
		$TextureRect.hide()
		$Label.hide()
	$Label.text = Loc.t("%s now holds\nCarcaj's crown.") % winner if winner != "" else Loc.t("Nobody is left\nto take the crown.")
	$Label.add_theme_color_override("font_color", UI.GOLD)
	$Label.add_theme_font_override("font", UI.bold())
	$Label.add_theme_font_size_override("font_size", 40)
	lobby_button = Button.new()
	lobby_button.position = Vector2(686, 381)
	lobby_button.size = Vector2(329, 61)
	add_child(lobby_button)
	_relabel()
	_plates = [again_button, lobby_button, back_button]
	for b: Button in [again_button, lobby_button, back_button]:
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		UI.juice(b, 1.04)
	again_button.pressed.connect(_on_again)
	lobby_button.pressed.connect(_on_lobby)
	back_button.pressed.connect(_on_quit)
	# Only the host deals; the others wait for it, here or in the lobby.
	var room: Node = Room.current
	if room != null and not room.hosting:
		again_button.disabled = true
		again_button.mouse_default_cursor_shape = Control.CURSOR_ARROW
		var waiting := UI.label("Only the host can deal again.", 15, PLATE_INK)
		waiting.position = Vector2(686, 356) if _mirror == null else Vector2(ROW.x, ROW.y - 26)
		waiting.size = Vector2(329, 22) if _mirror == null else Vector2(ROW_PLATE.x, 22)
		waiting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(waiting)
		_plates.append(waiting)
	if _mirror != null:
		_line_up()


## Under the mirror the plates stand in a row, and wait for the pictures.
func _line_up() -> void:
	for i in _plates.size():
		var plate: Control = _plates[i]
		if plate is Button:
			plate.position = ROW + Vector2((ROW_PLATE.x + ROW_GAP) * i, 0)
			plate.size = ROW_PLATE
		plate.modulate.a = 0.0
		plate.hide()
	_mirror.revealed.connect(func() -> void:
		for plate: Control in _plates:
			plate.show()
			plate.create_tween().tween_property(plate, "modulate:a", 1.0, 0.8).set_delay(0.3))


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_relabel()


func _relabel() -> void:
	UI.art_button(again_button, "PLAY AGAIN", PLATE, PLATE_BORDER, PLATE_INK, 30)
	UI.art_button(back_button, "QUIT", PLATE, PLATE_BORDER, PLATE_INK, 30)
	UI.art_button(lobby_button, "BACK TO LOBBY", PLATE, PLATE_BORDER, PLATE_INK, 30)
	# Nothing is painted under this one.
	lobby_button.text = "BACK TO LOBBY"
	lobby_button.add_theme_stylebox_override("normal", UI.box(PLATE, PLATE_BORDER, 4, 4, 0))
	lobby_button.add_theme_stylebox_override("hover", UI.box(PLATE.lightened(0.08), UI.GOLD, 4, 4, 0))
	lobby_button.add_theme_stylebox_override("pressed", UI.box(PLATE.darkened(0.25), UI.GOLD, 4, 4, 0))
	if _mirror != null:
		# Nothing is painted under any of them.
		for b: Button in [again_button, back_button]:
			b.text = "PLAY AGAIN" if b == again_button else "QUIT"
			b.add_theme_stylebox_override("normal", UI.box(PLATE, PLATE_BORDER, 4, 4, 0))
			b.add_theme_stylebox_override("hover", UI.box(PLATE.lightened(0.08), UI.GOLD, 4, 4, 0))
			b.add_theme_stylebox_override("pressed", UI.box(PLATE.darkened(0.25), UI.GOLD, 4, 4, 0))
		for b: Button in [again_button, lobby_button, back_button]:
			b.add_theme_font_size_override("font_size", roundi(22 * UI.FONT_SCALE))
	again_button.add_theme_stylebox_override("disabled", UI.box(Color(0, 0, 0, 0.55), Color(0, 0, 0, 0), 0, 4, 0))


## A new match with the rules of the last one.
func _on_again() -> void:
	if Room.current != null:
		Room.current.start()
	else:
		Transition.go("res://scenes/main.tscn", Transition.DEAL)


## Back to the lobby, where the rules are as they were left. The host takes
## the whole room along; anyone else just goes there to wait.
func _on_lobby() -> void:
	var room: Node = Room.current
	if room == null:
		Transition.go(ROOM_SCENE, Transition.GATHER)
	elif room.hosting:
		room.to_lobby()
	else:
		Transition.go(LOBBY_SCENE, Transition.GATHER)


func _on_quit() -> void:
	if Room.current != null:
		Room.current.leave()
	Transition.go(MENU_SCENE, Transition.DOORS)


func _unhandled_key_input(event: InputEvent) -> void:
	UI.handle_fullscreen_key(event, get_window())
