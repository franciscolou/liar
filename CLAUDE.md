# LIAR!

Jogo de cartas de blefe em turnos, inspirado em Coup, feito em **Godot 4.7** (GDScript, renderer `gl_compatibility`). A especificação é o GDD em `Entrega/LIAR! - GDD.pdf` (em português). A interface do jogo é escrita em inglês e traduzida para português (ver "Configurações e idioma"); o usuário conversa em português.

Premissa central: qualquer jogador pode **alegar** a habilidade de qualquer personagem da partida; só quem tem a carta na mão diz a verdade. Toda alegação pode ser **duvidada** ("LIAR!"). Quem mente e é pego perde 1 de Moral; quem duvida de uma verdade paga moedas.

## Estrutura

```
scenes/            menu.tscn (cena principal) → setup.tscn → main.tscn → end.tscn
scripts/core/      regras e fluxo, sem nenhuma dependência de tela
scripts/content/   characters/*.gd e items/*.gd: um arquivo por personagem/item
scripts/ui/        telas e widgets, construídos em código (as cenas são só raiz + script)
scripts/tests/     simulation.gd (partidas de bots), simulate.gd (headless), simulate_scene.tscn (pelo editor), rules.gd + rules_scene.tscn (cenas de regra roteirizadas), check_scripts.gd
assets/            cartas 55x100, itens 61x64 (pixel art, filtro nearest), sons, fonte Jersey 15
tools/             gen_sfx.py, gen_card_frame.py, gen_placeholder_cards.py, gen_proto_cards.py, remaster_cards.py
```

Não há autoloads do jogo. A configuração passa entre cenas por `GameConfig.current` (static var) e o vencedor por `GameConfig.last_winner`.

## Núcleo (`scripts/core/`)

- **`GameEngine`**: a partida inteira é uma coroutine (`run()`). Não conhece a tela.
- **`fire(type, data)`** é o ponto único de extensão. Para cada evento, nesta ordem:
  1. `observers` (a mesa) animam o evento — o motor espera a animação terminar;
  2. cada `CharacterDef.on_event` da partida e cada `ItemDef.on_held_event` de item em inventário;
  3. abre-se uma **janela de reação**: cada jogador pode alegar uma habilidade cujo `reacts_to()` aceite o evento, ou usar um item de reação.
- Uma alegação feita numa janela de reação é uma alegação normal (pode ser duvidada, custa moedas, dispara eventos), recursivamente até `MAX_REACTION_DEPTH`.
- Eventos `before_*` são mutáveis: listeners alteram `event.data` ou marcam `event.cancelled`.
- A lista de eventos e seus campos está documentada no topo de `game_event.gd`. **Atualize-a ao criar um evento.**
- **`claim()`**: alvo → `prepare()` → `claim_declared` → janela de dúvida → pagar custo → `claim_resolving` (cancelável) → `_resolve()` → `claim_resolved` → `lie_succeeded` se mentiu e passou.
- **`Decision` / `Controller`**: o motor pede escolhas (`TURN`, `TARGET`, `DOUBT`, `REACT`, `PICK`) sem saber quem responde. `BotController` decide sozinho; `HumanController` repassa para `table.request()`.
- **`Playable`** é a base de `Ability` e `ItemDef` (alvo, tags, `can_use`, `resolve`, `reacts_to`, dicas `ai_*` para os bots). **`Play`** é o contexto de um uso, do anúncio à resolução.
- **Status** (`add_status`): dicionário por jogador com `expires` (`own_turn_start` / `own_turn_end` / `never`), `turns`, `by` (quem aplicou; sempre passe, o "Antidote" do Doutor depende disso), `blocks` (tags que o jogador não pode usar). O motor conhece só dois status por nome: `untargetable` e `truth_bound`. A tag `&"doubt"` em `blocks` tira do jogador o direito de gritar LIAR! (`doubt_stakes` volta vazio); quem não pode duvidar nem reagir nem é perguntado na janela de dúvida.
- Ajudas para conteúdo: `carry_out(play)` (resolve uma jogada que não foi anunciada, passando por escudo/espelho e `play_effect`), `note(player, texto)` (linha de log + texto flutuante para algo que nenhum outro evento conta), `flip_coin`, `redraw_hand`, `trade_with_deck`, `take_item`. `Play.stand_in` marca uma alegação provada sem a carta (não há carta para renovar). `guards(instance, holder, event)` é para itens passivos de defesa (`ItemDef.guard`: Escudo, Espelho): diz se aquele item é o que age naquele `targeted` (só um age; quem tem mais de um tipo escolhe por uma decisão `PICK`, e os bots pesam por `ItemDef.ai_guard_weight`). `Playable.inflicts` marca o que põe um status no alvo; `Ability.foresees(play, player, engine)` deixa uma reação ser oferecida já na janela de dúvida (ver "Reação adiantada").
- Decisão `PICK`: `context.weights` orienta os bots; `context.foreign` avisa a mesa que as cartas oferecidas não são da mão do jogador.
- **`Content`**: registro estático; varre `scripts/content/` com `ResourceLoader.list_directory`.

