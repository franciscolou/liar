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
## May hold placeholders, filled from `description_args` after translation
## (see describe()): the numbers then follow the code in every language.
var description := "":
	get:
		return Loc.fill(description, description_args)
var description_args: Array = []
## A side remark under the description, shown fainter than it.
var footnote := "":
	get:
		return Loc.t(footnote)
var targeting := Targeting.NONE
## Free-form labels. Statuses can block tags (a hexed player can't use
## anything tagged &"damage" or &"heal").
var tags: Array = []
## Puts a status on its target, with the user as its `by`.
var inflicts := false
## Nothing its target holds answers it: shields and mirrors stay as they are
## (see GameEngine.guards).
var unstoppable := false
## As a reaction, only one player can get it (the coins of a Swindle, an
## ability to silence): it goes to whoever plays it first, not by seat (see
## GameEngine._contested_window).
var contested := false


## Sets a description whose numbers come from the code: `text` keeps its
## placeholders ("Gain %d coins.") and is the translation key as written.
func describe(text: String, args: Array) -> void:
	description = text
	description_args = args


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


## True when playing this in answer to `event` (null if not known yet) is
## `player` looking after themselves: their own Morale, coins, cards, items,
## statuses or claim. Whoever is to keep still (the chains of an Entropy) may
## still do that; anything else reaches out and costs them (entity.gd).
func for_oneself(_event: GameEvent, _player: PlayerState) -> bool:
	return false


# --- hints for BotController -------------------------------------------------

## How much a bot wants to play this on its turn (0 = never).
func ai_weight(_player: PlayerState, _engine: GameEngine) -> float:
	return 1.0


func ai_target_weight(_play: Play, candidate: PlayerState) -> float:
	return 1.0 + candidate.coins * 0.05 + (3 - candidate.morale) * 0.3


## Added to a bot's chance of calling LIAR! on this play (it may be negative).
func ai_suspicion(_play: Play, _doubter: PlayerState) -> float:
	return 0.0


## How much a bot wants to play this as a reaction to `event` (0..1).
func ai_react_weight(_event: GameEvent, _player: PlayerState, _engine: GameEngine) -> float:
	return 1.0
