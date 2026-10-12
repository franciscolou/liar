extends CharacterDef
## Augustus Belmont. Money was never the problem.


func _init() -> void:
	id = &"heir"
	display_name = "Heir"
	title = "Augustus Belmont"
	texture_path = "res://assets/cards/Heir.png"
	order = 40
	_add(SoldOut.new())
	_add(PassiveIncome.new())


class SoldOut extends Ability:
	const PAY := 4

	func _init() -> void:
		id = &"heir.sold_out"
		display_name = "Sold Out"
		describe("Swap this card for a random one and gain %d coins.", [PAY])
		on_turn = true

	func resolve(play: Play) -> void:
		var engine := play.engine
		var index := play.actor.cards.find(character_id)
		if index == -1:
			# Bluffed: there is no "this card", so the liar says which one goes.
			index = await engine.pick_own_card(play.actor, Loc.t("%s, you don't hold the %s: choose the card to swap") % [play.actor.name, Content.character(character_id).display_name])
		await engine.replace_card(play.actor, index, &"sold_out")
		await engine.gain_coins(play.actor, PAY, &"sold_out")

	func ai_weight(player: PlayerState, _engine: GameEngine) -> float:
		return 0.5 if player.has_character(character_id) else 1.0


class PassiveIncome extends Ability:
	const INCOME := 3

	func _init() -> void:
		id = &"heir.passive_income"
		display_name = "Passive Income"
		describe("Spend your whole turn to gain %d coins.", [INCOME])
		on_turn = true
		fresh_turn = true

	func resolve(play: Play) -> void:
		await play.engine.gain_coins(play.actor, INCOME, &"passive_income")

	func ai_weight(_player: PlayerState, _engine: GameEngine) -> float:
		return 1.4
