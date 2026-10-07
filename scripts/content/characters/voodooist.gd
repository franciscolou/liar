extends CharacterDef
## The Voodooist. One doll, pinned on one player at a time.
##
## Hex is a claim that never closes: for as long as the doll stays pinned,
## anyone else may call LIAR! on it during their own turn. What counts is
## whether the owner holds the Voodooist at that moment.

const BREAK_COST := 4

var _hex: Hex


func _init() -> void:
	id = &"voodooist"
	display_name = "Voodooist"
	title = "The Voodooist"
	texture_path = "res://assets/cards/Voodooist.png"
	order = 30
	status_defs = {
		&"hexed": {
			"name": "Hexed",
			"description": "Can't deal damage or heal. Half of every coin gain goes to the doll's owner. Break it for %d coins. Any other player may call LIAR! on the doll during their turn." % BREAK_COST,
			"color": Color("8e4fb5"),
		},
		&"voodoo_cooldown": {
			"name": "Doll recharging",
			"description": "The Voodoo doll was broken and can't be used until this player's next turn is over.",
			"color": Color("6b6470"),
		},
	}
	_hex = Hex.new()
	_add(PuppetStrings.new())
	_add(_hex)


func on_event(event: GameEvent, engine: GameEngine) -> void:
	match event.type:
		&"before_gain":
			var victim: PlayerState = event.data.player
			if not victim.has_status(&"hexed") or event.data.reason == &"voodoo":
				return
			var owner := engine.player_by_id(victim.statuses[&"hexed"].get("by", -1))
			var cut: int = event.data.amount / 2
			if owner == null or not owner.alive or cut <= 0:
				return
			event.data.amount -= cut
			await engine.change_coins(owner, cut, &"voodoo", victim)
		&"player_eliminated":
			# A dead owner's doll goes with them. A dead victim already lost the
			# status, which frees the doll with no recharge.
			var dead: PlayerState = event.data.player
			for p: PlayerState in engine.players:
				if p.alive and p.has_status(&"hexed") and p.statuses[&"hexed"].get("by", -1) == dead.id:
					await engine.remove_status(p, &"hexed")


func turn_extras(player: PlayerState, engine: GameEngine) -> Array:
	var out := []
	if player.has_status(&"hexed"):
		var affordable := engine.can_pay(player, BREAK_COST)
		out.append({
			"id": &"voodooist.break",
			"label": Loc.t("Break the Hex"),
			"description": Loc.t("Pay %d coins to destroy the Voodoo doll pinned on you.") % BREAK_COST,
			"cost": BREAK_COST,
			"enabled": affordable,
			"reason": "" if affordable else Loc.t("Not enough coins"),
			"run": _break_hex,
			"priority": 1,
		})
	var fine := engine.config.doubt_cost
	var stakes := engine.doubt_stakes(player)
	for victim: PlayerState in engine.players:
		var owner := _doubtable_owner(victim, engine)
		if owner == null or owner == player:
			continue
		var spent: bool = player.turn.get(&"doll_doubted", []).has(victim.id)
		var whose := Loc.t("you") if victim == player else victim.name
		# One option per way of backing the call; a single greyed one once used.
		for stake: StringName in (stakes.slice(0, 1) if spent else stakes):
			var label := Loc.t("LIAR! %s's doll") % owner.name
			var risk := Loc.t("If they do, you pay %d coins.") % fine
			match stake:
				GameEngine.STAKE_DEBT:
					label = Loc.t("LIAR! %s's doll (on credit)") % owner.name
					risk = Loc.t("If they do, you go %d coins into debt by claiming Vagabond (On the Cuff).") % fine
				GameEngine.STAKE_MORALE:
					label = Loc.t("LIAR! %s's doll (1 Morale)") % owner.name
					risk = Loc.t("If they do, you lose 1 Morale.")
			out.append({
				"id": &"voodooist.doubt",
				"label": label,
				"description": Loc.t("Doubt the doll %s pinned on %s. If %s doesn't hold the Voodooist right now, they lose 1 Morale and the doll is destroyed.") % [owner.name, whose, owner.name] + " " + risk,
				"enabled": not spent,
				"reason": Loc.t("Already doubted this turn") if spent else "",
				"run": _doubt_doll.bind(victim.id, stake),
				"ai": _ai_doubt(player, victim, stake, engine),
			})
	return out


