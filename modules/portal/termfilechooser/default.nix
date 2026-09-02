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

  yaziBin =
    if config ? desktop && config.desktop ? fileManager && config.desktop.fileManager ? yazi && config.desktop.fileManager.yazi ? finalPackage then
      "${config.desktop.fileManager.yazi.finalPackage}/bin/yazi"
    else
      "${pkgs.yazi}/bin/yazi";

  # 内置优化的 Yazi 专用包装脚本
  defaultYaziWrapperPkg = pkgs.writeShellScriptBin "yazi-wrapper.sh" ''
    set -e

    multiple="$1"
    directory="$2"
    save="$3"
    path="$4"
    out="$5"
    debug="$6"

    if [ "$debug" = "1" ]; then
        set -x
    fi

    cmd="${yaziBin}"
    termcmd="''${TERMCMD:-${cfg.termcmd}}"

    if [ "$save" = "1" ]; then
        set -- --chooser-file="$out" "$path"
    elif [ "$directory" = "1" ]; then
        set -- --chooser-file="$out" --cwd-file="$out.1" "$path"
    elif [ "$multiple" = "1" ]; then
        set -- --chooser-file="$out" "$path"
    else
        set -- --chooser-file="$out" "$path"
    fi

    command="$termcmd $cmd"
    for arg in "$@"; do
        escaped=$(printf "%s" "$arg" | ${pkgs.gnused}/bin/sed 's/"/\\"/g')
        command="$command \"$escaped\""
    done

    eval "$command"

    if [ "$directory" = "1" ]; then
        if [ ! -s "$out" ] && [ -s "$out.1" ]; then
            ${pkgs.coreutils}/bin/cat "$out.1" > "$out"
            ${pkgs.coreutils}/bin/rm -f "$out.1"
        else
            ${pkgs.coreutils}/bin/rm -f "$out.1"
        fi
    fi
  '';

  # 选定的生效包装脚本 Package
  activeWrapperPkg =
    if cfg.wrapperScript != null then
      (if isDerivation cfg.wrapperScript then cfg.wrapperScript else pkgs.writeShellScriptBin "custom-wrapper.sh" (builtins.readFile cfg.wrapperScript))
    else
      defaultYaziWrapperPkg;

  activeWrapperExecutable = "${activeWrapperPkg}/bin/${if cfg.wrapperScript != null then "custom-wrapper.sh" else "yazi-wrapper.sh"}";

  # 生成额外的环境变量配置行
  customEnvLines = concatStringsSep "\n" (
    mapAttrsToList (name: val: "    ${name}=${val}") cfg.env
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
        PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.gnused pkgs.bash pkgs.yazi ]}:/run/current-system/sw/bin:/etc/profiles/per-user/$USER/bin
    ${optionalString (customEnvLines != "") customEnvLines}
    ${optionalString (cfg.extraConfig != "") cfg.extraConfig}
  '';
in
{
  options.desktop.portal.termfilechooser = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "是否启用 xdg-desktop-portal-termfilechooser 终端文件选择器门户后端。";
    };

    package = mkPackageOption pkgs "xdg-desktop-portal-termfilechooser" { };

    fileManager = mkOption {
      type = types.enum [ "yazi" "custom" ];
      default = "yazi";
      description = "终端文件选择器所使用的文件管理器后端（默认使用极速终端文件管理器 Yazi）。";
    };

    terminal = mkOption {
      type = types.str;
      default = "ghostty";
      description = "唤起终端文件选择器所使用的终端模拟器（默认 ghostty）。";
    };

    termcmd = mkOption {
      type = types.str;
      default = "${cfg.terminal} --class=termfilechooser --title=termfilechooser -e";
      description = "执行文件管理器所使用的终端命令行模板（注入 TERMCMD 环境变量，配合 Hyprland 浮动居中规则）。";
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
      description = "保存文件时是否预先在目标路径创建占位文件，以便在终端文件管理器中直接选中并确认保存。";
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

    wrapperScript = mkOption {
      type = types.nullOr (types.either types.path types.package);
      default = null;
      description = "自定义文件选择器包装脚本。若为 null 则自动使用内置优化版 Yazi 包装脚本。";
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
      # 1. 注册 Portal 软件包与包装脚本
      environment.systemPackages = [
        cfg.package
        activeWrapperPkg
      ];

      # 2. 系统级配置文件部署 (/etc/xdg/xdg-desktop-portal-termfilechooser/...)
      environment.etc = {
        "xdg/xdg-desktop-portal-termfilechooser/config".text = configContent;
        "xdg/xdg-desktop-portal-termfilechooser/yazi-wrapper.sh" = {
          source = "${defaultYaziWrapperPkg}/bin/yazi-wrapper.sh";
          mode = "0755";
        };
      };

      # 3. 注册 XDG Desktop Portal 路由规则与后端
      xdg.portal = {
        enable = true;
        extraPortals = [ cfg.package ];
        config = mkIf cfg.setAsDefaultFileChooser {
          hyprland = {
            "org.freedesktop.impl.portal.FileChooser" = "termfilechooser";
          };
          common = {
            "org.freedesktop.impl.portal.FileChooser" = "termfilechooser";
          };
        };
      };

      # 4. 联动向 Hyprland 声明使用 termfilechooser
      desktop.windowManager.hyprland = mkIf (config ? desktop && config.desktop ? windowManager && config.desktop.windowManager ? hyprland && config.desktop.windowManager.hyprland.enable) {
        portal = {
          filechooser = mkDefault "termfilechooser";
        };
      };
    }

    # 5. Home Manager 自动联动
    (optionalAttrs (options ? home-manager) {
      home-manager = mkIf cfg.homeManager.enable {
        sharedModules = [
          ({ ... }: {
            home.packages = [
              cfg.package
              activeWrapperPkg
            ];

            xdg.configFile = {
              "xdg-desktop-portal-termfilechooser/config".text = configContent;
              "xdg-desktop-portal-termfilechooser/yazi-wrapper.sh" = {
                source = "${defaultYaziWrapperPkg}/bin/yazi-wrapper.sh";
                executable = true;
              };
            };
          })
        ];
      };
    })
  ]);
}
