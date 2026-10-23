extends Node
## A ranked room against a real house, from the outside: a few members join
## the house, one of them hosts a room the usual way (no match server), the
## others join it by address, the host turns it ranked and deals, everyone
## plays the match through, each machine reports the end to the house, and
## the house rates them. For trying the house's ranked rooms, on a laptop or
## on the VPS:
##
##     godot --headless res://scripts/tests/ranked_room_e2e.tscn -- --house=https://liar.example.com [--players=3] [--logs=<dir>]
##
## Every machine is a branch of the tree, as in net_scene.gd, with a member
## of its own (Room.house_name, house_token). The members are new ones, named
## "e2r" and a number. With `--logs`, the house's data folder on this
## computer, it also checks the file of the match. It prints
## "RANKED ROOM E2E OK" or "RANKED ROOM E2E FAILED: why" and quits with 0 or 1.

const Room := preload("res://scripts/net/room.gd")
const RankedApi := preload("res://scripts/net/ranked_api.gd")
const Net := preload("res://scripts/tests/net_scene.gd")
const E2E := preload("res://scripts/tests/ranked_e2e.gd")
const TIME_LIMIT := 240.0
const PORT := Room.PORT + Room.PORT_RANGE + 7

var _house := "http://127.0.0.1:8080"
var _players := 3
var _logs := ""
var _rng := RandomNumberGenerator.new()
var _caller: Node


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--house="):
			_house = arg.trim_prefix("--house=").trim_suffix("/")
		elif arg.begins_with("--players="):
			_players = clampi(arg.trim_prefix("--players=").to_int(), 2, Room.MAX_SEATS)
		elif arg.begins_with("--logs="):
			_logs = arg.trim_prefix("--logs=")
	Content.ensure_loaded()
	Settings.ensure_loaded()
	RankedApi._url_read = true
	RankedApi._url = _house
	Room._keys_loaded = true
	Room._known_keys = []
	_rng.randomize()
	# The calls of ranked_e2e.gd, and its way of sitting a machine at a match.
	_caller = E2E.new()
	var problem: String = await _play()
	print("RANKED ROOM E2E OK" if problem == "" else "RANKED ROOM E2E FAILED: " + problem)
	get_tree().quit(0 if problem == "" else 1)


func _call(method: int, path: String, body: Variant = null, token := "") -> Dictionary:
	return await RankedApi.call_house(method, path, body, token != "", token)


func _until(condition: Callable, problem: String) -> String:
	var waited := 0.0
	while not condition.call():
		await get_tree().process_frame
		waited += get_process_delta_time()
		if waited > TIME_LIMIT:
			return problem
	return ""


func _play() -> String:
	var tag := "%04x" % _rng.randi_range(0, 0xffff)
	var members := []
	for i in _players:
		var joined := await _call(HTTPClient.METHOD_POST, "/v1/accounts", {"name": "e2r%s_%d" % [tag, i], "password": "e2r-" + tag})
		if not joined.ok:
			return "could not join the house: %s" % [joined.data]
		members.append({"name": joined.data.me.name, "token": joined.data.token})
	var rooms := []
	for i in members.size():
		rooms.append(_machine(i, members[i]))
	var host: Node = rooms[0]
	var server := ENetMultiplayerPeer.new()
	if server.create_server(PORT, 8) != OK:
		return "port %d is taken" % PORT
	host.multiplayer.multiplayer_peer = server
	host.hosted(members[0].name, PORT, 0)
	# The room of this process, as far as the room is concerned.
	Room.current = host
	host.rated_note.connect(func(text: String) -> void:
		if text != "":
			print("the house: " + text))
	for i in range(1, rooms.size()):
		var client := ENetMultiplayerPeer.new()
		client.create_client("127.0.0.1", PORT)
		rooms[i].multiplayer.multiplayer_peer = client
		rooms[i]._player_name = "guest%d" % i
	var seated := await _until(func() -> bool:
		return host.seats.size() == rooms.size() and host.seats.all(func(seat: Dictionary) -> bool: return seat.member != ""),
		"the members never sat down in the room")
	if seated != "":
		return seated
	await host.set_rated(true)
	if not host.rated:
		return "the room would not turn ranked"
	if host.seats.map(func(seat: Dictionary) -> String: return seat.name) != members.map(func(m: Dictionary) -> String: return m.name):
		return "the seats are not named after the members: %s" % [host.seats]
	host.start()
	var dealt := await _until(func() -> bool: return rooms.all(func(r: Node) -> bool: return r.in_match and r.house_match != ""),
			"the house never opened the match")
	if dealt != "":
		return dealt
	print("ranked room match %s" % host.house_match)
	var machines := []
	for room: Node in rooms:
		var machine: Net.Machine = _caller._sit(room)
		room.watch_match(machine.engine)
		machines.append(machine)
	for m: Net.Machine in machines:
		m.engine.run()
	var ended := await _until(func() -> bool: return machines.all(func(m: Net.Machine) -> bool: return m.done), "the match never ended")
	if ended != "":
		return ended
	print("over in %d turns, %s won" % [machines[0].engine.turn_count, machines[0].engine.winner.name if machines[0].engine.winner != null else "nobody"])
	var told := await _until(func() -> bool: return rooms.all(func(r: Node) -> bool: return not r.ranked_result.is_empty()),
			"the house never settled the match")
	if told != "":
		return told
	for room: Node in rooms:
		if not room.ranked_result.recorded or room.ranked_result.seats.size() != rooms.size():
			return "the house did not rate everyone: %s" % [room.ranked_result]
	print("ratings: %s" % [rooms[0].ranked_result.seats])
	var match_id: String = host.house_match
	for room: Node in rooms:
		room.leave()
	var board := await _call(HTTPClient.METHOD_GET, "/v1/standings?limit=200")
	var names: Array = board.data.players.map(func(p: Dictionary) -> String: return p.name) if board.ok else []
	for m: Dictionary in members:
		if not names.has(m.name):
			return "%s is not in the standings" % m.name
	if _logs != "":
		var file := _logs.path_join("logs").path_join(match_id + ".json")
		var log: Variant = JSON.parse_string(FileAccess.get_file_as_string(file))
		if not log is Dictionary:
			return "no file of the match at " + file
		if log.house.mode != "room" or log.events.is_empty() or log.snapshots.is_empty() or log.decisions.is_empty():
			return "the file of the match is missing things"
		if int(log.snapshots.back().turn) != machines[0].engine.turn_count:
			return "the last snapshot is not the end of the match"
		print("file: %d events, %d decisions, %d snapshots" % [log.events.size(), log.decisions.size(), log.snapshots.size()])
	return ""


func _machine(index: int, member: Dictionary) -> Node:
	var branch := Node.new()
	branch.name = "Member%d" % index
	add_child(branch)
	get_tree().set_multiplayer(SceneMultiplayer.new(), branch.get_path())
	var room: Node = Room.new()
	room.name = Room.NODE_NAME
	room.scenes = false
	room.house_name = member.name
	room.house_token = member.token
	branch.add_child(room)
	return room
