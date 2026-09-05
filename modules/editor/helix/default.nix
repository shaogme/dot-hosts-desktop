{
  config,
  pkgs,
  lib,
  options,
  ...
}:

with lib;

let
  cfg = config.desktop.editor.helix;
  themes = import ./themes.nix;

  tomlFormat = pkgs.formats.toml { };

  # 默认基础配置预设 (config.toml)
  defaultSettings = {
    theme =
      if cfg.themePreset != "default" then
        themes.themePresetMap.${cfg.themePreset} or cfg.themePreset
      else
        null;
    editor = {
      line-number = "relative";
      mouse = true;
      cursorline = true;
      color-modes = true;
      cursor-shape = {
        insert = "bar";
        normal = "block";
        select = "underline";
      };
      file-picker = {
        hidden = false;
      };
      indent-guides = {
        render = true;
        character = "│";
      };
      statusline = {
        left = [ "mode" "spinner" "file-name" "read-only-indicator" "file-modification-indicator" ];
        center = [ ];
        right = [ "diagnostics" "selections" "position" "file-encoding" "file-line-ending" "file-type" ];
        separator = "│";
        mode = {
          normal = "NORMAL";
          insert = "INSERT";
          select = "SELECT";
        };
      };
    };
  };

  # 递归过滤 null 值，避免生成无效 TOML 键值
  filterNulls = attrs:
    lib.filterAttrsRecursive (_: v: v != null) attrs;

  # 深度合并用户配置与预设
  mergedSettings = recursiveUpdate (filterNulls defaultSettings) cfg.settings;

  # 生成 TOML 配置文件 Derivations
  baseHelixToml = tomlFormat.generate "helix-config.toml" mergedSettings;
  helixTomlFile =
    if cfg.extraConfig != "" then
      pkgs.runCommand "helix-config.toml" { } ''
        cat ${baseHelixToml} > $out
        echo "" >> $out
        cat ${pkgs.writeText "helix-extra.toml" cfg.extraConfig} >> $out
      ''
    else
      baseHelixToml;

  languagesTomlFile =
    if cfg.languages != { } then
      tomlFormat.generate "languages.toml" cfg.languages
    else
      null;

  # 生成桌面启动项 (helix.desktop)
  helixDesktopItem = lib.hiPrio (pkgs.makeDesktopItem {
    name = "helix";
    desktopName = "Helix";
    genericName = "Text Editor";
    comment = "后现代模态终端文本编辑器";
    icon = "helix";
    exec = "${cfg.terminal} -e hx %F";
    terminal = false;
    type = "Application";
    categories = [ "Utility" "TextEditor" "Development" ];
    mimeTypes = [ "text/plain" ];
  });

  # 组织所有需要写入 /etc/xdg/helix 的文件列表
  baseEtcFiles = {
    "xdg/helix/config.toml".source = helixTomlFile;
  }
  // optionalAttrs (languagesTomlFile != null) {
    "xdg/helix/languages.toml".source = languagesTomlFile;
  }
  // (mapAttrs' (
    name: themeData:
    nameValuePair "xdg/helix/themes/${name}.toml" {
      source = tomlFormat.generate "${name}.toml" themeData;
    }
  ) cfg.themes);

  # Home Manager 对应的 xdg.configFile 配置
  baseHmConfigFiles = {
    "helix/config.toml".source = helixTomlFile;
  }
  // optionalAttrs (languagesTomlFile != null) {
    "helix/languages.toml".source = languagesTomlFile;
  }
  // (mapAttrs' (
    name: themeData:
    nameValuePair "helix/themes/${name}.toml" {
      source = tomlFormat.generate "${name}.toml" themeData;
    }
  ) cfg.themes);
in
{
  options.desktop.editor.helix = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "是否启用 Helix 现代终端文本编辑器。";
    };

    package = mkPackageOption pkgs "helix" { };


    terminal = mkOption {
      type = types.str;
      description = "启动 Helix 文本编辑器的终端模拟器命令（必须显式配置，禁止提供默认 fallback）。";
    };

    themePreset = mkOption {
      type = types.enum [ "default" "catppuccin-mocha" "catppuccin-latte" "tokyo-night" "nord" ];
      default = "catppuccin-mocha";
      description = "Helix 终端文本编辑器的开箱即用视觉预设主题配色方案。";
    };

    settings = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "以 Nix 结构化数据编写的 config.toml 配置，将与默认预设深度合并。";
    };

    languages = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "以 Nix 结构化数据编写的 languages.toml 配置（语言服务器与语法高亮）。";
    };

    themes = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "以 Nix 结构化数据编写的自定义主题集合，生成至 themes/<name>.toml。";
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "注入到系统环境的 Language Server (LSP)、DAP 调试器与代码格式化工具列表。";
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = "追加写入 config.toml 的原生纯文本 TOML 配置片段。";
    };


    desktopEntry = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否为 Helix 注册系统与桌面启动器识别的 helix.desktop 图形启动项。";
      };
    };

    homeManager = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "若系统中启用了 Home Manager，是否自动将 Helix 配置注入到所有 Home Manager 用户中。";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      assertions = [
        {
          assertion = cfg.terminal != "";
          message = "desktop.editor.helix: 启用了 Helix 文本编辑器时，必须显式配置终端模拟器 (desktop.editor.helix.terminal)，禁止提供默认 fallback。";
        }
      ];

      # 2. NixOS 系统级软件包与桌面项安装
      environment.systemPackages = [
        cfg.package
      ]
      ++ (optional cfg.desktopEntry.enable helixDesktopItem)
      ++ cfg.extraPackages;

      # 3. 系统级配置文件部署 (/etc/xdg/helix/config.toml 等)
      environment.etc = baseEtcFiles;

    }

    # 5. Home Manager 自动联动
    (optionalAttrs (options ? home-manager) {
      home-manager = mkIf cfg.homeManager.enable {
        sharedModules = [
          ({ ... }: {
            home.packages = [
              cfg.package
            ]
            ++ cfg.extraPackages;

            xdg.configFile = baseHmConfigFiles;
          })
        ];
      };
    })
  ]);
}