## Adicionar conteúdo

Personagem: criar `scripts/content/characters/<nome>.gd` com `extends CharacterDef`, preencher `id`, `display_name`, `texture_path`, `order` e chamar `_add()` para cada habilidade (classes internas `extends Ability`). Nada mais precisa ser registrado. Modelos:

- ação de turno com alvo: `assassin.gd` (`BloodCount`)
- reação a evento: `judge.gd` (`ContemptOfCourt`), `mercenary.gd`
- efeito de substituição: `vagabond.gd` (cancela `before_morale_loss`, libera `payment_short`)
- efeito permanente + opção extra no turno + status próprio: `voodooist.gd`
- escolha extra antes de anunciar e custo variável: `magician.gd` (`Counterfeit.prepare`)
- contador próprio do jogador: `mythomaniac.gd` (cofre)
- reação que muda o resultado de uma dúvida: `impostor.gd` (`PerfectDisguise`)
- aposta guardada na jogada (`Play.params`) e paga em outro evento: `gambler.gd` (`SideBet` + `on_event`)
- escolha entre cartas que não são da mão: `gravedigger.gd` (`Exhume`)
- status que bloqueia a dúvida e expira pelo turno de quem aplicou: `bartender.gd`
- efeito em área e roubo de item: `sheriff.gd`
- reação a um status recebido: `doctor.gd` (`Antidote`)
- efeito atrasado que resolve como jogada própria (`carry_out`) + opção de turno com `priority`: `bomber.gd`

Personagem sem arte: `tools/gen_placeholder_cards.py` desenha um provisório 55x100 (uma função por carta). Os sete personagens novos (Impostor, Gambler, Gravedigger, Bartender, Sheriff, Doctor, Bomber) usam esses provisórios.

Item: `scripts/content/items/<nome>.gd` com `extends ItemDef`; `kind` é `ACTIVE`, `PASSIVE` (`on_held_event`, ex.: `shield.gd`, `money_bag.gd`) ou `REACTION` (`reacts_to`, ex.: `silencer.gd`).

Prefira resolver uma mecânica nova com um evento + hook no arquivo de conteúdo a colocar um caso especial no motor.

## Interface (`scripts/ui/`)

