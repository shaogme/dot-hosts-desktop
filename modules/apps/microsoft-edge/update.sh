#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NPINS_DIR="$SCRIPT_DIR/npins"

DRY_RUN=0
for arg in "$@"; do
    if [[ "$arg" == "-n" || "$arg" == "--dry-run" ]]; then
        DRY_RUN=1
    fi
done

# 1. 从微软官方 Edge 软件源拉取最新应用元数据 (APT Packages.gz)
BASE_URL="https://packages.microsoft.com/repos/edge"
PACKAGES_URL="${BASE_URL}/dists/stable/main/binary-amd64/Packages.gz"

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

HTTP_CODE=$(curl -sSL -w "%{http_code}" "$PACKAGES_URL" -o "$TEMP_DIR/Packages.gz" 2>/dev/null || true)
if [ "$HTTP_CODE" != "200" ] && [ "$HTTP_CODE" != "304" ] || [ ! -s "$TEMP_DIR/Packages.gz" ]; then
    echo "Warning: [microsoft-edge] Failed to fetch Edge repository Packages.gz (HTTP: $HTTP_CODE), skipping upstream check."
    exit 0
fi

# 2. 解析 microsoft-edge-stable 的最新版本、相对路径和 SHA256
PKG_INFO=$(gzip -dc "$TEMP_DIR/Packages.gz" 2>/dev/null | awk '
/^Package: microsoft-edge-stable$/ { pkg = "microsoft-edge-stable"; ver = ""; file = ""; sha = "" }
/^Package:/ && !/^Package: microsoft-edge-stable$/ { pkg = "" }
pkg && /^Version:/ { ver = $2 }
pkg && /^Filename:/ { file = $2 }
pkg && /^SHA256:/ { sha = $2 }
/^$/ && pkg && ver && file && sha {
    print ver " " file " " sha
    pkg = ""
}
' | sort -k1 -V | tail -n 1 || true)

if [ -z "$PKG_INFO" ]; then
    echo "Warning: [microsoft-edge] Could not find 'microsoft-edge-stable' in package index, skipping upstream check."
    exit 0
fi

LATEST_VERSION=$(echo "$PKG_INFO" | awk '{print $1}')
FILENAME=$(echo "$PKG_INFO" | awk '{print $2}')
SHA256_HEX=$(echo "$PKG_INFO" | awk '{print $3}')

NEW_URL="${BASE_URL}/${FILENAME}"

# 3. 将 SHA256 转换为 Nix SRI Hash 格式
NEW_HASH=""
if command -v nix &>/dev/null; then
    NEW_HASH=$(nix hash convert --hash-algo sha256 --to sri "$SHA256_HEX" 2>/dev/null || true)
fi
if [ -z "$NEW_HASH" ] && command -v python3 &>/dev/null; then
    NEW_HASH=$(python3 -c "import base64, sys; print('sha256-' + base64.b64encode(bytes.fromhex(sys.argv[1])).decode('utf-8'))" "$SHA256_HEX" 2>/dev/null || true)
fi

if [ -z "$NEW_HASH" ]; then
    echo "Error: [microsoft-edge] Failed to convert SHA256 to SRI hash." >&2
    exit 1
fi

# 4. 获取当前 sources.json 中的 URL 与 Hash
CURRENT_URL=""
CURRENT_HASH=""
if [ -f "$NPINS_DIR/sources.json" ]; then
    if command -v jq &>/dev/null; then
        CURRENT_URL=$(jq -r '.pins["microsoft-edge"].url // empty' "$NPINS_DIR/sources.json" 2>/dev/null || true)
        CURRENT_HASH=$(jq -r '.pins["microsoft-edge"].hash // empty' "$NPINS_DIR/sources.json" 2>/dev/null || true)
    elif command -v python3 &>/dev/null; then
        CURRENT_URL=$(python3 -c "import json; data=json.load(open('$NPINS_DIR/sources.json')); print(data.get('pins',{}).get('microsoft-edge',{}).get('url',''))" 2>/dev/null || true)
        CURRENT_HASH=$(python3 -c "import json; data=json.load(open('$NPINS_DIR/sources.json')); print(data.get('pins',{}).get('microsoft-edge',{}).get('hash',''))" 2>/dev/null || true)
    fi
fi

if [ "$CURRENT_URL" == "$NEW_URL" ] && [ "$CURRENT_HASH" == "$NEW_HASH" ]; then
    echo "[microsoft-edge] Up to date: $LATEST_VERSION (hash: $CURRENT_HASH)"
else
    echo "[microsoft-edge] New version detected: $LATEST_VERSION (current: ${CURRENT_URL:-none})"
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "[microsoft-edge] (dry-run) Would update to: $NEW_URL"
        echo "[microsoft-edge] (dry-run) New hash: $NEW_HASH"
    else
        echo "[microsoft-edge] Updating npins to: $NEW_URL"
        if command -v python3 &>/dev/null; then
            python3 -c "
import json
src_file = '$NPINS_DIR/sources.json'
try:
    with open(src_file, 'r') as f:
        data = json.load(f)
except Exception:
    data = {'pins': {}, 'version': 8}

data.setdefault('pins', {})['microsoft-edge'] = {
    'type': 'Url',
    'url': '$NEW_URL',
    'unpack': False,
    'hash': '$NEW_HASH'
}
data['version'] = 8

with open(src_file, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
"
        elif command -v jq &>/dev/null; then
            TMP_JSON=$(mktemp)
            jq --arg url "$NEW_URL" --arg hash "$NEW_HASH" \
               '.pins["microsoft-edge"] = {"type": "Url", "url": $url, "unpack": false, "hash": $hash}' \
               "$NPINS_DIR/sources.json" > "$TMP_JSON"
            mv "$TMP_JSON" "$NPINS_DIR/sources.json"
        fi
    fi
fi
