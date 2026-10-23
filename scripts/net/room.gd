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
## of their own as it is dealt, which their machine keeps on disk
## (`_known_keys`) and shows when it joins again: that, and not the name, is
## how the host knows the seat is theirs (see _hello; every machine has the
## hashes of the keys, `_key_hashes`). Every machine keeps each answer handed
## out this match (`_history`), and the one coming back gets them all from the
## host with the deal: their machine plays the whole match again from
## the start, without stopping for anything (`catching_up`), until it reaches
## a decision that is still open.
##
## A host who leaves does not end the room: it passes to one of the others.
## Every guest listens on a port of its own from the lobby on (`_probe`), and
## the machines send each other a packet there now and then: the host ranks
## the guests by who got through to them and tells everyone (`_succession`).
## When the host is gone, every machine walks that list in the same order:
## the first one on it opens the room on its port (`_take_over`), the others
## join it (`_resume`), each with a token of its own (`_token`, whose hash the
## seat carries as its `mark`) to be known by. Every machine keeps the answers
## it got (`_history`), and those it sent that never came back (`_sent`): the
## new host takes the longest history there is, hands the rest of it to whoever
## is behind, and only then sends on the answers that were lost on the way and
## any new ones. Whoever does not come back in time (`HANDOVER_GRACE`) has
## left, as if they had dropped out, and the old host's seat waits for them.
##
## Someone who joins while a match is being played (and holds no key to a seat
## of it) asks to watch it (`asking`): the host lets them in or sends them away.
## A watcher gets the match the way someone coming back does, and then every
## answer, but sits nowhere and answers nothing (`watchers`, `watching`). Back
## in the lobby they get a seat like anyone joining. A watcher does not take
## the room over: if the host leaves, so do they.
##
## A ranked match is played in a room of the house (server/ and
## match_server.gd): there the host is the house's own process, `dedicated`,
## which sits nowhere and plays no part but the host's. Its seats were dealt
## before anyone joined, one to each member the queue put at the table, each
## with the hash of its ticket as its `key`; a member's machine (`ranked`)
## joins with the ticket among its keys (see join_ranked) and takes the seat
## it opens. Once every seat is taken, or after a while, the house deals: the
## match is the same lockstep match as anywhere else. A seat whose player
## drops out of it waits for them `away_seconds`, and then a bot plays it
## until they come back. The room never passes to anyone: it is the house's.
##
## A room of friends may be ranked too (`rated`, the host's switch in the
## lobby): every seat a member of the house, played by the house's rules, no
## bots. Dealing it asks the house for a match first (`_start_rated`, the
## house's rooms.py), whose id goes out with the deal (`house_match`); from
## there it is a room like any other, and each member's machine tells the
## house it is at the table and, at the end, how it ended (house_report.gd).
## Each seat says who it is at the house (`member`), as its machine told the
## host (`_member_up`).

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
## The host left: the room is trying to pass to `heir` (the player's name),
## who may be this machine (`mine`). Once for each one it tries.
signal passing(heir: String, mine: bool)
## The room is back, with another host (which may be this machine).
signal host_changed
## Whether the others could get through to this machine, so that it could take
## the room over (see `reachable`). Only said when someone on another computer
## tried.
signal reach_checked(ok: bool)
## Host: `peer`, named `who`, asks to watch the match (see `asking`).
signal watch_asked(peer: int, who: String)
## Host: the request of `peer` to watch was answered, or they left.
signal watch_settled(peer: int)
## `who` came to watch the match (`on`), or stopped watching it.
signal watcher(who: String, on: bool)
## Guest: the room has a match on, and its host was asked to let this machine
## watch it.
signal watch_pending
## Ranked: the house said how the match ended for everyone, with the new
## ratings (see ranked_result).
signal ranked_over(result: Dictionary)
## Dedicated: the player of `seat` sat down at the table before the deal.
signal arrived(seat: int)
## Host of a ranked room: what the house said, or what is missing, while the
## room was turned ranked or dealt ("" once it is all right).
signal rated_note(text: String)
signal _tail_came

const Transition := preload("res://scripts/ui/transition.gd")
const RankedApi := preload("res://scripts/net/ranked_api.gd")
const HouseReport := preload("res://scripts/net/house_report.gd")
const PATH := "res://scripts/net/room.gd"
const SCREEN := "res://scenes/room.tscn"
const RANKED_SCREEN := "res://scenes/ranked.tscn"
const LOBBY := "res://scenes/setup.tscn"
const GAME := "res://scenes/main.tscn"
const PORT := 24565
## A second room on the same computer takes the next free port, up to this
## many of them: PORT, PORT + 1, ...
const PORT_RANGE := 8
## The room's name under the root. No scene may call its own root this.
const NODE_NAME := "NetRoom"
const MAX_SEATS := 8
const NAME_LENGTH := 12
## How long a line typed to the table may be (the same as Emotes.SAY_LENGTH).
const SAY_LENGTH := 60
## Bump when machines running different builds could no longer play together.
const PROTOCOL := 43
const JOIN_TIMEOUT := 8.0
## Joining a table of the house: its process may still be starting.
const RANKED_JOIN_TIMEOUT := 20.0
## Joining with no port given: how long each port of the range is tried, past
## the first, before the next one (the room may have passed to someone who
## opened it on another, see _take_over).
const SCAN_TIMEOUT := 1.5
## How long a machine tries each heir on the list before the next one.
const HANDOVER_TIMEOUT := 8.0
## How long the new host waits for the others to come back to it.
const HANDOVER_GRACE := 14.0
## Each test packet is sent this many times, this far apart: UDP may lose some.
const PROBE_TIMES := 3
const PROBE_GAP := 0.4
## How long after a guest starts listening the host says whether anyone got
## through to it.
const PROBE_VERDICT := 4.0
const PROBE_TAG := "LIAR?"
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
## Host: the UDP port the room listens on (PORT, unless another room on this
## computer has it).
var port := PORT
## The host left and this machine is looking for the one taking the room over.
var handing_over := false
## False once the others tried and could not get through to this machine: if
## the host leaves, the room cannot pass to it (most likely a firewall).
var reachable := true
## [{name: String, bot: bool, peer: int, member: String}]; peer is 0 for a
## bot, member is the name at the house of whoever sits there ("" for none).
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
## Host: who asked to watch the match being played and waits for an answer,
## and who watches it: peer -> {name, mark}.
var asking: Dictionary = {}
var watchers: Dictionary = {}
## This machine watches the match being played, without a seat in it.
var watching := false
## Whether the room changes scenes on its own when the network says so. The
## tests, which have no scenes, turn it off.
var scenes := true
## This room is the house's (see the top): `dedicated` on its own process,
## `ranked` on a member's machine.
var dedicated := false
var ranked := false
## Dedicated: how long the seat of someone who dropped out waits before a bot
## plays it.
var away_seconds := 60.0
## Ranked: what the house said when the match ended: {seats: [{seat, place,
## before, after, delta}]} (see ranked_over). Empty until then.
var ranked_result: Dictionary = {}
## Ranked: the key to this member's seat, given by the queue. It is the only
## key shown to the house: the others this machine keeps are for rooms of
## friends (and two games on one computer would show each other's).
var ticket := ""
## The room is ranked (see the top): the host's switch in the lobby.
var rated := false
## The house's id of the ranked match being played in this room, or "".
var house_match := ""
## Who this machine is at the house: the member signed in on it, unless a
## test gives another one (several members in one process).
var house_name := ""
var house_token := ""
## Host: asking the house for a ranked match, between the press and the deal.
var _asking_house := false

