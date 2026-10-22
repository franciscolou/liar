extends CharacterDef
## Vittorio "Steel" Bellandi. Came to Carcaj with a sword and no gun, and is
## still here.
##
## A Duel is a choice both sides make at once and in secret (GameEngine.ask_all):
## lay the sword down for the pot, or strike. It is shown to the table as one
## event (duel_settled) before anything comes of it. Berserk is paid in Morale,
## as a price (GameEngine.spend_morale), by whoever started it: a mirror sends
## the sword back, not the bill.

## What each side of a Duel gets when both lay their swords down.
const POT := 5
## Why the coins of a Duel come (coins.reason).
const DUEL := &"duel"
## The two answers of a Duel, in the order of the options.
const GIVE := 0
const STRIKE := 1


func _init() -> void:
	id = &"duelist"
	display_name = "Duelist"
	title = "Vittorio \"Steel\" Bellandi"
	texture_path = "res://assets/cards/Duelist.png"
	order = 210
	_add(Dilemma.new())
	_add(Berserk.new())


class Dilemma extends Ability:
	func _init() -> void:
		id = &"duelist.dilemma"
		display_name = "Prisoner's Dilemma"
		describe("Challenge a player to a dilemma. Each of you chooses in secret, at the same time, to contribute or to attack.\n\nBoth contribute: each of you gains %d coins.\nBoth attack: nothing happens.\nOne attacks and the other contributes: whoever contributed loses 1 Morale.", [POT])
		on_turn = true
		targeting = Targeting.OPPONENT

	func resolve(play: Play) -> void:
		var engine := play.engine
		var sides: Array = [play.actor, play.target]
		var asked: Array = []
		for p: PlayerState in sides:
			var other: PlayerState = sides[1 - sides.find(p)]
			var d := Decision.new(Decision.Kind.PICK, p)
			d.prompt = Loc.t("Prisoner's Dilemma with %s. Do you contribute or attack?") % other.name
			# What comes of each answer, by what the other answers: the screen
			# shows it (see dilemma_pick.gd); a plain menu reads the description.
			var gives := Loc.t("If %s contributes") % other.name
			var strikes := Loc.t("If %s attacks") % other.name
			d.options = [
				{"label": Loc.t("Contribute"), "does": &"give",
					"description": Loc.t("If %s contributes too, you both gain %d coins. If they attack, you lose 1 Morale.") % [other.name, POT],
					"outcomes": [
						{"if": gives, "then": Loc.t("+%d coins for each of you") % POT, "tone": &"good"},
						{"if": strikes, "then": Loc.t("you lose 1 Morale"), "tone": &"bad"},
					]},
				{"label": Loc.t("Attack"), "does": &"strike",
					"description": Loc.t("If %s contributes, they lose 1 Morale. If they attack too, nothing happens.") % other.name,
					"outcomes": [
						{"if": gives, "then": Loc.t("%s loses 1 Morale") % other.name, "tone": &"hit"},
						{"if": strikes, "then": Loc.t("the swords break: nothing happens"), "tone": &"none"},
					]},
			]
			# Not a menu: the two answers on either side of the sword (see dilemma_pick.gd).
			d.context = {"play": play, "weights": _weights(p, other), "look": &"dilemma", "rival": other}
			asked.append(d)
		var answers := await engine.ask_all(asked)
		if engine.over:
			return
		# No answer (a clock that ran out) lays the sword down.
		var strikes: Array = sides.map(func(p: PlayerState) -> bool: return answers.get(p.id, GIVE) == STRIKE)
		await engine.fire(&"duel_settled", {
			"play": play, "duelist": play.actor, "rival": play.target,
			"duelist_strikes": strikes[0], "rival_strikes": strikes[1],
		})
		if engine.over:
			return
		if not strikes[0] and not strikes[1]:
			for p: PlayerState in sides:
				if p.alive and not engine.over:
					await engine.gain_coins(p, POT, DUEL)
		elif strikes[0] != strikes[1]:
			var striker: PlayerState = sides[0] if strikes[0] else sides[1]
			var struck: PlayerState = sides[1] if strikes[0] else sides[0]
			if struck.alive and not engine.over:
				await engine.deal_damage(striker, struck, play)

	# Whoever cannot take a blow, or can deal the last one, would rather strike.
	func _weights(p: PlayerState, other: PlayerState) -> Array:
		var strike := 1.0
		if p.morale <= 1:
			strike += 1.5
		if other.morale <= 1:
			strike += 1.5
		return [1.3, strike]

	func ai_weight(_player: PlayerState, _engine: GameEngine) -> float:
		return 1.3

	func ai_target_weight(_play: Play, candidate: PlayerState) -> float:
		return 1.0 + (3 - candidate.morale) * 0.5


## The sword goes through everything the target holds. A shield stops it and
## a mirror sends it back at the Duelist's own items; either way the Morale
## is the Duelist's to give up.
class Berserk extends Ability:
	func _init() -> void:
		id = &"duelist.berserk"
		display_name = "Berserk"
		description = "Sacrifice 1 Morale to destroy every item a player of your choice holds. It can't be used with your last Morale."
		on_turn = true
		targeting = Targeting.OPPONENT

	func can_use(player: PlayerState, _engine: GameEngine) -> String:
		return Loc.t("Not with your last Morale") if player.morale <= 1 else ""

	func target_candidates(play: Play) -> Array:
		return play.engine.targetable_opponents(play.actor).filter(
			func(p: PlayerState) -> bool: return not p.items.is_empty())

	func resolve(play: Play) -> void:
		var engine := play.engine
		var victim := play.target
		# Whoever went berserk: the one aimed at, if a mirror turned it round.
		var berserker := berserker_of(play)
		if not await engine.spend_morale(berserker, 1, play) or engine.over or not victim.alive:
			return
		if victim.items.is_empty():
			return
		# They may keep what they hold out of reach (see GameEngine.reach_items).
		if not await engine.reach_items(play.actor, victim, &"break") or engine.over:
			return
		# From the last one: the ones still to go stay where they are drawn.
		for i in range(victim.items.size() - 1, -1, -1):
			if engine.over or not victim.alive:
				return
			if i < victim.items.size():
				await engine.break_item(victim, victim.items[i])

	static func berserker_of(play: Play) -> PlayerState:
		return play.target if play.reflected else play.actor

	func ai_weight(player: PlayerState, engine: GameEngine) -> float:
		if player.morale < engine.config.start_morale:
			return 0.2
		var most := 0
		for p: PlayerState in engine.targetable_opponents(player):
			most = maxi(most, p.items.size())
		return 0.0 if most < 2 else 0.5 * most

	func ai_target_weight(_play: Play, candidate: PlayerState) -> float:
		return float(candidate.items.size() * candidate.items.size())