- **`table.gd`** (script de `main.tscn`): cria o motor, é observer (`present(event)` → animações, depois `_sync()`) e responde decisões humanas (`request(decision)` → `await answered`).
- A loja fica recolhida no canto direito, ao lado do baralho: abre ao passar o mouse e fica fixa ao clicar no fundo dela.
- `HeroPanel` (faixa de baixo: mão, inventário, fileira dos personagens que **não** estão na mão; as habilidades das cartas da mão abrem clicando na própria mão; com mais de onze personagens a fileira se sobrepõe em leque e perde as legendas), `SeatView` (oponentes), `CardView`, `ItemView`, `StatBar`, `StatusChips`, `ArrowFx`, `TipLayer` (tooltip próprio; use `TipLayer.attach`).
- `UI` (`ui.gd`): paleta, tema, `label()`/`button()`, tweens (`pop`, `shake`, `juice`), textos de tooltip, tela cheia.
- A face das cartas é a arte crua + `assets/ui/card_frame.png`, compostos em `UI.card_face` (que também arredonda os cantos como o verso). A arte em `assets/cards/` continua sem moldura.
- Conjunto alternativo de arte: `UI.CARD_ART_DIR` aponta para uma pasta onde a arte de cada carta é procurada pelo nome do arquivo (carta que falta lá usa a própria; `""` volta à arte de `assets/cards/`, que o `texture_path` dos personagens continua nomeando). Hoje aponta para `assets/cards_proto2/`. `tools/gen_proto_cards.py` gera um conjunto por pasta de pinturas grandes (`SETS`: `assets/prototype/` → `assets/cards_proto/`, `assets/prototype2/` → `assets/cards_proto2/`), recortadas em 55:100 e reduzidas a 220x400 (`anchor` diz de que lado fica o recorte de cada carta, `RENAME` corrige nomes de arquivo). Arte maior que a carta precisa ser um múltiplo inteiro de 55x100: a moldura e os cantos crescem junto, a textura ganha mipmaps e o `CardView` a desenha com filtro linear (`UI.card_filter`).
- Sons: `table._play_sfx(nome, fallback)` procura `assets/sounds/<nome>.wav` e depois `.mp3`. Usar ou quebrar um item toca `item_<id>` se o arquivo existir (senão `item_use` / `breaking`). `damage` é só para perda de Moral. Os `.wav` são sintetizados por `tools/gen_sfx.py` (a moldura, por `tools/gen_card_frame.py`).
- Roleta Russa: `table._anim_roulette` (tambor `CylinderFx`, mira saltando entre os candidatos, tiro). O alvo sorteado fica fora do palco e do log até o tambor parar (entrada de palco `concealed`). Sons `item_roulette` (fundo), `_tick`, `_cock`, `_shot`.
- Efeito de cada habilidade/item: `PlayFx` (`scripts/ui/play_fx.gd`), disparado pelo evento `play_effect` (o motor o emite em `_resolve`, depois de escudo/espelho e antes de `resolve()`). Um método por id, com o ponto virando sublinhado (`_fx_bard_swindle`, `_fx_potion`); o som é tocado dentro do método (`fx_<nome>` ou `item_<id>`). A duração acompanha a tensão da ação: itens simples são um piscar. Escudo e Espelho passam por `PlayFx.item_broken`. `assets/cards_v2/` é só uma proposta de arte (`tools/remaster_cards.py`), não usada pelo jogo.
- Carta em trânsito (troca com o baralho, compra, troca entre jogadores) some do lugar na mão enquanto voa: `table._card_view` + `_set_cards_shown`.
- O menu de um personagem (`table._open_popup`) mostra a descrição de cada habilidade embaixo do botão (`note`), sem depender do tooltip.
- Esc fecha primeiro o que estiver aberto (menu de personagem, escolha de alvo) e só depois abre a pausa; o botão direito também cancela a escolha de alvo (`table._back_out`).
- `HelpPanel` (`scripts/ui/help_panel.gd`, sem `class_name`: use `preload`): o "como jogar" em cinco páginas, aberto pelo menu e pela pausa. Cada página é uma chave de tradução inteira.
- A tela de setup mostra os personagens em uma fileira até 10 e em duas fileiras menores acima disso.
- `StatusFx` (`scripts/ui/status_fx.gd`, sem `class_name`: use `preload`): o visual dos status na caixa do jogador, filho de `SeatView` e de `HeroPanel` e atualizado no `sync()` deles. Grogue: estrelas, brilhos e bolhas num anel deitado, visto um pouco de cima, que passa pela frente da caixa e some por trás dela (a metade de trás é desenhada por `StatusFx.back`, um nó que o dono põe na árvore **antes** do painel da caixa; lá as estrelas ficam menores e mais apagadas). Enfeitiçado: um boneco de pano sentado numa beirada (`doll_foot` é o ponto onde ele senta; precisa de espaço embaixo), parecido com o da arte da Voduísta: cabeça de saco com olhos em X e boca costurada, coração bordado, alfinetes de cabeça vermelha. Uma perna fica esticada ao longo da beirada e a outra pendurada, balançando; um braço cai solto e a cabeça pende. É brinquedo: nada nele se mexe sozinho, só balança, e de tempos em tempos leva um puxão (`jolt`). Cada parte é um bitmap girado em torno da sua junta (`_doll_part`). Tique-taque: três bananas de dinamite com o pavio aceso (no turno em que vai explodir, o pavio encurta e a dinamite treme). Tudo é desenhado em código (bitmaps de texto + `draw_rect`), sem assets. Os chips de status continuam lá, com o tooltip que explica a regra. Para dar visual a outro status: acrescente o id em `LOOKS` e desenhe a partir de `_draw()`. Nos assentos o boneco senta na quina inferior direita da caixa (perna esticada sobre a borda de baixo, a outra para fora) e a dinamite fica por fora do canto esquerdo; no painel do jogador ele senta na linha de cima da faixa, onde o bloco da esquerda acaba.
- Adereços do `PlayFx` desenhados em código, como classes internas no fim de `play_fx.gd`: `BadgeFx` (o distintivo da "Shakedown", uma estrela em pixels de 4 px recortada de uma grade, três tons e contorno: entra girando, `shine` passa um reflexo em "+", depois vem a onda) e `RopeFx` (o laço do "Confiscate": uma corrente de pontos com peso e sem rigidez, presa na mão e no laço, que faz barriga, atrasa e estala; `slack` diz o quanto ela sobra, `fling` é o arremesso, `whirl` o giro, `twang` o tranco ao esticar). Os dois são desenhados em blocos, como o resto dos efeitos: nada de polígonos lisos.
- `item_stolen` é animado como um laço (`PlayFx.item_roped`, chamado por `table._anim_item_stolen`): lançado do ladrão até o lugar do item (`table._item_spot`, pelo `index` do evento), fechado em volta dele e puxado até o espaço do inventário do ladrão. O `_fx_sheriff_confiscate` só gira o laço por cima do Xerife; ele fica girando até `item_roped` assumir, ou é solto em `claim_resolved` (`PlayFx.put_away`) se a jogada acabar sem item. Se o alvo não tem item nenhum (só acontece com um Confisco devolvido por Espelho a um Xerife de mãos vazias), o `Confiscate` dispara `item_missed` e o laço é arremessado mesmo assim (`PlayFx.rope_missed`): fecha no ar, cai (`RopeFx.ground` é o chão em que a corda fica deitada) e é arrastado de volta vazio.
- "Hat Trick": o `_fx_magician_hat_trick` só põe a cartola na mesa (`HatFx`, boca para cima, acesa por dentro); o item só existe depois de `resolve`, então é o `item_gained` que o imprime (`table._anim_item_gained` → `PlayFx.item_conjured`, enquanto `PlayFx.conjuring(jogador)` for verdade): a arte aparece linha por linha de baixo para cima (`HatFx.printed`), com o contorno do que falta em listras, a linha de impressão com a cabeça correndo, um anel de luzes que sobe junto e faíscas; depois o item vai para o seu espaço no inventário. Cartola de que não saiu nada é guardada em `claim_resolved` (`PlayFx.put_away`).
- A moeda de `coin_flipped` é animada por `PlayFx.coin_flip` (não é um `_fx_<id>`: o resultado só existe depois de `resolve`).
- Layout pensado em **1152x648**, com stretch `canvas_items` e aspecto `keep`. Posições são fixas nessa resolução.
- `viewer` é o jogador cuja mão está na tela. Com um humano, é ele; com vários (hot-seat), a mesa mostra uma cortina "pass the device" antes de cada decisão; sem humanos, modo espectador com os assentos em círculo completo.
- Ao sair da mesa, `_exit_tree` chama `engine.abort()`; qualquer novo `await` no motor precisa tolerar `aborted`.

