{ config, pkgs, lib, options, ... }:

with lib;

let
  cfg = config.desktop.terminal.zsh;
in
{
  options.desktop.terminal.zsh = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "是否启用 Zsh 现代化终端 Shell 及深度环境配置（默认关闭）。";
    };

    package = mkOption {
      type = types.package;
      default = pkgs.zsh;
      defaultText = literalExpression "pkgs.zsh";
      description = "使用的 Zsh 软件包。";
    };

    setAsDefaultShell = mkOption {
      type = types.bool;
      default = true;
      description = "是否将 Zsh 设置为系统及用户的默认登录 Shell。";
    };

    enableCompletion = mkOption {
      type = types.bool;
      default = true;
      description = "是否启用 Zsh 智能命令自动补全功能。";
    };

    enableAutosuggestions = mkOption {
      type = types.bool;
      default = true;
      description = "是否启用 Zsh 命令行历史输入建议（zsh-autosuggestions）。";
    };

    enableSyntaxHighlighting = mkOption {
      type = types.bool;
      default = true;
      description = "是否启用 Zsh 命令行语法实时高亮增强（zsh-syntax-highlighting）。";
    };

    enableVteIntegration = mkOption {
      type = types.bool;
      default = true;
      description = "是否启用 VTE 终端会话集成（自动同步当前工作目录等）。";
    };

    history = {
      size = mkOption {
        type = types.int;
        default = 10000;
        description = "内存中保留的命令历史最大条目数。";
      };

      save = mkOption {
        type = types.int;
        default = 10000;
        description = "持久化写入历史文件的命令历史最大条目数。";
      };

      path = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Zsh 历史记录文件路径（默认为 ~/.zsh_history）。";
      };

      ignoreDups = mkOption {
        type = types.bool;
        default = true;
        description = "是否在命令历史中忽略与上一条连续重复的命令。";
      };

      ignoreAllDups = mkOption {
        type = types.bool;
        default = true;
        description = "当记录新命令时，是否删除历史中所有较旧的重复条目。";
      };

      expireDuplicatesFirst = mkOption {
        type = types.bool;
        default = true;
        description = "历史记录超出上限时，是否优先剔除重复的历史命令条目。";
      };

      share = mkOption {
        type = types.bool;
        default = true;
        description = "是否在多个运行中的 Zsh 终端会话之间实时共享命令历史。";
      };

      extended = mkOption {
        type = types.bool;
        default = true;
        description = "是否以扩展格式保存历史（记录命令执行时间戳与运行时长）。";
      };
    };

    shellAliases = mkOption {
      type = types.attrsOf types.str;
      default = {
        ".." = "cd ..";
        "..." = "cd ../..";
        "l" = "ls -alh";
        "ll" = "ls -lh";
        "la" = "ls -a";
        "grep" = "grep --color=auto";
        "cls" = "clear";
      };
      description = "Zsh 快捷别名（Shell Aliases）映射配置。";
    };

    sessionVariables = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Zsh 会话环境变量字典。";
    };

    initExtra = mkOption {
      type = types.lines;
      default = "";
      description = "追加到 ~/.zshrc 交互式配置末尾的原生 Shell 脚本内容。";
    };

    envExtra = mkOption {
      type = types.lines;
      default = "";
      description = "追加到 ~/.zshenv 环境配置末尾的原生 Shell 脚本内容。";
    };

    profileExtra = mkOption {
      type = types.lines;
      default = "";
      description = "追加到 ~/.zprofile 登录环境配置末尾的原生 Shell 脚本内容。";
    };

    loginShellInit = mkOption {
      type = types.lines;
      default = "";
      description = "追加到 ~/.zlogin 登录初始化配置末尾的原生 Shell 脚本内容。";
    };

    ohMyZsh = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "是否启用 Oh-My-Zsh 插件与主题管理框架。";
      };

      plugins = mkOption {
        type = types.listOf types.str;
        default = [ "git" "sudo" ];
        description = "Oh-My-Zsh 启用的内置插件名称列表。";
      };

      theme = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Oh-My-Zsh 主题名称（若使用 Starship 提示符建议保持为 null）。";
      };

      custom = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Oh-My-Zsh 自定义目录路径。";
      };
    };

    plugins = mkOption {
      type = types.listOf (types.submodule {
        options = {
          name = mkOption {
            type = types.str;
            description = "自定义 Zsh 插件名称。";
          };
          src = mkOption {
            type = types.path;
            description = "插件源文件所在目录或 Package 路径。";
          };
          file = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "插件入口脚本文件名（若与插件同名可留空）。";
          };
        };
      });
      default = [ ];
      description = "通过 Home Manager 引入的自定义 Zsh 插件列表。";
    };

    homeManager = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "若系统中启用了 Home Manager，是否自动将 Zsh 深度配置应用到所有 Home Manager 用户。";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      # 1. NixOS 系统级 Zsh 支持（生成 /etc/zshrc、补全系统、PAM 与系统 shells 注册）
      programs.zsh = {
        enable = true;
        package = cfg.package;
        enableCompletion = cfg.enableCompletion;
        autosuggestions.enable = cfg.enableAutosuggestions;
        syntaxHighlighting.enable = cfg.enableSyntaxHighlighting;
        vteIntegration = cfg.enableVteIntegration;
        shellAliases = cfg.shellAliases;
      };

      # 2. 将 Zsh 设置为系统默认登录 Shell
      users.defaultUserShell = mkIf cfg.setAsDefaultShell cfg.package;
      environment.shells = [ cfg.package ];

      # 3. 系统级辅助软件包
      environment.systemPackages = with pkgs; [
        cfg.package
        zsh-completions
        zsh-autosuggestions
        zsh-syntax-highlighting
      ];

      # 4. 会话环境变量
      environment.sessionVariables = cfg.sessionVariables;
    }

    # 5. Home Manager 深度配置联动
    (optionalAttrs (options ? home-manager) {
      home-manager = mkIf cfg.homeManager.enable {
        sharedModules = [
          ({ ... }: {
            programs.zsh = {
              enable = true;
              package = cfg.package;
              enableCompletion = cfg.enableCompletion;
              autosuggestion.enable = cfg.enableAutosuggestions;
              syntaxHighlighting.enable = cfg.enableSyntaxHighlighting;
              enableVteIntegration = cfg.enableVteIntegration;
              history = {
                size = cfg.history.size;
                save = cfg.history.save;
                path = if cfg.history.path != null then cfg.history.path else "$HOME/.zsh_history";
                ignoreDups = cfg.history.ignoreDups;
                ignoreAllDups = cfg.history.ignoreAllDups;
                expireDuplicatesFirst = cfg.history.expireDuplicatesFirst;
                share = cfg.history.share;
                extended = cfg.history.extended;
              };
              shellAliases = cfg.shellAliases;
              sessionVariables = cfg.sessionVariables;
              initExtra = cfg.initExtra;
              envExtra = cfg.envExtra;
              profileExtra = cfg.profileExtra;
              loginExtra = cfg.loginShellInit;
              oh-my-zsh = mkIf cfg.ohMyZsh.enable {
                enable = true;
                plugins = cfg.ohMyZsh.plugins;
                theme = cfg.ohMyZsh.theme;
                custom = cfg.ohMyZsh.custom;
              };
              plugins = cfg.plugins;
            };
          })
        ];
      };
    })
  ]);
}
