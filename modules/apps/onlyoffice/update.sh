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
RELEASE_JSON=$(curl "${CURL_ARGS[@]}" "https://api.github.com/repos/ONLYOFFICE/DesktopEditors/releases/latest" || true)
if [ -z "$RELEASE_JSON" ]; then
    echo "Warning: [onlyoffice] Failed to fetch GitHub release API, skipping."
    exit 0
fi

# 2. 解析最新版本与各架构下载链接
LATEST_VERSION=""
NEW_URL_X86=""
NEW_URL_ARM=""
if command -v jq &>/dev/null; then
    LATEST_VERSION=$(echo "$RELEASE_JSON" | jq -r '.tag_name // empty' | sed 's/^v//')
    NEW_URL_X86=$(echo "$RELEASE_JSON" | jq -r '(.assets[]? | select(.name | test("onlyoffice-desktopeditors_amd64\\.deb$")) | .browser_download_url) // empty' | head -n 1)
    NEW_URL_ARM=$(echo "$RELEASE_JSON" | jq -r '(.assets[]? | select(.name | test("onlyoffice-desktopeditors_arm64\\.deb$")) | .browser_download_url) // empty' | head -n 1)
elif command -v python3 &>/dev/null; then
    PARSED=$(python3 -c "
import json, sys, re
try:
    data = json.loads(sys.argv[1])
    tag = data.get('tag_name', '').lstrip('v')
    x86 = ''
    arm = ''
    for asset in data.get('assets', []):
        name = asset.get('name', '')
        if re.search(r'onlyoffice-desktopeditors_amd64\.deb$', name):
            x86 = asset.get('browser_download_url', '')
        elif re.search(r'onlyoffice-desktopeditors_arm64\.deb$', name):
            arm = asset.get('browser_download_url', '')
    print(f'{tag}\t{x86}\t{arm}')
except Exception:
    pass
" "$RELEASE_JSON" 2>/dev/null || true)
    LATEST_VERSION=$(echo "$PARSED" | cut -f1)
    NEW_URL_X86=$(echo "$PARSED" | cut -f2)
    NEW_URL_ARM=$(echo "$PARSED" | cut -f3)
fi

if [ -z "$NEW_URL_X86" ] || [ -z "$NEW_URL_ARM" ]; then
    echo "Warning: [onlyoffice] Could not find Linux amd64 / arm64 deb packages in latest release, skipping."
    exit 0
fi

# 3. 读取当前 sources.json 中的 URL
CURRENT_URL_X86=""
CURRENT_URL_ARM=""
if [ -f "$NPINS_DIR/sources.json" ]; then
    if command -v jq &>/dev/null; then
        CURRENT_URL_X86=$(jq -r '.pins["onlyoffice-x86_64"].url // empty' "$NPINS_DIR/sources.json" 2>/dev/null || true)
        CURRENT_URL_ARM=$(jq -r '.pins["onlyoffice-aarch64"].url // empty' "$NPINS_DIR/sources.json" 2>/dev/null || true)
    elif command -v python3 &>/dev/null; then
        CURRENT_URL_X86=$(python3 -c "
import json
try:
    with open('$NPINS_DIR/sources.json') as f:
        data = json.load(f)
    print(data.get('pins', {}).get('onlyoffice-x86_64', {}).get('url', ''))
except Exception:
    pass
" 2>/dev/null || true)
        CURRENT_URL_ARM=$(python3 -c "
import json
try:
    with open('$NPINS_DIR/sources.json') as f:
        data = json.load(f)
    print(data.get('pins', {}).get('onlyoffice-aarch64', {}).get('url', ''))
except Exception:
    pass
" 2>/dev/null || true)
    fi
fi

# 4. 比较并执行更新
if [ "$CURRENT_URL_X86" == "$NEW_URL_X86" ] && [ "$CURRENT_URL_ARM" == "$NEW_URL_ARM" ]; then
    echo "[onlyoffice] Up to date: $LATEST_VERSION (x86_64 & aarch64)"
else
    echo "[onlyoffice] New version detected: $LATEST_VERSION"
    echo "[onlyoffice] Updating x86_64: $NEW_URL_X86"
    echo "[onlyoffice] Updating aarch64: $NEW_URL_ARM"

    for url in "$NEW_URL_X86" "$NEW_URL_ARM"; do
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -A "Mozilla/5.0" "$url" || true)
        if [ "$HTTP_CODE" -ne 200 ] && [ "$HTTP_CODE" -ne 302 ]; then
            echo "Warning: [onlyoffice] Target URL returned HTTP $HTTP_CODE, skipping update: $url"
            exit 0
        fi
    done

    if [ "$DRY_RUN" -eq 1 ]; then
        echo "[onlyoffice] (dry-run) Would update onlyoffice-x86_64 to: $NEW_URL_X86"
        echo "[onlyoffice] (dry-run) Would update onlyoffice-aarch64 to: $NEW_URL_ARM"
    else
        echo "[onlyoffice] Updating npins for onlyoffice-x86_64 and onlyoffice-aarch64..."
        run_npins -d "$NPINS_DIR" add url --name onlyoffice-x86_64 "$NEW_URL_X86"
        run_npins -d "$NPINS_DIR" add url --name onlyoffice-aarch64 "$NEW_URL_ARM"
    fi
fi
