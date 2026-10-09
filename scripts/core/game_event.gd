class_name GameEvent
extends RefCounted
## Something that happened (or is about to happen) in the game.
##
## Every event goes through GameEngine.fire, which shows it to the view, lets
## characters and held items hook into it, and then opens a reaction window
## where players may claim an ability or use a reaction item. `before_*`
## events are mutable: listeners may change `data` or set `cancelled`.
##
## Event types and their data:
##   game_started, game_over {winner}
##   turn_started / turn_ended {player}
##   income {player, amount}                    mutable amount
##   before_gain {player, amount, reason}       mutable amount (0: the coins
##     went somewhere else, see bard.gd)
##   coins {player, delta, reason, other}       other = counterpart player or null (bank)
##   payment_short {player, amount, allowed}    set allowed to let the player go into debt
##   before_steal {thief, victim, amount, play} cancellable (also fired by a Swindle,
##     for coins still on their way to the victim: see bard.gd)
##   item_buying {player, item, slot}           before the item is shown in the inventory
##   item_bought {player, item, slot}           slot = -1 for an item that is always on sale
##   shop_restocked {slot} / shop_rerolled {player}
##   item_used {player, item, play} / item_gained {player, item} / item_broken {player, item, index}
##   item_stolen {thief, victim, item, index}   a held item changes inventory as it is
##     (index: where it was in the victim's inventory)
##   item_missed {thief, victim}                the victim had no item to take
##   claim_declared {play} / claim_resolving {play} (cancellable)
##   claim_cancelled {play} / claim_resolved {play}
##   doubt_declared {play, doubter, stake} / doubt_revealed {play, doubter, truthful}
##   doubt_failed {play, doubter, defender} / doubt_succeeded {play, doubter, liar}
##   lie_succeeded {play, player}               private to the liar
##   targeted {play, target, blocked, reflected}
##   play_effect {play}                         the play goes through: nothing stopped
##     it and its resolve() comes next. For the screen; nothing reacts to it.
##   before_morale_loss {target, source, amount, cause, play}  cancellable
##   morale_lost {target, source, amount, cause, play} / morale_gained {player, amount}
##     (source is null when the Morale was staked on a wrong LIAR! call)
##   damage_dealt {source, target, play}
##   player_eliminated {player, killer, play}
##   cards_changed {player, index, reason, old} / cards_swapped {a, a_index, b, b_index}
##     (old: the card that left, known to the table only when reason is
##     &"proven": it survived a doubt and was traded for a new one)
##   cards_recalled {player, index, card, hands}  every copy of `card` went back to
##     the deck for a new one, starting with the one `player` showed (at `index`
##     of their hand); hands: [{player, index}], public
##   card_peeked {viewer, owner, index, card}   private to the viewer
##   card_lost {player, index, card}            the hand follows Morale; public
##   card_drawn {player, index}
##   hand_redrawn {player, count}               the whole hand went back for new cards
##   coin_flipped {player, heads, won}          a coin tossed for everyone to see;
##     won: it fell on the side the player was hoping for
##   note {player, text, good}                  news from content that no other event
##     carries: `text` is an English key with one %s for the player's name
##   status_added / status_removed {player, status}
##   counter_changed {player, counter, value, delta}  a private counter is its owner's secret

var type: StringName
var data: Dictionary
var cancelled := false


func _init(event_type: StringName = &"", event_data: Dictionary = {}) -> void:
	type = event_type
	data = event_data
