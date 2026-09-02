{
  config,
  pkgs,
  lib,
  options,
  ...
}:

with lib;

let
  cfg = config.desktop.launcher.anyrun;
  inline = lib.generators.mkLuaInline;
  themes = import ./themes.nix;
  svgIcons = import ./icons.nix { inherit pkgs; };

  # 专用电源管理菜单包装脚本（纯净文本，无 emoji）
  anyrunPowerScript = pkgs.writeShellScriptBin "anyrun-power" ''
    OPTIONS="锁定屏幕 (Lock)
注销登录 (Logout)
睡眠挂起 (Suspend)
休眠挂起 (Hibernate)
重启系统 (Reboot)
关闭计算机 (Shutdown)"

    CHOICE=$(echo "$OPTIONS" | ${cfg.package}/bin/anyrun --plugins libstdin.so)

    case "$CHOICE" in
      *"锁定屏幕"*)
        hyprlock || loginctl lock-session
        ;;
      *"注销登录"*)
        hyprctl dispatch exit || loginctl terminate-user $USER
        ;;
      *"睡眠挂起"*)
        systemctl suspend
        ;;
      *"休眠挂起"*)
        systemctl hibernate
        ;;
      *"重启系统"*)
        systemctl reboot
        ;;
      *"关闭计算机"*)
        systemctl poweroff
        ;;
    esac
  '';

  # 转换 numeric 位置与尺寸为 RON 格式
  renderNumeric = num:
    if num ? absolute && num.absolute != null then
      "Absolute(${toString num.absolute})"
    else if num ? fraction && num.fraction != null then
      "Fraction(${toString num.fraction})"
    else
      "Absolute(0)";

  # 转换 bool 为 RON 字符串
  renderBool = b: if b then "true" else "false";

  # 映射 Layer 与 KeyboardMode 为 RON 枚举格式
  renderLayer = l: {
    background = "Background";
    bottom = "Bottom";
    top = "Top";
    overlay = "Overlay";
  }.${l} or "Overlay";

  renderKeyboardMode = m: {
    exclusive = "Exclusive";
    on-demand = "OnDemand";
  }.${m} or "Exclusive";

  # 转换 plugin 列表为 RON 格式
  renderPlugins = plugins:
    "[\n"
    + concatMapStringsSep ",\n" (p: "    \"${toString p}\"") plugins
    + "\n  ]";

  # 生成主配置 config.ron
  defaultConfigRon = ''
    Config(
      x: ${renderNumeric cfg.position.x},
      y: ${renderNumeric cfg.position.y},
      width: ${renderNumeric cfg.position.width},
      height: ${renderNumeric cfg.position.height},
      hide_icons: ${renderBool cfg.hideIcons},
      ignore_exclusive_zones: ${renderBool cfg.ignoreExclusiveZones},
      layer: ${renderLayer cfg.layer},
      keyboard_mode: ${renderKeyboardMode cfg.keyboardMode},
      hide_plugin_info: ${renderBool cfg.hidePluginInfo},
      close_on_click: ${renderBool cfg.closeOnClick},
      show_results_immediately: ${renderBool cfg.showResultsImmediately},
      max_entries: ${if cfg.maxEntries == null then "None" else "Some(${toString cfg.maxEntries})"},
      plugins: ${renderPlugins cfg.plugins},
      ${optionalString (cfg.extraLines != "") cfg.extraLines}
      keybinds: [
        Keybind(
          key: "Return",
          action: Select,
        ),
        Keybind(
          key: "Up",
          action: Up,
        ),
        Keybind(
          key: "Down",
          action: Down,
        ),
        Keybind(
          key: "ISO_Left_Tab",
          action: Up,
          shift: true,
        ),
        Keybind(
          key: "Tab",
          action: Down,
        ),
        Keybind(
          key: "Escape",
          action: Close,
        ),
      ],
    )
  '';

  # 生成 GTK4 CSS 样式
  styleCss = themes.generateCss {
    themeName = cfg.theme;
    extraCss = cfg.extraCss;
  };

  # 默认插件配置文件定义
  defaultApplicationsRon = ''
    Config(
      desktop_actions: true,
      max_entries: 5,
      hide_description: false,
      terminal: Some(Terminal(
        command: "${cfg.terminal.command}",
        args: "${cfg.terminal.args}",
      )),
    )
  '';

  defaultActionsRon = ''
    Config(
      enable_power_actions: false,
      custom_actions: [
        (
          title: "锁定屏幕",
          command: "hyprlock || loginctl lock-session",
          description: "锁定当前桌面会话",
          icon: "${svgIcons}/icons/lock.svg",
          confirm: false,
        ),
        (
          title: "注销登录",
          command: "hyprctl dispatch exit || loginctl terminate-user $USER",
          description: "退出当前用户桌面会话",
          icon: "${svgIcons}/icons/logout.svg",
          confirm: true,
        ),
        (
          title: "睡眠",
          command: "systemctl suspend",
          description: "挂起系统到内存 (RAM)",
          icon: "${svgIcons}/icons/suspend.svg",
          confirm: false,
        ),
        (
          title: "休眠",
          command: "systemctl hibernate",
          description: "挂起系统到硬盘 (Disk)",
          icon: "${svgIcons}/icons/hibernate.svg",
          confirm: false,
        ),
        (
          title: "重启系统",
          command: "systemctl reboot",
          description: "重新启动计算机",
          icon: "${svgIcons}/icons/reboot.svg",
          confirm: true,
        ),
        (
          title: "关闭计算机",
          command: "systemctl poweroff",
          description: "关闭计算机电源",
          icon: "${svgIcons}/icons/shutdown.svg",
          confirm: true,
        ),
      ],
    )
  '';

  defaultShellRon = ''
    Config(
      prefix: ":sh",
      shell: None,
    )
  '';

  defaultSymbolsRon = ''
    Config(
      prefix: ":sym",
      symbols: {},
      max_entries: 5,
    )
  '';

  defaultTranslateRon = ''
    Config(
      prefix: ":tr",
      language_delimiter: ">",
      max_entries: 3,
    )
  '';

  defaultStdinRon = ''
    Config(
      allow_invalid: false,
      max_entries: 10,
      preserve_order: false,
    )
  '';

  defaultWebsearchRon = ''
    Config(
      prefix: "?",
      engines: [DuckDuckGo],
    )
  '';

  # 基础配置文件集合
  baseConfigFiles = {
    "anyrun/config.ron".text = defaultConfigRon;
    "anyrun/style.css".text = styleCss;
    "anyrun/applications.ron".text = defaultApplicationsRon;
    "anyrun/actions.ron".text = defaultActionsRon;
    "anyrun/shell.ron".text = defaultShellRon;
    "anyrun/symbols.ron".text = defaultSymbolsRon;
    "anyrun/translate.ron".text = defaultTranslateRon;
    "anyrun/stdin.ron".text = defaultStdinRon;
    "anyrun/websearch.ron".text = defaultWebsearchRon;
  };

  # 合并用户额外自定义配置文件
  normalizedExtraConfigs = mapAttrs' (
    name: val:
    nameValuePair "anyrun/${name}" (if isAttrs val && val ? text then val else { text = val; })
  ) cfg.extraConfigFiles;

  allConfigFiles = baseConfigFiles // normalizedExtraConfigs;

  # 构建 /etc 及 /etc/xdg 路径映射
  etcConfigFiles = (mapAttrs' (name: val: nameValuePair name val) allConfigFiles)
    // (mapAttrs' (name: val: nameValuePair "xdg/${name}" val) allConfigFiles);
in
{
  options.desktop.launcher.anyrun = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "是否启用 Anyrun 现代轻量级 Wayland 原生应用启动器与快速搜索菜单。";
    };

    package = mkPackageOption pkgs "anyrun" { };

    terminal = {
      command = mkOption {
        type = types.str;
        default = "ghostty";
        description = "Anyrun 运行终端应用时调用的终端命令行或可执行文件路径。";
      };

      args = mkOption {
        type = types.str;
        default = "-e {}";
        description = "Anyrun 调用终端时传递的参数模板。";
      };
    };

    daemon = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否以 systemd 用户服务形式运行 Anyrun 守护进程（大幅提升呼出速度并支持剪贴板）。";
      };
    };

    theme = mkOption {
      type = types.enum [ "default-theme" "catppuccin-mocha" "tokyo-night" "nord" ];
      default = "default-theme";
      description = "Anyrun 启动器视觉主题配色方案。默认使用 default-theme（与 Waybar default-theme 风格统一）。";
    };

    position = {
      x = mkOption {
        type = types.submodule {
          options = {
            fraction = mkOption {
              type = types.nullOr types.float;
              default = 0.5;
              description = "水平位置屏幕占比 (0.0 - 1.0)，0.5 为居中。";
            };
            absolute = mkOption {
              type = types.nullOr types.int;
              default = null;
              description = "水平位置绝对像素偏移。";
            };
          };
        };
        default = { fraction = 0.5; };
        description = "Anyrun 窗口的水平位置。";
      };

      y = mkOption {
        type = types.submodule {
          options = {
            fraction = mkOption {
              type = types.nullOr types.float;
              default = 0.3;
              description = "垂直位置屏幕占比 (0.0 - 1.0)。";
            };
            absolute = mkOption {
              type = types.nullOr types.int;
              default = null;
              description = "垂直位置绝对像素偏移。";
            };
          };
        };
        default = { fraction = 0.3; };
        description = "Anyrun 窗口的垂直位置。";
      };

      width = mkOption {
        type = types.submodule {
          options = {
            fraction = mkOption {
              type = types.nullOr types.float;
              default = null;
              description = "窗口宽度屏幕占比 (0.0 - 1.0)。";
            };
            absolute = mkOption {
              type = types.nullOr types.int;
              default = 800;
              description = "窗口绝对像素宽度。";
            };
          };
        };
        default = { absolute = 800; };
        description = "Anyrun 窗口的宽度。";
      };

      height = mkOption {
        type = types.submodule {
          options = {
            fraction = mkOption {
              type = types.nullOr types.float;
              default = null;
              description = "窗口高度屏幕占比 (0.0 - 1.0)。";
            };
            absolute = mkOption {
              type = types.nullOr types.int;
              default = 1;
              description = "窗口最小绝对像素高度（设为 1 则按内容自适应高度）。";
            };
          };
        };
        default = { absolute = 1; };
        description = "Anyrun 窗口的最小高度。";
      };
    };

    hideIcons = mkOption {
      type = types.bool;
      default = false;
      description = "是否隐藏匹配项与插件信息图标。";
    };

    hidePluginInfo = mkOption {
      type = types.bool;
      default = false;
      description = "是否隐藏插件信息面板。";
    };

    ignoreExclusiveZones = mkOption {
      type = types.bool;
      default = false;
      description = "是否忽略屏幕专属区域（如 Waybar 状态栏）。";
    };

    closeOnClick = mkOption {
      type = types.bool;
      default = true;
      description = "在窗口外部区域点击时是否自动关闭 Anyrun。";
    };

    showResultsImmediately = mkOption {
      type = types.bool;
      default = false;
      description = "在 Anyrun 启动时是否立即显示前置搜索结果。";
    };

    maxEntries = mkOption {
      type = types.nullOr types.int;
      default = null;
      description = "限制搜索结果最大展示条目数量（null 表示不限制）。";
    };

    layer = mkOption {
      type = types.enum [ "background" "bottom" "top" "overlay" ];
      default = "overlay";
      description = "Layer shell 图层层级。";
    };

    keyboardMode = mkOption {
      type = types.enum [ "exclusive" "on-demand" ];
      default = "exclusive";
      description = "Layer shell 键盘捕获模式。";
    };

    plugins = mkOption {
      type = types.listOf (types.either types.str types.package);
      default = [
        "${cfg.package}/lib/libapplications.so"
        "${cfg.package}/lib/libactions.so"
        "${cfg.package}/lib/libsymbols.so"
        "${cfg.package}/lib/librink.so"
        "${cfg.package}/lib/libshell.so"
        "${cfg.package}/lib/libtranslate.so"
        "${cfg.package}/lib/libstdin.so"
        "${cfg.package}/lib/libwebsearch.so"
      ];
      description = "Anyrun 加载的插件动态库路径列表。";
    };

    extraLines = mkOption {
      type = types.lines;
      default = "";
      description = "追加写入 config.ron 的自定义 RON 配置片段。";
    };

    extraCss = mkOption {
      type = types.lines;
      default = "";
      description = "追加写入 style.css 的自定义 GTK4 CSS 样式。";
    };

    extraConfigFiles = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "额外写入 anyrun 配置目录的自定义配置文件集合（如 plugin-name.ron）。";
    };

    hyprland = {
      keybind = mkOption {
        type = types.str;
        default = "SUPER + Space";
        description = "在 Hyprland 中唤起 Anyrun 启动器的快捷键绑定（设为空字符串则不注册）。";
      };

      powerKeybinds = mkOption {
        type = types.listOf types.str;
        default = [ "SUPER + M" "XF86PowerOff" ];
        description = "在 Hyprland 中唤起 Anyrun 电源管理菜单的快捷键列表。";
      };

      blur = mkOption {
        type = types.bool;
        default = true;
        description = "是否自动向 Hyprland 注册 anyrun layer_rule 背景毛玻璃模糊。";
      };
    };

    homeManager = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "若系统中启用了 Home Manager，是否自动将 Anyrun 配置注入到所有 Home Manager 用户中。";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      environment.systemPackages = [
        cfg.package
        anyrunPowerScript
      ];

      # 配置 XDG 默认终端规范 (xdg-terminal-exec)，确保 GLib/GIO 及 Anyrun drun/applications 模式正常拉起终端
      xdg.terminal-exec = {
        enable = true;
        settings = {
          default = [
            "com.mitchellh.ghostty.desktop"
            "ghostty.desktop"
          ];
          Hyprland = [
            "com.mitchellh.ghostty.desktop"
            "ghostty.desktop"
          ];
          hyprland = [
            "com.mitchellh.ghostty.desktop"
            "ghostty.desktop"
          ];
        };
      };

      # 系统级 systemd 用户守护进程服务
      systemd.user.services.anyrun = mkIf cfg.daemon.enable {
        description = "Anyrun Runner Daemon";
        partOf = [ "graphical-session.target" ];
        after = [ "graphical-session.target" ];
        serviceConfig = {
          Type = "simple";
          ExecStart = "${cfg.package}/bin/anyrun daemon";
          Restart = "on-failure";
          KillMode = "process";
        };
        wantedBy = [ "graphical-session.target" ];
      };

      environment.etc = etcConfigFiles;

      # 联动向 Hyprland 注册快捷键与图层毛玻璃规则
      desktop.windowManager.hyprland = mkIf (config ? desktop && config.desktop ? windowManager && config.desktop.windowManager ? hyprland && config.desktop.windowManager.hyprland.enable) {
        layerRules = optionals cfg.hyprland.blur [
          {
            match = {
              namespace = "anyrun";
            };
            blur = true;
            ignore_alpha = 0;
          }
        ];
        extraBinds =
          (optional (cfg.hyprland.keybind != "") {
            _args = [ (inline ''"${cfg.hyprland.keybind}"'') (inline ''hl.dsp.exec_cmd("anyrun")'') ];
          })
          ++ (map (bindStr: {
            _args = [ (inline ''"${bindStr}"'') (inline ''hl.dsp.exec_cmd("anyrun-power")'') ];
          }) cfg.hyprland.powerKeybinds);
      };
    }

    (optionalAttrs (options ? home-manager) {
      home-manager = mkIf cfg.homeManager.enable {
        sharedModules = [
          ({ ... }: {
            home.packages = [ cfg.package anyrunPowerScript ];

            systemd.user.services.anyrun = mkIf cfg.daemon.enable {
              Unit = {
                Description = "Anyrun Runner Daemon";
                PartOf = [ "graphical-session.target" ];
                After = [ "graphical-session.target" ];
              };
              Service = {
                Type = "simple";
                ExecStart = "${cfg.package}/bin/anyrun daemon";
                Restart = "on-failure";
                KillMode = "process";
              };
              Install = {
                WantedBy = [ "graphical-session.target" ];
              };
            };

            xdg.configFile = allConfigFiles // {
              "xdg-terminals.list".text = "com.mitchellh.ghostty.desktop\nghostty.desktop\n";
              "hyprland-xdg-terminals.list".text = "com.mitchellh.ghostty.desktop\nghostty.desktop\n";
            };
          })
        ];
      };
    })
  ]);
}
