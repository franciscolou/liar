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
## A doubted claim that stood without its card being shown: there is no
## proven card to send back to the deck.
var stand_in := false
var doubter: PlayerState
var failed := false  # caught lying, or could not pay
var cancelled := false
var blocked := false
## Going the other way from how it was aimed: actor and target traded
## places an odd number of times (see mirror.gd).
var reflected := false


## The play this one is really about: the one it carries out in its place
## (params.repeat, see impostor.gd), or itself. Its source and target are
## what the table should be told.
func aimed() -> Play:
	return params.get("repeat", self)


func is_claim() -> bool:
	return source is Ability


func ability() -> Ability:
	return source as Ability
