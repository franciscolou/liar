extends Node

@export var players: Array[Player]
@export var current_player: Player
@export var turn: int
@export var state: String = "waiting_action"
@export var deck_manager: DeckManager
@export var shop_manager: ShopManager
@export var approval: int = 1

var window_size
var centerX
var centerY
var rH = 400 # raio horizontal
var rV = 200 # raio vertical
var doubt_cost = 2
var spy_item = null
 
@onready var player_scene = preload("res://scenes/player.tscn")
@onready var sounds_player = get_node("/root/Main/SoundsPlayer")

func _ready() -> void:
	window_size = get_viewport().get_visible_rect().size
	centerX = (window_size.x / 2) - window_size.x / 15
	centerY = (window_size.y / 2) - window_size.y / 9
	
	
func create_players(amount: int = 4) -> void:
	for i in amount:
		var new_player = player_scene.instantiate()
		new_player.pname = "Player " + str(i)
		players.push_back(new_player)
		add_child(new_player)
		new_player.get_node("Name").text = new_player.pname
	for p in players:
		p.connect("doubt_pressed", Callable(self, "_on_player_doubted"))
		p.connect("passup_pressed", Callable(self, "_on_passup"))
		p.connect("target_selected", Callable(self, "_on_target_selected"))

func flip_cards(player: Player) -> void:
	for c in player.cards:
		c.flip()
		
func connect_skill_signals():
	get_skill_by_name("Fickle").connect("heir_exchange", Callable(self, "_on_heir_exchange"))
	get_skill_by_name("Blood Count").connect("damage", Callable(self, "_on_damage"))
	get_skill_by_name("Low Profile").connect("spy_buy", Callable(self, "_on_spy_buy"))
	get_item_by_name("Potion").connect("recover", Callable(self, "_on_recover"))
	get_item_by_name("Death").connect("damage", Callable(self, "_on_damage"))

func set_helperlabel(text: String) -> void:
	get_node("HelperLabel").text = text

func set_log(text: String) -> void:
	get_node("HelperLabel/ActionLogger").text = text
	
func get_skill_by_name(action_name: String) -> Skill:
	for card in deck_manager.unique_cards:
		if action_name == card.skill1.sname:
			return card.skill1
		if action_name == card.skill2.sname:
			return card.skill2
	return null
	
func get_item_by_name(item_name: String) -> Skill:
	for item in shop_manager.unique_items:
		if item_name == item.iname:
			return item.action
	return null
	
func find_skill_in_player(player: Player, skill_name: String) -> Skill:
	for card in player.cards:
		if card.skill1.sname == player.requested_action:
			return card.skill1
		if card.skill2.sname == player.requested_action:
			return card.skill2
	return null

func set_available_actions() -> void:
	var option_button = $ActionGUI.get_node("ActionSelection")
	var index_in_dropdown = 1

	for i in range(deck_manager.unique_cards.size()):
		var scene = deck_manager.unique_cards[i]
		
		var original_texture: Texture2D = scene.get_node("TextureButton").texture_normal
		var image: Image = original_texture.get_image()
		image.resize(26, 47, Image.INTERPOLATE_LANCZOS)
		var small_texture: ImageTexture = ImageTexture.create_from_image(image)

		var action_identifier = scene.skill1.sname + ": " + scene.skill1.description
		option_button.add_item(action_identifier)
		option_button.set_item_metadata(index_in_dropdown, scene.skill1)
		option_button.set_item_icon(index_in_dropdown, small_texture)
		index_in_dropdown += 1 

		action_identifier = scene.skill2.sname + ": " + scene.skill2.description
		option_button.add_item(action_identifier)
		option_button.set_item_metadata(index_in_dropdown, scene.skill2)
		option_button.set_item_icon(index_in_dropdown, small_texture)
		index_in_dropdown += 1
		
func show_challenge_options(origin_player: Player) -> void:
	if state != "waiting_target":
		for player in players:
			if player != origin_player:
				if player.coins >= doubt_cost:
					player.get_node("LIAR").visible = true
					player.get_node("PassUp").visible = true
				else:
					increment_approval()
			
func _on_player_doubted(doubting_player: Player) -> void:
	sounds_player.stream = load("res://assets/sounds/doubt.mp3")
	sounds_player.play()
	var p_action_name = current_player.requested_action
	var action_is_legit = false
	var log_text = ""
	var action
	for card in current_player.cards:
		if card.skill1.sname == p_action_name or card.skill2.sname == p_action_name:
			doubting_player.coins = doubting_player.coins - doubt_cost
			action = get_skill_by_name(current_player.requested_action)
			hide_challenge_options()
			await action.action(current_player)
			log_text = doubting_player.pname + " doubted and broke their nose!\n" + current_player.pname + " gets to do their action."
			action_is_legit = true
			break
	if not action_is_legit:
		apply_non_blockable_damage(current_player)
		print("aplicou dano nao bloqueavel")
		log_text = doubting_player.pname + " doubted and revealed " + current_player.pname + "!"
	hide_challenge_options()
	if ((action and action.ends_turn) or !action_is_legit):
		print("era pra ir next")
		next(log_text)
	
