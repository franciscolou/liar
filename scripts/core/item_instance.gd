class_name ItemInstance
extends RefCounted
## One copy of an item sitting in an inventory.

var def: ItemDef
var hidden := false  # other players only see the item back
## The turn (GameEngine.turn_count) it was handed over sealed in: it can't be
## used before that turn is over (see GameEngine.item_lock_reason).
var sealed_turn := -1


func _init(item_def: ItemDef = null) -> void:
	def = item_def
