extends CharacterDef
## Mister Giggles. Nobody in Carcaj has ever seen him without the paint, and
## nobody has ever been sure the gun was a toy.

## What loading the gun costs the Clown, and ducking it its target.
const ROUND := 4
## What each player the Clown laughs at is worth.
const LAUGH := 3


func _init() -> void:
	id = &"clown"
	display_name = "Clown"
	title = "Mister Giggles"
	texture_path = "res://assets/cards/Clown.png"
	order = 190
	_add(Bang.new())
	_add(Laughter.new())


## An empty gun gives its round back once it has been shown. Usually that is
## Bang.resolve, but a gun that never got there (a Shield, a Silencer) still
## owes it, and only now that the claim is over.
func on_event(event: GameEvent, engine: GameEngine) -> void:
	if event.type != &"claim_resolved":
		return
	var claimed: Play = event.data.play
	if claimed.failed or claimed.paid <= 0:
		return
	var play := claimed.aimed()
	if play.source is Bang:
		await Bang.give_back(play, claimed.paid, claimed)


class Bang extends Ability:
	func _init() -> void:
		id = &"clown.bang"
		display_name = "Bang!"
		describe("In secret, load the gun or leave it empty and aim it at a player. They may pay %d coins to duck and dodge the shot, or take their chances.\n\nIf it is loaded: you pay %d coins and the target loses 1 Morale unless they ducked.\nIf it is empty: you pay nothing.", [ROUND, ROUND])
		on_turn = true
		# Put down whether the gun is loaded or not: what is on the table
		# must not tell. An empty gun gives it back once it is shown.
		cost = ROUND
		targeting = Targeting.OPPONENT
		tags = [&"damage"]

	# The round has to be in the purse: no gun is loaded on credit.
	func can_use(player: PlayerState, engine: GameEngine) -> String:
		return Loc.t("Not enough coins") if player.coins < engine.claim_cost(player, self) else ""

	# Loaded or not is settled before the claim is announced, in secret.
	func prepare(play: Play) -> bool:
		var d := Decision.new(Decision.Kind.PICK, play.actor)
		d.prompt = Loc.t("Do you load the gun?")
		d.cancellable = true
		d.options = [
			{"label": Loc.t("Load it"), "description": Loc.t("A real shot: the coins put down are spent on it."), "does": &"load"},
			{"label": Loc.t("Leave it empty"), "description": Loc.t("Confetti: the coins put down come back once the gun is shown."), "does": &"empty"},
		]
		# Not a menu: the gun between two bills (see gun_pick.gd).
		d.context = {"play": play, "weights": [_load_weight(play), 1.0], "look": &"gun"}
		var index: int = await play.engine.ask(d)
		if index < 0 or index > 1:
			return false
		play.params["loaded"] = index == 0
		# Who put the round down: a mirror makes somebody else the shooter.
		play.params["clown"] = play.actor
		return true

	func resolve(play: Play) -> void:
		var engine := play.engine
		var target := play.target
		var loaded: bool = play.params.get("loaded", false)
		var duck := engine.price(target, ROUND)
		var ducked := false
		if target.alive and engine.can_pay(target, duck):
			var d := Decision.new(Decision.Kind.PICK, target)
			d.prompt = Loc.t("%s aims a circus gun at you. Is it loaded?") % play.actor.name
			d.options = [
				{"label": Loc.t("Duck"), "price": duck, "description": Loc.t("Pay to be out of the way, loaded or not."), "does": &"duck"},
				{"label": Loc.t("Take your chances"), "description": Loc.t("Loaded, it costs you 1 Morale."), "does": &"chance"},
			]
			# Not a menu: the gun aimed down at them, between two bills (see gun_pick.gd).
			d.context = {"play": play, "weights": [_duck_weight(target), 1.0], "look": &"duck"}
			var answer: int = await engine.ask(d)
			if answer == 0 and not engine.over and target.alive:
				ducked = await engine.pay(target, duck, &"duck")
		if engine.over:
			return
		await engine.fire(&"gun_fired", {
			"play": play, "shooter": play.actor, "target": target, "loaded": loaded, "ducked": ducked,
		})
		if loaded and not ducked and target.alive and not engine.over:
			await engine.deal_damage(play.actor, target, play)
		elif not loaded:
			await give_back(play, play.cost, play)

	## The round put down for an empty gun goes back to whoever put it down,
	## once. `claimed` is the play the coins were put down for (the
	## Impostor's, for a repeated Bang!), for the table to find them.
	static func give_back(play: Play, amount: int, claimed: Play) -> void:
		if play.params.get("loaded", true) or play.params.get("settled", false):
			return
		play.params["settled"] = true
		var clown: PlayerState = play.params.get("clown")
		var engine := play.engine
		if clown != null and clown.alive and not engine.over and amount > 0:
			await engine.change_coins(clown, amount, &"blank", null, claimed)

	func _load_weight(play: Play) -> float:
		# Nobody ducks without the coins to do it: that one is a sure hit.
		if play.target != null and play.target.coins < play.engine.price(play.target, ROUND):
			return 4.0
		return 1.3

	func _duck_weight(target: PlayerState) -> float:
		return [0.0, 4.0, 1.4, 0.7][clampi(target.morale, 0, 3)]

	func ai_weight(_player: PlayerState, _engine: GameEngine) -> float:
		return 2.0

	func ai_target_weight(play: Play, candidate: PlayerState) -> float:
		var cornered := 2.0 if candidate.coins < play.engine.price(candidate, ROUND) else 0.0
		return 1.0 + (3 - candidate.morale) + cornered


class Laughter extends Ability:
	func _init() -> void:
		id = &"clown.laughter"
		display_name = "Laughter"
		describe("Gain %d coins for each other player under any effect or with 0 coins or less.", [LAUGH])
		on_turn = true

	func can_use(player: PlayerState, engine: GameEngine) -> String:
		return Loc.t("Nobody to laugh at") if laughed_at(player, engine).is_empty() else ""

	func resolve(play: Play) -> void:
		var count := laughed_at(play.actor, play.engine).size()
		if count > 0:
			await play.engine.gain_coins(play.actor, count * LAUGH, &"laughter")

	## The players `player` would laugh at right now.
	static func laughed_at(player: PlayerState, engine: GameEngine) -> Array:
		return engine.opponents(player).filter(
			func(p: PlayerState) -> bool: return not p.statuses.is_empty() or p.coins <= 0)

	func ai_weight(player: PlayerState, engine: GameEngine) -> float:
		return 0.6 * laughed_at(player, engine).size()
