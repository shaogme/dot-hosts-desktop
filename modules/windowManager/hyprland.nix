{
  config,
  pkgs,
  lib,
  options,
  ...
}:

with lib;

let
  cfg = config.desktop.windowManager.hyprland;
  inline = lib.generators.mkLuaInline;

  toHyprlua =
    {
      attrs,
    }:
    let
      inherit (lib)
        attrNames
        concatMapStrings
        filter
        optionalString
        sort
        ;

      toLua = lib.generators.toLua { };
      renderLuaArgs =
        value:
        if lib.isAttrs value && value ? _args then
          lib.concatMapStringsSep ", " toLua value._args
        else
          toLua value;

      isLuaLocal = value: lib.isAttrs value && value ? _var;
      luaLocalName = name: value: value.name or name;

      names = sort lib.lessThan (attrNames attrs);
      luaLocalNames = filter (name: isLuaLocal attrs.${name}) names;
      settingNames = filter (name: !(builtins.elem name luaLocalNames)) names;

      renderLocal =
        name:
        let
          value = attrs.${name};
        in
        "local ${luaLocalName name value} = ${renderLuaArgs value._var}\n";

      renderCall = name: value: "hl.${name}(${renderLuaArgs value})\n";
      renderCalls =
        name: value: concatMapStrings (renderCall name) (if lib.isList value then value else [ value ]);
    in
    optionalString (luaLocalNames != [ ]) (
      "-- locals\n"
      + concatMapStrings renderLocal luaLocalNames
      + "\n"
    )
    + concatMapStrings (
      name:
      "-- ${name}\n"
      + renderCalls name attrs.${name}
      + "\n"
    ) settingNames;

  # 默认的 Hyprland 桌面配置集合 (Lua 格式)
  defaultSettings = {
    monitor = [
      {
        output = "";
        mode = "preferred";
        position = "auto";
        scale = "auto";
      }
    ];

    config = {
      general = {
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;
        layout = "dwindle";
      };

      decoration = {
        rounding = 8;
        blur = {
          enabled = true;
          size = 5;
          passes = 2;
        };
      };

      animations = {
        enabled = true;
      };
    };

    on = [
      {
        _args = [
          "hyprland.start"
          (inline ''
            function()
              hl.exec_cmd("waybar")
              hl.exec_cmd("dunst")
            end
          '')
        ];
      }
    ];

    bind = [
      { _args = [ (inline ''"SUPER + Return"'') (inline ''hl.dsp.exec_cmd("kitty")'') ]; }
      { _args = [ (inline ''"SUPER + Q"'') (inline ''hl.dsp.window.close()'') ]; }
      { _args = [ (inline ''"SUPER + M"'') (inline ''hl.dsp.exec_cmd("wlogout-menu")'') ]; }
      { _args = [ (inline ''"SUPER + Space"'') (inline ''hl.dsp.exec_cmd("wofi --show drun --allow-images")'') ]; }
      { _args = [ (inline ''"SUPER + B"'') (inline ''hl.dsp.exec_cmd("pkill -SIGUSR1 waybar")'') ]; }
      { _args = [ (inline ''"SUPER + V"'') (inline ''hl.dsp.window.float({ action = "toggle" })'') ]; }
      { _args = [ (inline ''"SUPER + F"'') (inline ''hl.dsp.window.fullscreen()'') ]; }

      # 窗口焦点移动
      { _args = [ (inline ''"SUPER + left"'') (inline ''hl.dsp.focus({ direction = "left" })'') ]; }
      { _args = [ (inline ''"SUPER + right"'') (inline ''hl.dsp.focus({ direction = "right" })'') ]; }
      { _args = [ (inline ''"SUPER + up"'') (inline ''hl.dsp.focus({ direction = "up" })'') ]; }
      { _args = [ (inline ''"SUPER + down"'') (inline ''hl.dsp.focus({ direction = "down" })'') ]; }
      { _args = [ (inline ''"SUPER + h"'') (inline ''hl.dsp.focus({ direction = "left" })'') ]; }
      { _args = [ (inline ''"SUPER + l"'') (inline ''hl.dsp.focus({ direction = "right" })'') ]; }
      { _args = [ (inline ''"SUPER + k"'') (inline ''hl.dsp.focus({ direction = "up" })'') ]; }
      { _args = [ (inline ''"SUPER + j"'') (inline ''hl.dsp.focus({ direction = "down" })'') ]; }

      # 工作区切换 (1-9)
      { _args = [ (inline ''"SUPER + 1"'') (inline ''hl.dsp.focus({ workspace = 1 })'') ]; }
      { _args = [ (inline ''"SUPER + 2"'') (inline ''hl.dsp.focus({ workspace = 2 })'') ]; }
      { _args = [ (inline ''"SUPER + 3"'') (inline ''hl.dsp.focus({ workspace = 3 })'') ]; }
      { _args = [ (inline ''"SUPER + 4"'') (inline ''hl.dsp.focus({ workspace = 4 })'') ]; }
      { _args = [ (inline ''"SUPER + 5"'') (inline ''hl.dsp.focus({ workspace = 5 })'') ]; }
      { _args = [ (inline ''"SUPER + 6"'') (inline ''hl.dsp.focus({ workspace = 6 })'') ]; }
      { _args = [ (inline ''"SUPER + 7"'') (inline ''hl.dsp.focus({ workspace = 7 })'') ]; }
      { _args = [ (inline ''"SUPER + 8"'') (inline ''hl.dsp.focus({ workspace = 8 })'') ]; }
      { _args = [ (inline ''"SUPER + 9"'') (inline ''hl.dsp.focus({ workspace = 9 })'') ]; }

      # 移动活动窗口至工作区
      { _args = [ (inline ''"SUPER + SHIFT + 1"'') (inline ''hl.dsp.window.move({ workspace = 1 })'') ]; }
      { _args = [ (inline ''"SUPER + SHIFT + 2"'') (inline ''hl.dsp.window.move({ workspace = 2 })'') ]; }
      { _args = [ (inline ''"SUPER + SHIFT + 3"'') (inline ''hl.dsp.window.move({ workspace = 3 })'') ]; }
      { _args = [ (inline ''"SUPER + SHIFT + 4"'') (inline ''hl.dsp.window.move({ workspace = 4 })'') ]; }
      { _args = [ (inline ''"SUPER + SHIFT + 5"'') (inline ''hl.dsp.window.move({ workspace = 5 })'') ]; }
      { _args = [ (inline ''"SUPER + SHIFT + 6"'') (inline ''hl.dsp.window.move({ workspace = 6 })'') ]; }
      { _args = [ (inline ''"SUPER + SHIFT + 7"'') (inline ''hl.dsp.window.move({ workspace = 7 })'') ]; }
      { _args = [ (inline ''"SUPER + SHIFT + 8"'') (inline ''hl.dsp.window.move({ workspace = 8 })'') ]; }
      { _args = [ (inline ''"SUPER + SHIFT + 9"'') (inline ''hl.dsp.window.move({ workspace = 9 })'') ]; }

      # 鼠标拖动与调整大小
      { _args = [ (inline ''"SUPER + mouse:272"'') (inline ''hl.dsp.window.drag()'') { mouse = true; } ]; }
      { _args = [ (inline ''"SUPER + mouse:273"'') (inline ''hl.dsp.window.resize()'') { mouse = true; } ]; }
    ];
  };

  # 虚拟机兼容模式环境配置
  virtualizationEnv = [
    { _args = [ "WLR_NO_HARDWARE_CURSORS" "1" ]; }
    { _args = [ "WLR_RENDERER_ALLOW_SOFTWARE" "1" ]; }
  ];

  # Wi-Fi 托盘自启动配置
  wifiExecOnceOn = optional cfg.wifi.enable {
    _args = [
      "hyprland.start"
      (inline ''
        function()
          hl.exec_cmd("nm-applet --indicator")
        end
      '')
    ];
  };

  # 将 extraExecOnce 格式化为 autostart 动作
  extraExecOnceOn = optional (cfg.extraExecOnce != [ ]) {
    _args = [
      "hyprland.start"
      (inline ''
        function()
        ${concatMapStringsSep "\n" (cmd: "  hl.exec_cmd(${builtins.toJSON cmd})") cfg.extraExecOnce}
        end
      '')
    ];
  };

  # 规范化 extraBinds 支持 table 或 raw string
  normalizedExtraBinds = map (
    b:
    if isAttrs b then
      b
    else
      { _args = [ (inline b) ]; }
  ) cfg.extraBinds;

  # 合并默认配置、虚拟机配置与用户自定义 settings
  rawSettings = defaultSettings // (optionalAttrs cfg.virtualization.enable {
    env = (defaultSettings.env or [ ]) ++ virtualizationEnv;
  });

  mergedSettings = recursiveUpdate rawSettings cfg.settings;

  finalSettings = mergedSettings // {
    bind = (mergedSettings.bind or [ ]) ++ normalizedExtraBinds;
    on = (mergedSettings.on or [ ]) ++ wifiExecOnceOn ++ extraExecOnceOn;
  };

  wofiConfText =
    let
      defaultWofiSettings = {
        mode = cfg.wofi.mode;
        allow_images = cfg.wofi.allowImages;
        image_size = cfg.wofi.imageSize;
        insensitive = true;
        hide_scroll = true;
        term = "${pkgs.kitty}/bin/kitty";
        gtk_dark = true;
      };
      mergedWofi = defaultWofiSettings // cfg.wofi.settings;
      renderWofiVal = v: if builtins.isBool v then (if v then "true" else "false") else toString v;
    in
    lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "${k}=${renderWofiVal v}") mergedWofi) + "\n";
