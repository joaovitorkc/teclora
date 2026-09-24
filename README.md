# Teclora

Launcher nativo para Mac (Tahoe). Option+Space, apps, clipboard e barra de menu; profundidade em [docs/profundidade.md](docs/profundidade.md). Tecpet: [docs/tecpet.md](docs/tecpet.md).

Não é app web. Não tem servidor, login nem porta HTTP.

## Requisitos

- macOS 26 Tahoe ou superior
- Xcode estável mais novo (`/Applications/Xcode.app`)

Conta Apple Developer **não** é necessária para Run local.

## Abrir no Xcode

1. Abra `Teclora.xcodeproj`.
2. Scheme **Teclora**, destino **My Mac**.
3. Run (⌘R). O app fica invisível no Dock (agente).
4. **Option+Space** abre o painel. Digite para filtrar, Enter abre, Esc fecha.

Sair: na lista, escolha **Sair do Teclora**.

### Atalhos no painel

| Tecla | Ação |
|-------|------|
| ↑ ↓ · ⌃N ⌃P · Tab | Mover seleção |
| Page Up / Page Down | Pular 8 itens |
| ↵ | Abrir |
| ⌘↵ | Mostrar no Finder |
| ⌘1…⌘9 | Abrir o item N (segure ⌘ para ver os números) |
| Esc | Limpa a busca; com a busca vazia, fecha |

A busca aceita prefixo, início de palavra, iniciais (`vsc` → Visual Studio Code), nome do arquivo em inglês (`calculator` acha "Calculadora") e fuzzy. Apps que você abre mais sobem na lista e aparecem em **Recentes**.

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

- Option+Space (não substitui o Spotlight)
- Catálogo em `/Applications`, `/System/Applications`, `~/Applications`
- Barra de menu + clipboard (F1). Snippets, arquivos, janelas, Tecpet: na fila da profundidade
- Sem loja, Sparkle ou sandbox App Store
