extends CharacterDef
## Monsieur Vermeil. Everything has a price, and every price is a colour.
##
## All Is Color is a turn action: for as long as it lasts the Painter turns
## the items he holds back into coins, at what the shop asks for them, and
## buys from the shop with whatever he has (two Russian Roulettes and a few
## coins are a Death). It does not end his turn, so what he bought can be
## used at once. So that it is no free way to go through the whole shop, it
## is once per turn and nothing bought in it can be sold again in the same
## go (a slot bought out is restocked at once, as after any purchase).
##
## Monochrome paints two players who are not painted yet (he may be one of
## them) the same colour, chosen once the table has let the claim pass.
## During their own turns they are to keep their hands off each other:
## whenever a painted player reaches the one they were painted with on their
## turn, the bank gives the Painter TOLL coins, and the paint stays (the
## Painter reaching his own partner is paid nothing). It comes off the two of
## them once both have played a turn in it, at the end of the later one's
## turn, and only if that turn left the partner alone; if not, it waits for
## the next clean turn of either.

const PAINTED := &"painted"
const TOLL := 4
## The paints, for the table only: nothing in the rules tells them apart.
## Blue, pink and yellow; green only once those three are all on the table
## (with eight players, four pairs can be painted at once).
const PAINTS := [Color("4f8fe0"), Color("e877b8"), Color("f2cf3c"), Color("5fbf5a")]
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
			"description": "Painted the same colour as another player. On their own turn they are to keep away from that player: whenever they reach them, the bank gives the Painter %d coins. It comes off both once each has played a turn, if the last of those turns left the other one alone.", "args": [TOLL],
			"color": PAINTS[0],
			# Bots steer clear of the partner on their own turn (BotController._target).
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
			await _wear(event.data.player, engine)
		&"doubt_declared":
			# A LIAR! is no reaching out: neither the call nor what comes of
			# it counts, until the claim it was called on is over.
			var doubter: PlayerState = event.data.doubter
			if doubter == engine.current:
				doubter.turn["paint_doubting"] = event.data.play
		&"claim_resolved":
			var current := engine.current
			if current != null and current.turn.get("paint_doubting") == event.data.play:
				current.turn.erase("paint_doubting")
		&"player_eliminated":
			var dead: PlayerState = event.data.player
			for p: PlayerState in engine.players:
				if p.alive and p.has_status(PAINTED) and p.statuses[PAINTED].get("by", -1) == dead.id:
					await engine.remove_status(p, PAINTED)
		_:
			await _check_toll(event, engine)


## `wearer`'s turn is over. A turn played in the paint counts (not the one it
## was put on in); once both of the pair have played one, it comes off the
## two of them, unless this turn reached the partner.
func _wear(wearer: PlayerState, engine: GameEngine) -> void:
	if engine.over or not wearer.alive or not wearer.has_status(PAINTED):
		return
	var status: Dictionary = wearer.statuses[PAINTED]
	if status.get("planted", 0) >= engine.turn_count:
		return
	status["played"] = true
	var partner := partner_of(wearer, engine)
	var waiting: bool = partner != null and partner.alive and partner.has_status(PAINTED) \
			and not partner.statuses[PAINTED].get("played", false)
	if waiting or not wearer.turn.get("paint_tolled", []).is_empty():
		return
	await engine.remove_status(wearer, PAINTED)
	if partner != null and partner.alive and partner.has_status(PAINTED):
		await engine.remove_status(partner, PAINTED)


