extends Node
## A room: the machines playing together, over ENet. One of them hosts it and
## the others join by its address (a LAN or a VPN such as Radmin). It has no
## class name: preload it.
##
## The room is a node hung on the root of the tree, at the same path on every
## machine, so it outlives the scenes: the lobby (setup.tscn), the match and
## the end screen all find it in `current`.
##
## In the lobby the host owns everything: who sits where, the bots and the
## rules. The others see each change as it is made. Everyone, the host
## included, may only rename themselves.
##
## A match is not played by the host and watched by the others: every machine
## runs the whole of it, from the same seed, and so they all reach the same
## decisions in the same order. The only thing that travels is the answer of a
## person to a decision (see HumanController). Each answer goes up to the host,
## which sends them all back down in one order for everybody, and a machine
## only acts on an answer once it comes back. Decisions are numbered as they
## are asked (a Ticket each), which is how an answer finds its decision on a
## machine that has not got that far yet.
##
## Someone who drops out of a match leaves their seat empty (`away`): it does
## nothing until the host has a bot play it or kicks them out of the match.
## Unless kicked, they may come back to it. Each person in a match gets a key
## of their own as it is dealt (`_keys`), which their machine keeps on disk
## (`_known_keys`) and shows when it joins again: that, and not the name, is
## how the host knows the seat is theirs (see _hello). The host keeps every
## answer it has handed out this match (`_history`), and the one coming back
## gets them all with the deal: their machine plays the whole match again from
## the start, without stopping for anything (`catching_up`), until it reaches
## a decision that is still open.

signal changed
## A player left in the middle of a match; the host answers for that seat.
signal seat_left(seat: int)
## The player of `seat` of the match came back; they answer for it again.
signal seat_back(seat: int)
## What becomes of the empty seat `seat` changed (see `away`).
signal away_changed(seat: int)
## This machine came back to a match and has played it up to where the others
## are: from here on it goes at the pace of the table (see `catching_up`).
signal caught_up
## The machines stopped agreeing about the match they are playing.
signal out_of_step(turn: int)
## The player at `seat` of the match sent an emote (see emotes.gd).
signal emoted(seat: int, kind: int)
## The player at `seat` of the match typed something to the table.
signal said(seat: int, text: String)

const Transition := preload("res://scripts/ui/transition.gd")
const PATH := "res://scripts/net/room.gd"
const SCREEN := "res://scenes/room.tscn"
const LOBBY := "res://scenes/setup.tscn"
const GAME := "res://scenes/main.tscn"
const PORT := 24565
## The room's name under the root. No scene may call its own root this.
const NODE_NAME := "NetRoom"
const MAX_SEATS := 8
const NAME_LENGTH := 12
## How long a line typed to the table may be (the same as Emotes.SAY_LENGTH).
const SAY_LENGTH := 60
## Bump when machines running different builds could no longer play together.
const PROTOCOL := 22
const JOIN_TIMEOUT := 8.0
## Where a machine keeps the keys of the seats it was dealt (see _known_keys).
const KEYS_PATH := "user://rejoin.cfg"
## How many of those it keeps, the latest ones.
const KEYS_KEPT := 8
const BOT_NAMES := ["Bones", "Pablo", "Miah", "Valentino", "Judson", "Vincent", "Dolores", "Ezekiel"]

## The room this machine is in, or null.
static var current: Node
## The keys of the seats this machine was dealt lately, latest last. They are
## kept on disk, so the game may even be closed and opened again before
## coming back. Several games open on one computer share them, which is what
## lets one of them take back the seat of another to try it out.
static var _known_keys: Array = []
static var _keys_loaded := false
## Why the last room ended, for the room screen to show once.
static var notice := ""

