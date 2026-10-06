class_name GameConfig
extends RefCounted
## Everything the pre-game screen decides. The engine reads it once in setup.

## Config chosen in the setup screen; survives scene changes.
static var current: GameConfig
## Name of the last winner, shown by the end screen.
static var last_winner := ""

var seats: Array = []  # [{name: String, bot: bool}]
var character_ids: Array = []  # empty = pick `character_count` at random
var character_count := 5
var copies_per_character := 3
var item_ids: Array = []  # empty = every registered item
var hand_size := 2
var start_morale := 3
var start_coins := 2
var income := 1
var doubt_cost := 2
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
