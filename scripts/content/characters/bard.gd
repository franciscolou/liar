extends CharacterDef
## Alistair "Silver Tongue" Rhys. Leaves with your purse and your name.


func _init() -> void:
	id = &"bard"
	display_name = "Bard"
	title = "Alistair \"Silver Tongue\" Rhys"
	texture_path = "res://assets/cards/Bard.png"
	order = 100
	_add(Swindle.new())
	_add(SilverTongue.new())


class Swindle extends Ability:
	func _init() -> void:
		id = &"bard.swindle"
		display_name = "Swindle"
		description = "Steal every coin from a player and trade this card for one of theirs. They choose which."
		on_turn = true
		targeting = Targeting.OPPONENT
		tags = [&"steal"]

	func resolve(play: Play) -> void:
		var engine := play.engine
		var actor := play.actor
		var target := play.target
		await engine.steal_coins(actor, target, target.coins, play)
		if engine.over or not actor.alive or not target.alive or target.cards.is_empty():
			return
		var given := actor.cards.find(character_id)
		if given == -1:
			given = engine.random_card_index(actor)
		var d := Decision.new(Decision.Kind.PICK, target)
		d.prompt = Loc.t("%s swindled you. Which card do you hand over?") % actor.name
		d.context = {"play": play}
		d.options = target.cards.map(func(card): return {
			"label": Content.character(card).display_name, "description": "", "card": card,
		})
		var taken: int = await engine.ask(d)
		if taken < 0 or taken >= target.cards.size():
			taken = engine.random_card_index(target)
		await engine.swap_cards(actor, given, target, taken)

	func ai_weight(_player: PlayerState, _engine: GameEngine) -> float:
		return 1.6

	func ai_target_weight(_play: Play, candidate: PlayerState) -> float:
		return 0.2 + candidate.coins


class SilverTongue extends Ability:
	func _init() -> void:
		id = &"bard.silver_tongue"
		display_name = "Silver Tongue"
		description = "Keep your coins: you are immune to abilities and items that steal. A Swindle aimed at you is cancelled outright, card trade included."
		trigger_text = "When someone steals coins from you or Swindles you"

	func reacts_to(event: GameEvent, player: PlayerState, _engine: GameEngine) -> bool:
		match event.type:
			&"claim_resolving":
				# Negates the whole Swindle, even if there are no coins to take.
				var incoming: Play = event.data.play
				return incoming.source.id == &"bard.swindle" and incoming.target == player
			&"before_steal":
				if event.data.victim != player:
					return false
				# A Swindle was already offered above; only a reflected one gets here unasked.
				var cause: Play = event.data.play
				return cause == null or cause.source.id != &"bard.swindle" or cause.reflected
		return false

	func resolve(play: Play) -> void:
		play.event.cancelled = true
