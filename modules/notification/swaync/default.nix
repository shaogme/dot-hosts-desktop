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
  inline = lib.generators.mkLuaInline;

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
    @define-color background rgba(20, 20, 28, 0.85);
    @define-color background-card rgba(30, 30, 42, 0.88);
    @define-color foreground #cdd6f4;
    @define-color foreground-muted #a6adc8;
    @define-color foreground-dim #6c7086;
    @define-color border-color rgba(255, 255, 255, 0.08);
    @define-color active-border #89b4fa;
    @define-color hover-bg rgba(255, 255, 255, 0.08);
    @define-color hover-bg-light rgba(255, 255, 255, 0.12);
    @define-color selected-bg rgba(137, 180, 250, 0.15);
    @define-color warning #f9e2af;
    @define-color critical #f38ba8;
    @define-color accent #89b4fa;

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
in
{
  options.desktop.notification.swaync = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "是否启用 SwayNC (SwayNotificationCenter) 现代化 Wayland 通知中心。";
    };

    package = mkPackageOption pkgs "swaynotificationcenter" { };

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

    blur = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否自动向 Hyprland 注册 swaync 的 layer_rule 背景毛玻璃模糊。";
      };
    };

    hyprland = {
      autostart = mkOption {
        type = types.bool;
        default = true;
        description = "是否在 Hyprland 启动时自动拉起 SwayNC。";
      };

      keybind = mkOption {
        type = types.str;
        default = "SUPER + N";
        description = "在 Hyprland 中切换/唤起通知中心的快捷键绑定（设为空字符串则不注册）。";
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

      # 联动向 Hyprland 注册自启动、按键绑定及图层模糊规则
      desktop.windowManager.hyprland = mkIf (config ? desktop && config.desktop ? windowManager && config.desktop.windowManager ? hyprland && config.desktop.windowManager.hyprland.enable) {
        autostart = mkIf cfg.hyprland.autostart [
          "swaync"
        ];
        extraBinds = mkIf (cfg.hyprland.keybind != "") [
          { _args = [ (inline ''"${cfg.hyprland.keybind}"'') (inline ''hl.dsp.exec_cmd("swaync-client -t -sw")'') ]; }
        ];
        layerRules = optionals cfg.blur.enable [
          {
            match = {
              namespace = "swaync-control-center";
            };
            blur = true;
            ignore_alpha = 0;
          }
          {
            match = {
              namespace = "swaync-notification-window";
            };
            blur = true;
            ignore_alpha = 0;
          }
        ];
      };
    }

    (optionalAttrs (options ? home-manager) {
      home-manager = mkIf cfg.homeManager.enable {
        sharedModules = [
          ({ ... }: {
            home.packages = [ cfg.package pkgs.libnotify ];
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
