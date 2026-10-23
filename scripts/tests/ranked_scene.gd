extends Node
## A ranked table of the house played inside one process: the house's own
## process (match_server.gd, with no house to report to) and the members'
## machines, each under its own branch with its own multiplayer, as in
## net_scene.gd. Every member is a bot answering through the room.
##
## Play it from the editor and read the output: `ok`/`FAILED` per table and
## "RANKED DONE: n failed". At the first table everyone sits down, one member
## walks away halfway, a bot takes the seat, and the member comes back by
## their ticket on another machine, which has to replay the match. At the
## second one a member never shows up: the table is dealt without them, a bot
## plays the seat and the report puts it last. Every machine has to end in the
## same match, and hear the result from the house.

const Room := preload("res://scripts/net/room.gd")
const MatchServer := preload("res://scripts/net/match_server.gd")
const Net := preload("res://scripts/tests/net_scene.gd")
# Past the ports real rooms and the net test take; one for each table.
const PORT := Room.PORT + Room.PORT_RANGE + 2
const TIME_LIMIT := 120.0
const NAMES := ["Ana", "Bia", "Caio"]

var _rng := RandomNumberGenerator.new()
var _branches: Array = []


func _ready() -> void:
	Content.ensure_loaded()
	Room._keys_loaded = true
	Room._known_keys = []
	_rng.seed = 41
	var failed := 0
	for table in 2:
		var outcome: Variant = await _table(table)
		var problem: String = outcome if outcome is String else "it stopped on a script error"
		print("%s  table %d%s" % ["ok    " if problem == "" else "FAILED", table, "" if problem == "" else ": " + problem])
		if problem != "":
			push_error("ranked: table %d: %s" % [table, problem])
			failed += 1
		for branch: Node in _branches:
			branch.queue_free()
		_branches.clear()
		await get_tree().create_timer(0.5).timeout
	print("RANKED DONE: %d failed" % failed)
	var verdict := Label.new()
	verdict.text = "Ranked: %d failed. See the output." % failed
	verdict.position = Vector2(24, 24)
	add_child(verdict)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(failed)


func _machine(index: int) -> Node:
	var branch := Node.new()
	branch.name = "Machine%d_%d" % [index, Time.get_ticks_usec()]
	add_child(branch)
	_branches.append(branch)
	get_tree().set_multiplayer(SceneMultiplayer.new(), branch.get_path())
	var room: Node = Room.new()
	room.name = "Room"
	branch.add_child(room)
	return room


func _member(index: int, ticket: String, member_name: String, at: int) -> Node:
	var room := _machine(index)
	var client := ENetMultiplayerPeer.new()
	client.create_client("127.0.0.1", at)
	room.multiplayer.multiplayer_peer = client
	room.ranked = true
	room.ticket = ticket
	room._player_name = member_name
	room.scenes = false
	return room


func _until(condition: Callable, problem: String) -> String:
	var waited := 0.0
	while not condition.call():
		await get_tree().process_frame
		waited += get_process_delta_time()
		if waited > TIME_LIMIT:
			return problem
	return ""


