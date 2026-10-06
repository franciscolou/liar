class_name Decision
extends RefCounted
## A choice the engine needs from a player. Controllers (human UI or bot)
## answer it; the engine never knows who is on the other side.
##
## Answers by kind:
##   TURN   -> Dictionary: one of the entries in options.abilities / buy / use /
##             extras, options.reroll (null when there is nothing to restock),
##             or {kind = &"end"}
##   TARGET -> PlayerState from `options`, or null to cancel
##   DOUBT  -> bool (context.play is the claim being judged)
##   REACT  -> one of the option dictionaries, or null to pass
##   PICK   -> index into `options` ([{label, description, card, item}]), -1 to cancel

enum Kind { TURN, TARGET, DOUBT, REACT, PICK }

var kind: Kind
var player: PlayerState
var prompt := ""
var options: Variant
var context: Dictionary = {}
var cancellable := false


func _init(decision_kind: Kind = Kind.TURN, decision_player: PlayerState = null) -> void:
	kind = decision_kind
	player = decision_player
