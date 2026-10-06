extends CharacterDef
## Lucian "The Weaver" Vellard. Every lie is an investment.
##
## While he is in the match every player has a Vault that fills by itself;
## only emptying it (Cash Out) is a claim.

const VAULT := &"vault"
const STASH := 3


func _init() -> void:
	id = &"mythomaniac"
	display_name = "Mythomaniac"
	title = "Lucian \"The Weaver\" Vellard"
	texture_path = "res://assets/cards/Mythomaniac.png"
	order = 90
	counter_defs = {
		VAULT: {
			"name": "Vault",
			"description": "Grows by %d whenever a lie of yours goes undoubted or you catch a liar. Only you can see it. Claim Mythomaniac's Cash Out to collect it." % STASH,
			"icon": "res://assets/ui/vault.png",
			# A public vault would give away every lie that got through.
			"private": true,
		},
	}
	_add(TallTale.new())
	_add(CashOut.new())


func on_event(event: GameEvent, engine: GameEngine) -> void:
	var earner: PlayerState = null
	match event.type:
		&"lie_succeeded":
			earner = event.data.player
		&"doubt_succeeded":
			earner = event.data.doubter
	if earner != null and earner.alive:
		await engine.set_counter(earner, VAULT, earner.counter(VAULT) + STASH)


class TallTale extends Ability:
	func _init() -> void:
		id = &"mythomaniac.tall_tale"
		display_name = "Tall Tale"
		description = "Every player has a secret Vault. It grows by %d coins whenever a lie of theirs goes undoubted or they catch a liar." % STASH
		info_only = true


class CashOut extends Ability:
	func _init() -> void:
		id = &"mythomaniac.cash_out"
		display_name = "Cash Out"
		description = "Discard this card for a new one and collect every coin in your Vault."
		trigger_text = "On your turn, or when you lose Morale"
		on_turn = true

	func can_use(player: PlayerState, _engine: GameEngine) -> String:
		return "" if player.counter(VAULT) > 0 else Loc.t("Vault is empty")

	func reacts_to(event: GameEvent, player: PlayerState, _engine: GameEngine) -> bool:
		return event.type == &"morale_lost" and event.data.target == player and player.alive

	func resolve(play: Play) -> void:
		var engine := play.engine
		var index := play.actor.cards.find(character_id)
		if index == -1:
			index = engine.random_card_index(play.actor)
		await engine.replace_card(play.actor, index, &"cash_out")
		var stash := play.actor.counter(VAULT)
		await engine.set_counter(play.actor, VAULT, 0)
		await engine.gain_coins(play.actor, stash, &"vault")

	func ai_weight(player: PlayerState, _engine: GameEngine) -> float:
		return 0.4 * player.counter(VAULT)

	func ai_react_weight(_event: GameEvent, player: PlayerState, _engine: GameEngine) -> float:
		return 0.15 * player.counter(VAULT)
