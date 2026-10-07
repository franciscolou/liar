extends SceneTree
## Headless smoke test: bots play whole matches against each other.
##   godot --headless --script res://scripts/tests/simulate.gd -- [games] [v] [first game]
## "-- 1 v 172" plays match 172 by itself and prints its log.
## With the editor open, run scripts/tests/simulate_scene.tscn instead.

const Simulation := preload("res://scripts/tests/simulation.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var games := int(args[0]) if args.size() > 0 else 50
	var first := int(args[2]) if args.size() > 2 else 0
	quit(1 if Simulation.run(games, args.size() > 1 and args[1] != "-", first) > 0 else 0)
