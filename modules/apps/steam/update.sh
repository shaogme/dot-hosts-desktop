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

# 1. 获取 Valve Steam 官方稳定归档源目录
REPO_BASE_URL="https://repo.steampowered.com/steam/archive/stable/"
INDEX_HTML=$(curl -sSL --compressed "$REPO_BASE_URL" 2>/dev/null || true)
if [ -z "$INDEX_HTML" ]; then
    echo "Warning: [steam] Failed to fetch upstream repository index from $REPO_BASE_URL, skipping."
    exit 0
fi

# 2. 从官方归档目录中解析最新的稳定版本号
LATEST_VERSION=""
if command -v python3 &>/dev/null; then
    LATEST_VERSION=$(python3 -c "
import sys, re
html = sys.stdin.read()
versions = re.findall(r'steam-launcher_([0-9.]+)_amd64\.deb', html)
if not versions:
    versions = re.findall(r'steam-launcher_([0-9.]+)_all\.deb', html)
if versions:
    def parse_ver(v):
        return [int(x) if x.isdigit() else x for x in v.split('.')]
    versions.sort(key=parse_ver)
    print(versions[-1])
" <<< "$INDEX_HTML" 2>/dev/null || true)
fi

if [ -z "$LATEST_VERSION" ]; then
    LATEST_VERSION=$(echo "$INDEX_HTML" | grep -oE 'steam-launcher_[0-9.]+_amd64\.deb' | sed -E 's/steam-launcher_([0-9.]+)_amd64\.deb/\1/' | sort -V | tail -n 1 || true)
fi

if [ -z "$LATEST_VERSION" ]; then
    echo "Warning: [steam] Could not parse latest version from repository index, skipping."
    exit 0
fi

NEW_LAUNCHER_URL="${REPO_BASE_URL}steam-launcher_${LATEST_VERSION}_amd64.deb"
NEW_LIBS_AMD64_URL="${REPO_BASE_URL}steam-libs-amd64_${LATEST_VERSION}_amd64.deb"
NEW_LIBS_I386_URL="${REPO_BASE_URL}steam-libs-i386_${LATEST_VERSION}_i386.deb"

# 3. 读取当前 sources.json 中的 URL
CURRENT_LAUNCHER_URL=""
CURRENT_LIBS_AMD64_URL=""
CURRENT_LIBS_I386_URL=""
if [ -f "$NPINS_DIR/sources.json" ]; then
    if command -v jq &>/dev/null; then
        CURRENT_LAUNCHER_URL=$(jq -r '.pins["steam"].url // empty' "$NPINS_DIR/sources.json" 2>/dev/null || true)
        CURRENT_LIBS_AMD64_URL=$(jq -r '.pins["steam-libs-amd64"].url // empty' "$NPINS_DIR/sources.json" 2>/dev/null || true)
        CURRENT_LIBS_I386_URL=$(jq -r '.pins["steam-libs-i386"].url // empty' "$NPINS_DIR/sources.json" 2>/dev/null || true)
    elif command -v python3 &>/dev/null; then
        CURRENT_LAUNCHER_URL=$(python3 -c "
import json
try:
    with open('$NPINS_DIR/sources.json') as f:
        data = json.load(f)
    print(data.get('pins', {}).get('steam', {}).get('url', ''))
except Exception:
    pass
" 2>/dev/null || true)
        CURRENT_LIBS_AMD64_URL=$(python3 -c "
import json
try:
    with open('$NPINS_DIR/sources.json') as f:
        data = json.load(f)
    print(data.get('pins', {}).get('steam-libs-amd64', {}).get('url', ''))
except Exception:
    pass
" 2>/dev/null || true)
        CURRENT_LIBS_I386_URL=$(python3 -c "
import json
try:
    with open('$NPINS_DIR/sources.json') as f:
        data = json.load(f)
    print(data.get('pins', {}).get('steam-libs-i386', {}).get('url', ''))
except Exception:
    pass
" 2>/dev/null || true)
    fi
fi

# 4. 对比并执行更新
if [ "$CURRENT_LAUNCHER_URL" == "$NEW_LAUNCHER_URL" ] && \
   [ "$CURRENT_LIBS_AMD64_URL" == "$NEW_LIBS_AMD64_URL" ] && \
   [ "$CURRENT_LIBS_I386_URL" == "$NEW_LIBS_I386_URL" ]; then
    echo "[steam] Up to date: $LATEST_VERSION ($CURRENT_LAUNCHER_URL)"
else
    echo "[steam] New version detected: $LATEST_VERSION"
    echo "[steam] Current launcher URL:   ${CURRENT_LAUNCHER_URL:-none}"
    echo "[steam] Target launcher URL:    $NEW_LAUNCHER_URL"
    echo "[steam] Target libs amd64 URL:  $NEW_LIBS_AMD64_URL"
    echo "[steam] Target libs i386 URL:   $NEW_LIBS_I386_URL"

    # 验证目标链接有效性
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -A "Mozilla/5.0" "$NEW_LAUNCHER_URL" || true)
    if [ "$HTTP_CODE" -ne 200 ] && [ "$HTTP_CODE" -ne 302 ]; then
        echo "Warning: [steam] Target launcher URL returned HTTP $HTTP_CODE, skipping update."
        exit 0
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        echo "[steam] (dry-run) Would update steam to: $NEW_LAUNCHER_URL"
        echo "[steam] (dry-run) Would update steam-libs-amd64 to: $NEW_LIBS_AMD64_URL"
        echo "[steam] (dry-run) Would update steam-libs-i386 to: $NEW_LIBS_I386_URL"
    else
        echo "[steam] Updating npins to: $NEW_LAUNCHER_URL"
        run_npins -d "$NPINS_DIR" add url --name steam "$NEW_LAUNCHER_URL"
        run_npins -d "$NPINS_DIR" add url --name steam-libs-amd64 "$NEW_LIBS_AMD64_URL"
        run_npins -d "$NPINS_DIR" add url --name steam-libs-i386 "$NEW_LIBS_I386_URL"
    fi
fi
