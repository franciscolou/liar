extends ColorRect
## The "how to play" overlay: the rules in a handful of short pages. Shared by
## the title screen and the pause menu; add it as a child and it covers the
## screen until closed. It has no class name: preload it where it is needed.

signal closed

## [tab title, page]. The pages are BBCode and translation keys as a whole.
const PAGES := [
	["BASICS", "[b]Everyone lies in Carcaj.[/b]\n\nYou hold character cards, face down. On your turn you may [color=#e6bc4c]claim[/color] the ability of [b]any[/b] character in the match: the cards in your hand only decide whether you are telling the truth.\n\nWhoever hears a claim may answer it with [color=#c8402f]LIAR![/color]\n\nThe last player with Morale left takes the crown."],
	["YOUR TURN", "You collect your income and then, in any order:\n\n[color=#e6bc4c]•[/color] [b]Buy[/b] items in the shop and [b]use[/b] the ones you hold. Neither ends your turn.\n[color=#e6bc4c]•[/color] [b]Claim one ability.[/b] Click a card of your hand to play it honestly, or one of the other characters to bluff. [color=#78a846]Green[/color] is the truth, [color=#c8402f]red[/color] is a bluff. This ends your turn.\n\nOr press END TURN and keep your coins.\n\n[b]Reactions[/b] are abilities claimed outside your turn, when what triggers them happens: the game asks you whenever you may use one. They are claims like any other."],
	["LIAR!", "When someone claims an ability, anyone else may call [color=#c8402f]LIAR![/color] Only the first call counts.\n\n[color=#c8402f]•[/color] [b]It was a lie:[/b] the liar loses 1 Morale and the ability fails.\n[color=#78a846]•[/color] [b]It was the truth:[/b] the doubter pays a fine in coins, the ability goes through, and the proven card is traded for a new one from the deck.\n\nNo coins for the fine? You put 1 Morale on the line instead.\n\nThe question tells you how many copies of that character you hold yourself: the more of them you have, the likelier it is a lie."],
	["MORALE", "Morale is your life: at 0 you are out of the match.\n\nYour hand is never larger than your Morale. When you drop to 1 Morale you give up a card, shown to the whole table. Recover Morale and you draw one back.\n\n[b]Statuses[/b] are the coloured tags next to a player: effects that last for a while. Hover one to read what it does and who put it there."],
	["SHOP", "One shop for the whole table, in the corner next to the deck: hover it to open, click it to keep it open.\n\n[color=#e6bc4c]•[/color] [b]Active[/b] items are used on your turn, from your inventory.\n[color=#e6bc4c]•[/color] [b]Passive[/b] items work by themselves while you hold them.\n[color=#e6bc4c]•[/color] [b]Reaction[/b] items are offered the moment they can be used.\n\nA reroll replaces every slot; what is marked ALWAYS never leaves the shelf.\n\n[b]Handy to know:[/b] hover anything for details. Esc or a right click cancels a target. F11 toggles fullscreen."],
]

var _tabs: Array = []  # Button, one per page
var _text: RichTextLabel
var _page := 0


func _init() -> void:
	color = Color(0, 0, 0, 0.78)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 30
	theme = UI.theme()

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.box(Color(UI.INK, 0.98), UI.GOLD, 3, 8, 22))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var heading := UI.label("HOW TO PLAY", 28, UI.GOLD, true)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)

	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 6)
	box.add_child(tabs)
	for i: int in PAGES.size():
		var b := UI.button(PAGES[i][0], UI.BORDER, 15)
		b.custom_minimum_size = Vector2(118, 32)
		b.pressed.connect(_show_page.bind(i))
		tabs.add_child(b)
		_tabs.append(b)

	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.custom_minimum_size = Vector2(640, 292)
	_text.add_theme_font_size_override("normal_font_size", 19)
	_text.add_theme_font_size_override("bold_font_size", 19)
	_text.add_theme_constant_override("line_separation", 2)
	_text.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(_text)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var previous := UI.button("<", UI.BORDER, 18)
	previous.custom_minimum_size = Vector2(46, 42)
	previous.pressed.connect(_step.bind(-1))
	row.add_child(previous)
	var back := UI.button("Back", UI.GOLD, 18)
	back.custom_minimum_size = Vector2(200, 42)
	back.pressed.connect(close)
	row.add_child(back)
	var next := UI.button(">", UI.BORDER, 18)
	next.custom_minimum_size = Vector2(46, 42)
	next.pressed.connect(_step.bind(1))
	row.add_child(next)
	_show_page(0)


func close() -> void:
	closed.emit()
	queue_free()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _text != null:
		_show_page(_page)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		_step(-1)
	elif event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		_step(1)


func _step(by: int) -> void:
	_show_page(posmod(_page + by, PAGES.size()))


func _show_page(index: int) -> void:
	_page = index
	_text.text = Loc.t(PAGES[index][1])
	for i: int in _tabs.size():
		var b: Button = _tabs[i]
		var on := i == index
		var accent := UI.GOLD if on else UI.BORDER.darkened(0.3)
		b.add_theme_stylebox_override("normal", UI.box(accent.darkened(0.6) if on else UI.PANEL, accent, 2, 4, 6))
		b.add_theme_color_override("font_color", UI.GOLD if on else UI.MUTED)