var hosting := false
## [{name: String, bot: bool, peer: int}]; peer is 0 for a bot.
var seats: Array = []
## The rules as the host has them set. They stay between matches.
var config: GameConfig
var in_match := false
## Seat -> peer of the match being played; 0 for a bot or for someone who left.
var match_peers: Array = []
## True while this machine, back in a match it had dropped out of, is playing
## again what the others have already played: the table shows none of it.
## It ends (`caught_up`) once every answer of the past has been used and the
## match waits for one that has not been given yet.
var catching_up := false
## The seats of the match whose player left, and what is done about each:
## &"idle" (nobody answers for it: the match waits on what it is asked),
## &"bot" (a bot plays it until they come back) or &"kick" (it is taken out of
## the match as the answer to what it is being asked, or to the next thing,
## and its player may not come back). Kept on every machine, for the table to
## show; only the host acts on it.
var away: Dictionary = {}
## Whether the room changes scenes on its own when the network says so. The
## tests, which have no scenes, turn it off.
var scenes := true

var _match_id := 0
var _joined := false
var _player_name := ""
var _address := ""
var _tickets: Dictionary = {}  # number -> Ticket still open
var _settled: Dictionary = {}  # number -> true
var _next_ticket := 0
var _inbox: Array = []  # [number, seat, wire], in the order the host gave them
var _sums: Dictionary = {}  # turn -> this machine's fingerprint of the match
var _reported: Dictionary = {}  # turn -> {peer: fingerprint}
var _split := false
## What the match was dealt (GameConfig.to_wire), for whoever comes back to it.
var _dealt: Dictionary = {}
## Host: every answer handed out this match, in order: [number, seat, wire].
var _history: Array = []
## Host: the key of each seat of the match, "" for its own seat and the bots'.
var _keys: Array = []
## How many of the answers in `_inbox` are from the past (see catching_up).
var _replay_left := 0


## One decision waiting for a person's answer.
class Ticket extends RefCounted:
	signal settled
	var number := 0
	var decision: Decision
	var controller: Controller
	var done := false
	var wire: Variant
	## Whether this machine has put it to whoever answers it here.
	var asked := false


# --- opening and leaving -----------------------------------------------------------

## Opens a room on this machine. Returns "" or what went wrong.
static func host(player_name: String) -> String:
	var peer := ENetMultiplayerPeer.new()
	# More than the table seats: whoever doesn't fit is told why and leaves.
	if peer.create_server(PORT, MAX_SEATS * 2) != OK:
		return Loc.t("Could not open a room: port %d is in use. Is the game already hosting one on this computer?") % PORT
	var room := _enter(peer)
	room.hosting = true
	room.config = GameConfig.new()
	room.seats = [{"name": clean_name(player_name), "bot": false, "peer": 1}]
	for i in 3:
		room.add_bot()
	return ""


## Starts joining the room at `address` ("host" or "host:port"). Returns ""
## or what went wrong at once; what goes wrong later ends in `notice`.
static func join(address: String, player_name: String) -> String:
	var where := address.strip_edges()
	var port := PORT
	if where.count(":") == 1 and where.get_slice(":", 1).is_valid_int():
		port = where.get_slice(":", 1).to_int()
		where = where.get_slice(":", 0)
	if where == "":
		return Loc.t("Type the address of the room.")
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(where, port) != OK:
		return Loc.t("Could not reach the room at %s.") % where
	var room := _enter(peer)
	room._player_name = clean_name(player_name)
	room._address = where
	room.get_tree().create_timer(JOIN_TIMEOUT).timeout.connect(room._on_join_timeout)
	return ""


static func _enter(peer: MultiplayerPeer) -> Node:
	if current != null:
		current.leave()
	var room: Node = load(PATH).new()
	var root := (Engine.get_main_loop() as SceneTree).root
	# Rpcs find the room by its path, so it has to be the same on every
	# machine. A clash (with a scene's root, or a room on its way out) would
	# get it a made-up name.
	if root.has_node(NODE_NAME):
		var old := root.get_node(NODE_NAME)
		root.remove_child(old)
		old.queue_free()
	room.name = NODE_NAME
	root.add_child(room)
	room.multiplayer.multiplayer_peer = peer
	current = room
	return room


