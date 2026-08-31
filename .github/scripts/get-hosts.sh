#!/usr/bin/env bash
set -euo pipefail

# Change directory to the repository root (two levels up from .github/scripts)
cd "$(dirname "$0")/../../"

FILTER_NPINS=false
if [[ "${1:-}" == "--filter-npins" ]]; then
    FILTER_NPINS=true
fi

# Whitelisted host categories (Single Source of Truth for desktop repository)
WHITELIST_DIRS=("hosts")

hosts=()

for category in "${WHITELIST_DIRS[@]}"; do
    if [ -d "$category" ]; then
        for dir in "$category"/*/; do
            [ -d "$dir" ] || continue
            dir=${dir%/} # strip trailing slash
            
            if [ -f "$dir/configuration.nix" ]; then
                if [ "$FILTER_NPINS" = true ]; then
                    if [ ! -f "$dir/npins/default.nix" ] || [ ! -f "$dir/npins/sources.json" ]; then
                        continue
                    fi
                fi
                hosts+=("$dir")
            fi
        done
    fi
done

# Sort host list for deterministic ordering
if [ ${#hosts[@]} -gt 0 ]; then
    IFS=$'\n' hosts=($(sort <<<"${hosts[*]}"))
fi

# Output as JSON array
if [ ${#hosts[@]} -eq 0 ]; then
    echo "[]"
elif command -v jq &>/dev/null; then
    printf '%s\n' "${hosts[@]}" | jq -R . | jq -s -c .
elif command -v python3 &>/dev/null; then
    python3 -c 'import json, sys; print(json.dumps(sys.argv[1:]))' "${hosts[@]}"
else
    res="["
    first=true
    for h in "${hosts[@]}"; do
        if [ "$first" = true ]; then
            first=false
        else
            res+=", "
        fi
        res+="\"$h\""
    done
    res+="]"
    echo "$res"
fi
