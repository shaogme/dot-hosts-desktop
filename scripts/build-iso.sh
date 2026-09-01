#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Binary Cache 配置 (与 CI 及 tests/run.sh 保持一致)
# ==============================================================================
CACHE_SUBSTITUTERS="https://cache.nixos.org https://attic.xuyh0120.win/lantian"
CACHE_TRUSTED_PUBLIC_KEYS="cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="

# 获取脚本所在目录及仓库根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# ==============================================================================
# 自动检测可用主机列表（调用 .github/scripts/get-hosts.sh）
# ==============================================================================
get_available_hosts() {
    local hosts_json
    if [ -f "$REPO_DIR/.github/scripts/get-hosts.sh" ]; then
        hosts_json=$(bash "$REPO_DIR/.github/scripts/get-hosts.sh")
    else
        echo "Error: .github/scripts/get-hosts.sh not found!" >&2
        exit 1
    fi

    local -a hosts=()
    if command -v jq &>/dev/null; then
        while IFS= read -r host; do
            [ -n "$host" ] && hosts+=("$host")
        done < <(echo "$hosts_json" | jq -r '.[]')
    elif command -v python3 &>/dev/null; then
        while IFS= read -r host; do
            [ -n "$host" ] && hosts+=("$host")
        done < <(python3 -c "import json, sys; [print(h) for h in json.loads(sys.argv[1])]" "$hosts_json")
    else
        local clean_json
        clean_json=$(echo "$hosts_json" | tr -d '[]" ' | tr ',' '\n')
        while IFS= read -r host; do
            [ -n "$host" ] && hosts+=("$host")
        done <<< "$clean_json"
    fi
    printf '%s\n' "${hosts[@]}"
}

readarray -t AVAILABLE_HOSTS < <(get_available_hosts)

# ==============================================================================
# 帮助信息与用法
# ==============================================================================
print_help() {
    cat <<EOF
本地 NixOS ISO 自动化镜像构建工具

用法:
  $0 [选项] [主机名/路径...]

参数说明:
  [主机名/路径...]       指定要构建的一个或多个目标主机（如 'virtual-box' 或 'hosts/virtual-box'）。
                         若未指定或指定为 'all'，则依次构建所有可用主机。

选项:
  -h, --help             显示此帮助信息并退出
  -l, --list             列出当前仓库中所有可用的主机
  -o, --out-dir DIR      指定生成 result 软链接的输出目录（默认: 仓库根目录下的 result-iso/）
  --dry-run              评估构建并显示需要构建/下载的 Derivations，但不实际执行构建
  --no-cache             不使用预设的远程 Binary Cache (Substituters)
  --extra-args ARGS      向 nix-build 传递额外的参数（如 --extra-args "--show-trace -j 4"）

可用主机列表:
$(for h in "${AVAILABLE_HOSTS[@]}"; do echo "  - $(basename "$h")  ($h)"; done)

使用示例:
  $0                              # 依次构建所有主机的 ISO
  $0 all                          # 依次构建所有主机的 ISO
  $0 virtual-box                  # 仅构建 virtual-box 的 ISO
  $0 hosts/home-7950x             # 仅构建 home-7950x 的 ISO
  $0 virtual-box home-7950x       # 依次构建指定的多个主机
  $0 --dry-run virtual-box        # 仅干运行/评估 virtual-box 的构建依赖
  $0 -o ./my-isos virtual-box     # 构建 virtual-box 并输出软链接到 ./my-isos
EOF
}

# ==============================================================================
# 解析命令行参数
# ==============================================================================
OUT_DIR="$REPO_DIR/result-iso"
USE_CACHE=true
DRY_RUN=false
EXTRA_NIX_ARGS=()
SELECTED_HOSTS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help|help)
            print_help
            exit 0
            ;;
        -l|--list)
            echo "Available hosts:"
            for h in "${AVAILABLE_HOSTS[@]}"; do
                echo "  - $(basename "$h") ($h)"
            done
            exit 0
            ;;
        -o|--out-dir)
            if [[ -n "${2:-}" && "${2:0:1}" != "-" ]]; then
                OUT_DIR="$2"
                shift 2
            else
                echo "Error: Argument for $1 is missing." >&2
                exit 1
            fi
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --no-cache)
            USE_CACHE=false
            shift
            ;;
        --extra-args)
            if [[ -n "${2:-}" ]]; then
                read -r -a extra_flags <<< "$2"
                EXTRA_NIX_ARGS+=("${extra_flags[@]}")
                shift 2
            else
                echo "Error: Argument for $1 is missing." >&2
                exit 1
            fi
            ;;
        --show-trace|--keep-failed|--keep-going|--cores|--max-jobs|-j|--option)
            if [[ "$1" == "-j" || "$1" == "--cores" || "$1" == "--max-jobs" || "$1" == "--option" ]]; then
                EXTRA_NIX_ARGS+=("$1" "$2")
                shift 2
            else
                EXTRA_NIX_ARGS+=("$1")
                shift
            fi
            ;;
        -*)
            echo "Warning: Passing unrecognized option '$1' to nix-build." >&2
            EXTRA_NIX_ARGS+=("$1")
            shift
            ;;
        *)
            SELECTED_HOSTS+=("$1")
            shift
            ;;
    esac
done

# ==============================================================================
# 筛选目标主机
# ==============================================================================
TARGETS_TO_BUILD=()

