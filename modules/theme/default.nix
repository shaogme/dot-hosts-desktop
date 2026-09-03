{
  config,
  pkgs,
  lib,
  options,
  ...
}:

with lib;

let
  cfg = config.desktop.theme;

  # 生成 darkman 配置文件内容
  darkmanConfig = ''
    lat: ${toString cfg.solar.latitude}
    lng: ${toString cfg.solar.longitude}
    usegeoclue: ${if cfg.solar.useGeoclue then "true" else "false"}
    portal: true
  '';

  # ── 同步脚本：将 runtime SSOT 同步到宿主机可变配置 ──
  # 设计：Hook 仅写 $RUNTIME_DIR/desktop-theme/*（SSOT），本脚本负责把
  # runtime 的 gtk-settings.ini 拷贝到 $XDG_CONFIG_HOME/gtk-{3,4}.0/settings.ini。
  # 自愈：若 runtime 缺失则内联播种。
  themeSyncScriptBin = pkgs.writeShellScriptBin "theme-sync-apply" ''
    #!/usr/bin/env bash
    set -uo pipefail

    RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    THEME_DIR="$RUNTIME_DIR/desktop-theme"
    SRC="$THEME_DIR/gtk-settings.ini"

    if [ -d "$SRC" ]; then
      echo "[theme-sync] error: $SRC is a directory." >&2
      exit 0
    fi
    if [ -e "$THEME_DIR" ] && [ ! -d "$THEME_DIR" ]; then
      echo "[theme-sync] error: $THEME_DIR exists but not a directory" >&2
      exit 0
    fi

    if [ ! -f "$SRC" ]; then
      echo "[theme-sync] SRC missing, seeding inline..." >&2
      SEED_MODE=""
      if command -v darkman >/dev/null 2>&1; then
        SEED_MODE="$(darkman get 2>&1 || true)"
      fi
      if [ "$SEED_MODE" != "dark" ] && [ "$SEED_MODE" != "light" ]; then
        GTK_HOST="''${XDG_CONFIG_HOME:-$HOME/.config}/gtk-3.0/settings.ini"
        if [ -f "$GTK_HOST" ] && grep -q "gtk-theme-name.*-dark" "$GTK_HOST" 2>&1; then
          SEED_MODE="dark"
        elif [ -f "$GTK_HOST" ] && grep -q "gtk-application-prefer-dark-theme=1" "$GTK_HOST" 2>&1; then
          SEED_MODE="dark"
        elif [ -f "$GTK_HOST" ] && grep -q "gtk-theme-name" "$GTK_HOST" 2>&1; then
          SEED_MODE="light"
        else
          SEED_MODE="${if cfg.mode != "auto" then cfg.mode else "dark"}"
        fi
      fi
      # 边界：非法值兜底
      if [ "$SEED_MODE" != "dark" ] && [ "$SEED_MODE" != "light" ]; then
        SEED_MODE="dark"
      fi
      mkdir -p "$THEME_DIR" 2>/dev/null || {
        echo "[theme-sync] error: failed to create $THEME_DIR" >&2
        exit 0
      }
      echo "$SEED_MODE" > "$THEME_DIR/mode" 2>/dev/null || echo "[theme-sync] warn: failed to write mode" >&2
      if [ "$SEED_MODE" = "dark" ]; then
        GTK_THEME="${cfg.dark.gtkTheme}"
        ICON_THEME="${cfg.dark.iconTheme}"
        CURSOR_NAME="${cfg.dark.cursor.name}"
        CURSOR_SIZE="${toString cfg.dark.cursor.size}"
        PREF_DARK=1
      else
        GTK_THEME="${cfg.light.gtkTheme}"
        ICON_THEME="${cfg.light.iconTheme}"
        CURSOR_NAME="${cfg.light.cursor.name}"
        CURSOR_SIZE="${toString cfg.light.cursor.size}"
        PREF_DARK=0
      fi
      GTK_SETTINGS_CONTENT="[Settings]
