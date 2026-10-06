class_name ItemDef
extends Playable
## An item sold in the shop. Drop a script extending this in
## res://scripts/content/items and it is picked up by Content.

enum Kind {
	ACTIVE,  # used from the inventory during your turn
	PASSIVE,  # works by itself through on_held_event()
	REACTION,  # may be used when reacts_to() says so
}

var price := 0
var texture_path := ""
var kind := Kind.ACTIVE
## Always on sale: takes no shop slot, survives rerolls and can't be banned.
var fixed := false
var status_defs: Dictionary = {}


## Called for every event while `holder` owns `instance`.
func on_held_event(_event: GameEvent, _holder: PlayerState, _instance: ItemInstance, _engine: GameEngine) -> void:
	pass


func kind_label() -> String:
	match kind:
		Kind.PASSIVE:
			return Loc.t("Passive")
		Kind.REACTION:
			return Loc.t("Reaction")
	return Loc.t("Use on your turn")


## How much a bot wants to buy this (0 = never).
func ai_buy_weight(_player: PlayerState, _engine: GameEngine) -> float:
	return 1.0
