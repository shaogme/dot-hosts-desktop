{ config, pkgs, lib, options, ... }:

with lib;

let
  cfg = config.desktop.terminal.starship;
in
{
  options.desktop.terminal.starship = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "是否启用 Starship 现代化极速跨 Shell 提示符（默认关闭）。";
    };

    package = mkOption {
      type = types.package;
      default = pkgs.starship;
      defaultText = literalExpression "pkgs.starship";
      description = "使用的 Starship 软件包。";
    };

    enableZshIntegration = mkOption {
      type = types.bool;
      default = true;
      description = "是否自动集成进 Zsh（在 Zsh 启动时加载 Starship 提示符环境）。";
    };

    enableBashIntegration = mkOption {
      type = types.bool;
      default = true;
      description = "是否自动集成进 Bash。";
    };

    enableFishIntegration = mkOption {
      type = types.bool;
      default = true;
      description = "是否自动集成进 Fish。";
    };

    settings = mkOption {
      type = types.attrsOf types.anything;
      default = {
        add_newline = true;
        character = {
          success_symbol = "[➜](bold green)";
          error_symbol = "[✗](bold red)";
        };
        directory = {
          truncation_length = 4;
          truncate_to_repo = true;
          style = "bold cyan";
        };
        git_branch = {
          symbol = " ";
          style = "bold purple";
        };
        git_status = {
          style = "bold red";
        };
        nix_shell = {
          symbol = " ";
          style = "bold blue";
          format = "via [$symbol$state(\\($name\\))]($style) ";
        };
        cmd_duration = {
          min_time = 2000;
          style = "bold yellow";
        };
      };
      description = "Starship 结构化配置选项（将自动渲染为 starship.toml）。";
    };

    homeManager = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "若系统中启用了 Home Manager，是否自动将 Starship 及其 Shell 集成应用到所有 Home Manager 用户。";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      # 1. NixOS 系统级 Starship 支持
      programs.starship = {
        enable = true;
        package = cfg.package;
        settings = cfg.settings;
      };

      # 2. 系统级软件包
      environment.systemPackages = [
        cfg.package
      ];
    }

    # 3. Home Manager 用户级 Starship 支持与 Zsh 自动深度集成
    (optionalAttrs (options ? home-manager) {
      home-manager = mkIf cfg.homeManager.enable {
        sharedModules = [
          ({ ... }: {
            programs.starship = {
              enable = true;
              package = cfg.package;
              enableZshIntegration = cfg.enableZshIntegration;
              enableBashIntegration = cfg.enableBashIntegration;
              enableFishIntegration = cfg.enableFishIntegration;
              settings = cfg.settings;
            };
          })
        ];
      };
    })
  ]);
}
