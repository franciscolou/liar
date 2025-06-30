extends Skill

@onready var gm := get_node("/root/Main/GameManager")
@onready var sm := get_node("/root/Main/GameManager/ShopManager")

signal spy_buy

func action(player: Player) -> void:
	emit_signal("spy_buy", self)