## Configurações e idioma

- **`Settings`** (`scripts/ui/settings.gd`, estático): volume de música e de efeitos e idioma, salvos em `user://settings.cfg`. Toda tela chama `Settings.ensure_loaded()` no início do `_ready`. Os buses `Music` e `SFX` são criados em código; todo `AudioStreamPlayer` novo deve usar `Settings.MUSIC_BUS` ou `Settings.SFX_BUS`.
- **`SettingsPanel`**: overlay único, aberto pelo botão SETTINGS do menu e pelo menu de pausa da mesa.
- **`Loc`** (`scripts/core/loc.gd`): o texto em inglês no código é a chave de tradução; `scripts/locale/pt_br.gd` tem o dicionário inglês → português. Texto que falta no dicionário aparece em inglês.
  - Texto fixo posto direto num `Label`/`Button` (ou passado a `TipLayer.attach`) é traduzido sozinho: deixe a chave em inglês, sem `Loc.t()`, para que a troca de idioma funcione nos dois sentidos.
  - Texto formatado ou que entra em BBCode: `Loc.t("%s buys %s.") % [...]`. A ordem dos `%s` não pode mudar na tradução.
  - `display_name`, `description`, `title` e `trigger_text` do conteúdo já voltam traduzidos (getter). Nomes e descrições de `status_defs`/`counter_defs` não: passe por `Loc.t()` ao exibir.
  - Descrição montada com constante (`"Gain %d coins." % REWARD`) é procurada já formatada: a chave no dicionário leva o número.
  - "LIAR!" fica em inglês de propósito. Texto que cita uma habilidade pelo nome precisa acompanhar o nome dado a ela na seção "abilities" do dicionário.
