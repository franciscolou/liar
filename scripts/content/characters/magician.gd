extends CharacterDef
## Valentino Mirage. Nobody knows what is in the hat, him included.


func _init() -> void:
	id = &"magician"
	display_name = "Magician"
	title = "Valentino Mirage"
	texture_path = "res://assets/cards/Magician.png"
	order = 60
	_add(HatTrick.new())
	_add(Counterfeit.new())


class HatTrick extends Ability:
	func _init() -> void:
		id = &"magician.hat_trick"
		display_name = "Hat Trick"
		description = "Pay 2 coins to pull a random item out of the hat."
		on_turn = true
		cost = 2

	func can_use(player: PlayerState, engine: GameEngine) -> String:
		if _hat(engine).is_empty():
			return Loc.t("No items in this match")
		return Loc.t("Inventory full") if player.items.size() >= engine.config.inventory_limit else ""

	func resolve(play: Play) -> void:
		var engine := play.engine
		var hat := _hat(engine)
		await engine.give_item(play.actor, hat[engine.rng.randi_range(0, hat.size() - 1)])

	func _hat(engine: GameEngine) -> Array:
		return engine.fixed_items + engine.item_pool

	# A bot leaves its last slot for an item it chose: three things out of a
	# hat can fill an inventory with nothing that ends a match.
	func ai_weight(player: PlayerState, engine: GameEngine) -> float:
		return 0.0 if player.items.size() >= engine.config.inventory_limit - 1 else 1.0


class Counterfeit extends Ability:
	const DISCOUNT := 3

	func _init() -> void:
		id = &"magician.counterfeit"
		display_name = "Counterfeit"
		description = "Copy an item from the shop or from another player, paying up to 3 coins less."
		on_turn = true

	func can_use(player: PlayerState, engine: GameEngine) -> String:
		if player.items.size() >= engine.config.inventory_limit:
			return Loc.t("Inventory full")
		for def: ItemDef in _copyable(player, engine):
			if engine.can_pay(player, _price(def)):
				return ""
		return Loc.t("Nothing affordable to copy")

	func prepare(play: Play) -> bool:
		var engine := play.engine
		var defs := _copyable(play.actor, engine).filter(
			func(def): return engine.can_pay(play.actor, _price(def)))
		var d := Decision.new(Decision.Kind.PICK, play.actor)
		d.prompt = Loc.t("Which item do you copy?")
		d.cancellable = true
		d.context = {"play": play}
		d.options = defs.map(func(def): return {
			"label": "%s (%d)" % [def.display_name, _price(def)],
			"description": def.description, "item": def,
		})
		var index: int = await engine.ask(d)
		if index < 0 or index >= defs.size():
			return false
		play.params["item"] = defs[index]
		play.cost = _price(defs[index])
		return true

	func resolve(play: Play) -> void:
		await play.engine.give_item(play.actor, play.params.get("item"))

	func _price(def: ItemDef) -> int:
		return maxi(def.price - DISCOUNT, 0)

	func _copyable(player: PlayerState, engine: GameEngine) -> Array:
		var defs := engine.items_on_sale()
		for p: PlayerState in engine.opponents(player):
			for instance: ItemInstance in p.items:
				if not instance.hidden and not defs.has(instance.def):
					defs.append(instance.def)
		return defs
