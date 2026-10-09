extends CharacterDef
## Sheriff Amos Harlan. The law in Carcaj comes with a price list.

const TOLL := 3


func _init() -> void:
	id = &"sheriff"
	display_name = "Sheriff"
	title = "Sheriff Amos Harlan"
	texture_path = "res://assets/cards/Sheriff.png"
	order = 150
	_add(Shakedown.new())
	_add(Confiscate.new())


class Shakedown extends Ability:
	func _init() -> void:
		id = &"sheriff.shakedown"
		display_name = "Shakedown"
		description = "Steal %d coins from a player." % TOLL
		on_turn = true
		targeting = Targeting.OPPONENT
		tags = [&"steal"]

	func can_use(player: PlayerState, engine: GameEngine) -> String:
		return "" if engine.targetable_opponents(player).any(_has_coins) else Loc.t("Nobody has coins to take")

	func target_candidates(play: Play) -> Array:
		return play.engine.targetable_opponents(play.actor).filter(_has_coins)

	func resolve(play: Play) -> void:
		await play.engine.steal_coins(play.actor, play.target, TOLL, play)

	func _has_coins(p: PlayerState) -> bool:
		return p.coins > 0

	func ai_weight(_player: PlayerState, _engine: GameEngine) -> float:
		return 1.4

	func ai_target_weight(_play: Play, candidate: PlayerState) -> float:
		return float(mini(candidate.coins, TOLL))


class Confiscate extends Ability:
	func _init() -> void:
		id = &"sheriff.confiscate"
		display_name = "Confiscate"
		description = "Pay 3 coins to seize an item from a player. You choose which; a hidden item is taken blind."
		on_turn = true
		cost = 3
		targeting = Targeting.OPPONENT

	func can_use(player: PlayerState, engine: GameEngine) -> String:
		return Loc.t("Inventory full") if player.items.size() >= engine.config.inventory_limit else ""

	func target_candidates(play: Play) -> Array:
		return play.engine.targetable_opponents(play.actor).filter(
			func(p): return not p.items.is_empty())

	func resolve(play: Play) -> void:
		var engine := play.engine
		var target := play.target
		if target.items.is_empty():
			# Only a rope that came back off a mirror is thrown at empty hands.
			await engine.fire(&"item_missed", {"thief": play.actor, "victim": target})
			return
		var index := 0
		if target.items.size() > 1:
			var d := Decision.new(Decision.Kind.PICK, play.actor)
			d.prompt = Loc.t("Which of %s's items do you seize?") % target.name
			# Picked where they lie, in the target's own box (see table._open_pick).
			d.context = {"play": play, "held_by": target}
			d.options = target.items.map(_option)
			index = await engine.ask(d)
			if index < 0 or index >= target.items.size():
				index = engine.rng.randi_range(0, target.items.size() - 1)
		if not engine.over and target.alive and index < target.items.size():
			await engine.take_item(play.actor, target, target.items[index])

	func _option(instance: ItemInstance) -> Dictionary:
		if instance.hidden:
			return {"label": Loc.t("Hidden item"), "description": "", "item": null, "hidden": true}
		return {"label": instance.def.display_name, "description": instance.def.description, "item": instance.def}

	func ai_weight(_player: PlayerState, _engine: GameEngine) -> float:
		return 1.3

	func ai_target_weight(_play: Play, candidate: PlayerState) -> float:
		return float(candidate.items.size())
