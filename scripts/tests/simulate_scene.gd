extends Node
## The smoke test of simulate.gd as a scene, for when a second, headless Godot
## is not welcome (it knocks the editor's MCP plugin out): play this scene from
## the editor and read the output. The window stays open with the verdict.

const Simulation := preload("res://scripts/tests/simulation.gd")
const GAMES := 150


func _ready() -> void:
	var failed := Simulation.run(GAMES)
	print("SIMULATION DONE: %d failed" % failed)
	var verdict := Label.new()
	verdict.text = "Simulation: %d of %d games failed. See the output." % [failed, GAMES]
	verdict.position = Vector2(24, 24)
	add_child(verdict)