- Os botões pintados na arte (menu e tela final) estão em inglês; em outro idioma `UI.art_button` cobre a pintura com uma placa com o texto traduzido.
- Ao trocar de idioma no meio da partida, a mesa redesenha o que consegue (`table._retranslate`); o log já escrito e a decisão já aberta continuam no idioma anterior.

## Decisões de regra (onde o GDD é ambíguo)

- Moral são 3 pontos de vida. A mão tem `min(hand_size, Moral)` cartas (`GameEngine.hand_limit`): perder a 1ª Moral não muda a mão; ao cair para 1, o jogador escolhe uma carta para devolver ao baralho, revelada a todos; ao recuperar Moral, compra uma.
- Uma ação de personagem encerra o turno; comprar e usar itens é livre antes dela. Renda: +1 por turno.
- Dúvida contra uma verdade: a carta provada volta ao baralho e o jogador compra outra (`GameEngine.renew_proven_card`), **depois** de a habilidade resolver, para que "esta carta" (Bardo, Herdeiro, Mitomaníaco) ainda seja ela. Se a própria habilidade já tirou a carta da mão, não há segunda troca.
- Juiz: "Contempt of Court" rende sempre 5 moedas: saem de quem duvidou e o que faltar vem do banco (inclusive se quem duvidou foi eliminado ou protegeu as moedas com "Silver Tongue"); "Under Oath" vale até o fim do próximo turno do alvo.
- Bardo entrega a própria carta do Bardo (ou uma aleatória, se blefou).
- "Silver Tongue" contra um "Swindle" reage em `claim_resolving` e cancela a habilidade inteira (moedas e troca de cartas), mesmo se o alvo não tiver moedas. Contra os demais roubos (e contra um Swindle refletido por Espelho) reage em `before_steal` e protege só as moedas.
- "Descartar esta carta" (Herdeiro, Mitomaníaco) troca a carta por outra do baralho. Quem blefou escolhe qual carta da mão vai embora (`GameEngine.pick_own_card`), na hora em que a habilidade resolve.
- Vagabundo: a dívida só é permitida com uma alegação automática de "On the Cuff", que pode ser duvidada. A multa de uma dúvida errada segue a mesma regra: a alegação só acontece se a dúvida falhar. Quem é pego mentindo sobre o Vagabundo (qualquer habilidade dele) não pode alegar "Street Bargain" contra a Moral perdida por essa mentira.
- Janela de dúvida (`GameEngine._doubt_window`): só uma pessoa duvida de cada alegação. Todos são consultados ao mesmo tempo e o primeiro LIAR! encerra a consulta; os bots só são ouvidos depois que todos os humanos deixaram passar (entre os bots que querem duvidar, um é sorteado). Com vários humanos na mesma tela a decisão vem com `context.shared` e a mesa mostra um prompt único, sem cortina e sem informação de mão (`table._prompt_shared_doubt`); as decisões que sobram são encerradas por `Controller.withdraw`.
- Reação adiantada: a decisão `DOUBT` de um humano traz em `context.reactions` (`GameEngine.early_options`) o que ele já pode responder àquela alegação: as reações à janela de `claim_resolving` dela ("Silver Tongue" contra um Swindle, o Silenciador) e as reações que enxergam o próprio gatilho chegando (`Ability.foresees`: o "Antidote" contra uma habilidade com `inflicts` mirada nele). Responder com uma dessas opções é deixar passar e já reagir: a resposta fica em `play.params.early_reactions` (`{answer, offered}` por jogador) e vale para o `claim_resolving` e para tudo o que acontecer enquanto a alegação resolve (pilha `_resolving`); a reação é alegada na hora do gatilho dela, sem perguntar de novo. Quem deixou passar tendo a opção também não é perguntado de novo sobre o que já viu, a não ser que alguém duvide e a alegação se prove verdadeira (inclusive ele mesmo: duvidar e errar não tira a reação). Os bots continuam reagindo só na janela de reação.
- Aposta da dúvida (`GameEngine.doubt_stakes`, resposta da decisão `DOUBT`): quem tem as moedas da multa aposta moedas (`coins`). Quem não tem escolhe entre se endividar (`debt`, só se puder alegar "On the Cuff" sem passar do limite) e apostar 1 de Moral (`morale`); todo jogador vivo pode, portanto, duvidar. A Moral perdida assim tem `cause = &"doubt"` e `source = null` (ninguém leva crédito por dano ou eliminação), mas passa por `before_morale_loss` como qualquer outra. O botão de dívida de quem não tem o Vagabundo usa o estilo apagado (`table._make_shady`).
- Escudo e Espelho: um só age por jogada mirada no dono. Quem tem os dois escolhe qual usar (não há a opção de não se defender); dois do mesmo tipo não perguntam nada. O reflexo do Espelho é uma jogada mirada em quem usou como qualquer outra: o Escudo dele a bloqueia, o Espelho dele a devolve de novo, e assim por diante até acabar a defesa de alguém (`GameEngine._resolve` repete o `targeted`). `Play.reflected` diz se a jogada está no sentido contrário ao anunciado (número ímpar de espelhos).
- A Poção não está no GDD (veio da versão anterior) e foi mantida.
- Mitomaníaco: com ele na partida, **todo jogador** tem um Cofre que cresce sozinho (+3 por mentira que passou ou mentiroso pego), via `on_event`. Só o "Cash Out" é alegação, e só como ação de turno (não reage à perda de Moral). O Cofre é um contador `private`: só o dono vê (público, ele denunciaria toda mentira bem-sucedida).
- Voduísta: o "Hex" é uma alegação como as outras: só pode ser duvidado na hora em que o boneco é preso, nunca depois.
- Impostora: "Perfect Disguise" reage a `doubt_declared` contra uma mentira própria e a transforma em verdade (`truthful` + `stand_in`): quem duvidou paga a multa e a habilidade original resolve. A própria alegação do disfarce pode ser duvidada; se for mentira, o jogador perde Moral pelo disfarce **e** pela mentira original. Só é oferecida quando a alegação duvidada era mentira.
- Apostadora: a "Side Bet" escolhe o lado em segredo (`prepare`) e é paga no `doubt_revealed`, pelo resultado oficial (um disfarce da Impostora conta como verdade). Quem duvidou e quem foi duvidado não podem apostar.
- Coveiro: "Exhume" olha as 3 cartas do topo; trocar é opcional e o baralho é embaralhado depois. "Last Rites" leva as moedas de quem foi eliminado sem passar por `before_steal`; o primeiro na ordem dos assentos que alegar fica com tudo.
- Bartender: "Mickey Finn" dura até o fim do **próximo turno de quem serviu** (não do alvo). Quem está grogue ainda pode reagir e apostar; só não pode duvidar.
- Xerife: "Shakedown" não tem alvo (Escudo e Espelho não agem), mas pula quem está invisível; cada roubo passa por `before_steal`. "Confiscate" é com alvo; o item escondido continua escondido no novo dono.
- Doutor: "Patch Up" só pode ser alegado com 1 de Moral (cura à vontade deixava uma mesa rica parada na Moral cheia para sempre). O "Antidote" só reage a status com `by` de outro jogador. Ele não precisa deixar a habilidade passar para depois se livrar dela: o botão do "Antidote" já aparece ao lado do LIAR! (reação adiantada), e quem duvida e erra paga a dúvida e ainda é perguntado sobre o "Antidote" quando o status cai.
- `GameEngine.pay`: a dívida liberada por `payment_short` é conferida de novo antes da cobrança; moedas gastas durante a própria alegação de "On the Cuff" (uma reação paga) podem tê-la esgotado, e aí o pagamento falha.
- Dinamitador: a bomba explode no fim do próximo turno do portador (se foi plantada no turno dele mesmo, por Espelho, espera o seguinte). Desarmar custa 4. A explosão é uma jogada do dono da bomba: Escudo bloqueia, Espelho devolve, e um dono enfeitiçado ou eliminado não causa dano.
- Loja: uma só para a mesa. Itens com `ItemDef.fixed` (a Morte) estão sempre à venda, fora dos slots (`slot = -1`), sobrevivem a re-rolagens e não podem ser banidos no setup. Re-rolar custa `GameConfig.reroll_cost` (2) e troca todos os slots.

