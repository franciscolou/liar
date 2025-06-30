class_name Player

extends Node2D

@export var pname: String
@export var shielded: bool = false
@export var coins: int = 2
@export var cards: Array[Card]
@export var items: Array[Item]
@export var requested_action: String
@export var requested_item: String
@export var target: Player

const CARD_SPACING: int = 10  # Space between cards
const CARD_Y: int = 30  # Space between cards

signal doubt_pressed
signal target_selected
signal passup_pressed

func _ready() -> void:
	$LIAR.connect("pressed", Callable(self, "_on_doubt_button_pressed"))
	$PassUp.connect("pressed", Callable(self, "_on_pass_up_button_pressed"))
	$".".connect("input_event", Callable(self, "_on_input_event"))
	
func update():
	var x_offset = 0
	$Coin.text = str(coins)
	for card in cards:
		card.position = Vector2(x_offset, CARD_Y)
		x_offset += card.get_node("TextureButton").size.x + CARD_SPACING
		
		
func _on_doubt_button_pressed():
	emit_signal("doubt_pressed", self)

func _on_pass_up_button_pressed() -> void:
	emit_signal("passup_pressed", self)
	
func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		emit_signal("target_selected", self)