gtk-theme-name=$GTK_THEME
gtk-icon-theme-name=$ICON_THEME
gtk-cursor-theme-name=$CURSOR_NAME
gtk-cursor-theme-size=$CURSOR_SIZE
gtk-application-prefer-dark-theme=$PREF_DARK
"
      if ! printf '%s' "$GTK_SETTINGS_CONTENT" | ${pkgs.coreutils}/bin/install -Dm644 /dev/stdin "$SRC" 2>/dev/null; then
        if ! printf '%s' "$GTK_SETTINGS_CONTENT" > "$SRC" 2>/dev/null; then
          echo "[theme-sync] error: failed to seed $SRC" >&2
          exit 0
        fi
      fi
      if [ ! -f "$SRC" ]; then
        echo "[theme-sync] error: inline seeding failed, $SRC still missing" >&2
        exit 0
      fi
      echo "[theme-sync] seeded runtime with mode=$SEED_MODE" >&2
    fi

    # 同步到宿主机（幂等：内容相同时跳过，避免频繁触发）
    for ver in "3.0" "4.0"; do
      DST="''${XDG_CONFIG_HOME:-$HOME/.config}/gtk-$ver/settings.ini"
      if [ -f "$DST" ] && diff -q "$SRC" "$DST" >/dev/null 2>&1; then
        continue
      fi
      if [ -d "$DST" ]; then
        echo "[theme-sync] error: $DST is a directory, skipping" >&2
        continue
      fi
      mkdir -p "$(dirname "$DST")" 2>/dev/null || true
      if ! ${pkgs.coreutils}/bin/install -Dm644 "$SRC" "$DST" 2>/dev/null; then
        ${pkgs.coreutils}/bin/cp -f "$SRC" "$DST" 2>/dev/null || echo "[theme-sync] warn: failed to sync $SRC -> $DST" >&2
      fi
    done
  '';
  themeSyncScript = "${themeSyncScriptBin}/bin/theme-sync-apply";

  # 全局主题切换 Hook 脚本（部署到 XDG_DATA_DIRS/darkman/）
  # 架构：runtime 为 Single Source of Truth，Hook 仅写 runtime，同步由 theme-sync.service 完成
  themeSwitchScript = pkgs.writeShellScript "theme-switch" ''
    #!/usr/bin/env bash
    set -uo pipefail

    MODE="''${1:-dark}"
    # 边界：非法模式兜底为 dark，避免未定义行为
    if [ "$MODE" != "dark" ] && [ "$MODE" != "light" ]; then
      echo "[theme-switch] warn: invalid MODE=$MODE, fallback to dark" >&2
      MODE="dark"
    fi
    RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    THEME_DIR="$RUNTIME_DIR/desktop-theme"

    # 边界：THEME_DIR 若为文件而非目录
    if [ -e "$THEME_DIR" ] && [ ! -d "$THEME_DIR" ]; then
      echo "[theme-switch] error: $THEME_DIR is not a directory" >&2
      exit 0
    fi
    # 边界：gtk-settings.ini 若为目录而非文件
    if [ -d "$THEME_DIR/gtk-settings.ini" ]; then
      echo "[theme-switch] error: $THEME_DIR/gtk-settings.ini is a directory" >&2
      exit 0
    fi

    mkdir -p "$THEME_DIR" 2>/dev/null || {
      echo "[theme-switch] error: failed to create $THEME_DIR" >&2
      exit 0
    }
    echo "$MODE" > "$THEME_DIR/mode" 2>/dev/null || echo "[theme-switch] warn: failed to write mode" >&2

    # ── 2. 选取当前模式的主题变量 ─────────────────────────────────────────
    if [ "$MODE" = "dark" ]; then
      GTK_THEME="${cfg.dark.gtkTheme}"
      ICON_THEME="${cfg.dark.iconTheme}"
      CURSOR_NAME="${cfg.dark.cursor.name}"
      CURSOR_SIZE="${toString cfg.dark.cursor.size}"
      NIRI_FOCUS_ACTIVE="${cfg.dark.niri.focusRingActiveColor}"
      NIRI_BORDER_ACTIVE="${cfg.dark.niri.borderActiveColor}"
      NIRI_INACTIVE="${cfg.dark.niri.inactiveColor}"
      COLOR_SCHEME="prefer-dark"
      DCONF_COLOR_SCHEME="'prefer-dark'"
    else
      GTK_THEME="${cfg.light.gtkTheme}"
      ICON_THEME="${cfg.light.iconTheme}"
      CURSOR_NAME="${cfg.light.cursor.name}"
      CURSOR_SIZE="${toString cfg.light.cursor.size}"
      NIRI_FOCUS_ACTIVE="${cfg.light.niri.focusRingActiveColor}"
      NIRI_BORDER_ACTIVE="${cfg.light.niri.borderActiveColor}"
      NIRI_INACTIVE="${cfg.light.niri.inactiveColor}"
      COLOR_SCHEME="prefer-light"
      DCONF_COLOR_SCHEME="'prefer-light'"
    fi

    # ── 3. 写入运行时 SSOT ──────────────────────────────────────────────
    GTK_SETTINGS_CONTENT="[Settings]
