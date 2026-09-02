{
  config,
  pkgs,
  lib,
  options,
  ...
}:

with lib;

let
  cfg = config.desktop.powerMenu.wlogout;
  inline = lib.generators.mkLuaInline;

  powerIcons = import ./icons.nix { inherit pkgs; };
  themePalettes = import ./themes.nix;
  currentTheme = themePalettes.${cfg.theme} or themePalettes.catppuccin-mocha;

  wlogoutArgs =
    if cfg.style == "bar" then
      "-b 6 -c 16 -r 0 -T 320 -B 320 -L 120 -R 120 --protocol layer-shell"
    else if cfg.style == "grid" then
      "-b 3 -c 16 -r 16 -T 240 -B 240 -L 280 -R 280 --protocol layer-shell"
    else
      "-b 3 -c 24 -r 24 -m 120 --protocol layer-shell";

  wlogoutMenuScript = pkgs.writeShellScriptBin "wlogout-menu" ''
    # 防止重复唤起
    if ${pkgs.procps}/bin/pidof wlogout >/dev/null 2>&1; then
      exit 0
    fi

    # 1. 隐藏 Waybar（向 waybar 发送 SIGUSR1 信号切换至隐藏状态）
    ${pkgs.procps}/bin/pkill -SIGUSR1 waybar 2>/dev/null || true

    # 2. 阻塞运行全屏现代化电源中心 wlogout
    ${cfg.package}/bin/wlogout ${wlogoutArgs} "$@"

    # 3. 退出后恢复显示 Waybar（向 waybar 发送 SIGUSR1 信号恢复显示）
    ${pkgs.procps}/bin/pkill -SIGUSR1 waybar 2>/dev/null || true
  '';

  wlogoutLayoutText = builtins.toJSON [
    {
      label = "lock";
      action = "hyprlock || loginctl lock-session";
      text = "锁定 [L]";
      keybind = "l";
    }
    {
      label = "logout";
      action = "hyprctl dispatch exit || loginctl terminate-user $USER";
      text = "注销 [E]";
      keybind = "e";
    }
    {
      label = "suspend";
      action = "systemctl suspend";
      text = "睡眠 [U]";
      keybind = "u";
    }
    {
      label = "hibernate";
      action = "systemctl hibernate";
      text = "休眠 [H]";
      keybind = "h";
    }
    {
      label = "reboot";
      action = "systemctl reboot";
      text = "重启 [R]";
      keybind = "r";
    }
    {
      label = "shutdown";
      action = "systemctl poweroff";
      text = "关机 [S]";
      keybind = "s";
    }
  ];

  wlogoutStyleText = ''
    * {
      background-image: none;
      box-shadow: none;
      font-family: "Geist", "TsangerJinKai04", "Maple Mono NF CN", "Noto Sans CJK SC", sans-serif;
    }

    window {
      background-color: ${currentTheme.bg};
    }

    button {
      border-radius: 18px;
      border: 1px solid ${currentTheme.cardBorder};
      color: ${currentTheme.text};
      background-color: ${currentTheme.cardBg};
      background-repeat: no-repeat;
      background-position: center 32%;
      background-size: 54px;
      margin: 10px;
      padding: 16px 12px;
      font-size: 15px;
      font-weight: 500;
      box-shadow: 0 4px 18px rgba(0, 0, 0, 0.25);
      transition: all 0.24s cubic-bezier(0.16, 1, 0.3, 1);
    }

    button:focus, button:active, button:hover {
      outline-style: none;
    }

    #lock {
      background-image: image(url("${powerIcons}/icons/lock.svg"));
    }
    #lock:hover, #lock:focus {
      background-color: rgba(${currentTheme.lock.rgb}, 0.16);
      border-color: ${currentTheme.lock.hex};
      color: #ffffff;
      box-shadow: 0 0 24px rgba(${currentTheme.lock.rgb}, 0.40);
    }

    #logout {
      background-image: image(url("${powerIcons}/icons/logout.svg"));
    }
    #logout:hover, #logout:focus {
      background-color: rgba(${currentTheme.logout.rgb}, 0.16);
      border-color: ${currentTheme.logout.hex};
      color: #ffffff;
      box-shadow: 0 0 24px rgba(${currentTheme.logout.rgb}, 0.40);
    }

    #suspend {
      background-image: image(url("${powerIcons}/icons/suspend.svg"));
    }
    #suspend:hover, #suspend:focus {
      background-color: rgba(${currentTheme.suspend.rgb}, 0.16);
      border-color: ${currentTheme.suspend.hex};
      color: #ffffff;
      box-shadow: 0 0 24px rgba(${currentTheme.suspend.rgb}, 0.40);
    }

    #hibernate {
      background-image: image(url("${powerIcons}/icons/hibernate.svg"));
    }
    #hibernate:hover, #hibernate:focus {
      background-color: rgba(${currentTheme.hibernate.rgb}, 0.16);
      border-color: ${currentTheme.hibernate.hex};
      color: #ffffff;
      box-shadow: 0 0 24px rgba(${currentTheme.hibernate.rgb}, 0.40);
    }

    #reboot {
      background-image: image(url("${powerIcons}/icons/reboot.svg"));
    }
    #reboot:hover, #reboot:focus {
      background-color: rgba(${currentTheme.reboot.rgb}, 0.16);
      border-color: ${currentTheme.reboot.hex};
      color: #ffffff;
      box-shadow: 0 0 24px rgba(${currentTheme.reboot.rgb}, 0.40);
    }

    #shutdown {
      background-image: image(url("${powerIcons}/icons/shutdown.svg"));
    }
    #shutdown:hover, #shutdown:focus {
      background-color: rgba(${currentTheme.shutdown.rgb}, 0.18);
      border-color: ${currentTheme.shutdown.hex};
      color: #ffffff;
      box-shadow: 0 0 24px rgba(${currentTheme.shutdown.rgb}, 0.45);
    }

    ${cfg.extraStyle}
  '';
