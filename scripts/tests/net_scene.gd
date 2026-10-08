extends Node
## A room played inside one process: a host and two machines that join it,
## each under its own branch of the tree with its own multiplayer, each running
## its own copy of the match (room.gd). People are bots with dice of their
## own that answer late, and every machine stutters at its own pace, so
## answers cross on the way. The match must still be the same one everywhere.
##
## Play it from the editor and read the output: `ok`/`FAILED` per match and
## "NET DONE: n failed". In the odd matches one machine walks away halfway and
## the host has to play its seat.

const Room := preload("res://scripts/net/room.gd")
const PORT := Room.PORT + 1
const MATCHES := 6
const TIME_LIMIT := 90.0

var _rooms: Array = []  # host first
var _rng := RandomNumberGenerator.new()
var _split := false


func _ready() -> void:
	Content.ensure_loaded()
	_rng.seed = 99
	var problem := await _open()
	var failed := 1 if problem != "" else 0
	if problem != "":
		print("FAILED  opening the room: ", problem)
	else:
		for m in MATCHES:
			problem = await _play(m)
			print("%s  match %d%s" % ["ok    " if problem == "" else "FAILED", m, "" if problem == "" else ": " + problem])
			if problem != "":
				push_error("net: match %d: %s" % [m, problem])
				failed += 1
	print("NET DONE: %d failed" % failed)
	var verdict := Label.new()
	verdict.text = "Net: %d failed. See the output." % failed
	verdict.position = Vector2(24, 24)
	add_child(verdict)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(failed)


func _machine(index: int) -> Node:
	var branch := Node.new()
	branch.name = "Machine%d" % index
	add_child(branch)
	get_tree().set_multiplayer(SceneMultiplayer.new(), branch.get_path())
	var room: Node = Room.new()
	room.name = "Room"
	branch.add_child(room)
	return room


func _open() -> String:
	var host := _machine(0)
	var server := ENetMultiplayerPeer.new()
	if server.create_server(PORT, 8) != OK:
		return "port %d is taken" % PORT
	host.multiplayer.multiplayer_peer = server
	host.hosting = true
	host.config = GameConfig.new()
	host.seats = [{"name": "Host", "bot": false, "peer": 1}]
	host.add_bot()
	_rooms.append(host)
	for i in [1, 2]:
		_join(i)
	return await _until(func() -> bool: return host.seats.size() == 4 and _rooms.all(func(room: Node) -> bool: return room.seats.size() == 4), "the machines never got in")


func _join(index: int) -> void:
	var room := _machine(index)
	var client := ENetMultiplayerPeer.new()
	client.create_client("127.0.0.1", PORT)
	room.multiplayer.multiplayer_peer = client
	room._player_name = "Guest%d" % index
	room._joined = true  # no lobby scene to open here
	_rooms.append(room)


func _until(condition: Callable, problem: String) -> String:
	var waited := 0.0
	while not condition.call():
		await get_tree().process_frame
		waited += get_process_delta_time()
		if waited > TIME_LIMIT:
			return problem
	return ""


