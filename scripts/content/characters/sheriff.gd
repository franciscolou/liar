extends CharacterDef
## Sheriff Amos Harlan. The law in Carcaj comes with a price list.

const TOLL := 2


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
		description = "Take %d coins from every other player." % TOLL
		on_turn = true
		tags = [&"steal"]

	func can_use(player: PlayerState, engine: GameEngine) -> String:
		return "" if not _marks(player, engine).is_empty() else Loc.t("Nobody has coins to take")

	func resolve(play: Play) -> void:
		var engine := play.engine
		for mark: PlayerState in _marks(play.actor, engine):
			if engine.over or not play.actor.alive:
				return
			if mark.alive:
				await engine.steal_coins(play.actor, mark, TOLL, play)

	## Everyone the round goes through, in turn order. Nobody is aimed at, but
	## a player out of sight is passed over all the same.
	func _marks(player: PlayerState, engine: GameEngine) -> Array:
		return engine.seat_order(player).filter(
			func(p): return p != player and p.coins > 0 and not p.has_status(&"untargetable"))

	func ai_weight(player: PlayerState, engine: GameEngine) -> float:
		return 0.6 * _marks(player, engine).size()


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
			return
		var index := 0
		if target.items.size() > 1:
			var d := Decision.new(Decision.Kind.PICK, play.actor)
			d.prompt = Loc.t("Which of %s's items do you seize?") % target.name
			d.context = {"play": play}
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
