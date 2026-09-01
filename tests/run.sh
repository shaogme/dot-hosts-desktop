#!/usr/bin/env bash
set -e

# 定义 Binary Cache 参数
CACHE_Substituters="https://cache.nixos.org https://attic.xuyh0120.win/lantian"
CACHE_TrustedPublicKeys="cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="

# 获取脚本所在目录及仓库根目录
TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$TESTS_DIR/.." && pwd)"

# 若本地存在 dot-base / dot-exts 源码目录，自动覆盖 npins 避免开发测试时指向远端旧 commit
if [ -d "$REPO_DIR/dot-base" ] && [ -z "${NPINS_OVERRIDE_dot_base:-}" ]; then
  export NPINS_OVERRIDE_dot_base="$REPO_DIR/dot-base"
fi
if [ -d "$REPO_DIR/dot-exts" ] && [ -z "${NPINS_OVERRIDE_dot_exts:-}" ]; then
  export NPINS_OVERRIDE_dot_exts="$REPO_DIR/dot-exts"
fi

# 自动检测支持的主机列表（使用 .github/scripts/get-hosts.sh）
HOSTS_JSON=$(bash "$REPO_DIR/.github/scripts/get-hosts.sh")
HOST_LIST=()
if command -v jq &>/dev/null; then
    while IFS= read -r host; do
        [ -n "$host" ] && HOST_LIST+=("$host")
    done < <(echo "$HOSTS_JSON" | jq -r '.[]')
elif command -v python3 &>/dev/null; then
    while IFS= read -r host; do
        [ -n "$host" ] && HOST_LIST+=("$host")
    done < <(python3 -c "import json, sys; [print(h) for h in json.loads(sys.argv[1])]" "$HOSTS_JSON")
fi

print_help() {
  echo "统一主机测试工具"
  echo "用法: $0 [host-name | host-path | all]"
  echo ""
  echo "可用的主机选项:"
  for h in "${HOST_LIST[@]}"; do
    echo "  - $h"
  done
  echo "  - all          (运行所有主机的全部测试)"
}

run_test_for_host() {
  local target_host=$1
  echo "============================================"
  echo "正在测试主机: $target_host"
  echo "============================================"
  
  echo ""
  echo "[1/2] 正在运行静态配置检查..."
  nix-build "$TESTS_DIR" -A "\"$target_host\".staticCheck"
  echo "静态检查通过。"
  
  echo ""
  echo "[2/2] 正在运行虚拟机集成测试..."
  echo "使用 Binary Caches 加速虚拟机测试构建:"
  echo "  - https://attic.xuyh0120.win/lantian"
  
  nix-build "$TESTS_DIR" -A "\"$target_host\".vmTest" \
    --option substituters "$CACHE_Substituters" \
    --option trusted-public-keys "$CACHE_TrustedPublicKeys"
    
  echo ""
  echo "============================================"
  echo "主机 $target_host 所有测试成功通过！"
  echo "============================================"
}

TARGET=${1:-all}

if [ "$TARGET" = "help" ] || [ "$TARGET" = "-h" ] || [ "$TARGET" = "--help" ]; then
  print_help
  exit 0
fi

if [ "$TARGET" = "all" ]; then
  for h in "${HOST_LIST[@]}"; do
    run_test_for_host "$h"
  done
  echo "============================================"
  echo "恭喜！所有主机的静态和虚拟机测试均已成功通过！"
  echo "============================================"
else
  MATCHED_HOST=""
  for h in "${HOST_LIST[@]}"; do
    base_h=$(basename "$h")
    if [ "$h" = "$TARGET" ] || [ "$base_h" = "$TARGET" ]; then
      MATCHED_HOST="$h"
      break
    fi
  done
  
  if [ -n "$MATCHED_HOST" ]; then
    run_test_for_host "$MATCHED_HOST"
  else
    echo "错误: 未知的主机名称或路径 '$TARGET'"
    echo ""
    print_help
    exit 1
  fi
fi
