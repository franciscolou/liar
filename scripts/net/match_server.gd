extends Node
## One ranked table of the house, run headless: the game started with
## `--ranked-server=<spec.json>` (the house's matchmaker does it, see
## server/api/liar_api/matchmaker.py; the export preset "Linux Server" makes
## this scene the main one, and menu.gd sends the game here too).
##
## The spec says the port, the seats (each with the hash of the ticket its
## member was given), the rules, and how to report to the house. The room is
## opened with nobody in it (Room.serve); once every seat is taken, or after
## `arrive_seconds`, the match is dealt. This process plays the match like
## every machine at the table does, with no table of its own: it is the host
## that orders the answers, the one whose engine says how the match ended,
## and the one that writes it down (match_record.gd). When it is over it
## reports to the house, tells the table the new ratings, and quits once the
## table is empty.
##
## It does not wait on anyone forever: a decision left open far past what the
## table's own clocks allow is answered with nothing (`_hurry_up`).

const Room := preload("res://scripts/net/room.gd")
const Record := preload("res://scripts/net/match_record.gd")
const Log := preload("res://scripts/net/match_log.gd")
const ARG := "--ranked-server="
## How long past its own clock (a turn's, or a choice's) a decision is let
## wait; and the patience for those with no clock (doubts, reactions).
const GRACE := 20.0
const PATIENCE := 45.0
## A turn with no clock at all still ends after this long.
const UNCLOCKED := 90.0
## After the end: how long the table may stay before the process quits.
const LINGER := 180.0
const REPORT_TRIES := 5

## Closed: the table is over and empty, or was called off. A test that runs a
## table inside its own process listens to this instead of the process quitting.
signal closed

## What the table was dealt as (the spec file), and its room. Both are read
## and opened on `_ready`, unless a test gave them already.
var spec: Dictionary = {}
var room: Node
## Whether the process is this table's alone: it quits when the table closes.
var standalone := true
var engine: GameEngine
var _record: Record
var _log: Log
var _dealt := false
var _hurried: Dictionary = {}  # ticket number -> true
var _turns := 0
var _over_at := -1.0


## The spec file this process was started with, or "".
static func spec_path() -> String:
	for arg: String in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with(ARG):
			return arg.trim_prefix(ARG)
	return ""


static func wanted() -> bool:
	return spec_path() != ""


func _ready() -> void:
	Content.ensure_loaded()
	if spec.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(spec_path()))
		if not parsed is Dictionary:
			_say("could not read the spec at '%s'" % spec_path())
			_close(2)
			return
		spec = parsed
	if room == null:
		# The root is still busy with this scene: the room hangs on it next.
		await get_tree().process_frame
		# This process holds no keys: the tickets are the members'.
		Room._keys_loaded = true
		Room._known_keys = []
		var problem: String = Room.serve(int(spec.port), spec.players)
		if problem != "":
			_say(problem)
			await _tell_house("aborted", {})
			_close(3)
			return
		room = Room.current
	room.scenes = false
	room.away_seconds = float(spec.get("away_seconds", 60))
	room.config = GameConfig.from_wire(spec.config)
	room.arrived.connect(_on_arrived)
	_say("table %s open on port %d for %s" % [spec.match, int(spec.port), ", ".join(PackedStringArray(spec.players.map(func(p: Dictionary) -> String: return p.name)))])
	get_tree().create_timer(float(spec.get("arrive_seconds", 60))).timeout.connect(_deal)


func _say(text: String) -> void:
	print("[%s] %s" % [Time.get_time_string_from_system(), text])


func _on_arrived(seat: int) -> void:
	_say("%s sat down" % room.seats[seat].name)
	if room.all_seated():
		_deal()


## Deals the match to whoever sat down; a table nobody came to is called off.
func _deal() -> void:
	if _dealt:
		return
	_dealt = true
	if room.seats.all(func(seat: Dictionary) -> bool: return seat.peer == 0):
		_say("nobody came: the table is called off")
		await _tell_house("aborted", {})
		_close()
		return
	room.start()
	var config: GameConfig = GameConfig.current
	engine = GameEngine.new()
	engine.setup(config)
	# No tree: nothing waits for an animation, nor for a bot to make up its mind.
	engine.tree = null
	_record = Record.new(engine, func(seat: int) -> bool: return room.absent(seat))
	engine.observers.append(self)
	engine.observers.append(_record)
	_log = Log.new(engine)
	engine.observers.append(_log)
	for p: PlayerState in engine.players:
		var controller := HumanController.new()
		controller.room = room
		var bot := BotController.new()
		bot.engine = engine
		bot.player = p
		bot.rng = RandomNumberGenerator.new()
		bot.rng.randomize()
		controller.stand_in = bot
		controller.engine = engine
		controller.player = p
		engine.controllers[p.id] = controller
	engine.finished.connect(_on_finished)
	_say("dealt: %s" % ", ".join(PackedStringArray(engine.characters.map(func(def: CharacterDef) -> String: return String(def.id)))))
	_tell_house("started", {"characters": engine.characters.map(func(def: CharacterDef) -> String: return String(def.id))})
	engine.run()


