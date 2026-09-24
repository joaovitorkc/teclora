#!/bin/sh
set -e
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
if ! command -v swiftlint >/dev/null 2>&1; then
  echo "SwiftLint não está no PATH. Instale com: brew install swiftlint" >&2
  exit 1
fi
exec swiftlint lint "$@"
