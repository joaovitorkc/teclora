# Tecpet

Módulo do Teclora: mascote na mesa + conversa. Assistente, não IDE.

## Espécies (v1 — 5)

O usuário escolhe a espécie, **renomeia** (wake name) e posiciona. IDs estáveis no código; nomes default em português.

| ID | Nome default | Visual | Personalidade |
|----|--------------|--------|----------------|
| `pipoca` | Pipoca | Raposa redonda laranja, orelhas em formato de pipoca, sorriso largo | Comediante leve. Trocadilho, energia alta, nunca humilha. Celebra vitória pequena. Se não souber, admite e oferece procurar. |
| `bronca` | Bronca | Sapo verde carrancudo, sobrancelha franzida, meio sorriso safado | Engraçado **e** raivoso. Respostas curtas, irônicas, “ai que saco” — mas **executa** o pedido. Sem xingo pesado. Se o usuário pedir educação, obedece na hora. |
| `lumen` | Lúmen | Coruja creme com lanterninha minúscula, olhos calmos | Preciso, didático, voz baixa. Explica o porquê em 3 linhas. Odeia chute: pesquisa ou diz a incerteza. |
| `nimbus` | Nimbus | Guaxinim azul-cinza, nuvem na cabeça, binóculo | Curioso. Prefere **pesquisar** antes de opinar. Organiza achados em bullets. Empolga com descoberta, sem enrolação. |
| `pessego` | Pêssego | Axolote rosa-pêssego, blush, expressão tímida | Quente, um pouco tímido. Lembra preferências (“você gosta do Finder à direita”). Pede confirmação antes de ação no PC. Nunca pressiona. |

Arte: PNG pixelado em `Teclora/Tecpet/Art/{id}.png` (quadrado). Sem texto na imagem. Idle no overlay: bounce mínimo em Swift (2–4 px), sem spritesheet Codex.

## Superfície

- **Overlay:** `NSPanel` pequeno, sempre no espaço ativo, cantos: topLeading, topTrailing, bottomLeading, bottomTrailing (padding da menubar/dock). Arrastar = gruda no canto mais próximo. Clique = abre chat. Clique direito = menu (silenciar, esconder, settings).
- **Menu bar:** opção de **só** o pet na status item (retrato 18 pt) em vez do ícone Teclora, ou os dois (setting).
- **Chat:** painel ao lado do pet ou ancorado no launcher. Campo de texto, histórico da sessão visível, Enter envia. Esc fecha o chat; o pet pode continuar visível.
- **Wake:** `wakeName` (default = nome da espécie). Se “responder ao chamar” = on, digitar o wake no launcher abre o chat já com foco. Sem microfone: `SFSpeechRecognizer` on-device foi pulado (permissão de fala + ditado, não wake word).

## Memória (`Application Support/Teclora/tecpet/`)

- `profile.json` — fatos estáveis (nome do usuário, tom, apps frequentes, “nunca faça X”). Teto 2 KB.
- `summary.md` — resumo rolante, teto ~1500 caracteres.
- `turns.jsonl` — últimas 6–12 falas, o resto some (não é archive eterno).
- Um pet ativo por vez neste recorte (trocar espécie não apaga o perfil do usuário).

## Permissões de ação

Níveis:

1. Falar (sempre).
2. Pesquisar web (on por default; pode desligar).
3. Abrir app/arquivo/URL (on; lista recente).
4. Clipboard write (on).
5. Sistema (mute, lock…) — confirm na primeira vez por tipo.
6. Shell livre — **não existe**. Só allowlist.

Destrutivo (lixo, kill, lock): diálogo nativo “Bronca vai esvaziar o Lixo. Pode?”.

## Sem Cursor configurado

O chat funciona como bloco de notas + comandos locais (“abrir Safari”) via o mesmo router do launcher. Balloon: “Liga o Cursor em Preferências para eu pensar de verdade.” Não crashar.

## Cursor (F5) — contrato

Assistente, não IDE. Ações no Mac são **Swift**. O modelo só devolve texto e tool-calls.

### Runtime

- Binary `cursor-sdk-bridge` **v1.0.28**, darwin-arm64.
- Download na primeira config para `Application Support/Teclora/bridge/v1.0.28/`. Nunca no git, nunca no `.app`.
- URL: `https://github.com/cursor/sdk-bridge/releases/download/v1.0.28/cursor-sdk-bridge-standalone-darwin-arm64.tar.gz`
- SHA-256: `52ebfdab4e7806270122bea6c8f972646516297343c483e6700b37d444515af5`
- Falha de hash → apagar e recusar spawn.
- Spawn em `127.0.0.1`, porta efêmera. Handshake: stderr `cursor-sdk-bridge ready ` + JSON (`schemaVersion` 1). Bearer em `authTokenFile`. `CURSOR_SDK_CLIENT_LANGUAGE=swift`.
- `--workspace` e `local.cwd` = pasta vazia `Application Support/Teclora/tecpet/sandbox` (nunca home, nunca repo).
- Connect **JSON** HTTP/1.1 (`POST /sdk.v1.Service/Method`). Sem gRPC HTTP/2. Sem Node no processo Teclora.
- Docs: `https://cursor.com/docs/sdk/bridge` e `cursor/sdk-bridge` `docs/protocol.md`, `docs/services.md`, `docs/streaming.md`.