gtk-theme-name=$GTK_THEME
gtk-icon-theme-name=$ICON_THEME
gtk-cursor-theme-name=$CURSOR_NAME
gtk-cursor-theme-size=$CURSOR_SIZE
gtk-application-prefer-dark-theme=$([ "$MODE" = "dark" ] && echo 1 || echo 0)
"
    if ! printf '%s' "$GTK_SETTINGS_CONTENT" | ${pkgs.coreutils}/bin/install -Dm644 /dev/stdin "$THEME_DIR/gtk-settings.ini" 2>/dev/null; then
      printf '%s' "$GTK_SETTINGS_CONTENT" > "$THEME_DIR/gtk-settings.ini" 2>/dev/null || echo "[theme-switch] error: failed to write gtk-settings.ini" >&2
    fi

    # 触发同步服务（异步，避免与 theme-sync 互调导致 fork 炸弹）
    if command -v systemctl >/dev/null 2>&1; then
      systemctl --user start --no-block theme-sync.service 2>/dev/null || true
    fi

    # ── 4. 通过 dconf/gsettings 广播 ───────────────────────────────────
    if command -v dconf >/dev/null 2>&1; then
      dconf write /org/gnome/desktop/interface/color-scheme "$DCONF_COLOR_SCHEME" 2>/dev/null || true
      dconf write /org/gnome/desktop/interface/gtk-theme "'$GTK_THEME'" 2>/dev/null || true
      dconf write /org/gnome/desktop/interface/icon-theme "'$ICON_THEME'" 2>/dev/null || true
      dconf write /org/gnome/desktop/interface/cursor-theme "'$CURSOR_NAME'" 2>/dev/null || true
      dconf write /org/gnome/desktop/interface/cursor-size "$CURSOR_SIZE" 2>/dev/null || true
    fi
    if command -v gsettings >/dev/null 2>&1; then
      gsettings set org.gnome.desktop.interface color-scheme "$COLOR_SCHEME" 2>/dev/null || true
      gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME" 2>/dev/null || true
      gsettings set org.gnome.desktop.interface icon-theme "$ICON_THEME" 2>/dev/null || true
      gsettings set org.gnome.desktop.interface cursor-theme "$CURSOR_NAME" 2>/dev/null || true
      gsettings set org.gnome.desktop.interface cursor-size "$CURSOR_SIZE" 2>/dev/null || true
    fi

    # ── 5. 刷新 Niri 合成器主题配置 ───────────────────────────────────
    NIRI_THEME_DIR="$RUNTIME_DIR/niri"
    if [ -e "$NIRI_THEME_DIR" ] && [ ! -d "$NIRI_THEME_DIR" ]; then
      echo "[theme-switch] warn: $NIRI_THEME_DIR is not a directory" >&2
    else
      mkdir -p "$NIRI_THEME_DIR" 2>/dev/null || true
      NIRI_THEME_CONTENT="layout {
    focus-ring {
        width ${toString cfg.layout.focusRing.width}
        active-color \"$NIRI_FOCUS_ACTIVE\"
        inactive-color \"$NIRI_INACTIVE\"
    }
    border {
        active-color \"$NIRI_BORDER_ACTIVE\"
        inactive-color \"$NIRI_INACTIVE\"
    }
}
"
      if ! printf '%s' "$NIRI_THEME_CONTENT" | ${pkgs.coreutils}/bin/install -Dm644 /dev/stdin "$NIRI_THEME_DIR/theme.kdl" 2>/dev/null; then
        printf '%s' "$NIRI_THEME_CONTENT" > "$NIRI_THEME_DIR/theme.kdl" 2>/dev/null || echo "[theme-switch] warn: failed to write niri theme" >&2
      fi
      if command -v niri >/dev/null 2>&1; then
        NIRI_CONFIG_DIR="''${XDG_CONFIG_HOME:-$HOME/.config}/niri"
        NIRI_SYSTEM_CONFIG="/etc/xdg/niri/config.kdl"
        if [ -f "$NIRI_CONFIG_DIR/config.kdl" ]; then
          niri msg action load-config-file --path "$NIRI_CONFIG_DIR/config.kdl" 2>/dev/null || true
        elif [ -f "$NIRI_SYSTEM_CONFIG" ]; then
          niri msg action load-config-file --path "$NIRI_SYSTEM_CONFIG" 2>/dev/null || true
        fi
      fi
    fi

    # ── 6. 刷新 Waybar ────────────────────────────────────────────────
    if command -v pkill >/dev/null 2>&1; then
      pkill -SIGUSR2 waybar 2>/dev/null || true
    fi

    # ── 7. 刷新 SwayNC ───────────────────────────────────────────────
    if command -v swaync-client >/dev/null 2>&1; then
      swaync-client --reload-css 2>/dev/null || true
    fi

    # ── 8. 壁纸切换 ──────────────────────────────────────────────────
    ${optionalString (cfg.dark.wallpaper != null || cfg.light.wallpaper != null) ''
      WALLPAPER_PATH=""
      if [ "$MODE" = "dark" ]; then
        WALLPAPER_PATH="${toString (if cfg.dark.wallpaper != null then cfg.dark.wallpaper else "")}"
      else
        WALLPAPER_PATH="${toString (if cfg.light.wallpaper != null then cfg.light.wallpaper else "")}"
      fi
      if [ -n "$WALLPAPER_PATH" ] && [ -f "$WALLPAPER_PATH" ] && command -v awww-set >/dev/null 2>&1; then
        awww-set "$WALLPAPER_PATH" 2>/dev/null || true
      fi
    ''}

    # ── 9. 用户自定义附加 Hook ─────────────────────────────────────
    ${cfg.extraSwitchHooks}
  '';


  # theme-ctl 控制脚本
  themeCtlScript = pkgs.writeShellScriptBin "theme-ctl" ''
    #!/usr/bin/env bash
    set -euo pipefail

    RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    THEME_STATE="$RUNTIME_DIR/desktop-theme/mode"

    usage() {
      echo "用法: theme-ctl <status|set dark|set light|auto|toggle>"
      echo ""
      echo "命令:"
      echo "  status          显示当前主题状态"
      echo "  set dark        强制切换为深色模式"
      echo "  set light       强制切换为浅色模式"
      echo "  auto            切换为根据太阳起落自适应模式"
      echo "  toggle          翻转当前主题"
    }

    get_current_mode() {
      if [ -f "$THEME_STATE" ]; then
        local m; m="$(cat "$THEME_STATE" 2>/dev/null | tr -d '
' | tr -d ' ')"
        if [ "$m" = "dark" ] || [ "$m" = "light" ]; then
          echo "$m"
        else
          echo "dark"
        fi
      elif command -v darkman >/dev/null 2>&1; then
        darkman get 2>/dev/null || echo "unknown"
      else
        echo "unknown"
      fi
    }

    case "''${1:-}" in
      status)
        MODE=$(get_current_mode)
        echo "当前模式: $MODE"
        if command -v darkman >/dev/null 2>&1; then
          echo "Darkman 模式: $(darkman get 2>/dev/null || echo '未运行')"
        fi
        if [ -f "$RUNTIME_DIR/desktop-theme/gtk-settings.ini" ]; then
          echo "GTK 配置 (runtime SSOT):"
          grep -E "^gtk-theme-name|^gtk-icon-theme-name" "$RUNTIME_DIR/desktop-theme/gtk-settings.ini" 2>/dev/null | sed 's/^/  /' || true
          echo "  运行时文件: $RUNTIME_DIR/desktop-theme/gtk-settings.ini"
        elif [ -f "$RUNTIME_DIR/desktop-theme/mode" ]; then
          echo "GTK 配置: (runtime 部分初始化: mode=$MODE 但 gtk-settings.ini 缺失)"
          echo "  运行时文件: $RUNTIME_DIR/desktop-theme/gtk-settings.ini (缺失)"
          echo "  建议: 运行 theme-ctl set $MODE 或 systemctl --user restart theme-seed.service"
        else
          echo "GTK 配置: (runtime 未初始化)"
        fi
        GTK3_HOST="''${XDG_CONFIG_HOME:-$HOME/.config}/gtk-3.0/settings.ini"
        GTK4_HOST="''${XDG_CONFIG_HOME:-$HOME/.config}/gtk-4.0/settings.ini"
        if [ -L "$GTK3_HOST" ]; then
          echo "宿主机 GTK3: symlink -> $(readlink "$GTK3_HOST") (将被 theme-sync 替换)"
        elif [ -f "$GTK3_HOST" ]; then
          echo "宿主机 GTK3: $(grep -E "^gtk-theme-name" "$GTK3_HOST" 2>/dev/null | head -1 | sed 's/^/  /')"
        else
          echo "宿主机 GTK3: 未找到 ($GTK3_HOST)"
        fi
        if [ -L "$GTK4_HOST" ]; then
          echo "宿主机 GTK4: symlink -> $(readlink "$GTK4_HOST")"
        elif [ -f "$GTK4_HOST" ]; then
          echo "宿主机 GTK4: $(grep -E "^gtk-theme-name" "$GTK4_HOST" 2>/dev/null | head -1 | sed 's/^/  /')"
        else
          echo "宿主机 GTK4: 未找到 ($GTK4_HOST)"
        fi
        if command -v systemctl >/dev/null 2>&1; then
          echo "theme-sync 服务: $(systemctl --user is-active theme-sync.service 2>/dev/null || echo 'inactive')"
          echo "theme-seed 服务: $(systemctl --user is-active theme-seed.service 2>/dev/null || echo 'inactive')"
        fi
        if command -v darkman >/dev/null 2>&1 && systemctl --user is-active darkman.service >/dev/null 2>&1; then
          echo "darkman 服务: active (running)"
          darkman get 2>&1 | sed 's/^/  /' || true
        else
          echo "darkman 服务: $(systemctl --user is-active darkman.service 2>/dev/null || echo 'inactive')"
        fi
        if [ ! -f "$RUNTIME_DIR/desktop-theme/gtk-settings.ini" ]; then
          if [ -d "$RUNTIME_DIR/desktop-theme/gtk-settings.ini" ]; then
            echo "  诊断: gtk-settings.ini 为目录（历史遗留），请执行: rmdir \"$RUNTIME_DIR/desktop-theme/gtk-settings.ini\" && systemctl --user restart theme-seed.service"
          fi
          echo "  建议: theme-ctl set $MODE"
        fi
        ;;
      set)
        TARGET_MODE="''${2:-}"
        if [ "$TARGET_MODE" != "dark" ] && [ "$TARGET_MODE" != "light" ]; then
          echo "错误: 必须指定 dark 或 light" >&2
          usage
          exit 1
        fi
        if command -v darkman >/dev/null 2>&1; then
          darkman set "$TARGET_MODE"
        else
          ${themeSwitchScript} "$TARGET_MODE"
        fi
        ;;
      auto)
        echo "切换为自动日出/日落模式..."
        if command -v systemctl >/dev/null 2>&1; then
          systemctl --user restart darkman.service 2>/dev/null || true
        fi
        echo "已恢复为自动自适应模式（需要 darkman.service 正常运行）"
        ;;
      toggle)
        CURRENT=$(get_current_mode)
        if [ "$CURRENT" != "dark" ] && [ "$CURRENT" != "light" ]; then
          CURRENT="light"
        fi
        if [ "$CURRENT" = "dark" ]; then
          NEW_MODE="light"
        else
          NEW_MODE="dark"
        fi
        if command -v darkman >/dev/null 2>&1; then
          darkman set "$NEW_MODE"
        else
          ${themeSwitchScript} "$NEW_MODE"
        fi
        ;;
      *)
        usage
        exit 1
        ;;
    esac
  '';


