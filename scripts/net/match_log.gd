extends RefCounted
## Everything that happened in a ranked match, written down for the house's
## files (server/LOGS.md has the format): every event the engine fired, every
## decision put to a player with what they answered, and the whole state of
## the table at the start of the match, of each turn and at the end. A
## snapshot is enough to set the table as it stood in that turn; the events
## after it say what happened in it, step by step. The seed, the rules and
## the answers of the people (`finish`) are enough to play the match again.
##
## It watches the match as one more observer of the engine (it hears the
## decisions by GameEngine.answered), on every machine that keeps one: the
## house's match server, and each member's own machine in a ranked room.
## The engine is the same on all of them, so what is written down is too,
## but for the times. No class name: preload it.
##
## Players are written as their seat, items held as {item, uid} (the uid
## follows a copy from one inventory to another), plays as {play: id, ...}
## the first time an event carries them, and as their id when nested.

const FORMAT := 1

var engine: GameEngine
var events: Array = []
var decisions: Array = []
var snapshots: Array = []
var started_at := 0.0
var _started := 0
var _plays: Dictionary = {}  # Play -> id
var _items: Dictionary = {}  # ItemInstance -> uid
## Events whose data listeners may still change (before_*, claim_resolving):
## [entry, event], looked at again in `finish`.
var _mutable: Array = []


func _init(of: GameEngine) -> void:
	engine = of
	_started = Time.get_ticks_msec()
	started_at = Time.get_unix_time_from_system()
	engine.answered.connect(_on_answered)


func _seconds() -> float:
	return snappedf((Time.get_ticks_msec() - _started) / 1000.0, 0.001)


func _current() -> int:
	return engine.current.id if engine.current != null else -1


func present(event: GameEvent) -> void:
	var entry := {
		"n": events.size(), "turn": engine.turn_count, "current": _current(), "t": _seconds(),
		"type": String(event.type), "data": _data(event.data),
	}
	events.append(entry)
	if String(event.type).begins_with("before_") or event.type == &"claim_resolving":
		_mutable.append([entry, event])
	if event.type in [&"game_started", &"turn_started", &"game_over"]:
		snapshots.append(snapshot(entry.n))


func _on_answered(decision: Decision, answer: Variant) -> void:
	var entry := {
		"n": decisions.size(), "after_event": events.size() - 1, "turn": engine.turn_count, "t": _seconds(),
		"seat": decision.player.id, "bot": decision.player.is_bot,
		"kind": Decision.Kind.keys()[decision.kind], "prompt": decision.prompt,
		"options": _value(decision.options, 1), "context": _value(decision.context, 1),
		"answer": _answer(decision, answer),
	}
	decisions.append(entry)


## The answer as what it chose: the option itself, not a place in a list.
func _answer(decision: Decision, answer: Variant) -> Variant:
	if decision.kind == Decision.Kind.PICK:
		var index: int = answer if answer is int else -1
		var chosen: Variant = decision.options[index] if index >= 0 and index < decision.options.size() else null
		return {"index": index, "option": _value(chosen, 1)}
	if decision.kind == Decision.Kind.DOUBT and answer is bool:
		return {"doubt": false}
	if decision.kind == Decision.Kind.DOUBT and answer is StringName:
		return {"doubt": true, "stake": String(answer)}
	return _value(answer, 1)


## The whole table as it stands now.
func snapshot(after_event := -1) -> Dictionary:
	var players := []
	for p: PlayerState in engine.players:
		players.append({
			"seat": p.id, "name": p.name, "bot": p.is_bot, "alive": p.alive,
			"morale": p.morale, "coins": p.coins,
			"cards": _ids(p.cards), "left": _ids(p.left),
			"items": p.items.map(func(instance: ItemInstance) -> Variant: return _value(instance, 1)),
			"statuses": _value(p.statuses, 1), "counters": _value(p.counters, 1),
			"hand_limit": engine.hand_limit(p) if p.alive else 0,
		})
	return {
		"after_event": after_event, "turn": engine.turn_count, "current": _current(),
		"deck": _ids(engine.deck),
		"shop": engine.shop.map(func(def: Variant) -> Variant: return String(def.id) if def is ItemDef else null),
		"fixed_items": engine.fixed_items.map(func(def: ItemDef) -> String: return String(def.id)),
		"last_action": String(engine.last_action.id) if engine.last_action != null else null,
		"players": players,
	}


