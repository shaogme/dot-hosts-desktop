{
  config,
  pkgs,
  lib,
  options,
  ...
}:

with lib;

let
  cfg = config.desktop.notification.dunst;
in
{
  options.desktop.notification.dunst = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "是否启用 Dunst 轻量级现代化桌面通知守护进程。";
    };

    package = mkPackageOption pkgs "dunst" { };

    hyprland = {
      autostart = mkOption {
        type = types.bool;
        default = true;
        description = "是否在 Hyprland 启动时自动拉起 Dunst。";
      };
    };

    homeManager = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "若系统中启用了 Home Manager，是否自动将 Dunst 注入到所有 Home Manager 用户中。";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      environment.systemPackages = [
        cfg.package
        pkgs.libnotify
      ];

      # 联动向 Hyprland 注册自启动
      desktop.windowManager.hyprland = mkIf (config ? desktop && config.desktop ? windowManager && config.desktop.windowManager ? hyprland && config.desktop.windowManager.hyprland.enable) {
        autostart = mkIf cfg.hyprland.autostart [
          "dunst"
        ];
      };
    }

    (optionalAttrs (options ? home-manager) {
      home-manager = mkIf cfg.homeManager.enable {
        sharedModules = [
          ({ ... }: {
            home.packages = [ cfg.package pkgs.libnotify ];
          })
        ];
      };
    })
  ]);
}
