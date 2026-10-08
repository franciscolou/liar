extends CharacterDef
## Barnaby "Boom" Flint. A short fuse and a shorter list of friends.
##
## The bomb is a status its carrier takes into their next turn. When that
## turn ends it goes off as a play of its own (GameEngine.carry_out), so
## shields and mirrors get to stop the blast like any other attack.

const TICKING := &"ticking"
const DEFUSE_COST := 4

var _blast: Blast


func _init() -> void:
	id = &"bomber"
	display_name = "Bomber"
	title = "Barnaby \"Boom\" Flint"
	texture_path = "res://assets/cards/Bomber.png"
	order = 170
	status_defs = {
		TICKING: {
			"name": "Ticking",
			"description": "Carries a bomb: it goes off at the end of this player's next turn and costs them 1 Morale. They can defuse it for %d coins during that turn." % DEFUSE_COST,
			"color": Color("d8662a"),
		},
	}
	# Never claimed: it is what the bomb does when it goes off.
	_blast = Blast.new()
	_blast.character_id = id
	_add(ShortFuse.new())
	_add(TimeBomb.new())


func on_event(event: GameEvent, engine: GameEngine) -> void:
	match event.type:
		&"turn_ended":
			var carrier: PlayerState = event.data.player
			if engine.over or not carrier.alive or not carrier.has_status(TICKING):
				return
			var status: Dictionary = carrier.statuses[TICKING]
			# Planted during this very turn (a mirror sent it back): it waits
			# for the next one, so the carrier gets a chance to defuse it.
			if status.get("planted", 0) >= engine.turn_count:
				return
			var owner := engine.player_by_id(status.get("by", -1))
			await engine.remove_status(carrier, TICKING)
			if owner == null or not owner.alive or engine.over:
				return
			var play := Play.new()
			play.engine = engine
			play.actor = owner
			play.target = carrier
			play.source = _blast
			await engine.carry_out(play)
		&"player_eliminated":
			# A dead bomber's bombs are duds.
			var dead: PlayerState = event.data.player
			for p: PlayerState in engine.players:
				if p.alive and p.has_status(TICKING) and p.statuses[TICKING].get("by", -1) == dead.id:
					await engine.remove_status(p, TICKING)


func turn_extras(player: PlayerState, engine: GameEngine) -> Array:
	if not player.has_status(TICKING):
		return []
	var cost := engine.price(player, DEFUSE_COST)
	var affordable := engine.can_pay(player, cost)
	return [{
		"id": &"bomber.defuse",
		"label": Loc.t("Defuse the Bomb"),
		"description": Loc.t("Pay %d coins to defuse the bomb planted on you. If you don't, it goes off when this turn ends and you lose 1 Morale.") % DEFUSE_COST,
		"cost": cost,
		"enabled": affordable,
		"reason": "" if affordable else Loc.t("Not enough coins"),
		"run": _defuse,
		"ai": 0.95 if player.morale <= 1 else 0.7,
		"priority": 2,
	}]


func _defuse(player: PlayerState, engine: GameEngine) -> void:
	if not player.has_status(TICKING) or not await engine.pay(player, engine.price(player, DEFUSE_COST)):
		return
	await engine.remove_status(player, TICKING)
	await engine.note(player, "%s defuses the bomb.")


class ShortFuse extends Ability:
	func _init() -> void:
		id = &"bomber.short_fuse"
		display_name = "Short Fuse"
		description = "Your bomb goes off at the end of its carrier's next turn: they lose 1 Morale, unless they pay %d coins to defuse it first. Shields and Mirrors work against the blast." % DEFUSE_COST
		info_only = true


class TimeBomb extends Ability:
	func _init() -> void:
		id = &"bomber.time_bomb"
		display_name = "Time Bomb"
		description = "Pay 3 coins to plant a bomb on a player. A player can only carry one bomb."
		on_turn = true
		cost = 3
		targeting = Targeting.OPPONENT
		tags = [&"damage"]
		inflicts = true

	func target_candidates(play: Play) -> Array:
		return play.engine.targetable_opponents(play.actor).filter(
			func(p): return not p.has_status(TICKING))

	func resolve(play: Play) -> void:
		if play.target.has_status(TICKING):
			return
		await play.engine.add_status(play.target, TICKING, {
			"by": play.actor.id, "planted": play.engine.turn_count,
		})

	func ai_weight(_player: PlayerState, _engine: GameEngine) -> float:
		return 1.6

	# Best on someone who is hurt already, or too broke to cut the wire.
	func ai_target_weight(_play: Play, candidate: PlayerState) -> float:
		return 1.0 + (3 - candidate.morale) + (0.6 if candidate.coins < DEFUSE_COST else 0.0)


## The explosion itself, carried out by on_event.
class Blast extends Ability:
	func _init() -> void:
		id = &"bomber.blast"
		display_name = "Blast"
		tags = [&"damage"]

	func resolve(play: Play) -> void:
		await play.engine.deal_damage(play.actor, play.target, play)
