extends CharacterDef
## Dolores "Snake Eyes" Quinn. The house always wins, and she is the house.
##
## Side bets are not raced for. When somebody calls LIAR!, everyone who could
## bet is asked at once, with BET_SECONDS on the clock, whether they bet and
## on which side; once all of them have answered, the bets are claimed one
## after the other, by seat, each one a claim like any other (it can be
## doubted). They ride on the doubted claim (Play.params) until its reveal,
## which pays them out here. Nobody bets on the doubt of a side bet: that
## would never end.

const ANTE := 2
const JACKPOT := 8
const STAKE := 2
const PRIZE := 6
## How long the table has to place its bets.
const BET_SECONDS := 20
## Play.params key on a doubted claim: [{player, lie}], one per bet placed.
const BETS := "side_bets"
## The tag of the notes that settle a bet, and the reason of its prize.
const SIDE_BET := &"side_bet"

var _side_bet: SideBet


func _init() -> void:
	id = &"gambler"
	display_name = "Gambler"
	title = "Dolores \"Snake Eyes\" Quinn"
	texture_path = "res://assets/cards/Gambler.png"
	order = 120
	_side_bet = SideBet.new()
	_add(DoubleDown.new())
	_add(_side_bet)


func on_event(event: GameEvent, engine: GameEngine) -> void:
	match event.type:
		&"doubt_declared":
			await _take_bets(event, engine)
		&"doubt_revealed":
			await _settle_bets(event, engine)


## The round of bets on a LIAR! call: everyone at once, then claim by claim.
func _take_bets(event: GameEvent, engine: GameEngine) -> void:
	var doubted: Play = event.data.play
	var doubter: PlayerState = event.data.doubter
	if doubted.source == _side_bet or not engine.can_react():
		return
	var asked: Array = []
	for p: PlayerState in engine.seat_order(engine.current):
		if p == doubted.actor or p == doubter or not engine.ability_option(p, _side_bet).enabled:
			continue
		var hunch := _side_bet.hunch(p, doubted, engine)
		# How keen a bot is to bet at all, as the weight of not betting.
		var keen := _side_bet.ai_react_weight(event, p, engine)
		if not p.has_character(id):
			keen *= 0.25 / BotController.oath_caution(p, engine)
		var d := Decision.new(Decision.Kind.PICK, p)
		d.prompt = Loc.t("%s calls LIAR! on %s. Do you place a Side Bet?") % [doubter.name, doubted.actor.name]
		d.cancellable = true
		d.options = [
			{"label": Loc.t("%s lied") % doubted.actor.name, "description": ""},
			{"label": Loc.t("%s told the truth") % doubted.actor.name, "description": ""},
		]
		d.context = {
			"play": doubted, "look": SIDE_BET, "seconds": BET_SECONDS,
			"option": engine.ability_option(p, _side_bet),
			"weights": hunch, "pass": (hunch[0] + hunch[1]) * (1.0 - keen) / maxf(keen, 0.01),
		}
		asked.append(d)
	var answers := await engine.ask_all(asked)
	for d: Decision in asked:
		if engine.over:
			return
		var side: int = answers.get(d.player.id, -1)
		# What came before may have emptied their purse, or put them out.
		if side < 0 or side > 1 or not engine.ability_option(d.player, _side_bet).enabled:
			continue
		await engine.claim_reaction(d.player, _side_bet, event, {"lie": side == 0})


func _settle_bets(event: GameEvent, engine: GameEngine) -> void:
	var bets: Array = event.data.play.params.get(BETS, [])
	var lied: bool = not event.data.truthful
	for bet: Dictionary in bets.duplicate():
		var gambler: PlayerState = bet.player
		if engine.over or not gambler.alive:
			continue
		if bet.lie == lied:
			await engine.note(gambler, "%s wins the side bet.", true, SIDE_BET)
			await engine.gain_coins(gambler, PRIZE, SIDE_BET)
		else:
			await engine.note(gambler, "%s loses the side bet.", false, SIDE_BET)
	bets.clear()


class DoubleDown extends Ability:
	func _init() -> void:
		id = &"gambler.double_down"
		display_name = "Double Down"
		describe("Pay %d coins and flip a coin.\n  • Tails: gain %d coins.\n  • Heads: nothing.", [ANTE, JACKPOT])
		on_turn = true
		cost = ANTE

	func resolve(play: Play) -> void:
		if not await play.engine.flip_coin(play.actor, false):
			await play.engine.gain_coins(play.actor, JACKPOT, &"double_down")

	func ai_weight(_player: PlayerState, _engine: GameEngine) -> float:
		return 1.1


## Never offered in a reaction window: the Gambler's own hook asks for it
## (see _take_bets), with the side already chosen in `params.lie`.
class SideBet extends Ability:
	func _init() -> void:
		id = &"gambler.side_bet"
		display_name = "Side Bet"
		describe("Pay %d coins and bet on who is right. Call it and gain %d coins. Using Side Bet on a doubt over another Side Bet is not allowed.", [STAKE, PRIZE])
		trigger_text = "When someone calls LIAR! on another player"
		cost = STAKE

	func prepare(play: Play) -> bool:
		return play.event != null and play.params.has("lie")

	func resolve(play: Play) -> void:
		var doubted: Play = play.event.data.play
		if not doubted.params.has(BETS):
			doubted.params[BETS] = []
		doubted.params[BETS].append({"player": play.actor, "lie": play.params.get("lie", true)})

	## What a bot makes of the claim, as PICK weights for [lied, told the truth].
	func hunch(player: PlayerState, doubted: Play, engine: GameEngine) -> Array:
		# Every copy in this hand is one the claimant can't be holding.
		var held := player.cards.count(doubted.ability().character_id)
		if held >= engine.copies_in_play():
			return [1.0, 0.0]
		# Few people bluff with their whole purse on the line.
		return [0.8 + held, 1.2 * BotController.oath_caution(doubted.actor, engine)]

	func ai_react_weight(_event: GameEvent, player: PlayerState, _engine: GameEngine) -> float:
		return 0.4 if player.coins >= STAKE + 2 else 0.1
