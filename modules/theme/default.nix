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

  # 全局主题切换 Hook 脚本（部署到 XDG_DATA_DIRS/darkman/）
  themeSwitchScript = pkgs.writeShellScript "theme-switch" ''
    #!/usr/bin/env bash
    set -euo pipefail

    MODE="''${1:-dark}"
    RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    THEME_DIR="$RUNTIME_DIR/desktop-theme"

    # ── 1. 建立运行时主题状态目录 ─────────────────────────────────────────
    mkdir -p "$THEME_DIR"
    echo "$MODE" > "$THEME_DIR/mode"

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

    # ── 3. 写入宿主机 GTK 配置文件 ────────────────────────────────────────
    GTK3_DIR="''${XDG_CONFIG_HOME:-$HOME/.config}/gtk-3.0"
    GTK4_DIR="''${XDG_CONFIG_HOME:-$HOME/.config}/gtk-4.0"
    mkdir -p "$GTK3_DIR" "$GTK4_DIR"

    GTK_SETTINGS_CONTENT="[Settings]
gtk-theme-name=$GTK_THEME
gtk-icon-theme-name=$ICON_THEME
gtk-cursor-theme-name=$CURSOR_NAME
gtk-cursor-theme-size=$CURSOR_SIZE
gtk-application-prefer-dark-theme=$([ "$MODE" = "dark" ] && echo 1 || echo 0)
"
    printf '%s' "$GTK_SETTINGS_CONTENT" > "$GTK3_DIR/settings.ini"
    printf '%s' "$GTK_SETTINGS_CONTENT" > "$GTK4_DIR/settings.ini"

    # 同时写入 $THEME_DIR 供沙箱共享
    printf '%s' "$GTK_SETTINGS_CONTENT" > "$THEME_DIR/gtk-settings.ini"

    # ── 4. 通过 dconf 广播主题变更（GSettings 标准接口）─────────────────
    if command -v dconf >/dev/null 2>&1; then
      dconf write /org/gnome/desktop/interface/color-scheme "$DCONF_COLOR_SCHEME" 2>/dev/null || true
      dconf write /org/gnome/desktop/interface/gtk-theme "'$GTK_THEME'" 2>/dev/null || true
      dconf write /org/gnome/desktop/interface/icon-theme "'$ICON_THEME'" 2>/dev/null || true
      dconf write /org/gnome/desktop/interface/cursor-theme "'$CURSOR_NAME'" 2>/dev/null || true
      dconf write /org/gnome/desktop/interface/cursor-size "$CURSOR_SIZE" 2>/dev/null || true
    fi

    # 同时通过 gsettings 广播（兼容没有 dconf 但有 GSettings 的应用）
    if command -v gsettings >/dev/null 2>&1; then
      gsettings set org.gnome.desktop.interface color-scheme "$COLOR_SCHEME" 2>/dev/null || true
      gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME" 2>/dev/null || true
      gsettings set org.gnome.desktop.interface icon-theme "$ICON_THEME" 2>/dev/null || true
      gsettings set org.gnome.desktop.interface cursor-theme "$CURSOR_NAME" 2>/dev/null || true
      gsettings set org.gnome.desktop.interface cursor-size "$CURSOR_SIZE" 2>/dev/null || true
    fi

    # ── 5. 刷新 Niri 合成器主题配置（动态颜色注入）─────────────────────
    NIRI_THEME_DIR="$RUNTIME_DIR/niri"
    mkdir -p "$NIRI_THEME_DIR"
    cat > "$NIRI_THEME_DIR/theme.kdl" <<EOF
layout {
    focus-ring {
        width ${toString cfg.layout.focusRing.width}
        active-color "$NIRI_FOCUS_ACTIVE"
        inactive-color "$NIRI_INACTIVE"
    }
    border {
        active-color "$NIRI_BORDER_ACTIVE"
        inactive-color "$NIRI_INACTIVE"
    }
}
EOF
    # 通知 niri 重载配置（若 niri 当前正在运行）
    if command -v niri >/dev/null 2>&1; then
      NIRI_CONFIG_DIR="''${XDG_CONFIG_HOME:-$HOME/.config}/niri"
      NIRI_SYSTEM_CONFIG="/etc/xdg/niri/config.kdl"
      if [ -f "$NIRI_CONFIG_DIR/config.kdl" ]; then
        niri msg action load-config-file --path "$NIRI_CONFIG_DIR/config.kdl" >/dev/null 2>&1 || true
      elif [ -f "$NIRI_SYSTEM_CONFIG" ]; then
        niri msg action load-config-file --path "$NIRI_SYSTEM_CONFIG" >/dev/null 2>&1 || true
      fi
    fi

    # ── 6. 刷新 Waybar（SIGUSR2 热重载样式表）────────────────────────────
    if command -v pkill >/dev/null 2>&1; then
      pkill -SIGUSR2 waybar 2>/dev/null || true
    fi

    # ── 7. 刷新 SwayNC 通知中心样式 ─────────────────────────────────────
    if command -v swaync-client >/dev/null 2>&1; then
      swaync-client --reload-css 2>/dev/null || true
    fi

    # ── 8. 壁纸切换 ────────────────────────────────────────────────────
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

    # ── 9. 用户自定义附加 Hook ──────────────────────────────────────────
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
      echo "  status          显示当前主题状态（模式、GTK 主题、日出/日落时间）"
      echo "  set dark        强制切换为深色模式"
      echo "  set light       强制切换为浅色模式"
      echo "  auto            切换为根据太阳起落自适应模式"
      echo "  toggle          翻转当前主题（快捷键绑定用）"
    }

    get_current_mode() {
      if [ -f "$THEME_STATE" ]; then
        cat "$THEME_STATE"
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
          echo "GTK 配置:"
          grep -E "^gtk-theme-name|^gtk-icon-theme-name" "$RUNTIME_DIR/desktop-theme/gtk-settings.ini" 2>/dev/null | sed 's/^/  /' || true
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
      ];

      # 2. 全局会话环境变量
      environment.sessionVariables = {
        XCURSOR_THEME = cfg.cursor.name;
        XCURSOR_SIZE = toString cfg.cursor.size;
      };

      # 3. 部署 Darkman 配置文件（/etc/xdg/darkman/config.yaml 供系统级用户共享）
      environment.etc."xdg/darkman/config.yaml".text = darkmanConfig;

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
        after = [ "graphical-session.target" ];
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
          XDG_CONFIG_DIRS = "/etc/xdg";
          XDG_DATA_DIRS = "/etc/xdg";
        };
      };

      # 6. 确保 dconf 服务可以被 Darkman Hook 调用
      programs.dconf.enable = mkDefault true;
    }

    (optionalAttrs (options ? home-manager) {
      home-manager = mkIf cfg.homeManager.enable {
        sharedModules = [
          ({ ... }: {
            home.packages = optionals cfg.icons.enable [
              cfg.icons.package
              pkgs.hicolor-icon-theme
            ];

            gtk = mkIf cfg.icons.enable {
              enable = true;
              iconTheme = {
                name = cfg.icons.name;
                package = cfg.icons.package;
              };
            };
          })
        ];
      };
    })
  ]);
}
