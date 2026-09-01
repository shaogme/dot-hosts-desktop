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

  toHyprconf =
    if lib ? hm && lib.hm ? generators && lib.hm.generators ? toHyprconf then
      lib.hm.generators.toHyprconf
    else
      {
        attrs,
        indentLevel ? 0,
        importantPrefixes ? [
          "$"
          "bezier"
          "monitor"
          "size"
        ],
      }:
      let
        initialIndent = concatStrings (replicate indentLevel "  ");

        toHyprconf' =
          indent: attrs:
          let
            isImportantField = n: _: any (prev: hasPrefix prev n) importantPrefixes;
            importantFields = filterAttrs isImportantField attrs;
            withoutImportantFields = fields: removeAttrs fields (attrNames importantFields);

            allSections = filterAttrs (_n: v: isAttrs v || (isList v && all isAttrs v)) attrs;
            sections = withoutImportantFields allSections;

            mkSection =
              n: attrs:
              if isList attrs then
                let
                  separator = "\n";
                in
                (concatMapStringsSep separator (a: mkSection n a) attrs)
              else if isAttrs attrs then
                ''
                  ${indent}${n} {
                  ${toHyprconf' "  ${indent}" attrs}${indent}}
                ''
              else
                toHyprconf' indent { ${n} = attrs; };

            mkFields = generators.toKeyValue {
              listsAsDuplicateKeys = true;
              inherit indent;
              mkKeyValue = generators.mkKeyValueDefault { } " = ";
            };

            allFields = filterAttrs (_n: v: !(isAttrs v || (isList v && all isAttrs v))) attrs;
            fields = withoutImportantFields allFields;
          in
          mkFields importantFields
          + concatStringsSep "\n" (mapAttrsToList mkSection sections)
          + mkFields fields;
      in
      toHyprconf' initialIndent attrs;

  # 默认的 Hyprland 桌面配置集合
  defaultSettings = {
    "$mod" = "SUPER";
    "$terminal" = "kitty";
    "$menu" = "wofi --show drun";

    monitor = [
      ",preferred,auto,auto"
    ];

    exec-once = [
      "waybar"
      "dunst"
    ];

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

    bind = [
      "$mod, Return, exec, $terminal"
      "$mod, Q, killactive,"
      "$mod, M, exit,"
      "$mod, Space, exec, $menu"
      "$mod, V, togglefloating,"
      "$mod, F, fullscreen,"

      # 窗口焦点移动
      "$mod, left, movefocus, l"
      "$mod, right, movefocus, r"
      "$mod, up, movefocus, u"
      "$mod, down, movefocus, d"
      "$mod, h, movefocus, l"
      "$mod, l, movefocus, r"
      "$mod, k, movefocus, u"
      "$mod, j, movefocus, d"

      # 工作区切换 (1-9)
      "$mod, 1, workspace, 1"
      "$mod, 2, workspace, 2"
      "$mod, 3, workspace, 3"
      "$mod, 4, workspace, 4"
      "$mod, 5, workspace, 5"
      "$mod, 6, workspace, 6"
      "$mod, 7, workspace, 7"
      "$mod, 8, workspace, 8"
      "$mod, 9, workspace, 9"

      # 移动活动窗口至工作区
      "$mod SHIFT, 1, movetoworkspace, 1"
      "$mod SHIFT, 2, movetoworkspace, 2"
      "$mod SHIFT, 3, movetoworkspace, 3"
      "$mod SHIFT, 4, movetoworkspace, 4"
      "$mod SHIFT, 5, movetoworkspace, 5"
      "$mod SHIFT, 6, movetoworkspace, 6"
      "$mod SHIFT, 7, movetoworkspace, 7"
      "$mod SHIFT, 8, movetoworkspace, 8"
      "$mod SHIFT, 9, movetoworkspace, 9"
    ];

    bindm = [
      "$mod, mouse:272, movewindow"
      "$mod, mouse:273, resizewindow"
    ];
  };

  # 虚拟机兼容模式环境配置
  virtualizationEnv = [
    "WLR_NO_HARDWARE_CURSORS,1"
    "WLR_RENDERER_ALLOW_SOFTWARE,1"
  ];

  # 合并默认配置、虚拟机配置与用户自定义 settings
  rawSettings = defaultSettings // (optionalAttrs cfg.virtualization.enable {
    env = (defaultSettings.env or [ ]) ++ virtualizationEnv;
  });

  mergedSettings = recursiveUpdate rawSettings cfg.settings;

  finalSettings = mergedSettings // {
    bind = (mergedSettings.bind or [ ]) ++ cfg.extraBinds;
    exec-once = (mergedSettings.exec-once or [ ]) ++ cfg.extraExecOnce;
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
      type = types.listOf types.str;
      default = [ ];
      description = "附加的按键绑定列表（追加至 settings.bind）。";
    };

    extraExecOnce = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "附加的自启动命令列表（追加至 settings.exec-once）。";
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = "追加写入到 hyprland.conf 的额外原生配置文本。";
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

      # 3. 桌面配套常用工具包
      environment.systemPackages = mkIf cfg.defaultTools.enable cfg.defaultTools.packages;

      # 4. 会话环境变量
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

      # 5. 系统级 Hyprland 配置文件部署
      environment.etc =
        let
          generatedText =
            toHyprconf {
              attrs = finalSettings;
            }
            + optionalString (cfg.extraConfig != "") "\n${cfg.extraConfig}";
        in
        {
          "hypr/hyprland.conf".text = generatedText;
          "xdg/hypr/hyprland.conf".text = generatedText;
        };
    }

    # 6. Home Manager 自动联动
    (optionalAttrs (options ? home-manager) {
      home-manager = mkIf cfg.homeManager.enable {
        sharedModules = [
          ({ ... }: {
            wayland.windowManager.hyprland = {
              enable = true;
              # 使用 NixOS 系统级模块提供的 Hyprland 与 XDPH，避免包冲突
              package = null;
              portalPackage = null;
              configType = "hyprlang";
              systemd = {
                enable = true;
                variables = [ "--all" ];
              };
              settings = finalSettings;
              extraConfig = cfg.extraConfig;
            };
            home.packages = mkIf cfg.defaultTools.enable cfg.defaultTools.packages;
          })
        ];
      };
    })
  ]);
}
