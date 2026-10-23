extends Control
## Touch mode: every character of the match on one board over the table, big
## enough to read on a phone. It takes the place of the shelf of small cards
## on the counter (and of the row an eliminated player looks up), which a
## phone could not show legibly with a big cast. The cards in the viewer's
## hand come first, framed in green. Tapping a card says so (`picked`); the
## table opens its menu over the board as it would over the shelf.
## Closed by the X, a tap outside the board, or Esc (the table's _back_out).

signal picked(def: CharacterDef, view: CardView)
signal closed

const Board := preload("res://scripts/ui/saloon_board.gd")
## The room the board leaves around it, and between two cards.
const MARGIN := Vector2(28, 16)
const GAP := Vector2(10, 12)
## The biggest a card is drawn, and the most cards in a row before a new one.
const MOST := 2.0
const ROW := 11

var _board: PanelContainer


## `cast`: the characters to show; `held`: the ids of the viewer's hand
## (empty for nobody's); `hint`: the line under the title.
func setup(cast: Array, held: Array, hint: String) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var mine := cast.filter(func(def: CharacterDef) -> bool: return held.has(def.id))
	var others := cast.filter(func(def: CharacterDef) -> bool: return not held.has(def.id))
	var order := mine + others

	var screen := Vector2(1152, 648)
	var rows := ceili(float(order.size()) / ROW)
	var columns := ceili(float(order.size()) / maxi(rows, 1))
	# As big as the screen lets them be: across, and down under the title.
	var room := screen - MARGIN * 2.0 - Vector2(44, 150)
	var scale_across := (room.x - GAP.x * (columns - 1)) / (CardView.BASE.x * columns)
	var scale_down := (room.y - GAP.y * (rows - 1)) / (CardView.BASE.y * rows)
	var card_scale := minf(MOST, minf(scale_across, scale_down))

	_board = PanelContainer.new()
	Board.frame(_board, UI.BORDER, 22)
	_board.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_board)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_board.add_child(column)
	column.add_child(Board.plaque("CHARACTERS IN THIS MATCH", 20))
	var line := UI.label(hint, 13, UI.MUTED)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(line)
	var grid := GridContainer.new()
	grid.columns = maxi(columns, 1)
	grid.add_theme_constant_override("h_separation", int(GAP.x))
	grid.add_theme_constant_override("v_separation", int(GAP.y))
	column.add_child(grid)
	for def: CharacterDef in order:
		var card := CardView.new(card_scale)
		card.set_card(def.id, true)
		card.set_caption(def.display_name)
		card.lift = 6.0
		card.custom_minimum_size = card.size
		if held.has(def.id):
			card.highlight(UI.GREEN)
			card.note = "You hold this card."
		card.clicked.connect(func() -> void: picked.emit(def, card))
		grid.add_child(card)

	var shut := Button.new()
	Board.plank(shut, UI.RED)
	shut.custom_minimum_size = Vector2(48, 48)
	shut.focus_mode = Control.FOCUS_NONE
	shut.pressed.connect(close)
	shut.draw.connect(_draw_cross.bind(shut))
	add_child(shut)

	_board.reset_size()
	_board.position = ((screen - _board.size) / 2.0).round()
	shut.size = shut.custom_minimum_size
	shut.position = Vector2(_board.position.x + _board.size.x - shut.size.x - 10.0, _board.position.y + 10.0)
	_board.pivot_offset = _board.size / 2.0
	UI.pop(_board, 1.04, 0.15)


func close() -> void:
	if is_queued_for_deletion():
		return
	closed.emit()
	queue_free()


## A tap off the board puts it away.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and not _board.get_global_rect().has_point(event.global_position):
		accept_event()
		close()


## The X of the button that closes it: a thin cross in blocks, as on the
## board of how to play.
func _draw_cross(button: Button) -> void:
	var cell := 3.0
	var rows := 8
	var ink := Color("ffb9a8") if button.is_hovered() else UI.CREAM
	var face := button.size.y / 2.0 + (2.0 if button.button_pressed else -2.0)
	var origin := (Vector2(button.size.x / 2.0, face) - Vector2(rows + 1, rows) * cell / 2.0).round()
	for row in rows:
		for x: int in [row, row + 1, rows - row, rows - 1 - row]:
			button.draw_rect(Rect2(origin + Vector2(x, row) * cell, Vector2(cell, cell)), ink)
