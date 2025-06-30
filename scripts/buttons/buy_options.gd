extends Node

@onready var gm := get_node("/root/Main/GameManager")
@onready var sm := get_node("/root/Main/GameManager/ShopManager")
@onready var button_a = $Buy
@onready var button_b = $BuyAsSpy

func _ready():
	button_a.pressed.connect(_on_button_a_pressed)
	button_b.pressed.connect(_on_button_b_pressed)

func _on_button_a_pressed():
	var item = get_parent().get_child(1)
	sm.buy_item(item)
	for node in get_parent().get_parent().get_children():
		var buy_options = node.get_child(0)
		buy_options.get_node("Buy").visible = false
		buy_options.get_node("BuyAsSpy").visible = false
	
func _on_button_b_pressed():
	var item = get_parent().get_child(1)
	for node in get_parent().get_parent().get_children():
		var buy_options = node.get_child(0)
		buy_options.get_node("Buy").visible = false
		buy_options.get_node("BuyAsSpy").visible = false
	gm.current_player.requested_action = "Low Profile"
	gm.current_player.requested_item = item.iname
	gm.spy_item = item
	gm.show_challenge_options(gm.current_player)
