#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$PROJECT_ROOT/.build"
SOURCES=()
while IFS= read -r -d '' file; do
  SOURCES+=("$file")
done < <(find "$PROJECT_ROOT/Sources/NagaController" -name '*.swift' ! -name main.swift -print0)
while IFS= read -r -d '' file; do
  SOURCES+=("$file")
done < <(find "$PROJECT_ROOT/Tests" -name '*.swift' ! -path '*/NagaControllerTests/*' -print0)
printf 'Compiling dependency-free tests with the macOS SDK...\n'
swiftc -swift-version 5 -parse-as-library -module-name NagaController \
  "${SOURCES[@]}" -framework Cocoa -framework IOKit -framework CoreBluetooth \
  -framework UserNotifications -o "$PROJECT_ROOT/.build/NagaControllerTests"
"$PROJECT_ROOT/.build/NagaControllerTests"