var _match_id := 0
var _joined := false
var _player_name := ""
var _address := ""
## Joining: the port being tried, whether the next ones are tried if nobody
## answers there, and a number for each try.
var _knocking := PORT
var _scanning := false
var _try := 0
## Guest: where this machine reached the room ("address" or "address:port"):
## kept as the last address when it walks out, the room may have moved.
var _where := ""
## Guest: the host was asked to let this machine watch: no hurry to get in.
var _waiting := false
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
## The hash of the key of each seat of the match, "" for the bots'. Every
## machine has them, so that whoever takes the room over knows them too.
var _key_hashes: Array = []
## What this machine is known by in the room; its seat carries the hash.
var _token := ""
## The room's own number, for the test packets and for finding the same room
## again after its host left.
var _nonce := 0
## This machine's peer in the room; it is changed by a handover.
var _me := 0
## Guest: answers this machine sent that have not come back yet: number ->
## [seat, wire]. They are sent again to a new host.
var _sent: Dictionary = {}
## Guest: where this machine listens for the test packets, and on which port.
var _probe: PacketPeerUDP
var _probe_port := 0
## Whether the host still has to be told where this machine listens.
var _unannounced := true
## Host: peer -> {port, addresses} of where each guest listens.
var _listen: Dictionary = {}
## Host: peer -> {peer that got through: index of the address it used}.
var _reach: Dictionary = {}
## Host: the guests told nobody got through to them.
var _warned: Dictionary = {}
## Who takes the room over, in order: [{peer, name, port, addresses, reach}],
## and peer -> the computer each guest is on (the same text for the same one).
var _succession: Array = []
var _machines: Dictionary = {}
## Walking the list after the host left: where this machine is on it, and a
## number for each try (a timer of a try given up on does nothing).
var _walk: Array = []
var _step := -1
var _attempt := 0
## New host: waiting for the others (`_pending`: mark -> peer they had), what
## each one that came back had (`_resumes`), answers held back meanwhile.
var _taking_over := false
var _pending: Dictionary = {}
var _resumes: Dictionary = {}
var _held: Array = []
var _renamed: Dictionary = {}  # peer before the handover -> peer after it
var _take_over_id := 0
var _reconciling := false
## Vector2i(number, seat) of every answer handed out this match: the same one
## coming twice (sent again to a new host) is only passed on once.
var _given: Dictionary = {}
## This machine is walking out: the connection closing is no reason to look
## for another host.
var _leaving := false
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
	## When it was opened (Time.get_ticks_msec), for the house's patience.
	var opened := 0


# --- opening and leaving -----------------------------------------------------------

## Opens a room on this machine. Returns "" or what went wrong.
static func host(player_name: String) -> String:
	var peer: ENetMultiplayerPeer
	var at := PORT
	while true:
		peer = ENetMultiplayerPeer.new()
		# More than the table seats: whoever doesn't fit is told why and leaves.
		if peer.create_server(at, MAX_SEATS * 2) == OK:
			break
		at += 1
		if at >= PORT + PORT_RANGE:
			return Loc.t("Could not open a room: ports %d to %d are all in use on this computer.") % [PORT, PORT + PORT_RANGE - 1]
	var room := _enter(peer)
	room.hosted(player_name, at)
	return ""


## This machine has just opened the room on `at`, with `bots` bots seated.
func hosted(player_name: String, at: int, bots := 3) -> void:
	hosting = true
	port = at
	_me = 1
	_player_name = clean_name(player_name)
	_nonce = randi_range(1, 0x7fffffff)
	config = GameConfig.new()
	seats = [{"name": _player_name, "bot": false, "peer": 1, "mark": _mark(), "member": _member()}]
	for i in bots:
		add_bot()


## Starts joining the room at `address` ("host" or "host:port"). Returns ""
## or what went wrong at once; what goes wrong later ends in `notice`.
static func join(address: String, player_name: String) -> String:
	var where := address.strip_edges()
	var port := PORT
	var scanning := true
	if where.count(":") == 1 and where.get_slice(":", 1).is_valid_int():
		port = where.get_slice(":", 1).to_int()
		where = where.get_slice(":", 0)
		scanning = false
	if where == "":
		return Loc.t("Type the address of the room.")
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(where, port) != OK:
		return Loc.t("Could not reach the room at %s.") % where
	var room := _enter(peer)
	room._player_name = clean_name(player_name)
	room._address = where
	room._knocking = port
	room._scanning = scanning
	room._wait_at_door()
	return ""


## Dedicated: opens the room of a ranked table on `at`, its seats dealt to
## `players` ([{name, ticket_hash}]) and nobody in them yet. Returns "" or
## what went wrong.
static func serve(at: int, players: Array) -> String:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(at, MAX_SEATS * 2) != OK:
		return "port %d is taken" % at
	_enter(peer).served(at, players)
	return ""


## This machine has just opened the house's room on `at` (see serve).
func served(at: int, players: Array) -> void:
	hosting = true
	dedicated = true
	port = at
	_me = 1
	_nonce = randi_range(1, 0x7fffffff)
	config = GameConfig.new()
	seats = []
	for player: Dictionary in players:
		seats.append({"name": clean_name(str(player.name)), "bot": false, "peer": 0, "mark": "", "key": str(player.ticket_hash)})


## Ranked: joins the table the house dealt this member, at `address`:`at`,
## with the ticket of their seat. Like `join`, returns "" or what went wrong
## at once; what goes wrong later ends in `notice`, on the ranked screen.
static func join_ranked(address: String, at: int, ticket: String, player_name: String) -> String:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(address, at) != OK:
		return Loc.t("Could not reach the house.")
	var room := _enter(peer)
	room.ranked = true
	room.ticket = ticket
	room._player_name = clean_name(player_name)
	room._address = address
	room._knocking = at
	room._scanning = false
	room._wait_at_door()
	return ""


## Dedicated: whether everyone dealt a seat has sat down.
func all_seated() -> bool:
	return seats.all(func(seat: Dictionary) -> bool: return seat.peer > 1)


func _wait_at_door() -> void:
	_try += 1
	var patience := SCAN_TIMEOUT if _scanning and _knocking != PORT else (RANKED_JOIN_TIMEOUT if ranked else JOIN_TIMEOUT)
	get_tree().create_timer(patience).timeout.connect(_on_join_timeout.bind(_try))


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


## What the others type to reach this room at `ip`: the port only shows when
## it is not the usual one.
func address_at(ip: String) -> String:
	return ip if port == PORT else "%s:%d" % [ip, port]


