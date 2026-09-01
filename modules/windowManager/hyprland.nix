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
      { _args = [ (inline ''"SUPER + M"'') (inline ''hl.dsp.exit()'') ]; }
      { _args = [ (inline ''"SUPER + Space"'') (inline ''hl.dsp.exec_cmd("wofi --show drun")'') ]; }
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

      # 3. 桌面配套常用工具包与 Wi-Fi 支持工具
      environment.systemPackages =
        (optionals cfg.defaultTools.enable cfg.defaultTools.packages)
        ++ (optionals cfg.wifi.enable cfg.wifi.packages);

      # 4. 可选的 NetworkManager Applet 系统级支持
      programs.nm-applet.enable = mkIf cfg.wifi.enable true;

      # 5. 会话环境变量
      environment.sessionVariables = mkMerge [
        {
          NIXOS_OZONE_WL = "1";
        }
        cfg.sessionVariables
        (mkIf cfg.virtualization.enable {
          WLR_NO_HARDWARE_CURSORS = "1";
          WLR_RENDERER_ALLOW_SOFTWARE = "1";
        })
      ];

      # 6. 系统级 Hyprland 配置文件部署
      environment.etc =
        let
          generatedText =
            toHyprlua {
              attrs = finalSettings;
            }
            + optionalString (cfg.extraConfig != "") "\n${cfg.extraConfig}";
        in
        {
          "hypr/hyprland.lua".text = generatedText;
          "xdg/hypr/hyprland.lua".text = generatedText;
        };
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
              (optionals cfg.defaultTools.enable cfg.defaultTools.packages)
              ++ (optionals cfg.wifi.enable cfg.wifi.packages);
          })
        ];
      };
    })
  ]);
}