func _table(round: int) -> String:
	var house := _machine(0)
	var server := ENetMultiplayerPeer.new()
	var at := PORT + round
	if server.create_server(at, 16) != OK:
		return "port %d is taken" % at
	house.multiplayer.multiplayer_peer = server
	var tickets: Array = NAMES.map(func(n: String) -> String: return "ticket-%d-%s" % [round, n])
	var players := []
	for i in NAMES.size():
		players.append({"account": i + 1, "name": NAMES[i], "ticket_hash": tickets[i].sha256_text()})
	house.served(at, players)
	var rules := GameConfig.new()
	rules.character_count = 5
	rules.max_turns = 400
	var table: Node = MatchServer.new()
	table.spec = {"match": "test%d" % round, "port": at, "api": "", "config": rules.to_wire(),
			"players": players, "arrive_seconds": 3 if round == 1 else 30, "away_seconds": 1}
	table.room = house
	table.standalone = false
	var closed := [false]
	table.closed.connect(func() -> void: closed[0] = true)
	add_child(table)
	_branches.append(table)

	# At the second table, the last member never shows up.
	var coming := NAMES.size() if round == 0 else NAMES.size() - 1
	var members := []
	for i in coming:
		members.append(_member(i + 1, tickets[i], NAMES[i], at))
	var dealt := await _until(func() -> bool: return members.all(func(r: Node) -> bool: return r.in_match), "the house never dealt")
	if dealt != "":
		return dealt
	if round == 0 and table.engine == null:
		return "dealt before everyone sat down"
	var machines := []
	for room: Node in members:
		if room.my_match_seat() < 0:
			return "%s got no seat" % room._player_name
		machines.append(_sit(room))
	for m: Net.Machine in machines:
		m.engine.run()

	var came_back: Node
	if round == 0:
		var leaver: Net.Machine = machines.back()
		var seat: int = leaver.room.my_match_seat()
		var going := await _until(func() -> bool: return leaver.engine.turn_count >= 6 or leaver.engine.over, "never got to turn 6")
		if going != "":
			return going
		if not leaver.engine.over:
			leaver.engine.abort()
			machines.erase(leaver)
			leaver.room.leave()
			var benched := await _until(func() -> bool: return house.away_mode(seat) == &"bot" or table.engine.over, "no bot took the seat")
			if benched != "":
				return benched
			# Back by the ticket, on another machine.
			came_back = _member(9, tickets[NAMES.size() - 1], NAMES.back(), at)
			var back := await _until(func() -> bool: return came_back.in_match or table.engine.over, "the member never got back to the match")
			if back != "":
				return back
			if came_back.in_match:
				if came_back.my_match_seat() != seat:
					return "came back to another seat"
				var again := _sit(came_back)
				machines.append(again)
				again.engine.run()

	var ended := await _until(func() -> bool: return table.engine.over and machines.all(func(m: Net.Machine) -> bool: return m.done), "the match never ended")
	if ended != "":
		return ended
	var winner: PlayerState = table.engine.winner
	for m: Net.Machine in machines:
		if (m.engine.winner == null) != (winner == null) or (winner != null and m.engine.winner.id != winner.id):
			return "%s saw another match" % m.room._player_name
	var told := await _until(func() -> bool: return machines.all(func(m: Net.Machine) -> bool: return not m.room.ranked_result.is_empty()), "the table never heard the result")
	if told != "":
		return told
	var report: Dictionary = table._record.report()
	var places: Array = report.players.map(func(p: Dictionary) -> int: return p.place)
	places.sort()
	if places.front() != 1 or report.claims.is_empty():
		return "a report with no winner or no claims: %s" % [places]
	var forfeits: Array = report.players.filter(func(p: Dictionary) -> bool: return p.forfeit)
	if round == 1 and (forfeits.size() != 1 or forfeits[0].seat != NAMES.size() - 1 or forfeits[0].place != NAMES.size()):
		return "the one who never came was not put last: %s" % [report.players]
	if round == 0 and came_back != null and came_back.in_match and not forfeits.is_empty():
		return "the one who came back was counted out: %s" % [report.players]
	print("        %d turns, %d claims, %d doubts; places %s" % [report.turns, report.claims.size(), report.doubts.size(),
			report.players.map(func(p: Dictionary) -> String: return "%s:%d%s" % [NAMES[p.seat], p.place, "*" if p.forfeit else ""])])
	for m: Net.Machine in machines:
		m.room.leave()
	var gone := await _until(func() -> bool: return closed[0], "the house never closed the table")
	server.close()
	return gone


## Sets `room` playing the match it was dealt, as a table does.
func _sit(room: Node) -> Net.Machine:
	var machine := Net.Machine.new()
	machine.room = room
	machine.rng.seed = _rng.randi()
	room.get_parent().add_child(machine)
	var engine := GameEngine.new()
	engine.setup(GameConfig.from_wire(room._dealt))
	engine.observers.append(machine)
	engine.finished.connect(func(_winner: PlayerState) -> void: machine.done = true)
	machine.engine = engine
	var mine: int = room.my_match_seat()
	for p: PlayerState in engine.players:
		var controller := HumanController.new()
		controller.room = room
		var bot := BotController.new()
		bot.engine = engine
		bot.player = p
		bot.rng = RandomNumberGenerator.new()
		bot.rng.seed = _rng.randi()
		controller.stand_in = bot
		if p.id == mine:
			controller.table = machine
			machine.person = bot
		controller.engine = engine
		controller.player = p
		engine.controllers[p.id] = controller
	return machine
