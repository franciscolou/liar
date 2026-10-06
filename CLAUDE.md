# LIAR!

Jogo de cartas de blefe em turnos, inspirado em Coup, feito em **Godot 4.7** (GDScript, renderer `gl_compatibility`). A especificação é o GDD em `Entrega/LIAR! - GDD.pdf` (em português). A interface do jogo é escrita em inglês e traduzida para português (ver "Configurações e idioma"); o usuário conversa em português.

Premissa central: qualquer jogador pode **alegar** a habilidade de qualquer personagem da partida; só quem tem a carta na mão diz a verdade. Toda alegação pode ser **duvidada** ("LIAR!"). Quem mente e é pego perde 1 de Moral; quem duvida de uma verdade paga moedas.

## Estrutura

```
scenes/            menu.tscn (cena principal) → setup.tscn → main.tscn → end.tscn
scripts/core/      regras e fluxo, sem nenhuma dependência de tela
scripts/content/   characters/*.gd e items/*.gd: um arquivo por personagem/item
scripts/ui/        telas e widgets, construídos em código (as cenas são só raiz + script)
scripts/tests/     simulate.gd (partidas de bots headless), check_scripts.gd
assets/            cartas 55x100, itens 61x64 (pixel art, filtro nearest), sons, fonte Jersey 15
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
- **Status** (`add_status`): dicionário por jogador com `expires` (`own_turn_start` / `own_turn_end` / `never`), `turns`, `by`, `blocks` (tags que o jogador não pode usar). O motor conhece só dois status por nome: `untargetable` e `truth_bound`.
- **`Content`**: registro estático; varre `scripts/content/` com `ResourceLoader.list_directory`.

## Adicionar conteúdo

Personagem: criar `scripts/content/characters/<nome>.gd` com `extends CharacterDef`, preencher `id`, `display_name`, `texture_path`, `order` e chamar `_add()` para cada habilidade (classes internas `extends Ability`). Nada mais precisa ser registrado. Modelos:

- ação de turno com alvo: `assassin.gd` (`BloodCount`)
- reação a evento: `judge.gd` (`ContemptOfCourt`), `mercenary.gd`
- efeito de substituição: `vagabond.gd` (cancela `before_morale_loss`, libera `payment_short`)
- efeito permanente + opção extra no turno + status próprio: `voodooist.gd`
- escolha extra antes de anunciar e custo variável: `magician.gd` (`Counterfeit.prepare`)
- contador próprio do jogador: `mythomaniac.gd` (cofre)

Item: `scripts/content/items/<nome>.gd` com `extends ItemDef`; `kind` é `ACTIVE`, `PASSIVE` (`on_held_event`, ex.: `shield.gd`, `money_bag.gd`) ou `REACTION` (`reacts_to`, ex.: `silencer.gd`).

Prefira resolver uma mecânica nova com um evento + hook no arquivo de conteúdo a colocar um caso especial no motor.

## Interface (`scripts/ui/`)

- **`table.gd`** (script de `main.tscn`): cria o motor, é observer (`present(event)` → animações, depois `_sync()`) e responde decisões humanas (`request(decision)` → `await answered`).
- A loja fica recolhida no canto direito, ao lado do baralho: abre ao passar o mouse e fica fixa ao clicar no fundo dela.
- `HeroPanel` (faixa de baixo: mão, inventário, fileira dos personagens que **não** estão na mão; as habilidades das cartas da mão abrem clicando na própria mão), `SeatView` (oponentes), `CardView`, `ItemView`, `StatBar`, `StatusChips`, `ArrowFx`, `TipLayer` (tooltip próprio; use `TipLayer.attach`).
- `UI` (`ui.gd`): paleta, tema, `label()`/`button()`, tweens (`pop`, `shake`, `juice`), textos de tooltip, tela cheia.
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
- Juiz: as moedas saem de quem duvidou; "Under Oath" vale até o fim do próximo turno do alvo.
- Bardo entrega a própria carta do Bardo (ou uma aleatória, se blefou).
- "Silver Tongue" contra um "Swindle" reage em `claim_resolving` e cancela a habilidade inteira (moedas e troca de cartas), mesmo se o alvo não tiver moedas. Contra os demais roubos (e contra um Swindle refletido por Espelho) reage em `before_steal` e protege só as moedas.
- "Descartar esta carta" (Herdeiro, Mitomaníaco) troca a carta por outra do baralho.
- Vagabundo: a dívida só é permitida com uma alegação automática de "On the Cuff", que pode ser duvidada. A multa de uma dúvida errada segue a mesma regra (`GameEngine.can_doubt`): quem não tem as moedas só é consultado se puder alegar "On the Cuff", e a alegação só acontece se a dúvida falhar. Quem não pode duvidar vê um aviso na mesa (`table._no_doubt_notice`).
- Escudo e Espelho: age o que vier primeiro no inventário, um por ataque; efeito refletido não é bloqueado nem refletido de novo.
- A Poção não está no GDD (veio da versão anterior) e foi mantida.
- Mitomaníaco: com ele na partida, **todo jogador** tem um Cofre que cresce sozinho (+3 por mentira que passou ou mentiroso pego), via `on_event`. Só o "Cash Out" é alegação. O Cofre é um contador `private`: só o dono vê (público, ele denunciaria toda mentira bem-sucedida).
- Voduísta: o "Hex" é uma alegação que fica aberta. Enquanto o boneco estiver preso, qualquer outro jogador pode duvidar dele no próprio turno (opção extra; `GameEngine.challenge`). Vale quem tem a Voduísta **no momento da dúvida**. Uma dúvida por boneco por turno; boneco refletido por Espelho não é duvidável. Boneco que sobreviveu a uma dúvida também deixa de ser duvidável (a Voduísta provada foi trocada).
- Loja: uma só para a mesa. Itens com `ItemDef.fixed` (a Morte) estão sempre à venda, fora dos slots (`slot = -1`), sobrevivem a re-rolagens e não podem ser banidos no setup. Re-rolar custa `GameConfig.reroll_cost` (2) e troca todos os slots.

## Como rodar e testar

- Com o editor aberto, use as ferramentas do MCP `godot-mcp-toolkit`: `game_start` (cena `main` = menu, ou um caminho `res://scenes/...`), `runtime_screenshot`, `input_simulate`, `debugger_get_log`.
- `scripts/tests/simulate.gd`: `godot --headless --script res://scripts/tests/simulate.gd -- <partidas> [v]`. Bots jogam partidas inteiras e o script confere invariantes (cartas no jogo, limite de dívida, inventário).
- `scripts/tests/check_scripts.gd`: carrega todos os scripts e cenas para expor erros de parse.

### Armadilhas

- **Não rode o Godot headless com o editor aberto** sem avisar o usuário: o projeto carrega o plugin/autoload do MCP, e um segundo processo derruba o registro do editor (as ferramentas de runtime passam a falhar com "no token path"). O conserto é reativar o plugin ou reiniciar o editor.
- `script_check` do MCP dá falso positivo em scripts que passam ou atribuem `self` a um tipo com `class_name` (`game_engine.gd`, `tip_layer.gd`): ele compila o arquivo como script anônimo. Os erros reais aparecem ao rodar o jogo.
- Arquivos novos em `assets/` só ganham `.import` quando o editor reescaneia (ao ganhar foco). `UI.font()` tem fallback que lê o `.ttf` direto; texturas novas não têm.
- No editor, o jogo roda embutido na aba Game; redimensionar e tela cheia (F11) só valem em janela própria.
- `input_simulate` com tecla Esc não abriu a pausa nos testes; use o clique no botão MENU.
- `execute_code` chamando uma função que troca de cena trava a chamada.

## Convenções

- GDScript tipado, indentação com tabs, nomes e comentários em inglês (como o código existente).
- Comentários `##` de documentação no topo de classes e em funções públicas não óbvias.
- Não commitar nem dar push sem o usuário pedir.
