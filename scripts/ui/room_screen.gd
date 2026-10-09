extends Control
## Between the menu and the table: open a room on this computer or join the
## one a friend opened. Either way the next screen is the lobby (setup.tscn).

const Room := preload("res://scripts/net/room.gd")
const Jukebox := preload("res://scripts/ui/jukebox.gd")
const Transition := preload("res://scripts/ui/transition.gd")
const MENU_SCENE := "res://scenes/menu.tscn"
const LOBBY_SCENE := "res://scenes/setup.tscn"

var _name: LineEdit
var _address: LineEdit
var _create: Button
var _join: Button
var _status: Label


func _ready() -> void:
	Settings.ensure_loaded()
	theme = UI.theme()
	Jukebox.play(Jukebox.LOBBY)

	var bg := TextureRect.new()
	bg.texture = UI.tex("res://assets/table.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.modulate = Color(0.5, 0.44, 0.42)
	add_child(bg)
	add_child(TipLayer.new())

	var title := UI.label("FIND A TABLE", 36, UI.GOLD, true)
	title.position = Vector2(26, 10)
	add_child(title)

	# The whole plate is the name: no box inside the box. Enter puts the pen
	# down; a click picks the name up again, all of it.
	var who := _panel(Rect2(226, 84, 700, 92))
	who.add_theme_constant_override("separation", 0)
	var asks := UI.label("YOUR NAME", 13, UI.MUTED, true)
	asks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	who.add_child(asks)
	_name = _field(Settings.player_name, "Player", Room.NAME_LENGTH)
	_name.add_theme_font_size_override("font_size", 40)
	_name.add_theme_font_override("font", UI.bold())
	_name.add_theme_color_override("font_color", UI.GOLD)
	_name.add_theme_color_override("font_uneditable_color", UI.GOLD.darkened(0.3))
	for state: String in ["normal", "focus", "read_only"]:
		_name.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_name.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.select_all_on_focus = true
	_name.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_name.text_submitted.connect(func(_text: String): _name.release_focus())
	who.add_child(_name)
	TipLayer.attach(_name, "Click to change your name.")

	var hosting := _panel(Rect2(226, 190, 340, 290))
	hosting.add_child(UI.label("CREATE A ROOM", 24, UI.GOLD, true))
	hosting.add_child(_text("The match runs on this computer. Your friends join by your address: the same network, or a VPN such as Radmin VPN.\n\nEmpty seats can be filled with bots."))
	_create = UI.button("CREATE ROOM", UI.GOLD, 22)
	_create.custom_minimum_size = Vector2(0, 52)
	_create.pressed.connect(_on_create)
	hosting.add_child(_create)

	var joining := _panel(Rect2(586, 190, 340, 290))
	joining.add_child(UI.label("JOIN A ROOM", 24, UI.GOLD, true))
	joining.add_child(_text("Ask whoever created the room for the address shown in their lobby and type it here."))
	_address = _field(Settings.last_address, "26.0.0.0", 64)
	_address.custom_minimum_size = Vector2(0, 40)
	_address.text_submitted.connect(func(_text: String): _on_join())
	joining.add_child(_address)
	_join = UI.button("JOIN ROOM", UI.GOLD, 22)
	_join.custom_minimum_size = Vector2(0, 52)
	_join.pressed.connect(_on_join)
	joining.add_child(_join)

	_status = UI.label("", 16, UI.RED)
	_status.position = Vector2(226, 494)
	_status.size = Vector2(700, 48)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	# Why the last room ended, if that is how the player got here.
	_status.text = Room.notice
	Room.notice = ""

	var back := UI.button("BACK", UI.BORDER, 20)
	back.position = Vector2(24, 584)
	back.size = Vector2(150, 48)
	back.pressed.connect(_on_back)
	add_child(back)


func _panel(rect: Rect2) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel", UI.box(Color(UI.INK, 0.93), UI.BORDER, 2, 6, 16))
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	return box


func _text(text: String) -> Label:
	var l := UI.label(text, 15, UI.CREAM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return l


func _field(text: String, hint: String, length: int) -> LineEdit:
	var edit := LineEdit.new()
	edit.text = text
	edit.placeholder_text = hint
	edit.max_length = length
	edit.add_theme_font_size_override("font_size", 20)
	return edit


func _remember() -> void:
	var player_name: String = Room.clean_name(_name.text)
	Settings.player_name = player_name if player_name != "" else "Player"
	Settings.last_address = _address.text.strip_edges()
	Settings.save()


func _on_create() -> void:
	_remember()
	var problem: String = Room.host(Settings.player_name)
	if problem != "":
		_status.text = problem
		return
	Transition.go(LOBBY_SCENE, Transition.KEYHOLE)


## The lobby opens by itself once the host lets this machine in; if it never
## does, the room comes back here with the reason (Room.notice).
func _on_join() -> void:
	if _join.disabled:
		return
	_remember()
	var problem: String = Room.join(_address.text, Settings.player_name)
	if problem != "":
		_status.text = problem
		return
	_status.add_theme_color_override("font_color", UI.MUTED)
	_status.text = "Knocking on the door..."
	_create.disabled = true
	_join.disabled = true
	_name.editable = false
	_address.editable = false


func _on_back() -> void:
	if Room.current != null:
		Room.current.leave()
	Transition.go(MENU_SCENE, Transition.DOORS)


func _unhandled_key_input(event: InputEvent) -> void:
	UI.handle_fullscreen_key(event, get_window())