static func clean_name(text: String) -> String:
	return text.strip_edges().left(NAME_LENGTH)


## Whether `text` is the name of some seat other than `seat` (-1: any) in the
## room, as names go: no matter the capitals or the spaces round it.
func name_taken(seat: int, text: String) -> bool:
	var wanted := clean_name(text).to_lower()
	if wanted == "":
		return false
	for i: int in seats.size():
		if i != seat and String(seats[i].name).strip_edges().to_lower() == wanted:
			return true
	return false


## `text`, or the first of "text 2", "text 3"... nobody in the room has.
func _free_name(text: String) -> String:
	var free := text
	var n := 2
	while name_taken(-1, free):
		var number := " %d" % n
		free = text.left(NAME_LENGTH - number.length()) + number
		n += 1
	return free


func _ready() -> void:
	_token = Crypto.new().generate_random_bytes(16).hex_encode()
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_host_gone)


func _notification(what: int) -> void:
	# The window is closing: the others are told at once, instead of finding
	# out when the connection times out.
	if what == NOTIFICATION_WM_CLOSE_REQUEST and multiplayer.multiplayer_peer != null:
		_leaving = true
		multiplayer.multiplayer_peer.close()


## Walks out of the room. If this machine hosts it, it passes to one of the
## others. The scene is left to the caller.
func leave() -> void:
	_leaving = true
	_keep_address()
	release()
	if current == self:
		current = null
	_close_probe()
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	queue_free()


## The address this machine would come back to the room by is kept as the last
## one, for the room screen: the room may have moved since it was typed (it
## passed to someone else, or is about to, as this host walks out).
func _keep_address() -> void:
	if current != self or ranked:
		return
	var back := _where
	if hosting:
		var heirs := _succession.filter(func(entry: Dictionary) -> bool: return entry.peer > 1)
		if heirs.is_empty():
			return
		var heir: Dictionary = heirs[0]
		var ip: String = "127.0.0.1" if _machine_of(heir.peer) == "" else heir.addresses[0]
		back = ip if heir.port == PORT else "%s:%d" % [ip, heir.port]
	if back == "":
		return
	Settings.last_address = back
	Settings.save()


## The room is gone: back to the room screen, which says why.
func _fail(reason: String) -> void:
	if current != self:
		return
	notice = reason
	var back := RANKED_SCREEN if ranked else SCREEN
	leave()
	_show(back, Transition.DESK)


func _on_join_timeout(attempt: int) -> void:
	if not _joined and not _waiting and not handing_over and attempt == _try:
		_knock_next()


## Nobody answered at the port being tried: the next one of the range, if the
## player gave none, or the room is not there.
func _knock_next() -> void:
	if _scanning and multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		while _knocking + 1 < PORT + PORT_RANGE:
			_knocking += 1
			var link := ENetMultiplayerPeer.new()
			if link.create_client(_address, _knocking) == OK:
				_swap_link(link)
				_wait_at_door()
				return
	_fail(Loc.t("Could not reach the room at %s.") % _address)


func _on_connected() -> void:
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return
	_me = my_peer()
	_unannounced = true
	if not handing_over:
		# Someone is there: no more ports to try, and the time to get in starts.
		_scanning = false
		_where = _address if _knocking == PORT else "%s:%d" % [_address, _knocking]
		_wait_at_door()
	if handing_over:
		_resume.rpc_id(1, _nonce, _token, _player_name, _build(), known_keys(), _history.size(), _sent.duplicate())
	else:
		_hello.rpc_id(1, _player_name, _build(), [ticket] if ranked else known_keys(), _mark())


func _on_connection_failed() -> void:
	if handing_over:
		_next_heir()
	elif not _joined:
		_knock_next()
	else:
		_fail("Could not reach the room.")


func _on_peer_disconnected(peer: int) -> void:
	if not hosting:
		return
	_listen.erase(peer)
	_reach.erase(peer)
	_warned.erase(peer)
	if _resumes.has(peer):
		# It was to hand over the answers it had: there are none to wait for.
		_resumes.erase(peer)
		_tail_came.emit()
	if asking.erase(peer):
		watch_settled.emit(peer)
		return
	if watchers.has(peer):
		var who: String = watchers[peer].name
		watchers.erase(peer)
		_send(_watcher_down, [who, false])
		_watcher_down(who, false)
		return
	var seat := _seat_of(peer)
	if seat < 0:
		return
	if dedicated and not in_match:
		# The seat was dealt to them: it stays theirs until the deal.
		seats[seat].peer = 0
		_push()
		return
	seats.remove_at(seat)
	var played := match_peers.find(peer) if in_match else -1
	if played >= 0:
		_send(_seat_left, [_match_id, played])
		_seat_left(_match_id, played)
		# The seat waits for them, doing nothing, until the host says otherwise.
		_set_away(played, &"idle")
		if dedicated:
			_bench_later(played)
	_push()
	_rank()


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
## name of somebody else. A name somebody else has already is not taken: who
## had it first keeps it (see name_taken).
func rename(seat: int, text: String) -> void:
	if seat < 0 or seat >= seats.size() or seats[seat].bot or seats[seat].peer != my_peer():
		return
	if rated and seats[seat].get("member", "") != "":
		return
	if name_taken(seat, text):
		return
	if hosting:
		seats[seat].name = clean_name(text)
		_push()
	else:
		seats[seat].name = clean_name(text)
		_rename.rpc_id(1, text)


func add_bot() -> void:
	if not hosting or seats.size() >= MAX_SEATS or rated:
		return
	var taken := seats.map(func(seat: Dictionary) -> String: return seat.name)
	var bot_name: String = BOT_NAMES[0]
	for candidate: String in BOT_NAMES:
		if not taken.has(candidate):
			bot_name = candidate
			break
	seats.append({"name": bot_name, "bot": true, "peer": 0})
	_push()


## Host, in the lobby: takes a seat out of the room, a bot or a guest (who is
## sent back to the room screen, told why). The host's own seat stays.
func remove_seat(seat: int) -> void:
	if not hosting or in_match or seat < 0 or seat >= seats.size():
		return
	var peer: int = seats[seat].peer
	if not seats[seat].bot and peer <= 1:
		return
	seats.remove_at(seat)
	if peer > 1:
		_refused.rpc_id(peer, "The host removed you from the room.")
	_push()


## The host changed `config` (or the seats): everyone gets to see it.
func push() -> void:
	if hosting:
		_push()


func _push() -> void:
	_send(_lobby, [_state()])
	changed.emit()


## Calls an rpc on every other machine that has a seat in the room, or
## watches the match.
func _send(method: Callable, arguments: Array) -> void:
	for seat: Dictionary in seats:
		if seat.peer > 1:
			callv(&"rpc_id", [seat.peer, method.get_method()] + arguments)
	for peer: int in watchers:
		callv(&"rpc_id", [peer, method.get_method()] + arguments)


@rpc("any_peer", "call_remote", "reliable")
func _hello(player_name: String, build: int, keys: Array, mark: String) -> void:
	if hosting:
		_greet(multiplayer.get_remote_sender_id(), player_name, build, keys, mark)