if [ ${#SELECTED_HOSTS[@]} -eq 0 ] || [[ "${SELECTED_HOSTS[*]}" == *"all"* && ${#SELECTED_HOSTS[@]} -eq 1 ]]; then
    TARGETS_TO_BUILD=("${AVAILABLE_HOSTS[@]}")
else
    for sel in "${SELECTED_HOSTS[@]}"; do
        if [ "$sel" = "all" ]; then
            TARGETS_TO_BUILD=("${AVAILABLE_HOSTS[@]}")
            break
        fi
        matched=""
        for avail in "${AVAILABLE_HOSTS[@]}"; do
            base_avail=$(basename "$avail")
            if [ "$sel" = "$avail" ] || [ "$sel" = "$base_avail" ] || [ "$sel" = "./$avail" ]; then
                matched="$avail"
                break
            fi
        done
        if [ -n "$matched" ]; then
            # 去重添加
            if [[ ! " ${TARGETS_TO_BUILD[*]:-} " =~ [[:space:]]"${matched}"[[:space:]] ]]; then
                TARGETS_TO_BUILD+=("$matched")
            fi
        else
            echo "Error: Host '$sel' not found in available hosts." >&2
            echo "" >&2
            echo "Available hosts:" >&2
            for h in "${AVAILABLE_HOSTS[@]}"; do
                echo "  - $(basename "$h") ($h)" >&2
            done
            exit 1
        fi
    done
fi

if [ ${#TARGETS_TO_BUILD[@]} -eq 0 ]; then
    echo "No matching hosts found to build."
    exit 0
fi

# ==============================================================================
# 依次执行构建
# ==============================================================================
mkdir -p "$OUT_DIR"

echo "======================================================"
echo " NixOS Local ISO Builder"
echo "======================================================"
echo " Targets (${#TARGETS_TO_BUILD[@]}):"
for t in "${TARGETS_TO_BUILD[@]}"; do
    echo "   * $t"
done
echo " Output Directory: $OUT_DIR"
if [ "$DRY_RUN" = true ]; then
    echo " Mode: DRY-RUN (no actual build)"
fi
if [ "$USE_CACHE" = true ]; then
    echo " Binary Caches: Enabled"
else
    echo " Binary Caches: Disabled"
fi
echo "======================================================"
echo ""

START_TOTAL_TIME=$SECONDS
BUILT_ISOS=()

for idx in "${!TARGETS_TO_BUILD[@]}"; do
    target_host="${TARGETS_TO_BUILD[$idx]}"
    host_name="$(basename "$target_host")"
    step=$((idx + 1))
    total=${#TARGETS_TO_BUILD[@]}
    out_link="$OUT_DIR/result-$host_name"

    echo "------------------------------------------------------"
    echo "[$step/$total] Building ISO for host: $target_host ($host_name)"
    echo "  Out Link: $out_link"
    echo "------------------------------------------------------"

    BUILD_CMD=(
        nix-build "$REPO_DIR/.github/scripts/iso-builder.nix"
        --arg hostPath "./$target_host"
    )

    if [ "$DRY_RUN" = true ]; then
        BUILD_CMD+=(--dry-run)
    else
        BUILD_CMD+=(-o "$out_link")
    fi

    if [ "$USE_CACHE" = true ]; then
        BUILD_CMD+=(
            --option substituters "$CACHE_SUBSTITUTERS"
            --option trusted-public-keys "$CACHE_TRUSTED_PUBLIC_KEYS"
        )
    fi

    if [ ${#EXTRA_NIX_ARGS[@]} -gt 0 ]; then
        BUILD_CMD+=("${EXTRA_NIX_ARGS[@]}")
    fi

    HOST_START_TIME=$SECONDS
    (
        cd "$REPO_DIR"
        "${BUILD_CMD[@]}"
    )
    HOST_ELAPSED=$((SECONDS - HOST_START_TIME))

    if [ "$DRY_RUN" = true ]; then
        echo ">> Dry run evaluation finished for $host_name in ${HOST_ELAPSED}s"
        BUILT_ISOS+=("$host_name|dry-run|N/A|${HOST_ELAPSED}s")
    else
        # 寻找生成的 ISO 文件
        ISO_PATH=$(find -L "$out_link" -name "*.iso" 2>/dev/null | head -n 1 || true)
        if [ -n "$ISO_PATH" ] && [ -f "$ISO_PATH" ]; then
            ISO_SIZE=$(du -h "$ISO_PATH" | cut -f1)
            echo ">> Successfully built ISO for $host_name in ${HOST_ELAPSED}s"
            echo "   ISO file: $ISO_PATH ($ISO_SIZE)"
            BUILT_ISOS+=("$host_name|$ISO_PATH|$ISO_SIZE|${HOST_ELAPSED}s")
        else
            echo ">> Warning: ISO build finished for $host_name but .iso file not found in $out_link"
            BUILT_ISOS+=("$host_name|$out_link|Unknown|${HOST_ELAPSED}s")
        fi
    fi
    echo ""
done

TOTAL_ELAPSED=$((SECONDS - START_TOTAL_TIME))

echo "======================================================"
if [ "$DRY_RUN" = true ]; then
    echo " All dry-run evaluations completed in ${TOTAL_ELAPSED}s!"
else
    echo " All ISO builds completed successfully in ${TOTAL_ELAPSED}s!"
fi
echo "======================================================"
echo "Build Summary:"
printf "%-20s %-10s %-12s %s\n" "HOST" "DURATION" "SIZE" "OUTPUT"
printf "%-20s %-10s %-12s %s\n" "--------------------" "----------" "------------" "----------------------------------------"
for item in "${BUILT_ISOS[@]}"; do
    IFS="|" read -r h_name h_path h_size h_time <<< "$item"
    printf "%-20s %-10s %-12s %s\n" "$h_name" "$h_time" "$h_size" "$h_path"
done
echo "======================================================"
