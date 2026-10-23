extends Control
## Between the menu and the table: open a room on this computer or join the
## one a friend opened. Either way the next screen is the lobby (setup.tscn).
##
## The screen is the top of a desk (noir_desk.gd): the name is the brass
## plate on it, and the two things to do are two papers lying side by side.
## Next to them lies the house's card (house_props.gd), the way into the
## ranked matches (ranked_screen.gd).

const Room := preload("res://scripts/net/room.gd")
const Jukebox := preload("res://scripts/ui/jukebox.gd")
const Transition := preload("res://scripts/ui/transition.gd")
const Desk := preload("res://scripts/ui/noir_desk.gd")
const House := preload("res://scripts/ui/house_props.gd")
const RankedApi := preload("res://scripts/net/ranked_api.gd")
const MENU_SCENE := "res://scenes/menu.tscn"
const LOBBY_SCENE := "res://scenes/setup.tscn"
const RANKED_SCENE := "res://scenes/ranked.tscn"

var _name: LineEdit
var _address: LineEdit
var _create: Button
var _join: Button
var _status: Label
var _desk: Desk
var _create_note: Label
var _house_note: Label
var _things: Array = []


func _ready() -> void:
	Settings.ensure_loaded()
	theme = UI.theme()
	Jukebox.play(Jukebox.LOBBY)

	_desk = Desk.desk()
	# On a phone (touch mode) the plates and papers are bigger, for the bigger
	# text, and what the papers explain is said shorter.
	var touch := UI.touch
	# Three things to do lie across the desk; the odds and ends are along the
	# foot of it, clear of them.
	_desk.props = [
		{"kind": &"ring", "at": Vector2(1050, 122)},
		# A hand of cards thrown down, and what was riding on it.
		# Both answer the mouse: the cards are pushed, the coins catch the light.
		{"kind": &"cards", "at": Vector2(318, 602), "live": true, "lay": [
			[-62, 2, 1.45], [-10, -8, 1.2], [44, 6, 1.64], [96, -2, 1.36]]},
		{"kind": &"coins", "at": Vector2(550, 606), "live": true},
		# Whoever signs here has not been careful with the ink.
		{"kind": &"ink", "at": Vector2(698, 616), "size": 10.0},
		{"kind": &"ink", "at": Vector2(664, 590), "size": 5.0},
		{"kind": &"ink", "at": Vector2(752, 638), "size": 4.0},
		{"kind": &"ink", "at": Vector2(1010, 628), "size": 3.0},
	]
	add_child(_desk)
	# The pen is a thing of its own: its barbs give under the mouse.
	add_child(Desk.quill(Vector2(712, 622), -0.18))
	add_child(TipLayer.new())
	var plaque: Desk = Desk.make(Desk.Kind.PLAQUE, Rect2(20, 12, 430, 58) if touch else Rect2(20, 12, 310, 46))
	add_child(plaque)
	var title := Desk.written("FIND A TABLE", 30, UI.INK, true)
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plaque.add_child(title)

	# Whose desk this is: the brass plate is the name itself. Enter puts the
	# pen down; a click picks the name up again, all of it.
	var who: Desk = Desk.make(Desk.Kind.NAMEPLATE, Rect2(376, 72, 400, 92))
	who.plate = Rect2(14, 30, 372, 50)
	add_child(who)
	var asks := UI.label("YOUR NAME", 13, UI.MUTED, true)
	asks.position = Vector2(0, 8)
	asks.size = Vector2(who.size.x, 20)
	asks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	who.add_child(asks)
	_name = _field(Settings.player_name, "Player", Room.NAME_LENGTH)
	_name.position = who.plate.position
	_name.size = who.plate.size
	_name.add_theme_font_size_override("font_size", UI.grow(36))
	_name.add_theme_font_override("font", UI.bold())
	Desk.line(_name, UI.INK, false)
	_name.add_theme_color_override("font_uneditable_color", Color(UI.INK, 0.6))
	_name.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.select_all_on_focus = true
	_name.text_submitted.connect(func(_text: String): _name.release_focus())
	_name.focus_entered.connect(func(): who.lit = true)
	_name.focus_exited.connect(func(): who.lit = false)
	who.add_child(_name)
	TipLayer.attach(_name, "Click to change your name.")

	# The two things to do here are two papers on the desk.
	var deed: Desk = Desk.make(Desk.Kind.SHEET, Rect2(14, 178, 362, 372) if touch else Rect2(38, 192, 330, 320))
	deed.rotation = -0.03
	deed.aged = true
	deed.torn = true
	deed.tone = Desk.OLD_PAPER
	deed.clip_at = 36.0
	deed.margin = 20.0
	deed.stain = Vector3(272, 60, 26)
	# What the pen left on it: all of it out by the edges, clear of the writing.
	deed.inked = [Vector3(308, 164, 3), Vector3(22, 258, 4), Vector3(312, 232, 2), Vector3(96, 302, -84), Vector3(170, 14, -46)]
	var hosting := _write_on(deed, "CREATE A ROOM")
	if touch:
		hosting.add_child(_text("The match runs on this device. Friends on the same Wi-Fi join by your address.\n\nEmpty seats can be filled with bots."))
	else:
		hosting.add_child(_text("The match runs on this computer. Your friends join by your address: the same network, or a VPN such as Radmin VPN.\n\nEmpty seats can be filled with bots."))
	_create = UI.button("CREATE ROOM", UI.BORDER, 22)
	_create.custom_minimum_size = Vector2(0, 64 if touch else 52)
	Desk.stamp(_create)
	_create.pressed.connect(_on_create)
	hosting.add_child(_create)
	_create_note = _note()
	hosting.add_child(_create_note)

	var wire: Desk = Desk.make(Desk.Kind.SHEET, Rect2(392, 184, 362, 372) if touch else Rect2(400, 198, 330, 320))
	wire.rotation = 0.025
	wire.tone = Desk.OLD_TELEGRAM
	wire.aged = true
	wire.bordered = true
	wire.inked = [Vector3(306, 44, 4), Vector3(24, 284, 3), Vector3(22, 120, 2), Vector3(188, 296, -96), Vector3(220, 18, -52)]
	var joining := _write_on(wire, "JOIN A ROOM")
	joining.add_child(_text("Type the address shown in the lobby of whoever created the room." if touch else "Ask whoever created the room for the address shown in their lobby and type it here."))
	_address = _field(Settings.last_address, "26.0.0.0", 64)
	_address.custom_minimum_size = Vector2(0, 54 if touch else 40)
	_address.add_theme_font_size_override("font_size", UI.grow(24))
	Desk.line(_address)
	_address.text_submitted.connect(func(_text: String): _on_join())
	joining.add_child(_address)
	_join = UI.button("JOIN ROOM", UI.BORDER, 22)
	_join.custom_minimum_size = Vector2(0, 64 if touch else 52)
	Desk.stamp(_join)
	_join.pressed.connect(_on_join)
	joining.add_child(_join)
	_status = _note()
	joining.add_child(_status)

	_lay_house_card(touch)

	# Why the last room ended, if that is how the player got here.
	_tell(Room.notice)
	Room.notice = ""

	var back := UI.button("BACK", UI.BORDER, 20)
	back.size = UI.grown(Vector2(150, 46))
	back.position = Vector2(24, 632 - back.size.y)
	Desk.brass(back)
	back.pressed.connect(_on_back)
	add_child(back)
	var settings := UI.button("SETTINGS", UI.BORDER, 20)
	settings.size = UI.grown(Vector2(170, 46))
	settings.position = Vector2(1128 - settings.size.x, 12)
	Desk.brass(settings)
	settings.pressed.connect(func(): add_child(SettingsPanel.new()))
	add_child(settings)
	_things = Desk.things(self, _desk)
	add_child(Desk.lamplight())
	if Transition.desk_bare():
		desk_slide(1.0)


