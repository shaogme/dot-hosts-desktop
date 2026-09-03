{
  config,
  pkgs,
  lib,
  options,
  ...
}:

with lib;

let
  cfg = config.desktop.portal.termfilechooser;

  activeWrapperExecutable =
    if cfg.cmd != null then
      cfg.cmd
    else if cfg.wrapperScript != null then
      if isDerivation cfg.wrapperScript then
        lib.getExe cfg.wrapperScript
      else if isPath cfg.wrapperScript then
        lib.getExe (pkgs.writeShellScriptBin "custom-wrapper.sh" (builtins.readFile cfg.wrapperScript))
      else
        toString cfg.wrapperScript
    else
      "";

  # 生成额外的环境变量配置行 (标准 INI 格式，多行 env= 避免解析截断)
  customEnvLines = concatStringsSep "\n" (
    mapAttrsToList (name: val: "env=${name}=${val}") cfg.env
  );

  # 生成 termfilechooser 主配置文件文本 (INI 格式)
  configContent = ''
    [filechooser]
    cmd=${activeWrapperExecutable}
    default_dir=${cfg.defaultDir}
    create_help_file=${if cfg.createHelpFile then "1" else "0"}
    open_mode=${cfg.openMode}
    save_mode=${cfg.saveMode}
    env=TERMCMD=${cfg.termcmd}
    ${optionalString (customEnvLines != "") "${customEnvLines}\n"}${optionalString (cfg.extraConfig != "") cfg.extraConfig}
  '';
in
{
  options.desktop.portal.termfilechooser = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "是否启用 xdg-desktop-portal-termfilechooser 终端文件选择器门户后端。";
    };

    package = mkOption {
      type = types.package;
      default = pkgs.xdg-desktop-portal-termfilechooser.overrideAttrs (old: {
        mesonFlags = [
          "--sysconfdir=/etc"
          "-Dsd-bus-provider=libsystemd"
        ];
      });
      defaultText = literalExpression "pkgs.xdg-desktop-portal-termfilechooser.overrideAttrs (...)";
      description = "xdg-desktop-portal-termfilechooser 软件包。";
    };

    cmd = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "直接指定文件选择器包装脚本的可执行命令或路径。若设置则优先于 wrapperScript。";
    };

    wrapperScript = mkOption {
      type = types.nullOr (types.either types.path types.package);
      default = null;
      description = "自定义文件选择器包装脚本（Package 或文件路径）。";
    };

    terminal = mkOption {
      type = types.str;
      default = "rio";
      description = "唤起终端文件选择器所使用的终端模拟器（默认 rio）。";
    };

    termcmd = mkOption {
      type = types.str;
      default = "${cfg.terminal} --app-id=termfilechooser --title-placeholder=termfilechooser -e";
      description = "执行文件选择器所使用的终端命令行模板（注入 TERMCMD 环境变量，配合窗口规则）。";
    };

    defaultDir = mkOption {
      type = types.str;
      default = "$HOME";
      description = "调用方程序未指定建议打开路径时的默认起始目录。";
    };

    openMode = mkOption {
      type = types.enum [ "suggested" "default" "last" ];
      default = "suggested";
      description = "打开文件对话框的初始目录决策策略：suggested（调用程序建议）、default（defaultDir）或 last（上次所选目录）。";
    };

    saveMode = mkOption {
      type = types.enum [ "suggested" "default" "last" ];
      default = "suggested";
      description = "保存文件对话框的初始目录决策策略：suggested（调用程序建议）、default（defaultDir）或 last（上次所选目录）。";
    };

    createHelpFile = mkOption {
      type = types.bool;
      default = true;
      description = "保存文件时是否预先在目标路径创建占位文件，以便在终端中直接选中并确认保存。";
    };

    env = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "传递给包装脚本执行环境的额外环境变量字典。";
      example = literalExpression ''
        {
          EDITOR = "nvim";
          LANG = "zh_CN.UTF-8";
        }
      '';
    };

    setAsDefaultFileChooser = mkOption {
      type = types.bool;
      default = true;
      description = "是否自动将 termfilechooser 设为系统与 Hyprland 的默认 FileChooser 门户后端。";
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = "追加写入 xdg-desktop-portal-termfilechooser 配置文件的自定义配置文本。";
    };

    homeManager = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "若系统中启用了 Home Manager，是否自动将 termfilechooser 配置注入到所有 Home Manager 用户中。";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      # 校验：必须配置有效的包装脚本或执行命令
      assertions = [
        {
          assertion = cfg.cmd != null || cfg.wrapperScript != null;
          message = "桌面门户配置错误：xdg-desktop-portal-termfilechooser 需要配置 cmd 或 wrapperScript。请提供有效的文件选择器命令或包装脚本。";
        }
      ];

      # 1. 注册包装脚本包（如果为 derivation）
      environment.systemPackages = optional (cfg.wrapperScript != null && isDerivation cfg.wrapperScript) cfg.wrapperScript;

      # 2. 系统级配置文件部署 (/etc/xdg/xdg-desktop-portal-termfilechooser/config)
      environment.etc = {
        "xdg/xdg-desktop-portal-termfilechooser/config".text = configContent;
      };

      # 3. 注册 XDG Desktop Portal 路由规则与后端
      xdg.portal = {
        enable = true;
        extraPortals = [ cfg.package ];
        config = mkIf cfg.setAsDefaultFileChooser {
          common = {
            "org.freedesktop.impl.portal.FileChooser" = "termfilechooser";
          };
        };
      };

      # 4. 配置 systemd user 服务的环境变量 PATH，确保能找到系统与用户终端（如 rio）
      systemd.user.services.xdg-desktop-portal-termfilechooser = {
        environment = {
          PATH = mkDefault "/run/wrappers/bin:/run/current-system/sw/bin:/etc/profiles/per-user/%u/bin";
        };
      };

      # 5. 联动向 Niri 声明使用 termfilechooser
      desktop.windowManager.niri = mkIf (config ? desktop && config.desktop ? windowManager && config.desktop.windowManager ? niri && config.desktop.windowManager.niri.enable && cfg.setAsDefaultFileChooser) {
        portal = {
          filechooser = mkDefault "termfilechooser";
        };
      };
    }

    # 6. Home Manager 自动联动
    (optionalAttrs (options ? home-manager) {
      home-manager = mkIf cfg.homeManager.enable {
        sharedModules = [
          ({ ... }: {
            home.packages = optional (cfg.wrapperScript != null && isDerivation cfg.wrapperScript) cfg.wrapperScript;

            xdg.configFile = {
              "xdg-desktop-portal-termfilechooser/config".text = configContent;
            };
          })
        ];
      };
    })
  ]);
}