## Como rodar e testar

- Com o editor aberto, use as ferramentas do MCP `godot-mcp-toolkit`: `game_start` (cena `main` = menu, ou um caminho `res://scenes/...`), `runtime_screenshot`, `input_simulate`, `debugger_get_log`.
- `scripts/tests/simulate.gd`: `godot --headless --script res://scripts/tests/simulate.gd -- <partidas> [v]`. Bots jogam partidas inteiras e o script confere invariantes (cartas no jogo, limite de dívida, inventário).
- Com o editor aberto, rode `game_start` com `res://scripts/tests/simulate_scene.tscn`: as mesmas partidas de bots, dentro do processo do editor, com o resultado em `debugger_get_log` (inclui a duração média das partidas por personagem). Uma partida que não termina em 600 turnos conta como falha. As invariantes são conferidas a cada início de turno. Cada partida é determinada pelo seu número: `simulate.gd -- 1 v 172` repete só a partida 172 e imprime o log dela.
- `res://scripts/tests/rules_scene.tscn` (também por `game_start`): cenas roteirizadas de `rules.gd`, em que cada jogador é um fantoche que responde o que a cena manda, para regras que as partidas de bots só encontram por sorte (espelho contra espelho, escolha da defesa, "Antidote" depois de uma dúvida errada). Sai `ok`/`FAILED` por cena e `RULES DONE: n failed`. Regra nova no motor: acrescente uma cena.
- `scripts/tests/check_scripts.gd`: carrega todos os scripts e cenas para expor erros de parse.

