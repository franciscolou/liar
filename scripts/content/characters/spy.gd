extends CharacterDef
## M. Bones. Information and discretion.


func _init() -> void:
	id = &"spy"
	display_name = "Spy"
	title = "M. Bones"
	texture_path = "res://assets/cards/Spy.png"
	order = 10
	_add(SneakPeek.new())
	_add(Untraceable.new())


class SneakPeek extends Ability:
	func _init() -> void:
		id = &"spy.sneak_peek"
		display_name = "Sneak Peek"
		description = "See a card of your choice from a player. Then you may trade it for a card of yours, of your choice."
		on_turn = true
		targeting = Targeting.OPPONENT

	func resolve(play: Play) -> void:
		var engine := play.engine
		var spy := play.actor
		var owner := play.target
		var index := await engine.peek_card(spy, owner)
		if index < 0 or engine.over or not spy.alive or not owner.alive or spy.cards.is_empty():
			return
		if index >= owner.cards.size():
			return
		# The hand was reached already, for the peek: no second chance to hide it.
		var mine := await _trade_for(play, owner.cards[index])
		if mine >= 0 and mine < spy.cards.size() and index < owner.cards.size() and not engine.over:
			await engine.swap_cards(spy, mine, owner, index, true)

	## Which card of theirs the Spy hands over for `seen`, -1 to keep it all.
	func _trade_for(play: Play, seen: StringName) -> int:
		var spy := play.actor
		var d := Decision.new(Decision.Kind.PICK, spy)
		d.prompt = Loc.t("Trade %s's %s for one of your cards?") % [play.target.name, Content.character(seen).display_name]
		d.cancellable = true
		d.options = spy.cards.map(func(card): return {
			"label": Content.character(card).display_name, "card": card,
		})
		# Bots trade a card they hold twice, or now and then for one they lack.
		var weights: Array = spy.cards.map(func(card) -> float:
			if card == seen:
				return 0.0
			return 1.5 if spy.cards.count(card) > 1 else (0.35 if not spy.cards.has(seen) else 0.0))
		d.context = {"play": play, "weights": weights, "pass": 1.0, "cancel": "Keep my cards"}
		var index: int = await play.engine.ask(d)
		return index if index >= 0 and index < spy.cards.size() else -1


class Untraceable extends Ability:
	func _init() -> void:
		id = &"spy.untraceable"
		display_name = "Untraceable"
		description = "Your cards and items can't be seen or manipulated."
		trigger_text = "When another player is about to see or mess with your cards or your items"

	# Their own hand and items.
	func for_oneself(_event: GameEvent, _player: PlayerState) -> bool:
		return true

	func reacts_to(event: GameEvent, player: PlayerState, _engine: GameEngine) -> bool:
		# Their hand (GameEngine.reach_hand) or what they hold (reach_items).
		return (event.type == &"before_hand_reach" or event.type == &"before_item_reach") and event.data.owner == player

	func resolve(play: Play) -> void:
		play.event.cancelled = true

	func ai_react_weight(event: GameEvent, player: PlayerState, _engine: GameEngine) -> float:
		# A Last Call asks every hand: with no copy of the card there is
		# nothing to keep, but now and then a hand vanishes all the same.
		if event.type == &"before_hand_reach" and event.data.how == &"recall" and not player.cards.has(event.data.card):
			return 0.15
		return 0.85
