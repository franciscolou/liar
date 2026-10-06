extends SceneTree
## Headless smoke test: bots play whole matches against each other.
##   godot --headless --script res://scripts/tests/simulate.gd -- [games] [verbose]

var _lines: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var games := int(args[0]) if args.size() > 0 else 50
	var verbose := args.size() > 1
	Content.ensure_loaded()
	print("characters: ", Content.characters.keys())
	print("items: ", Content.items.keys())

	var finished := 0
	var turns := 0
	var claims := {}
	for g in games:
		var config := GameConfig.new()
		var seats := 2 + g % 5
		for s in seats:
			config.seats.append({"name": "Bot%d" % s, "bot": true})
		config.character_count = 3 + g % 8
		config.max_turns = 600
		config.rng_seed = 1000 + g
		var engine := GameEngine.new()
		engine.setup(config)
		for p: PlayerState in engine.players:
			var bot := BotController.new()
			bot.engine = engine
			bot.player = p
			bot.boldness = 0.2 + 0.1 * (p.id % 4)
			engine.controllers[p.id] = bot
		_lines = []
		engine.observers.append(self)
		engine.run()
		if not engine.over:
			push_error("game %d did not finish (turn %d)" % [g, engine.turn_count])
		else:
			finished += 1
		turns += engine.turn_count
		for line: String in _lines:
			if line.contains(" claims "):
				var key := line.get_slice(" claims ", 1).get_slice(":", 0) + ":" + line.get_slice(": ", 1).get_slice(" on ", 0).trim_suffix(".")
				claims[key] = claims.get(key, 0) + 1
		_check(engine, g)
		if verbose and g == 0:
			print("\n".join(_lines))
	print("finished %d/%d games, %.1f turns on average" % [finished, games, float(turns) / games])
	var keys := claims.keys()
	keys.sort()
	for key in keys:
		print("  %-36s %d" % [key, claims[key]])
	quit(0 if finished == games else 1)


func present(event: GameEvent) -> void:
	var line := EventText.describe(event)
	if line != "":
		_lines.append(line)


func _check(engine: GameEngine, game: int) -> void:
	var cards := engine.deck.size()
	for p: PlayerState in engine.players:
		cards += p.cards.size()
		if p.alive and p.cards.size() != engine.hand_limit(p):
			push_error("game %d: %s holds %d cards" % [game, p.name, p.cards.size()])
		if p.coins < -10:
			push_error("game %d: %s has %d coins" % [game, p.name, p.coins])
		if p.items.size() > engine.config.inventory_limit:
			push_error("game %d: %s has too many items" % [game, p.name])
	if cards != engine.characters.size() * engine.copies_in_play():
		push_error("game %d: %d cards in the game" % [game, cards])
