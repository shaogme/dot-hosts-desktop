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

  availableThemes = import ./themes { inherit pkgs lib config; };
  selectedTheme = availableThemes.${cfg.theme} or availableThemes.default-theme;

  mergedSettings = recursiveUpdate selectedTheme.settings cfg.settings;
  waybarConfText = builtins.toJSON mergedSettings;

  finalStyleText =
    (if cfg.style != "" then cfg.style else selectedTheme.style)
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

    theme = mkOption {
      type = types.str;
      default = "default-theme";
      description = "Waybar 视觉子主题方案。默认使用 default-theme（极简多胶囊浮动主题，复刻 V7 并集成通知中心与全套快捷控制）。";
    };

    position = mkOption {
      type = types.enum [ "top" "bottom" "left" "right" ];
      default = "top";
      description = "状态栏放置屏幕边缘方位。";
    };

    settings = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "以 Nix 结构化数据编写的 Waybar 模块配置，将与所选子主题预设深度合并。";
    };

    style = mkOption {
      type = types.lines;
      default = "";
      description = "自定义 Waybar CSS 样式表内容（若设置则完全替换子主题预设）。";
    };

    extraStyle = mkOption {
      type = types.lines;
      default = "";
      description = "追加到 Waybar 样式表的自定义 CSS 规则。";
    };

    commands = {
      menu = mkOption {
        type = types.str;
        default = "anyrun";
        description = "点击菜单图标执行的应用启动器命令行。";
      };

      terminal = mkOption {
        type = types.str;
        default = "ghostty";
        description = "右键菜单图标执行的终端命令行。";
      };

      cpu = mkOption {
        type = types.str;
        default = "ghostty -e btop";
        description = "点击 CPU 监控模块执行的性能监控命令行。";
      };

      memory = mkOption {
        type = types.str;
        default = "ghostty -e btop";
        description = "点击内存监控模块执行的性能监控命令行。";
      };

      network = mkOption {
        type = types.str;
        default = "ghostty -e nmtui";
        description = "点击网络状态模块执行的网络配置命令行。";
      };

      bluetooth = mkOption {
        type = types.str;
        default = "ghostty -e bluetuith";
        description = "点击蓝牙状态模块执行的蓝牙管理命令行。";
      };

      audioControl = mkOption {
        type = types.str;
        default = "pavucontrol";
        description = "点击音量控制模块执行的音频控制台命令行。";
      };

      audioMuteToggle = mkOption {
        type = types.str;
        default = "pamixer -t";
        description = "右键音量控制模块执行的静音切换命令行。";
      };

      powerMenu = mkOption {
        type = types.str;
        default = "anyrun-power";
        description = "点击电源管理按钮执行的电源菜单命令行。";
      };
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
      ] ++ selectedTheme.extraPackages;

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
            home.packages = [ cfg.package ] ++ selectedTheme.extraPackages;
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
