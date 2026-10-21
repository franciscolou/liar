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
			"description": "Stores +%d whenever a lie of yours goes undoubted or you catch someone lying. Only you can see it. Claim Mythomaniac's 'Cash Out' to collect it.", "args": [STASH],
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
		describe("Whenever you lie without being cought or catch someone lying, store %d coins in the Vault.", [STASH])
		info_only = true


class CashOut extends Ability:
	func _init() -> void:
		id = &"mythomaniac.cash_out"
		display_name = "Cash Out"
		description = "Replace this card with a new one and collect every coin in your Vault (if there are any)."
		on_turn = true

	# A bluffer says now which card will go: asked later, it would give them away.
	func prepare(play: Play) -> bool:
		return await play.engine.choose_card_to_shed(play)

	func resolve(play: Play) -> void:
		var engine := play.engine
		await engine.shed_card(play, &"cash_out")
		# An empty vault: the card was all there was to trade.
		var stash := play.actor.counter(VAULT)
		if stash <= 0 or engine.over:
			return
		await engine.set_counter(play.actor, VAULT, 0)
		await engine.gain_coins(play.actor, stash, &"vault")

	func ai_weight(player: PlayerState, _engine: GameEngine) -> float:
		return 0.4 * player.counter(VAULT) if player.counter(VAULT) > 0 else 0.08
