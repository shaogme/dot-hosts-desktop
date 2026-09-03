{
  config,
  pkgs,
  lib,
  options,
  ...
}:

with lib;

let
  cfg = config.desktop.notification.swaync;
  paletteLib = import ../../theme/palette.nix { inherit lib; };
  paletteDark = (config.desktop.theme.palette.dark or paletteLib.palettes.dark);
  fallbackCss = paletteLib.toCss paletteDark;

  defaultSwayncSettings = {
    "$schema" = "/etc/xdg/swaync/configSchema.json";
    positionX = "right";
    positionY = "top";
    layer = "overlay";
    control-center-layer = "top";
    layer-shell = true;
    cssPriority = "user";
    control-center-margin-top = 10;
    control-center-margin-bottom = 10;
    control-center-margin-right = 10;
    control-center-margin-left = 10;
    notification-2fa-action = true;
    notification-inline-replies = true;
    notification-window-width = 400;
    control-center-width = 400;
    control-center-height = 600;
    timeout = 8;
    timeout-low = 4;
    timeout-critical = 0;
    fit-to-screen = true;
    relative-timestamps = true;
    keyboard-shortcuts = true;
    notification-grouping = true;
    image-visibility = "when-available";
    transition-time = 200;
    hide-on-clear = false;
    hide-on-action = true;
    text-empty = "没有新通知";
    widgets = [
      "inhibitors"
      "title"
      "dnd"
      "mpris"
      "notifications"
    ];
    widget-config = {
      inhibitors = {
        text = "应用抑制";
        button-text = "全部清除";
        clear-all-button = true;
      };
      title = {
        text = "通知中心";
        clear-all-button = true;
        button-text = "全部清除";
      };
      dnd = {
        text = "勿扰模式";
      };
      mpris = {
        image-size = 80;
        image-radius = 12;
      };
      notifications = {
        vexpand = true;
      };
    };
  };

  mergedSettings = recursiveUpdate defaultSwayncSettings cfg.settings;
  swayncConfText = builtins.toJSON mergedSettings;

  defaultSwayncStyle = ''
    /* 统一调色板 fallback (palette.dark)：由 modules/theme/palette.nix 提供 */
    ${fallbackCss}
    /* 动态覆盖：由 desktop.theme 在 $XDG_RUNTIME_DIR/desktop-theme/colors.css 及 $XDG_CONFIG_HOME/swaync/colors.css 生成，swaync-client --reload-css 生效 */
    /* 若 colors.css 存在则覆盖上方 fallback；缺失则静默回退 */
    @import "colors.css";

    * {
      all: unset;
      font-family: "Geist", "TsangerJinKai04", "Maple Mono NF CN", "Symbols Nerd Font", sans-serif;
      transition: all 0.2s ease;
    }

    /* 浮动通知卡片 (Toasts / Floating Notifications) */
    .floating-notifications.background {
      background: transparent;
    }

    .floating-notifications.background .notification-row {
      outline: none;
      margin: 0;
      padding: 0;
    }

    .floating-notifications.background .notification-row .notification-background {
      box-shadow: 0 8px 24px rgba(0, 0, 0, 0.45);
      background: @background;
      border: 1px solid @border-color;
      border-radius: 14px;
      margin: 10px 14px;
      padding: 0;
    }

    .floating-notifications.background .notification-row .notification-background .notification {
      padding: 12px 14px;
      border-radius: 14px;
      background: transparent;
    }

    .floating-notifications.background .notification-row .notification-background .notification.low,
    .floating-notifications.background .notification-row .notification-background .notification.normal {
      border-left: 3px solid @accent;
    }

    .floating-notifications.background .notification-row .notification-background .notification.critical {
      border-left: 4px solid @critical;
      background: rgba(243, 139, 168, 0.06);
    }

    .floating-notifications.background .notification-row .notification-background .notification .notification-content {
      margin: 4px 6px;
    }

    .floating-notifications.background .notification-row .notification-background .notification .notification-content .summary {
      color: #ffffff;
      font-weight: 700;
      font-size: 13px;
    }

    .floating-notifications.background .notification-row .notification-background .notification .notification-content .time {
      color: @foreground-muted;
      font-size: 11px;
      font-weight: 500;
      margin-right: 8px;
    }

    .floating-notifications.background .notification-row .notification-background .notification .notification-content .body {
      color: @foreground;
      font-size: 12px;
      margin-top: 4px;
    }

    .floating-notifications.background .notification-row .notification-background .notification .notification-content .body-image {
      border-radius: 8px;
      margin-top: 6px;
    }

    /* 通知交互按钮 (Action Buttons & Close Button) */
    .notification-action-buttons {
      margin-top: 8px;
    }

    .notification-action-buttons button,
    .notification-action-buttons .notification-action {
      background: rgba(255, 255, 255, 0.06);
      border: 1px solid @border-color;
      border-radius: 8px;
      color: @foreground;
      font-size: 12px;
      font-weight: 500;
      padding: 4px 10px;
      margin: 2px 4px;
    }

    .notification-action-buttons button:hover,
    .notification-action-buttons .notification-action:hover {
      background: @hover-bg-light;
      color: #ffffff;
      border-color: @accent;
    }

    .close-button {
      background: transparent;
      border-radius: 6px;
      color: @foreground-muted;
      padding: 2px 6px;
      margin: 4px;
    }

    .close-button:hover {
      background: rgba(243, 139, 168, 0.2);
      color: @critical;
    }

    /* 内联快速回复 */
    .notification-inline-reply {
      margin-top: 6px;
    }

    .notification-inline-reply-entry {
      background: @background-card;
      border: 1px solid @border-color;
      border-radius: 8px;
      color: @foreground;
      padding: 6px 10px;
      font-size: 12px;
    }

    .notification-inline-reply-entry:focus {
      border-color: @accent;
      box-shadow: 0 0 8px rgba(137, 180, 250, 0.3);
    }

    .notification-inline-reply-button {
      background: @accent;
      color: #1e1e2e;
      font-weight: bold;
      border-radius: 8px;
      padding: 4px 10px;
      margin-left: 4px;
    }

    /* 通知中心主面板 (Control Center) */
    .control-center {
      box-shadow: 0 8px 32px rgba(0, 0, 0, 0.45);
      border-radius: 16px;
      border: 1px solid @border-color;
      background: @background;
      color: @foreground;
      padding: 14px;
    }

    .control-center-list {
      background: transparent;
    }

    .control-center .notification-row .notification-background {
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.25);
      background: @background-card;
      border: 1px solid @border-color;
      border-radius: 12px;
      margin: 6px 0;
      padding: 0;
    }

    .control-center .notification-row .notification-background:hover {
      border-color: rgba(255, 255, 255, 0.15);
      background: rgba(35, 35, 50, 0.92);
    }

    .control-center .notification-row .notification-background .notification {
      padding: 10px 12px;
      border-radius: 12px;
    }

    .control-center .notification-row .notification-background .notification.critical {
      border-left: 3px solid @critical;
    }

    .control-center .notification-row .notification-background .notification .notification-content .summary {
      color: #ffffff;
      font-weight: 700;
      font-size: 13px;
    }

    .control-center .notification-row .notification-background .notification .notification-content .body {
      color: @foreground;
      font-size: 12px;
      margin-top: 2px;
    }

    .control-center .notification-row .notification-background .notification .notification-content .time {
      color: @foreground-muted;
      font-size: 11px;
    }

    /* 标题与清空栏 */
    .control-center .widget-title {
      color: @accent;
      font-size: 15px;
      font-weight: 700;
      padding: 6px 4px 10px 4px;
    }

    .control-center .widget-title > button {
      background: rgba(255, 255, 255, 0.06);
      border: 1px solid @border-color;
      border-radius: 8px;
      padding: 4px 10px;
      color: @foreground;
      font-size: 12px;
      font-weight: 500;
    }

    .control-center .widget-title > button:hover {
      background: rgba(243, 139, 168, 0.18);
      border-color: @critical;
      color: @critical;
    }

    /* 应用抑制组件 */
    .widget-inhibitors {
      background: @background-card;
      border: 1px solid @border-color;
      border-radius: 12px;
      padding: 8px 12px;
      margin: 4px 0;
    }

    .widget-inhibitors > button {
      background: rgba(255, 255, 255, 0.06);
      border: 1px solid @border-color;
      border-radius: 8px;
      padding: 4px 10px;
      color: @foreground;
      font-size: 12px;
    }

    .widget-inhibitors > button:hover {
      background: rgba(243, 139, 168, 0.18);
      border-color: @critical;
      color: @critical;
    }

    /* 勿扰模式组件 (DND) */
    .control-center .widget-dnd {
      background: @background-card;
      border: 1px solid @border-color;
      border-radius: 12px;
      padding: 10px 14px;
      margin: 6px 0;
      color: @foreground;
      font-weight: 600;
      font-size: 13px;
    }

    .control-center .widget-dnd > switch {
      background: rgba(255, 255, 255, 0.1);
      border: 1px solid @border-color;
      border-radius: 12px;
      min-width: 44px;
      min-height: 22px;
    }

    .control-center .widget-dnd > switch:checked {
      background: @accent;
      border-color: @accent;
    }

    .control-center .widget-dnd > switch slider {
      background: #ffffff;
      border-radius: 10px;
      min-width: 18px;
      min-height: 18px;
      margin: 2px;
    }

    /* 媒体播放控制组件 (MPRIS) */
    .widget-mpris {
      background: @background-card;
      border: 1px solid @border-color;
      border-radius: 14px;
      padding: 12px;
      margin: 8px 0;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.25);
    }

    .widget-mpris-player {
      padding: 4px;
    }

    .widget-mpris-album-art {
      border-radius: 10px;
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.3);
    }

    .widget-mpris-title {
      font-weight: 700;
      font-size: 13px;
      color: #ffffff;
    }

    .widget-mpris-subtitle {
      font-size: 12px;
      color: @foreground-muted;
    }

    .widget-mpris button,
    .widget-mpris-button {
      background: rgba(255, 255, 255, 0.06);
      border: 1px solid @border-color;
      border-radius: 8px;
      color: @foreground;
      padding: 6px 12px;
      margin: 0 3px;
    }

    .widget-mpris button:hover,
    .widget-mpris-button:hover {
      background: @hover-bg-light;
      color: @accent;
      border-color: @accent;
    }

    /* 空状态提示 */
    .blank,
    .text-empty {
      color: @foreground-dim;
      font-size: 13px;
      font-weight: 500;
      padding: 30px;
    }

    /* 滚动条 */
    scrollbar {
      background: transparent;
    }

    scrollbar slider {
      background: rgba(255, 255, 255, 0.1);
      border-radius: 6px;
      min-width: 4px;
    }

    scrollbar slider:hover {
      background: rgba(255, 255, 255, 0.2);
    }
  '';

  finalStyleText =
    (if cfg.style != "" then cfg.style else defaultSwayncStyle)
    + optionalString (cfg.extraStyle != "") "\n${cfg.extraStyle}";

  # 修正上游 swaynotificationcenter 的 D-Bus 服务文件命名缺陷：
  # 上游在 share/dbus-1/services/ 中生成的是 org.erikreider.swaync.service，
  # 但其内部声明的 BusName 为 org.freedesktop.Notifications。
  # dbus-broker 会严格校验服务文件名是否与其声明的 BusName 一致，
  # 否则会打印警告并产生命名不匹配问题。此处构建纯符号链接包装层，
  # 将其规范化为 org.freedesktop.Notifications.service，
  defaultPackage =
    let
      orig = pkgs.swaynotificationcenter;
    in
    pkgs.runCommand "${orig.pname or "swaynotificationcenter"}-${orig.version or "wrapped"}" {
      pname = orig.pname or "swaynotificationcenter";
      version = orig.version or "unknown";
      meta = orig.meta or { };
      passthru = (orig.passthru or { }) // {
        originalPackage = orig;
      };
    } ''
      mkdir -p $out
      for d in ${orig}/*; do
        name=$(basename "$d")
        if [ "$name" = "share" ]; then
          mkdir -p $out/share
          for sd in $d/*; do
            sname=$(basename "$sd")
            if [ "$sname" = "dbus-1" ]; then
              mkdir -p $out/share/dbus-1/services
              ln -s "$sd/services/org.erikreider.swaync.cc.service" "$out/share/dbus-1/services/org.erikreider.swaync.cc.service"
              ln -s "$sd/services/org.erikreider.swaync.service" "$out/share/dbus-1/services/org.freedesktop.Notifications.service"
            else
              ln -s "$sd" "$out/share/$sname"
            fi
          done
        else
          ln -s "$d" "$out/$name"
        fi
      done
    '';
in
{
  options.desktop.notification.swaync = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "是否启用 SwayNC (SwayNotificationCenter) 现代化 Wayland 通知中心。";
    };

    package = mkOption {
      type = types.package;
      default = defaultPackage;
      defaultText = literalExpression "pkgs.swaynotificationcenter (with dbus service name fix)";
      description = "SwayNotificationCenter 软件包。默认包含规范化 D-Bus 激活服务文件名的符号链接包装。";
    };

    settings = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "以 Nix 结构化数据编写的 SwayNC 配置 (config.json)，将与默认预设深度合并。";
    };

    style = mkOption {
      type = types.lines;
      default = "";
      description = "自定义 SwayNC CSS 样式表内容（若设置则完全替换默认预设）。";
    };

    extraStyle = mkOption {
      type = types.lines;
      default = "";
      description = "追加到 SwayNC 样式表的自定义 CSS 规则。";
    };

    systemd = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否通过 systemd 用户服务管理 SwayNC 守护进程。启用后由 graphical-session.target 统一管理生命周期，避免与 D-Bus 激活及 Hyprland autostart 产生竞态双开冲突。";
      };
    };

    blur = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否自动向 Hyprland 注册 swaync 的 layer_rule 背景毛玻璃模糊。";
      };
    };

    niri = {
      autostart = mkOption {
        type = types.bool;
        default = true;
        description = "是否在 Niri 启动时自动拉起 SwayNC（当 systemd.enable = true 时自动由 systemd 管理，不向 Niri 注册重复启动命令）。";
      };

      keybind = mkOption {
        type = types.str;
        default = "Mod+N";
        description = "在 Niri 中切换/唤起通知中心的快捷键绑定（设为空字符串则不注册）。";
      };
    };

    homeManager = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "若系统中启用了 Home Manager，是否自动将 SwayNC 配置注入到所有 Home Manager 用户中。";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      environment.systemPackages = [
        cfg.package
        pkgs.libnotify
      ];

      environment.etc = {
        "xdg/swaync/config.json".text = swayncConfText;
        "xdg/swaync/style.css".text = finalStyleText;
      };

      # ── 主题联动：显式声明 SwayNC 对主题钩子的 PATH 与脚本注入 ───────────
      desktop.theme.hookPackages = mkIf (config.desktop.theme.enable or false) [
        cfg.package
        pkgs.procps
        pkgs.systemd
      ];
      desktop.theme.hookFragmentsReload = mkIf (config.desktop.theme.enable or false) [''
        # --- SwayNC 主题联动 reload（由 modules/notification/swaync 注入，需 swaync 守护进程，seed 跳过） ---
        if systemctl --user is-active swaync.service >/dev/null 2>&1 || pgrep -x swaync >/dev/null 2>&1 || pgrep -x swaync-client >/dev/null 2>&1; then
          if command -v swaync-client >/dev/null 2>&1; then
            swaync-client --reload-css 2>/dev/null || true
          elif [ -x "${cfg.package}/bin/swaync-client" ]; then
            ${cfg.package}/bin/swaync-client --reload-css 2>/dev/null || true
          fi
        else
          echo "[theme-switch] diag: swaync not ready, skipping reload" >&2
        fi
      ''];

      # Systemd 用户守护进程服务：由 graphical-session.target 统一管理生命周期
      systemd.user.services.swaync = mkIf cfg.systemd.enable {
        description = "Swaync notification daemon";
        documentation = [ "https://github.com/ErikReider/SwayNotificationCenter" ];
        partOf = [ "graphical-session.target" ];
        after = [ "graphical-session.target" ];
        wantedBy = [ "graphical-session.target" ];
        unitConfig = {
          ConditionEnvironment = "WAYLAND_DISPLAY";
        };
        serviceConfig = {
          Type = "dbus";
          BusName = "org.freedesktop.Notifications";
          ExecStart = "${cfg.package}/bin/swaync";
          ExecReload = [
            "${cfg.package}/bin/swaync-client --reload-config"
            "${cfg.package}/bin/swaync-client --reload-css"
          ];
          Restart = "on-failure";
          RestartSec = 1;
        };
      };

      # 联动向 Niri 注册自启动与按键绑定
      desktop.windowManager.niri = mkIf (config ? desktop && config.desktop ? windowManager && config.desktop.windowManager ? niri && config.desktop.windowManager.niri.enable) {
        # 仅在未启用 systemd 服务管理时通过 Niri 命令行拉起，避免同时启动产生竞态导致 "An instance of SwayNotificationCenter is already running!" 崩溃
        autostart = mkIf (cfg.niri.autostart && !cfg.systemd.enable) [
          "swaync"
        ];
        extraBinds = mkIf (cfg.niri.keybind != "") {
          "${cfg.niri.keybind}" = {
            _props.hotkey-overlay-title = "Toggle Notification Center";
            spawn-sh = [ "swaync-client -t -sw" ];
          };
        };
      };
    }

    (optionalAttrs (options ? home-manager) {
      home-manager = mkIf cfg.homeManager.enable {
        sharedModules = [
          ({ ... }: {
            # 注意：此处切勿将 cfg.package 重复加入 home.packages，
            # 否则会导致 dbus-broker 同时扫描 ~/.nix-profile 与 /run/current-system/sw，
            # 触发 "Ignoring duplicate name 'org.erikreider.swaync.cc'" 等重复服务声明警告。
            # 系统级环境已通过 environment.systemPackages 提供了全局可用的二进制及 D-Bus 激活文件。
            xdg.configFile = {
              "swaync/config.json".text = swayncConfText;
              "swaync/style.css".text = finalStyleText;
            };
          })
        ];
      };
    })
  ]);
}
