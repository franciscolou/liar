extends Node
## A room played inside one process: a host and two machines that join it,
## each under its own branch of the tree with its own multiplayer, each running
## its own copy of the match (room.gd). People are bots with dice of their
## own that answer late, and every machine stutters at its own pace, so
## answers cross on the way. The match must still be the same one everywhere.
##
## Play it from the editor and read the output: `ok`/`FAILED` per match and
## "NET DONE: n failed". In the odd matches one machine walks away halfway.
## In the first of them the host has a bot play the seat, in the second it
## leaves it waiting, and in both the same player comes back later on another
## machine (by the key of the seat, under another name), which has to replay
## the match up to where the others are. A waiting seat stops the match on
## the next thing it is asked: then they come back to answer it. In the last
## one the host kicks them out, and they are turned away when they try to come
## back. Then the host itself walks away twice in the middle of a match: the
## room passes to one of the others and the match goes on there. The first
## time the new host has a bot play the seat; the second time the old host
## comes back, by the key of their seat, typing only the address: the room is
## on another port by then, which they have to find.

const Room := preload("res://scripts/net/room.gd")
# Past the ports real rooms take, so a game open on this computer is no bother.
const PORT := Room.PORT + Room.PORT_RANGE
const MATCHES := 6
const TIME_LIMIT := 90.0

var _rooms: Array = []  # host first
var _rng := RandomNumberGenerator.new()
var _split := false


func _ready() -> void:
	Content.ensure_loaded()
	# The keys of the seats stay in this process: none of them is written down.
	Room._keys_loaded = true
	Room._known_keys = []
	_rng.seed = 99
	var problem := await _open()
	var failed := 1 if problem != "" else 0
	if problem != "":
		_out("FAILED  opening the room: ", problem)
	else:
		for m in MATCHES:
			var outcome: Variant = await _play(m)
			# A script error cuts the match short with nothing to say: that is a failure too.
			problem = outcome if outcome is String else "it stopped on a script error"
			_out("%s  match %d%s" % ["ok    " if problem == "" else "FAILED", m, "" if problem == "" else ": " + problem])
			if problem != "":
				push_error("net: match %d: %s" % [m, problem])
				failed += 1
		# One more guest: when the host leaves, one of them takes the room
		# over and the others have to find it.
		# Back in the lobby, as Room.to_lobby leaves them: nobody joins a match.
		for room: Node in _rooms:
			room.in_match = false
		_join(30, "Guest3")
		var full := await _until(func() -> bool: return _rooms.all(func(room: Node) -> bool:
				return room.seats.size() == _rooms.size() + 1), "the third guest never got in")
		if full != "":
			_out("FAILED  ", full)
			failed += 1
		for m in [MATCHES, MATCHES + 1]:
			var outcome: Variant = await _hand_over_match(m, m == MATCHES + 1)
			problem = outcome if outcome is String else "it stopped on a script error"
			_out("%s  match %d (the host leaves)%s" % ["ok    " if problem == "" else "FAILED", m, "" if problem == "" else ": " + problem])
			if problem != "":
				push_error("net: match %d: %s" % [m, problem])
				failed += 1
				break
	_out("NET DONE: %d failed" % failed)
	var verdict := Label.new()
	verdict.text = "Net: %d failed. See the output." % failed
	verdict.position = Vector2(24, 24)
	add_child(verdict)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(failed)


## Prints `text`, and keeps it in a file of this run's own: another copy of the
## game (sharing user://) may be writing over the log meanwhile.
func _out(a: Variant, b: Variant = "") -> void:
	var line := str(a) + str(b)
	print(line)
	var path := "user://net_scene_%d.log" % OS.get_process_id()
	var file := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if file != null:
		file.seek_end()
		file.store_line(line)


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
	host.hosted("Host", PORT, 1)
	_rooms.append(host)
	for i in [1, 2]:
		_join(i)
	return await _until(func() -> bool: return host.seats.size() == 4 and _rooms.all(func(room: Node) -> bool: return room.seats.size() == 4), "the machines never got in")


## A machine joins the room at `port`. With no port (0), as the player who
## types only the address: Room.PORT first, then the rest of the range.
func _join(index: int, player_name := "", port := PORT) -> Node:
	var room := _machine(index)
	var client := ENetMultiplayerPeer.new()
	client.create_client("127.0.0.1", port if port > 0 else Room.PORT)
	room.multiplayer.multiplayer_peer = client
	room._player_name = player_name if player_name != "" else "Guest%d" % index
	room.scenes = false
	if port > 0:
		room._joined = true  # no lobby scene to open here
	else:
		room._address = "127.0.0.1"
		room._scanning = true
		room._wait_at_door()
	_rooms.append(room)
	return room


