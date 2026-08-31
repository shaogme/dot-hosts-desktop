#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Check help
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    echo "Usage: $0 [npins-update-flags/names...]"
    echo ""
    echo "Updates npins dependencies for all hosts and modules (including modules/apps)."
    echo "Optional arguments will be passed directly to 'npins update'."
    exit 0
fi

# Run npins command with fallback to nix shell if npins is not in PATH
run_npins() {
    if command -v npins &>/dev/null; then
        npins "$@"
    elif command -v nix &>/dev/null; then
        nix shell nixpkgs#npins -c npins "$@"
    else
        echo "Error: neither npins nor nix command was found." >&2
        exit 1
    fi
}

TARGETS=()

# 1. 扫描主机列表 (通过 .github/scripts/get-hosts.sh)
if [ -f "$REPO_DIR/.github/scripts/get-hosts.sh" ]; then
    HOSTS_JSON=$(bash "$REPO_DIR/.github/scripts/get-hosts.sh" --filter-npins || true)
    if command -v jq &>/dev/null; then
        while IFS= read -r host; do
            [ -n "$host" ] && TARGETS+=("$host")
        done < <(echo "$HOSTS_JSON" | jq -r '.[]' 2>/dev/null || true)
    elif command -v python3 &>/dev/null; then
        while IFS= read -r host; do
            [ -n "$host" ] && TARGETS+=("$host")
        done < <(python3 -c "import json, sys; [print(h) for h in json.loads(sys.argv[1])]" "$HOSTS_JSON" 2>/dev/null || true)
    else
        clean_json=$(echo "$HOSTS_JSON" | tr -d '[]" ' | tr ',' '\n')
        while IFS= read -r host; do
            [ -n "$host" ] && TARGETS+=("$host")
        done <<< "$clean_json"
    fi
fi

# 2. 扫描 modules 目录下所有包含 npins 的模块与应用 (如 modules/apps/clash-verge)
if [ -d "$REPO_DIR/modules" ]; then
    while IFS= read -r npins_dir; do
        target_dir=$(dirname "$npins_dir")
        rel_path="${target_dir#$REPO_DIR/}"
        TARGETS+=("$rel_path")
    done < <(find "$REPO_DIR/modules" -type d -name "npins" -exec test -f "{}/sources.json" -a -f "{}/default.nix" \; -print 2>/dev/null || true)
fi

# 排序并去重
readarray -t SORTED_TARGETS < <(printf "%s\n" "${TARGETS[@]}" | sort -u)

if [ ${#SORTED_TARGETS[@]} -eq 0 ]; then
    echo "No targets with npins found."
    exit 0
fi

echo "Found ${#SORTED_TARGETS[@]} target(s) with npins:"
for target in "${SORTED_TARGETS[@]}"; do
    echo "  - $target"
done
echo ""

for target in "${SORTED_TARGETS[@]}"; do
    target_dir="$REPO_DIR/$target"
    if [ ! -d "$target_dir" ]; then
        echo "Warning: Directory $target_dir does not exist, skipping."
        continue
    fi
    echo "=========================================="
    echo "Updating npins for: $target"
    echo "=========================================="
    (
        cd "$target_dir"
        run_npins upgrade
        run_npins update "$@"
    )
done

echo ""
echo "=========================================="
echo "Successfully updated npins for all targets!"
echo "=========================================="