### Armadilhas

- **Não rode o Godot headless com o editor aberto** sem avisar o usuário: o projeto carrega o plugin/autoload do MCP, e um segundo processo derruba o registro do editor (as ferramentas de runtime passam a falhar com "no token path"). O conserto é reativar o plugin ou reiniciar o editor.
- `script_check` do MCP dá falso positivo em scripts que passam ou atribuem `self` a um tipo com `class_name` (`game_engine.gd`, `tip_layer.gd`): ele compila o arquivo como script anônimo. Os erros reais aparecem ao rodar o jogo.
- Arquivos novos em `assets/` só ganham `.import` quando o editor reescaneia (ao ganhar foco). `UI.font()`, `UI.tex()` e os `.wav` têm fallback que lê o arquivo direto; isso só vale rodando pelo editor, não num build exportado.
- Um script novo com `class_name` só é conhecido pelo jogo depois que o editor reescaneia. Para algo criado e usado na mesma sessão, deixe sem `class_name` e use `preload` (como `help_panel.gd` e `simulation.gd`).
- No editor, o jogo roda embutido na aba Game; redimensionar e tela cheia (F11) só valem em janela própria.
- `input_simulate` com tecla Esc não abriu a pausa nos testes; use o clique no botão MENU.
- `execute_code` chamando uma função que troca de cena trava a chamada.

## Convenções

- GDScript tipado, indentação com tabs, nomes e comentários em inglês (como o código existente).
- Comentários `##` de documentação no topo de classes e em funções públicas não óbvias.
- Não commitar nem dar push sem o usuário pedir.
