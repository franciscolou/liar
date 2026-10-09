class_name PlayerState
extends RefCounted

var id := 0
var name := ""
var is_bot := false
var alive := true
var morale := 3
var coins := 0
var cards: Array = []  # character ids (StringName)
## The cards an eliminated player was holding: they stay on the table, face
## up, out of the deck for the rest of the match.
var left: Array = []
var items: Array = []  # ItemInstance
## status id -> {expires, turns, by, blocks}. See GameEngine.add_status.
var statuses: Dictionary = {}
## Free-form numeric counters owned by content (e.g. the Mythomaniac vault).
var counters: Dictionary = {}
## Scratch data reset at the start of this player's turn.
var turn: Dictionary = {}


func has_character(character_id: StringName) -> bool:
	return cards.has(character_id)


func has_status(status_id: StringName) -> bool:
	return statuses.has(status_id)


func counter(counter_id: StringName) -> int:
	return counters.get(counter_id, 0)