## Host: `peer` asks to come in.
func _greet(peer: int, player_name: String, build: int, keys: Array, mark: String) -> void:
	if _seat_of(peer) >= 0 or asking.has(peer) or watchers.has(peer):
		return
	var seat_name := clean_name(player_name)
	if seat_name == "":
		seat_name = "Player"
	if build != _build():
		_refused.rpc_id(peer, "That room is running another version of the game.")
		return
	if dedicated and not in_match:
		var dealt := _dealt_seat(keys)
		if dealt < 0:
			_refused.rpc_id(peer, "That table was dealt to other players.")
			return
		seats[dealt].peer = peer
		seats[dealt].mark = mark
		_push()
		arrived.emit(dealt)
		return
	if dedicated and _seat_with_key(keys) < 0:
		_refused.rpc_id(peer, "Ranked matches cannot be watched.")
		return
	if in_match:
		var back := _seat_with_key(keys)
		if back >= 0 and away.get(back) == &"kick":
			_refused.rpc_id(peer, "You were removed from the match being played in that room. Try again when it ends.")
		elif back >= 0:
			_take_back(peer, back, mark)
		else:
			# No seat of theirs in it: they may watch it, if the host says so.
			asking[peer] = {"name": seat_name, "mark": mark}
			_watch_wait.rpc_id(peer)
			watch_asked.emit(peer, seat_name)
		return
	if _sit(peer, seat_name, mark):
		_push()


## Host: seats `peer` in the lobby, in the place of a bot if the room is full.
## Returns false, and sends them away, if there is no place for them.
func _sit(peer: int, seat_name: String, mark: String) -> bool:
	var bots := seats.filter(func(seat: Dictionary) -> bool: return seat.bot)
	if seats.size() >= MAX_SEATS and bots.is_empty():
		_refused.rpc_id(peer, "That room is full.")
		return false
	if seats.size() >= MAX_SEATS:
		seats.erase(bots.back())
	# Somebody here has the name already: they keep it, the newcomer gets a number.
	seats.append({"name": _free_name(seat_name), "bot": false, "peer": peer, "mark": mark, "member": ""})
	return true


## Dedicated, before the deal: the seat whose ticket is among `keys`, or -1.
func _dealt_seat(keys: Array) -> int:
	var hashes := keys.filter(func(key: Variant) -> bool: return key is String).map(_hash)
	var taken := -1
	for i in seats.size():
		if seats[i].get("key", "") != "" and hashes.has(seats[i].key):
			if seats[i].peer == 0:
				return i
			# Theirs, from a connection that is on its way out.
			taken = i
	return taken


## Dedicated: a seat left empty in the match is played by a bot once its
## player has been away for `away_seconds` (they may still come back to it).
func _bench_later(seat: int) -> void:
	var id := _match_id
	get_tree().create_timer(away_seconds).timeout.connect(func() -> void:
		if id == _match_id and absent(seat) and away.get(seat) == &"idle":
			_set_away(seat, &"bot"))


## Host: the empty seat of the match whose key is among `keys`, or -1.
func _seat_with_key(keys: Array) -> int:
	var hashes := keys.filter(func(key: Variant) -> bool: return key is String).map(_hash)
	for i in mini(match_peers.size(), _key_hashes.size()):
		if match_peers[i] == 0 and _key_hashes[i] != "" and hashes.has(_key_hashes[i]):
			return i
	return -1


static func _hash(text: String) -> String:
	return text.sha256_text()


## What this machine's seat carries to be known by.
func _mark() -> String:
	return _hash(_token)


## What everyone in the room is sent of it: the seats and the rules.
func _state() -> Dictionary:
	return {"seats": seats, "config": config.to_wire(), "nonce": _nonce, "rated": rated}


## Host: `peer` comes back to the seat they left. They get the deal and every
## answer given so far, before anything else of the match can reach them; from
## then on the answers go to them as to everyone else.
func _take_back(peer: int, seat: int, mark: String) -> void:
	match_peers[seat] = peer
	away.erase(seat)
	var state := _state()
	state.hashes = _key_hashes
	_back.rpc_id(peer, _match_id, _dealt, match_peers, _history, away, state)
	_send(_seat_back, [_match_id, seat, peer])
	_seat_back(_match_id, seat, peer)
	seats.append({"name": _dealt.seats[seat].name, "bot": false, "peer": peer, "mark": mark})
	_push()


@rpc("authority", "call_remote", "reliable")
func _back(id: int, dealt: Dictionary, peers: Array, history: Array, empty: Dictionary, state: Dictionary) -> void:
	_catch_up(id, dealt, peers, history, empty, state)


## Takes this machine into the match being played, which it plays again from
## the deal through every answer given so far (see catching_up).
func _catch_up(id: int, dealt: Dictionary, peers: Array, history: Array, empty: Dictionary, state: Dictionary) -> void:
	_joined = true
	_waiting = false
	handing_over = false
	seats = state.seats
	config = GameConfig.from_wire(state.config)
	_nonce = state.nonce
	_start_dealt(id, dealt, peers)
	_key_hashes = state.hashes
	away = empty.duplicate()
	_history = history.duplicate()
	for entry: Array in _history:
		_given[Vector2i(entry[0], entry[1])] = true
	_inbox = history.duplicate()
	_replay_left = _inbox.size()
	catching_up = true
	changed.emit()
	_announce()
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


## Guest: the room has a match on, and the host is asked to let this machine
## watch it. It waits for as long as the host takes.
@rpc("authority", "call_remote", "reliable")
func _watch_wait() -> void:
	_waiting = true
	watch_pending.emit()


## Host: lets `peer`, who asked, watch the match (`yes`), or sends them away.
func let_watch(peer: int, yes: bool) -> void:
	if not hosting or not asking.has(peer):
		return
	var who: Dictionary = asking[peer]
	asking.erase(peer)
	watch_settled.emit(peer)
	if not yes or not in_match:
		_refused.rpc_id(peer, "The host did not let you watch the match.")
		return
	watchers[peer] = who
	var state := _state()
	state.hashes = _key_hashes
	# Before any answer that comes after: the rpcs keep their order.
	_watch.rpc_id(peer, _match_id, _dealt, match_peers, _history, away, state)
	_send(_watcher_down, [who.name, true])
	_watcher_down(who.name, true)


@rpc("authority", "call_remote", "reliable")
func _watch(id: int, dealt: Dictionary, peers: Array, history: Array, empty: Dictionary, state: Dictionary) -> void:
	watching = true
	_catch_up(id, dealt, peers, history, empty, state)


@rpc("authority", "call_remote", "reliable")
func _watcher_down(who: String, on: bool) -> void:
	watcher.emit(who, on)


