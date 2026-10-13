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
		description = "Block the damage."
		trigger_text = "When you would lose Morale"
		cost = 6

	func reacts_to(event: GameEvent, player: PlayerState, _engine: GameEngine) -> bool:
		if event.type != &"before_morale_loss" or event.data.target != player:
			return false
		# Caught claiming the Vagabond: the table has just seen it was a lie,
		# so that Morale can't be bargained away with the same claim.
		var lie: Play = event.data.get("play")
		return not (event.data.cause == &"lie" and lie != null and lie.actor == player
				and lie.is_claim() and lie.ability().character_id == &"vagabond")

	# Caught, the lie costs a Morale and the blow it was meant to stop lands too.
	func caution(player: PlayerState, _engine: GameEngine) -> String:
		if player.has_character(character_id):
			return ""
		return Loc.t("Street Bargain would be a bluff: caught lying, you lose 2 Morale, one for the lie and the one you failed to block.")

	func resolve(play: Play) -> void:
		play.event.data.amount -= 1
		if play.event.data.amount <= 0:
			play.event.cancelled = true


class OnTheCuff extends Ability:
	func _init() -> void:
		id = &"vagabond.on_the_cuff"
		display_name = "On the Cuff"
		describe("Pay for something you can't afford, down to a balance of %d coins.", [DEBT_LIMIT])
		trigger_text = "When you are short on coins"

	func reacts_to(event: GameEvent, player: PlayerState, _engine: GameEngine) -> bool:
		return (event.type == &"payment_short" and event.data.player == player
				and player.coins - event.data.amount >= DEBT_LIMIT)

	func resolve(play: Play) -> void:
		play.event.data.allowed = true
