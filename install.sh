#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/DuckCosmos/wayck.git"
SRC_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/wayck-src"

if ! command -v pacman >/dev/null; then
    echo "Only Arch/CachyOS (pacman) is supported. See the manual installation in the README."
    exit 1
fi

NEED=()
command -v git   >/dev/null || NEED+=(git)
command -v cargo >/dev/null || NEED+=(rust)
command -v cc    >/dev/null || NEED+=(base-devel)
if (( ${#NEED[@]} )); then
    sudo pacman -S --needed "${NEED[@]}"
fi

if [[ -f "${BASH_SOURCE[0]:-}" ]]; then
    cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
fi

if [[ ! -f Cargo.toml || ! -d qml ]]; then
    if [[ -d "$SRC_DIR/.git" ]]; then
        git -C "$SRC_DIR" pull --ff-only
    else
        git clone --depth 1 "$REPO_URL" "$SRC_DIR"
    fi
    cd "$SRC_DIR"
fi

if [[ -f src/bin/wayck-setup.rs ]]; then
    exec cargo run --release --bin wayck-setup -- "$@"
fi

if [[ -f setup.rs ]]; then
    TMP="$(mktemp -d)"
    trap 'rm -rf "$TMP"' EXIT
    CARGO_MANIFEST_DIR="$PWD" rustc --edition 2021 -O setup.rs -o "$TMP/wayck-setup"
    "$TMP/wayck-setup" "$@"
    exit
fi

echo "Installer not found (expected src/bin/wayck-setup.rs or setup.rs)."
exit 1