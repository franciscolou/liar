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
		description = "Pay 2 coins: the lie stands as the truth and the doubter pays for a wrong call. Then discard this card for a new one."
		trigger_text = "When someone calls LIAR! on a lie of yours"
		cost = 2

	func reacts_to(event: GameEvent, player: PlayerState, _engine: GameEngine) -> bool:
		if event.type != &"doubt_declared":
			return false
		var doubted: Play = event.data.play
		return doubted.actor == player and not doubted.truthful

	func resolve(play: Play) -> void:
		var engine := play.engine
		var doubted: Play = play.event.data.play
		# The reveal that follows reads this: the table sees the truth.
		doubted.truthful = true
		doubted.stand_in = true
		var index := play.actor.cards.find(character_id)
		if index == -1:
			index = await engine.pick_own_card(play.actor, Loc.t("%s, you don't hold the %s: choose the card to swap") % [play.actor.name, Content.character(character_id).display_name])
		await engine.replace_card(play.actor, index, &"disguise")

	# Whoever was just caught has every reason to try it.
	func ai_suspicion(_play: Play, _doubter: PlayerState) -> float:
		return 0.3
