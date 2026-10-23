extends Control
## The figures of the house, reached from the newspaper folded on the ranked
## screen. The same desk, and on it the newspaper opened out (the house's
## figures, /v1/analytics) and the member's own file in a manila folder
## (/v1/me/dossier). Both are drawn by house_props.gd; the words and the
## charts in ink are put on them here.

const Desk := preload("res://scripts/ui/noir_desk.gd")
const House := preload("res://scripts/ui/house_props.gd")
const RankedApi := preload("res://scripts/net/ranked_api.gd")
const Icons := preload("res://scripts/ui/character_icons.gd")
const Jukebox := preload("res://scripts/ui/jukebox.gd")
const Transition := preload("res://scripts/ui/transition.gd")
const RANKED_SCENE := "res://scenes/ranked.tscn"
## Where things are on the newspaper, in its own coordinates.
const PAPER := Rect2(18, 12, 748, 624)
const LEAD := Rect2(18, 108, 460, 368)
const SIDE := Rect2(500, 108, 230, 368)
const SHOP := Rect2(18, 492, 712, 120)
const FOLDER := Rect2(782, 62, 352, 522)
const INK := House.NEWS_INK
## The characters in the lead table, and the items in the shop strip.
const ROWS := 10
const TOUCH_ROWS := 6

var _desk: Desk
var _things: Array = []
var _paper: Control
var _folder: Control
var _sheet: Control
var _touch := false


func _ready() -> void:
	Settings.ensure_loaded()
	theme = UI.theme()
	Jukebox.play(Jukebox.LOBBY)
	Content.ensure_loaded()
	_touch = UI.touch
	_desk = Desk.desk()
	_desk.props = [{"kind": &"ring", "at": Vector2(1100, 610)}]
	add_child(_desk)
	add_child(TipLayer.new())
	_lay_paper()
	_lay_folder()
	var back := UI.button("BACK", UI.BORDER, 20)
	back.size = UI.grown(Vector2(150, 46))
	back.position = Vector2(1128 - back.size.x, 632 - back.size.y)
	Desk.brass(back)
	back.pressed.connect(func() -> void: Transition.go(RANKED_SCENE, Transition.DESK))
	add_child(back)
	var settings := UI.button("SETTINGS", UI.BORDER, 20)
	settings.size = UI.grown(Vector2(170, 46))
	settings.position = Vector2(1128 - settings.size.x, 8)
	Desk.brass(settings)
	settings.pressed.connect(func(): add_child(SettingsPanel.new()))
	add_child(settings)
	_things = Desk.things(self, _desk)
	add_child(Desk.lamplight())
	if Transition.desk_bare():
		desk_slide(1.0)
	_read()


func desk_slide(amount: float) -> void:
	Desk.slide(_desk, _things, amount)


func _ink(text: String, size: int, bold := false, color: Color = INK) -> Label:
	return Desk.written(text, size, color, bold)


func _put(parent: Control, node: Control, at: Vector2, extent := Vector2.ZERO) -> Control:
	node.position = at
	if extent != Vector2.ZERO:
		node.size = extent
	parent.add_child(node)
	return node


# --- the newspaper -------------------------------------------------------------

func _lay_paper() -> void:
	_paper = House.of(House.Look.NEWSPAPER, PAPER)
	_paper.rotation = -0.008
	_paper.mast = 72.0
	_paper.rules.assign([
		Vector4(16, 100, PAPER.size.x - 16, 100),
		Vector4(SIDE.position.x - 10, LEAD.position.y, SIDE.position.x - 10, LEAD.end.y),
		Vector4(16, SHOP.position.y - 8, PAPER.size.x - 16, SHOP.position.y - 8),
	])
	add_child(_paper)
	# On a phone the type grows: the masthead would run into its ears.
	var mast := _ink("THE HOUSE GAZETTE", 36 if _touch else 50, true)
	_put(_paper, mast, Vector2(0, 8), Vector2(PAPER.size.x, 60))
	mast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# The two ears of the front page.
	for side in 2:
		var ear := _ink("ALL THE LIES\nFIT TO PRINT" if side == 0 else "PRICE\nONE COIN", 10, true)
		ear.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_put(_paper, ear, Vector2(18 if side == 0 else PAPER.size.x - 108, 20), Vector2(90, 36))
		var box := ColorRect.new()
		box.color = Color(INK, 0.0)
		_paper.add_child(box)
	var dateline := _ink("", 12)
	dateline.name = "Dateline"
	_put(_paper, dateline, Vector2(20, 80), Vector2(PAPER.size.x - 40, 18))
	var waiting := _ink("The presses are running...", 18, false, Desk.INK_FADED)
	waiting.name = "Waiting"
	waiting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_put(_paper, waiting, Vector2(0, 260), Vector2(PAPER.size.x, 30))


