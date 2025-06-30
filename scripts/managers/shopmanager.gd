class_name ShopManager

extends Node

@onready var gm := get_node("/root/Main/GameManager")
@onready var sounds_player = get_node("/root/Main/SoundsPlayer")
@onready var shopgui := gm.get_node("ShopGUI")
var item_scenes: Array[PackedScene] = []
var unique_items: Array[Item] = []
var max_items: int = 2
var store_items: Array[Item] = []

func _ready():
	var dir = DirAccess.open("res://scenes/items")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tscn"):
				var full_path = "res://scenes/items/" + file_name
				var scene = load(full_path)
				if scene is PackedScene:
					item_scenes.push_back(scene)
					unique_items.push_back(scene.instantiate())
			file_name = dir.get_next()
		dir.list_dir_end()
	restock_store()

func restock_store():
	store_items.clear()
	for i in max_items:
		add_random_item_to_store()

func add_random_item_to_store():
	for slot in shopgui.get_children():
		if slot.get_children().size() == 1:
			var new_item = item_scenes.pick_random().instantiate()
			var new_item_image = new_item.get_node("TextureButton")
			new_item_image.visible = true
			new_item_image.pressed.connect(_on_item_pressed.bind(new_item))
			slot.add_child(new_item)
			slot.get_node("BuyOptions").get_node("Price").text = str(new_item.price)
			var img_path = "res://assets/items/" + new_item.iname + ".png"
		
			
func _on_item_pressed(item: Item) -> void:
	if gm.current_player.coins >= item.price and gm.current_player.items.size() < 3:
		toggle_buy_options(item)

func toggle_buy_options(item: Item):
	var buy_options = item.get_parent().get_node("BuyOptions")
	var new_state = !buy_options.get_node("Buy").visible
	buy_options.get_node("Buy").visible = new_state
	buy_options.get_node("BuyAsSpy").visible = new_state
	
func buy_item(item: Item) -> void:
	var player = gm.current_player
	sell_item(item, player)
	store_items.erase(item)
	add_random_item_to_store()
	
func _on_item_use(item: Item) -> void:
	if item.i_owner == gm.current_player:
		var skill_scene = item.get_node("Action")
		if skill_scene.can_make_action(gm.current_player):
			gm.current_player.requested_item = item.iname
			gm.set_log(gm.current_player.pname + " used " + item.iname + ".")
			if skill_scene.target_needed and gm.current_player.target == null:
				gm.state = "waiting_target"
			else:
				await gm.get_item_by_name(gm.current_player.requested_item).action(gm.current_player)
				for it in gm.current_player.get_node("Inventory").get_children():
					var inner_item = it.get_child(0)
					if inner_item and inner_item.iname == gm.current_player.requested_item:
						#inner_item.queue_free()
						it.remove_child(inner_item)
						inner_item.get_node("ItemBack").visible = false
						gm.current_player.items.erase(item)
						break

func sell_item(item: Item, player: Player) -> Item:
	sounds_player.stream = load("res://assets/sounds/spend.mp3")
	sounds_player.play()
	player.coins -= item.price
	item.i_owner = player
	var item_img = item.get_node("TextureButton")
	var item_in_slot_size = item_img.size * 0.6
	item_img.visible = true

	# Remove callbacks antigos
	if item_img.is_connected("pressed", Callable(self, "_on_item_pressed")):
		item_img.disconnect("pressed", Callable(self, "_on_item_pressed"))

	# Conecta callback do inventário
	item_img.pressed.connect(_on_item_use.bind(item))

	# Remove item da loja
	for i in shopgui.get_children():
		if i.get_child(1) == item:
			i.remove_child(item)

	# Adiciona no inventário
	player.items.push_back(item)
	var slot = find_empty_slot(player)
	if slot:
		slot.add_child(item)

	return item
	
func find_empty_slot(player: Player) -> Node2D:
	for slot in player.get_node("Inventory").get_children():
		if slot.get_child(0) == null:
			return slot
	return null

func confiscate_item(player: Player) -> void:
	var item_removed = player.items.pop_back()
	player.remove_child(item_removed)