in
{
  options.desktop.windowManager.hyprland = {
    enable = mkEnableOption "Hyprland 现代化动态平铺 Wayland 窗口管理器";

    package = mkPackageOption pkgs "hyprland" { };

    xwayland = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否启用 XWayland 兼容层支持。";
      };
    };

    audio = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否自动启用 PipeWire 音频服务与 rtkit 实时调度支持。";
      };
    };

    wifi = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "是否启用 Wi-Fi 支持与托盘管理（如 networkmanager-applet / nm-applet）。";
      };

      packages = mkOption {
        type = types.listOf types.package;
        default = with pkgs; [
          networkmanagerapplet
        ];
        description = "Hyprland Wi-Fi 管理工具包列表。";
      };
    };

    iconTheme = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否启用并统一配置桌面与 GTK 图标主题（如 Adwaita、hicolor-icon-theme）。";
      };

      package = mkOption {
        type = types.package;
        default = pkgs.adwaita-icon-theme;
        defaultText = literalExpression "pkgs.adwaita-icon-theme";
        description = "默认图标主题软件包。";
      };

      name = mkOption {
        type = types.str;
        default = "Adwaita";
        description = "默认图标主题名称。";
      };
    };

    wofi = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否启用并生成系统级 Wofi 启动器配置（默认开启图像/图标渲染与不区分大小写检索）。";
      };

      mode = mkOption {
        type = types.str;
        default = "drun";
        description = "Wofi 默认启动模式（如 drun、run、dmenu）。";
      };

      allowImages = mkOption {
        type = types.bool;
        default = true;
        description = "是否允许 Wofi 在 drun 模式下显示应用程序图标。";
      };

      imageSize = mkOption {
        type = types.int;
        default = 32;
        description = "Wofi 中应用程序图标的显示大小（像素）。";
      };

      settings = mkOption {
        type = types.attrsOf types.anything;
        default = { };
        description = "写入 /etc/wofi/config 及 /etc/xdg/wofi/config 的自定义配置项。";
      };
    };

    powerMenu = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否启用基于 wlogout 的全屏现代化电源中心（集成锁屏、注销、休眠、睡眠、重启、关机，并在打开时自动隐藏 Waybar，退出时恢复）。";
      };

      package = mkOption {
        type = types.package;
        default = pkgs.wlogout;
        defaultText = literalExpression "pkgs.wlogout";
        description = "使用的 wlogout 软件包。";
      };
    };

    defaultTools = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否安装并配置常用的 Wayland 桌面配套工具（kitty, waybar, wofi, dunst, wl-clipboard, grim, slurp, libnotify 等）。";
      };

      packages = mkOption {
        type = types.listOf types.package;
        default = with pkgs; [
          kitty
          waybar
          wofi
          wl-clipboard
          grim
          slurp
          dunst
          libnotify
          hicolor-icon-theme
          adwaita-icon-theme
        ];
        description = "Wayland 桌面配套工具软件包列表。";
      };
    };

    virtualization = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "是否启用虚拟机环境兼容设置（禁用硬件光标，允许软件渲染，适配 VirtualBox / VMware / QEMU 等环境）。";
      };
    };

    sessionVariables = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "桌面会话所需的环境变量。";
    };

    settings = mkOption {
      type =
        with types;
        let
          valueType =
            nullOr (oneOf [
              bool
              int
              float
              str
              path
              (attrsOf valueType)
              (listOf valueType)
            ])
            // {
              description = "Hyprland configuration value";
            };
        in
        attrsOf valueType;
      default = { };
      description = "以 Nix 结构化数据编写的 Hyprland 配置，将与默认预设深度合并。";
    };

    extraBinds = mkOption {
      type = types.listOf (types.either types.str (types.attrsOf types.anything));
      default = [ ];
      description = "附加的按键绑定列表（追加至 settings.bind）。";
    };

    extraExecOnce = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "附加的自启动命令列表（追加至 settings.on 中的 hyprland.start）。";
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = "追加写入到 hyprland.lua 的额外原生配置文本。";
    };

    homeManager = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "若系统中启用了 Home Manager，是否自动将 Hyprland 配置注入到所有 Home Manager 用户中。";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      # 校验：虚拟机兼容模式只允许在虚拟机环境下开启
      assertions = [
        {
          assertion = cfg.virtualization.enable -> (
            if config ? base && config.base ? hardware && config.base.hardware ? type then
              config.base.hardware.type != "physical"
            else
              true
          );
          message = "桌面环境配置错误：Hyprland 虚拟机兼容模式 (desktop.windowManager.hyprland.virtualization.enable) 仅允许在虚拟机环境 (base.hardware.type != \"physical\") 下开启。";
        }
      ];

      # 1. 启用 NixOS 系统级 Hyprland 支持
      programs.hyprland = {
        enable = true;
        package = cfg.package;
        xwayland.enable = cfg.xwayland.enable;
      };

      # 2. 音频服务支持 (PipeWire + rtkit)
      security.rtkit.enable = mkIf cfg.audio.enable true;
      services.pipewire = mkIf cfg.audio.enable {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
      };

      # 3. 桌面配套常用工具包与 Wi-Fi 支持工具以及图标主题包与电源管理中心
      environment.systemPackages =
        let
          wlogoutMenuScript = pkgs.writeShellScriptBin "wlogout-menu" ''
            # 防止重复唤起
            if ${pkgs.procps}/bin/pidof wlogout >/dev/null 2>&1; then
              exit 0
            fi

            # 1. 隐藏 Waybar（向 waybar 发送 SIGUSR1 信号切换至隐藏状态）
            ${pkgs.procps}/bin/pkill -SIGUSR1 waybar 2>/dev/null || true

            # 2. 阻塞运行全屏电源中心 wlogout
            ${cfg.powerMenu.package}/bin/wlogout -b 5 -c 0 -r 0 -m 0 --protocol layer-shell "$@"

            # 3. 退出后恢复显示 Waybar（向 waybar 发送 SIGUSR1 信号恢复显示）
            ${pkgs.procps}/bin/pkill -SIGUSR1 waybar 2>/dev/null || true
          '';
        in
        (optionals cfg.defaultTools.enable cfg.defaultTools.packages)
        ++ (optionals cfg.wifi.enable cfg.wifi.packages)
        ++ (optionals cfg.iconTheme.enable [ cfg.iconTheme.package pkgs.hicolor-icon-theme ])
        ++ (optionals cfg.powerMenu.enable [ cfg.powerMenu.package wlogoutMenuScript ]);

      # 4. 可选的 NetworkManager Applet 系统级支持
      programs.nm-applet.enable = mkIf cfg.wifi.enable true;

      # 5. 会话环境变量
      environment.sessionVariables = mkMerge [
        {
          NIXOS_OZONE_WL = "1";
        }
        (mkIf cfg.iconTheme.enable {
          XCURSOR_THEME = cfg.iconTheme.name;
        })
        cfg.sessionVariables
        (mkIf cfg.virtualization.enable {
          WLR_NO_HARDWARE_CURSORS = "1";
          WLR_RENDERER_ALLOW_SOFTWARE = "1";
        })
      ];

      # 6. 系统级 Hyprland, Wofi, Waybar 与 Wlogout 配置文件部署
      environment.etc =
        let
          generatedText =
            toHyprlua {
              attrs = finalSettings;
            }
            + optionalString (cfg.extraConfig != "") "\n${cfg.extraConfig}";

          waybarConfText = builtins.toJSON {
            layer = "top";
            position = "top";
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
              "custom/power"
            ];
            "hyprland/workspaces" = {
              format = "{name}";
              on-click = "activate";
            };
            "hyprland/window" = {
              max-length = 50;
              separate-outputs = true;
            };
            clock = {
              format = "{:%Y-%m-%d %H:%M}";
              tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
            };
            cpu = {
              format = " {usage}%";
              tooltip = false;
            };
            memory = {
              format = " {}%";
            };
            temperature = {
              critical-threshold = 80;
              format = "{temperatureC}°C ";
            };
            battery = {
              states = {
                warning = 30;
                critical = 15;
              };
              format = "{icon} {capacity}%";
              format-charging = " {capacity}%";
              format-plugged = " {capacity}%";
              format-icons = [ "" "" "" "" "" ];
            };
            network = {
              format-wifi = " {essid} ({signalStrength}%)";
              format-ethernet = " {ipaddr}/{cidr}";
              format-disconnected = "⚠ Disconnected";
            };
            pulseaudio = {
              format = "{icon} {volume}%";
              format-muted = " Muted";
              format-icons = {
                default = [ "" "" "" ];
              };
              on-click = "pavucontrol";
            };
            tray = {
              spacing = 10;
            };
            "custom/power" = {
              format = "⏻";
              tooltip = false;
              on-click = "wlogout-menu";
            };
          };

          waybarStyleText = ''
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
            #clock, #battery, #cpu, #memory, #temperature, #network, #pulseaudio, #tray, #custom-power {
              padding: 0 10px;
              color: #ffffff;
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

          wlogoutLayoutText = builtins.toJSON [
            {
              label = "lock";
              action = "hyprlock || loginctl lock-session";
              text = "锁定 (Lock)";
              keybind = "l";
            }
            {
              label = "logout";
              action = "hyprctl dispatch exit || loginctl terminate-user $USER";
              text = "注销 (Logout)";
              keybind = "e";
            }
            {
              label = "suspend";
              action = "systemctl suspend";
              text = "睡眠 (Suspend)";
              keybind = "u";
            }
            {
              label = "hibernate";
              action = "systemctl hibernate";
              text = "休眠 (Hibernate)";
              keybind = "h";
            }
            {
              label = "reboot";
              action = "systemctl reboot";
              text = "重启 (Reboot)";
              keybind = "r";
            }
            {
              label = "shutdown";
              action = "systemctl poweroff";
              text = "关机 (Shutdown)";
              keybind = "s";
            }
          ];

          wlogoutStyleText = ''
            * {
              background-image: none;
              box-shadow: none;
            }
            window {
              background-color: rgba(12, 12, 12, 0.85);
            }
            button {
              border-radius: 12px;
              border-color: rgba(255, 255, 255, 0.1);
              text-decoration-color: #FFFFFF;
              color: #FFFFFF;
              background-color: rgba(30, 30, 30, 0.8);
              border-style: solid;
              border-width: 1px;
              background-repeat: no-repeat;
              background-position: center;
              background-size: 25%;
              margin: 12px;
              font-family: inherit;
              font-size: 16px;
              transition: all 0.2s ease-in-out;
            }
            button:focus, button:active, button:hover {
              background-color: rgba(65, 75, 110, 0.95);
              border-color: rgba(120, 160, 255, 0.8);
              outline-style: none;
            }
            #lock { background-image: image(url("${cfg.powerMenu.package}/share/wlogout/icons/lock.png")); }
            #logout { background-image: image(url("${cfg.powerMenu.package}/share/wlogout/icons/logout.png")); }
            #suspend { background-image: image(url("${cfg.powerMenu.package}/share/wlogout/icons/suspend.png")); }
            #hibernate { background-image: image(url("${cfg.powerMenu.package}/share/wlogout/icons/hibernate.png")); }
            #shutdown { background-image: image(url("${cfg.powerMenu.package}/share/wlogout/icons/shutdown.png")); }
            #reboot { background-image: image(url("${cfg.powerMenu.package}/share/wlogout/icons/reboot.png")); }
          '';
        in
        {
          "hypr/hyprland.lua".text = generatedText;
          "xdg/hypr/hyprland.lua".text = generatedText;
        }
        // (optionalAttrs cfg.wofi.enable {
          "wofi/config".text = wofiConfText;
          "xdg/wofi/config".text = wofiConfText;
        })
        // (optionalAttrs cfg.powerMenu.enable {
          "xdg/waybar/config.jsonc".text = waybarConfText;
          "xdg/waybar/config".text = waybarConfText;
          "xdg/waybar/style.css".text = waybarStyleText;
          "wlogout/layout".text = wlogoutLayoutText;
          "wlogout/style.css".text = wlogoutStyleText;
          "xdg/wlogout/layout".text = wlogoutLayoutText;
          "xdg/wlogout/style.css".text = wlogoutStyleText;
        });
    }

    # 7. Home Manager 自动联动
    (optionalAttrs (options ? home-manager) {
      home-manager = mkIf cfg.homeManager.enable {
        sharedModules = [
          ({ ... }: {
            wayland.windowManager.hyprland = {
              enable = true;
              # 使用 NixOS 系统级模块提供的 Hyprland 与 XDPH，避免包冲突
              package = null;
              portalPackage = null;
              configType = "lua";
              systemd = {
                enable = true;
                variables = [ "--all" ];
              };
              settings = finalSettings;
              extraConfig = cfg.extraConfig;
            };
            home.packages =
              let
                wlogoutMenuScript = pkgs.writeShellScriptBin "wlogout-menu" ''
                  # 防止重复唤起
                  if ${pkgs.procps}/bin/pidof wlogout >/dev/null 2>&1; then
                    exit 0
                  fi

                  # 1. 隐藏 Waybar（向 waybar 发送 SIGUSR1 信号切换至隐藏状态）
                  ${pkgs.procps}/bin/pkill -SIGUSR1 waybar 2>/dev/null || true

                  # 2. 阻塞运行全屏电源中心 wlogout
                  ${cfg.powerMenu.package}/bin/wlogout -b 5 -c 0 -r 0 -m 0 --protocol layer-shell "$@"

                  # 3. 退出后恢复显示 Waybar（向 waybar 发送 SIGUSR1 信号恢复显示）
                  ${pkgs.procps}/bin/pkill -SIGUSR1 waybar 2>/dev/null || true
                '';
              in
              (optionals cfg.defaultTools.enable cfg.defaultTools.packages)
              ++ (optionals cfg.wifi.enable cfg.wifi.packages)
              ++ (optionals cfg.iconTheme.enable [ cfg.iconTheme.package pkgs.hicolor-icon-theme ])
              ++ (optionals cfg.powerMenu.enable [ cfg.powerMenu.package wlogoutMenuScript ]);

            xdg.configFile = mkIf cfg.wofi.enable {
              "wofi/config".text = wofiConfText;
            };

            gtk = mkIf cfg.iconTheme.enable {
              enable = true;
              iconTheme = {
                name = cfg.iconTheme.name;
                package = cfg.iconTheme.package;
              };
            };
          })
        ];
      };
    })
  ]);
}
