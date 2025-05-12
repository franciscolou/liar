class_name DeckManager

extends Node

var card_scenes: Array[PackedScene] = []
var unique_cards: Array[Card] = []
var max_different_cards: int = 3
var each_card_amount: int = 3
@export var deck: Array[Card]

func _ready():
	var dir = DirAccess.open("res://scenes/cards")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tscn"):
				var full_path = "res://scenes/cards/" + file_name
				var scene = load(full_path)
				if scene is PackedScene:
					card_scenes.push_back(scene)
					unique_cards.push_back(scene.instantiate())
			file_name = dir.get_next()
		dir.list_dir_end()
		
	card_scenes.shuffle()
	for i in max_different_cards:
		for j in each_card_amount:
			var card_unpacked = card_scenes[i].instantiate()
			card_unpacked.get_node("TextureButton").visible = true
			deck.push_back(card_unpacked)
	deck.shuffle()
	
func draw_card(player: Player) -> Card:
	var card: Card = deck.pop_back()
	player.cards.push_back(card)
	player.add_child(card)
	return card
	
func confiscate_card(player: Player) -> void:
	var card_removed = player.cards.pop_back()
	player.remove_child(card_removed)
	
	
func initial_draw(players: Array[Player]) -> void:
	for i in players.size():
		var player = players[i]
		var card1 = draw_card(player)
		var card2 = draw_card(player)
		card1.flip()
		card2.flip()
		
func exchange_card(player: Player, out_card: Card) -> void:
	player.cards.erase(out_card)
	player.remove_child(out_card)
	
	var new_card = deck.pop_back()
	deck.append(out_card)
	deck.shuffle()
	
	player.cards.append(new_card)
	player.add_child(new_card)
		
