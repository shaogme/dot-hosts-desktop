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

# 从 QQ 官网官方 Rainbow 配置接口拉取最新 Linux 发布信息
CONFIG_JSON=$(curl -sSL "https://qq-web.cdn-go.cn/im.qq.com_new/latest/rainbow/pcConfig.json" || true)
if [ -z "$CONFIG_JSON" ]; then
    echo "Warning: [qq] Failed to fetch Tencent rainbow pcConfig.json API, skipping upstream check."
    exit 0
fi

NEW_URL=""
LATEST_VERSION=""
if command -v jq &>/dev/null; then
    NEW_URL=$(echo "$CONFIG_JSON" | jq -r '.Linux.x64DownloadUrl.deb // empty')
    LATEST_VERSION=$(echo "$CONFIG_JSON" | jq -r '.Linux.version // empty')
elif command -v python3 &>/dev/null; then
    NEW_URL=$(python3 -c "import json, sys; data=json.loads(sys.argv[1]); print(data.get('Linux',{}).get('x64DownloadUrl',{}).get('deb',''))" "$CONFIG_JSON" 2>/dev/null || true)
    LATEST_VERSION=$(python3 -c "import json, sys; data=json.loads(sys.argv[1]); print(data.get('Linux',{}).get('version',''))" "$CONFIG_JSON" 2>/dev/null || true)
fi

CURRENT_URL=""
CURRENT_HASH=""
if [ -f "$NPINS_DIR/sources.json" ]; then
    if command -v jq &>/dev/null; then
        CURRENT_URL=$(jq -r '.pins.qq.url // empty' "$NPINS_DIR/sources.json" 2>/dev/null || true)
        CURRENT_HASH=$(jq -r '.pins.qq.hash // empty' "$NPINS_DIR/sources.json" 2>/dev/null || true)
    elif command -v python3 &>/dev/null; then
        CURRENT_URL=$(python3 -c "import json; data=json.load(open('$NPINS_DIR/sources.json')); print(data.get('pins',{}).get('qq',{}).get('url',''))" 2>/dev/null || true)
        CURRENT_HASH=$(python3 -c "import json; data=json.load(open('$NPINS_DIR/sources.json')); print(data.get('pins',{}).get('qq',{}).get('hash',''))" 2>/dev/null || true)
    fi
fi

if [ -n "$NEW_URL" ] && [ "$CURRENT_URL" != "$NEW_URL" ]; then
    # 验证新 URL 是否可正常访问
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -A "Mozilla/5.0" "$NEW_URL" || true)
    if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 302 ]; then
        echo "[qq] New version detected: $LATEST_VERSION (current: ${CURRENT_URL:-none})"
        if [ "$DRY_RUN" -eq 1 ]; then
            echo "[qq] (dry-run) Would update to: $NEW_URL"
        else
            echo "[qq] Updating npins to: $NEW_URL"
            run_npins -d "$NPINS_DIR" add url --name qq "$NEW_URL"
        fi
        exit 0
    fi
fi

echo "[qq] Up to date (url: $CURRENT_URL, hash: $CURRENT_HASH)"
