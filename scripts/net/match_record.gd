extends RefCounted
## What the house writes down about a ranked match it hosts, for the
## standings and the figures (server/api/liar_api/results.py). It watches the
## match as one more observer of the engine (GameEngine.observers), on the
## house's own process, and is turned into the report the house is sent once
## the match is over (`report`). No class name: preload it.
##
## It knows everything the engine knows, hidden cards included: a claim is
## written down as the truth or the bluff it was, and the cards each player
## was dealt are kept.

var engine: GameEngine
## Which seats were left to a bot: never sat down, or their player was away
## when they went out (or when the match ended, if they were still in it).
var forfeits: Dictionary = {}
var claims: Array = []
var doubts: Array = []
var purchases: Array = []
var start_hands: Dictionary = {}  # seat -> [character id]
var characters: Array = []
## The seats in the order they went out, and the turn each did.
var out: Array = []
var out_turn: Dictionary = {}
var stats: Dictionary = {}  # seat -> {claims, bluffs, caught, ...}
var started := 0
## Play -> the claim written down for it, while it can still be doubted.
var _open: Dictionary = {}
## Tells whether the player of `seat` is away from the table now.
var away: Callable


func _init(of: GameEngine, seat_away: Callable) -> void:
	engine = of
	away = seat_away
	started = Time.get_ticks_msec()


func _stat(seat: int, what: String, amount := 1) -> void:
	if not stats.has(seat):
		stats[seat] = {"claims": 0, "bluffs": 0, "caught": 0, "doubts": 0, "doubts_right": 0,
				"coins_earned": 0, "coins_spent": 0, "damage_dealt": 0, "damage_taken": 0, "items": 0}
	stats[seat][what] += amount


func present(event: GameEvent) -> void:
	var d := event.data
	match event.type:
		&"game_started":
			characters = engine.characters.map(func(def: CharacterDef) -> String: return String(def.id))
			for p: PlayerState in engine.players:
				start_hands[p.id] = p.cards.map(func(id: StringName) -> String: return String(id))
		&"claim_declared":
			var play: Play = d.play
			if not play.is_claim():
				return
			var entry := {
				"turn": engine.turn_count, "seat": play.actor.id,
				"character": String(play.ability().character_id), "ability": String(play.source.id),
				"truthful": play.truthful, "doubted": false, "caught": false, "reaction": play.event != null,
			}
			claims.append(entry)
			_open[play] = entry
			_stat(play.actor.id, "claims")
			if not play.truthful:
				_stat(play.actor.id, "bluffs")
		&"doubt_revealed":
			var entry: Dictionary = _open.get(d.play, {})
			var right: bool = not d.truthful
			if not entry.is_empty():
				entry.doubted = true
				entry.caught = right
			doubts.append({"turn": engine.turn_count, "seat": d.doubter.id, "against": d.play.actor.id,
					"ability": String(d.play.source.id) if d.play.source != null else "", "correct": right})
			_stat(d.doubter.id, "doubts")
			if right:
				_stat(d.doubter.id, "doubts_right")
				_stat(d.play.actor.id, "caught")
		&"claim_resolved", &"claim_cancelled":
			_open.erase(d.play)
		&"item_bought", &"service_bought":
			purchases.append({"turn": engine.turn_count, "seat": d.player.id, "item": _item_id(d.item)})
			_stat(d.player.id, "items")
		&"coins":
			var delta: int = d.delta
			_stat(d.player.id, "coins_earned" if delta > 0 else "coins_spent", absi(delta))
		&"morale_lost":
			_stat(d.target.id, "damage_taken", d.amount)
			if d.source != null and d.source != d.target:
				_stat(d.source.id, "damage_dealt", d.amount)
		&"player_eliminated", &"player_kicked":
			var seat: int = d.player.id
			if not out.has(seat):
				out.append(seat)
				out_turn[seat] = engine.turn_count
			if away.call(seat):
				forfeits[seat] = true


func _item_id(item: Variant) -> String:
	if item is ItemInstance:
		return String(item.def.id)
	if item is ItemDef:
		return String(item.id)
	return ""


## The report the house is sent (see results.record). The places: the winner
## first, then whoever went out last; a seat left to a bot comes after all the
## others, tied with any other such seat.
func report() -> Dictionary:
	var order: Array = []
	if engine.winner != null:
		order.append(engine.winner.id)
	for p: PlayerState in engine.players:
		if p.alive and not order.has(p.id):
			order.append(p.id)
	var gone := out.duplicate()
	gone.reverse()
	for seat: int in gone:
		if not order.has(seat):
			order.append(seat)
	# Whoever was still in it at the end, and away, never finished it.
	for p: PlayerState in engine.players:
		if p.alive and away.call(p.id):
			forfeits[p.id] = true
	var played := order.filter(func(seat: int) -> bool: return not forfeits.has(seat))
	var players := []
	for seat: int in order:
		var place: int = played.find(seat) + 1 if not forfeits.has(seat) else played.size() + 1
		players.append({
			"seat": seat, "place": place, "forfeit": forfeits.has(seat),
			"eliminated_turn": out_turn.get(seat, -1), "start_hand": start_hands.get(seat, []),
			"stats": stats.get(seat, {}),
		})
	return {
		"turns": engine.turn_count,
		"seconds": (Time.get_ticks_msec() - started) / 1000.0,
		"characters": characters,
		"players": players,
		# The engine's own order, before anyone left to a bot is put last: the
		# house puts it together again with whatever forfeits it agrees on.
		"order": order,
		"claims": claims,
		"doubts": doubts,
		"purchases": purchases,
	}
