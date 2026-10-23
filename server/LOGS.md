# Arquivos das partidas

Toda partida ranqueada que termina vira um arquivo JSON em `LIAR_DATA/logs/<id>.json`. Na VPS, isso fica dentro do volume `house-data`, em `/data/logs/`. Valem os dois modos: as mesas da fila, jogadas num servidor de partida, e as salas ranqueadas, hospedadas por um jogador (rede local, Radmin VPN). Os arquivos não ficam no banco: são para as consultas que você quiser fazer depois, com `jq`, pandas ou o que for.

Quem escreve o arquivo é `scripts/net/match_log.gd`: um observador do motor que roda no servidor de partida e, numa sala ranqueada, na máquina de cada sócio. A casa grava a versão de que todos concordam e põe por cima o que ela fez da partida (`house`).

Para olhar rápido: `python server/api/match_log.py <arquivo> [--turn N | --type <evento>]`, ou `python server/api/match_log.py <pasta> --summary`.

## Convenções

- **Jogador** é sempre o número do assento (`0`, `1`, ...). O nome de cada assento está em `players`, e a conta da casa em `house.seats`.
- **Turno** (`turn`) é o `GameEngine.turn_count`. O `0` é a distribuição das cartas e o `1` é o primeiro turno; ele conta os turnos de todos, não as voltas na mesa. `current` é o assento de quem está jogando o turno.
- **Item na mão de alguém** é `{"item": "<id>", "uid": n, "hidden", "sealed_turn"}`. O `uid` é a mesma cópia do começo ao fim: dá para seguir um Escudo de quem o comprou até quem o roubou.
- **Jogada** (o uso de uma habilidade ou de um item, do anúncio ao fim) é `{"play": id, ...}`, com os campos abaixo. Dentro de outra coisa ela aparece só como `{"play": id}`.
- **Ids**: personagem (`bard`), habilidade (`bard.swindle`), item (`shield`), status (`hexed`), sempre os do código.

## Raiz

| Campo | O que é |
|---|---|
| `match` | id da partida (`m...` mesa da fila, `r...` sala ranqueada) |
| `house` | o que a casa fez dela: `mode` (`house`/`room`), `state` (`done`, ou `void` se foi anulada, com `why`), `build`, `seats` (`seat`, `name`, `account`, `place`, `forfeit`, `before`, `after`, `delta`), `summary` |
| `format` | versão do formato (hoje `1`) |
| `started_at`, `ended_at`, `seconds` | horário Unix do começo e do fim, e a duração |
| `seed`, `config` | a semente do dado e as regras (`GameConfig.to_wire`) |
| `characters`, `item_pool` | os personagens sorteados e os itens que a loja pode ter |
| `players` | `[{seat, name, bot}]` |
| `turns`, `winner`, `places` | turnos jogados, o assento vencedor e as colocações (`seat`, `place`, `forfeit`) |
| `events` | tudo o que o motor disparou, em ordem (abaixo) |
| `decisions` | toda pergunta feita a um jogador e o que ele respondeu (abaixo) |
| `snapshots` | a mesa inteira na distribuição, no início de cada turno e no fim (abaixo) |
| `replay` | `seed` e `answers`: as respostas das pessoas, na ordem da sala (`[ticket, assento, resposta]`). Com as regras, isso joga a partida de novo, idêntica, no motor |

## `events`

```json
{"n": 180, "turn": 9, "current": 1, "t": 1.191, "type": "player_eliminated",
 "data": {"player": 0, "killer": 1, "play": {"play": 13, "source": "clown.bang", "actor": 1, "target": 0, "truthful": false, ...}}}
```

- `n` é a posição do evento e `t`, os segundos desde o começo.
- `type` e `data` seguem a lista documentada no topo de `scripts/core/game_event.gd`.
- Os eventos `before_*` e o `claim_resolving` levam também `cancelled`. Se alguém mudou o evento enquanto ele passava (uma Fraude zerando um ganho, por exemplo), o evento traz também `after`, com os dados como ficaram.

Uma jogada (`data.play`) traz:

| Campo | O que é |
|---|---|
| `source`, `kind`, `character` | a habilidade ou o item, se é `ability` ou `item`, e o personagem alegado |
| `actor`, `target`, `mark` | quem jogou, o alvo e quem é apontado sem ser alvo |
| `truthful` | **se quem alegou tinha mesmo a carta**: `false` é blefe |
| `doubter` | quem gritou LIAR! nela |
| `cost`, `paid` | o preço e o que já tinha sido pago |
| `reacting_to` | o evento a que ela responde, se for uma reação |
| `failed`, `cancelled`, `blocked`, `reflected` | como ela terminou até aquele momento |
| `params` | as escolhas feitas (`repeat` da Impostora, `loaded` do Palhaço...) |