## The IPv4 addresses the others may reach this machine by, VPN ones first.
static func addresses() -> Array:
	var out := []
	for address: String in IP.get_local_addresses():
		if address.contains(":") or address.begins_with("127.") or address.begins_with("169.254."):
			continue
		# Radmin VPN hands out 26.x.x.x.
		if address.begins_with("26."):
			out.push_front(address)
		else:
			out.append(address)
	return out


static func clean_name(text: String) -> String:
	return text.strip_edges().left(NAME_LENGTH)


func _ready() -> void:
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_fail.bind("Could not reach the room."))
	multiplayer.server_disconnected.connect(_fail.bind("The host closed the room."))


## Walks out of the room (closing it for everyone, if this machine hosts it).
## The scene is left to the caller.
func leave() -> void:
	release()
	if current == self:
		current = null
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	queue_free()


## The room is gone: back to the room screen, which says why.
func _fail(reason: String) -> void:
	if current != self:
		return
	notice = reason
	leave()
	_show(SCREEN, Transition.DESK)


func _on_join_timeout() -> void:
	if not _joined:
		_fail(Loc.t("Could not reach the room at %s.") % _address)


func _on_connected() -> void:
	_hello.rpc_id(1, _player_name, _build(), known_keys())


func _on_peer_disconnected(peer: int) -> void:
	if not hosting:
		return
	var seat := _seat_of(peer)
	if seat < 0:
		return
	seats.remove_at(seat)
	var played := match_peers.find(peer) if in_match else -1
	if played >= 0:
		_send(_seat_left, [_match_id, played])
		_seat_left(_match_id, played)
		# The seat waits for them, doing nothing, until the host says otherwise.
		_set_away(played, &"idle")
	_push()


## Takes this machine to another screen. A match still being played is cut
## at once: it must not go on running behind the transition.
func _show(scene: String, style: StringName) -> void:
	if not scenes:
		return
	var on := get_tree().current_scene
	Transition.go(scene, style, on != null and on.scene_file_path == GAME)


## What has to match for two machines to play the same match.
func _build() -> int:
	Content.ensure_loaded()
	# As text: StringNames don't sort the same way from one run to the next.
	var characters := Content.characters.keys().map(func(id: StringName) -> String: return String(id))
	var items := Content.items.keys().map(func(id: StringName) -> String: return String(id))
	characters.sort()
	items.sort()
	return str([PROTOCOL, characters, items]).hash()


# --- the lobby ---------------------------------------------------------------------

func my_peer() -> int:
	return multiplayer.get_unique_id()


func _seat_of(peer: int) -> int:
	for i in seats.size():
		if seats[i].peer == peer:
			return i
	return -1


## Renames a seat, which has to be one's own: not even the host writes the
## name of somebody else.
func rename(seat: int, text: String) -> void:
	if seat < 0 or seat >= seats.size() or seats[seat].bot or seats[seat].peer != my_peer():
		return
	if hosting:
		seats[seat].name = clean_name(text)
		_push()
	else:
		seats[seat].name = clean_name(text)
		_rename.rpc_id(1, text)


func add_bot() -> void:
	if not hosting or seats.size() >= MAX_SEATS:
		return
	var taken := seats.map(func(seat: Dictionary) -> String: return seat.name)
	var bot_name: String = BOT_NAMES[0]
	for candidate: String in BOT_NAMES:
		if not taken.has(candidate):
			bot_name = candidate
			break
	seats.append({"name": bot_name, "bot": true, "peer": 0})
	_push()


func remove_bot(seat: int) -> void:
	if hosting and seat >= 0 and seat < seats.size() and seats[seat].bot:
		seats.remove_at(seat)
		_push()


## The host changed `config` (or the seats): everyone gets to see it.
func push() -> void:
	if hosting:
		_push()


func _push() -> void:
	_send(_lobby, [{"seats": seats, "config": config.to_wire()}])
	changed.emit()


