{
  config,
  pkgs,
  lib,
  options,
  ...
}:

with lib;

let
  cfg = config.desktop.clipboard.cliphist;

  # 基础公共参数构造 (严格对应 cliphist CLI 支持参数，彻底移除无效的 max-store-size)
  commonArgs = [
    "-max-items"
    (toString cfg.storage.maxItems)
    "-max-dedupe-search"
    (toString cfg.storage.maxDedupeSearch)
    "-min-store-length"
    (toString cfg.storage.minStoreLength)
    "-preview-width"
    (toString cfg.storage.previewWidth)
  ]
  ++ (optional (cfg.storage.dbPath != null) "-db-path")
  ++ (optional (cfg.storage.dbPath != null) cfg.storage.dbPath)
  ++ cfg.storage.extraArgs;

  allArgsStr = escapeShellArgs commonArgs;

  # 静态配置文本写入
  cliphistConfigText =
    let
      attrsText = concatStringsSep "\n" (mapAttrsToList (k: v: "${k} ${toString v}") cfg.settings);
    in
    concatStringsSep "\n" (filter (s: s != "") [
      attrsText
      cfg.extraConfig
    ]);

  thumbDirStr =
    if cfg.selector.thumbnailDir != null then
      cfg.selector.thumbnailDir
    else
      "";

  # 交互式剪贴板历史选择工具：支持富媒体缩略图预览协议及快捷键删除/清空
  cliphistPickScript = pkgs.writeShellScriptBin "cliphist-pick" ''
    set -euo pipefail

    SELECTOR="''${1:-${cfg.selector.command}}"
    if [ -z "$SELECTOR" ]; then
      echo "错误: 未配置剪贴板选择器交互前端命令 (desktop.clipboard.cliphist.selector.command)" >&2
      exit 1
    fi

    THUMB_DIR="${thumbDirStr}"
    if [ -z "$THUMB_DIR" ]; then
      THUMB_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/cliphist/thumbnails"
    fi

    PREVIEW_THUMBNAILS="${if cfg.selector.previewThumbnails then "1" else "0"}"

    list_items() {
      if [ "$PREVIEW_THUMBNAILS" = "1" ]; then
        mkdir -p "$THUMB_DIR"
        ${getExe cfg.package} ${allArgsStr} list | ${pkgs.gawk}/bin/awk -v thumb_dir="$THUMB_DIR" -v cliphist_bin="${getExe cfg.package}" -v all_args="${allArgsStr}" '
        BEGIN { FS = "\t"; }
        {
          id = $1;
          rest = substr($0, index($0, "\t") + 1);
          if (match(rest, /^\[\[ binary data .* ([a-zA-Z0-9_-]+) \]\]$/, arr)) {
            ext = arr[1];
            thumb = thumb_dir "/" id "." ext;
            cmd = "test -s \"" thumb "\" || " cliphist_bin " " all_args " decode " id " > \"" thumb "\" 2>/dev/null";
            system(cmd);
            printf "%s\t%s\0icon\x1f%s\n", id, rest, thumb;
          } else {
            print $0;
          }
        }'
      else
        ${getExe cfg.package} ${allArgsStr} list
      fi
    }

    set +e
    ITEM=$(list_items | eval "$SELECTOR")
    EXIT_CODE=$?
    set -e

    # 用户取消退出 (Esc / Ctrl+C)
    if [ "$EXIT_CODE" -eq 1 ] || [ "$EXIT_CODE" -eq 130 ]; then
      exit 0
    fi

    # 快捷删除条目 (Exit Code 10 / Alt+1 / custom-1)
    if [ "$EXIT_CODE" -eq 10 ]; then
      if [ -n "$ITEM" ]; then
        ID=$(printf '%s' "$ITEM" | awk -F'\t' '{print $1}' | tr -d '\0')
        if [ -n "$ID" ]; then
          printf '%s\n' "$ID" | ${getExe cfg.package} ${allArgsStr} delete
          rm -f "$THUMB_DIR/$ID".*
        fi
      fi
      exit 0
    fi

    # 快捷清空历史 (Exit Code 19 / Alt+0 / custom-10)
    if [ "$EXIT_CODE" -eq 19 ]; then
      ${getExe cfg.package} ${allArgsStr} wipe
      rm -rf "$THUMB_DIR"/*
      exit 0
    fi

    # 正常选中 (Exit Code 0)
    if [ "$EXIT_CODE" -eq 0 ] && [ -n "$ITEM" ]; then
      ID=$(printf '%s' "$ITEM" | awk -F'\t' '{print $1}' | tr -d '\0')
      if [ -n "$ID" ]; then
        if printf '%s' "$ITEM" | grep -q '\[\[ binary data '; then
          ext=$(printf '%s' "$ITEM" | sed -n 's/.*\[\[ binary data [^]]* \([a-zA-Z0-9_-]\+\) \]\]/\1/p')
          case "$ext" in
            png) mime="image/png" ;;
            jpg|jpeg) mime="image/jpeg" ;;
            webp) mime="image/webp" ;;
            gif) mime="image/gif" ;;
            svg) mime="image/svg+xml" ;;
            *) mime="application/octet-stream" ;;
          esac
          ${getExe cfg.package} ${allArgsStr} decode "$ID" | ${getExe' cfg.clipboardPackage "wl-copy"} --type "$mime"
        else
          ${getExe cfg.package} ${allArgsStr} decode "$ID" | ${getExe' cfg.clipboardPackage "wl-copy"}
        fi
      fi
    fi
  '';

  # 交互式与命令行批量条目删除工具
  cliphistDeleteScript = pkgs.writeShellScriptBin "cliphist-delete" ''
    set -euo pipefail

    THUMB_DIR="${thumbDirStr}"
    if [ -z "$THUMB_DIR" ]; then
      THUMB_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/cliphist/thumbnails"
    fi

    if [ "''${1:-}" = "--query" ] || [ "''${1:-}" = "-q" ]; then
      if [ -z "''${2:-}" ]; then
        echo "用法: cliphist-delete --query <pattern>" >&2
        exit 1
      fi
      QUERY="$2"
      MATCHING_IDS=$(${getExe cfg.package} ${allArgsStr} list | grep -F "$QUERY" | awk -F'\t' '{print $1}' || true)
      ${getExe cfg.package} ${allArgsStr} delete-query "$QUERY"
      for id in $MATCHING_IDS; do
        rm -f "$THUMB_DIR/$id".*
      done
      echo "已删除匹配 \"$QUERY\" 的条目及缩略图缓存。"
      exit 0
    fi

    SELECTOR="''${1:-${cfg.selector.command}}"
    if [ -z "$SELECTOR" ]; then
      echo "错误: 未配置剪贴板选择器交互前端命令 (desktop.clipboard.cliphist.selector.command)" >&2
      exit 1
    fi

    ITEM=$(${getExe cfg.package} ${allArgsStr} list | eval "$SELECTOR") || exit 0
    if [ -n "$ITEM" ]; then
      ID=$(printf '%s' "$ITEM" | awk -F'\t' '{print $1}' | tr -d '\0')
      if [ -n "$ID" ]; then
        printf '%s\n' "$ID" | ${getExe cfg.package} ${allArgsStr} delete
        rm -f "$THUMB_DIR/$ID".*
        echo "已删除条目: $ID"
      fi
    fi
  '';

  # 剪贴板历史安全清空工具（带二次确认与 -f 强制模式）
  cliphistWipeScript = pkgs.writeShellScriptBin "cliphist-wipe" ''
    set -euo pipefail

    THUMB_DIR="${thumbDirStr}"
    if [ -z "$THUMB_DIR" ]; then
      THUMB_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/cliphist/thumbnails"
    fi

    FORCE=0
    for arg in "$@"; do
      if [ "$arg" = "-f" ] || [ "$arg" = "--force" ]; then
        FORCE=1
      fi
    done

    if [ "$FORCE" -eq 1 ]; then
      ${getExe cfg.package} ${allArgsStr} wipe
      rm -rf "$THUMB_DIR"/*
      echo "剪贴板历史及缩略图缓存已彻底清空。"
      exit 0
    fi

    printf "确定要清空全部剪贴板历史与缩略图缓存吗？ [y/N]: "
    read -r ans
    case "$ans" in
      [yY]|[yY][eE][sS])
        ${getExe cfg.package} ${allArgsStr} wipe
        rm -rf "$THUMB_DIR"/*
        echo "剪贴板历史及缩略图缓存已清空。"
        ;;
      *)
        echo "操作已取消。"
        exit 0
        ;;
    esac
  '';

  # 剪贴板历史统一运维工具（状态统计、数据库压缩整理、孤儿缩略图清理）
  cliphistManageScript = pkgs.writeShellScriptBin "cliphist-manage" ''
    set -euo pipefail

    THUMB_DIR="${thumbDirStr}"
    if [ -z "$THUMB_DIR" ]; then
      THUMB_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/cliphist/thumbnails"
    fi

    DB_PATH="${if cfg.storage.dbPath != null then cfg.storage.dbPath else ""}"
    if [ -z "$DB_PATH" ]; then
      DB_PATH="''${XDG_CACHE_HOME:-$HOME/.cache}/cliphist/db"
    fi

    CMD="''${1:-help}"

    case "$CMD" in
      stats)
        echo "=== Cliphist 存储状态统计 ==="
        TOTAL_ITEMS=$(${getExe cfg.package} ${allArgsStr} list 2>/dev/null | wc -l || echo 0)
        IMAGE_ITEMS=$(${getExe cfg.package} ${allArgsStr} list 2>/dev/null | grep -c '\[\[ binary data ' || true)
        TEXT_ITEMS=$((TOTAL_ITEMS - IMAGE_ITEMS))
        echo "历史条目总数: $TOTAL_ITEMS"
        echo "  - 文本条目数: $TEXT_ITEMS"
        echo "  - 图片条目数: $IMAGE_ITEMS"
        if [ -f "$DB_PATH" ]; then
          DB_SIZE=$(du -h "$DB_PATH" | awk '{print $1}')
          echo "数据库文件: $DB_PATH ($DB_SIZE)"
        else
          echo "数据库文件: 不存在或尚未创建 ($DB_PATH)"
        fi
        if [ -d "$THUMB_DIR" ]; then
          THUMB_COUNT=$(find "$THUMB_DIR" -type f 2>/dev/null | wc -l || echo 0)
          THUMB_SIZE=$(du -sh "$THUMB_DIR" 2>/dev/null | awk '{print $1}' || echo "0B")
          echo "缩略图缓存: $THUMB_DIR ($THUMB_COUNT 个文件, $THUMB_SIZE)"
        else
          echo "缩略图缓存目录: 未创建"
        fi
        ;;
      cache-clean)
        echo "=== 清理失效缩略图缓存 ==="
        if [ ! -d "$THUMB_DIR" ]; then
          echo "缩略图缓存目录不存在，无需清理。"
          exit 0
        fi
        EXISTING_IDS=$(${getExe cfg.package} ${allArgsStr} list 2>/dev/null | awk -F'\t' '{print $1}')
        CLEANED=0
        for f in "$THUMB_DIR"/*; do
          [ -f "$f" ] || continue
          fname=$(basename "$f")
          fid="''${fname%%.*}"
          if ! echo "$EXISTING_IDS" | grep -qx "$fid"; then
            rm -f "$f"
            CLEANED=$((CLEANED + 1))
          fi
        done
        echo "已清理 $CLEANED 个孤儿缩略图文件。"
        ;;
      compact)
        echo "=== 整理压缩 Cliphist 数据库 ==="
        if [ ! -f "$DB_PATH" ]; then
          echo "数据库文件不存在: $DB_PATH"
          exit 0
        fi
        TMP_DIR=$(mktemp -d)
        TMP_DB="$TMP_DIR/compacted_db"
        trap 'rm -rf "$TMP_DIR"' EXIT

        IDS=$(${getExe cfg.package} ${allArgsStr} list | awk -F'\t' '{print $1}' | sort -n)
        COUNT=0
        for id in $IDS; do
          ${getExe cfg.package} ${allArgsStr} decode "$id" | ${getExe cfg.package} -db-path "$TMP_DB" store
          COUNT=$((COUNT + 1))
        done

        if [ -f "$TMP_DB" ]; then
          OLD_SIZE=$(du -h "$DB_PATH" | awk '{print $1}')
          mv "$TMP_DB" "$DB_PATH"
          NEW_SIZE=$(du -h "$DB_PATH" | awk '{print $1}')
          echo "数据库压缩成功！已重新索引 $COUNT 个条目。"
          echo "体积变化: $OLD_SIZE -> $NEW_SIZE"
        else
          echo "压缩后数据库为空，保留原数据库。"
        fi
        ;;
      help|--help|-h)
        echo "Cliphist 统一运维工具"
        echo "用法: cliphist-manage <子命令>"
        echo ""
        echo "子命令:"
        echo "  stats        查看条目数、图片占比及数据库与缓存占用体积"
        echo "  compact      对底层 bbolt 数据库执行去碎片压缩整理"
        echo "  cache-clean  清理已不存在于历史中的孤儿缩略图文件"
        ;;
      *)
        echo "未知子命令: $CMD" >&2
        echo "运行 'cliphist-manage help' 查看帮助。" >&2
        exit 1
        ;;
    esac
  '';
in
{
  options.desktop.clipboard.cliphist = {
    enable = mkEnableOption "cliphist 现代化 Wayland 剪贴板历史管理服务与交互组件";

    package = mkPackageOption pkgs "cliphist" { };

    clipboardPackage = mkPackageOption pkgs "wl-clipboard" { };

    # ── 1. 存储与守护监听策略 (storage) ──────────────────────────────────
    storage = {
      text = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "是否自动监听并持久化常规文本剪贴板历史。";
        };
        mimeType = mkOption {
          type = types.str;
          default = "text";
          description = "wl-paste 监听的文本 MIME 筛选类型。";
        };
      };

      images = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "是否自动监听并持久化图片及二进制剪贴板历史。";
        };
        mimeType = mkOption {
          type = types.str;
          default = "image";
          description = "wl-paste 监听的图像 MIME 筛选类型。";
        };
      };

      primary = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "是否自动监听并持久化 Wayland Primary Selection (鼠标选中/中键) 剪贴板历史。";
        };
      };

      maxItems = mkOption {
        type = types.int;
        default = 1000;
        description = "剪贴板持久化存储的最大历史条目数 (-max-items)。";
      };

      maxDedupeSearch = mkOption {
        type = types.int;
        default = 100;
        description = "寻找重复项时向前比对的最大条目数 (-max-dedupe-search)。";
      };

      minStoreLength = mkOption {
        type = types.int;
        default = 0;
        description = "入库存储的最小文本字符数 (-min-store-length)。";
      };

      previewWidth = mkOption {
        type = types.int;
        default = 120;
        description = "列表预览展示的最大字符宽度 (-preview-width)。";
      };

      dbPath = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "自定义数据库存储绝对路径 (-db-path)。设为 null 时遵循 XDG 规范 (~/.cache/cliphist/db)。";
      };

      extraArgs = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "传递给 cliphist 守护进程与命令行的额外底层参数列表。";
      };
    };

    # ── 2. 交互式选择器配置 (selector) ──────────────────────────────────
    selector = {
      command = mkOption {
        type = types.str;
        default = "";
        description = "交互式选择器前端命令（如 dmenu 兼容程序，必须显式配置，禁止提供隐式 fallback）。";
      };

      keybind = mkOption {
        type = types.str;
        default = "";
        description = "在当前启用的窗口管理器 (如 Niri) 中自动注册唤起剪贴板选择器的全局快捷键绑定。";
      };

      previewThumbnails = mkOption {
        type = types.bool;
        default = true;
        description = "是否为图片剪贴板条目生成缓存缩略图，并通过 \\0icon\\x1f 协议注入选择器以实现富媒体图标预览。";
      };

      thumbnailDir = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "缩略图缓存绝对目录。设为 null 时默认使用 $XDG_CACHE_HOME/cliphist/thumbnails。";
      };
    };

    # ── 3. 配置文件生成与原生设置 (settings) ────────────────────────────
    settings = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "以属性集格式写入 /etc/xdg/cliphist/config 的键值对配置项 (基于 flagconf 空格分隔语法)。";
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = "追加写入 cliphist 原生配置文件尾部的纯文本。";
    };

    # ── 4. Systemd 守护进程生命周期 (systemd) ───────────────────────────
    systemd = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否通过 systemd 用户守护进程自动化管理剪贴板监听器。";
      };

      target = mkOption {
        type = types.str;
        default = "graphical-session.target";
        description = "绑定拉起守护进程的 systemd target。";
      };
    };

    # ── 5. Home Manager 同步配置 ─────────────────────────────────────────
    homeManager = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "若系统中启用了 Home Manager，是否自动同步相关软件包与配置文件。";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      assertions = [
        {
          assertion = cfg.selector.keybind != "" -> cfg.selector.command != "";
          message = "desktop.clipboard.cliphist: 配置了 selector.keybind 快捷键时，必须显式指定 selector.command 交互前端命令，禁止提供默认 fallback。";
        }
      ];

      # 1. 系统软件包安装：cliphist 主程序、wl-clipboard、xdg-utils 与配套交互管理脚本
      environment.systemPackages = [
        cfg.package
        cfg.clipboardPackage
        pkgs.gawk
        pkgs.xdg-utils
        cliphistPickScript
        cliphistDeleteScript
        cliphistWipeScript
        cliphistManageScript
      ];

      # 2. 系统级配置文件部署（若配置了 settings 或 extraConfig）
      environment.etc = mkIf (cliphistConfigText != "") {
        "xdg/cliphist/config".text = cliphistConfigText;
        "cliphist/config".text = cliphistConfigText;
      };

      # 3. systemd 用户守护进程：文本、图片及 Primary 剪贴板监听服务与沙箱加固
      systemd.user.services.cliphist = mkIf (cfg.systemd.enable && cfg.storage.text.enable) {
        description = "Cliphist clipboard history daemon (text)";
        documentation = [ "https://github.com/sentriz/cliphist" ];
        partOf = [ cfg.systemd.target ];
        after = [ cfg.systemd.target ];
        wantedBy = [ cfg.systemd.target ];
        unitConfig = {
          ConditionEnvironment = "WAYLAND_DISPLAY";
        };
        serviceConfig = {
          Type = "simple";
          ExecStart = "${getExe' cfg.clipboardPackage "wl-paste"} --type ${cfg.storage.text.mimeType} --watch ${getExe cfg.package} ${allArgsStr} store";
          Restart = "on-failure";
          RestartSec = "1s";
          Slice = "app-graphical.slice";
          ProtectSystem = "strict";
          ProtectHome = "read-only";
          ReadWritePaths = [ "%C/cliphist" ] ++ (optional (cfg.storage.dbPath != null) (dirOf cfg.storage.dbPath));
          PrivateTmp = true;
          NoNewPrivileges = true;
        };
      };

      systemd.user.services.cliphist-images = mkIf (cfg.systemd.enable && cfg.storage.images.enable) {
        description = "Cliphist clipboard history daemon (images)";
        documentation = [ "https://github.com/sentriz/cliphist" ];
        partOf = [ cfg.systemd.target ];
        after = [ cfg.systemd.target ];
        wantedBy = [ cfg.systemd.target ];
        unitConfig = {
          ConditionEnvironment = "WAYLAND_DISPLAY";
        };
        serviceConfig = {
          Type = "simple";
          ExecStart = "${getExe' cfg.clipboardPackage "wl-paste"} --type ${cfg.storage.images.mimeType} --watch ${getExe cfg.package} ${allArgsStr} store";
          Restart = "on-failure";
          RestartSec = "1s";
          Slice = "app-graphical.slice";
          ProtectSystem = "strict";
          ProtectHome = "read-only";
          ReadWritePaths = [ "%C/cliphist" ] ++ (optional (cfg.storage.dbPath != null) (dirOf cfg.storage.dbPath));
          PrivateTmp = true;
          NoNewPrivileges = true;
        };
      };

      systemd.user.services.cliphist-primary = mkIf (cfg.systemd.enable && cfg.storage.primary.enable) {
        description = "Cliphist clipboard history daemon (primary)";
        documentation = [ "https://github.com/sentriz/cliphist" ];
        partOf = [ cfg.systemd.target ];
        after = [ cfg.systemd.target ];
        wantedBy = [ cfg.systemd.target ];
        unitConfig = {
          ConditionEnvironment = "WAYLAND_DISPLAY";
        };
        serviceConfig = {
          Type = "simple";
          ExecStart = "${getExe' cfg.clipboardPackage "wl-paste"} --primary --watch ${getExe cfg.package} ${allArgsStr} store";
          Restart = "on-failure";
          RestartSec = "1s";
          Slice = "app-graphical.slice";
          ProtectSystem = "strict";
          ProtectHome = "read-only";
          ReadWritePaths = [ "%C/cliphist" ] ++ (optional (cfg.storage.dbPath != null) (dirOf cfg.storage.dbPath));
          PrivateTmp = true;
          NoNewPrivileges = true;
        };
      };

      # 4. 联动向 Niri 注册快捷键（若显式配置了 selector.keybind 且 Niri 启用）
      desktop.windowManager.niri = mkIf (config ? desktop && config.desktop ? windowManager && config.desktop.windowManager ? niri && config.desktop.windowManager.niri.enable && cfg.selector.keybind != "") {
        extraBinds = {
          "${cfg.selector.keybind}" = {
            _props.hotkey-overlay-title = "Clipboard History Selector";
            spawn-sh = [ "${cliphistPickScript}/bin/cliphist-pick" ];
          };
        };
      };
    }

    # 5. Home Manager 自动联动
    (optionalAttrs (options ? home-manager) {
      home-manager = mkIf cfg.homeManager.enable {
        sharedModules = [
          ({ ... }: {
            home.packages = [
              cfg.package
              cfg.clipboardPackage
              pkgs.gawk
              pkgs.xdg-utils
              cliphistPickScript
              cliphistDeleteScript
              cliphistWipeScript
              cliphistManageScript
            ];
            xdg.configFile = mkIf (cliphistConfigText != "") {
              "cliphist/config".text = cliphistConfigText;
            };
          })
        ];
      };
    })
  ]);
}