@rpc("any_peer", "call_remote", "reliable")
func _rename(text: String) -> void:
	var from := _seat_of(multiplayer.get_remote_sender_id())
	if dedicated or (rated and from >= 0 and seats[from].get("member", "") != ""):
		# The names at a ranked table are the members'.
		_push()
		return
	var seat := _seat_of(multiplayer.get_remote_sender_id())
	if hosting and seat >= 0 and name_taken(seat, text):
		# Somebody got there first: the room tells them their name as it is.
		_push()
		return
	if hosting and seat >= 0:
		seats[seat].name = clean_name(text)
		_push()


@rpc("authority", "call_remote", "reliable")
func _lobby(state: Dictionary) -> void:
	seats = state.seats
	config = GameConfig.from_wire(state.config)
	_nonce = state.nonce
	rated = state.get("rated", false)
	if handing_over:
		# Back in the room too late to be waited for: let in again instead.
		handing_over = false
		host_changed.emit()
	if not _joined:
		_joined = true
		_waiting = false
		# At the house there is no lobby: the ranked screen waits for the deal.
		if not ranked:
			_show(LOBBY, Transition.DESK)
			# Who this machine is at the house, for a ranked room.
			_member_up.rpc_id(1, _member())
	changed.emit()
	_announce()


# --- starting and ending a match ---------------------------------------------------

## Host: deals a match to everyone in the room, with the rules as they stand.
func start() -> void:
	if not hosting or seats.size() < 2:
		return
	if dedicated:
		_deal_ranked()
		return
	if rated:
		_start_rated()
		return
	_deal()


## Host: deals the match; `house_match` is the house's id of it, if ranked.
func _deal(house_id := "") -> void:
	var dealt := GameConfig.from_wire(config.to_wire())
	dealt.seats = []
	for i in seats.size():
		var seat: Dictionary = seats[i]
		dealt.seats.append({"name": seat.name if seat.name != "" else "Player %d" % (i + 1), "bot": seat.bot})
	# The seed is what makes every machine deal the same match.
	dealt.rng_seed = randi_range(1, 0x7fffffff)
	var wire := dealt.to_wire()
	if house_id != "":
		wire["house_match"] = house_id
	var peers := seats.map(func(seat: Dictionary) -> int: return seat.peer)
	# Each person gets a key to their seat, the host too (the room may pass to
	# someone else, and they may want to come back), and nobody else sees it:
	# everyone gets only the hashes.
	var keys := []
	var crypto := Crypto.new()
	for peer: int in peers:
		keys.append(crypto.generate_random_bytes(16).hex_encode() if peer >= 1 else "")
	var hashes := keys.map(func(key: String) -> String: return _hash(key) if key != "" else "")
	for i in peers.size():
		if peers[i] > 1:
			_start.rpc_id(peers[i], _match_id + 1, wire, peers, keys[i], hashes)
	# Whoever watched the last match watches this one.
	for peer: int in watchers:
		_start.rpc_id(peer, _match_id + 1, wire, peers, "", hashes)
	_start(_match_id + 1, wire, peers, keys[peers.find(1)], hashes)


# --- ranked rooms ------------------------------------------------------------------

## Who this machine is at the house: its member's name, or "" if it is not
## signed in; and the token it signs in with.
func _member() -> String:
	if house_name != "":
		return house_name
	return Settings.ranked_name if RankedApi.signed_in() else ""


func member_token() -> String:
	return house_token if house_token != "" else Settings.ranked_token


@rpc("any_peer", "call_remote", "reliable")
func _member_up(member: String) -> void:
	var seat := _seat_of(multiplayer.get_remote_sender_id())
	if not hosting or seat < 0 or seats[seat].bot:
		return
	seats[seat].member = clean_name(member) if member.length() <= 64 else ""
	if rated:
		_name_members()
	_push()


## Ranked: every member sits by their name at the house. Whoever else had it
## gets a number after it.
func _name_members() -> void:
	for i in seats.size():
		var member: String = seats[i].get("member", "")
		if member == "" or seats[i].name == member:
			continue
		seats[i].name = member
		for j in seats.size():
			if j != i and seats[j].name.to_lower() == member.to_lower():
				seats[j].name = _free_name(seats[j].name)


## Why the ranked room cannot be dealt as it is, or "".
func rated_problem() -> String:
	if not RankedApi.configured():
		return Loc.t("The house has not opened its doors yet.")
	if seats.any(func(seat: Dictionary) -> bool: return seat.bot):
		return Loc.t("A ranked table has no bots.")
	for seat: Dictionary in seats:
		if seat.get("member", "") == "":
			return Loc.t("%s is not signed in to the house.") % seat.name
	if seats.size() < 2:
		return Loc.t("A ranked table needs at least 2 members.")
	return ""


## Host: the room turns ranked (`on`) or back. Ranked, it is played by the
## house's rules, which it asks the house for, and the bots leave.
func set_rated(on: bool) -> void:
	if not hosting or in_match or _asking_house or on == rated:
		return
	if not on:
		rated = false
		rated_note.emit("")
		_push()
		return
	if member_token() == "":
		rated_note.emit(Loc.t("Sign in at the house first: RANKED, on the room screen."))
		return
	_asking_house = true
	rated_note.emit(Loc.t("Knocking on the house's door..."))
	var answer: Dictionary = await RankedApi.get_json("/v1/status", false)
	_asking_house = false
	if not is_instance_valid(self) or current != self or in_match:
		return
	if not answer.ok or not answer.data is Dictionary or not answer.data.get("rules") is Dictionary:
		rated_note.emit(Loc.t(answer.get("error", "")) if answer.get("error", "") != "" else Loc.t("The house does not answer right now."))
		return
	config = GameConfig.from_wire(answer.data.rules)
	rated = true
	seats = seats.filter(func(seat: Dictionary) -> bool: return not seat.bot)
	seats[_seat_of(1)].member = _member()
	_name_members()
	rated_note.emit("")
	_push()


## Host: asks the house for the ranked match of this table, then deals it.
func _start_rated() -> void:
	if _asking_house:
		return
	var problem := rated_problem()
	if problem != "":
		rated_note.emit(problem)
		return
	_asking_house = true
	rated_note.emit(Loc.t("The house is opening its book for this table..."))
	var answer: Dictionary = await RankedApi.post_json("/v1/rooms", {
		"build": _build(), "seats": seats.map(func(seat: Dictionary) -> String: return seat.member),
		"config": config.to_wire(),
	}, true, member_token())
	_asking_house = false
	if not is_instance_valid(self) or current != self or in_match or not rated:
		return
	if not answer.ok or not answer.data is Dictionary:
		rated_note.emit(Loc.t(answer.error))
		return
	rated_note.emit("")
	_deal(str(answer.data.get("match", "")))


## The table has its engine: in a ranked room, this member's machine tells
## the house about the match (house_report.gd).
func watch_match(engine: GameEngine) -> void:
	if house_match != "" and my_match_seat() >= 0:
		HouseReport.watch(self, engine)


