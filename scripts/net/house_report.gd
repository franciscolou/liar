extends Node
## A ranked room's match, as this member's machine tells the house about it
## (see "ranked rooms" at the top of room.gd, and the house's rooms.py): that
## the member is at the table, as the match is dealt, and how it ended, with
## the record of it (match_record.gd) and everything that happened in it
## (match_log.gd). Then it asks the house until the match is settled, and
## hands the new ratings to the room (Room.ranked_result, ranked_over).
##
## It hangs on the root of the tree, not on the room: whoever walks out of the
## room once the match is over still gets it written down. It goes away by
## itself once it is done. No class name: preload it.

const Record := preload("res://scripts/net/match_record.gd")
const Log := preload("res://scripts/net/match_log.gd")
const RankedApi := preload("res://scripts/net/ranked_api.gd")
const GROUP := &"house_report"
const TRIES := 5
## How often the house is asked whether the match is settled, and for how long.
const POLL := 3.0
const PATIENCE := 240.0

var match_id := ""
var engine: GameEngine
## The member's token at the house.
var token := ""
var _room: WeakRef
var _record: Record
var _log: Log
var _sent := false


## Starts telling the house about the match `engine` plays in `room`. A
## report of an earlier deal of the same match (this machine left and came
## back: it plays it all again) gives way to this one.
static func watch(room: Node, of: GameEngine) -> void:
	var tree := room.get_tree()
	for old: Node in tree.get_nodes_in_group(GROUP):
		if old.match_id == room.house_match and old._room.get_ref() == room and not old._sent:
			old.queue_free()
	var report: Node = load("res://scripts/net/house_report.gd").new()
	report.match_id = room.house_match
	report.engine = of
	report._room = weakref(room)
	report.token = room.member_token()
	report.name = "HouseReport_" + room.house_match
	tree.root.add_child(report)


func _ready() -> void:
	add_to_group(GROUP)
	_record = Record.new(engine, _away)
	_log = Log.new(engine)
	# Ahead of the table: it sees the end of the match before the table
	# leaves for the end screen (and stops the engine on its way out).
	engine.observers.push_front(self)
	_join()


func _away(seat: int) -> bool:
	var room: Node = _room.get_ref()
	return room != null and room.absent(seat)


func _join() -> void:
	var answer: Dictionary = await RankedApi.post_json("/v1/rooms/%s/join" % match_id, {}, true, token)
	if not answer.ok:
		print("the house would not seat this machine at %s: %s" % [match_id, answer.error])


func present(event: GameEvent) -> void:
	_record.present(event)
	_log.present(event)
	if event.type == &"game_over" and not _sent:
		_sent = true
		_report.call_deferred()


func _report() -> void:
	var room: Node = _room.get_ref()
	var report := _record.report()
	report.build = room._build() if room != null else 0
	var answers: Array = room._history.duplicate() if room != null else []
	report.log = _log.finish(answers, report.players.map(func(p: Dictionary) -> Dictionary:
			return {"seat": p.seat, "place": p.place, "forfeit": p.forfeit}))
	# What every machine at the table has the same: how the match ended.
	var final: Dictionary = _log.snapshots.back() if not _log.snapshots.is_empty() else {}
	var digest := JSON.stringify({"seed": engine.config.rng_seed, "turns": engine.turn_count,
			"order": report.order, "final": final}).sha256_text()
	var answer: Dictionary = {"ok": false}
	for attempt in TRIES:
		answer = await RankedApi.post_json("/v1/rooms/%s/report" % match_id, {"digest": digest, "report": report}, true, token)
		if answer.ok or (answer.status >= 400 and answer.status < 500):
			break
		await get_tree().create_timer(2.0 * (attempt + 1)).timeout
	if not answer.ok:
		_tell({}, false)
		return
	var waited := 0.0
	while answer.ok and answer.data is Dictionary and answer.data.get("state") == "playing" and waited < PATIENCE:
		await get_tree().create_timer(POLL).timeout
		waited += POLL
		answer = await RankedApi.get_json("/v1/rooms/" + match_id, true, token)
	var done: bool = answer.ok and answer.data is Dictionary and answer.data.get("state") == "done"
	_tell(answer.data if done else {}, done)


func _tell(data: Dictionary, recorded: bool) -> void:
	var room: Node = _room.get_ref()
	if room != null and room.house_match == match_id:
		room.ranked_result = {"seats": data.get("seats", []), "recorded": recorded}
		room.ranked_over.emit(room.ranked_result)
	queue_free()
