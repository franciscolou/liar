extends Node

@onready var gm = $GameManager
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	gm.create_players()
	gm.connect_skill_signals()
	gm.deck_manager.initial_draw(gm.players)
	gm.set_available_actions()
	gm.current_player = gm.players[0]
	gm.current_player.coins += 1
	gm.flip_cards(gm.current_player)
	gm.current_player.get_node("TurnIndicator").visible = true
	gm.set_helperlabel(gm.current_player.pname + "'s turn")
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	gm.update()
