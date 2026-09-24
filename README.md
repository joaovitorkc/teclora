# Teclora

Launcher nativo para Mac (Tahoe). Option+Space abre o painel; a barra de menu abre o mesmo painel. Busca apps, clipboard, snippets, quicklinks, arquivos e janelas. Profundidade: [docs/profundidade.md](docs/profundidade.md). Tecpet: [docs/tecpet.md](docs/tecpet.md).

Não é app web. Não tem servidor, login nem porta HTTP.

## Requisitos

- macOS 26 Tahoe ou superior
- Xcode estável mais novo (`/Applications/Xcode.app`)

Conta Apple Developer **não** é necessária para Run local.

## Abrir no Xcode

1. Abra `Teclora.xcodeproj`.
2. Scheme **Teclora**, destino **My Mac**.
3. Run (⌘R). O app fica invisível no Dock (agente) e aparece na barra de menu.
4. **Option+Space**, ou um clique no ícone da barra, abre o painel. O clique direito nesse ícone abre Teclora, Tecpet, Preferências e Sair. Digite para filtrar. Enter abre o app, copia o clipboard, cola um snippet ou abre Preferências. Esc fecha.

Sair: comando **Sair do Teclora**, ou **Sair** no menu da barra.

### Atalhos no painel

| Tecla | Ação |
|-------|------|
| ↑ ↓ · ⌃N ⌃P · Tab | Mover seleção |
| Page Up / Page Down | Pular 8 itens |
| ↵ | Abrir app, arquivo ou janela; copiar clipboard ou snippet; abrir Preferências |
| ⌘↵ | No app ou arquivo: mostrar no Finder. No clipboard: fixar |
| ⌘⌫ | Apagar o item de clipboard selecionado |
| ⌘1…⌘9 | Abrir o item N (segure ⌘ para ver os números) |
| Esc | Limpa a busca; com a busca vazia, fecha |

A busca aceita prefixo, início de palavra, iniciais (`vsc` → Visual Studio Code), nome do arquivo em inglês (`calculator` acha "Calculadora") e fuzzy. Apps que você abre mais sobem na lista e aparecem em **Recentes**. Texto copiado entra em **Clipboard**; a busca casa o conteúdo. Preferências (Geral, Clipboard, Snippets, Quicklinks, Tecpet, Cursor) ficam em `~/Library/Application Support/Teclora/`. O clipboard não sai do Mac.

O chat do Tecpet mostra `≈ N tokens no texto`: é o tamanho do prompt (persona, perfil, resumo, últimas 6 falas, rascunho) dividido por 4. Não é a conta da API. O schema das tools não entra nesse número. Em Tecpet → “O que o pet sabe” dá para ver e gravar o `profile.json`.

## Build na linha de comando

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project Teclora.xcodeproj -scheme Teclora -configuration Debug \
  -destination 'platform=macOS' build
```

## Lint

Teto de **350 linhas** por arquivo e proibição de `print` / `debugPrint` / `dump` / `NSLog` diretos (equivalente Swift dos quality gates de ESLint). Não é um guia de estilo.

```bash
brew install swiftlint   # uma vez
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swiftlint lint
# ou: ./scripts/lint.sh
```

## Cloud Agent

Repo único (`github.com/joaovitorkc/teclora`). Sem servidor na VM. Passo a passo: [docs/cloud-environments.md](docs/cloud-environments.md).

## Recorte — o que entra

- Option+Space (não substitui o Spotlight) e ícone template na barra de menu
- Catálogo em `/Applications`, `/System/Applications`, `~/Applications`
- Histórico de clipboard (texto): gravar, tamanho máximo, fixar, copiar de volta, apagar
- Snippets, calculadora, comandos de sistema e quicklinks
- Arquivos via Spotlight (Enter abre, ⌘Enter revela) e janelas (focar; esquerda, direita, maximizar, centro)
- Preferências: Geral, Clipboard, Snippets, Quicklinks, Tecpet, Cursor
- Tecpet: overlay, chat, memória local. Cursor só pelo bridge darwin-arm64 e key no Keychain. Sem key, o chat continua no balão e ainda abre app (“abrir Safari”).
- Orçamento de tokens estimado no chat e editor do `profile.json` (JSON, 2 KB)

Fora de propósito: voz (`SFSpeechRecognizer` — pede microfone e não é wake word; o wake continua sendo o nome digitado no launcher), GPT, Claude, cloud agent, segunda chamada de modelo para resumir. Sem loja, Sparkle ou sandbox App Store.