## Dedicated: deals the match to the seats as they were dealt by the queue.
## Nobody holds a key the house does not have: the tickets were given out by
## the queue, and only their hashes are here. A seat nobody came to is played
## by a bot from the start (they may still come and take it).
func _deal_ranked() -> void:
	var dealt := GameConfig.from_wire(config.to_wire())
	dealt.seats = seats.map(func(seat: Dictionary) -> Dictionary: return {"name": seat.name, "bot": false})
	dealt.rng_seed = randi_range(1, 0x7fffffff)
	var peers := seats.map(func(seat: Dictionary) -> int: return seat.peer)
	var hashes := seats.map(func(seat: Dictionary) -> String: return seat.key)
	for peer: int in peers:
		if peer > 1:
			_start.rpc_id(peer, _match_id + 1, dealt.to_wire(), peers, "", hashes)
	_start(_match_id + 1, dealt.to_wire(), peers, "", hashes)
	for i in peers.size():
		if peers[i] == 0:
			_set_away(i, &"bot")


## Dedicated: tells everyone at the table what the house made of the match.
func ranked_finish(result: Dictionary) -> void:
	if dedicated:
		_send(_ranked_down, [_match_id, result])


@rpc("authority", "call_remote", "reliable")
func _ranked_down(id: int, result: Dictionary) -> void:
	if id == _match_id:
		ranked_result = result
		ranked_over.emit(result)


## Host: everyone leaves the match (played out or not) and goes back to the
## lobby.
func to_lobby() -> void:
	if not hosting:
		return
	_send(_to_lobby, [])
	_to_lobby()
	# Whoever watched, or asked to, gets a seat like anyone joining the lobby.
	var guests := watchers.duplicate()
	guests.merge(asking)
	for peer: int in asking:
		watch_settled.emit(peer)
	watchers.clear()
	asking.clear()
	for peer: int in guests:
		_sit(peer, guests[peer].name, guests[peer].mark)
	_push()


@rpc("authority", "call_remote", "reliable")
func _start(id: int, dealt: Dictionary, peers: Array, key: String, hashes: Array) -> void:
	_start_dealt(id, dealt, peers)
	_key_hashes = hashes
	if key != "":
		remember_key(key)
	_show(GAME, Transition.DEAL)


func _start_dealt(id: int, dealt: Dictionary, peers: Array) -> void:
	_begin(id, peers, dealt)
	house_match = str(dealt.get("house_match", ""))
	GameConfig.current = GameConfig.from_wire(dealt)


## A new match: nothing of the last one may leak into it.
func _begin(id: int, peers: Array, dealt: Dictionary = {}) -> void:
	release()
	_match_id = id
	in_match = true
	match_peers = peers
	_dealt = dealt
	_history.clear()
	_given.clear()
	_key_hashes = []
	_sent.clear()
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
	house_match = ""
	ranked_result = {}


@rpc("authority", "call_remote", "reliable")
func _to_lobby() -> void:
	in_match = false
	watching = false
	if not hosting:
		_member_up.rpc_id(1, _member())
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
	ticket.opened = Time.get_ticks_msec()
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
		return
	# Kept until it comes back: if the host leaves first, it goes to the next.
	_sent[ticket.number] = [seat, wire]
	if not handing_over:
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
	if not _given.has(Vector2i(number, seat)):
		_relay(number, seat, wire)


## Host: this answer is the next one, for every machine. While taking the
## room over, it waits for what the others had (see _end_take_over).
func _relay(number: int, seat: int, wire: Variant) -> void:
	if _taking_over:
		_held.append([number, seat, wire])
		return
	_send(_answer_down, [_match_id, number, seat, wire])
	_answer_down(_match_id, number, seat, wire)


@rpc("authority", "call_remote", "reliable")
func _answer_down(id: int, number: int, seat: int, wire: Variant) -> void:
	if id != _match_id:
		return
	# Every machine keeps them all: any of them may have to host the room.
	_history.append([number, seat, wire])
	_given[Vector2i(number, seat)] = true
	if _sent.has(number) and _sent[number][0] == seat:
		_sent.erase(number)
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
	elif not handing_over:
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
	elif not handing_over:
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
	elif not handing_over:
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


# --- passing the room on -----------------------------------------------------------

## The name of whoever hosts the room.
func host_name() -> String:
	for seat: Dictionary in seats:
		if seat.peer == 1:
			return seat.name
	return ""


## Guest: listens for the test packets, on a port of the room's range (the
## room may be opened on it one day), and tells the host where.
func _announce() -> void:
	if hosting or watching or ranked or not _unannounced:
		return
	if _probe == null:
		_probe = PacketPeerUDP.new()
		_probe_port = 0
		for at in range(PORT, PORT + PORT_RANGE):
			if _probe.bind(at) == OK:
				_probe_port = at
				break
		if _probe_port == 0:
			# Every port taken: this machine cannot take the room over.
			_probe = null
			return
	_unannounced = false
	_listening.rpc_id(1, _probe_port, addresses())


func _close_probe() -> void:
	if _probe != null:
		_probe.close()
		_probe = null
	_probe_port = 0


func _process(_delta: float) -> void:
	if _probe == null:
		return
	var tag := (PROBE_TAG + "|").to_ascii_buffer()
	while _probe.get_available_packet_count() > 0:
		var packet := _probe.get_packet()
		# Anything else that reaches the port (an ENet client knocking on
		# what it thinks is a room) is no text of ours.
		if packet.size() > 64 or packet.slice(0, tag.size()) != tag:
			continue
		var parts := packet.get_string_from_ascii().split("|")
		if parts.size() != 5 or parts[0] != PROBE_TAG or parts[1].to_int() != _nonce or parts[3].to_int() != _me:
			continue
		if not hosting and not handing_over:
			_heard.rpc_id(1, parts[2].to_int(), parts[4].to_int())


## Host: a guest listens at `at`. It is tried by every address it may have:
## the one it came from, its own and, for a machine on the same computer,
## this computer's.
@rpc("any_peer", "call_remote", "reliable")
func _listening(at: int, own: Array) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if not hosting or _seat_of(peer) < 0:
		return
	var list := []
	var seen := _remote_address(peer)
	if not _loopback(seen):
		list.append(seen)
	for address: Variant in own:
		if address is String and not list.has(address) and list.size() < 6:
			list.append(address)
	list.append("127.0.0.1")
	var entry := {"port": at, "addresses": list}
	_listen[peer] = entry
	_reach[peer] = {}
	_warned.erase(peer)
	_probe_round()
	_rank()
	get_tree().create_timer(PROBE_VERDICT).timeout.connect(_verdict.bind(peer, entry))


static func _loopback(address: String) -> bool:
	return address == "" or address.begins_with("127.") or address == "::1" or address.begins_with("::ffff:127.")


func _remote_address(peer: int) -> String:
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet == null or not multiplayer.get_peers().has(peer):
		return ""
	var link := enet.get_peer(peer)
	return link.get_remote_address() if link != null else ""


## Host: the computer `peer` is on, as an address: "" for this one.
func _machine_of(peer: int) -> String:
	if peer == 1:
		return ""
	var seen := _remote_address(peer)
	return "" if _loopback(seen) else seen


