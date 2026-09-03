{
  config,
  pkgs,
  lib,
  options,
  ...
}:

with lib;

let
  cfg = config.desktop.wallpaper.wallpapers;

  defaultSource = import ./default-source.nix { inherit pkgs lib; };
in
{
  options.desktop.wallpaper.wallpapers = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "是否启用系统桌面壁纸统一资源与集合管理模块。";
    };

    default = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否启用通过 npins 跟踪维护的预置自然风光壁纸资源包 (default-source)。";
      };

      package = mkOption {
        type = types.package;
        default = defaultSource.package;
        description = "预置的默认壁纸集合软件包。";
      };
    };

    defaultWallpaper = mkOption {
      type = types.nullOr (types.either types.path types.str);
      default = if cfg.default.enable then defaultSource.defaultWallpaper else null;
      description = "系统全局默认壁纸图片文件路径。";
    };

    wallpaperDir = mkOption {
      type = types.nullOr (types.either types.path types.str);
      default = "/run/current-system/sw/share/wallpapers";
      description = "系统壁纸统一存放与索引目录。";
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "用户自定义附加安装的壁纸软件包列表。";
    };

    packages = mkOption {
      type = types.listOf types.package;
      default = (optional cfg.default.enable cfg.default.package) ++ cfg.extraPackages;
      defaultText = literalExpression "汇总后的全部启用壁纸包";
      description = "系统全局安装的壁纸资源包集合。";
    };

    homeManager = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "若系统中启用了 Home Manager，是否自动将壁纸资源与环境信息同步至用户环境。";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      # 系统级安装壁纸软件包，系统构建时将自动软链接到 /run/current-system/sw/share/wallpapers
      environment.systemPackages = cfg.packages;

      environment.sessionVariables = optionalAttrs (cfg.wallpaperDir != null) {
        NIX_WALLPAPERS_DIR = toString cfg.wallpaperDir;
      } // optionalAttrs (cfg.defaultWallpaper != null) {
        DEFAULT_WALLPAPER = toString cfg.defaultWallpaper;
      };
    }

    (optionalAttrs (options ? home-manager) {
      home-manager = mkIf cfg.homeManager.enable {
        sharedModules = [
          ({ ... }: {
            home.packages = cfg.packages;
            home.sessionVariables = optionalAttrs (cfg.wallpaperDir != null) {
              NIX_WALLPAPERS_DIR = toString cfg.wallpaperDir;
            } // optionalAttrs (cfg.defaultWallpaper != null) {
              DEFAULT_WALLPAPER = toString cfg.defaultWallpaper;
            };
          })
        ];
      };
    })
  ]);
}