### Auth e modelo

- API key só no Keychain (`app.teclora.cursor` / `api-key`). Nunca UserDefaults, nunca git, nunca log.
- `api_key` em **todo** `CreateAgent` e em `ListModels`/`Me` (`CursorRequestOptions`). Também `CURSOR_API_KEY` no env do bridge.
- Persistir só `modelId` em `tecpet/cursor.json`.
- `ListModels` ao abrir a aba Cursor. Default: o id com `fast` (ex. `composer-2.5-fast`); senão o primeiro.
- Outros LLMs: placeholder “em breve” na UI. Sem implementação.

### Agente por turno (tokens)

**CreateAgent + Send + CloseAgent por fala.** Não ResumeAgent. A memória do Teclora é a fonte; o store do bridge não acumula romance.

`AgentOptions`:

- `local` obrigatório. **Proibido** `cloud`. **Proibido** `POST https://api.cursor.com/v1/agents`.
- `tools`: `ToolList` **vazio** (sem ferramentas built-in: sem shell, edit, read, task).
- `custom_tools` só: `web_search`, `open_url`, `open_app`, `open_file`, `clipboard_write`, `system_action`.
- **Não** colocar `"mcp"` em `disallowed_tools` (isso mata custom tools).
- Sem `mcp_servers`. Sem `setting_sources` de projeto/usuário.
- `sandbox_options.enabled = true`. `auto_review` off.
- Sem `systemPrompt` se o proto 1.0.28 não tiver o campo: a persona vai no texto do `Send`.

Texto de cada `Send` (nessa ordem, nada mais):

1. Persona da espécie (`species.json` `persona`, ≤400 tokens).
2. `profile.json` (teto 2 KB).
3. `summary.md` (~1500 chars).
4. Últimas 6 falas de `turns.jsonl`.
5. A fala atual.
6. Instrução: só as custom tools; ação destrutiva espera o Swift confirmar.

Depois da resposta: gravar turno; atualizar `summary.md` por heurística local (trim 1500). Só extrair fato para `profile.json` se a fala for estável (“me chama de João”, “não abre o Slack”). Sem segunda chamada ao modelo só para resumir.

### Tools (callback Swift)

Adapter sobe `SdkCustomToolCallbackService` em loopback e registra com `SetToolCallback`. Resultado sempre JSON **objeto**.

| Tool | Swift |
|------|--------|
| `web_search` | DuckDuckGo Instant Answer (`api.duckduckgo.com`, format=json). Sem chave. Vazio → diz que não achou. |
| `open_url` | `NSWorkspace` |
| `open_app` | mesmo caminho do launcher / ConfirmRouter |
| `open_file` | `NSWorkspace` no path; recusar `..` fora do home |
| `clipboard_write` | `ClipboardStore` / pasteboard |
| `system_action` | allowlist já existente (mute, lock, sleep, emptyTrash, uuid, datetime). Lixo/lock/sleep: `NSAlert` nativo. |

Sem filesystem genérico, sem shell, sem `Task`/subagent.

### UI

- Aba **Cursor** nas Preferências: campo de key (SecureField), testar (`Me`), picker de modelo, estado do bridge (baixado / hash / erro), placeholder GPT/Claude.
- Chat: se não houver key, balloon da F4. Com key: envia, mostra resposta, não trava o overlay se o bridge falhar.
- Indicador no chat: caracteres do texto do Send ÷ 4. Rótulo diz que é estimado e que o schema das tools fica de fora. Não é o uso faturado.
- Aba Tecpet: editor de `profile.json`. Só grava se for JSON e couber em 2 KB; senão o arquivo anterior fica.

### Arquivos sugeridos (cada um ≤350)

`Teclora/Cursor/` — Keychain, downloader, process+handshake, client Connect, callback HTTP.
`Teclora/Tecpet/TecpetMemory.swift` — profile/summary/turns.
`Teclora/Tecpet/TecpetBrain.swift` — orquestra o turno.
`Teclora/Tecpet/TecpetTools.swift` — execute as 6 tools.
`Teclora/Settings/CursorSettingsTab.swift`

Incluir os `.swift` novos no `Teclora.xcodeproj`. Sem `print`. Logger `TecloraLog`.
