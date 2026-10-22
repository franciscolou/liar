extends CharacterDef
## Ezekiel Ashgrave. Every wound he takes is owed back, and every soul that
## falls by his hand keeps him on his feet a little longer.


func _init() -> void:
	id = &"necromancer"
	display_name = "Necromancer"
	title = "Ezekiel Ashgrave"
	texture_path = "res://assets/cards/Necromancer.png"
	order = 220
	_add(Retaliation.new())
	_add(Drain.new())


## The blow comes back to whoever dealt it. It is aimed at them like any other
## damage: a shield stops it, a mirror sends it back to the Necromancer.
class Retaliation extends Ability:
	func _init() -> void:
		id = &"necromancer.retaliation"
		display_name = "Retaliation"
		description = "Deal 1 damage to whoever damaged you."
		trigger_text = "When another player deals damage to you"
		# Nobody to choose: the one who dealt the blow is the only candidate.
		targeting = Targeting.RANDOM
		tags = [&"damage"]

	func reacts_to(event: GameEvent, player: PlayerState, _engine: GameEngine) -> bool:
		if event.type != &"damage_dealt" or event.data.target != player:
			return false
		# A Retaliation is never answered with another, not even one a mirror
		# turned round: the blow it deals is the end of it.
		var blow: Variant = event.data.get("play")
		if blow is Play and blow.source is Retaliation:
			return false
		var source: PlayerState = event.data.source
		return source != null and source != player and source.alive

	# Asked with no event (is it usable at all?), anyone could have struck.
	func target_candidates(play: Play) -> Array:
		var candidates := play.engine.targetable_opponents(play.actor)
		if play.event == null:
			return candidates
		var source: Variant = play.event.data.get("source")
		return candidates.filter(func(p): return p == source)

	func resolve(play: Play) -> void:
		await play.engine.deal_damage(play.actor, play.target, play)

	func ai_react_weight(_event: GameEvent, player: PlayerState, _engine: GameEngine) -> float:
		# On the last Morale a lie caught would be the end of them.
		return 0.5 if player.morale <= 1 else 0.85

	func ai_target_weight(_play: Play, _candidate: PlayerState) -> float:
		return 1.0


class Drain extends Ability:
	func _init() -> void:
		id = &"necromancer.drain"
		display_name = "Drain"
		description = "Recover 1 Morale."
		trigger_text = "When you eliminate a player"
		tags = [&"heal"]

	func reacts_to(event: GameEvent, player: PlayerState, _engine: GameEngine) -> bool:
		return event.type == &"player_eliminated" and event.data.killer == player

	func can_use(player: PlayerState, engine: GameEngine) -> String:
		return Loc.t("Morale is full") if player.morale >= engine.config.start_morale else ""

	func resolve(play: Play) -> void:
		await play.engine.heal(play.actor, 1)
