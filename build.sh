#!/usr/bin/env bash
GREEN=$'\e[32m'
YE=$'\e[33m'
RED=$'\e[31m'
NEG=$'\e[1m'
RESET=$'\e[0m' 

set -e

echo "📦 Compilando backend ultra otimizado em ${RED}Rust...${RESET}"
cargo build --release

echo "📁 ${GREEN}Instalando arquivos em ~/.config/quickshell/wayck/...${RESET}"
mkdir -p ~/.config/quickshell/wayck
cp target/release/wayck-backend ~/.config/quickshell/wayck/
cp qml/*.qml ~/.config/quickshell/wayck/

echo "✅ Pronto! Teste rodando:"
quickshell -p ~/.config/quickshell/wayck