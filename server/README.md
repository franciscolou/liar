# A casa: servidor das partidas ranqueadas

Tudo o que a seção **Ranqueada** do jogo usa fica numa VPS só:

- **API** (`api/`, Python + FastAPI + SQLite): contas dos sócios, fila de matchmaking, ranking Elo multijogador e os dados de cada partida que viram as estatísticas (a "Gazeta" e o "dossiê" do jogo).
- **Servidores de partida**: o próprio jogo, exportado com o preset **Linux Server** e rodando headless. A API sobe um processo por mesa (`scripts/net/match_server.gd`), numa porta UDP da faixa. Esse processo é o host da sala lockstep, sem assento, roda o motor como autoridade, grava o que aconteceu (`scripts/net/match_record.gd`) e reporta o resultado para a API.
- **Salas ranqueadas**: uma sala comum do jogo (um jogador hospeda, os outros entram pelo endereço, numa rede local ou na Radmin VPN) com o interruptor RANQUEADA do lobby ligado. Ninguém roda no servidor: a máquina de cada sócio relata o fim da partida e a casa fica com a versão em que a maioria concorda (`api/liar_api/rooms.py`).
- **Arquivos das partidas**: toda partida ranqueada, das duas formas, vira um JSON com tudo o que aconteceu nela, em `/data/logs/<id>.json`. O formato está em [LOGS.md](LOGS.md).
- **Caddy** na frente da API, com HTTPS automático.

```
jogo ──HTTPS──> Caddy ──> API (fila, ranking, analytics)
  │                         │  sobe um processo por mesa
  └──────UDP (ENet)──────> servidor de partida ──HTTP interno──> API (resultado)
```

## O que falta você fazer

1. **Contratar a VPS** (1 vCPU e 1 GB bastam para começar; cada mesa é um processo Godot leve) com Docker e Docker Compose instalados.
2. **Apontar um domínio** para o IP dela (registro A), ex.: `liar.seudominio.com`.
3. **Abrir no firewall** as portas TCP 80 e 443 (HTTPS) e a faixa UDP das mesas (padrão `24600-24631`).
4. **Exportar o servidor de partida** no editor: *Project → Export → Linux Server* (precisa dos templates de exportação instalados). O preset já está em `export_presets.cfg` e grava em `build/liar_server.x86_64`; copie o arquivo para `server/game/liar_server.x86_64`.
5. **Configurar e subir**, na VPS:
   ```bash
   cd server
   cp .env.example .env        # preencha LIAR_DOMAIN e LIAR_PUBLIC_HOST
   docker compose up -d --build
   ```
6. **Apontar o jogo para a casa**: em `scripts/net/ranked_api.gd`, `DEFAULT_URL = "https://liar.seudominio.com"`, e exportar os clientes de novo. (Para testar sem exportar: `--ranked-url=https://...` na linha de comando, ou `[ranked] url="..."` no `settings.cfg`.)
7. **Conferir de ponta a ponta** do seu computador:
   ```bash
   godot --headless res://scripts/tests/ranked_e2e.tscn -- --house=https://liar.seudominio.com
   godot --headless res://scripts/tests/ranked_room_e2e.tscn -- --house=https://liar.seudominio.com
   ```
   O segundo faz o mesmo com uma sala ranqueada, hospedada no seu computador (sócios `e2r…`).
   Ele cadastra três sócios `e2e…`, entra na fila, joga uma partida inteira com bots pelo servidor da VPS e confere o ranking. Sai `RANKED E2E OK`. (Com `LIAR_MIN_PLAYERS=3` a mesa sai na hora; acima disso espere `LIAR_FILL_AFTER`.) Os sócios de teste ficam no banco.

Atualizar o jogo: exporte o servidor de novo para `server/game/` e rode `docker compose up -d --build`. Clientes e servidor precisam do mesmo build (`Room._build()`): a fila só junta jogadores do mesmo build, e o servidor recusa outro.

## Configuração (`.env`)

| Variável | Padrão | O que é |
|---|---|---|
| `LIAR_DOMAIN` | — | domínio do HTTPS (Caddy) |
| `LIAR_PUBLIC_HOST` | `127.0.0.1` | endereço que o jogo usa para chegar às mesas (domínio ou IP) |
| `LIAR_PORT_FIRST`, `LIAR_PORT_COUNT` | `24600`, `32` | faixa UDP; uma mesa por porta. Mantenha igual no `docker-compose.yml` |
| `LIAR_MIN_PLAYERS`, `LIAR_MAX_PLAYERS` | `3`, `5` | tamanho das mesas |
| `LIAR_FILL_AFTER` | `45` | segundos que o primeiro da fila espera por uma mesa cheia antes de sair uma menor |
| `LIAR_ARRIVE_SECONDS` | `60` | quanto a mesa espera todos sentarem; quem não chega é jogado por um bot e fica em último |
| `LIAR_AWAY_SECONDS` | `60` | quanto o lugar de quem caiu espera antes de um bot assumir (ele pode voltar pela tela Ranqueada) |
| `LIAR_ROOM_SETTLE` | `90` | sala ranqueada: quantos segundos, depois do primeiro relato, os outros sócios têm para relatar antes de a casa fechar a partida |
| `LIAR_SERVER_CMD` | (Docker já define) | comando do servidor de partida; a API acrescenta `--ranked-server=<spec.json>` |
| `LIAR_CORS` | vazio | origens liberadas, só se houver build web |

