{
  config,
  pkgs,
  lib,
  options,
  ...
}:

with lib;

let
  cfg = config.desktop.theme;
in
{
  options.desktop.theme = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "是否启用统一的桌面视觉、图标与光标主题管理。";
    };

    icons = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否启用并配置桌面与 GTK 图标主题（如 Adwaita、hicolor-icon-theme）。";
      };

      package = mkPackageOption pkgs "adwaita-icon-theme" { };

      name = mkOption {
        type = types.str;
        default = "Adwaita";
        description = "默认图标主题名称。";
      };
    };

    cursor = {
      name = mkOption {
        type = types.str;
        default = "Adwaita";
        description = "默认光标主题名称。";
      };

      size = mkOption {
        type = types.int;
        default = 24;
        description = "默认光标尺寸大小。";
      };
    };

    homeManager = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "若系统中启用了 Home Manager，是否自动将主题配置注入到所有 Home Manager 用户中。";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      environment.systemPackages = optionals cfg.icons.enable [
        cfg.icons.package
        pkgs.hicolor-icon-theme
      ];

      environment.sessionVariables = {
        XCURSOR_THEME = cfg.cursor.name;
        XCURSOR_SIZE = toString cfg.cursor.size;
      };
    }

    (optionalAttrs (options ? home-manager) {
      home-manager = mkIf cfg.homeManager.enable {
        sharedModules = [
          ({ ... }: {
            home.packages = optionals cfg.icons.enable [
              cfg.icons.package
              pkgs.hicolor-icon-theme
            ];

            gtk = mkIf cfg.icons.enable {
              enable = true;
              iconTheme = {
                name = cfg.icons.name;
                package = cfg.icons.package;
              };
            };
          })
        ];
      };
    })
  ]);
}