in
{
  options.desktop.powerMenu.wlogout = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "是否启用基于 wlogout 的全屏现代化毛玻璃电源中心（集成锁屏、注销、休眠、睡眠、重启、关机）。";
    };

    package = mkPackageOption pkgs "wlogout" { };

    style = mkOption {
      type = types.enum [ "bar" "grid" "fullscreen" ];
      default = "bar";
      description = "电源菜单布局形态：bar(居中横向浮动胶囊岛)、grid(2x3紧凑卡片矩阵)、fullscreen(全屏极简沉浸式)。";
    };

    theme = mkOption {
      type = types.enum [ "catppuccin-mocha" "tokyo-night" "nord" ];
      default = "catppuccin-mocha";
      description = "电源菜单主题配色方案（支持 catppuccin-mocha、tokyo-night、nord）。";
    };

    blur = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否自动向 Hyprland 注册 wlogout 的 layerrule 背景毛玻璃模糊。";
      };
    };

    extraStyle = mkOption {
      type = types.lines;
      default = "";
      description = "追加到 wlogout style.css 的自定义 CSS 样式规则。";
    };

    hyprland = {
      keybinds = mkOption {
        type = types.listOf types.str;
        default = [ "SUPER + M" "XF86PowerOff" ];
        description = "在 Hyprland 中唤起电源中心的快捷键列表。";
      };
    };

    homeManager = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "若系统中启用了 Home Manager，是否自动将 wlogout 配置注入到所有 Home Manager 用户中。";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      environment.systemPackages = [
        cfg.package
        wlogoutMenuScript
      ];

      environment.etc = {
        "wlogout/layout".text = wlogoutLayoutText;
        "wlogout/style.css".text = wlogoutStyleText;
        "xdg/wlogout/layout".text = wlogoutLayoutText;
        "xdg/wlogout/style.css".text = wlogoutStyleText;
      };

      # 联动向 Hyprland 注册 layerrule 和快捷键
      desktop.windowManager.hyprland = mkIf (config ? desktop && config.desktop ? windowManager && config.desktop.windowManager ? hyprland && config.desktop.windowManager.hyprland.enable) {
        layerRules = optionals cfg.blur.enable [
          "blur, wlogout"
          "ignorezero, wlogout"
        ];
        extraBinds = map (bindStr: {
          _args = [ (inline ''"${bindStr}"'') (inline ''hl.dsp.exec_cmd("wlogout-menu")'') ];
        }) cfg.hyprland.keybinds;
      };
    }

    (optionalAttrs (options ? home-manager) {
      home-manager = mkIf cfg.homeManager.enable {
        sharedModules = [
          ({ ... }: {
            home.packages = [ cfg.package wlogoutMenuScript ];
            xdg.configFile = {
              "wlogout/layout".text = wlogoutLayoutText;
              "wlogout/style.css".text = wlogoutStyleText;
            };
          })
        ];
      };
    })
  ]);
}
