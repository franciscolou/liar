extends CharacterDef
## The Voodooist. Her dolls are pinned on players asleep, wake up if nobody
## pays to break them in time, and stay until somebody does.
##
## Hex pins a doll on a player (one doll per player, as many players as she
## likes). It is a claim like any other: it may be doubted as the doll is
## pinned, and never again after that. The doll sleeps through the rest of
## that round: when its carrier's next turn ends and they have not paid
## BREAK_COST to break it, it wakes. Asleep or awake, it stays on them until
## they pay to break it.
##
## Puppet Strings makes every doll of hers that is awake do one thing to whoever
## carries it (hurt them, take TOLL coins or take an item), and the doll stays
## where it is, ready to do it again. It is no claim, and nobody can doubt it:
## the doll is hers already, and the time to call LIAR! was when it was
## pinned. It is offered as a turn extra (turn_extras) to whoever pinned a
## doll, card or no card, ends the turn and is carried out with no announcement
## (GameEngine.carry_out). Nothing the doll does goes through Shields or
## Mirrors either: the time to stop it was when it was pinned too.

const HEXED := &"hexed"
const BREAK_COST := 4
const TOLL := 3

var _strings: PuppetStrings


func _init() -> void:
	id = &"voodooist"
	display_name = "Voodooist"
	title = "The Voodooist"
	texture_path = "res://assets/cards/Voodooist.png"
	order = 30
	status_defs = {
		HEXED: {
			"name": "Hexed",
			"description": "Carries a Voodoo doll until they break it for %d coins. Asleep, it wakes at the end of this player's turn. Awake, the Voodooist's Puppet Strings can make it hurt them, take %d coins or take an item, again and again.", "args": [BREAK_COST, TOLL],
			"color": Color("8e4fb5"),
		},
	}
	_add(Hex.new())
	_strings = PuppetStrings.new()
	_add(_strings)


## Whether `holder` carries a doll pinned by `owner` (any owner, for null)
## that has woken up.
static func awake_doll(holder: PlayerState, owner: PlayerState = null) -> bool:
	return PuppetStrings.awake(holder, owner)


func on_event(event: GameEvent, engine: GameEngine) -> void:
	match event.type:
		&"turn_ended":
			var holder: PlayerState = event.data.player
			if engine.over or not holder.alive or not holder.has_status(HEXED):
				return
			var status: Dictionary = holder.statuses[HEXED]
			# Pinned during this very turn (a mirror sent it back): it sleeps
			# on into the next, so the carrier gets a chance to break it.
			if status.get("awake", false) or status.get("planted", 0) >= engine.turn_count:
				return
			status["awake"] = true
			await engine.note(holder, "The doll on %s wakes up.", false, &"doll_awake")
		&"player_eliminated":
			# A dead owner's dolls go with them. A dead carrier already lost
			# the status.
			var dead: PlayerState = event.data.player
			for p: PlayerState in engine.players:
				if p.alive and p.has_status(HEXED) and p.statuses[HEXED].get("by", -1) == dead.id:
					await engine.remove_status(p, HEXED)


func turn_extras(player: PlayerState, engine: GameEngine) -> Array:
	var out := []
	if player.has_status(HEXED):
		var cost := engine.price(player, BREAK_COST)
		var affordable := engine.can_pay(player, cost)
		var awake := awake_doll(player)
		out.append({
			"id": &"voodooist.break",
			"label": Loc.t("Break the Hex"),
			"description": (Loc.t("Pay %d coins to destroy the Voodoo doll pinned on you. It is awake: until you do, the Voodooist can use it on you.") if awake
					else Loc.t("Pay %d coins to destroy the Voodoo doll pinned on you. If you don't, it wakes up when this turn ends.")) % BREAK_COST,
			"cost": cost,
			"enabled": affordable,
			"reason": "" if affordable else Loc.t("Not enough coins"),
			"run": _break_hex,
			"ai": 0.95 if awake or player.morale <= 1 else (0.8 if not player.items.is_empty() else 0.6),
			"priority": 1,
		})
	# Whoever pinned a doll pulls its strings: no claim, nothing to doubt.
	var pinned := engine.players.any(func(p: PlayerState) -> bool:
		return p != player and p.alive and p.statuses.get(HEXED, {}).get("by", -1) == player.id)
	if pinned:
		var reason := _strings.can_use(player, engine)
		out.append({
			"id": &"voodooist.puppet_strings",
			"label": _strings.display_name,
			"description": _strings.description,
			"cost": 0,
			"enabled": reason == "",
			"reason": reason,
			"run": _pull_strings,
			"ends_turn": true,
			"ai": 0.9,
			"priority": 2,
		})
	return out


func _pull_strings(player: PlayerState, engine: GameEngine) -> void:
	if _strings.can_use(player, engine) != "":
		return
	await engine.note(player, "%s pulls the strings of the dolls.", true, &"puppet_strings")
	var play := Play.new()
	play.engine = engine
	play.actor = player
	play.source = _strings
	await engine.carry_out(play)


func _break_hex(player: PlayerState, engine: GameEngine) -> void:
	if not player.has_status(HEXED) or not await engine.pay(player, engine.price(player, BREAK_COST)):
		return
	# Paying on a tab is a claim of its own: by the time it settles the doll
	# may be gone (its owner lost their last Morale on a wrong call).
	if not player.has_status(HEXED):
		return
	await engine.remove_status(player, HEXED)


