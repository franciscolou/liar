class_name StatBar
extends HBoxContainer
## Morale hearts, coins and content counters (vault...) of one player.

var _hearts: HBoxContainer
var _coin_icon: TextureRect
var _coins: Label
var _counters: HBoxContainer
## Coins shown on top of what the player really has, while an animation is
## still carrying them in or out (see add_coins).
var coin_bias := 0
var _shown_coins := -9999
var _shown_morale := -1
var _shown_counters := ""
var _icon_size: int


func _init(icon_size := 18, font_size := 16) -> void:
	_icon_size = icon_size
	add_theme_constant_override("separation", 6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hearts = HBoxContainer.new()
	_hearts.add_theme_constant_override("separation", 1)
	_hearts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hearts)
	_coin_icon = _icon("res://assets/ui/coin.png")
	add_child(_coin_icon)
	_coins = UI.label("0", font_size, UI.GOLD, true)
	add_child(_coins)
	_counters = HBoxContainer.new()
	_counters.add_theme_constant_override("separation", 3)
	add_child(_counters)


## `owner_view`: the bar is shown to the player it describes, so private
## counters are included.
func sync(player: PlayerState, max_morale: int, owner_view := false) -> void:
	if player.morale != _shown_morale:
		_shown_morale = player.morale
		UI.clear(_hearts)
		for i in max_morale:
			_hearts.add_child(_icon("res://assets/ui/heart.png" if i < player.morale else "res://assets/ui/heart_empty.png"))
	if player.coins + coin_bias != _shown_coins:
		_show_coins(player.coins + coin_bias, _shown_coins != -9999)
	var signature := str(player.counters)
	if signature != _shown_counters:
		_shown_counters = signature
		UI.clear(_counters)
		for counter_id: StringName in player.counters:
			var def: Dictionary = Content.counters.get(counter_id, {})
			if player.counters[counter_id] == 0 or (def.get("private", false) and not owner_view):
				continue
			var icon := _icon(def.get("icon", "res://assets/ui/coin.png"))
			icon.mouse_filter = Control.MOUSE_FILTER_PASS
			TipLayer.attach(icon, "[b]%s[/b]\n%s" % [Loc.t(def.get("name", counter_id)), Loc.t(def.get("description", ""))])
			_counters.add_child(icon)
			_counters.add_child(UI.label(str(player.counters[counter_id]), _coins.get_theme_font_size("font_size"), UI.BLUE, true))
		UI.pop(_counters, 1.3)


## Keeps showing the current number although `player` already has another:
## the difference is then counted in with add_coins, coin by coin.
func hold_coins(player: PlayerState) -> void:
	if _shown_coins != -9999:
		coin_bias = _shown_coins - player.coins


## Moves the number shown by `amount` without waiting for the next sync.
func add_coins(amount: int) -> void:
	if amount == 0 or _shown_coins == -9999:
		return
	coin_bias += amount
	_show_coins(_shown_coins + amount, true)


func _show_coins(value: int, pop: bool) -> void:
	_shown_coins = value
	_coins.text = str(value)
	_coins.add_theme_color_override("font_color", UI.RED if value < 0 else UI.GOLD)
	if pop:
		UI.pop(_coins, 1.5)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_shown_counters = ""  # their tooltips are in the old language


func coin_center() -> Vector2:
	return _coin_icon.global_position + _coin_icon.size / 2.0


func hearts_center() -> Vector2:
	return _hearts.global_position + _hearts.size / 2.0


func _icon(path: String) -> TextureRect:
	var t := TextureRect.new()
	t.texture = UI.tex(path)
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(_icon_size, _icon_size)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t