## Host: every machine sends the test packets to every guest but itself.
func _probe_round() -> void:
	var targets := []
	for peer: int in _listen:
		targets.append({"peer": peer, "port": _listen[peer].port, "addresses": _listen[peer].addresses})
	for peer: int in _listen:
		_probe_now.rpc_id(peer, _nonce, targets.filter(func(target: Dictionary) -> bool: return target.peer != peer))
	_send_probes(targets)


@rpc("authority", "call_remote", "reliable")
func _probe_now(nonce: int, targets: Array) -> void:
	_nonce = nonce
	_send_probes(targets)


func _send_probes(targets: Array) -> void:
	if targets.is_empty():
		return
	for i in PROBE_TIMES:
		get_tree().create_timer(PROBE_GAP * i).timeout.connect(_send_burst.bind(targets))


func _send_burst(targets: Array) -> void:
	var out := PacketPeerUDP.new()
	for target: Dictionary in targets:
		for i in target.addresses.size():
			out.set_dest_address(target.addresses[i], target.port)
			out.put_packet(("%s|%d|%d|%d|%d" % [PROBE_TAG, _nonce, _me, target.peer, i]).to_utf8_buffer())
	out.close()


## Host: a test packet from `from` got through to the guest that says so, by
## the address numbered `index`.
@rpc("any_peer", "call_remote", "reliable")
func _heard(from: int, index: int) -> void:
	var target := multiplayer.get_remote_sender_id()
	if not hosting or not _reach.has(target):
		return
	var heard: Dictionary = _reach[target]
	if heard.has(from) and heard[from] <= index:
		return
	heard[from] = index
	if _warned.has(target) and _machine_of(from) != _machine_of(target):
		_warned.erase(target)
		_reach_note.rpc_id(target, true)
	_rank()


## Host: whether anyone on another computer got through to `peer`, once they
## have had the time to. A machine on the same computer always does: it does
## not count.
func _verdict(peer: int, entry: Dictionary) -> void:
	if not hosting or not is_same(_listen.get(peer), entry):
		return
	var home := _machine_of(peer)
	var tried := _machine_of(1) != home or _listen.keys().any(func(other: int) -> bool:
		return other != peer and _machine_of(other) != home)
	var heard: Dictionary = _reach.get(peer, {})
	if not tried or heard.keys().any(func(from: int) -> bool: return _machine_of(from) != home):
		return
	_warned[peer] = true
	_reach_note.rpc_id(peer, false)


@rpc("authority", "call_remote", "reliable")
func _reach_note(ok: bool) -> void:
	reachable = ok
	reach_checked.emit(ok)


## Host: who would take the room over, best first: the guests the most others
## on other computers got through to, then the ones this machine got through
## to, in the order they sit. Everyone gets the list.
func _rank() -> void:
	# The house's room never passes to anyone: there is nobody to rank.
	if not hosting or _taking_over or dedicated:
		return
	var entries := []
	var machines := {}
	for i in seats.size():
		var seat: Dictionary = seats[i]
		if seat.bot or seat.peer <= 1:
			continue
		var home := _machine_of(seat.peer)
		machines[seat.peer] = home
		if not _listen.has(seat.peer):
			continue
		var heard: Dictionary = _reach.get(seat.peer, {})
		var score := 0
		for from: int in heard:
			if _machine_of(from) != home:
				score += 2 if from > 1 else 1
		entries.append({"peer": seat.peer, "name": seat.name, "port": _listen[seat.peer].port,
				"addresses": _listen[seat.peer].addresses, "reach": heard.duplicate(), "score": score, "order": i})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.score > b.score or (a.score == b.score and a.order < b.order))
	_succession = entries
	_machines = machines
	_send(_succession_down, [entries, machines])


@rpc("authority", "call_remote", "reliable")
func _succession_down(entries: Array, machines: Dictionary) -> void:
	_succession = entries
	_machines = machines


## Guest: the host is gone. The room passes to the first one on the list who
## can be reached; this machine takes it if that is itself.
func _on_host_gone() -> void:
	if _leaving or hosting:
		return
	if ranked:
		# The house's room never passes to anyone.
		_fail("The house closed the table.")
		return
	if watching or _waiting:
		# Only those with a seat take the room over.
		_fail("The host closed the room.")
		return
	if handing_over:
		# The one taking the room over left too, or was never there.
		_next_heir()
		return
	var heirs := _succession.filter(func(entry: Dictionary) -> bool: return entry.peer != 1)
	if not _joined or heirs.is_empty():
		_fail("The host closed the room.")
		return
	handing_over = true
	_walk = heirs
	_step = -1
	_next_heir()


## The next one on the list: this machine opens the room, or joins whoever
## does. A try that gets nowhere in HANDOVER_TIMEOUT is given up on.
func _next_heir() -> void:
	if not handing_over:
		return
	_attempt += 1
	_step += 1
	if _step >= _walk.size():
		handing_over = false
		# The last one tried must not get through later, as someone joining.
		_swap_link(OfflineMultiplayerPeer.new())
		_fail("The host left, and nobody could take the room over.")
		return
	var heir: Dictionary = _walk[_step]
	var mine: bool = heir.peer == _me
	passing.emit(heir.name, mine)
	if mine:
		if not _take_over(heir):
			_next_heir()
		return
	var link := ENetMultiplayerPeer.new()
	var ip := _address_of(heir)
	if link.create_client(ip, heir.port) != OK:
		_next_heir.call_deferred()
		return
	_where = ip if heir.port == PORT else "%s:%d" % [ip, heir.port]
	_swap_link(link)
	get_tree().create_timer(HANDOVER_TIMEOUT).timeout.connect(_heir_late.bind(_attempt))


func _heir_late(attempt: int) -> void:
	if handing_over and attempt == _attempt and multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		_next_heir()


## Where this machine reaches `heir`: by the address that got its test
## packet through, or this computer's if it is on it.
func _address_of(heir: Dictionary) -> String:
	var reach: Dictionary = heir.reach
	if reach.has(_me):
		return heir.addresses[reach[_me]]
	if _machines.has(_me) and _machines.get(_me) == _machines.get(heir.peer):
		return "127.0.0.1"
	return heir.addresses[0]


## Puts the room on another connection. The old one is closed only once it
## has been let go of, so that it says nothing about closing.
func _swap_link(link: MultiplayerPeer) -> void:
	var old := multiplayer.multiplayer_peer
	multiplayer.multiplayer_peer = link
	if old != null:
		old.close()


