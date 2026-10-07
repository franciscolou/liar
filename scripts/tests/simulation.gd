extends RefCounted
## Bots play whole matches against each other while the invariants of the game
## are checked. Shared by simulate.gd (headless) and simulate_scene.gd (run
## from the editor). It has no class name: preload it.


## Plays `games` matches, numbered from `first` on, and prints a summary.
## Returns how many went wrong. A match is fully decided by its number, so a
## bad one can be played again by itself; `verbose` prints the log of the
## first match played.
static func run(games: int, verbose := false, first := 0) -> int:
	Content.ensure_loaded()
	print("characters: ", Content.characters.keys())
	print("items: ", Content.items.keys())

	var failed := 0
	var turns := 0
	var claims := {}
	var length := {}  # character id -> [games it was in, turns they took]
	for g in range(first, first + games):
		var config := GameConfig.new()
		var seats := 2 + g % 5
		for s in seats:
			config.seats.append({"name": "Bot%d" % s, "bot": true})
		# From a small cast up to every character at once.
		config.character_count = 3 + g % (Content.characters.size() - 2)
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
		var recorder := Recorder.new()
		recorder.engine = engine
		engine.observers.append(recorder)
		engine.run()
		var problems := recorder.problems
		if not engine.over:
			problems.append("did not finish (turn %d): %s; %s" % [
				engine.turn_count, ", ".join(engine.characters.map(func(def): return String(def.id))),
				", ".join(engine.players.map(func(p): return "%s %dM %dc" % [p.name, p.morale, p.coins]))])
		for def: CharacterDef in engine.characters:
			var tally: Array = length.get(def.id, [0, 0])
			length[def.id] = [tally[0] + 1, tally[1] + engine.turn_count]
		for problem: String in problems:
			push_error("game %d: %s" % [g, problem])
			print("PROBLEM game %d: %s" % [g, problem])
		if not problems.is_empty():
			failed += 1
		turns += engine.turn_count
		for line: String in recorder.lines:
			if line.contains(" claims "):
				var key := line.get_slice(" claims ", 1).get_slice(":", 0) + ":" + line.get_slice(": ", 1).get_slice(" on ", 0).trim_suffix(".")
				claims[key] = claims.get(key, 0) + 1
		if verbose and g == first:
			print("\n".join(recorder.lines))
			print("; ".join(engine.players.map(func(p): return "%s %s %dM %dc %s" % [
				p.name, "alive" if p.alive else "out", p.morale, p.coins, p.cards])))
	print("finished %d/%d games, %.1f turns on average" % [games - failed, games, float(turns) / maxi(games, 1)])
	var cast := length.keys()
	cast.sort()
	print("turns per game, by character in the match:")
	for id: StringName in cast:
		print("  %-14s %5.1f  (%d games)" % [id, float(length[id][1]) / length[id][0], length[id][0]])
	var keys := claims.keys()
	keys.sort()
	for key: String in keys:
		print("  %-36s %d" % [key, claims[key]])
	return failed


## The log of one match, as the table would have written it. It also checks
## the invariants every time a turn starts: by then nothing is half done.
class Recorder extends RefCounted:
	var engine: GameEngine
	var lines: Array = []
	var problems: Array = []

	func present(event: GameEvent) -> void:
		var line := EventText.describe(event)
		if line != "":
			lines.append(line)
		if event.type == &"turn_started" and problems.is_empty():
			for problem: String in _check():
				problems.append("turn %d: %s" % [engine.turn_count, problem])

	## What is wrong with the state of the match, as it stands between two turns.
	func _check() -> Array:
		var found := []
		var cards := engine.deck.size()
		for p: PlayerState in engine.players:
			cards += p.cards.size()
			if p.alive and p.cards.size() != engine.hand_limit(p):
				found.append("%s holds %d cards" % [p.name, p.cards.size()])
			if p.coins < -10:
				found.append("%s has %d coins" % [p.name, p.coins])
			if p.items.size() > engine.config.inventory_limit:
				found.append("%s has too many items" % p.name)
			if p.morale < 0 or p.morale > engine.config.start_morale:
				found.append("%s has %d Morale" % [p.name, p.morale])
		if cards != engine.characters.size() * engine.copies_in_play():
			found.append("%d cards in the game" % cards)
		return found