## The owner of the doll on `victim`, if that doll is a claim someone may
## still doubt (a doll bounced back by a Mirror was never claimed).
func _doubtable_owner(victim: PlayerState, engine: GameEngine) -> PlayerState:
	if not victim.alive or not victim.has_status(&"hexed"):
		return null
	var status: Dictionary = victim.statuses[&"hexed"]
	if not status.get("claimed", false):
		return null
	var owner := engine.player_by_id(status.get("by", -1))
	return owner if owner != null and owner.alive else null


func _doubt_doll(player: PlayerState, engine: GameEngine, victim_id: int, stake: StringName) -> void:
	var victim := engine.player_by_id(victim_id)
	var owner: PlayerState = _doubtable_owner(victim, engine) if victim != null else null
	if owner == null or owner == player or not engine.doubt_stakes(player).has(stake):
		return
	if player.turn.get(&"doll_doubted", []).has(victim_id):
		return
	if not player.turn.has(&"doll_doubted"):
		player.turn[&"doll_doubted"] = []
	player.turn[&"doll_doubted"].append(victim_id)
	var play := Play.new()
	play.engine = engine
	play.actor = owner
	play.target = victim
	play.source = _hex
	play.params["standing"] = true
	play.truthful = owner.has_character(id)
	var still_theirs := func() -> bool:
		return victim.has_status(&"hexed") and victim.statuses[&"hexed"].get("by", -1) == owner.id
	if await engine.challenge(player, play, stake):
		if still_theirs.call():
			await engine.remove_status(victim, &"hexed")
		return
	# Proven: the Voodooist goes back to the deck, so the doll is settled and
	# nobody may doubt it again.
	if still_theirs.call():
		victim.statuses[&"hexed"]["claimed"] = false
	if not play.stand_in:
		await engine.renew_proven_card(owner, id)


func _ai_doubt(player: PlayerState, victim: PlayerState, stake: StringName, engine: GameEngine) -> float:
	# Holding every copy of the Voodooist proves the doll is a lie.
	if player.cards.count(id) >= engine.copies_in_play():
		return 1.0
	if stake != BotController.doubt_stake(player, [stake]):
		return 0.0
	var chance := 0.04 + 0.05 * player.cards.count(id)
	if victim == player:
		chance += 0.1
	if stake == GameEngine.STAKE_MORALE:
		chance *= 0.4
	elif player.coins - engine.config.doubt_cost < 2:
		chance *= 0.5
	return chance


func _break_hex(player: PlayerState, engine: GameEngine) -> void:
	if not player.has_status(&"hexed") or not await engine.pay(player, BREAK_COST):
		return
	# Paying on a tab is a claim of its own: by the time it settles the doll
	# may be gone (its owner lost their last Morale on a wrong call).
	if not player.has_status(&"hexed"):
		return
	var owner := engine.player_by_id(player.statuses[&"hexed"].get("by", -1))
	await engine.remove_status(player, &"hexed")
	if owner != null and owner.alive:
		await engine.add_status(owner, &"voodoo_cooldown", {"expires": &"own_turn_end"})


class PuppetStrings extends Ability:
	func _init() -> void:
		id = &"voodooist.puppet_strings"
		display_name = "Puppet Strings"
		description = "Your Voodoo victim can't deal damage or heal, and half of the coins they gain are yours. They can break the doll for 4 coins; it then recharges for a turn. While the doll stands, any other player may call LIAR! on it during their turn."
		info_only = true


class Hex extends Ability:
	func _init() -> void:
		id = &"voodooist.hex"
		display_name = "Hex"
		description = "Pin your Voodoo doll on a player. A player can only carry one doll."
		on_turn = true
		targeting = Targeting.OPPONENT

	func can_use(player: PlayerState, _engine: GameEngine) -> String:
		return Loc.t("Doll recharging") if player.has_status(&"voodoo_cooldown") else ""

	func target_candidates(play: Play) -> Array:
		return play.engine.targetable_opponents(play.actor).filter(
			func(p): return not p.has_status(&"hexed"))

	func resolve(play: Play) -> void:
		if play.target.has_status(&"hexed"):
			return
		for p: PlayerState in play.engine.players:
			if p.alive and p.has_status(&"hexed") and p.statuses[&"hexed"].get("by", -1) == play.actor.id:
				await play.engine.remove_status(p, &"hexed")
		await play.engine.add_status(play.target, &"hexed", {
			"by": play.actor.id, "blocks": [&"damage", &"heal"], "claimed": not play.reflected,
		})

	func ai_target_weight(_play: Play, candidate: PlayerState) -> float:
		return 1.0 + candidate.coins * 0.2