Onde está o que você pediu:

| Pergunta | Eventos |
|---|---|
| Quem comprou ou usou qual item | `item_bought`, `service_bought`, `item_used`, `item_gained`, `item_stolen`, `item_broken`, `item_discarded`, `item_sold` |
| Quem usou qual ação, e se mentia | `claim_declared` (`play.truthful`), `lie_succeeded` (a mentira passou) |
| Quem duvidou | `doubt_declared` (`doubter`, `stake`), `doubt_revealed` (`truthful`: era verdade?), `doubt_succeeded` / `doubt_failed` |
| Quem eliminou quem | `player_eliminated` (`player`, `killer`, `play`), `player_kicked` |
| Moedas, Moral, cartas, status | `coins` (`delta`, `reason`, `other`), `morale_lost` / `morale_gained` / `morale_spent`, `cards_changed` / `cards_swapped` / `card_lost` / `card_drawn` / `cards_recalled` / `card_peeked`, `status_added` / `status_removed` |

## `decisions`

```json
{"n": 3, "after_event": 9, "turn": 1, "seat": 1, "bot": false, "kind": "DOUBT",
 "options": ["morale"], "context": {"play": {"play": 0}, "reactions": []}, "answer": {"doubt": false}}
```

Aqui entram todas as perguntas, as de pessoas e as de bots (`bot`).

- `kind` é o tipo da pergunta: `TURN`, `TARGET`, `DOUBT`, `REACT` ou `PICK`.
- `options` é o que dava para escolher.
- `answer` é o que foi escolhido:
  - `TURN`: a opção do turno (`kind`, `ability`, `item`...);
  - `TARGET`: o assento escolhido;
  - `DOUBT`: `{"doubt": true, "stake": "coins"}` para quem duvidou ou `{"doubt": false}` para quem deixou passar;
  - `PICK`: `{"index", "option"}`.
- `after_event` é o último evento antes da resposta.

É aqui que se vê também quem **deixou passar** uma alegação que podia ter duvidado.

## `snapshots`

```json
{"after_event": 90, "turn": 5, "current": 0, "deck": ["painter", "clown", ...], "shop": ["shield", null, "potion"],
 "fixed_items": ["fresh_card", "death"], "last_action": "painter.monochrome",
 "players": [{"seat": 0, "name": "...", "alive": true, "morale": 1, "coins": 4, "cards": ["doctor"], "left": [],
              "items": [...], "statuses": {...}, "counters": {...}, "hand_limit": 1, "bot": false}]}
```

É a mesa inteira:

- o baralho, na ordem;
- a loja;
- a mão de cada um, inclusive as cartas escondidas;
- as cartas deixadas por quem saiu (`left`);
- os itens, status e contadores (o Cofre do Mitomaníaco, por exemplo).

Há uma foto na distribuição (`turn` 0), uma no início de cada turno (antes da renda) e uma no `game_over`. **Para montar o estado no turno N**, pegue a foto daquele turno e aplique os eventos dele (`events` com aquele `turn`) até o ponto que quiser. Ou rode `match_log.py <arquivo> --turn N`.

## Exemplos

Todos os blefes pegos, com quem pegou:

```bash
jq -c '.events[] | select(.type=="doubt_revealed" and .data.truthful==false) | {turn, liar: .data.play.actor, by: .data.doubter, claim: .data.play.source}' logs/*.json
```

Em Python, a porcentagem de blefe por personagem em todas as partidas:

```python
import json, glob, collections
total, bluffs = collections.Counter(), collections.Counter()
for f in glob.glob("logs/*.json"):
    for e in json.load(open(f))["events"]:
        if e["type"] == "claim_declared" and e["data"]["play"]["kind"] == "ability":
            c = e["data"]["play"]["character"]
            total[c] += 1
            bluffs[c] += not e["data"]["play"]["truthful"]
print({c: round(bluffs[c] / total[c], 2) for c in total})
```

## Salas ranqueadas

Numa sala ranqueada, cada sócio manda à casa o seu próprio relato, junto com um resumo de como a partida acabou (o `digest`). A casa fecha a partida quando todos os que se apresentaram já mandaram, ou `LIAR_ROOM_SETTLE` segundos depois do primeiro relato, e fica com a versão em que a maioria concorda. Se duas versões empatarem, a partida é anulada, e o arquivo é gravado mesmo assim, com `house.state = "void"` e o motivo em `why`. Os relatos de cada máquina ficam em `LIAR_DATA/reports/<id>/` só até a partida fechar.

O servidor de partida também deixa uma cópia do que mandou ao lado do spec, em `LIAR_DATA/matches/<id>.record.json`. Ela serve para o caso de a API não ter recebido o resultado.
