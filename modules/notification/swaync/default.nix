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
    * {
      all: unset;
      font-family: inherit;
      transition: 200ms ease;
    }

    .floating-notifications.background .notification-row .notification-background {
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.4);
      background: rgba(26, 27, 38, 0.92);
      border: 1px solid rgba(255, 255, 255, 0.12);
      border-radius: 12px;
      margin: 12px;
      padding: 0;
    }

    .floating-notifications.background .notification-row .notification-background .notification {
      padding: 12px;
      border-radius: 12px;
    }

    .floating-notifications.background .notification-row .notification-background .notification.critical {
      border: 2px solid #ff5555;
    }

    .floating-notifications.background .notification-row .notification-background .notification .notification-content {
      margin: 6px;
    }

    .floating-notifications.background .notification-row .notification-background .notification .notification-content .summary {
      color: #c0caf5;
      font-weight: bold;
      font-size: 14px;
    }

    .floating-notifications.background .notification-row .notification-background .notification .notification-content .time {
      color: #565f89;
      font-size: 12px;
      font-weight: 500;
      margin-right: 12px;
    }

    .floating-notifications.background .notification-row .notification-background .notification .notification-content .body {
      color: #a9b1d6;
      font-size: 13px;
      margin-top: 4px;
    }

    .control-center {
      box-shadow: 0 8px 24px rgba(0, 0, 0, 0.5);
      border-radius: 16px;
      border: 1px solid rgba(255, 255, 255, 0.12);
      background: rgba(26, 27, 38, 0.95);
      color: #c0caf5;
      padding: 14px;
    }

    .control-center .widget-title {
      color: #7aa2f7;
      font-size: 16px;
      font-weight: bold;
      padding: 8px;
    }

    .control-center .widget-title > button {
      background: rgba(255, 255, 255, 0.08);
      border: 1px solid rgba(255, 255, 255, 0.1);
      border-radius: 8px;
      padding: 4px 12px;
      color: #c0caf5;
    }

    .control-center .widget-title > button:hover {
      background: rgba(255, 85, 85, 0.25);
      border-color: #ff5555;
      color: #ff7777;
    }

    .control-center .widget-dnd {
      background: rgba(255, 255, 255, 0.04);
      border-radius: 10px;
      padding: 8px 12px;
      margin: 6px 0;
    }

    .control-center .widget-dnd > switch {
      background: rgba(255, 255, 255, 0.1);
      border-radius: 12px;
    }

    .control-center .widget-dnd > switch:checked {
      background: #7aa2f7;
    }

    .widget-mpris {
      background: rgba(255, 255, 255, 0.04);
      border: 1px solid rgba(255, 255, 255, 0.08);
      border-radius: 12px;
      padding: 10px;
      margin: 8px 0;
    }

    .widget-mpris-title {
      font-weight: bold;
      font-size: 14px;
      color: #c0caf5;
    }

    .widget-mpris-subtitle {
      font-size: 12px;
      color: #565f89;
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
