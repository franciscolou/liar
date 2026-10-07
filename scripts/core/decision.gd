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
##   DOUBT  -> one of the stakes in `options` (GameEngine.doubt_stakes) to
##             call LIAR!, or false to let it pass (context.play is the claim;
##             context.shared: other humans are being asked at the same time)
##             or one of context.reactions (humans only): let it pass and
##             answer the claim's reaction window with that option right away
##   REACT  -> one of the option dictionaries, or null to pass
##   PICK   -> index into `options` ([{label, description, card, item}]), -1 to cancel
##             (context.weights: how much a bot likes each option, default 1;
##             context.foreign: the cards offered are not from the player's hand)

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