## The house's card, the third thing on the desk: black stock and gold foil,
## sealed in wax. It says how busy the house is, if there is a house.
func _lay_house_card(touch: bool) -> void:
	var card: Control = House.of(House.Look.INVITE, Rect2(770, 172, 370, 404) if touch else Rect2(764, 182, 352, 350))
	card.rotation = -0.02
	card.lifts = true
	add_child(card)
	var box := VBoxContainer.new()
	# Clear of the sunburst at the head of the frame.
	box.position = Vector2(30, 44)
	box.size = Vector2(card.size.x - 60.0, card.size.y - 104.0)
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	var heading := UI.label("RANKED", 32, House.FOIL_LIGHT, true)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)
	var under := UI.label("THE HOUSE TABLE", 13, House.FOIL)
	under.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(under)
	# The card's rule of foil goes in this gap, wherever the heading ends.
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 22)
	box.add_child(gap)
	box.sort_children.connect(func(): card.parting = box.position.y + gap.position.y + gap.size.y / 2.0)
	var text := UI.label("Strangers at the house's own tables. Every match goes in the ledger: your rating, your wins, your lies." if not touch
			else "Strangers at the house's tables. Every match goes in the ledger.", 16, UI.CREAM)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(text)
	_house_note = UI.label("", 13, House.FOIL)
	_house_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_house_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_house_note)
	var enter := UI.button("ENTER THE HOUSE", UI.BORDER, 22)
	enter.custom_minimum_size = Vector2(0, 64 if touch else 52)
	Desk.stamp(enter, House.FOIL)
	enter.add_theme_color_override("font_hover_color", House.FOIL_LIGHT)
	enter.pressed.connect(_on_ranked)
	box.add_child(enter)
	_ask_the_house()


