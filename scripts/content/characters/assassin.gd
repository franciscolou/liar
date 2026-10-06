extends CharacterDef
## Vincent "Clean Cut" Shaw. Never misses, never brags.


func _init() -> void:
	id = &"assassin"
	display_name = "Assassin"
	title = "Vincent \"Clean Cut\" Shaw"
	texture_path = "res://assets/cards/Assassin.png"
	order = 80
	_add(BloodCount.new())
	_add(StreakThirst.new())


class BloodCount extends Ability:
	func _init() -> void:
		id = &"assassin.blood_count"
		display_name = "Blood Count"
		description = "Pay 4 coins to deal 1 damage to a player."
		on_turn = true
		cost = 4
		targeting = Targeting.OPPONENT
		tags = [&"damage"]

	func resolve(play: Play) -> void:
		await play.engine.deal_damage(play.actor, play.target, play)

	func ai_weight(_player: PlayerState, _engine: GameEngine) -> float:
		return 2.5

	func ai_target_weight(_play: Play, candidate: PlayerState) -> float:
		return 1.0 + (3 - candidate.morale)


class StreakThirst extends Ability:
	func _init() -> void:
		id = &"assassin.streak_thirst"
		display_name = "Streak Thirst"
		description = "Pay 4 coins to deal 1 damage to another player."
		trigger_text = "When you eliminate a player"
		cost = 4
		targeting = Targeting.OPPONENT
		tags = [&"damage"]
		self_chain = true

	func reacts_to(event: GameEvent, player: PlayerState, _engine: GameEngine) -> bool:
		return event.type == &"player_eliminated" and event.data.killer == player

	func resolve(play: Play) -> void:
		await play.engine.deal_damage(play.actor, play.target, play)

	func ai_target_weight(_play: Play, candidate: PlayerState) -> float:
		return 1.0 + (3 - candidate.morale)
