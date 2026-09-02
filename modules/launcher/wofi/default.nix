{
  config,
  pkgs,
  lib,
  options,
  ...
}:

with lib;

let
  cfg = config.desktop.launcher.wofi;
  inline = lib.generators.mkLuaInline;

  defaultWofiSettings = {
    mode = cfg.mode;
    allow_images = cfg.allowImages;
    image_size = cfg.imageSize;
    insensitive = true;
    hide_scroll = true;
    term = cfg.terminal;
    gtk_dark = true;
  };
  mergedWofi = defaultWofiSettings // cfg.settings;
  renderWofiVal = v: if builtins.isBool v then (if v then "true" else "false") else toString v;
  wofiConfText = lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "${k}=${renderWofiVal v}") mergedWofi) + "\n";
in
{
  options.desktop.launcher.wofi = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "是否启用 Wofi 现代轻量级 Wayland 应用启动器与搜索菜单。";
    };

    package = mkPackageOption pkgs "wofi" { };

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

    terminal = mkOption {
      type = types.str;
      default = "${pkgs.kitty}/bin/kitty";
      description = "Wofi 调用的默认终端执行路径。";
    };

    settings = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "写入 /etc/wofi/config 及 /etc/xdg/wofi/config 的自定义配置项。";
    };

    hyprland = {
      keybind = mkOption {
        type = types.str;
        default = "SUPER + Space";
        description = "在 Hyprland 中唤起 Wofi 的快捷键绑定（设为空字符串则不注册）。";
      };
    };

    homeManager = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "若系统中启用了 Home Manager，是否自动将 Wofi 配置注入到所有 Home Manager 用户中。";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      environment.systemPackages = [
        cfg.package
      ];

      # 配置 XDG 默认终端规范 (xdg-terminal-exec)，确保 GLib/GIO 及 Wofi drun 模式正常拉起终端
      xdg.terminal-exec = {
        enable = true;
        settings = {
          default = [ "kitty.desktop" ];
          Hyprland = [ "kitty.desktop" ];
          hyprland = [ "kitty.desktop" ];
        };
      };

      environment.etc = {
        "wofi/config".text = wofiConfText;
        "xdg/wofi/config".text = wofiConfText;
      };

      # 联动向 Hyprland 注册快捷键
      desktop.windowManager.hyprland = mkIf (config ? desktop && config.desktop ? windowManager && config.desktop.windowManager ? hyprland && config.desktop.windowManager.hyprland.enable) {
        extraBinds = mkIf (cfg.hyprland.keybind != "") [
          { _args = [ (inline ''"${cfg.hyprland.keybind}"'') (inline ''hl.dsp.exec_cmd("wofi --show ${cfg.mode} --allow-images")'') ]; }
        ];
      };
    }

    (optionalAttrs (options ? home-manager) {
      home-manager = mkIf cfg.homeManager.enable {
        sharedModules = [
          ({ ... }: {
            home.packages = [ cfg.package ];
            xdg.configFile = {
              "wofi/config".text = wofiConfText;
              "xdg-terminals.list".text = "kitty.desktop\n";
              "hyprland-xdg-terminals.list".text = "kitty.desktop\n";
            };
          })
        ];
      };
    })
  ]);
}
