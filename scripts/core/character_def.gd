class_name CharacterDef
extends RefCounted
## A character card. Drop a script extending this in
## res://scripts/content/characters and it is picked up by Content.

var id: StringName
## Written in English; reads come back in the current language (see Loc).
var display_name := "":
	get:
		return Loc.t(display_name)
var title := "":
	get:
		return Loc.t(title)
var texture_path := ""
var order := 0
var abilities: Array = []  # Ability
## status id -> {name, description, color}; shown as chips on the player.
## Texts in these two are English too: pass them through Loc.t() to show them.
var status_defs: Dictionary = {}
## counter id -> {name, description, icon, private}; shown next to the player's
## coins. A private counter is only shown to its owner.
var counter_defs: Dictionary = {}


## Called for every event while this character is part of the match, no
## matter who holds it. Use it for standing effects (see voodooist.gd).
func on_event(_event: GameEvent, _engine: GameEngine) -> void:
	pass


## Extra options for `player`'s turn menu:
## [{id, label, description, cost, enabled, reason, run: Callable(player, engine)}]
## Optional: ai (chance 0..1 that a bot takes it, default 0.7).
func turn_extras(_player: PlayerState, _engine: GameEngine) -> Array:
	return []


func _add(ability: Ability) -> void:
	ability.character_id = id
	abilities.append(ability)
