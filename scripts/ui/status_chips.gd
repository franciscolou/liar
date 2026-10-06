class_name StatusChips
extends HFlowContainer
## Small coloured tags for the statuses on a player (Hexed, Under Oath...).

var _shown := ""


func _init() -> void:
	add_theme_constant_override("h_separation", 3)
	add_theme_constant_override("v_separation", 2)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_shown = ""  # redraw on the next sync


func sync(player: PlayerState, engine: GameEngine) -> void:
	var signature := str(player.statuses.keys())
	if signature == _shown:
		return
	_shown = signature
	UI.clear(self)
	for status_id: StringName in player.statuses:
		var def: Dictionary = Content.statuses.get(status_id, {})
		var color: Color = def.get("color", UI.MUTED)
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", UI.box(color.darkened(0.45), color, 1, 3, 3))
		chip.mouse_filter = Control.MOUSE_FILTER_PASS
		chip.add_child(UI.label(Loc.t(def.get("name", String(status_id))).to_upper(), 10, UI.CREAM, true))
		var tip := "[b]%s[/b]\n%s" % [Loc.t(def.get("name", status_id)), Loc.t(def.get("description", ""))]
		var by := engine.player_by_id(player.statuses[status_id].get("by", -1))
		if by != null:
			tip += "\n[color=%s]%s[/color]" % [UI.hex(UI.MUTED), Loc.t("Placed by %s.") % by.name]
		TipLayer.attach(chip, tip)
		add_child(chip)
		UI.pop(chip, 1.4)
