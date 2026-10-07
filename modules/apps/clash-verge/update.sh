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

# 1. 请求 GitHub 官方 Releases API
CURL_ARGS=(-sSL)
if [ -n "${GITHUB_TOKEN:-}" ]; then
    CURL_ARGS+=(-H "Authorization: Bearer $GITHUB_TOKEN")
fi
RELEASE_JSON=$(curl "${CURL_ARGS[@]}" "https://api.github.com/repos/clash-verge-rev/clash-verge-rev/releases/latest" || true)
if [ -z "$RELEASE_JSON" ]; then
    echo "Warning: [clash-verge] Failed to fetch GitHub release API, skipping."
    exit 0
fi

# 2. 解析最新版本与下载链接
NEW_URL=""
LATEST_VERSION=""
if command -v jq &>/dev/null; then
    LATEST_VERSION=$(echo "$RELEASE_JSON" | jq -r '.tag_name // empty' | sed 's/^v//')
    NEW_URL=$(echo "$RELEASE_JSON" | jq -r '(.assets[]? | select(.name | test("Clash\\.Verge_.*_amd64\\.deb$")) | .browser_download_url) // empty' | head -n 1)
elif command -v python3 &>/dev/null; then
    PARSED=$(python3 -c "
import json, sys, re
try:
    data = json.loads(sys.argv[1])
    tag = data.get('tag_name', '').lstrip('v')
    url = ''
    for asset in data.get('assets', []):
        name = asset.get('name', '')
        if re.search(r'Clash\.Verge_.*_amd64\.deb$', name):
            url = asset.get('browser_download_url', '')
            break
    print(f'{tag}\t{url}')
except Exception:
    pass
" "$RELEASE_JSON" 2>/dev/null || true)
    LATEST_VERSION=$(echo "$PARSED" | cut -f1)
    NEW_URL=$(echo "$PARSED" | cut -f2)
fi

if [ -z "$NEW_URL" ]; then
    echo "Warning: [clash-verge] Could not find Linux amd64 deb package in latest release, skipping."
    exit 0
fi

# 3. 读取当前 sources.json 中的 URL
CURRENT_URL=""
if [ -f "$NPINS_DIR/sources.json" ]; then
    if command -v jq &>/dev/null; then
        CURRENT_URL=$(jq -r '.pins["clash-verge"].url // empty' "$NPINS_DIR/sources.json" 2>/dev/null || true)
    elif command -v python3 &>/dev/null; then
        CURRENT_URL=$(python3 -c "
import json
try:
    with open('$NPINS_DIR/sources.json') as f:
        data = json.load(f)
    print(data.get('pins', {}).get('clash-verge', {}).get('url', ''))
except Exception:
    pass
" 2>/dev/null || true)
    fi
fi

# 4. 比较并执行更新
if [ "$CURRENT_URL" == "$NEW_URL" ]; then
    echo "[clash-verge] Up to date: $LATEST_VERSION ($CURRENT_URL)"
else
    echo "[clash-verge] New version detected: $LATEST_VERSION"
    echo "[clash-verge] Current URL: ${CURRENT_URL:-none}"
    echo "[clash-verge] Target URL:  $NEW_URL"

    # 验证目标链接有效性
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -A "Mozilla/5.0" "$NEW_URL" || true)
    if [ "$HTTP_CODE" -ne 200 ] && [ "$HTTP_CODE" -ne 302 ]; then
        echo "Warning: [clash-verge] Target URL returned HTTP $HTTP_CODE, skipping update."
        exit 0
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        echo "[clash-verge] (dry-run) Would update to: $NEW_URL"
    else
        echo "[clash-verge] Updating npins to: $NEW_URL"
        run_npins -d "$NPINS_DIR" add url --name clash-verge "$NEW_URL"
    fi
fi
