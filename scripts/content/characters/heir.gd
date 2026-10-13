extends CharacterDef
## Augustus Belmont. Money was never the problem.


func _init() -> void:
	id = &"heir"
	display_name = "Heir"
	title = "Augustus Belmont"
	texture_path = "res://assets/cards/Heir.png"
	order = 40
	_add(SoldOut.new())
	_add(Party.new())


class SoldOut extends Ability:
	const PAY := 4

	func _init() -> void:
		id = &"heir.sold_out"
		display_name = "Sold Out"
		describe("Swap this card for a random one and gain %d coins.", [PAY])
		on_turn = true

	# Bluffed, there is no "this card": the liar says which one goes, and says
	# it now, since asked later it would give them away.
	func prepare(play: Play) -> bool:
		return await play.engine.choose_card_to_shed(play)

	func resolve(play: Play) -> void:
		var engine := play.engine
		await engine.shed_card(play, &"sold_out")
		await engine.gain_coins(play.actor, PAY, &"sold_out")

	func ai_weight(player: PlayerState, _engine: GameEngine) -> float:
		return 0.5 if player.has_character(character_id) else 1.0


## The shop is on the house for the rest of the turn (GameEngine.free_rerolls).
## It is claimed once a turn and is no action of it: the turn goes on.
class Party extends Ability:
	const REROLLS := 10

	func _init() -> void:
		id = &"heir.party"
		display_name = "Party"
		describe("Reroll the shop for free up to %d times this turn. Does not consume the turn.", [REROLLS])
		on_turn = true
		ends_turn = false
		# Not the action of a turn: there is nothing in it for a disguise.
		repeatable = false

	func can_use(player: PlayerState, engine: GameEngine) -> String:
		if player.turn.get("party", false):
			return Loc.t("Once per turn")
		return "" if not engine.item_pool.is_empty() else Loc.t("No items in this match")

	func prepare(play: Play) -> bool:
		play.actor.turn["party"] = true
		return true

	func resolve(play: Play) -> void:
		play.actor.turn["free_rerolls"] = REROLLS

	func ai_weight(player: PlayerState, _engine: GameEngine) -> float:
		return 0.5 if player.coins >= 4 else 0.15
