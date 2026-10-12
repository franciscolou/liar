extends CharacterDef
## The Entity. It was here before the table and has all the time there is.
##
## Entropy is a status its own user carries into their next turn, where it
## pays out by itself (on_event). Until then they are to keep still: reacting
## is fine, but a LIAR! call throws the chains away, unpaid. Materialize is paid in Morale, not as a blow
## but as a price (GameEngine.spend_morale): nothing gets to stop it.

const ENTROPY := &"entropy"
## What the chains break into when the next turn starts.
const ENTROPY_COINS := 3
## What the Morale is worth to someone who can't take it (full, or hexed).
const MORALE_WORTH := 2
## Why the chains go when they go for nothing (status_removed.reason).
const WASTED := &"wasted"


func _init() -> void:
	id = &"entity"
	display_name = "Entity"
	title = "The Entity"
	texture_path = "res://assets/cards/Entity.png"
	order = 180
	status_defs = {
		ENTROPY: {
			"name": "Entropy",
			"description": "In chains until this player's next turn starts. Then they break into 1 Morale and %d coins; Morale that can't be recovered becomes %d more coins. Calling LIAR! before that throws it all away.", "args": [ENTROPY_COINS, MORALE_WORTH],
			"color": Color("7f8cff"),
			# For whoever is about to call LIAR! with it on, and for the bots.
			"doubt_warning": "You are in chains: calling LIAR! throws your Entropy away, with nothing for it.",
			"ai_doubt": 0.2,
		},
	}
	_add(Entropy.new())
	_add(Materialize.new())


func on_event(event: GameEvent, engine: GameEngine) -> void:
	if event.type == &"doubt_declared":
		# Whoever is in chains was to keep still: the call costs them all of it.
		await engine.remove_status(event.data.doubter, ENTROPY, WASTED)
		return
	if event.type != &"turn_started":
		return
	var player: PlayerState = event.data.player
	if not player.has_status(ENTROPY):
		return
	await engine.remove_status(player, ENTROPY)
	if engine.over or not player.alive:
		return
	var coins := ENTROPY_COINS
	if not await engine.heal(player, 1):
		coins += MORALE_WORTH
	await engine.gain_coins(player, coins, ENTROPY)


class Entropy extends Ability:
	func _init() -> void:
		id = &"entity.entropy"
		display_name = "Entropy"
		describe("Spend your entire turn. When your next turn begins, recover 1 Morale and gain %d coins. If your Morale is full, receive %d additional coins. Calling LIAR! before receiving them cancels the effect, forfeiting the rewards.", [ENTROPY_COINS, MORALE_WORTH])
		on_turn = true
		fresh_turn = true

	func resolve(play: Play) -> void:
		await play.engine.add_status(play.actor, ENTROPY, {"by": play.actor.id})

	func ai_weight(player: PlayerState, engine: GameEngine) -> float:
		return 1.8 if player.morale < engine.config.start_morale else 1.2


class Materialize extends Ability:
	## How many coins a point of Morale buys.
	const WORTH := 6

	func _init() -> void:
		id = &"entity.materialize"
		display_name = "Materialize"
		describe("Convert 1 Morale into an item costing up to %d coins. If the item costs more, pay the difference. Keep the change if it costs less. This does not end your turn, but the item cannot be used during the same turn it was created.", [WORTH])
		on_turn = true
		ends_turn = false
		# Not the action of a turn: there is nothing in it for a disguise.
		repeatable = false

	func can_use(player: PlayerState, engine: GameEngine) -> String:
		if player.morale <= 1:
			return Loc.t("Not with your last Morale")
		if player.items.size() >= engine.config.inventory_limit:
			return Loc.t("Inventory full")
		if _makeable(engine).is_empty():
			return Loc.t("No items in this match")
		return "" if not _affordable(player, engine).is_empty() else Loc.t("Not enough coins")

	func prepare(play: Play) -> bool:
		var engine := play.engine
		var defs := _affordable(play.actor, engine)
		var d := Decision.new(Decision.Kind.PICK, play.actor)
		d.prompt = Loc.t("Which item would you like to create?")
		d.cancellable = true
		d.context = {
			"play": play,
			# Not a menu: the table hangs the options in the dark, each with
			# what it does to the purse going round it (`coins`).
			"look": &"cosmos",
			"weights": defs.map(func(def: ItemDef) -> float: return def.ai_buy_weight(play.actor, engine)),
		}
		d.options = defs.map(func(def: ItemDef) -> Dictionary: return {
			"label": _label(def, _change(def) - engine.price(play.actor, _owed(def))),
			"description": def.description, "item": def,
			"coins": _change(def) - engine.price(play.actor, _owed(def)),
		})
		var index: int = await engine.ask(d)
		if index < 0 or index >= defs.size():
			return false
		play.params["item"] = defs[index]
		play.cost = engine.price(play.actor, _owed(defs[index]))
		return true

	func resolve(play: Play) -> void:
		var engine := play.engine
		var actor := play.actor
		var def: ItemDef = play.params.get("item")
		if def == null or actor.items.size() >= engine.config.inventory_limit:
			return
		if not await engine.spend_morale(actor, 1, play):
			return
		if engine.over or not actor.alive:
			return
		await engine.give_item(actor, def, false, true)
		await engine.gain_coins(actor, _change(def), &"materialize")

	## What the Morale does not cover.
	func _owed(def: ItemDef) -> int:
		return maxi(def.price - WORTH, 0)

	## What is left of the Morale once the item is paid for.
	func _change(def: ItemDef) -> int:
		return maxi(WORTH - def.price, 0)

	## The item and what it does to the purse: "Shield (+1)", "Death (-1)".
	func _label(def: ItemDef, coins: int) -> String:
		return def.display_name if coins == 0 else "%s (%+d)" % [def.display_name, coins]

	# Out of nothing: anything this match has, on the shelf or not.
	func _makeable(engine: GameEngine) -> Array:
		return engine.fixed_items + engine.item_pool

	func _affordable(player: PlayerState, engine: GameEngine) -> Array:
		return _makeable(engine).filter(func(def: ItemDef) -> bool:
			return engine.can_pay(player, engine.price(player, _owed(def))))

	# A bot only gives up Morale it can spare, and never its last free slot.
	func ai_weight(player: PlayerState, engine: GameEngine) -> float:
		if player.morale < engine.config.start_morale or player.items.size() >= engine.config.inventory_limit - 1:
			return 0.0
		return 0.5
