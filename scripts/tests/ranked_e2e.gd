extends Node
## One ranked match against a real house, from the outside: a few members
## join it, queue, get a table, play it through the match server the house
## starts, and hear their new ratings. For trying a house end to end, the one
## on a laptop or the one on the VPS:
##
##     godot --headless res://scripts/tests/ranked_e2e.tscn -- --house=https://liar.example.com [--players=3]
##
## Every member is a bot answering through the room, each on a machine of its
## own (a branch of the tree, as in net_scene.gd). The members are new ones,
## named "e2e" and a number: on a real house they stay in its books (with
## the match they played). It prints "RANKED E2E OK" or "RANKED E2E FAILED: why"
## and quits with 0 or 1.

const Room := preload("res://scripts/net/room.gd")
const Net := preload("res://scripts/tests/net_scene.gd")
const TIME_LIMIT := 240.0

var _house := "http://127.0.0.1:8080"
var _players := 3
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--house="):
			_house = arg.trim_prefix("--house=").trim_suffix("/")
		elif arg.begins_with("--players="):
			_players = clampi(arg.trim_prefix("--players=").to_int(), 2, Room.MAX_SEATS)
	Content.ensure_loaded()
	Room._keys_loaded = true
	Room._known_keys = []
	_rng.randomize()
	var problem: String = await _play()
	print("RANKED E2E OK" if problem == "" else "RANKED E2E FAILED: " + problem)
	get_tree().quit(0 if problem == "" else 1)


func _call(method: int, path: String, body: Variant = null, token := "") -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 15.0
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if token != "":
		headers.append("Authorization: Bearer " + token)
	if http.request(_house + path, headers, method, JSON.stringify(body) if body != null else "") != OK:
		http.queue_free()
		return {"ok": false, "data": null}
	var done: Array = await http.request_completed
	http.queue_free()
	var data: Variant = JSON.parse_string((done[3] as PackedByteArray).get_string_from_utf8())
	return {"ok": done[0] == HTTPRequest.RESULT_SUCCESS and done[1] >= 200 and done[1] < 300, "status": done[1], "data": data}


func _until(condition: Callable, problem: String) -> String:
	var waited := 0.0
	while not condition.call():
		await get_tree().process_frame
		waited += get_process_delta_time()
		if waited > TIME_LIMIT:
			return problem
	return ""


func _play() -> String:
	var status := await _call(HTTPClient.METHOD_GET, "/v1/status")
	if not status.ok:
		return "the house does not answer at " + _house
	print("house: %s" % [status.data])
	var probe: Node = Room.new()
	var build: int = probe._build()
	probe.free()
	var members := []
	var tag := "%04x" % _rng.randi_range(0, 0xffff)
	for i in _players:
		var member_name := "e2e%s_%d" % [tag, i]
		var joined := await _call(HTTPClient.METHOD_POST, "/v1/accounts", {"name": member_name, "password": "e2e-" + tag})
		if not joined.ok:
			return "could not join the house as %s: %s" % [member_name, joined.data]
		members.append({"name": joined.data.me.name, "token": joined.data.token, "rating": joined.data.me.rating})
	for m: Dictionary in members:
		var queued := await _call(HTTPClient.METHOD_POST, "/v1/queue", {"build": build}, m.token)
		if not queued.ok:
			return "could not queue: %s" % [queued.data]
	print("queued %d members; waiting for a table" % members.size())
	var tables := {}
	var waited := 0.0
	while tables.size() < members.size():
		for m: Dictionary in members:
			if tables.has(m.name):
				continue
			var now := await _call(HTTPClient.METHOD_GET, "/v1/queue", null, m.token)
			if now.ok and now.data.state == "matched":
				tables[m.name] = now.data.match
		await get_tree().create_timer(1.0).timeout
		waited += 1.0
		if waited > TIME_LIMIT:
			return "the house never dealt a table"
	var first: Dictionary = tables.values()[0]
	print("table %s at %s:%d" % [first.id, first.address, int(first.port)])
	var rooms := []
	for i in members.size():
		var table: Dictionary = tables[members[i].name]
		rooms.append(_member(i, table, members[i].name))
	var dealt := await _until(func() -> bool: return rooms.all(func(r: Node) -> bool: return r.in_match), "the match server never dealt the match")
	if dealt != "":
		return dealt
	var machines := []
	for room: Node in rooms:
		machines.append(_sit(room))
	for m: Net.Machine in machines:
		m.engine.run()
	var ended := await _until(func() -> bool: return machines.all(func(m: Net.Machine) -> bool: return m.done), "the match never ended")
	if ended != "":
		return ended
	var winner: PlayerState = machines[0].engine.winner
	for m: Net.Machine in machines:
		if (m.engine.winner == null) != (winner == null) or (winner != null and m.engine.winner.id != winner.id):
			return "the machines saw different matches"
	print("over in %d turns, %s won" % [machines[0].engine.turn_count, winner.name if winner != null else "nobody"])
	var told := await _until(func() -> bool: return rooms.all(func(r: Node) -> bool: return not r.ranked_result.is_empty()), "the table never heard from the house")
	if told != "":
		return told
	var result: Dictionary = rooms[0].ranked_result
	if not result.get("recorded", false):
		return "the match server could not write the match down at the house"
	print("ratings: %s" % [result.seats])
	for room: Node in rooms:
		room.leave()
	var board := await _call(HTTPClient.METHOD_GET, "/v1/standings?limit=200")
	var names: Array = board.data.players.map(func(p: Dictionary) -> String: return p.name) if board.ok else []
	for m: Dictionary in members:
		if not names.has(m.name):
			return "%s is not in the standings" % m.name
	var dossier := await _call(HTTPClient.METHOD_GET, "/v1/me/dossier", null, members[0].token)
	if not dossier.ok or int(dossier.data.me.matches) != 1:
		return "the member's file does not have the match: %s" % [dossier.data]
	return ""


func _member(index: int, table: Dictionary, member_name: String) -> Node:
	var branch := Node.new()
	branch.name = "Member%d" % index
	add_child(branch)
	get_tree().set_multiplayer(SceneMultiplayer.new(), branch.get_path())
	var room: Node = Room.new()
	# Rpcs find the room by its path from the root of its multiplayer, which
	# has to be the same as on the house's process.
	room.name = Room.NODE_NAME
	branch.add_child(room)
	var client := ENetMultiplayerPeer.new()
	client.create_client(str(table.address), int(table.port))
	room.multiplayer.multiplayer_peer = client
	room.ranked = true
	room.ticket = str(table.ticket)
	room._player_name = member_name
	room.scenes = false
	return room


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