func _until(condition: Callable, problem: String) -> String:
	var waited := 0.0
	while not condition.call():
		await get_tree().process_frame
		waited += get_process_delta_time()
		if waited > TIME_LIMIT:
			return problem
	return ""


## Deals match `m` to every machine in the room, as Room.start does, and sets
## them all playing it.
func _deal(m: int) -> Array:
	var host: Node = _rooms[0]
	var dealt := GameConfig.new()
	for seat: Dictionary in host.seats:
		dealt.seats.append({"name": seat.name, "bot": seat.bot})
	dealt.character_count = 4 + (m % MATCHES) * 2
	dealt.max_turns = 400
	dealt.rng_seed = 500 + m
	var peers: Array = host.seats.map(func(seat: Dictionary) -> int: return seat.peer)
	var tables := []
	_split = false
	for room: Node in _rooms:
		room._begin(m + 1, peers.duplicate(), dealt.to_wire())
		if not room.out_of_step.is_connected(_note):
			room.out_of_step.connect(_note)
	# A key to each person's seat, and their hashes to everyone.
	var keys: Array = peers.map(func(peer: int) -> String: return "key-%d-%d" % [m, peer] if peer >= 1 else "")
	var hashes: Array = keys.map(func(key: String) -> String: return key.sha256_text() if key != "" else "")
	for room: Node in _rooms:
		room._key_hashes = hashes.duplicate()
	for key: String in keys:
		if key != "":
			Room._known_keys.append(key)
	for room: Node in _rooms:
		tables.append(_sit(room, GameConfig.from_wire(dealt.to_wire())))
	for table: Machine in tables:
		table.engine.run()
	return tables


func _play(m: int) -> String:
	var host: Node = _rooms[0]
	var tables := _deal(m)

	# In the odd matches the last machine leaves once the match is under way.
	var leaver: Machine = tables.back() if m % 2 == 1 and tables.size() > 2 else null
	var someone_left := leaver != null
	if someone_left:
		var gone := await _until(func() -> bool: return leaver.engine.turn_count >= 6 or leaver.engine.over, "never got to turn 6")
		if gone != "":
			return gone
		var left_seat: int = leaver.room.my_match_seat()
		leaver.engine.abort()
		tables.erase(leaver)
		leaver.queue_free()
		_rooms.erase(leaver.room)
		# As a real machine walks out: its connection and the port it
		# listened on are closed, and it does not look for a new host.
		leaver.room.leave()
		var waiting := await _until(func() -> bool: return host.away_mode(left_seat) == &"idle", "the seat of the one who left is not waiting")
		if waiting != "":
			return waiting
		var kick := m == MATCHES - 1
		if kick:
			# Out at once: as the answer to what the seat is being asked, or to
			# the next thing, not on the turn it gets to some time later.
			var kicked_at: int = host_table(tables).engine.turn_count
			host.set_away(left_seat, &"kick")
			var out := await _until(func() -> bool: return not host_table(tables).engine.players[left_seat].alive or host_table(tables).engine.over, "the kick never came")
			if out != "":
				return out
			if host_table(tables).engine.turn_count > kicked_at + 1:
				return "the kick waited for turn %d (asked on turn %d)" % [host_table(tables).engine.turn_count, kicked_at]
			_out("        kicked on turn %d, asked on turn %d" % [host_table(tables).engine.turn_count, kicked_at])
		elif m == 1:
			host.set_away(left_seat, &"bot")
		# A waiting seat stops the match on the next thing it is asked: then
		# they come back to answer it.
		var held := func() -> bool: return host._tickets.values().any(func(ticket: RefCounted) -> bool:
			return ticket.decision.player.id == left_seat and not ticket.asked)
		var later := await _until(func() -> bool: return host_table(tables).engine.turn_count >= 12 or host_table(tables).engine.over or held.call(), "never got to turn 12")
		if later != "":
			return later
		if held.call():
			_out("        the match waits for the one who left")
		# The same player comes back from another machine, under another name:
		# the key is what counts.
		Room.notice = ""
		var comer := _join(10 + m, "Somebody")
		if kick:
			# Only the room this machine is in tells why it was turned away.
			Room.current = comer
			var turned := await _until(func() -> bool: return Room.notice != "", "the one who was kicked was let back in")
			_rooms.erase(comer)
			if turned != "":
				return turned
		else:
			var back := await _until(func() -> bool: return comer.in_match, "the one who came back never got the match")
			if back != "":
				return back
			var again := _sit(comer, GameConfig.from_wire(comer._dealt))
			if comer.my_match_seat() != left_seat:
				return "came back to another seat"
			tables.append(again)
			again.engine.run()
	var ended := await _finish(tables)
	if ended != "":
		return ended
	if someone_left and host.seats.size() != _rooms.size() + 1:
		return "the one who left still has a seat"
	if someone_left:
		var first: Machine = tables[0]
		var gone: PlayerState = first.engine.players[first.engine.players.size() - 1]
		var fate := "still in" if gone.alive else ("kicked" if gone.left.is_empty() else "eliminated")
		_out("        the one who left: %s" % fate)
	return ""