## Calls an rpc on every other machine that has a seat in the room.
func _send(method: Callable, arguments: Array) -> void:
	for seat: Dictionary in seats:
		if seat.peer > 1:
			callv(&"rpc_id", [seat.peer, method.get_method()] + arguments)


@rpc("any_peer", "call_remote", "reliable")
func _hello(player_name: String, build: int, keys: Array) -> void:
	if not hosting:
		return
	var peer := multiplayer.get_remote_sender_id()
	if _seat_of(peer) >= 0:
		return
	var bots := seats.filter(func(seat: Dictionary) -> bool: return seat.bot)
	var seat_name := clean_name(player_name)
	var why := ""
	if build != _build():
		why = "That room is running another version of the game."
	elif in_match:
		var back := _seat_with_key(keys)
		if back >= 0 and away.get(back) == &"kick":
			why = "You were removed from the match being played in that room. Try again when it ends."
		elif back >= 0:
			_take_back(peer, back)
			return
		else:
			why = "A match is being played in that room. Try again when it ends."
	elif seats.size() >= MAX_SEATS and bots.is_empty():
		why = "That room is full."
	if why != "":
		_refused.rpc_id(peer, why)
		return
	if seats.size() >= MAX_SEATS:
		seats.erase(bots.back())
	seats.append({"name": seat_name if seat_name != "" else "Player", "bot": false, "peer": peer})
	_push()


## Host: the empty seat of the match whose key is among `keys`, or -1.
func _seat_with_key(keys: Array) -> int:
	for i in mini(match_peers.size(), _keys.size()):
		if match_peers[i] == 0 and _keys[i] != "" and keys.has(_keys[i]):
			return i
	return -1


## Host: `peer` comes back to the seat they left. They get the deal and every
## answer given so far, before anything else of the match can reach them; from
## then on the answers go to them as to everyone else.
func _take_back(peer: int, seat: int) -> void:
	match_peers[seat] = peer
	away.erase(seat)
	_back.rpc_id(peer, _match_id, _dealt, match_peers, _history, away, {"seats": seats, "config": config.to_wire()})
	_send(_seat_back, [_match_id, seat, peer])
	_seat_back(_match_id, seat, peer)
	seats.append({"name": _dealt.seats[seat].name, "bot": false, "peer": peer})
	_push()


@rpc("authority", "call_remote", "reliable")
func _back(id: int, dealt: Dictionary, peers: Array, history: Array, empty: Dictionary, state: Dictionary) -> void:
	_joined = true
	seats = state.seats
	config = GameConfig.from_wire(state.config)
	_start_dealt(id, dealt, peers)
	away = empty.duplicate()
	_inbox = history.duplicate()
	_replay_left = _inbox.size()
	catching_up = true
	changed.emit()
	_show(GAME, Transition.DEAL)


@rpc("authority", "call_remote", "reliable")
func _seat_back(id: int, seat: int, peer: int) -> void:
	if id == _match_id and in_match and seat >= 0 and seat < match_peers.size():
		match_peers[seat] = peer
		away.erase(seat)
		seat_back.emit(seat)
		away_changed.emit(seat)


@rpc("authority", "call_remote", "reliable")
func _refused(why: String) -> void:
	_fail(why)


@rpc("any_peer", "call_remote", "reliable")
func _rename(text: String) -> void:
	var seat := _seat_of(multiplayer.get_remote_sender_id())
	if hosting and seat >= 0:
		seats[seat].name = clean_name(text)
		_push()


@rpc("authority", "call_remote", "reliable")
func _lobby(state: Dictionary) -> void:
	seats = state.seats
	config = GameConfig.from_wire(state.config)
	if not _joined:
		_joined = true
		_show(LOBBY, Transition.DESK)
	changed.emit()


# --- starting and ending a match ---------------------------------------------------