## This machine is the next host: it opens the room on the port it listened
## on and waits for the others to come back to it. False if it cannot.
func _take_over(heir: Dictionary) -> bool:
	_close_probe()
	var server := ENetMultiplayerPeer.new()
	if server.create_server(heir.port, MAX_SEATS * 2) != OK:
		return false
	_swap_link(server)
	handing_over = false
	hosting = true
	port = heir.port
	_taking_over = true
	_take_over_id += 1
	_pending.clear()
	_resumes.clear()
	_held.clear()
	_renamed.clear()
	_listen.clear()
	_reach.clear()
	_warned.clear()
	var was := _me
	_me = 1
	_renamed[was] = 1
	# The old host's seat is left; everyone else's waits for them, as the
	# peer they had made negative (nobody answers for it, nor is it absent).
	for i in range(seats.size() - 1, -1, -1):
		var seat: Dictionary = seats[i]
		if seat.bot:
			continue
		if seat.peer == 1:
			seats.remove_at(i)
		elif seat.peer == was:
			seat.peer = 1
		elif seat.peer > 1:
			_pending[seat.get("mark", "")] = seat.peer
			seat.peer = -seat.peer
	if in_match:
		var left := -1
		for i in match_peers.size():
			var peer: int = match_peers[i]
			if peer == 1:
				left = i
				match_peers[i] = 0
			elif peer == was:
				match_peers[i] = 1
			elif peer > 1:
				match_peers[i] = -peer
		if left >= 0:
			seat_left.emit(left)
			_set_away(left, &"idle")
	get_tree().create_timer(HANDOVER_GRACE).timeout.connect(_end_take_over.bind(_take_over_id))
	if _pending.is_empty():
		_end_take_over.call_deferred(_take_over_id)
	return true


## New host: one of the others is back (or someone else came in).
@rpc("any_peer", "call_remote", "reliable")
func _resume(nonce: int, token: String, player_name: String, build: int, keys: Array, had: int, sent: Dictionary) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if not hosting:
		return
	if nonce != _nonce:
		# Another room that happens to be on that port.
		_not_this_room.rpc_id(peer)
		return
	var mark := _hash(token)
	if not _taking_over or _reconciling or not _pending.has(mark):
		# Too late to be waited for: as anyone coming in.
		_greet(peer, player_name, build, keys, mark)
		return
	var was: int = _pending[mark]
	_pending.erase(mark)
	_renamed[was] = peer
	for seat: Dictionary in seats:
		if seat.peer == -was:
			seat.peer = peer
	var at := match_peers.find(-was) if in_match else -1
	if at >= 0:
		match_peers[at] = peer
	_resumes[peer] = {"had": had, "sent": sent}
	if _pending.is_empty():
		_end_take_over(_take_over_id)


@rpc("authority", "call_remote", "reliable")
func _not_this_room() -> void:
	if handing_over:
		_next_heir()


## New host: the others are back, or have had their time. The longest history
## any of them has is the match as it stands: the new host takes it, hands the
## rest of it to whoever is behind, and only then passes on the answers that
## never made it round, and the new ones.
func _end_take_over(id: int) -> void:
	if id != _take_over_id or not _taking_over or _reconciling or not hosting:
		return
	_reconciling = true
	# Whoever is not back has left, like anyone who drops out.
	for mark: String in _pending:
		var was: int = _pending[mark]
		for i in range(seats.size() - 1, -1, -1):
			if seats[i].peer == -was:
				seats.remove_at(i)
		var at := match_peers.find(-was) if in_match else -1
		if at >= 0:
			match_peers[at] = 0
			seat_left.emit(at)
			_away_down(_match_id, at, "idle")
	_pending.clear()
	while in_match:
		var ahead := 0
		var longest := _history.size()
		for peer: int in _resumes:
			if _resumes[peer].had > longest:
				longest = _resumes[peer].had
				ahead = peer
		if ahead == 0:
			break
		_tail_up.rpc_id(ahead, _match_id, _history.size())
		await _tail_came
		if not hosting or id != _take_over_id:
			return
		if _resumes.has(ahead):
			_resumes[ahead].had = mini(_resumes[ahead].had, _history.size())
	_taking_over = false
	_reconciling = false
	var machines := {}
	for peer: int in _machines:
		if _renamed.has(peer) and _renamed[peer] != 1:
			machines[_renamed[peer]] = _machines[peer]
	var heirs := []
	for entry: Dictionary in _succession:
		if not _renamed.has(entry.peer) or _renamed[entry.peer] == 1:
			continue
		var moved := entry.duplicate(true)
		moved.peer = _renamed[entry.peer]
		moved.reach = {}
		for from: int in entry.reach:
			if _renamed.has(from) and _renamed[from] != 1:
				moved.reach[_renamed[from]] = entry.reach[from]
		heirs.append(moved)
	_succession = heirs
	_machines = machines
	for peer: int in _resumes:
		var state := _state()
		state.peers = match_peers
		state.away = away
		state.tail = _history.slice(_resumes[peer].had) if in_match else []
		state.heirs = heirs
		state.machines = machines
		_resumed.rpc_id(peer, _match_id, state)
	if in_match:
		# Lost on the way: what was sent to the old host and never came back,
		# from the others and from this machine, in the order it was asked.
		var lost := []
		for peer: int in _resumes:
			var sent: Dictionary = _resumes[peer].sent
			for number: int in sent:
				lost.append([number, sent[number][0], sent[number][1], peer])
		for number: int in _sent:
			lost.append([number, _sent[number][0], _sent[number][1], 1])
		lost.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		for entry: Array in lost:
			var seat: int = entry[1]
			if seat >= 0 and seat < match_peers.size() and match_peers[seat] == entry[3] and not _given.has(Vector2i(entry[0], seat)):
				_relay(entry[0], seat, entry[2])
		_sent.clear()
		for entry: Array in _held:
			if not _given.has(Vector2i(entry[0], entry[1])):
				_relay(entry[0], entry[1], entry[2])
	_held.clear()
	_resumes.clear()
	_push()
	host_changed.emit()
	# What the old host was answering for (a bot in a seat, a kick) is now
	# answered here.
	for ticket: Ticket in _tickets.values():
		ticket.controller.cover(ticket)


@rpc("authority", "call_remote", "reliable")
func _tail_up(id: int, from: int) -> void:
	if id == _match_id:
		_tail_down.rpc_id(1, _match_id, _history.slice(from))


@rpc("any_peer", "call_remote", "reliable")
func _tail_down(id: int, entries: Array) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if not hosting or id != _match_id or not _resumes.has(peer):
		return
	for entry: Array in entries:
		_answer_down(_match_id, entry[0], entry[1], entry[2])
	_tail_came.emit()


## Guest: back in the room, under its new host.
@rpc("authority", "call_remote", "reliable")
func _resumed(id: int, state: Dictionary) -> void:
	if not handing_over:
		return
	handing_over = false
	seats = state.seats
	config = GameConfig.from_wire(state.config)
	_nonce = state.nonce
	_succession = state.heirs
	_machines = state.machines
	if in_match and id == _match_id:
		var before := match_peers
		match_peers = state.peers
		away = state.away
		for entry: Array in state.tail:
			_answer_down(_match_id, entry[0], entry[1], entry[2])
		for seat in match_peers.size():
			if match_peers[seat] == 0 and seat < before.size() and before[seat] != 0:
				seat_left.emit(seat)
		for seat: int in away:
			away_changed.emit(seat)
		# Whatever was answered here while the room was moving goes up now
		# (the host passes each answer on only once).
		for number: int in _sent:
			_answer_up.rpc_id(1, _match_id, number, _sent[number][0], _sent[number][1])
	host_changed.emit()
	changed.emit()
	_announce()
