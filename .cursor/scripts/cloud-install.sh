#!/usr/bin/env bash
# Cloud Agent — Teclora é app macOS. A VM é Linux: sem Xcode, sem .app, sem porta.
# Install só deixa o snapshot verde. Lint é bônus se SwiftLint existir.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "[install] app=$APP_DIR"
echo "[install] Teclora: source-only na VM (GUI e xcodebuild só no Mac)"

if [ -d /Applications/Xcode.app/Contents/Developer ]; then
  export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
fi

if command -v swiftlint >/dev/null 2>&1; then
  echo "[install] SwiftLint"
  ( cd "$APP_DIR" && swiftlint lint ) || {
    echo "[install] SwiftLint reportou issues — snapshot segue (agente corrige no código)" >&2
  }
else
  echo "[install] SwiftLint ausente — ok nesta VM"
fi

echo "[install] done"
