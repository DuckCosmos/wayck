#!/usr/bin/env bash
# Confere os JSONs de tradução contra o inglês (en.json):
#   - chaves que faltam ou sobram
#   - {placeholders} diferentes do inglês
#   - strings vazias
#
#   ./scripts/i18n-check.sh          # todos os idiomas
#   ./scripts/i18n-check.sh pt ja    # só alguns
#
# Chave que falta não quebra nada (o Wayck cai pro inglês), mas é bom saber.
# Requer: jq

set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DIR="$ROOT/qml/assets/languages"

command -v jq >/dev/null 2>&1 || { echo "jq is required." >&2; exit 2; }
[[ -f "$DIR/en.json" ]] || { echo "missing $DIR/en.json" >&2; exit 2; }

# "chave<TAB>placeholders ordenados"
flatten() {
    jq -r 'paths(scalars) as $p
        | getpath($p) as $v
        | "\($p | map(tostring) | join("."))\t\([$v | scan("\\{\\w+\\}")] | sort | join(","))\t\($v | length)"' "$1" | sort
}

if (($#)); then
    langs=("$@")
else
    langs=()
    for f in "$DIR"/*.json; do langs+=("$(basename "$f" .json)"); done
fi

base="$(flatten "$DIR/en.json")"
total="$(wc -l <<< "$base")"
problems=0

for lang in "${langs[@]}"; do
    [[ "$lang" == en ]] && continue

    file="$DIR/$lang.json"

    if [[ ! -f "$file" ]]; then
        echo "✗ $lang: arquivo não existe"
        problems=$((problems + 1))
        continue
    fi

    if ! jq -e . "$file" >/dev/null 2>&1; then
        echo "✗ $lang: JSON inválido"
        problems=$((problems + 1))
        continue
    fi

    current="$(flatten "$file")"
    missing="$(comm -23 <(cut -f1 <<< "$base") <(cut -f1 <<< "$current"))"
    extra="$(comm -13 <(cut -f1 <<< "$base") <(cut -f1 <<< "$current"))"
    empty="$(awk -F'\t' '$3 == 0 { print $1 }' <<< "$current")"
    mismatch="$(join -t $'\t' -j1 -o 1.1,1.2,2.2 <(cut -f1,2 <<< "$base") <(cut -f1,2 <<< "$current") | awk -F'\t' '$2 != $3 { print $1 " (en: " $2 " | aqui: " $3 ")" }')"

    count="$(wc -l <<< "$current")"
    status="✓"
    [[ -n "$missing$extra$empty$mismatch" ]] && status="✗"

    printf '%s %-6s %s/%s chaves\n' "$status" "$lang" "$count" "$total"

    [[ -n "$missing" ]]  && { sed 's/^/    falta:       /' <<< "$missing"; }
    [[ -n "$extra" ]]    && { sed 's/^/    sobrando:    /' <<< "$extra"; }
    [[ -n "$empty" ]]    && { sed 's/^/    vazia:       /' <<< "$empty"; }
    [[ -n "$mismatch" ]] && { sed 's/^/    placeholder: /' <<< "$mismatch"; }

    [[ "$status" == "✗" ]] && problems=$((problems + 1))
done

if ((problems)); then
    echo
    echo "$problems idioma(s) com problema."
    exit 1
fi

echo
echo "Tudo certo."