class Hex extends Ability:
	func _init() -> void:
		id = &"voodooist.hex"
		display_name = "Hex"
		describe("Pin a sleeping Voodoo doll on a player. It wakes up at the end of their next turn, and stays on them until they pay %d coins to break it. A player can only carry one doll.", [BREAK_COST])
		on_turn = true
		targeting = Targeting.OPPONENT
		inflicts = true

	func target_candidates(play: Play) -> Array:
		return play.engine.targetable_opponents(play.actor).filter(
			func(p): return not p.has_status(HEXED))

	func resolve(play: Play) -> void:
		if play.target.has_status(HEXED):
			return
		await play.engine.add_status(play.target, HEXED, {
			"by": play.actor.id, "planted": play.engine.turn_count, "awake": false,
		})

	func ai_weight(_player: PlayerState, _engine: GameEngine) -> float:
		return 1.2

	# Best on someone too broke to break it, with something worth taking.
	func ai_target_weight(_play: Play, candidate: PlayerState) -> float:
		return (1.0 + candidate.items.size() * 0.5 + (3 - candidate.morale) * 0.4
				+ (1.0 if candidate.coins < BREAK_COST else 0.0))


class PuppetStrings extends Ability:
	func _init() -> void:
		id = &"voodooist.puppet_strings"
		display_name = "Puppet Strings"
		describe("For each player with an awake Voodoo doll, make one of these moves of your choice:\n- Deal 1 damage\n- Steal %d coins\n- Steal an item\n\nThis action can't be doubted.", [TOLL])
		# Never claimed: a turn extra of whoever pinned the doll (see the top).
		info_only = true
		tags = [&"damage", &"steal"]

	func kind_label() -> String:
		return Loc.t("Action")

	## See awake_doll.
	static func awake(holder: PlayerState, owner: PlayerState) -> bool:
		if not holder.alive or not holder.has_status(HEXED):
			return false
		var status: Dictionary = holder.statuses[HEXED]
		return status.get("awake", false) and (owner == null or status.get("by", -1) == owner.id)

	func can_use(player: PlayerState, engine: GameEngine) -> String:
		for p: PlayerState in engine.players:
			if p != player and awake(p, player):
				return ""
		return Loc.t("None of your dolls is awake")

	func resolve(play: Play) -> void:
		var engine := play.engine
		for holder: PlayerState in engine.seat_order(play.actor):
			if engine.over or not play.actor.alive:
				return
			if holder == play.actor or not awake(holder, play.actor):
				continue
			await _work(play, holder)

	## The doll on `holder` does what the Voodooist picks.
	func _work(play: Play, holder: PlayerState) -> void:
		var engine := play.engine
		var actor := play.actor
		# All three are always offered: what can't be done there is shown
		# locked, with the reason (see doll_pick.gd).
		var no_coins := Loc.t("%s has no coins") % holder.name if holder.coins <= 0 else ""
		var no_item := ""
		if holder.items.is_empty():
			no_item = Loc.t("%s has no items") % holder.name
		elif actor.items.size() >= engine.config.inventory_limit:
			no_item = Loc.t("Your inventory is full")
		var options := [{
			"label": Loc.t("Hurt"), "description": Loc.t("%s loses 1 Morale.") % holder.name,
			"does": &"hurt", "weight": 1.5 + (2.5 if holder.morale <= 1 else 0.0),
		}, {
			"label": Loc.t("Take %d coins") % TOLL, "description": Loc.t("Steal up to %d coins from %s.") % [TOLL, holder.name],
			"does": &"coins", "weight": 0.5 * mini(holder.coins, TOLL),
			"disabled": no_coins != "", "reason": no_coins,
		}, {
			"label": Loc.t("Take an item"), "description": Loc.t("Steal one of %s's items.") % holder.name,
			"does": &"item", "weight": 0.9 * holder.items.size(),
			"disabled": no_item != "", "reason": no_item,
		}]
		var open := range(options.size()).filter(func(i: int) -> bool: return not options[i].get("disabled", false))
		var d := Decision.new(Decision.Kind.PICK, actor)
		d.prompt = Loc.t("What does the doll on %s do?") % holder.name
		d.options = options
		d.context = {
			"play": play, "look": &"doll",
			"weights": options.map(func(o: Dictionary) -> float: return 0.0 if o.get("disabled", false) else o.weight),
		}
		var pick: int = await engine.ask(d)
		if not open.has(pick):
			pick = open[engine.rng.randi_range(0, open.size() - 1)]
		if engine.over or not actor.alive or not holder.alive:
			return
		match options[pick].does:
			&"hurt":
				await engine.deal_damage(actor, holder, play)
			&"coins":
				await engine.steal_coins(actor, holder, TOLL, play, &"hexed", &"voodoo")
			&"item":
				await _take_item(play, holder)

	func _take_item(play: Play, holder: PlayerState) -> void:
		var engine := play.engine
		# They may keep what they hold out of reach (see GameEngine.reach_items).
		if not await engine.reach_items(play.actor, holder, &"steal") or engine.over or holder.items.is_empty():
			return
		var index := 0
		if holder.items.size() > 1:
			var d := Decision.new(Decision.Kind.PICK, play.actor)
			d.prompt = Loc.t("Which of %s's items does the doll take?") % holder.name
			# Picked where they lie, in the holder's own box (see table._open_pick).
			d.context = {"play": play, "held_by": holder}
			d.options = holder.items.map(_item_option)
			index = await engine.ask(d)
			if index < 0 or index >= holder.items.size():
				index = engine.rng.randi_range(0, holder.items.size() - 1)
		if not engine.over and holder.alive and index < holder.items.size():
			await engine.take_item(play.actor, holder, holder.items[index])

	func _item_option(instance: ItemInstance) -> Dictionary:
		if instance.hidden:
			return {"label": Loc.t("Hidden item"), "description": "", "item": null, "hidden": true}
		return {"label": instance.def.display_name, "description": instance.def.description, "item": instance.def}