in
{
  options.desktop.theme = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "是否启用全局浅色/深色主题控制中枢与视觉管理。";
    };

    mode = mkOption {
      type = types.enum [ "auto" "dark" "light" ];
      default = "auto";
      description = ''
        全局主题运行模式：
        - "auto": 默认根据日出日落时间自动在浅色与深色之间切换；
        - "dark": 强制锁定深色模式；
        - "light": 强制锁定浅色模式。
      '';
    };

    solar = {
      latitude = mkOption {
        type = types.float;
        default = 31.2304;
        description = "日出日落计算纬度（度数）。";
      };
      longitude = mkOption {
        type = types.float;
        default = 121.4737;
        description = "日出日落计算经度（度数）。";
      };
      useGeoclue = mkOption {
        type = types.bool;
        default = false;
        description = "是否启用 GeoClue 动态获取当前地理位置。";
      };
    };

    icons = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否启用并配置桌面与 GTK 图标主题（如 Adwaita、hicolor-icon-theme）。";
      };

      package = mkPackageOption pkgs "adwaita-icon-theme" { };

      name = mkOption {
        type = types.str;
        default = "Adwaita";
        description = "默认图标主题名称（静态，不随深浅色切换变化）。";
      };
    };

    cursor = {
      name = mkOption {
        type = types.str;
        default = "Adwaita";
        description = "默认光标主题名称（静态，不随深浅色切换变化）。";
      };

      size = mkOption {
        type = types.int;
        default = 24;
        description = "默认光标尺寸大小。";
      };
    };

    # 用于 Niri 焦点环宽度（切换时使用）
    layout = {
      focusRing = {
        width = mkOption {
          type = types.int;
          default = 4;
          description = "焦点环宽度（逻辑像素），在主题切换 KDL 片段中使用。";
        };
      };
    };

    dark = {
      gtkTheme = mkOption {
        type = types.str;
        default = "Adwaita-dark";
        description = "深色模式下的 GTK 主题名称。";
      };
      iconTheme = mkOption {
        type = types.str;
        default = "Adwaita";
        description = "深色模式下的图标主题名称。";
      };
      cursor = {
        name = mkOption { type = types.str; default = "Adwaita"; description = "深色模式下的光标主题名称。"; };
        size = mkOption { type = types.int; default = 24; description = "深色模式下的光标尺寸。"; };
      };
      niri = {
        focusRingActiveColor = mkOption { type = types.str; default = "#7fc8ff"; description = "深色模式下 Niri 焦点环活动颜色。"; };
        borderActiveColor = mkOption { type = types.str; default = "#ffc87f"; description = "深色模式下 Niri 边框活动颜色。"; };
        inactiveColor = mkOption { type = types.str; default = "#505050"; description = "深色模式下 Niri 非活动颜色。"; };
      };
      wallpaper = mkOption {
        type = types.nullOr (types.either types.path types.str);
        default = null;
        description = "深色模式下展示的桌面壁纸图片路径。";
      };
    };

    light = {
      gtkTheme = mkOption {
        type = types.str;
        default = "Adwaita";
        description = "浅色模式下的 GTK 主题名称。";
      };
      iconTheme = mkOption {
        type = types.str;
        default = "Adwaita";
        description = "浅色模式下的图标主题名称。";
      };
      cursor = {
        name = mkOption { type = types.str; default = "Adwaita"; description = "浅色模式下的光标主题名称。"; };
        size = mkOption { type = types.int; default = 24; description = "浅色模式下的光标尺寸。"; };
      };
      niri = {
        focusRingActiveColor = mkOption { type = types.str; default = "#1e66f5"; description = "浅色模式下 Niri 焦点环活动颜色。"; };
        borderActiveColor = mkOption { type = types.str; default = "#df8e1d"; description = "浅色模式下 Niri 边框活动颜色。"; };
        inactiveColor = mkOption { type = types.str; default = "#9ca0b0"; description = "浅色模式下 Niri 非活动颜色。"; };
      };
      wallpaper = mkOption {
        type = types.nullOr (types.either types.path types.str);
        default = null;
        description = "浅色模式下展示的桌面壁纸图片路径。";
      };
    };

    extraSwitchHooks = mkOption {
      type = types.lines;
      default = "";
      description = "主题切换时执行的附加 Bash 脚本片段（可接收参数 \$1 为 dark 或 light）。";
    };

    homeManager = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "若系统中启用了 Home Manager，是否自动将主题配置注入到所有 Home Manager 用户中。";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      # 1. 基础系统软件包
      environment.systemPackages = optionals cfg.icons.enable [
        cfg.icons.package
        pkgs.hicolor-icon-theme
      ] ++ [
        pkgs.darkman
        themeCtlScript
        pkgs.dconf
        themeSyncScriptBin
      ];

      # 2. 全局会话环境变量
      environment.sessionVariables = {
        XCURSOR_THEME = cfg.cursor.name;
        XCURSOR_SIZE = toString cfg.cursor.size;
      };

      # 3. 部署 Darkman 配置文件（/etc/darkman/config.yaml 供系统级用户共享）
      environment.etc."darkman/config.yaml".text = darkmanConfig;

      # 4. 部署主题切换钩子脚本到 XDG_DATA_DIRS
      #    Darkman 会自动搜索 $XDG_DATA_DIRS/darkman/ 下的可执行文件
      environment.etc."xdg/darkman/theme-switch.sh" = {
        source = themeSwitchScript;
        mode = "0755";
      };

      # 5. Systemd 用户服务：Darkman 守护进程
      systemd.user.services.darkman = {
        description = "Framework for dark-mode and light-mode transitions (Darkman)";
        documentation = [ "man:darkman(1)" ];
        partOf = [ "graphical-session.target" ];
        after = [ "graphical-session.target" "theme-seed.service" ];
        wantedBy = [ "graphical-session.target" ];
        unitConfig = {
          ConditionEnvironment = "WAYLAND_DISPLAY";
        };
        serviceConfig = {
          Type = "dbus";
          BusName = "nl.whynothugo.darkman";
          ExecStart = "${pkgs.darkman}/bin/darkman run";
          Restart = "on-failure";
          TimeoutStopSec = 15;
        } // optionalAttrs (cfg.mode != "auto") {
          ExecStartPost = "${pkgs.darkman}/bin/darkman set ${cfg.mode}";
        };
        environment = {
          XDG_CONFIG_DIRS = "/etc:/etc/xdg";
          XDG_DATA_DIRS = "/etc/xdg";
        };
      };

      # 5a. Systemd 用户服务：theme-seed 冷启动播种（SSOT 自愈，解决 No transition 时未初始化）
      systemd.user.services.theme-seed = {
        description = "Seed desktop-theme runtime SSOT if missing (cold-boot self-heal)";
        partOf = [ "graphical-session.target" ];
        after = [ "systemd-tmpfiles-setup.service" ];
        before = [ "darkman.service" ];
        wantedBy = [ "graphical-session.target" ];
        unitConfig = { };
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          RuntimeDirectory = "desktop-theme";
          RuntimeDirectoryMode = "0755";
          ExecCondition = "${pkgs.bash}/bin/bash -c '! test -f %t/desktop-theme/gtk-settings.ini'";
          ExecStart = "${pkgs.writeShellScript "theme-seed-apply" ''
            #!/usr/bin/env bash
            set -uo pipefail
            RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
            THEME_DIR="$RUNTIME_DIR/desktop-theme"
            SRC="$THEME_DIR/gtk-settings.ini"
            echo "[theme-seed] invoked RUNTIME_DIR=$RUNTIME_DIR SRC=$SRC" >&2
            if [ -f "$SRC" ]; then
              echo "[theme-seed] already exists, skip" >&2
              exit 0
            fi
            if [ -d "$SRC" ]; then
              echo "[theme-seed] error: $SRC is a directory" >&2
              exit 0
            fi
            if [ -e "$THEME_DIR" ] && [ ! -d "$THEME_DIR" ]; then
              echo "[theme-seed] error: $THEME_DIR is not a directory" >&2
              exit 0
            fi
            echo "[theme-seed] seeding runtime..." >&2
            SEED_MODE="${cfg.mode}"
            if [ "$SEED_MODE" = "auto" ]; then
              SEED_MODE="dark"
              if command -v darkman >/dev/null 2>&1; then
                DM="$(darkman get 2>&1 || true)"
                if [ "$DM" = "dark" ] || [ "$DM" = "light" ]; then SEED_MODE="$DM"; fi
              fi
              GTK_HOST="''${XDG_CONFIG_HOME:-$HOME/.config}/gtk-3.0/settings.ini"
              if [ -f "$GTK_HOST" ] && grep -q "gtk-theme-name.*-dark" "$GTK_HOST" 2>&1; then
                SEED_MODE="dark"
              fi
            fi
            SWITCH_RC=0
            if [ -x "/etc/xdg/darkman/theme-switch.sh" ]; then
              if "/etc/xdg/darkman/theme-switch.sh" "$SEED_MODE" 2>&1 | sed 's/^/[theme-seed] switch stderr: /' >&2; then
                :
              else
                SWITCH_RC=$?
                echo "[theme-seed] warn: theme-switch.sh failed rc=$SWITCH_RC" >&2
              fi
            else
              if "${themeSwitchScript}" "$SEED_MODE" 2>&1 | sed 's/^/[theme-seed] switch-nix stderr: /' >&2; then
                :
              else
                SWITCH_RC=$?
                echo "[theme-seed] warn: nix switch script failed rc=$SWITCH_RC" >&2
              fi
            fi
            if [ -f "$SRC" ]; then
              echo "[theme-seed] seeded successfully" >&2
              if command -v systemctl >/dev/null 2>&1; then
                if systemctl --user start --no-block theme-sync.service 2>&1 | sed 's/^/[theme-seed] systemctl stderr: /' >&2; then
                  :
                else
                  echo "[theme-seed] warn: systemctl trigger failed rc=$?" >&2
                fi
              fi
            else
              echo "[theme-seed] error: seeding failed, $SRC still missing" >&2
            fi
          ''}";
        };
      };

      # 5b. Systemd tmpfiles：预建宿主机 GTK 配置目录
      systemd.user.tmpfiles.rules = [
        "d %h/.config/gtk-3.0 0755 - - -"
        "d %h/.config/gtk-4.0 0755 - - -"
      ];

      # 5c. Systemd 用户服务：theme-sync 同步服务（runtime SSOT → 宿主机可变配置）
      systemd.user.services.theme-sync = {
        description = "Synchronize GTK theme from runtime SSOT to user config";
        documentation = [ "man:theme-ctl(1)" ];
        partOf = [ "graphical-session.target" ];
        after = [ "graphical-session.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${themeSyncScript}";
          RemainAfterExit = false;
          RuntimeDirectory = "desktop-theme";
          RuntimeDirectoryMode = "0755";
        };
      };

      # 5d. Systemd path 监听：runtime 变化时自动触发同步
      systemd.user.paths.theme-sync = {
        description = "Watch runtime GTK theme for changes and trigger sync";
        wantedBy = [ "graphical-session.target" ];
        partOf = [ "graphical-session.target" ];
        unitConfig = {
          TriggerLimitIntervalSec = "2s";
          TriggerLimitBurst = 1;
        };
        pathConfig = {
          PathChanged = "%t/desktop-theme/gtk-settings.ini";
          Unit = "theme-sync.service";
        };
      };

      # 6. 确保 dconf 服务可以被 Darkman Hook 调用
      programs.dconf.enable = mkDefault true;
    }

    (optionalAttrs (options ? home-manager) {
      home-manager = mkIf cfg.homeManager.enable {
        sharedModules = [
          ({ config, lib, ... }: {
            home.packages = optionals cfg.icons.enable [
              cfg.icons.package
              pkgs.hicolor-icon-theme
            ];

            # HM 的 gtk 模块默认会生成指向 /nix/store 的只读 symlink
            # （xdg.configFile."gtk-3.0/settings.ini"），与 runtime SSOT 冲突导致 EROFS。
            # 此处禁用 HM 的 settings.ini 生成，改由 theme-sync.service 原子同步接管；
            # 图标包仍通过 home.packages 提供，主题内容由 darkman 驱动的 runtime 提供。
            gtk = mkIf cfg.icons.enable {
              enable = true;
              iconTheme = {
                name = cfg.icons.name;
                package = cfg.icons.package;
              };
            };

            # 覆盖 HM 生成的只读文件：强制不启用其 settings.ini，交由同步服务管理
            xdg.configFile."gtk-3.0/settings.ini".enable = lib.mkForce false;
            xdg.configFile."gtk-4.0/settings.ini".enable = lib.mkForce false;

            # 登录时确保目录存在并通过 install 声明式填充
            # HM 已通过 xdg.configFile.enable=false 禁用 store symlink，
            # 此处仅通过 systemd.tmpfiles 的 "d" 保证目录，但为兼容首次激活仍显式 mkdir
            home.activation.themeGtkCleanup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
              ${pkgs.coreutils}/bin/mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0" 2>/dev/null || true
              # 若 runtime 已存在，则通过 install 声明式填充
              if [ -f "''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/desktop-theme/gtk-settings.ini" ]; then
                ${pkgs.coreutils}/bin/install -Dm644 "''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/desktop-theme/gtk-settings.ini" "$HOME/.config/gtk-3.0/settings.ini" 2>/dev/null || true
                ${pkgs.coreutils}/bin/install -Dm644 "''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/desktop-theme/gtk-settings.ini" "$HOME/.config/gtk-4.0/settings.ini" 2>/dev/null || true
              fi
            '';
          })
        ];
      };
    })
  ]);
}
