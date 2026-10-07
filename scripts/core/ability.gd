class_name Ability
extends Playable
## A character ability. Anyone may claim it; only players holding the
## character are telling the truth. Subclass it inside the character's file.
##
## Turn abilities set `on_turn`. Reaction abilities override reacts_to() and
## are offered in the window the engine opens after every event.

var character_id: StringName
var cost := 0
## Can be chosen as the action of your own turn.
var on_turn := false
var ends_turn := true
## Only usable if nothing else was done this turn.
var fresh_turn := false
## Pure description of an always-on effect; never claimed on its own.
var info_only := false
## May react to an event produced by its own resolution (kill streaks).
var self_chain := false
## Short text telling the player when a reaction ability can be claimed.
var trigger_text := "":
	get:
		return Loc.t(trigger_text)


## For reactions: true when `player` may already answer `play` with this as
## it is announced, in the doubt window, because what triggers it is plain to
## see coming (doctor.gd). It is still claimed when its own trigger comes.
func foresees(_play: Play, _player: PlayerState, _engine: GameEngine) -> bool:
	return false


func kind_label() -> String:
	if info_only:
		return Loc.t("Passive")
	if on_turn:
		return Loc.t("Action")
	return Loc.t("Reaction")
