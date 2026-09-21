{
  config,
  pkgs,
  lib,
  options,
  ...
}:

with lib;

let
  cfg = config.desktop.trash.rip2;
in
{
  imports = [
    (lib.mkAliasOptionModule [ "desktop" "recycleBin" "rip2" ] [ "desktop" "trash" "rip2" ])
  ];

  options.desktop.trash.rip2 = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "是否启用 rip2 现代化安全命令行回收站工具（rm 安全替代品）。";
    };

    package = mkPackageOption pkgs "rip2" { };

    graveyard = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "自定义回收站目录路径（通过环境变量 RIP_GRAVEYARD 注入）。默认为 null（遵循 XDG 规范 $XDG_DATA_HOME/graveyard 或 /tmp/graveyard-$USER）。";
    };

    enableAliases = mkOption {
      type = types.bool;
      default = true;
      description = "是否为系统及用户 Shell 自动创建 rm 别名指向 rip，防止因手滑误删关键文件。";
    };

    homeManager = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "若系统中启用了 Home Manager，是否自动将 rip2 软件包、环境变量与别名注入到所有 Home Manager 用户中。";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      # 1. NixOS 系统级软件包安装
      environment.systemPackages = [
        cfg.package
      ];

      # 2. 会话环境变量（自定义 graveyard 路径）
      environment.sessionVariables = mkIf (cfg.graveyard != null) {
        RIP_GRAVEYARD = cfg.graveyard;
      };

      # 3. 系统级 Shell 快捷别名 (Bash, Zsh 等标准 Shell 继承)
      environment.shellAliases = mkIf cfg.enableAliases {
        rm = "rip";
      };

      # 4. 联动 Nushell 终端环境（若启用）
      desktop.terminal.nushell = mkIf (config ? desktop && config.desktop ? terminal && config.desktop.terminal ? nushell && config.desktop.terminal.nushell.enable && cfg.enableAliases) {
        shellAliases = {
          rm = "rip";
        };
      };
    }

    # 5. Home Manager 深度联动
    (optionalAttrs (options ? home-manager) {
      home-manager = mkIf cfg.homeManager.enable {
        sharedModules = [
          ({ ... }: {
            home.packages = [
              cfg.package
            ];

            home.sessionVariables = mkIf (cfg.graveyard != null) {
              RIP_GRAVEYARD = cfg.graveyard;
            };

            programs.bash.shellAliases = mkIf cfg.enableAliases {
              rm = "rip";
            };

            programs.zsh.shellAliases = mkIf cfg.enableAliases {
              rm = "rip";
            };

            programs.fish.shellAliases = mkIf cfg.enableAliases {
              rm = "rip";
            };

            programs.nushell = mkIf cfg.enableAliases {
              shellAliases = {
                rm = "rip";
              };
            };
          })
        ];
      };
    })
  ]);
}
