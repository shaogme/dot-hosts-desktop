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

  toHyprlua = import ./lib/toHyprlua.nix { inherit lib; };
  defaultWindowRules = import ./rules;
  defaultSettings = import ./core/defaultSettings.nix { inherit cfg lib; };

  # 虚拟机兼容模式环境配置
  virtualizationEnv = [
    { _args = [ "WLR_NO_HARDWARE_CURSORS" "1" ]; }
    { _args = [ "WLR_RENDERER_ALLOW_SOFTWARE" "1" ]; }
  ];

  # 合并所有自启动命令 (autostart + extraExecOnce)
  allAutostartCommands = unique (cfg.autostart ++ cfg.extraExecOnce);

  # 将自启动命令集合格式化为 on.hyprland.start Lua 动作
  autostartOn = optional (allAutostartCommands != [ ]) {
    _args = [
      "hyprland.start"
      (inline ''
        function()
        ${concatMapStringsSep "\n" (cmd: "  hl.exec_cmd(${builtins.toJSON cmd})") allAutostartCommands}
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
    on = (mergedSettings.on or [ ]) ++ autostartOn;
    layerrule = (mergedSettings.layerrule or [ ]) ++ cfg.layerRules;
    windowrulev2 = unique (
      (optionals cfg.windowRules.enable defaultWindowRules)
      ++ (mergedSettings.windowrulev2 or [ ])
      ++ (cfg.settings.windowrulev2 or [ ])
      ++ cfg.extraRules
      ++ cfg.windowRules.extraRules
    );
  };

  generatedText =
    toHyprlua {
      attrs = finalSettings;
    }
    + optionalString (cfg.extraConfig != "") "\n${cfg.extraConfig}";
in
{
  options.desktop.windowManager.hyprland = {
    enable = mkEnableOption "Hyprland 现代化动态平铺 Wayland 合成器核心";

    package = mkPackageOption pkgs "hyprland" { };

    xwayland = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否启用 XWayland 兼容层支持。";
      };

      forceZeroScaling = mkOption {
        type = types.bool;
        default = true;
        description = "是否默认开启 XWayland 零缩放 (force_zero_scaling)，在高分屏与分数缩放下防止 XWayland 窗口字体与界面模糊。";
      };

      useNearestNeighbor = mkOption {
        type = types.bool;
        default = false;
        description = "XWayland 窗口在缩放时是否使用最近邻插值（适合像素风格应用与游戏，默认为 false 以保证平滑渲染）。";
      };
    };

    windowRules = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否启用默认的精细化窗口规则集合（优化常见 X11/Qt/GTK 框架应用、弹窗、文件选择器及对话框）。";
      };

      extraRules = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "附加的自定义窗口规则列表（追加写入 windowrulev2）。";
      };
    };

    extraRules = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "快捷注册的自定义窗口规则列表（追加写入 windowrulev2）。";
    };

    layerRules = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "附加的图层规则列表（追加写入 layerrule）。";
    };

    autostart = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "在 Hyprland 启动时自启动执行的命令列表。";
    };

    extraExecOnce = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "附加的自启动命令列表（等同于 autostart，写入 settings.on 中的 hyprland.start）。";
    };

    extraBinds = mkOption {
      type = types.listOf (types.either types.str (types.attrsOf types.anything));
      default = [ ];
      description = "附加的按键绑定列表（追加至 settings.bind）。";
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = "追加写入到 hyprland.lua 的额外原生配置文本。";
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

      # 2. 基础 Wayland 桌面配套工具 (Kitty 终端、剪贴板、截图工具)
      environment.systemPackages = with pkgs; [
        kitty
        wl-clipboard
        grim
        slurp
      ];

      # 3. 会话环境变量
      environment.sessionVariables = mkMerge [
        {
          NIXOS_OZONE_WL = "1";
          QT_QPA_PLATFORM = "wayland;xcb";
          QT_AUTO_SCREEN_SCALE_FACTOR = "1";
          QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
          QT_SCALE_FACTOR_ROUNDING_POLICY = "PassThrough";
          GDK_BACKEND = "wayland,x11";
          CLUTTER_BACKEND = "wayland";
          SDL_VIDEODRIVER = "wayland,x11,windows";
          _JAVA_AWT_WM_NONREPARENTING = "1";
          ELECTRON_OZONE_PLATFORM_HINT = "auto";
        }
        cfg.sessionVariables
        (mkIf cfg.virtualization.enable {
          WLR_NO_HARDWARE_CURSORS = "1";
          WLR_RENDERER_ALLOW_SOFTWARE = "1";
        })
      ];

      # 4. 系统级 Hyprland 配置文件部署
      environment.etc = {
        "hypr/hyprland.lua".text = generatedText;
        "xdg/hypr/hyprland.lua".text = generatedText;
      };
    }

    # 5. Home Manager 自动联动
    (optionalAttrs (options ? home-manager) {
      home-manager = mkIf cfg.homeManager.enable {
        sharedModules = [
          ({ ... }: {
            wayland.windowManager.hyprland = {
              enable = true;
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
            home.packages = with pkgs; [
              kitty
              wl-clipboard
              grim
              slurp
            ];
          })
        ];
      };
    })
  ]);
}
