class_name EventText
extends RefCounted
## Turns events into log lines. Returns "" for events that are not news
## (or that only one player is allowed to know about).


static func describe(e: GameEvent) -> String:
	var d := e.data
	match e.type:
		&"turn_started":
			return Loc.t("— %s's turn —") % d.player.name
		&"coins":
			return _coins(d)
		&"item_bought":
			return Loc.t("%s buys %s.") % [d.player.name, _item(d.item)]
		&"shop_rerolled":
			return Loc.t("%s rerolls the shop.") % d.player.name
		&"item_gained":
			return Loc.t("%s gets %s.") % [d.player.name, _item(d.item)]
		&"item_used":
			return Loc.t("%s uses %s%s.") % [d.player.name, d.item.def.display_name, _on(d.play)]
		&"item_stolen":
			return Loc.t("%s takes %s from %s.") % [d.thief.name, _item(d.item), d.victim.name]
		&"item_missed":
			return Loc.t("%s finds nothing to take from %s.") % [d.thief.name, d.victim.name]
		&"item_broken":
			return Loc.t("%s's %s breaks.") % [d.player.name, d.item.def.display_name]
		&"claim_declared":
			var play: Play = d.play
			return Loc.t("%s claims %s: %s%s.") % [
				play.actor.name, Content.character(play.ability().character_id).display_name,
				title(play), _on(play)]
		&"claim_cancelled":
			return Loc.t("%s is silenced.") % d.play.source.display_name
		&"doubt_declared":
			return Loc.t("%s shouts LIAR!") % d.doubter.name
		&"doubt_revealed":
			if d.truthful:
				return Loc.t("%s was telling the truth.") % d.play.actor.name
			return Loc.t("%s was lying!") % d.play.actor.name
		&"targeted":
			if d.get("blocked", false):
				return Loc.t("%s blocks it.") % d.target.name
			if d.get("reflected", false):
				return Loc.t("%s reflects it!") % d.target.name
		&"morale_lost":
			return Loc.t("%s loses %d Morale.") % [d.target.name, d.amount]
		&"morale_gained":
			return Loc.t("%s recovers %d Morale.") % [d.player.name, d.amount]
		&"player_eliminated":
			return Loc.t("%s is eliminated.") % d.player.name
		&"cards_changed":
			return Loc.t("%s draws a new card.") % d.player.name
		&"card_lost":
			return Loc.t("%s gives up the %s.") % [d.player.name, Content.character(d.card).display_name]
		&"card_drawn":
			return Loc.t("%s draws a card.") % d.player.name
		&"cards_recalled":
			var names: Array = []
			for hand: Dictionary in d.hands:
				if not names.has(hand.player.name):
					names.append(hand.player.name)
			return Loc.t("Last call for the %s: new cards for %s.") % [
				Content.character(d.card).display_name, ", ".join(names)]
		&"hand_redrawn":
			return Loc.t("%s trades the whole hand for new cards.") % d.player.name
		&"coin_flipped":
			return Loc.t("%s flips a coin: heads" if d.heads else "%s flips a coin: tails") % d.player.name + ("!" if d.won else ".")
		&"note":
			return Loc.t(d.text) % d.player.name
		&"cards_swapped":
			return Loc.t("%s and %s trade a card.") % [d.a.name, d.b.name]
		&"card_peeked":
			return Loc.t("%s peeks at one of %s's cards.") % [d.viewer.name, d.owner.name]
		&"status_added":
			return Loc.t("%s: %s.") % [d.player.name, _status(d.status)]
		&"status_removed":
			return Loc.t("%s: %s ends.") % [d.player.name, _status(d.status)]
		&"counter_changed":
			var def: Dictionary = Content.counters.get(d.counter, {})
			if def.get("private", false):
				return ""
			return Loc.t("%s's %s: %d.") % [d.player.name, Loc.t(def.get("name", d.counter)), d.value]
		&"game_over":
			return Loc.t("%s holds Carcaj's crown.") % d.winner.name if d.winner != null else Loc.t("Nobody is left standing.")
	return ""


static func _coins(d: Dictionary) -> String:
	var who: String = d.player.name
	match d.reason:
		&"income":
			return Loc.t("%s collects %d.") % [who, d.delta]
		&"doubt":
			return Loc.t("%s pays %d for the wrong call.") % [who, -d.delta]
		&"stolen":
			return Loc.t("%s loses %d coins to %s.") % [who, -d.delta, d.other.name]
		&"steal":
			return ""
		&"swindle":
			return Loc.t("%s makes off with %d coins meant for %s.") % [who, d.delta, d.other.name]
		&"voodoo":
			return Loc.t("%s's doll siphons %d from %s.") % [who, d.delta, d.other.name]
	if d.delta > 0:
		return Loc.t("%s gains %d coins.") % [who, d.delta]
	return Loc.t("%s pays %d coins.") % [who, -d.delta]


static func _item(instance: ItemInstance) -> String:
	return Loc.t("a hidden item") if instance.hidden else instance.def.display_name


## The name of what `play` puts into play, and of what it repeats if it is
## standing in for something else.
static func title(play: Play) -> String:
	var aimed := play.aimed()
	if aimed == play:
		return play.source.display_name
	return "%s → %s" % [play.source.display_name, aimed.source.display_name]


static func _on(play: Play) -> String:
	if play == null or play.aimed().whom() == null:
		return ""
	return Loc.t(" on %s") % play.aimed().whom().name


static func _status(status_id: StringName) -> String:
	return Loc.t(Content.statuses.get(status_id, {}).get("name", String(status_id)))
