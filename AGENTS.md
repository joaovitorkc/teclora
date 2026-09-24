# AGENTS.md — Teclora

Launcher nativo de macOS (atalho global → painel → abrir apps). **Não é produto web WI.**

## O que é

App local, sem servidor, sem conta, sem tenant. Vive em `teclora/` neste hub. Stack: **Swift 6**, **macOS 26 Tahoe** mínimo, janela em **AppKit** (`NSPanel`), conteúdo em **SwiftUI** (`NSHostingView`).

Não aplicar `wi-iniciar-produto` (Next/Nest, `users` / `user_accesses`, portas). Não copiar shell e-SUS, Visa, Lavite nem qualquer app Electron/React.

## Recorte atual (1)

Atalho **Option+Space** → painel → filtrar `.app` instalados → Enter abre → Esc fecha e devolve o foco. Sem ícone no Dock (`LSUIElement`). Sair pelo comando **Sair do Teclora** na lista.

Fora deste recorte: clipboard, snippets, janelas, quicklinks, arquivo, IA, loja, Sparkle, sandbox, notarização, Windows.

## Mapa

| Path | Papel |
|------|--------|
| `Teclora.xcodeproj` | Projeto Xcode (scheme `Teclora`) |
| `Teclora/AppDelegate.swift` | Processo agente, política accessory |
| `Teclora/Hotkey/` | Option+Space via KeyboardShortcuts |
| `Teclora/Launcher/` | `NSPanel` + SwiftUI busca/lista |
| `Teclora/Catalog/` | Enumeração de `.app` + filtro |
| `.swiftlint.yml` | Gates: teto 350 linhas, sem `print`/`NSLog` diretos |

## Como abrir

1. Xcode estável mais novo, Mac no Tahoe.
2. Abrir `teclora/Teclora.xcodeproj` (ou a pasta `teclora/` no Xcode).
3. Scheme **Teclora** → Run. O app não aparece no Dock; usar Option+Space.

Build CLI:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project teclora/Teclora.xcodeproj -scheme Teclora -configuration Debug \
  -destination 'platform=macOS' build
```

Lint (teto 350 linhas; sem `print` / `debugPrint` / `dump` / `NSLog` diretos):

```bash
brew install swiftlint   # uma vez
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swiftlint lint
# ou: ./scripts/lint.sh
```

Não existe `verify-teclora.sh`. Atalho global só se prova na GUI do Mac.

## Invariantes

- Sem Electron, Node, WKWebView, App Store sandbox.
- Hotkey: pacote KeyboardShortcuts (Carbon) — sem permissão de Acessibilidade neste recorte.
- Abrir app: `NSWorkspace.shared.open`.
- Assinatura: Time pessoal do Xcode basta para Run local.

## Git

Não commit/push sem pedido explícito do usuário.
