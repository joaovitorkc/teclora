# Teclora — profundidade (Raycast local + Tecpet)

Fonte para Cloud Agent e para o app. Recorte 1 (abrir apps + Option+Space) **permanece**. Isto soma módulos locais e o Tecpet.

Stack inalterada: Swift 6, AppKit + SwiftUI, macOS 26 Tahoe, `LSUIElement`, sem Electron/Node/WKWebView, sem porta HTTP de produto. Teto **350 linhas** por arquivo. Sem `print`/`debugPrint`/`dump`/`NSLog` — usar `TecloraLog` (`os.Logger`, subsystem `app.teclora`).

## Arquitetura do launcher

Hoje `LauncherItem` só tem `application` e `quit`. Isso não escala.

```
CommandProvider  →  [LauncherHit]
SearchIndex      →  funde apps + providers, reusa AppSearch.matchRank
LauncherModel    →  seções (Recentes, Aplicativos, Clipboard, …)
ConfirmRouter    →  executa a ação do hit
```

Cada provider é um arquivo pequeno: `ClipboardProvider`, `SnippetProvider`, `FileProvider`, `WindowProvider`, `SystemProvider`, `CalcProvider`, `TecpetProvider`.

`Application Support/Teclora/` para JSON/SQLite locais. Nunca iCloud obrigatório. Nunca rede para clipboard/snippets.

## Barra de menu

`NSStatusItem` sempre visível (recortes desta fase). Clique esquerdo: toggle do launcher. Menu: Abrir Teclora, Tecpet, Preferências, Sair. Ícone template (monocromático) para claro/escuro.

## Preferências

Janela Settings (SwiftUI + AppKit). Abre pelo comando “Preferências” / “Settings” e pelo menu bar. Abas mínimas: Geral (atalho já existe via KeyboardShortcuts), Clipboard, Snippets, Tecpet, Cursor. Sem conta.

## Módulos locais (fase A)

### Clipboard

- Poll `NSPasteboard.general.changeCount` em timer discreto (não a cada frame).
- Itens: texto, e se for barato um preview de imagem.
- Pin, copiar de novo, apagar um, limpar tudo.
- Persistência local. **Nunca** mandar ao modelo/Cursor salvo o usuário colar na conversa do Tecpet na hora.
- Busca no launcher: query casa o conteúdo; Enter copia e fecha.

### Snippets

- Nome, atalho curto, corpo, data.
- CRUD na Settings e comandos no launcher (“novo snippet”).
- Enter: copia o corpo (e se possível dispara paste — só com Acessibilidade; fallback = copiou, usuário cola).

### Arquivos

- `NSMetadataQuery` / Spotlight no home e discos do usuário, limite de resultados (ex. 40).
- Enter abre; ⌘Enter revela. Não indexar o mundo na mão.

### Janelas

- Listar janelas de apps (CGWindowList). Focar. Azul: esquerda, direita, maximizar, centro.
- Se o macOS exigir Acessibilidade, pedir de forma honesta (uma tela “Abrir Ajustes”) e degradar para só focar.

### Sistema (não depende de conta)

- Calculadora na busca (`1+2*3` → resultado, Enter copia).
- Emoji mais usados (catálogo curto; busca por nome).
- Bloquear tela, dormir, esvaziar lixo, mudo/unmute, mostrar desktop.
- Encerrar processo (confirma).
- UUID / data-hora (copia).
- Quicklinks locais (URL ou path que o usuário cadastrou) — CRUD mínimo.

## Tecpet (fase B/C)

Ver [tecpet.md](./tecpet.md).

## Cursor (fase C)

Integração **completa só Cursor**. Outros LLMs: placeholder “em breve” na UI.

- API key no **Keychain** (nunca UserDefaults em claro, nunca git).
- Modelo: `ListModels` via `cursor-sdk-bridge`. Default sugerido: o mais barato/rápido da lista (ex. `composer-2.5-fast` se existir).
- Runtime: spawn `cursor-sdk-bridge` (darwin-arm64) em loopback. O `.app` **não** embute Node. O binary pode ser vendored em `Resources/` ou baixado na primeira configuração (hash pin).
- Modo **ask** + tools **somente** as registradas pelo Teclora (callback no Swift). Proibido ligar filesystem/shell genérico do agent no disco do usuário.
- Tools locais: `web_search`, `open_url`, `open_app`, `open_file`, `clipboard_write`, `system_action` (allowlist + confirm se destrutivo).
- Não criar Cloud Agent (`POST /v1/agents`) para o pet — isso roda numa VM e não mexe neste Mac.

## Tokens

Por turno o prompt do modelo leva:

1. System da espécie (personalidade, ≤ 400 tokens).
2. Perfil do usuário (JSON compacto, teto ~2 KB).
3. Resumo rolante (teto ~500 tokens).
4. Últimas **6** mensagens (não 200).
5. A fala atual.
6. Schema das tools.

Depois da resposta: atualizar resumo (1 chamada barata ou heurística local se a fala for “ok/valeu”). Preferências extraídas só quando o usuário disser algo estável (“me chama de João”, “não abre o Slack”).

Mostrar na UI do chat um indicador simples (estimado) para o usuário não voar às cegas.

## Cloud Agent

A VM Linux **não** abre o `.app`. Critério de pronto de uma fatia Cloud:

- Código na branch `agent/teclora-profundidade`
- Arquivos ≤ 350 linhas
- Sem print
- Commit em português, curto
- Relato: arquivos + o que o Mac precisa clicar para validar

`xcodebuild` e Option+Space são do orchestrator no Mac.
