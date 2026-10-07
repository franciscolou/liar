extends CharacterDef
## Mortimer "Six Feet" Graves. Sooner or later everyone is a customer.

const DEPTH := 3


func _init() -> void:
	id = &"gravedigger"
	display_name = "Gravedigger"
	title = "Mortimer \"Six Feet\" Graves"
	texture_path = "res://assets/cards/Gravedigger.png"
	order = 130
	_add(Exhume.new())
	_add(LastRites.new())


class Exhume extends Ability:
	func _init() -> void:
		id = &"gravedigger.exhume"
		display_name = "Exhume"
		description = "Look at the top %d cards of the deck. You may trade one card of your hand for one of them." % DEPTH
		on_turn = true

	func can_use(_player: PlayerState, engine: GameEngine) -> String:
		return Loc.t("The deck is empty") if engine.deck.is_empty() else ""

	func resolve(play: Play) -> void:
		var engine := play.engine
		var actor := play.actor
		var count := mini(DEPTH, engine.deck.size())
		if count <= 0 or actor.cards.is_empty():
			return
		# The top of the deck is its far end.
		var first := engine.deck.size() - count
		var top: Array = engine.deck.slice(first)
		var d := Decision.new(Decision.Kind.PICK, actor)
		d.prompt = Loc.t("%s, the top of the deck: take a card, or leave them buried") % actor.name
		d.cancellable = true
		d.context = {
			"play": play, "foreign": true,
			# A bot would rather dig up something it doesn't hold yet.
			"weights": top.map(func(card): return 0.4 if actor.has_character(card) else 1.5),
		}
		d.options = top.map(func(card): return {
			"label": Content.character(card).display_name, "description": "", "card": card,
		})
		var taken: int = await engine.ask(d)
		if taken < 0 or taken >= count or engine.over or not actor.alive:
			return
		var given := await engine.pick_own_card(actor, Loc.t("%s, which card do you bury in its place?") % actor.name)
		await engine.trade_with_deck(actor, given, first + taken, &"exhume")

	func ai_weight(_player: PlayerState, _engine: GameEngine) -> float:
		return 0.6


class LastRites extends Ability:
	func _init() -> void:
		id = &"gravedigger.last_rites"
		display_name = "Last Rites"
		description = "Take every coin they left behind."
		trigger_text = "When another player is eliminated"

	func reacts_to(event: GameEvent, player: PlayerState, _engine: GameEngine) -> bool:
		return (event.type == &"player_eliminated" and event.data.player != player
				and event.data.player.coins > 0)

	func resolve(play: Play) -> void:
		var engine := play.engine
		var dead: PlayerState = play.event.data.player
		var amount := dead.coins
		if amount <= 0:
			return
		# Nobody is left to defend that purse: no before_steal.
		await engine.change_coins(dead, -amount, &"stolen", play.actor)
		await engine.gain_coins(play.actor, amount, &"steal", dead)