func _write_paper(data: Dictionary) -> void:
	var waiting := _paper.get_node_or_null("Waiting")
	if waiting != null:
		waiting.queue_free()
	var matches := int(data.get("matches", 0))
	var date := Time.get_date_dict_from_system()
	var dateline: Label = _paper.get_node("Dateline")
	dateline.text = Loc.t("VOL. I  ·  %d MATCHES ON THE BOOKS  ·  %d MEMBERS") % [matches, int(data.get("members", 0))] + "        %02d/%02d/%d" % [date.day, date.month, date.year]
	dateline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if matches == 0:
		var none := _ink("No match has been played at the house yet: there is nothing to print. Come back once the first tables are over.", 18, false, Desk.INK_FADED)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_put(_paper, none, Vector2(80, 220), Vector2(PAPER.size.x - 160, 120))
		_paper.print_at.assign([Rect2(30, 380, 200, 90), Rect2(270, 380, 200, 90), Rect2(510, 380, 200, 90)])
		_paper.queue_redraw()
		return
	_write_lead(data)
	_write_side(data)
	_write_shop(data)


## The lead story: the characters of the house, how much they are lied about.
func _write_lead(data: Dictionary) -> void:
	var lead := Control.new()
	_put(_paper, lead, LEAD.position, LEAD.size)
	_put(lead, _ink("WHO LIES BEST?", 30, true), Vector2(0, 0), Vector2(LEAD.size.x, 36))
	var deck := _ink("Every character of the house: how often a claim of it is a bluff, how often the bluff is caught, and how often whoever was dealt it went on to win.", 13)
	deck.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_put(lead, deck, Vector2(0, 36), Vector2(LEAD.size.x, 40))
	# No room for it under a finger: the tooltips of the names say as much.
	deck.visible = not _touch
	var top := 86.0
	var x_bars := [168.0, 266.0, 364.0]
	for c in 3:
		var head := _ink(["BLUFFED", "CAUGHT", "WON"][c], 11, true)
		_put(lead, head, Vector2(x_bars[c], top), Vector2(90, 16))
	var characters: Array = data.get("characters", []).filter(func(c: Dictionary) -> bool: return int(c.get("claims", 0)) > 0)
	var rows := mini(characters.size(), TOUCH_ROWS if _touch else ROWS)
	# Each column is drawn against its own largest figure, as a paper would:
	# the figure itself is printed by the bar.
	var keys := ["bluff_rate", "caught_rate", "win_rate"]
	var most := [0.01, 0.01, 0.01]
	for r in rows:
		for c in 3:
			var v: Variant = characters[r].get(keys[c])
			if v != null:
				most[c] = maxf(most[c], float(v))
	var step := (LEAD.size.y - top - 22.0) / maxf(rows, 1)
	step = minf(step, 28.0 if not _touch else 40.0)
	for r in rows:
		var entry: Dictionary = characters[r]
		var y := top + 20.0 + r * step
		var id := StringName(str(entry.get("id", "")))
		var icon := Icons.icon(id, 1.0 if not _touch else 1.3)
		_put(lead, icon, Vector2(0, y + (step - 20.0) / 2.0 - 2.0))
		var def := Content.character(id)
		var label := _ink(def.display_name if def != null else str(id).capitalize(), 15, true)
		label.clip_text = true
		_put(lead, label, Vector2(28, y), Vector2(136, step))
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var values := [entry.get("bluff_rate"), entry.get("caught_rate"), entry.get("win_rate")]
		for c in 3:
			var bar := House.Bar.new()
			bar.value = float(values[c]) / most[c] if values[c] != null else null
			bar.ink = Desk.INK_RED if c == 1 else INK
			bar.thick = 8.0
			_put(lead, bar, Vector2(x_bars[c], y), Vector2(56, step))
			var figure := _ink(_percent(values[c]), 13)
			_put(lead, figure, Vector2(x_bars[c] + 60.0, y), Vector2(36, step))
			figure.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		TipLayer.attach(label, Loc.t("%s: claimed %d times, %d of them bluffs; %d bluffs caught. Dealt to %d players, %d of whom won.") % [
				label.text, int(entry.get("claims", 0)), int(entry.get("bluffs", 0)), int(entry.get("caught", 0)),
				int(entry.get("holders", 0)), int(entry.get("holder_wins", 0))])
		label.mouse_filter = Control.MOUSE_FILTER_PASS
	# Whatever room is left goes to print.
	var used := top + 20.0 + rows * step
	if LEAD.size.y - used > 30.0:
		_paper.print_at.append(Rect2(LEAD.position + Vector2(0, used + 8.0), Vector2(LEAD.size.x, LEAD.size.y - used - 10.0)))
		_paper.queue_redraw()


