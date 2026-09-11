{ config, pkgs, lib, options, ... }:

with lib;

let
  cfg = config.desktop.terminal.nushell;

  # 历史记录配置合并
  finalSettings = recursiveUpdate {
    history = {
      max_size = cfg.history.maxSize;
      file_format = cfg.history.fileFormat;
      sync_on_enter = cfg.history.syncOnEnter;
      isolation = cfg.history.isolation;
    };
  } cfg.settings;
in
{
  options.desktop.terminal.nushell = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "是否启用 Nushell 现代化结构化终端 Shell 及深度环境配置（默认关闭）。";
    };

    package = mkOption {
      type = types.package;
      default = pkgs.nushell;
      defaultText = literalExpression "pkgs.nushell";
      description = "使用的 Nushell 软件包。";
    };

    setAsDefaultShell = mkOption {
      type = types.bool;
      default = true;
      description = "是否将 Nushell 设置为系统及用户的默认登录 Shell。";
    };

    plugins = mkOption {
      type = types.listOf types.package;
      default = with pkgs.nushellPlugins; [
        formats
        query
      ];
      defaultText = literalExpression "with pkgs.nushellPlugins; [ formats query ]";
      description = "系统与用户 Nushell 启用的官方/第三方二进制插件列表。";
    };

    history = {
      maxSize = mkOption {
        type = types.int;
        default = 100000;
        description = "历史记录中保留的最大命令条目数。";
      };

      fileFormat = mkOption {
        type = types.enum [ "plaintext" "sqlite" ];
        default = "plaintext";
        description = "历史记录文件格式（plaintext 文本格式或 sqlite 数据库格式）。";
      };

      syncOnEnter = mkOption {
        type = types.bool;
        default = true;
        description = "按回车执行命令时是否立即同步写入历史记录文件。";
      };

      isolation = mkOption {
        type = types.bool;
        default = false;
        description = "是否开启不同终端会话之间的历史记录隔离（默认 false，会话间实时共享历史）。";
      };
    };

    shellAliases = mkOption {
      type = types.attrsOf types.str;
      default = {
        ".." = "cd ..";
        "..." = "cd ../..";
        "l" = "ls -la";
        "ll" = "ls -l";
        "la" = "ls -a";
        "cls" = "clear";
      };
      description = "Nushell 快捷别名（Shell Aliases）映射配置。";
    };

    environmentVariables = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "Nushell 环境变量字典（通过 Home Manager load-env 注入 Nushell 会话）。";
    };

    sessionVariables = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Nushell 系统级会话环境变量字典（自动注入 environment.sessionVariables）。";
    };

    settings = mkOption {
      type = types.attrsOf types.anything;
      default = {
        show_banner = false;
        table = {
          mode = "rounded";
        };
      };
      description = "Nushell 核心配置选项字典（将自动展开并映射至 $env.config 中）。";
    };

    configFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "自定义 Nushell config.nu 配置文件路径（若指定则作为 source 引入）。";
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = "追加到 config.nu 交互式配置末尾的原生 Nushell 脚本内容。";
    };

    envFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "自定义 Nushell env.nu 环境配置文件路径。";
    };

    extraEnv = mkOption {
      type = types.lines;
      default = "";
      description = "追加到 env.nu 环境配置末尾的原生 Nushell 脚本内容。";
    };

    loginFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "自定义 Nushell login.nu 登录环境配置文件路径。";
    };

    extraLogin = mkOption {
      type = types.lines;
      default = "";
      description = "追加到 login.nu 登录环境配置末尾的原生 Nushell 脚本内容。";
    };

    homeManager = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "若系统中启用了 Home Manager，是否自动将 Nushell 深度配置应用到所有 Home Manager 用户。";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      # 1. NixOS 系统级 Nushell 支持（插件注册与 Vendor Autoload）
      programs.nushell = {
        enable = true;
        package = cfg.package;
        plugins = cfg.plugins;
      };

      # 2. 将 Nushell 设置为系统及用户的默认登录 Shell 与系统合法 Shell
      users.defaultUserShell = mkIf cfg.setAsDefaultShell cfg.package;
      environment.shells = [ cfg.package ];

      # 3. 系统级辅助软件包
      environment.systemPackages = [
        cfg.package
      ] ++ cfg.plugins;

      # 4. 会话环境变量
      environment.sessionVariables = cfg.sessionVariables // (filterAttrs (_: v: isString v) cfg.environmentVariables);
    }

    # 5. Home Manager 深度配置联动
    (optionalAttrs (options ? home-manager) {
      home-manager = mkIf cfg.homeManager.enable {
        sharedModules = [
          ({ ... }: {
            programs.nushell = {
              enable = true;
              package = cfg.package;
              plugins = cfg.plugins;
              shellAliases = cfg.shellAliases;
              environmentVariables = cfg.environmentVariables;
              settings = finalSettings;
              extraConfig = cfg.extraConfig;
              extraEnv = cfg.extraEnv;
              extraLogin = cfg.extraLogin;
            }
            // optionalAttrs (cfg.configFile != null) {
              configFile.source = cfg.configFile;
            }
            // optionalAttrs (cfg.envFile != null) {
              envFile.source = cfg.envFile;
            }
            // optionalAttrs (cfg.loginFile != null) {
              loginFile.source = cfg.loginFile;
            };
          })
        ];
      };
    })
  ]);
}
