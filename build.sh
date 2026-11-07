#!/usr/bin/env bash

set -Eeuo pipefail

GREEN=$'\e[32m'
RED=$'\e[31m'
RESET=$'\e[0m'

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DEST="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/wayck"

echo "📦 Compilando backend em ${RED}Rust...${RESET}"

cargo build --release --manifest-path "$ROOT/Cargo.toml"

echo "⏹️ Encerrando Wayck..."

quickshell -c wayck kill 2>/dev/null || true

echo "📁 ${GREEN}Instalando arquivos...${RESET}"

mkdir -p "$DEST"

install -m 755 "$ROOT/target/release/wayck-backend" "$DEST/wayck-backend.tmp"
mv -f "$DEST/wayck-backend.tmp" "$DEST/wayck-backend"

cp -a "$ROOT/qml/." "$DEST/"

echo "✅ Instalação concluída!"
