extends CharacterDef
## Dolores "Snake Eyes" Quinn. The house always wins, and she is the house.
##
## Side bets ride on the doubted claim (Play.params) until its reveal, which
## pays them out here.

const ANTE := 2
const JACKPOT := 6
const STAKE := 2
const PRIZE := 6
## Play.params key on a doubted claim: [{player, lie}], one per bet placed.
const BETS := "side_bets"


func _init() -> void:
	id = &"gambler"
	display_name = "Gambler"
	title = "Dolores \"Snake Eyes\" Quinn"
	texture_path = "res://assets/cards/Gambler.png"
	order = 120
	_add(DoubleDown.new())
	_add(SideBet.new())


func on_event(event: GameEvent, engine: GameEngine) -> void:
	if event.type != &"doubt_revealed":
		return
	var bets: Array = event.data.play.params.get(BETS, [])
	var lied: bool = not event.data.truthful
	for bet: Dictionary in bets.duplicate():
		var gambler: PlayerState = bet.player
		if engine.over or not gambler.alive:
			continue
		if bet.lie == lied:
			await engine.note(gambler, "%s wins the side bet.")
			await engine.gain_coins(gambler, PRIZE, &"side_bet")
		else:
			await engine.note(gambler, "%s loses the side bet.", false)
	bets.clear()


class DoubleDown extends Ability:
	func _init() -> void:
		id = &"gambler.double_down"
		display_name = "Double Down"
		description = "Pay %d coins and flip a coin. Tails: gain %d coins. Heads: nothing." % [ANTE, JACKPOT]
		on_turn = true
		cost = ANTE

	func resolve(play: Play) -> void:
		if not await play.engine.flip_coin(play.actor, false):
			await play.engine.gain_coins(play.actor, JACKPOT, &"double_down")

	func ai_weight(_player: PlayerState, _engine: GameEngine) -> float:
		return 1.1


class SideBet extends Ability:
	func _init() -> void:
		id = &"gambler.side_bet"
		display_name = "Side Bet"
		description = "Pay %d coins and bet on who is right. Call it and gain %d coins." % [STAKE, PRIZE]
		trigger_text = "When someone calls LIAR! on another player"
		cost = STAKE

	func reacts_to(event: GameEvent, player: PlayerState, _engine: GameEngine) -> bool:
		return (event.type == &"doubt_declared" and event.data.play.actor != player
				and event.data.doubter != player)

	func prepare(play: Play) -> bool:
		var doubted: Play = play.event.data.play
		var doubter: PlayerState = play.event.data.doubter
		var d := Decision.new(Decision.Kind.PICK, play.actor)
		d.prompt = Loc.t("%s calls LIAR! on %s. Who do you bet on?") % [doubter.name, doubted.actor.name]
		d.cancellable = true
		d.context = {"play": play, "weights": _hunch(play.actor, doubted, play.engine)}
		d.options = [
			{"label": Loc.t("%s lied") % doubted.actor.name, "description": ""},
			{"label": Loc.t("%s told the truth") % doubted.actor.name, "description": ""},
		]
		var index: int = await play.engine.ask(d)
		if index < 0 or index > 1:
			return false
		play.params["lie"] = index == 0
		return true

	func resolve(play: Play) -> void:
		var doubted: Play = play.event.data.play
		if not doubted.params.has(BETS):
			doubted.params[BETS] = []
		doubted.params[BETS].append({"player": play.actor, "lie": play.params.get("lie", true)})

	## What a bot makes of the claim, as PICK weights for [lied, told the truth].
	func _hunch(player: PlayerState, doubted: Play, engine: GameEngine) -> Array:
		# Every copy in this hand is one the claimant can't be holding.
		var held := player.cards.count(doubted.ability().character_id)
		if held >= engine.copies_in_play():
			return [1.0, 0.0]
		# Few people bluff with their whole purse on the line.
		return [0.8 + held, 1.2 * BotController.oath_caution(doubted.actor, engine)]

	func ai_react_weight(_event: GameEvent, player: PlayerState, _engine: GameEngine) -> float:
		return 0.4 if player.coins >= STAKE + 2 else 0.1