## How many are at the house's tables, said under its card.
func _ask_the_house() -> void:
	if not RankedApi.configured():
		_house_note.text = Loc.t("The house has not opened its doors yet.")
		return
	_house_note.text = Loc.t("Knocking on the house's door...")
	var answer: Dictionary = await RankedApi.get_json("/v1/status", false)
	if not is_instance_valid(_house_note):
		return
	if not answer.ok or not answer.data is Dictionary:
		_house_note.text = Loc.t("The house does not answer right now.")
		return
	var data: Dictionary = answer.data
	_house_note.text = Loc.t("%d at the tables, %d waiting for one") % [int(data.get("playing", 0)), int(data.get("queue", 0))]


func _on_ranked() -> void:
	_remember()
	Transition.go(RANKED_SCENE, Transition.DESK)


## Puts `sheet` on the desk with its heading written on it, and gives back
## the column the rest is written in.
func _write_on(sheet: Desk, heading: String) -> VBoxContainer:
	sheet.lifts = true
	add_child(sheet)
	var box := VBoxContainer.new()
	box.position = Vector2(30, 28)
	box.size = sheet.size - Vector2(60, 56)
	box.add_theme_constant_override("separation", 8)
	sheet.add_child(box)
	box.add_child(Desk.written(heading, 26, Desk.INK, true))
	# Ruled off twice, like the head of a form.
	for weight: int in [2, 1]:
		var rule := ColorRect.new()
		rule.color = Desk.INK if weight == 2 else Desk.INK_FADED
		rule.custom_minimum_size = Vector2(0, weight)
		rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(rule)
	return box


func _text(text: String) -> Label:
	var l := Desk.written(text, 16)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return l


func _field(text: String, hint: String, length: int) -> LineEdit:
	var edit := LineEdit.new()
	edit.text = text
	edit.placeholder_text = hint
	edit.max_length = length
	edit.add_theme_font_size_override("font_size", UI.grow(20))
	return edit


## A line under the button of a paper, for what went wrong: not there until
## there is something to say.
func _note() -> Label:
	var l := Desk.written("", 13, Desk.INK_RED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.hide()
	return l


## Says `text` under the button to join, or under the one to create.
func _tell(text: String, color: Color = Desk.INK_RED, creating := false) -> void:
	var said := _create_note if creating else _status
	var other := _status if creating else _create_note
	Desk.ink(said, color)
	said.text = text
	said.visible = text != ""
	other.hide()


func _remember() -> void:
	var player_name: String = Room.clean_name(_name.text)
	Settings.player_name = player_name if player_name != "" else "Player"
	Settings.last_address = _address.text.strip_edges()
	Settings.save()


func _on_create() -> void:
	_remember()
	var problem: String = Room.host(Settings.player_name)
	if problem != "":
		_tell(problem, Desk.INK_RED, true)
		return
	Transition.go(LOBBY_SCENE, Transition.DESK)


## The lobby opens by itself once the host lets this machine in; if it never
## does, the room comes back here with the reason (Room.notice).
func _on_join() -> void:
	if _join.disabled:
		return
	_remember()
	var problem: String = Room.join(_address.text, Settings.player_name)
	if problem != "":
		_tell(problem)
		return
	_tell("Knocking on the door...", Desk.INK_FADED)
	# A match is on in there: the host is asked to let this machine watch it.
	Room.current.watch_pending.connect(func() -> void:
		_tell("A match is being played in that room. Waiting for the host to let you watch it...", Desk.INK_FADED))
	_create.disabled = true
	_join.disabled = true
	_name.editable = false
	_address.editable = false


## The way in and out of the lobby (Transition.DESK): everything on the desk
## is dragged off it to the sides as `amount` goes to 1.
func desk_slide(amount: float) -> void:
	Desk.slide(_desk, _things, amount)


func _on_back() -> void:
	if Room.current != null:
		Room.current.leave()
	Transition.go(MENU_SCENE, Transition.DOORS)


func _unhandled_key_input(event: InputEvent) -> void:
	UI.handle_fullscreen_key(event, get_window())
