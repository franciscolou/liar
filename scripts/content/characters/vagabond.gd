extends CharacterDef
## Jeremiah "Miah" Crow. Nothing left to lose.

const DEBT_LIMIT := -10


func _init() -> void:
	id = &"vagabond"
	display_name = "Vagabond"
	title = "Jeremiah \"Miah\" Crow"
	texture_path = "res://assets/cards/Vagabond.png"
	order = 50
	_add(StreetBargain.new())
	_add(OnTheCuff.new())


class StreetBargain extends Ability:
	func _init() -> void:
		id = &"vagabond.street_bargain"
		display_name = "Street Bargain"
		description = "Lose 6 coins instead of 1 Morale."
		trigger_text = "When you would lose Morale"
		cost = 6

	func reacts_to(event: GameEvent, player: PlayerState, _engine: GameEngine) -> bool:
		return event.type == &"before_morale_loss" and event.data.target == player

	func resolve(play: Play) -> void:
		play.event.data.amount -= 1
		if play.event.data.amount <= 0:
			play.event.cancelled = true


class OnTheCuff extends Ability:
	func _init() -> void:
		id = &"vagabond.on_the_cuff"
		display_name = "On the Cuff"
		description = "Pay for something you can't afford, down to a balance of %d coins." % DEBT_LIMIT
		trigger_text = "When you are short on coins"

	func reacts_to(event: GameEvent, player: PlayerState, _engine: GameEngine) -> bool:
		return (event.type == &"payment_short" and event.data.player == player
				and player.coins - event.data.amount >= DEBT_LIMIT)

	func resolve(play: Play) -> void:
		play.event.data.allowed = true