## Waits for every machine to play the match out, and checks that they all
## played the same one.
func _finish(tables: Array) -> String:
	var host: Node = _rooms[0]
	var late := await _until(func() -> bool: return tables.all(func(table: Machine) -> bool: return table.engine.over or table.done), "late")
	if late != "":
		late = _stuck(tables)
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
	_out("        %d machines, %d decisions, %s" % [tables.size(), host._next_ticket, first.summary().get_slice("\n", 0)])
	return ""


## Where a match that did not finish is stuck, machine by machine.
func _stuck(tables: Array) -> String:
	var host: Node = _rooms[0]
	return "did not finish: turns %s, open on the host: %s; machines: %s" % [
		tables.map(func(table: Machine) -> int: return table.engine.turn_count),
		host._tickets.values().map(func(ticket: RefCounted) -> String:
			return "#%d seat %d kind %d%s, absent %s, mode %s, away %s, peers %s" % [ticket.number, ticket.decision.player.id, ticket.decision.kind,
				" asked" if ticket.asked else "", host.absent(ticket.decision.player.id), host.away_mode(ticket.decision.player.id), host.away, host.match_peers]),
		_rooms.map(func(room: Node) -> String: return "[me %d, host %s, handing over %s, open %s, sent %s, %d answers, last %s]" % [
			room.my_peer(), room.hosting, room.handing_over, room._tickets.keys(), room._sent.keys(), room._history.size(), room._history.slice(-2)])]


## The host walks away halfway through match `m`: the room has to pass to one
## of the others, in one piece, and the match go on there. With `comes_back`
## the old host comes back to the new one later, from another machine and by
## the key of their seat; without, the new host has a bot play the seat.
func _hand_over_match(m: int, comes_back: bool) -> String:
	var heard := await _until(func() -> bool: return _rooms.slice(1).all(func(room: Node) -> bool: return not room._succession.is_empty()),
			"the guests never heard who would take the room over")
	if heard != "":
		return heard
	var host: Node = _rooms[0]
	var tables := _deal(m)
	var leaver: Machine = tables[0]
	var under_way := await _until(func() -> bool: return leaver.engine.turn_count >= 6 or leaver.engine.over, "never got to turn 6")
	if under_way != "":
		return under_way
	var left_seat: int = host.my_match_seat()
	leaver.engine.abort()
	tables.erase(leaver)
	leaver.queue_free()
	_rooms.erase(host)
	host.leave()
	var moved := await _until(func() -> bool:
		return _rooms.any(func(room: Node) -> bool: return room.hosting) \
				and _rooms.all(func(room: Node) -> bool: return not room.handing_over and not room._taking_over), "the room never passed to anyone")
	if moved != "":
		return moved
	var hosts := _rooms.filter(func(room: Node) -> bool: return room.hosting)
	if hosts.size() != 1:
		return "the room split in %d" % hosts.size()
	var heir: Node = hosts[0]
	_rooms.erase(heir)
	_rooms.push_front(heir)
	for table: Machine in tables:
		if table.room == heir:
			tables.erase(table)
			tables.push_front(table)
			break
	_out("        the room passed to %s, on port %d" % [heir.host_name(), heir.port])
	if comes_back and heir.port == Room.PORT:
		return "the room is on the usual port: nothing to look for"
	if heir.away_mode(left_seat) != &"idle":
		return "the old host's seat is not waiting"
	if _rooms.any(func(room: Node) -> bool: return room.host_name() != heir.host_name()):
		return "the machines do not agree on who hosts the room"
	if comes_back:
		var held := func() -> bool: return heir._tickets.values().any(func(ticket: RefCounted) -> bool:
			return ticket.decision.player.id == left_seat and not ticket.asked)
		var turn: int = tables[0].engine.turn_count
		var later := await _until(func() -> bool: return tables[0].engine.turn_count >= turn + 4 or tables[0].engine.over or held.call(), "never got 4 turns further")
		if later != "":
			return later
		var comer := _join(20 + m, "Boss", 0)
		var back := await _until(func() -> bool: return comer.in_match, "the old host never got the match back")
		if back != "":
			return back
		_out("        the old host found it at %s" % comer._where)
		var again := _sit(comer, GameConfig.from_wire(comer._dealt))
		if comer.my_match_seat() != left_seat:
			return "the old host came back to another seat"
		tables.append(again)
		again.engine.run()
	else:
		heir.set_away(left_seat, &"bot")
	return await _finish(tables)


func host_table(tables: Array) -> Machine:
	return tables[0]


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
			# On every machine, as at a real table: any of them may come to host.
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