## The house in four figures, set large, and what claims are made the most.
func _write_side(data: Dictionary) -> void:
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 2)
	_put(_paper, side, SIDE.position, SIDE.size)
	side.add_child(_ink("THE HOUSE IN FIGURES", 17, true))
	var figures := [
		[_percent(data.get("bluff_rate")), "of all claims are bluffs"],
		[_percent(data.get("caught_rate")), "of the bluffs are caught"],
		[_percent(data.get("doubt_accuracy")), "of the LIAR! calls are right"],
		[str(roundi(float(data.get("avg_turns", 0)))), Loc.t("turns in a match, %d minutes") % roundi(float(data.get("avg_minutes", 0)))],
	]
	for f: Array in figures:
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 4)
		side.add_child(gap)
		side.add_child(_ink(f[0], 40 if not _touch else 32, false, Desk.INK_RED if f == figures[1] else INK))
		var caption := _ink(f[1], 13)
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		side.add_child(caption)
	if _touch:
		return
	var rule := ColorRect.new()
	rule.color = Color(INK, 0.7)
	rule.custom_minimum_size = Vector2(0, 1)
	side.add_child(Control.new())
	side.add_child(rule)
	side.add_child(_ink("MOST CLAIMED", 13, true))
	var abilities: Array = data.get("abilities", [])
	for a in mini(abilities.size(), 3):
		var entry: Dictionary = abilities[a]
		var ability: Ability = Content.abilities.get(StringName(str(entry.get("id", ""))))
		var title: String = ability.display_name if ability != null else str(entry.get("id", ""))
		var line := _ink(Loc.t("%s, %s bluffed") % [title, _percent(entry.get("bluff_rate"))], 12)
		line.clip_text = true
		side.add_child(line)


