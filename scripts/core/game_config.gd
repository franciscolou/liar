class_name GameConfig
extends RefCounted
## Everything the pre-game screen decides. The engine reads it once in setup.

## Config chosen in the setup screen; survives scene changes.
static var current: GameConfig
## Name of the last winner, shown by the end screen.
static var last_winner := ""
## The hand the last winner was holding (character ids), for the end screen to
## show once: it empties this as it reads it.
static var last_winner_cards: Array = []

var seats: Array = []  # [{name: String, bot: bool}]
var character_ids: Array = []  # empty = pick `character_count` at random
var character_count := 5
var copies_per_character := 3
var item_ids: Array = []  # empty = every registered item
var hand_size := 2
var start_morale := 3
var start_coins := 2
var income := 1
var doubt_cost := 4
var shop_slots := 3
var reroll_cost := 2
var inventory_limit := 3
var anim_speed := 1.0
var max_turns := 0  # 0 = unlimited (used by headless simulations)
var rng_seed := 0  # 0 = random


static func default_config() -> GameConfig:
	var c := GameConfig.new()
	c.seats = [
		{"name": "Player 1", "bot": false},
		{"name": "Bones", "bot": true},
		{"name": "Pablo", "bot": true},
		{"name": "Miah", "bot": true},
	]
	return c


## Smallest deck that deals every hand and still leaves cards to draw.
func min_copies(char_count: int) -> int:
	var needed := seats.size() * hand_size + 2
	return maxi(2, ceili(float(needed) / float(maxi(char_count, 1))))


## What travels between the machines of a room (see to_wire).
const WIRE_FIELDS := [
	"seats", "character_count", "copies_per_character", "hand_size", "start_morale",
	"start_coins", "income", "doubt_cost", "shop_slots", "reroll_cost",
	"inventory_limit", "anim_speed", "max_turns", "rng_seed",
]


## The config as plain data, for the other machines of a room.
func to_wire() -> Dictionary:
	var out := {
		"character_ids": character_ids.map(func(id: Variant) -> String: return String(id)),
		"item_ids": item_ids.map(func(id: Variant) -> String: return String(id)),
	}
	for field: String in WIRE_FIELDS:
		out[field] = get(field)
	return out


static func from_wire(data: Dictionary) -> GameConfig:
	var c := GameConfig.new()
	for field: String in WIRE_FIELDS:
		if typeof(data.get(field)) == typeof(c.get(field)):
			c.set(field, data[field])
	for id: Variant in data.get("character_ids", []):
		c.character_ids.append(StringName(str(id)))
	for id: Variant in data.get("item_ids", []):
		c.item_ids.append(StringName(str(id)))
	return c
