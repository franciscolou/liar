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
## Not an item but something done on the spot (fresh_card.gd): bought, it
## resolves at once, as a play of the buyer, and nothing goes to the
## inventory (so a full one doesn't stop it).
var service := false
## Takes the entire turn: it can only be bought while nothing else was done
## this turn, and it ends it (like Ability.fresh_turn + ends_turn).
var whole_turn := false
## A passive item that answers a play aimed at its holder (shield.gd,
## mirror.gd). Only one of them acts on a play: see GameEngine.guards().
var guard := false
var status_defs: Dictionary = {}


## Called for every event while `holder` owns `instance`.
func on_held_event(_event: GameEvent, _holder: PlayerState, _instance: ItemInstance, _engine: GameEngine) -> void:
	pass


func kind_label() -> String:
	if service:
		return Loc.t("Takes the entire turn") if whole_turn else Loc.t("Done on the spot")
	match kind:
		Kind.PASSIVE:
			return Loc.t("Passive")
		Kind.REACTION:
			return Loc.t("Reaction")
	return Loc.t("Use on your turn")


## How much a bot wants this one, of the guards it holds, to answer `play`.
func ai_guard_weight(_play: Play, _holder: PlayerState) -> float:
	return 1.0


## How much a bot wants to buy this (0 = never).
func ai_buy_weight(_player: PlayerState, _engine: GameEngine) -> float:
	return 1.0