## The shop: what is bought the most, and how its buyers fared.
func _write_shop(data: Dictionary) -> void:
	var shop := Control.new()
	_put(_paper, shop, SHOP.position, SHOP.size)
	_put(shop, _ink("AT THE SHOP", 17, true), Vector2(0, 0), Vector2(160, 22))
	var note := _ink("bought, and how many of the buyers won", 12, false, Desk.INK_FADED)
	_put(shop, note, Vector2(150, 2), Vector2(400, 20))
	var items: Array = data.get("items", [])
	var count := mini(items.size(), 6 if _touch else 9)
	var step := SHOP.size.x / maxf(count, 1)
	var best := 0.01
	for i in count:
		if items[i].get("win_rate") != null:
			best = maxf(best, float(items[i].win_rate))
	for i in count:
		var entry: Dictionary = items[i]
		var def: ItemDef = Content.items.get(StringName(str(entry.get("id", ""))))
		var x := i * step
		if def != null:
			var art := TextureRect.new()
			art.texture = UI.tex(def.texture_path)
			art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			# Printed: the newspaper has no colour to spare.
			art.modulate = Color(0.82, 0.78, 0.7)
			_put(shop, art, Vector2(x + (step - 40.0) / 2.0, 26), Vector2(40, 42))
			TipLayer.attach(art, def.display_name)
		var bought := _ink(str(int(entry.get("bought", 0))), 16)
		bought.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_put(shop, bought, Vector2(x, 68), Vector2(step, 18))
		var bar := House.Bar.new()
		bar.value = float(entry.win_rate) / best if entry.get("win_rate") != null else null
		bar.thick = 6.0
		_put(shop, bar, Vector2(x + 8.0, 88), Vector2(step - 16.0, 10))
		var won := _ink(_percent(entry.get("win_rate")), 11)
		won.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_put(shop, won, Vector2(x, 98), Vector2(step, 16))


static func _percent(value: Variant) -> String:
	if value == null:
		return "—"
	return "%d%%" % roundi(float(value) * 100.0)


# --- the file ------------------------------------------------------------------

func _lay_folder() -> void:
	_folder = House.of(House.Look.FOLDER, FOLDER)
	_folder.rotation = 0.012
	_folder.tab = 170.0
	add_child(_folder)
	var name_tab := _ink(Settings.ranked_name if RankedApi.signed_in() else Loc.t("NO NAME"), 14, true)
	name_tab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_tab.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_put(_folder, name_tab, Vector2(18, 4), Vector2(162, 20))
	_sheet = Control.new()
	_put(_folder, _sheet, Vector2(30, 48), FOLDER.size - Vector2(58, 72))


