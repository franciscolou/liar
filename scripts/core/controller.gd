class_name Controller
extends RefCounted
## Answers Decisions for one player. See BotController and HumanController.

var engine: GameEngine
var player: PlayerState


func decide(_decision: Decision) -> Variant:
	return null


## The engine no longer needs an answer to `_decision` (someone else settled
## it). A controller still waiting on it must drop it and answer its default.
func withdraw(_decision: Decision) -> void:
	pass


## Called for every event, so controllers can keep their own memory.
func observe(_event: GameEvent) -> void:
	pass
