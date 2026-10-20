extends CharacterDef
## Monsieur Vermeil. Everything has a price, and every price is a colour.
##
## All Is Color is a turn action: for as long as it lasts the Painter turns
## the items he holds back into coins, at what the shop asks for them, and
## buys from the shop with whatever he has (two Russian Roulettes and a few
## coins are a Death). It does not end his turn, so what he bought can be
## used at once. So that it is no free way to go through the whole shop, it
## is once per turn, nothing bought in it can be sold again in the same go,
## and a slot emptied in it is only restocked once he is done.
##
## Monochrome paints two players (he may be one of them) the same colour.
## During their own turns they are only to deal with each other: anything a
## painted player does on their turn that reaches somebody else costs them
## TOLL coins, paid to the Painter (the bank makes up what they don't have),
## and the paint stays. It comes off once its wearer's next turn is over.

const PAINTED := &"painted"
const TOLL := 4
## The paints, for the table only: nothing in the rules tells them apart.
const PAINTS := [Color("4f8fe0"), Color("e877b8"), Color("f2cf3c")]
const PAINT_NAMES := ["Blue", "Pink", "Yellow"]
## How many trades one All Is Color takes at most (a bot that won't stop).
const MAX_TRADES := 24


func _init() -> void:
	id = &"painter"
	display_name = "Painter"
	title = "Monsieur Vermeil"
	texture_path = "res://assets/cards/Painter.png"
	order = 200
	status_defs = {
		PAINTED: {
			"name": "Painted",
			"description": "Painted the same colour as another player. On their own turn they are to deal only with that player: whatever they do that reaches anyone else pays the Painter %d coins. It comes off when this player's next turn ends.", "args": [TOLL],
			"color": PAINTS[0],
			# Bots steer clear of anyone else on their own turn (BotController._target).
			"ai_stray": 0.12,
		},
	}
	_add(AllIsColor.new())
	_add(Monochrome.new())


## The one `player` was painted with, or null.
static func partner_of(player: PlayerState, engine: GameEngine) -> PlayerState:
	return Monochrome.partner(player, engine)


func on_event(event: GameEvent, engine: GameEngine) -> void:
	match event.type:
		&"turn_ended":
			var wearer: PlayerState = event.data.player
			# Painted during this very turn (by themselves, or on the
			# Painter's turn): it lasts through their next one.
			if wearer.alive and wearer.has_status(PAINTED) and wearer.statuses[PAINTED].get("planted", 0) < engine.turn_count:
				await engine.remove_status(wearer, PAINTED)
		&"player_eliminated":
			var dead: PlayerState = event.data.player
			for p: PlayerState in engine.players:
				if p.alive and p.has_status(PAINTED) and p.statuses[PAINTED].get("by", -1) == dead.id:
					await engine.remove_status(p, PAINTED)
		_:
			await _check_toll(event, engine)


## Charges the toll if `event` is a painted player, on their own turn,
## reaching somebody other than the one they were painted with.
func _check_toll(event: GameEvent, engine: GameEngine) -> void:
	if engine.over:
		return
	var doer := engine.current
	if doer == null or not doer.alive or not doer.has_status(PAINTED):
		return
	var reached := _reached(event, doer)
	if reached.is_empty():
		return
	var partner := partner_of(doer, engine)
	if not reached.any(func(p: PlayerState) -> bool: return p != doer and p != partner):
		return
	# Whatever a play goes on to do is still that one play: one thing done is
	# one toll. What was charged for is kept with the turn being played.
	var key: Variant = engine._resolving[0] if not engine._resolving.is_empty() else event
	var tolled: Array = doer.turn.get_or_add("paint_tolled", [])
	if tolled.has(key):
		return
	tolled.append(key)
	var painter := engine.player_by_id(doer.statuses[PAINTED].get("by", -1))
	if painter == null or not painter.alive or painter == doer:
		return
	await engine.note(doer, "%s steps outside the paint.", false, &"paint_toll")
	var owed := mini(TOLL, maxi(doer.coins, 0))
	if owed > 0:
		await engine.change_coins(doer, -owed, &"paint_toll")
	if not engine.over and painter.alive:
		await engine.gain_coins(painter, TOLL, &"paint")


