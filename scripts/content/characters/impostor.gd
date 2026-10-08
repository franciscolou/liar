extends CharacterDef
## Jane Doe. Whoever you need her to be, until you look twice.


func _init() -> void:
	id = &"impostor"
	display_name = "Impostor"
	title = "Jane Doe"
	texture_path = "res://assets/cards/Impostor.png"
	order = 110
	_add(CoverStory.new())
	_add(PerfectDisguise.new())


class CoverStory extends Ability:
	const PAY := 3

	func _init() -> void:
		id = &"impostor.cover_story"
		display_name = "Cover Story"
		description = "Shuffle your whole hand into the deck, draw as many new cards and gain %d coins." % PAY
		on_turn = true

	func resolve(play: Play) -> void:
		await play.engine.redraw_hand(play.actor)
		await play.engine.gain_coins(play.actor, PAY, &"cover_story")

	func ai_weight(player: PlayerState, _engine: GameEngine) -> float:
		# A bluff costs the cards that were worth keeping.
		return 0.5 if player.has_character(character_id) else 0.8


class PerfectDisguise extends Ability:
	func _init() -> void:
		id = &"impostor.perfect_disguise"
		display_name = "Perfect Disguise"
		description = "Repeat the last action taken at the table as if it were yours, for what it costs and nothing more."
		on_turn = true
		repeatable = false

	func can_use(player: PlayerState, engine: GameEngine) -> String:
		var last := engine.last_action
		if last == null:
			return Loc.t("Nothing to repeat yet")
		var reason := engine.blocked_reason(player, last.tags)
		if reason != "":
			return reason
		if last.fresh_turn and player.turn.get("busy", false):
			return Loc.t("Takes the whole turn")
		reason = last.can_use(player, engine)
		if reason == "" and last.targeting != Targeting.NONE and last.target_candidates(_repeat(player, engine)).is_empty():
			reason = Loc.t("No valid target")
		return reason

	func cost_for(player: PlayerState, engine: GameEngine) -> int:
		return engine.last_action.cost_for(player, engine) if engine.last_action != null else 0

	func detail(_player: PlayerState, engine: GameEngine) -> String:
		return engine.last_action.display_name if engine.last_action != null else ""

	# Everything the action asks for is settled before the disguise is
	# announced: the table hears what is being repeated, and on whom.
	func prepare(play: Play) -> bool:
		var engine := play.engine
		if engine.last_action == null:
			return false
		var repeat := _repeat(play.actor, engine)
		repeat.cost = play.cost
		if not await engine.choose_target(repeat):
			return false
		if not await repeat.source.prepare(repeat):
			return false
		play.params["repeat"] = repeat
		# The action may have named its own price (a Counterfeit).
		play.cost = repeat.cost
		return true

	# The repeated action is a play of its own: it can be silenced, shields
	# and mirrors answer it, and whatever reacts to the original reacts to it.
	func resolve(play: Play) -> void:
		var engine := play.engine
		var repeat: Play = play.params.get("repeat")
		if repeat == null:
			return
		var resolving := await engine.fire(&"claim_resolving", {"play": repeat})
		if resolving.cancelled:
			repeat.cancelled = true
			await engine.fire(&"claim_cancelled", {"play": repeat})
			return
		await engine.carry_out(repeat)

	func _repeat(player: PlayerState, engine: GameEngine) -> Play:
		var repeat := Play.new()
		repeat.engine = engine
		repeat.actor = player
		repeat.source = engine.last_action
		return repeat

	func ai_weight(player: PlayerState, engine: GameEngine) -> float:
		return engine.last_action.ai_weight(player, engine) * 0.9 if engine.last_action != null else 0.0