## Charges the toll if `event` is a painted player, on their own turn,
## reaching the one they were painted with.
func _check_toll(event: GameEvent, engine: GameEngine) -> void:
	if engine.over:
		return
	var doer := engine.current
	if doer == null or not doer.alive or not doer.has_status(PAINTED):
		return
	var reached := _reached(event, doer)
	if reached.is_empty():
		return
	# In the middle of a LIAR! of theirs only what they play themselves counts.
	if doer.turn.has("paint_doubting") and event.type != &"play_effect":
		return
	var partner := partner_of(doer, engine)
	if partner == null or not reached.has(partner):
		return
	# Whatever a play goes on to do is still that one play: one thing done is
	# one toll. What was charged for is kept with the turn being played.
	var key: Variant = engine._resolving[0] if not engine._resolving.is_empty() else event
	var tolled: Array = doer.turn.get_or_add("paint_tolled", [])
	if tolled.has(key):
		return
	tolled.append(key)
	# The Painter reaching the one he painted himself with: nobody pays him.
	var painter := engine.player_by_id(doer.statuses[PAINTED].get("by", -1))
	if painter == null or not painter.alive or painter == doer:
		return
	await engine.note(doer, "%s smudges the paint.", false, &"paint_toll")
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
		description = "Once you use this ability on your turn, you may turn your items back into coins, at the shop's price.\nThis ability does not end your turn, and the items you buy can be used right away."
		footnote = "Items bought with a surcharge don't sell for more coins."
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
					if await engine.buy_item(painter, option.item, option.slot):
						if painter.items.size() > before:
							fresh.append(painter.items.back())

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
		describe("Choose two players to be painted the same colour (you may be one of them). You can't repaint a player.\nWhen they play, if they deal with the other player painted the same colour, you get %d coins and the effect stays.\nIf they keep the peace, the effect ends when the last player painted this colour ends their turn.", [TOLL])
		on_turn = true
		inflicts = true

	func can_use(_player: PlayerState, engine: GameEngine) -> String:
		return Loc.t("Not enough players to paint") if unpainted(engine).size() < 2 else ""

	## Who can still be painted: nobody wears two coats.
	static func unpainted(engine: GameEngine) -> Array:
		return engine.alive_players().filter(func(p: PlayerState) -> bool: return not p.has_status(PAINTED))

	# The two are chosen now, once nobody called LIAR!: one question whose
	# options are the pairs, picked on the boxes of the table (table._prompt_paint).
	func resolve(play: Play) -> void:
		var engine := play.engine
		var candidates := engine.seat_order(play.actor).filter(func(p: PlayerState) -> bool: return not p.has_status(PAINTED))
		if candidates.size() < 2:
			return
		var paint := _free_paint(engine)
		var pairs: Array = []
		for i: int in candidates.size():
			for j: int in range(i + 1, candidates.size()):
				pairs.append([candidates[i], candidates[j]])
		var d := Decision.new(Decision.Kind.PICK, play.actor)
		d.prompt = Loc.t("Monochrome: paint two players the same colour")
		d.options = pairs.map(func(pair: Array) -> Dictionary: return {
			"label": "%s + %s" % [pair[0].name, pair[1].name], "pair": pair, "description": "",
		})
		d.context = {
			"play": play, "look": &"paint", "candidates": candidates, "tint": PAINTS[paint],
			"painted": engine.seat_order(play.actor).filter(func(p: PlayerState) -> bool: return p.has_status(PAINTED)),
			"weights": pairs.map(func(pair: Array) -> float: return _ai_pick(play, pair[0]) * _ai_pick(play, pair[1])),
		}
		var index: int = await engine.ask(d)
		if index < 0 or index >= pairs.size():
			index = engine.rng.randi_range(0, pairs.size() - 1)
		var pair: Array = pairs[index]
		if engine.over or pair.any(func(p: PlayerState) -> bool: return not p.alive or p.has_status(PAINTED)):
			return
		play.mark = pair[0] if pair[0] != play.actor else pair[1]
		await engine.fire(&"players_painted", {"play": play, "painter": play.actor, "pair": pair, "tint": PAINTS[paint]})
		for i: int in 2:
			if engine.over or not pair[i].alive:
				return
			await engine.add_status(pair[i], PAINTED, {
				"by": play.actor.id, "partner": pair[1 - i].id, "planted": engine.turn_count,
				"tint": PAINTS[paint], "paint": paint, "played": false,
			})

	## The first of blue, pink and yellow nobody wears; green if all three are on.
	static func _free_paint(engine: GameEngine) -> int:
		var worn := engine.alive_players().map(func(p: PlayerState) -> int: return p.statuses.get(PAINTED, {}).get("paint", -1))
		for i: int in 3:
			if not worn.has(i):
				return i
		return 3

	## See partner_of.
	static func partner(player: PlayerState, engine: GameEngine) -> PlayerState:
		if not player.has_status(PAINTED):
			return null
		return engine.player_by_id(player.statuses[PAINTED].get("partner", -1))

	## How much a bot likes painting `p`: two strong opponents, to keep them
	## off each other; itself now and then, with a weak one.
	func _ai_pick(play: Play, p: PlayerState) -> float:
		if p == play.actor:
			return 0.25
		return 1.0 + p.coins * 0.06 + p.items.size() * 0.3 + p.morale * 0.2

	func ai_weight(_player: PlayerState, _engine: GameEngine) -> float:
		return 1.1
