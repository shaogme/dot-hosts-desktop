#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NPINS_DIR="$SCRIPT_DIR/npins"

run_npins() {
    if command -v npins &>/dev/null; then
        npins "$@"
    elif command -v nix &>/dev/null; then
        nix shell nixpkgs#npins -c npins "$@"
    else
        echo "Error: npins or nix command not found." >&2
        exit 1
    fi
}

DRY_RUN=0
for arg in "$@"; do
    if [[ "$arg" == "-n" || "$arg" == "--dry-run" ]]; then
        DRY_RUN=1
    fi
done

# 从 Mozilla 官方 API 抓取最新版本信息
VERSIONS_JSON=$(curl -sSL "https://product-details.mozilla.org/1.0/firefox_versions.json" || true)
if [ -z "$VERSIONS_JSON" ]; then
    echo "Warning: [firefox-developer-edition] Failed to fetch Mozilla product-details API, skipping upstream check."
    exit 0
fi

if command -v jq &>/dev/null; then
    LATEST_VERSION=$(echo "$VERSIONS_JSON" | jq -r '.FIREFOX_DEVEDITION // .LATEST_FIREFOX_DEVEL_VERSION // empty')
elif command -v python3 &>/dev/null; then
    LATEST_VERSION=$(python3 -c "import json, sys; data=json.loads(sys.argv[1]); print(data.get('FIREFOX_DEVEDITION') or data.get('LATEST_FIREFOX_DEVEL_VERSION') or '')" "$VERSIONS_JSON" 2>/dev/null || true)
fi

if [ -z "$LATEST_VERSION" ]; then
    echo "Warning: [firefox-developer-edition] Could not parse latest Firefox Developer Edition version, skipping."
    exit 0
fi

CURRENT_URL=""
if [ -f "$NPINS_DIR/sources.json" ]; then
    if command -v jq &>/dev/null; then
        CURRENT_URL=$(jq -r '.pins["firefox-developer-edition"].url // empty' "$NPINS_DIR/sources.json" 2>/dev/null || true)
    elif command -v python3 &>/dev/null; then
        CURRENT_URL=$(python3 -c "import json; data=json.load(open('$NPINS_DIR/sources.json')); print(data.get('pins',{}).get('firefox-developer-edition',{}).get('url',''))" 2>/dev/null || true)
    fi
fi

NEW_URL="https://archive.mozilla.org/pub/devedition/releases/${LATEST_VERSION}/linux-x86_64/en-US/firefox-${LATEST_VERSION}.tar.xz"

if [ "$CURRENT_URL" == "$NEW_URL" ]; then
    echo "[firefox-developer-edition] Up to date: $LATEST_VERSION"
else
    echo "[firefox-developer-edition] New version detected: $LATEST_VERSION (current: ''${CURRENT_URL:-none})"
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "[firefox-developer-edition] (dry-run) Would update to: $NEW_URL"
    else
        echo "[firefox-developer-edition] Updating npins to: $NEW_URL"
        run_npins -d "$NPINS_DIR" add tarball --name firefox-developer-edition "$NEW_URL"
    fi
fi