func _on_passup(passing_player: Player) -> void:
	passing_player.get_node("PassUp").visible = false
	passing_player.get_node("LIAR").visible = false
	increment_approval()

func increment_approval() -> void:
	approval += 1
	if approval >= players.size():
		var action = get_skill_by_name(current_player.requested_action)
		await action.action(current_player)
		approval = 1
		if action.ends_turn:
			next("Everyone passed up! " + current_player.pname + " went ahead with their action.")
		
func apply_damage(player: Player) -> void:
	if not player.shielded:
		sounds_player.stream = load("res://assets/sounds/damage.mp3")
		sounds_player.play()
		deck_manager.confiscate_card(player)
		if player.cards.size() == 0:
			players.erase(player)
			remove_child(player)
		if players.size() == 1:
			var end_scene = get_node("End")
			end_scene.visible = true
			end_scene.get_node("Label").text = current_player.pname + " now holds the\nCarcaj's crown."
	else:
		player.shielded = false
		sounds_player.stream = load("res://assets/sounds/breaking.mp3")
		sounds_player.play()
		player.get_node("ShieldIndicator").visible = false

func apply_non_blockable_damage(player: Player) -> void:
	sounds_player.stream = load("res://assets/sounds/damage.mp3")
	sounds_player.play()
	deck_manager.confiscate_card(player)
	if player.cards.size() == 0:
		players.erase(player)
		remove_child(player)
	if players.size() == 1:
		get_node("End").visible = true

func _on_target_selected(target: Player) -> void:
	if state == "waiting_action" or state == "waiting_target":
		if target != current_player:
			for player in players:
				player.get_node("TargetIndicator").visible = false
			current_player.target = target
			current_player.target.get_node("TargetIndicator").visible = true
			if get_skill_by_name(current_player.requested_action):
				state = "waiting_approval"
			if get_item_by_name(current_player.requested_item):
				await get_item_by_name(current_player.requested_item).action(current_player)
				for item in current_player.get_node("Inventory").get_children():
					var inner_item = item.get_child(0)
					if inner_item and inner_item.iname == current_player.requested_item:
						inner_item.queue_free()
						current_player.target.get_node("TargetIndicator").visible = false
						current_player.target = null
						current_player.requested_item = ""
						for it in current_player.items:
							if it.iname == inner_item.iname:
								current_player.items.erase(it)
								break
						break

	if current_player.requested_action != "":
		show_challenge_options(current_player)
	if current_player.target:
		set_log(current_player.pname + " targeted " + current_player.target.pname + ".")

func _on_heir_exchange(skill: Skill):
	var player = current_player
	var heir_in_player = find_skill_in_player(player, player.requested_action)
	if heir_in_player:
		deck_manager.exchange_card(player, heir_in_player.get_parent())
	else:
		deck_manager.exchange_card(player, player.cards.pick_random())
		
func _on_spy_buy(skill: Skill) -> void:
	#spy_item.flip()
	spy_item.is_hidden = true
	shop_manager.buy_item(spy_item)
		
func _on_damage(skill: Skill):
	apply_damage(current_player.target)
	
func _on_recover(skill: Skill):
	deck_manager.draw_card(current_player)
	
func hide_challenge_options():
	for player in players:
		player.get_node("LIAR").visible = false
		player.get_node("LIAR").disabled = false
		player.get_node("PassUp").visible = false
		player.get_node("PassUp").disabled = false
		
func update() -> void:
	for i in players.size():
		var angle = (i - 1) * (2 * PI / players.size())
		players[i].position = Vector2(
			centerX + cos(angle) * rH,
			centerY + sin(angle) * rV
		)
		players[i].update()
	
func next(log_text: String = "") -> void:
	for player in players:
		player.get_node("TargetIndicator").visible = false
	turn = (turn + 1) % players.size()
	approval = 1
	
	for item in current_player.get_node("Inventory").get_children():
		var inner_item = item.get_child(0)
		if inner_item and !inner_item.get_node("ItemBack").visible and inner_item.is_hidden:
			inner_item.flip()
			
	current_player.requested_action = ""
	current_player.requested_item = ""
	current_player.target = null
	current_player.get_node("TurnIndicator").visible = false
	
	flip_cards(current_player)
	current_player = players[turn]
	flip_cards(current_player)
	
	current_player.coins += 1
	current_player.get_node("TurnIndicator").visible = true
	
	for item in current_player.get_node("Inventory").get_children():
		var inner_item = item.get_child(0)
		if inner_item and inner_item.get_node("ItemBack").visible:
			inner_item.flip()
			
	state = "waiting_action"
	hide_challenge_options()
	set_helperlabel(current_player.pname + "'s turn")
	set_log(log_text)
	$ActionGUI.get_node("ActionSelection").disabled = false
	$ActionGUI.get_node("ActionSelection").selected = 0
	
	
