{
  config,
  pkgs,
  lib,
  options,
  ...
}:

with lib;

let
  cfg = config.desktop.bar.waybar;
  inline = lib.generators.mkLuaInline;

  defaultWaybarSettings = {
    layer = "top";
    position = cfg.position;
    height = 32;
    spacing = 4;
    modules-left = [
      "hyprland/workspaces"
    ];
    modules-center = [
      "hyprland/window"
    ];
    modules-right = [
      "pulseaudio"
      "network"
      "cpu"
      "memory"
      "temperature"
      "battery"
      "clock"
      "tray"
      "custom/notification"
      "custom/power"
    ];
    "hyprland/workspaces" = {
      format = "{name}";
      on-click = "activate";
      sort-by = "number";
      persistent-workspaces = {
        "*" = 5;
      };
    };
    "hyprland/window" = {
      max-length = 50;
      separate-outputs = true;
    };
    clock = {
      format = "  {:%Y-%m-%d %H:%M}";
      tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
    };
    cpu = {
      format = "  {usage}%";
      tooltip = false;
    };
    memory = {
      format = "󰍛  {}%";
    };
    temperature = {
      critical-threshold = 80;
      format = "  {temperatureC}°C";
    };
    battery = {
      states = {
        warning = 30;
        critical = 15;
      };
      format = "{icon}  {capacity}%";
      format-charging = "󰂄  {capacity}%";
      format-plugged = "󰚥  {capacity}%";
      format-icons = [ "󰂎" "󰁺" "󰁼" "󰁾" "󰂀" "󰂂" "󰁹" ];
    };
    network = {
      interval = 5;
      format-wifi = "{icon}  {essid} ({signalStrength}%)";
      format-ethernet = "󰈀  {ipaddr}/{cidr}";
      format-disconnected = "<span color='#ff5555'>󰤮</span>  Disconnected";
      format-icons = [ "󰤯" "󰤟" "󰤢" "󰤥" "󰤨" ];
    };
    pulseaudio = {
      format = "{icon}  {volume}%";
      format-muted = "<span color='#888888'>󰝟</span>  Muted";
      format-icons = {
        default = [ "󰕿" "󰖀" "󰕾" ];
      };
      on-click = "pavucontrol";
    };
    tray = {
      spacing = 10;
    };
    "custom/notification" = {
      tooltip = false;
      format = "{icon}";
      format-icons = {
        notification = "<span foreground='red'><sup></sup></span>";
        none = "";
        dnd-notification = "<span foreground='red'><sup></sup></span>";
        dnd-none = "";
        inhibited-notification = "<span foreground='red'><sup></sup></span>";
        inhibited-none = "";
        dnd-inhibited-notification = "<span foreground='red'><sup></sup></span>";
        dnd-inhibited-none = "";
      };
      return-type = "json";
      exec-if = "which swaync-client";
      exec = "swaync-client -df -p";
      on-click = "swaync-client -t -sw";
      on-click-right = "swaync-client -d -sw";
      escape = true;
    };
    "custom/power" = {
      format = "";
      tooltip = false;
      on-click = "wlogout-menu";
    };
  };

  mergedSettings = recursiveUpdate defaultWaybarSettings cfg.settings;
  waybarConfText = builtins.toJSON mergedSettings;

  defaultWaybarStyle = ''
    * {
      border: none;
      border-radius: 0;
      font-family: inherit;
      font-size: 13px;
      min-height: 0;
    }
    window#waybar {
      background-color: rgba(20, 20, 25, 0.85);
      border-bottom: 2px solid rgba(100, 100, 120, 0.3);
      color: #ffffff;
    }
    #workspaces button {
      padding: 0 6px;
      background-color: transparent;
      color: #ffffff;
      border-bottom: 2px solid transparent;
    }
    #workspaces button:hover {
      background: rgba(255, 255, 255, 0.1);
    }
    #workspaces button.active {
      background-color: rgba(100, 150, 255, 0.3);
      border-bottom: 2px solid #5294e2;
    }
    #workspaces button.empty {
      color: rgba(255, 255, 255, 0.4);
    }
    #clock, #battery, #cpu, #memory, #temperature, #network, #pulseaudio, #tray, #custom-notification, #custom-power {
      padding: 0 10px;
      color: #ffffff;
    }
    #custom-notification {
      font-size: 14px;
    }
    #custom-notification:hover {
      color: #7aa2f7;
    }
    #battery.warning {
      color: #f9e2af;
    }
    #battery.critical {
      color: #ff5555;
    }
    #temperature.critical {
      color: #ff5555;
    }
    #custom-power {
      color: #ff5555;
      font-weight: bold;
      margin-right: 6px;
    }
    #custom-power:hover {
      color: #ff7777;
      background-color: rgba(255, 85, 85, 0.2);
      border-radius: 4px;
    }
  '';

  finalStyleText =
    (if cfg.style != "" then cfg.style else defaultWaybarStyle)
    + optionalString (cfg.extraStyle != "") "\n${cfg.extraStyle}";
in
{
  options.desktop.bar.waybar = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "是否启用 Waybar 高性能 Wayland 桌面状态栏组件。";
    };

    package = mkPackageOption pkgs "waybar" { };

    position = mkOption {
      type = types.enum [ "top" "bottom" "left" "right" ];
      default = "top";
      description = "状态栏放置屏幕边缘方位。";
    };

    settings = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "以 Nix 结构化数据编写的 Waybar 模块配置，将与默认预设深度合并。";
    };

    style = mkOption {
      type = types.lines;
      default = "";
      description = "自定义 Waybar CSS 样式表内容（若设置则完全替换默认预设）。";
    };

    extraStyle = mkOption {
      type = types.lines;
      default = "";
      description = "追加到 Waybar 样式表的自定义 CSS 规则。";
    };

    hyprland = {
      autostart = mkOption {
        type = types.bool;
        default = true;
        description = "是否在 Hyprland 启动时自动注入 waybar 自启动动作。";
      };

      keybind = mkOption {
        type = types.str;
        default = "SUPER + B";
        description = "在 Hyprland 中切换/显隐 Waybar 的快捷键绑定（设为空字符串则不注册）。";
      };
    };

    homeManager = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "若系统中启用了 Home Manager，是否自动将 Waybar 配置注入到所有 Home Manager 用户中。";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      environment.systemPackages = [
        cfg.package
      ];

      environment.etc = {
        "xdg/waybar/config.jsonc".text = waybarConfText;
        "xdg/waybar/config".text = waybarConfText;
        "xdg/waybar/style.css".text = finalStyleText;
      };

      # 联动向 Hyprland 注册自启动与快捷键
      desktop.windowManager.hyprland = mkIf (config ? desktop && config.desktop ? windowManager && config.desktop.windowManager ? hyprland && config.desktop.windowManager.hyprland.enable) {
        autostart = mkIf cfg.hyprland.autostart [
          "waybar"
        ];
        extraBinds = mkIf (cfg.hyprland.keybind != "") [
          { _args = [ (inline ''"${cfg.hyprland.keybind}"'') (inline ''hl.dsp.exec_cmd("pkill -SIGUSR1 waybar")'') ]; }
        ];
      };
    }

    (optionalAttrs (options ? home-manager) {
      home-manager = mkIf cfg.homeManager.enable {
        sharedModules = [
          ({ ... }: {
            home.packages = [ cfg.package ];
            xdg.configFile = {
              "waybar/config.jsonc".text = waybarConfText;
              "waybar/config".text = waybarConfText;
              "waybar/style.css".text = finalStyleText;
            };
          })
        ];
      };
    })
  ]);
}
