# Cloud Environment — Teclora

Repo **único** `teclora`. App Mac nativo: **sem web, sem API, sem porta**.

| | |
|--|--|
| Owner | `teclora/.cursor/environment.json` |
| Remote | `github.com/wi-consultoria/teclora` |
| Runtime na VM | nenhum (Linux não abre o `.app`) |
| Sensor na VM | SwiftLint **se** estiver instalado; senão o install só passa |

## Criar no dashboard

1. O código tem que estar **pushado** em `wi-consultoria/teclora` (não no hub).
2. Environment de **um** repo — não marcar web+server.
3. `environment.json location` = `.cursor/environment.json`.
4. Save / Update Environment.
5. Smoke: install verde. Start verde **sem** URL. Option+Space e `xcodebuild` continuam no Mac.

## O que o Cloud não faz

- `xcodebuild`, Run no Xcode, atalho global, clique/Esc no painel.
- Não inventar `start:dev` nem porta HTTP.

Secrets: este recorte não usa. Se um dia houver, painel Secrets da Environment — nunca no git.