## Who `doer` reaches with `event`, as far as the paint goes: none if it is
## not their doing.
func _reached(event: GameEvent, doer: PlayerState) -> Array:
	var d := event.data
	match event.type:
		&"play_effect":
			var play: Play = d.play
			if play.actor == doer and play.whom() != null:
				return [play.whom()]
		&"damage_dealt":
			if d.source == doer:
				return [d.target]
		&"item_stolen":
			if d.thief == doer:
				return [d.victim]
		&"coins":
			if (d.reason == &"stolen" or d.reason == &"hexed") and d.other == doer:
				return [d.player]
		&"card_peeked":
			if d.viewer == doer:
				return [d.owner]
		&"cards_swapped":
			if d.a == doer:
				return [d.b]
		&"cards_recalled":
			if d.player == doer:
				return d.hands.map(func(hand: Dictionary) -> PlayerState: return hand.player)
		&"status_added":
			if d.player != doer and d.player.statuses.get(d.status, {}).get("by", -1) == doer.id and d.status != PAINTED:
				return [d.player]
	return []


class AllIsColor extends Ability:
	func _init() -> void:
		id = &"painter.all_is_color"
		display_name = "All Is Color"
		description = "Trade with the shop using your items as coins, at their price: turn them into coins and buy whatever you can pay for, as many times as you like. What you buy here can't be turned back into coins in the same go, and the shelves are only restocked once you are done. Once per turn; it does not consume the turn, so what you bought can be used right away."
		on_turn = true
		# What he bought is for using in the same turn.
		ends_turn = false
		# Not the action of a turn: there is nothing in it for a disguise.
		repeatable = false

	func can_use(player: PlayerState, _engine: GameEngine) -> String:
		if player.turn.get("all_is_color", false):
			return Loc.t("Once per turn")
		return Loc.t("You have no items to paint with") if player.items.is_empty() else ""

	# Once per turn, whatever becomes of the claim: no going round the shop
	# claim after claim.
	func prepare(play: Play) -> bool:
		play.actor.turn["all_is_color"] = true
		return true

	func resolve(play: Play) -> void:
		var engine := play.engine
		var painter := play.actor
		# Bought in this go: not for sale again until it is over.
		var fresh: Array = []
		# Slots bought out in this go: restocked once it is over.
		var emptied: Array = []
		for step: int in MAX_TRADES:
			if engine.over or not painter.alive:
				break
			var options := _options(play, fresh)
			var d := Decision.new(Decision.Kind.PICK, painter)
			d.prompt = Loc.t("All Is Color: paint with what you hold")
			d.cancellable = true
			d.options = options
			d.context = {
				"play": play, "look": &"palette", "again": step > 0,
				"weights": options.map(func(o: Dictionary) -> float: return 0.0 if o.get("disabled", false) else o.weight),
				"pass": 0.8 + 0.35 * step,
			}
			var pick: int = await engine.ask(d)
			if pick < 0 or pick >= options.size() or engine.over:
				break
			var option: Dictionary = options[pick]
			if option.get("disabled", false):
				continue
			match option.does:
				&"sell":
					if painter.items.has(option.instance):
						await engine.sell_item(painter, option.instance, option.coins)
				&"buy":
					var before := painter.items.size()
					if await engine.buy_item(painter, option.item, option.slot, false):
						if painter.items.size() > before:
							fresh.append(painter.items.back())
						if option.slot >= 0:
							emptied.append(option.slot)
		for slot: int in emptied:
			if engine.over:
				return
			await engine.restock_slot(slot)

	## What the Painter may do right now: sell what he held before this go,
	## buy what is on the shelves.
	func _options(play: Play, fresh: Array) -> Array:
		var engine := play.engine
		var painter := play.actor
		var out := []
		for instance: ItemInstance in painter.items:
			if fresh.has(instance):
				continue
			out.append({
				"does": &"sell", "instance": instance, "item": instance.def, "coins": instance.def.price,
				"label": Loc.t("Sell %s") % instance.def.display_name,
				"description": Loc.t("Turn it into %d coins.") % instance.def.price,
				# Bots let go of what they are not keen on.
				"weight": maxf(0.05, 0.6 - instance.def.ai_buy_weight(painter, engine) * 0.3),
			})
		var full := painter.items.size() >= engine.config.inventory_limit
		var stock := []
		for def: ItemDef in engine.fixed_items:
			if not def.service:
				stock.append([def, -1])
		for slot: int in engine.shop.size():
			if engine.shop[slot] != null and not engine.shop[slot].service:
				stock.append([engine.shop[slot], slot])
		for entry: Array in stock:
			var def: ItemDef = entry[0]
			var cost := engine.price(painter, def.price)
			var reason := ""
			if full:
				reason = Loc.t("Inventory full")
			elif not engine.can_pay(painter, cost):
				reason = Loc.t("Not enough coins")
			out.append({
				"does": &"buy", "item": def, "slot": entry[1], "price": cost,
				"label": Loc.t("Buy %s") % def.display_name, "description": def.description,
				"disabled": reason != "", "reason": reason,
				"weight": def.ai_buy_weight(painter, engine) * (2.0 if cost <= painter.coins else 0.0),
			})
		return out

	func ai_weight(player: PlayerState, engine: GameEngine) -> float:
		# Worth it with something to sell and something better to buy.
		var worth := 0
		for instance: ItemInstance in player.items:
			worth += instance.def.price
		return 0.25 + 0.06 * mini(worth + player.coins, 16) if engine.items_on_sale().size() > 1 else 0.1


