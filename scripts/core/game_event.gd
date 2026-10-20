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
##   coins {player, delta, reason, other, play} other = counterpart player or null (bank)
##     (reason &"cost": the price of a claim, put down as it is announced;
##     &"refund": that price back to a liar who was caught; both carry the
##     claim in `play`. &"doubt_reward": the coins for calling LIAR! on a lie.
##     &"stolen"/&"steal": the two halves of a theft, &"hexed"/&"voodoo" when
##     a Voodoo doll does it; &"duck": ducking a Clown's gun, to the bank;
##     &"blank": the price of an empty Bang! back to the Clown, with the claim
##     the coins were put down for in `play`; &"sold": an item turned into
##     coins; &"paint_toll"/&"paint": what a painted player pays for reaching
##     outside the paint, and what the Painter gets for it, see painter.gd)
##   payment_short {player, amount, allowed, play}  set allowed to let the player go into debt; play = the claim being paid for, if any
##   before_steal {thief, victim, amount, play} cancellable (also fired by a Swindle,
##     for coins still on their way to the victim: see bard.gd)
##   item_buying {player, item, slot}           before the item is shown in the inventory
##   item_bought {player, item, slot}           slot = -1 for an item that is always on sale
##   service_bought {player, item, play}        a service (ItemDef.service) was paid for; it resolves next. `item` is a stand-in, never held
##   shop_restocked {slot} / shop_rerolled {player}
##   item_sold {player, item, index, amount}    turned into `amount` coins by its holder
##     (All Is Color, painter.gd); the coins follow, with reason &"sold"
##   item_used {player, item, play} / item_gained {player, item} / item_broken {player, item, index}
##   item_discarded {player, item, index}       thrown away by its holder, for nothing
##     (see GameEngine.discard_item)
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
##   morale_spent {player, amount, play}        Morale paid as the price of `play`
##     (see GameEngine.spend_morale): not a blow, so nothing gets to stop it
##   damage_dealt {source, target, play}
##   player_eliminated {player, killer, play}
##   player_kicked {player}                     taken out of the match by the host
##     of the room after leaving it (GameEngine.kick): cards back into the deck.
##     Only shown and observed: no hooks, no reaction window
##   cards_changed {player, index, reason, old} / cards_swapped {a, a_index, b, b_index}
##     (old: the card that left, known to the table only when reason is
##     &"proven": it survived a doubt and was traded for a new one)
##   cards_recalled {player, card, hands}       `player` named `card` and every copy
##     of it went back to the deck for a new one; hands: [{player, index}], public
##   card_peeked {viewer, owner, index, card}   private to the viewer
##   before_hand_reach {owner, by, how}         cancellable: `by` is about to see,
##     take or replace cards of `owner` (how: &"peek", &"swap", &"recall";
##     see GameEngine.reach_hand). A recall asks every hand, copy or not (the
##     caller's own too, where `owner` is `by`), and adds `card`, the character named
##   hand_missed {owner, by, how[, card]}       it was cancelled: the hand stays as it is
##   before_item_reach {owner, by, how}         cancellable: `by` is about to take or
##     destroy an item of `owner` (how: &"steal", &"break"; see GameEngine.reach_items)
##   items_missed {owner, by, how}              it was cancelled: the items stay as they are
##   card_lost {player, index, card}            the hand follows Morale; public
##   card_drawn {player, index}
##   hand_redrawn {player, count}               the whole hand went back for new cards
##   gun_fired {play, shooter, target, loaded, ducked}  a Clown's gun is shown (clown.gd):
##     loaded or empty, and whether the target paid to duck it
##   coin_flipped {player, heads, won}          a coin tossed for everyone to see;
##     won: it fell on the side the player was hoping for
##   note {player, text, good, tag}             news from content that no other event
##     carries: `text` is an English key with one %s for the player's name
##     (tag &"side_bet": a Side Bet settled; &"doll_awake": a Voodoo doll woke up;
##     &"paint_toll": a painted player reached outside the paint)
##   status_added {player, status} / status_removed {player, status, reason, was}
##     (reason: &"" when it just ended, &"wasted" when it was thrown away;
##     was: what the status held, now that the player has it no more)
##   counter_changed {player, counter, value, delta}  a private counter is its owner's secret

var type: StringName
var data: Dictionary
var cancelled := false


func _init(event_type: StringName = &"", event_data: Dictionary = {}) -> void:
	type = event_type
	data = event_data