func _write_file(data: Dictionary) -> void:
	UI.clear(_sheet)
	var me: Dictionary = data.get("me", {})
	var w := _sheet.size.x
	_put(_sheet, _ink(Loc.t("FILE No. %d") % int(me.get("id", 0)), 11, false, Desk.INK_FADED), Vector2(0, 0), Vector2(w, 14))
	var who := _ink(str(me.get("name", "")).to_upper(), 24, true, Desk.INK)
	who.clip_text = true
	who.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_put(_sheet, who, Vector2(0, 12), Vector2(w - (150 if _touch else 110), 30))
	var stamp := House.Stamp.new("CONFIDENTIAL", Desk.INK_RED, 14)
	stamp.size = UI.grown(Vector2(128, 30))
	stamp.position = Vector2(w - stamp.size.x + 6.0, 4)
	stamp.rotation = 0.14
	_sheet.add_child(stamp)
	var matches := int(me.get("matches", 0))
	var index := House.tier_of(float(me.get("rating", 1000)), matches)
	var medal := MedalOf.new()
	medal.tier = index
	_put(_sheet, medal, Vector2(22, 70))
	var said := Loc.t("%s, rating %d") % [Loc.t(House.tier_name(index)), int(me.get("rating", 0))]
	_put(_sheet, _ink(said, 15), Vector2(52, 50), Vector2(w - 52, 20))
	var placed := Loc.t("#%d in the house, best %d, %d wins in %d") % [int(me.rank), int(me.get("peak", 0)), int(me.get("wins", 0)), matches] if me.get("rank") != null else Loc.t("Not in the ledger yet.")
	var where := _ink(placed, 12, false, Desk.INK_FADED)
	where.clip_text = true
	_put(_sheet, where, Vector2(52, 70), Vector2(w - 52, 18))
	if matches == 0:
		var nothing := _ink("Nothing on file yet: play a ranked match and the house starts writing.", 14)
		nothing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_put(_sheet, nothing, Vector2(0, 120), Vector2(w, 80))
		return
	var y := 102.0
	_put(_sheet, _ink("RATING, LAST MATCHES", 11, true, Desk.INK_FADED), Vector2(0, y), Vector2(w, 14))
	var chart := House.Chart.new()
	chart.values = data.get("series", [])
	_put(_sheet, chart, Vector2(0, y + 18.0), Vector2(w, 58))
	y += 100.0
	_put(_sheet, _ink("PLACES", 11, true, Desk.INK_FADED), Vector2(0, y), Vector2(w, 14))
	var places := House.Places.new()
	places.counts = data.get("places", []).map(func(n: Variant) -> int: return int(n))
	_put(_sheet, places, Vector2(0, y + 16.0), Vector2(w, 70))
	y += 96.0
	var lines := [
		["Bluffs", data.get("bluff_rate"), "of your claims", INK],
		["Caught", data.get("caught_rate"), "of your bluffs", Desk.INK_RED],
		["Right calls", data.get("doubt_accuracy"), "of your LIAR! calls", INK],
	]
	for line: Array in lines:
		_put(_sheet, _ink(line[0], 13, true), Vector2(0, y), Vector2(90, 20))
		var bar := House.Bar.new()
		bar.value = line[1]
		bar.ink = line[3]
		bar.thick = 8.0
		_put(_sheet, bar, Vector2(92, y), Vector2(96, 20))
		_put(_sheet, _ink(_percent(line[1]), 14), Vector2(194, y), Vector2(40, 20))
		_put(_sheet, _ink(line[2], 11, false, Desk.INK_FADED), Vector2(92, y + 16.0), Vector2(w - 92, 14))
		y += 34.0
	_put(_sheet, _ink("FAVOURITE COVERS", 11, true, Desk.INK_FADED), Vector2(0, y + 2.0), Vector2(w, 14))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_put(_sheet, row, Vector2(0, y + 20.0), Vector2(w, 26))
	for fav: Dictionary in data.get("favourites", []).slice(0, 3):
		var id := StringName(str(fav.get("id", "")))
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 4)
		cell.add_child(Icons.icon(id))
		cell.add_child(_ink(str(int(fav.get("claims", 0))), 14))
		row.add_child(cell)
		var def := Content.character(id)
		TipLayer.attach(cell, Loc.t("%s: claimed %d times, %s of them bluffs.") % [def.display_name if def != null else str(id), int(fav.get("claims", 0)), _percent(fav.get("bluff_rate"))])


func _write_no_file(why: String) -> void:
	UI.clear(_sheet)
	var stamp := House.Stamp.new("NO RECORD", Desk.INK_FADED, 18)
	stamp.size = UI.grown(Vector2(160, 40))
	stamp.position = Vector2((_sheet.size.x - stamp.size.x) / 2.0, 90)
	stamp.rotation = -0.1
	_sheet.add_child(stamp)
	var text := _ink(why, 15)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_put(_sheet, text, Vector2(10, 160), Vector2(_sheet.size.x - 20, 120))


# --- reading the house ---------------------------------------------------------

func _read() -> void:
	if not RankedApi.configured():
		_write_paper({"matches": 0})
		_write_no_file("The house has not opened yet.")
		return
	if RankedApi.signed_in():
		_read_file()
	else:
		_write_no_file("Sign in at the house to see your own file.")
	var answer: Dictionary = await RankedApi.get_json("/v1/analytics", false)
	if not is_inside_tree():
		return
	if answer.ok and answer.data is Dictionary:
		_write_paper(answer.data)
	else:
		var waiting: Label = _paper.get_node_or_null("Waiting")
		if waiting != null:
			waiting.text = Loc.t(answer.error)


func _read_file() -> void:
	var answer: Dictionary = await RankedApi.get_json("/v1/me/dossier")
	if not is_inside_tree():
		return
	if answer.ok and answer.data is Dictionary:
		_write_file(answer.data)
	else:
		_write_no_file(answer.error)


func _unhandled_key_input(event: InputEvent) -> void:
	UI.handle_fullscreen_key(event, get_window())


## The medal of a rank, struck on the file.
class MedalOf extends Control:
	var tier := -1

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		House.medal(self, Vector2.ZERO, tier, 20.0)
