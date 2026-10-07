class_name Play
extends RefCounted
## One use of an ability (a claim) or of an item, from announcement to
## resolution. It is the context handed to Playable.resolve().

var engine: GameEngine
var actor: PlayerState
var target: PlayerState
var source: Playable
var item: ItemInstance  # set when the source is an item
var event: GameEvent  # the event this play reacts to, if any
var params: Dictionary = {}
var cost := 0

var truthful := true  # the actor really holds the claimed character
## A doubted claim that stood without its card being shown (see impostor.gd):
## there is no proven card to send back to the deck.
var stand_in := false
var doubter: PlayerState
var failed := false  # caught lying, or could not pay
var cancelled := false
var blocked := false
var reflected := false


func is_claim() -> bool:
	return source is Ability


func ability() -> Ability:
	return source as Ability
