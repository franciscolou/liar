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
## rules. The others see each change as it is made and may only rename
## themselves.
##
## A match is not played by the host and watched by the others: every machine
## runs the whole of it, from the same seed, and so they all reach the same
## decisions in the same order. The only thing that travels is the answer of a
## person to a decision (see HumanController). Each answer goes up to the host,
## which sends them all back down in one order for everybody, and a machine
## only acts on an answer once it comes back. Decisions are numbered as they
## are asked (a Ticket each), which is how an answer finds its decision on a
## machine that has not got that far yet.

signal changed
## A player left in the middle of a match; the host answers for that seat.
signal seat_left(seat: int)
## The machines stopped agreeing about the match they are playing.
signal out_of_step(turn: int)

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
## Bump when machines running different builds could no longer play together.
const PROTOCOL := 10
const JOIN_TIMEOUT := 8.0
const BOT_NAMES := ["Bones", "Pablo", "Miah", "Valentino", "Judson", "Vincent", "Dolores", "Ezekiel"]

## The room this machine is in, or null.
static var current: Node
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


## One decision waiting for a person's answer.
class Ticket extends RefCounted:
	signal settled
	var number := 0
	var decision: Decision
	var controller: Controller
	var done := false
	var wire: Variant


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
	_show(SCREEN, Transition.KEYHOLE)


func _on_join_timeout() -> void:
	if not _joined:
		_fail(Loc.t("Could not reach the room at %s.") % _address)


func _on_connected() -> void:
	_hello.rpc_id(1, _player_name, _build())


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
		# What they were being asked is now the host's to answer.
		for ticket: Ticket in _tickets.values():
			if ticket.decision.player.id == played:
				ticket.controller.cover(ticket)
	_push()


## Takes this machine to another screen. A match still being played is cut
## at once: it must not go on running behind the transition.
func _show(scene: String, style: StringName) -> void:
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


## Renames a seat: one's own, or any of them for the host.
func rename(seat: int, text: String) -> void:
	if seat < 0 or seat >= seats.size():
		return
	if hosting:
		seats[seat].name = clean_name(text)
		_push()
	elif seats[seat].peer == my_peer():
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
func _hello(player_name: String, build: int) -> void:
	if not hosting:
		return
	var peer := multiplayer.get_remote_sender_id()
	if _seat_of(peer) >= 0:
		return
	var bots := seats.filter(func(seat: Dictionary) -> bool: return seat.bot)
	var why := ""
	if build != _build():
		why = "That room is running another version of the game."
	elif in_match:
		why = "A match is being played in that room. Try again when it ends."
	elif seats.size() >= MAX_SEATS and bots.is_empty():
		why = "That room is full."
	if why != "":
		_refused.rpc_id(peer, why)
		return
	if seats.size() >= MAX_SEATS:
		seats.erase(bots.back())
	var seat_name := clean_name(player_name)
	seats.append({"name": seat_name if seat_name != "" else "Player", "bot": false, "peer": peer})
	_push()


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
		_show(LOBBY, Transition.KEYHOLE)
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
	_send(_start, [_match_id + 1, dealt.to_wire(), peers])
	_start(_match_id + 1, dealt.to_wire(), peers)


## Host: everyone leaves the match (played out or not) and goes back to the
## lobby.
func to_lobby() -> void:
	if not hosting:
		return
	_send(_to_lobby, [])
	_to_lobby()
	_push()


@rpc("authority", "call_remote", "reliable")
func _start(id: int, dealt: Dictionary, peers: Array) -> void:
	_begin(id, peers)
	GameConfig.current = GameConfig.from_wire(dealt)
	_show(GAME, Transition.DEAL)


## A new match: nothing of the last one may leak into it.
func _begin(id: int, peers: Array) -> void:
	release()
	_match_id = id
	in_match = true
	match_peers = peers
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
			continue
		var ticket: Ticket = _tickets.get(number)
		if ticket == null:
			return
		var answer: Array = _inbox.pop_front()
		if ticket.decision.player.id == answer[1]:
			_settle(ticket, answer[2])


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