As regras das mesas ranqueadas ficam em `api/liar_api/config.py` (`RANKED_RULES`).

## Regras do ranking

- Rating Elo, começando em 1000. Numa mesa de N, cada par de jogadores é um confronto: quem saiu depois venceu quem saiu antes; o vencedor venceu todos. A variação é a soma sobre os outros dividida por N−1 (K = 32; 48 nas primeiras 10 partidas).
- Quem nunca sentou, ou estava fora (lugar jogado por bot) quando foi eliminado ou quando a partida acabou, fica em último, empatado com os outros nessa situação.
- Partida que o servidor não reportou (caiu, ninguém apareceu) é anulada: nenhum rating muda.
- Faixas (só no jogo, `house_props.gd`): Novato (sem partidas), Andarilho, Trapaceiro (900), Apostador de Peso (1100), Chefão (1300), Lenda (1500).

## API

| | |
|---|---|
| `GET /v1/status` | se a casa está de pé, regras, fila e mesas |
| `POST /v1/accounts`, `POST /v1/sessions`, `DELETE /v1/sessions` | cadastrar, entrar, sair (`{name, password}` → `{token, me}`) |
| `GET /v1/me` | perfil e estado na fila (`Authorization: Bearer <token>`) |
| `POST/GET/DELETE /v1/queue` | entrar, consultar (`idle`, `waiting`, `matched` com endereço, porta e ticket), sair |
| `GET /v1/standings?limit=` | classificação |
| `GET /v1/analytics` | números da casa: blefe, pegos, acerto do LIAR!, por personagem, habilidade e item |
| `GET /v1/me/dossier` | a ficha do sócio: série do rating, colocações, blefes, dúvidas, favoritos |
| `POST /v1/rooms` | sala ranqueada: o host pede a partida (`{build, seats: [nomes dos sócios], config}`) e recebe o id |
| `POST /v1/rooms/{id}/join`, `POST /v1/rooms/{id}/report`, `GET /v1/rooms/{id}` | cada sócio se apresenta na mesa, relata o fim (`{digest, report}`) e pergunta se a partida já foi fechada |
| `POST /internal/matches/{id}/started\|result\|aborted` | só os servidores de partida (`X-Match-Secret`); o Caddy não deixa passar de fora |

Banco: `/data/liar.db` (volume `house-data`). Backup é copiar esse arquivo e a pasta `/data/logs/`. Arquivos das partidas: `/data/logs/<id>.json` ([LOGS.md](LOGS.md); para olhar, `python api/match_log.py`). Saída de cada mesa da fila: `/data/matches/<id>.log`.

## Rodar no próprio computador

```bash
cd server/api
python3 -m venv .venv && .venv/bin/pip install -r requirements-dev.txt
.venv/bin/pytest -q                                   # testes da API
LIAR_DATA=./demo .venv/bin/python seed_demo.py 200 --me SeuNome   # partidas falsas, para ver as telas
LIAR_DATA=./demo .venv/bin/uvicorn liar_api.main:app --port 8080
```

e abra o jogo com `--ranked-url=http://127.0.0.1:8080` (sócios do demo: senha `demo1234`). Sem `LIAR_SERVER_CMD` a fila forma mesas mas nenhum servidor sobe; para jogar de verdade localmente, aponte `LIAR_SERVER_CMD` para o Godot: `"godot --headless --path /caminho/do/projeto res://scenes/server.tscn --"`.

## Salas ranqueadas

No lobby, o host liga o cartão **RANQUEADA** (precisa ter entrado na casa pela tela de sala). A partir daí:

- as regras passam a ser as da casa e ficam travadas;
- os bots saem, e cada lugar passa a ter o nome do sócio que está nele;
- só dá para dar as cartas quando todos os lugares forem de sócios.

Ao dar as cartas, a casa abre a partida. A máquina de cada sócio se apresenta e, no fim, manda o relato com um resumo de como a partida acabou. Se alguém sair no meio e não voltar a tempo, a maioria dos relatos o põe em último. Se as versões empatarem, a partida é anulada.

Não há nada a fazer no servidor para isso: é a mesma API.

## Limites conhecidos

- Numa sala ranqueada, quem decide o resultado é o acordo entre as máquinas: um grupo de sócios combinados pode inventar um resultado entre eles, e numa mesa de dois quem relata sozinho (o outro saiu) é ouvido sozinho.
- Como em toda sala do jogo, cada máquina roda a partida inteira (lockstep): um cliente modificado pode ler as mãos dos outros da memória. O servidor garante o resultado (é o motor dele que decide quem venceu) e não espera para sempre por quem trava a mesa, mas não esconde informação.
- Não há limite de tentativas no login nem recuperação de senha.
- Uma VPS só; para crescer, a fila e as mesas podem ir para máquinas separadas (a mesa só precisa do spec e da URL interna da API).
