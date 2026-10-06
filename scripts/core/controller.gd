class_name Controller
extends RefCounted
## Answers Decisions for one player. See BotController and HumanController.

var engine: GameEngine
var player: PlayerState


func decide(_decision: Decision) -> Variant:
	return null


## Called for every event, so controllers can keep their own memory.
func observe(_event: GameEvent) -> void:
	pass
