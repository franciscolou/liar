extends CharacterDef
## Dr. Ezra "Sawbones" Quill. Cash up front, no questions asked.


func _init() -> void:
	id = &"doctor"
	display_name = "Doctor"
	title = "Dr. Ezra \"Sawbones\" Quill"
	texture_path = "res://assets/cards/Doctor.png"
	order = 160
	_add(PatchUp.new())
	_add(Antidote.new())


class PatchUp extends Ability:
	func _init() -> void:
		id = &"doctor.patch_up"
		display_name = "Patch Up"
		description = "Pay 6 coins to recover 1 Morale. Only when you are down to your last one."
		on_turn = true
		cost = 6
		tags = [&"heal"]

	# An emergency, not a habit: healing at will would let a rich table sit
	# at full Morale forever.
	func can_use(player: PlayerState, engine: GameEngine) -> String:
		if player.morale >= engine.config.start_morale:
			return Loc.t("Morale is full")
		return "" if player.morale <= 1 else Loc.t("Only on your last Morale")

	func resolve(play: Play) -> void:
		await play.engine.heal(play.actor, 1)

	func ai_weight(_player: PlayerState, _engine: GameEngine) -> float:
		return 3.0


class Antidote extends Ability:
	func _init() -> void:
		id = &"doctor.antidote"
		display_name = "Antidote"
		description = "Get rid of it at once, be it a hex, an oath, a spiked drink or a bomb."
		trigger_text = "When another player puts a status on you"

	func reacts_to(event: GameEvent, player: PlayerState, _engine: GameEngine) -> bool:
		if event.type != &"status_added" or event.data.player != player:
			return false
		# Only what somebody else did to them: `by` is who placed the status.
		var by: int = player.statuses.get(event.data.status, {}).get("by", -1)
		return by != -1 and by != player.id

	func resolve(play: Play) -> void:
		await play.engine.remove_status(play.actor, play.event.data.status)
