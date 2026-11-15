#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
    cat <<'EOF'
Utilizare: run.sh MODEL [MODEL ...]
           run.sh --all

Exemple: run.sh sum
         run.sh sum.smv fibo
         run.sh --all

Modelele sunt citite din src/, iar rezultatele sunt salvate in bin/.
Executabilul este detectat ca NuSMV sau nusmv in PATH.
Pentru o cale personalizata: NUSMV=/cale/catre/NuSMV run.sh sum
EOF
}

if (( $# == 0 )); then
    usage >&2
    exit 2
fi
if [[ "$1" == --help || "$1" == -h ]]; then
    usage
    exit 0
fi

models=()
if [[ "$1" == --all || "$1" == -all ]]; then
    if (( $# != 1 )); then
        usage >&2
        exit 2
    fi
    shopt -s nullglob
    for model_path in "$project_dir"/src/*.smv; do
        models+=("$(basename -- "$model_path" .smv)")
    done
else
    for argument in "$@"; do
        model="${argument%.smv}"
        if [[ -z "$model" || "$model" == */* || "$model" == -* ]]; then
            echo "Nume de model invalid: $argument. Foloseste numele din src/, fara cale." >&2
            exit 2
        fi
        models+=("$model")
    done
fi

if (( ${#models[@]} == 0 )); then
    echo "Nu exista modele .smv in $project_dir/src/." >&2
    exit 1
fi
for model in "${models[@]}"; do
    if [[ ! -f "$project_dir/src/$model.smv" ]]; then
        echo "Model inexistent: $project_dir/src/$model.smv" >&2
        exit 1
    fi
done

nusmv_bin="${NUSMV:-}"
if [[ -z "$nusmv_bin" ]]; then
    nusmv_bin="$(command -v NuSMV || command -v nusmv || true)"
fi
if [[ -z "$nusmv_bin" ]] || ! command -v "$nusmv_bin" >/dev/null 2>&1; then
    echo "NuSMV nu a fost gasit. Adauga-l in PATH sau seteaza NUSMV=/cale/catre/NuSMV." >&2
    exit 127
fi

commands_file="$(mktemp "${TMPDIR:-/tmp}/nusmv-commands.XXXXXX")"
trap 'rm -f -- "$commands_file"' EXIT
cat > "$commands_file" <<'EOF'
go

echo "=== Simulare: 11 tranzitii ==="
pick_state
simulate -k 11 -v

echo
echo "=== Verificare LTL ==="
check_ltlspec

echo
echo
echo "=== Verificare CTL ==="
check_ctlspec

quit
EOF

mkdir -p -- "$project_dir/bin"
for model in "${models[@]}"; do
    output_file="$project_dir/bin/${model}_output.txt"
    echo "Rulez $model.smv; rezultate: $output_file"
    {
        echo "=== Processing ${model}.smv ==="
        "$nusmv_bin" -source "$commands_file" "$project_dir/src/$model.smv"
    } | tee "$output_file"
done