class Monochrome extends Ability:
	func _init() -> void:
		id = &"painter.monochrome"
		display_name = "Monochrome"
		describe("Paint two players the same colour (you may be one of them). On their own turns they can only deal with each other: whatever they do that reaches anyone else pays you %d coins, and the paint stays. It comes off at the end of each one's next turn.", [TOLL])
		on_turn = true
		inflicts = true

	func can_use(_player: PlayerState, engine: GameEngine) -> String:
		return Loc.t("Not enough players") if engine.alive_players().size() < 3 else ""

	# Both picked before the claim is announced, the Painter among them if he likes.
	func prepare(play: Play) -> bool:
		var engine := play.engine
		var pair := []
		for nth: int in 2:
			var candidates := engine.seat_order(play.actor).filter(func(p: PlayerState) -> bool: return not pair.has(p))
			var d := Decision.new(Decision.Kind.PICK, play.actor)
			d.prompt = Loc.t("Who gets the first coat?") if nth == 0 else Loc.t("Who is painted the same colour as %s?") % pair[0].name
			d.cancellable = true
			d.options = candidates.map(func(p: PlayerState) -> Dictionary: return {
				"label": Loc.t("Yourself") if p == play.actor else p.name, "player": p,
				"description": "",
			})
			d.context = {
				"play": play,
				"weights": candidates.map(func(p: PlayerState) -> float: return _ai_pick(play, p)),
			}
			var index: int = await engine.ask(d)
			if index < 0 or index >= candidates.size():
				return false
			pair.append(candidates[index])
		play.params["pair"] = pair.map(func(p: PlayerState) -> int: return p.id)
		# The table points at whoever of them is not the Painter.
		play.mark = pair[0] if pair[0] != play.actor else pair[1]
		return true

	func resolve(play: Play) -> void:
		var engine := play.engine
		var pair: Array = play.params.get("pair", []).map(func(id: int) -> PlayerState: return engine.player_by_id(id))
		if pair.size() != 2 or pair.any(func(p: PlayerState) -> bool: return p == null or not p.alive):
			return
		# A fresh coat takes the old one off, and off whoever shared it.
		for p: PlayerState in pair:
			var old := partner(p, engine)
			if old != null and old.alive and not pair.has(old) and old.statuses.get(PAINTED, {}).get("partner", -1) == p.id:
				await engine.remove_status(old, PAINTED)
		var paint: int = engine.turn_count % PAINTS.size()
		for i: int in 2:
			if engine.over or not pair[i].alive:
				return
			await engine.add_status(pair[i], PAINTED, {
				"by": play.actor.id, "partner": pair[1 - i].id, "planted": engine.turn_count,
				"tint": PAINTS[paint], "paint": paint,
			})

	## See partner_of.
	static func partner(player: PlayerState, engine: GameEngine) -> PlayerState:
		if not player.has_status(PAINTED):
			return null
		return engine.player_by_id(player.statuses[PAINTED].get("partner", -1))

	## How much a bot likes painting `p`: two strong opponents, to keep them
	## busy with each other; itself now and then, with a weak one.
	func _ai_pick(play: Play, p: PlayerState) -> float:
		if p == play.actor:
			return 0.25
		return 1.0 + p.coins * 0.06 + p.items.size() * 0.3 + p.morale * 0.2

	func ai_weight(_player: PlayerState, _engine: GameEngine) -> float:
		return 1.1