func _ids(list: Array) -> Array:
	return list.map(func(id: Variant) -> String: return String(id))


func _data(data: Dictionary) -> Dictionary:
	var out := {}
	for key: Variant in data:
		out[str(key)] = _value(data[key], 0)
	return out


## Plain JSON for `value`. `depth` 0 is an event's own field: a play there is
## written out in full; deeper down, by its id only.
func _value(value: Variant, depth: int) -> Variant:
	if depth > 6:
		return null
	if value is PlayerState:
		return value.id
	if value is StringName:
		return String(value)
	if value is Play:
		return _play(value) if depth == 0 else {"play": _play_id(value)}
	if value is ItemInstance:
		return {"item": String(value.def.id), "uid": _uid(value), "hidden": value.hidden, "sealed_turn": value.sealed_turn}
	if value is Playable or value is CharacterDef:
		return String(value.id)
	if value is GameEvent:
		return {"event": String(value.type)}
	if value is Decision:
		return {"decision": Decision.Kind.keys()[value.kind], "seat": value.player.id}
	if value is Dictionary:
		var out := {}
		for key: Variant in value:
			out[str(_value(key, depth + 1)) if not key is String else key] = _value(value[key], depth + 1)
		return out
	if value is Array:
		return value.map(func(v: Variant) -> Variant: return _value(v, depth + 1))
	if value is Vector2 or value is Vector2i:
		return [value.x, value.y]
	if value is Color:
		return value.to_html()
	if value is Object:
		return value.get_class()
	return value


func _play_id(play: Play) -> int:
	if not _plays.has(play):
		_plays[play] = _plays.size()
	return _plays[play]


func _uid(instance: ItemInstance) -> int:
	if not _items.has(instance):
		_items[instance] = _items.size()
	return _items[instance]


func _play(play: Play) -> Dictionary:
	var out := {
		"play": _play_id(play),
		"source": String(play.source.id) if play.source != null else null,
		"kind": "ability" if play.is_claim() else "item",
		"character": String(play.ability().character_id) if play.is_claim() else null,
		"actor": play.actor.id if play.actor != null else null,
		"target": play.target.id if play.target != null else null,
		"mark": play.mark.id if play.mark != null else null,
		"item": _value(play.item, 1) if play.item != null else null,
		"reacting_to": String(play.event.type) if play.event != null else null,
		"truthful": play.truthful, "cost": play.cost, "paid": play.paid,
		"doubter": play.doubter.id if play.doubter != null else null,
		"failed": play.failed, "cancelled": play.cancelled, "blocked": play.blocked, "reflected": play.reflected,
	}
	var params := {}
	for key: Variant in play.params:
		# What the others could have answered with is in the decisions already.
		if key != "early_reactions":
			params[str(key)] = _value(play.params[key], 1)
	out["params"] = params
	return out


## The record, once the match is over. `answers`: the answers of the people,
## in the order the room gave them (Room._history), which with the seed and
## the rules play the match again.
func finish(answers: Array, places: Array) -> Dictionary:
	for pair: Array in _mutable:
		var entry: Dictionary = pair[0]
		var event: GameEvent = pair[1]
		entry["cancelled"] = event.cancelled
		var after := _data(event.data)
		if after != entry.data:
			entry["after"] = after
	var config := engine.config
	return {
		"format": FORMAT,
		"started_at": started_at,
		"ended_at": Time.get_unix_time_from_system(),
		"seconds": _seconds(),
		"seed": config.rng_seed,
		"config": config.to_wire(),
		"characters": engine.characters.map(func(def: CharacterDef) -> String: return String(def.id)),
		"item_pool": engine.item_pool.map(func(def: ItemDef) -> String: return String(def.id)),
		"players": engine.players.map(func(p: PlayerState) -> Dictionary: return {"seat": p.id, "name": p.name, "bot": p.is_bot}),
		"turns": engine.turn_count,
		"winner": engine.winner.id if engine.winner != null else null,
		"places": places,
		"events": events,
		"decisions": decisions,
		"snapshots": snapshots,
		"replay": {"seed": config.rng_seed, "answers": answers},
	}