## Host: deals a match to everyone in the room, with the rules as they stand.
func start() -> void:
	if not hosting or seats.size() < 2:
		return
	var dealt := GameConfig.from_wire(config.to_wire())
	dealt.seats = []
	for i in seats.size():
		var seat: Dictionary = seats[i]
		dealt.seats.append({"name": seat.name if seat.name != "" else "Player %d" % (i + 1), "bot": seat.bot})
	# The seed is what makes every machine deal the same match.
	dealt.rng_seed = randi_range(1, 0x7fffffff)
	var peers := seats.map(func(seat: Dictionary) -> int: return seat.peer)
	# Each of the others gets a key to their seat, and nobody else sees it.
	var keys := []
	var crypto := Crypto.new()
	for peer: int in peers:
		keys.append(crypto.generate_random_bytes(16).hex_encode() if peer > 1 else "")
	for i in peers.size():
		if peers[i] > 1:
			_start.rpc_id(peers[i], _match_id + 1, dealt.to_wire(), peers, keys[i])
	_start(_match_id + 1, dealt.to_wire(), peers)
	_keys = keys


## Host: everyone leaves the match (played out or not) and goes back to the
## lobby.
func to_lobby() -> void:
	if not hosting:
		return
	_send(_to_lobby, [])
	_to_lobby()
	_push()


@rpc("authority", "call_remote", "reliable")
func _start(id: int, dealt: Dictionary, peers: Array, key := "") -> void:
	_start_dealt(id, dealt, peers)
	if key != "":
		remember_key(key)
	_show(GAME, Transition.DEAL)


func _start_dealt(id: int, dealt: Dictionary, peers: Array) -> void:
	_begin(id, peers, dealt)
	GameConfig.current = GameConfig.from_wire(dealt)


## A new match: nothing of the last one may leak into it.
func _begin(id: int, peers: Array, dealt: Dictionary = {}) -> void:
	release()
	_match_id = id
	in_match = true
	match_peers = peers
	_dealt = dealt
	_history.clear()
	_keys = []
	away = {}
	_replay_left = 0
	catching_up = false
	_tickets.clear()
	_settled.clear()
	_inbox.clear()
	_sums.clear()
	_reported.clear()
	_next_ticket = 0
	_split = false


@rpc("authority", "call_remote", "reliable")
func _to_lobby() -> void:
	in_match = false
	_show(LOBBY, Transition.GATHER)


@rpc("authority", "call_remote", "reliable")
func _seat_left(id: int, seat: int) -> void:
	if id == _match_id and in_match and seat >= 0 and seat < match_peers.size():
		match_peers[seat] = 0
		seat_left.emit(seat)


## Host: what becomes of the waiting seat `seat` (see `away`): &"bot" or
## &"kick". Neither can be taken back while they are away.
func set_away(seat: int, mode: StringName) -> void:
	if not hosting or not absent(seat) or away.get(seat) != &"idle" or not mode in [&"bot", &"kick"]:
		return
	_set_away(seat, mode)


func _set_away(seat: int, mode: StringName) -> void:
	_send(_away_down, [_match_id, seat, String(mode)])
	_away_down(_match_id, seat, String(mode))
	# Whatever it is being asked is answered the new way.
	for ticket: Ticket in _tickets.values():
		if ticket.decision.player.id == seat:
			ticket.controller.cover(ticket)


@rpc("authority", "call_remote", "reliable")
func _away_down(id: int, seat: int, mode: String) -> void:
	if id == _match_id and in_match and seat >= 0 and seat < match_peers.size():
		away[seat] = StringName(mode)
		away_changed.emit(seat)


## What is done about the empty seat `seat` (see `away`); &"" if it is not empty.
func away_mode(seat: int) -> StringName:
	return away.get(seat, &"") if absent(seat) else &""


## The keys of the seats this machine was dealt lately (see _known_keys).
static func known_keys() -> Array:
	if not _keys_loaded:
		_keys_loaded = true
		var file := ConfigFile.new()
		if file.load(KEYS_PATH) == OK:
			_known_keys = file.get_value("rejoin", "keys", [])
	return _known_keys


