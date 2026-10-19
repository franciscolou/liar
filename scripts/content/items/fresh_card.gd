extends ItemDef
## Not an item: a service of the shop, always on sale. The buyer sends a card
## of their choice back to the deck for a random one, and that is their turn.


func _init() -> void:
	id = &"fresh_card"
	display_name = "Fresh Card"
	description = "Trade a card of your hand for a random card from the deck. Activates on purchase."
	price = 5
	fixed = true
	service = true
	whole_turn = true
	texture_path = "res://assets/items/fresh_card.png"


func can_use(player: PlayerState, engine: GameEngine) -> String:
	if player.cards.is_empty():
		return Loc.t("No cards in hand")
	if engine.deck.is_empty():
		return Loc.t("The deck is empty")
	return ""


# The card is chosen before paying, so backing out costs nothing; nobody else
# is told which one until it leaves.
func prepare(play: Play) -> bool:
	var actor := play.actor
	if actor.cards.size() <= 1:
		play.params["index"] = 0
		return true
	var d := Decision.new(Decision.Kind.PICK, actor)
	d.prompt = Loc.t("Choose the card to trade for one from the deck")
	d.cancellable = true
	# A bot lets go of a second copy first.
	var weights := actor.cards.map(func(card): return 3.0 if actor.cards.count(card) > 1 else 1.0)
	d.context = {"play": play, "quiet": true, "weights": weights}
	d.options = actor.cards.map(func(card): return {
		"label": Content.character(card).display_name, "card": card,
	})
	var index: int = await play.engine.ask(d)
	if index < 0 or index >= actor.cards.size():
		return false
	play.params["index"] = index
	return true


func resolve(play: Play) -> void:
	await play.engine.replace_card(play.actor, play.params.get("index", 0), &"fresh_card")


# Worth it to a bot holding two copies of the same character.
func ai_buy_weight(player: PlayerState, _engine: GameEngine) -> float:
	for card: StringName in player.cards:
		if player.cards.count(card) > 1:
			return 1.2
	return 0.1
