extends CharacterDef
## Alistair "Silver Tongue" Rhys. The money was on its way to you; it got to him.


func _init() -> void:
	id = &"bard"
	display_name = "Bard"
	title = "Alistair \"Silver Tongue\" Rhys"
	texture_path = "res://assets/cards/Bard.png"
	order = 100
	_add(Swindle.new())
	_add(SilverTongue.new())


class Swindle extends Ability:
	## What the coins are gained as once they changed course.
	const HAUL := &"swindle"

	func _init() -> void:
		id = &"bard.swindle"
		display_name = "Swindle"
		description = "Those coins go to you instead."
		trigger_text = "When another player is about to gain coins, other than the income of their turn"
		tags = [&"steal"]

	func reacts_to(event: GameEvent, player: PlayerState, _engine: GameEngine) -> bool:
		if event.type != &"before_gain" or event.data.player == player:
			return false
		# Coins that already changed course once stay where they went.
		return event.data.amount > 0 and event.data.reason != &"income" and event.data.reason != HAUL

	func prepare(play: Play) -> bool:
		if play.event == null:
			return false
		play.mark = play.event.data.player
		return true

	func resolve(play: Play) -> void:
		var gain := play.event
		var amount: int = gain.data.amount
		if amount <= 0:
			return
		gain.data.amount = 0
		await play.engine.gain_coins(play.actor, amount, HAUL, gain.data.player)

	func ai_react_weight(event: GameEvent, _player: PlayerState, _engine: GameEngine) -> float:
		return clampf((event.data.amount - 1) / 5.0, 0.0, 0.9)

	func ai_suspicion(play: Play, doubter: PlayerState) -> float:
		return 0.25 if play.mark == doubter else 0.0


class SilverTongue extends Ability:
	func _init() -> void:
		id = &"bard.silver_tongue"
		display_name = "Silver Tongue"
		description = "Keep your coins: you are immune to abilities and items that steal."
		trigger_text = "When someone steals coins from you"

	func reacts_to(event: GameEvent, player: PlayerState, _engine: GameEngine) -> bool:
		return event.type == &"before_steal" and event.data.victim == player

	func resolve(play: Play) -> void:
		play.event.cancelled = true
