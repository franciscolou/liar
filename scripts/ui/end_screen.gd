extends Control
## Shown when the match ends: who took the crown, then play again, go back
## to the lobby or leave.

# The look of the plates painted on the artwork.
const PLATE := Color("1d0a08")
const PLATE_BORDER := Color("4a1c16")
const PLATE_INK := Color("d9935c")

const Room := preload("res://scripts/net/room.gd")
const ROOM_SCENE := "res://scenes/room.tscn"
const LOBBY_SCENE := "res://scenes/setup.tscn"
const MENU_SCENE := "res://scenes/menu.tscn"

@onready var again_button: Button = $Again
@onready var back_button: Button = $Back
## The third plate, above the two painted ones. It is not on the artwork, so
## it is always drawn.
var lobby_button: Button


func _ready() -> void:
	Settings.ensure_loaded()
	theme = UI.theme()
	add_child(TipLayer.new())
	var winner := GameConfig.last_winner
	$Label.text = Loc.t("%s now holds\nCarcaj's crown.") % winner if winner != "" else Loc.t("Nobody is left\nto take the crown.")
	$Label.add_theme_color_override("font_color", UI.GOLD)
	$Label.add_theme_font_override("font", UI.bold())
	$Label.add_theme_font_size_override("font_size", 40)
	lobby_button = Button.new()
	lobby_button.position = Vector2(686, 381)
	lobby_button.size = Vector2(329, 61)
	add_child(lobby_button)
	_relabel()
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
		waiting.position = Vector2(686, 356)
		waiting.size = Vector2(329, 22)
		waiting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(waiting)
	elif room != null:
		TipLayer.attach(again_button, "Deals a new match to the whole room, with the same rules.")
		TipLayer.attach(lobby_button, "Takes the whole room back to the lobby, where the rules can be changed.")
		TipLayer.attach(back_button, "Closes the room for everyone.")


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
	again_button.add_theme_stylebox_override("disabled", UI.box(Color(0, 0, 0, 0.55), Color(0, 0, 0, 0), 0, 4, 0))


## A new match with the rules of the last one.
func _on_again() -> void:
	if Room.current != null:
		Room.current.start()
	else:
		get_tree().change_scene_to_file("res://scenes/main.tscn")


## Back to the lobby, where the rules are as they were left. The host takes
## the whole room along; anyone else just goes there to wait.
func _on_lobby() -> void:
	var room: Node = Room.current
	if room == null:
		get_tree().change_scene_to_file(ROOM_SCENE)
	elif room.hosting:
		room.to_lobby()
	else:
		get_tree().change_scene_to_file(LOBBY_SCENE)


func _on_quit() -> void:
	if Room.current != null:
		Room.current.leave()
	get_tree().change_scene_to_file(MENU_SCENE)


func _unhandled_key_input(event: InputEvent) -> void:
	UI.handle_fullscreen_key(event, get_window())