func present(event: GameEvent) -> void:
	# The machines compare notes with the host as each turn begins.
	if event.type == &"turn_started":
		_turns += 1
		var any: HumanController = engine.controllers[0]
		room.report(_turns, any._fingerprint())


func _process(_delta: float) -> void:
	if engine != null and not engine.over:
		_hurry_up()
	if _over_at >= 0.0:
		var empty: bool = room.match_peers.all(func(peer: int) -> bool: return peer == 0)
		if empty or Time.get_ticks_msec() / 1000.0 - _over_at > LINGER:
			_over_at = -1.0
			_close()


func _close(code := 0) -> void:
	closed.emit()
	if standalone:
		get_tree().quit(code)


## Answers with nothing a decision of someone at the table who has let it wait
## far longer than the table's clocks would. Their own machine should have
## done it already (or they are taking the match hostage).
func _hurry_up() -> void:
	var now := Time.get_ticks_msec()
	for ticket: RefCounted in room._tickets.values():
		if ticket.done or _hurried.has(ticket.number):
			continue
		var decision: Decision = ticket.decision
		if room.absent(decision.player.id):
			continue
		if (now - ticket.opened) / 1000.0 > _patience(decision):
			_hurried[ticket.number] = true
			_say("%s took too long: answered for them" % decision.player.name)
			room.submit(ticket, null)


func _patience(decision: Decision) -> float:
	if decision.context.has("seconds"):
		return float(decision.context.seconds) + GRACE
	match decision.kind:
		Decision.Kind.TURN, Decision.Kind.TARGET, Decision.Kind.PICK:
			var clock: int = engine.config.turn_seconds
			return clock + GRACE if clock > 0 else UNCLOCKED
	return PATIENCE


func _on_finished(winner: PlayerState) -> void:
	_over_at = Time.get_ticks_msec() / 1000.0
	var report := _record.report()
	report.build = room._build()
	report.log = _log.finish(room._history.duplicate(), report.players.map(func(p: Dictionary) -> Dictionary:
			return {"seat": p.seat, "place": p.place, "forfeit": p.forfeit}))
	_keep(report)
	_say("over in %d turns, %s won" % [engine.turn_count, winner.name if winner != null else "nobody"])
	var answer: Dictionary = {"ok": false}
	for attempt in (REPORT_TRIES if str(spec.get("api", "")) != "" else 0):
		answer = await _tell_house("result", report)
		if answer.ok:
			break
		await get_tree().create_timer(2.0 * (attempt + 1)).timeout
	var result := {"seats": answer.data.get("seats", []) if answer.ok and answer.data is Dictionary else []}
	for entry: Dictionary in report.players:
		if not result.seats.any(func(s: Dictionary) -> bool: return int(s.seat) == entry.seat):
			result.seats.append({"seat": entry.seat, "place": entry.place})
	result.recorded = answer.get("ok", false)
	room.ranked_finish(result)


## A copy of the report next to the spec, in case the house never hears of it.
func _keep(report: Dictionary) -> void:
	var at := spec_path()
	if at == "":
		return
	var file := FileAccess.open(at.get_basename() + ".record.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report))


## Posts to the house's /internal/matches/<id>/<what>.
func _tell_house(what: String, body: Dictionary) -> Dictionary:
	if str(spec.get("api", "")) == "":
		return {"ok": false}
	var http := HTTPRequest.new()
	http.timeout = 15.0
	add_child(http)
	var url := "%s/internal/matches/%s/%s" % [str(spec.get("api", "")).trim_suffix("/"), spec.get("match", ""), what]
	var headers := PackedStringArray(["Content-Type: application/json", "X-Match-Secret: " + str(spec.get("secret", ""))])
	if http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body)) != OK:
		http.queue_free()
		_say("could not call the house at " + url)
		return {"ok": false}
	var done: Array = await http.request_completed
	http.queue_free()
	var data: Variant = JSON.parse_string((done[3] as PackedByteArray).get_string_from_utf8())
	var ok: bool = done[0] == HTTPRequest.RESULT_SUCCESS and done[1] >= 200 and done[1] < 300
	if not ok:
		_say("the house answered %s to %s: %s" % [done[1], what, data])
	return {"ok": ok, "data": data}


func _exit_tree() -> void:
	if engine != null:
		engine.abort()