static func remember_key(key: String) -> void:
	var keys := known_keys()
	keys.erase(key)
	keys.append(key)
	while keys.size() > KEYS_KEPT:
		keys.pop_front()
	var file := ConfigFile.new()
	file.set_value("rejoin", "keys", keys)
	file.save(KEYS_PATH)


## The seat of the match that is played on this machine, or -1.
func my_match_seat() -> int:
	return match_peers.find(my_peer()) if in_match else -1


## True for a seat whose player left the match: the host plays it.
func absent(seat: int) -> bool:
	return in_match and seat >= 0 and seat < match_peers.size() and match_peers[seat] == 0


# --- decisions ---------------------------------------------------------------------

## Registers a decision the match needs from a person. Every machine opens
## the same decisions in the same order, so the numbers agree.
func open(decision: Decision, controller: Controller) -> Ticket:
	var ticket := Ticket.new()
	ticket.number = _next_ticket
	ticket.decision = decision
	ticket.controller = controller
	_next_ticket += 1
	_tickets[ticket.number] = ticket
	# The answer may have got here before the question.
	_deliver()
	_check_caught_up()
	return ticket


## Sends the answer this machine has for `ticket`. It only counts when it
## comes back from the host.
func submit(ticket: Ticket, wire: Variant) -> void:
	if ticket.done:
		return
	var seat: int = ticket.decision.player.id
	if hosting:
		_relay(ticket.number, seat, wire)
	else:
		_answer_up.rpc_id(1, _match_id, ticket.number, seat, wire)


## The match no longer wants an answer to `decision`.
func drop(decision: Decision) -> void:
	for ticket: Ticket in _tickets.values():
		if ticket.decision == decision:
			_settle(ticket, null)
			_deliver()
			return


## Lets go of every decision still waiting, so a match that was abandoned can
## unwind.
func release() -> void:
	_inbox.clear()
	_replay_left = 0
	catching_up = false
	for ticket: Ticket in _tickets.values():
		_settle(ticket, null)


func _settle(ticket: Ticket, wire: Variant) -> void:
	if ticket.done:
		return
	ticket.done = true
	ticket.wire = wire
	_tickets.erase(ticket.number)
	_settled[ticket.number] = true
	ticket.settled.emit()


@rpc("any_peer", "call_remote", "reliable")
func _answer_up(id: int, number: int, seat: int, wire: Variant) -> void:
	if not hosting or id != _match_id or not in_match:
		return
	if seat < 0 or seat >= match_peers.size() or match_peers[seat] != multiplayer.get_remote_sender_id():
		return
	_relay(number, seat, wire)


## Host: this answer is the next one, for every machine.
func _relay(number: int, seat: int, wire: Variant) -> void:
	_history.append([number, seat, wire])
	_send(_answer_down, [_match_id, number, seat, wire])
	_answer_down(_match_id, number, seat, wire)


@rpc("authority", "call_remote", "reliable")
func _answer_down(id: int, number: int, seat: int, wire: Variant) -> void:
	if id != _match_id:
		return
	_inbox.append([number, seat, wire])
	_deliver()


## Hands out the answers that arrived, strictly in the host's order: one for
## a decision this machine has not asked yet holds back the ones after it.
func _deliver() -> void:
	while not _inbox.is_empty():
		var number: int = _inbox[0][0]
		if _settled.has(number):
			# Too late: someone else's LIAR! closed it first, on every machine.
			_inbox.pop_front()
			_replay_left = maxi(_replay_left - 1, 0)
			continue
		var ticket: Ticket = _tickets.get(number)
		if ticket == null:
			break
		var answer: Array = _inbox.pop_front()
		_replay_left = maxi(_replay_left - 1, 0)
		if ticket.decision.player.id == answer[1]:
			_settle(ticket, answer[2])
	_check_caught_up()