func _play(m: int) -> String:
	var host: Node = _rooms[0]
	var dealt := GameConfig.new()
	for seat: Dictionary in host.seats:
		dealt.seats.append({"name": seat.name, "bot": seat.bot})
	dealt.character_count = 4 + m * 2
	dealt.max_turns = 400
	dealt.rng_seed = 500 + m
	var peers: Array = host.seats.map(func(seat: Dictionary) -> int: return seat.peer)
	var tables := []
	_split = false
	for room: Node in _rooms:
		room._begin(m + 1, peers.duplicate())
		if not room.out_of_step.is_connected(_note):
			room.out_of_step.connect(_note)
	for room: Node in _rooms:
		tables.append(_sit(room, GameConfig.from_wire(dealt.to_wire())))
	for table: Machine in tables:
		table.engine.run()

	# In the odd matches the last machine leaves once the match is under way.
	var leaver: Machine = tables.back() if m % 2 == 1 and tables.size() > 2 else null
	if leaver != null:
		var gone := await _until(func() -> bool: return leaver.engine.turn_count >= 6 or leaver.engine.over, "never got to turn 6")
		if gone != "":
			return gone
		leaver.engine.abort()
		leaver.room.release()
		leaver.room.multiplayer.multiplayer_peer.close()
		tables.erase(leaver)
		leaver.queue_free()
		_rooms.erase(leaver.room)
	var late := await _until(func() -> bool: return tables.all(func(table: Machine) -> bool: return table.engine.over or table.done), "did not finish: turns %s, %d decisions open on the host" % [
		tables.map(func(table: Machine) -> int: return table.engine.turn_count), host._tickets.size()])
	for table: Machine in tables:
		table.queue_free()
	if late != "":
		for table: Machine in tables:
			table.engine.abort()
			table.room.release()
		return late
	if _split:
		return "the host saw the machines out of step"
	var first: Machine = tables[0]
	for table: Machine in tables:
		if table.summary() != first.summary():
			return "the machines ended in different matches:\n%s\n%s" % [first.summary(), table.summary()]
	if leaver != null and host.seats.size() != _rooms.size() + 1:
		return "the one who left still has a seat"
	print("        %d machines, %d decisions, %s" % [tables.size(), host._next_ticket, first.summary().get_slice("\n", 0)])
	return ""


func _note(_turn: int) -> void:
	_split = true


## One machine's copy of the match.
func _sit(room: Node, config: GameConfig) -> Machine:
	var table := Machine.new()
	table.room = room
	table.rng.seed = _rng.randi()
	add_child(table)
	var engine := GameEngine.new()
	engine.setup(config)
	engine.observers.append(table)
	engine.finished.connect(func(_winner: PlayerState) -> void: table.done = true)
	table.engine = engine
	var mine: int = room.my_match_seat()
	for p: PlayerState in engine.players:
		var controller: Controller
		if p.is_bot:
			controller = BotController.new()
		else:
			controller = HumanController.new()
			controller.room = room
			if p.id == mine:
				controller.table = table
				table.person = _bot(engine, p)
			if room.hosting:
				controller.stand_in = _bot(engine, p)
		controller.engine = engine
		controller.player = p
		engine.controllers[p.id] = controller
	return table


func _bot(engine: GameEngine, p: PlayerState) -> BotController:
	var bot := BotController.new()
	bot.engine = engine
	bot.player = p
	bot.boldness = 0.5
	bot.suspicion = 0.3
	bot.rng = RandomNumberGenerator.new()
	bot.rng.seed = _rng.randi()
	return bot


## Stands where the table stands on a real machine: it answers for the person
## sitting at it, late, and holds every event up now and then.
class Machine extends Node:
	var room: Node
	var engine: GameEngine
	var person: BotController
	var rng := RandomNumberGenerator.new()
	var done := false
	var _asked: Decision

	func request(d: Decision) -> Variant:
		_asked = d
		await get_tree().create_timer(rng.randf() * 0.04).timeout
		if _asked != d or engine.aborted:
			return await engine.ask(d) if engine.aborted else false
		_asked = null
		var reactions: Array = d.context.get("reactions", [])
		if d.kind == Decision.Kind.DOUBT and not reactions.is_empty() and rng.randf() < 0.5:
			return reactions[0]
		return await person.decide(d)

	func withdraw(d: Decision) -> void:
		if _asked == d:
			_asked = null

	func present(event: GameEvent) -> void:
		person.observe(event)
		if rng.randf() < 0.06 and not engine.aborted:
			await get_tree().create_timer(rng.randf() * 0.03).timeout

	func summary() -> String:
		var lines := ["turn %d, winner %s, dice %d" % [engine.turn_count, engine.winner.name if engine.winner != null else "-", engine.rng.state]]
		for p: PlayerState in engine.players:
			lines.append("%s %dM %dc %s" % [p.name, p.morale, p.coins, p.cards])
		return "\n".join(lines)
