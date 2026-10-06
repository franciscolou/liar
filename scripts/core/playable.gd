class_name Playable
extends RefCounted
## Common ground between character abilities and items: something a player
## puts into play, optionally aimed at someone, that then resolves.

enum Targeting {
	NONE,
	OPPONENT,  # the player picks one of target_candidates()
	RANDOM,  # the engine picks one of target_candidates()
}

var id: StringName
## Written in English; reads come back in the current language (see Loc).
var display_name := "":
	get:
		return Loc.t(display_name)
var description := "":
	get:
		return Loc.t(description)
var targeting := Targeting.NONE
## Free-form labels. Statuses can block tags (a hexed player can't use
## anything tagged &"damage" or &"heal").
var tags: Array = []


## "" when usable, otherwise the reason shown to the player.
func can_use(_player: PlayerState, _engine: GameEngine) -> String:
	return ""


func target_candidates(play: Play) -> Array:
	return play.engine.targetable_opponents(play.actor)


## Extra choices made before the play is announced (it may also change
## play.cost). Return false to cancel.
func prepare(_play: Play) -> bool:
	return true


func resolve(_play: Play) -> void:
	pass


## True when `player` may play this in response to `event`.
func reacts_to(_event: GameEvent, _player: PlayerState, _engine: GameEngine) -> bool:
	return false


# --- hints for BotController -------------------------------------------------

## How much a bot wants to play this on its turn (0 = never).
func ai_weight(_player: PlayerState, _engine: GameEngine) -> float:
	return 1.0


func ai_target_weight(_play: Play, candidate: PlayerState) -> float:
	return 1.0 + candidate.coins * 0.05 + (3 - candidate.morale) * 0.3


## How much a bot wants to play this as a reaction to `event` (0..1).
func ai_react_weight(_event: GameEvent, _player: PlayerState, _engine: GameEngine) -> float:
	return 1.0
