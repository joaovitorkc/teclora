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
- **Wake:** `wakeName` (default = nome da espécie). Se “responder ao chamar” = on, digitar o wake no launcher abre o chat já com foco. Atalho global opcional (KeyboardShortcuts), default desligado para não brigar com Option+Space.

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
