class_name HumanController
extends Controller
## Answers for a seat played by a person.
##
## Offline the decision simply goes to the table. In a room every machine runs
## the same match, so an answer has to reach all of them, and in the same
## order: the machine the player sits at asks its table and hands the answer
## to the room; the others just wait for it to come back from the host. What
## travels is where the answer sits among the options (to_wire / from_wire),
## never the objects themselves.

## The lists of a TURN decision's options an answer may come from.
const TURN_LISTS := ["abilities", "buy", "use", "extras"]

## The screen of this machine, for the seat played on it. Null for a seat
## played somewhere else.
var table: Node
## The room the match is played in (room.gd). Null offline.
var room: Node
## Host only: answers for the seat once its player has left the room.
var stand_in: BotController

var _turns := 0


func decide(decision: Decision) -> Variant:
	if room == null:
		return await table.request(decision)
	var ticket: RefCounted = room.open(decision, self)
	if not ticket.done:
		_answer(ticket)
	if not ticket.done:
		await ticket.settled
	return from_wire(decision, ticket.wire)


func withdraw(decision: Decision) -> void:
	if room != null:
		room.drop(decision)
	if table != null:
		table.withdraw(decision)


func observe(event: GameEvent) -> void:
	if stand_in != null:
		stand_in.observe(event)
	# Every machine should be looking at the same match: they compare notes.
	if room != null and table != null and event.type == &"turn_started":
		_turns += 1
		room.report(_turns, _fingerprint())


## The host calls this for a decision left open by a player who walked away.
func cover(ticket: RefCounted) -> void:
	if not ticket.done:
		_answer(ticket)


## Finds the answer to `ticket` where this machine is the one to give it.
func _answer(ticket: RefCounted) -> void:
	var decision: Decision = ticket.decision
	var answer: Variant
	if table != null:
		answer = await table.request(decision)
	elif stand_in != null and room.absent(player.id):
		answer = await stand_in.decide(decision)
	else:
		return
	if not ticket.done and not engine.aborted:
		room.submit(ticket, to_wire(decision, answer))


func _fingerprint() -> int:
	var parts := [engine.rng.state, engine.deck, engine.shop.map(_item_id)]
	for p: PlayerState in engine.players:
		parts.append([p.alive, p.morale, p.coins, p.cards, p.statuses.keys(), p.counters,
				p.items.map(func(instance: ItemInstance) -> StringName: return instance.def.id)])
	return str(parts).hash()


func _item_id(def: Variant) -> StringName:
	return def.id if def != null else &""


# --- answers as plain data -------------------------------------------------------


static func to_wire(d: Decision, answer: Variant) -> Variant:
	match d.kind:
		Decision.Kind.TURN:
			if answer is Dictionary:
				for list: String in TURN_LISTS:
					var at := _index_of(d.options[list], answer)
					if at >= 0:
						return [list, at]
				if answer.get("kind") == &"reroll":
					return ["reroll", 0]
			return null
		Decision.Kind.TARGET:
			return answer.id if answer is PlayerState else -1
		Decision.Kind.DOUBT:
			if answer is StringName:
				return String(answer)
			return _index_of(d.context.get("reactions", []), answer)
		Decision.Kind.REACT:
			return _index_of(d.options, answer)
		Decision.Kind.PICK:
			return answer if answer is int else -1
	return null


## The answer `wire` stands for. Anything that doesn't fit the options is the
## answer of someone who did nothing: end the turn, pass, cancel.
static func from_wire(d: Decision, wire: Variant) -> Variant:
	match d.kind:
		Decision.Kind.TURN:
			if wire is Array and wire.size() == 2 and wire[0] is String and wire[1] is int:
				if wire[0] == "reroll" and d.options.reroll != null:
					return d.options.reroll
				if TURN_LISTS.has(wire[0]) and wire[1] >= 0 and wire[1] < d.options[wire[0]].size():
					return d.options[wire[0]][wire[1]]
			return {"kind": &"end"}
		Decision.Kind.TARGET:
			for candidate: PlayerState in d.options:
				if wire is int and candidate.id == wire:
					return candidate
			return null
		Decision.Kind.DOUBT:
			if wire is String and d.options.has(StringName(wire)):
				return StringName(wire)
			var reactions: Array = d.context.get("reactions", [])
			if wire is int and wire >= 0 and wire < reactions.size():
				return reactions[wire]
			return false
		Decision.Kind.REACT:
			if wire is int and wire >= 0 and wire < d.options.size():
				return d.options[wire]
			return null
		Decision.Kind.PICK:
			if wire is int and wire >= 0 and wire < d.options.size():
				return wire
			return -1
	return null


static func _index_of(options: Array, answer: Variant) -> int:
	if answer is Dictionary:
		for i in options.size():
			if is_same(options[i], answer):
				return i
		return options.find(answer)
	return -1
