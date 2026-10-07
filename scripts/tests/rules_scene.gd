extends Node
## The scripted rule checks of rules.gd as a scene: play it from the editor
## and read the output. The window stays open with the verdict.

const Rules := preload("res://scripts/tests/rules.gd")


func _ready() -> void:
	var failed: int = await Rules.run()
	print("RULES DONE: %d failed" % failed)
	var verdict := Label.new()
	verdict.text = "Rules: %d scenes failed. See the output." % failed
	verdict.position = Vector2(24, 24)
	add_child(verdict)
