class_name ItemInstance
extends RefCounted
## One copy of an item sitting in an inventory.

var def: ItemDef
var hidden := false  # other players only see the item back


func _init(item_def: ItemDef = null) -> void:
	def = item_def
