extends CharacterDef
## The Voodooist. One doll, pinned on one player at a time.
##
## Hex is a claim like any other: it may be doubted as the doll is pinned,
## and never again after that.

const BREAK_COST := 4


func _init() -> void:
	id = &"voodooist"
	display_name = "Voodooist"
	title = "The Voodooist"
	texture_path = "res://assets/cards/Voodooist.png"
	order = 30
	status_defs = {
		&"hexed": {
			"name": "Hexed",
			"description": "Can't deal damage or heal. Half of every coin gain goes to the doll's owner. Break it for %d coins." % BREAK_COST,
			"color": Color("8e4fb5"),
		},
		&"voodoo_cooldown": {
			"name": "Doll recharging",
			"description": "The Voodoo doll was broken and can't be used until this player's next turn is over.",
			"color": Color("6b6470"),
		},
	}
	_add(PuppetStrings.new())
	_add(Hex.new())


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
		var cost := engine.price(player, BREAK_COST)
		var affordable := engine.can_pay(player, cost)
		out.append({
			"id": &"voodooist.break",
			"label": Loc.t("Break the Hex"),
			"description": Loc.t("Pay %d coins to destroy the Voodoo doll pinned on you.") % BREAK_COST,
			"cost": cost,
			"enabled": affordable,
			"reason": "" if affordable else Loc.t("Not enough coins"),
			"run": _break_hex,
			"priority": 1,
		})
	return out


func _break_hex(player: PlayerState, engine: GameEngine) -> void:
	if not player.has_status(&"hexed") or not await engine.pay(player, engine.price(player, BREAK_COST)):
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
		description = "Your Voodoo victim can't deal damage or heal, and half of the coins they gain are yours. They can break the doll for 4 coins; it then recharges for a turn."
		info_only = true


class Hex extends Ability:
	func _init() -> void:
		id = &"voodooist.hex"
		display_name = "Hex"
		description = "Pin your Voodoo doll on a player. A player can only carry one doll."
		on_turn = true
		targeting = Targeting.OPPONENT
		inflicts = true

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
		await play.engine.add_status(play.target, &"hexed", {"by": play.actor.id, "blocks": [&"damage", &"heal"]})

	func ai_target_weight(_play: Play, candidate: PlayerState) -> float:
		return 1.0 + candidate.coins * 0.2