## Back in a match, this machine has used up the answers of the past and the
## match is waiting for one that has not been given: it is where the others are.
func _check_caught_up() -> void:
	if catching_up and _replay_left == 0 and not _tickets.is_empty():
		catching_up = false
		caught_up.emit()
		# What is open was held back while replaying: now it is asked.
		for ticket: Ticket in _tickets.values():
			ticket.controller.cover(ticket)


# --- emotes ------------------------------------------------------------------------

## Shows everyone at the table an emote of the player at this machine. It is
## no part of the match: it goes round at once, whatever is being decided.
func emote(kind: int) -> void:
	var seat := my_match_seat()
	if seat < 0:
		return
	if hosting:
		_emote_relay(seat, kind)
	else:
		_emote_up.rpc_id(1, _match_id, kind)


@rpc("any_peer", "call_remote", "reliable")
func _emote_up(id: int, kind: int) -> void:
	if not hosting or id != _match_id or not in_match:
		return
	var seat := match_peers.find(multiplayer.get_remote_sender_id())
	if seat >= 0:
		_emote_relay(seat, kind)


func _emote_relay(seat: int, kind: int) -> void:
	_send(_emote_down, [_match_id, seat, kind])
	_emote_down(_match_id, seat, kind)


@rpc("authority", "call_remote", "reliable")
func _emote_down(id: int, seat: int, kind: int) -> void:
	if id == _match_id and in_match:
		emoted.emit(seat, kind)


# --- talk --------------------------------------------------------------------------

## Shows everyone at the table a line typed by the player at this machine.
## Like an emote, it is no part of the match and nothing of it is kept.
func say(text: String) -> void:
	var seat := my_match_seat()
	var line := _clean_line(text)
	if seat < 0 or line == "":
		return
	if hosting:
		_say_relay(seat, line)
	else:
		_say_up.rpc_id(1, _match_id, line)


@rpc("any_peer", "call_remote", "reliable")
func _say_up(id: int, text: String) -> void:
	if not hosting or id != _match_id or not in_match:
		return
	var seat := match_peers.find(multiplayer.get_remote_sender_id())
	var line := _clean_line(text)
	if seat >= 0 and line != "":
		_say_relay(seat, line)


func _say_relay(seat: int, text: String) -> void:
	_send(_say_down, [_match_id, seat, text])
	_say_down(_match_id, seat, text)


@rpc("authority", "call_remote", "reliable")
func _say_down(id: int, seat: int, text: String) -> void:
	if id == _match_id and in_match:
		said.emit(seat, _clean_line(text))


## A typed line as it may go round: one line, no longer than SAY_LENGTH.
func _clean_line(text: String) -> String:
	return text.replace("\n", " ").replace("\r", " ").replace("\t", " ").strip_edges().left(SAY_LENGTH)


# --- keeping in step ---------------------------------------------------------------

## What the match looks like on this machine as turn number `turn` begins.
## The host compares everyone's with its own.
func report(turn: int, fingerprint: int) -> void:
	if hosting:
		_sums[turn] = fingerprint
		_compare(turn)
	else:
		_report.rpc_id(1, _match_id, turn, fingerprint)


@rpc("any_peer", "call_remote", "reliable")
func _report(id: int, turn: int, fingerprint: int) -> void:
	if not hosting or id != _match_id:
		return
	if not _reported.has(turn):
		_reported[turn] = {}
	_reported[turn][multiplayer.get_remote_sender_id()] = fingerprint
	_compare(turn)


func _compare(turn: int) -> void:
	if _split or not _sums.has(turn):
		return
	for peer: int in _reported.get(turn, {}):
		if _reported[turn][peer] != _sums[turn]:
			_split = true
			_send(_out_of_step, [turn])
			_out_of_step(turn)
			return
	_reported.erase(turn)


@rpc("authority", "call_remote", "reliable")
func _out_of_step(turn: int) -> void:
	out_of_step.emit(turn)
