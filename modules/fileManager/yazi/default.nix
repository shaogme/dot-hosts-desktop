{
  config,
  pkgs,
  lib,
  options,
  ...
}:

with lib;

let
  cfg = config.desktop.fileManager.yazi;
  themes = import ./themes.nix;

  tomlFormat = pkgs.formats.toml { };

  # 默认基础配置预设 (yazi.toml)
  defaultSettings = {
    mgr = {
      ratio = [ 1 4 3 ];
      sort_by = "alphabetical";
      sort_sensitive = false;
      sort_reverse = false;
      sort_dir_first = true;
      show_hidden = false;
      show_symlink = true;
      scrolloff = 5;
    };
    preview = {
      tab_size = 2;
      max_width = 1200;
      max_height = 1500;
      image_filter = "triangle";
      image_quality = 85;
      sixel_fraction = 15;
    };
    opener = {
      edit = [
        { run = "\${EDITOR:-nano} \"$@\""; block = true; desc = "Edit"; }
      ];
      open = [
        { run = "xdg-open \"$@\""; desc = "Open"; }
      ];
      reveal = [
        { run = "xdg-open \"$(dirname \"$1\")\""; desc = "Reveal"; }
      ];
    };
    open = {
      rules = [
        { name = "*/"; use = [ "edit" "open" "reveal" ]; }
        { mime = "text/*"; use = [ "edit" "reveal" ]; }
        { mime = "image/*"; use = [ "open" "reveal" ]; }
        { mime = "video/*"; use = [ "open" "reveal" ]; }
        { mime = "audio/*"; use = [ "open" "reveal" ]; }
        { mime = "*"; use = [ "open" "reveal" ]; }
      ];
    };
  };

  # 默认快捷键预设 (keymap.toml)
  defaultKeymap = {
    mgr.prepend_keymap = [
      { on = [ "<C-q>" ]; run = "close"; desc = "关闭当前标签页或退出 Yazi"; }
    ];
  };

  # 主题方案合并
  presetTheme = themes.presets.${cfg.themePreset} or { };
  mergedTheme = recursiveUpdate presetTheme cfg.theme;

  # 深度合并用户配置与预设
  mergedSettings = recursiveUpdate defaultSettings cfg.settings;
  mergedKeymap = recursiveUpdate defaultKeymap cfg.keymap;

  # 生成 TOML 配置文件 Derivations
  baseYaziToml = tomlFormat.generate "yazi-base.toml" mergedSettings;
  yaziTomlFile =
    if cfg.extraConfig != "" then
      pkgs.runCommand "yazi.toml" { } ''
        cat ${baseYaziToml} > $out
        echo "" >> $out
        cat ${pkgs.writeText "yazi-extra.toml" cfg.extraConfig} >> $out
      ''
    else
      baseYaziToml;

  keymapTomlFile = tomlFormat.generate "keymap.toml" mergedKeymap;
  themeTomlFile = tomlFormat.generate "theme.toml" mergedTheme;
  vfsTomlFile = tomlFormat.generate "vfs.toml" cfg.vfs;

  # 包装带有扩展 CLI 工具依赖的 Yazi Package
  finalPackage =
    if cfg.package ? override && cfg.extraPackages != [ ] then
      cfg.package.override (old: {
        extraPackages = (old.extraPackages or [ ]) ++ cfg.extraPackages;
      })
    else
      cfg.package;

  # 生成桌面启动项 (yazi.desktop)
  yaziDesktopItem = pkgs.makeDesktopItem {
    name = "yazi";
    desktopName = "Yazi";
    comment = "极速现代终端文件管理器";
    icon = "system-file-manager";
    exec = "${cfg.terminal} -e yazi %u";
    terminal = false;
    type = "Application";
    categories = [ "Utility" "FileManager" ];
    mimeTypes = [ "inode/directory" ];
  };

  # Shell 包装函数脚本 (退出时自动切换当前终端工作路径)
  shellWrapperCode = ''
    function ${cfg.shellIntegration.shellWrapperName}() {
      local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
      command yazi "$@" --cwd-file="$tmp"
      if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        builtin cd -- "$cwd"
      fi
      rm -f -- "$tmp"
    }
    ${optionalString cfg.shellIntegration.enableAliasYy "alias yy=${cfg.shellIntegration.shellWrapperName}"}
  '';

  # 组织所有需要写入 /etc/xdg/yazi 的文件列表
  baseEtcFiles = {
    "xdg/yazi/yazi.toml".source = yaziTomlFile;
    "xdg/yazi/keymap.toml".source = keymapTomlFile;
    "xdg/yazi/theme.toml".source = themeTomlFile;
  }
  // optionalAttrs (cfg.vfs != { }) {
    "xdg/yazi/vfs.toml".source = vfsTomlFile;
  }
  // optionalAttrs (cfg.initLua != null) {
    "xdg/yazi/init.lua" =
      if builtins.isPath cfg.initLua then
        { source = cfg.initLua; }
      else
        { text = cfg.initLua; };
  }
  // (mapAttrs' (
    name: pkg:
    nameValuePair "xdg/yazi/plugins/${name}.yazi" { source = pkg; }
  ) cfg.plugins)
  // (mapAttrs' (
    name: pkg:
    nameValuePair "xdg/yazi/flavors/${name}.yazi" { source = pkg; }
  ) cfg.flavors);

  # 归一化 extraConfigFiles
  normalizedExtraConfigs = mapAttrs' (
    name: val:
    nameValuePair "xdg/yazi/${name}" (if isAttrs val && (val ? text || val ? source) then val else { text = val; })
  ) cfg.extraConfigFiles;

  allEtcFiles = baseEtcFiles // normalizedExtraConfigs;

  # Home Manager 对应的 xdg.configFile 配置
  baseHmConfigFiles = {
    "yazi/yazi.toml".source = yaziTomlFile;
    "yazi/keymap.toml".source = keymapTomlFile;
    "yazi/theme.toml".source = themeTomlFile;
  }
  // optionalAttrs (cfg.vfs != { }) {
    "yazi/vfs.toml".source = vfsTomlFile;
  }
  // optionalAttrs (cfg.initLua != null) {
    "yazi/init.lua" =
      if builtins.isPath cfg.initLua then
        { source = cfg.initLua; }
      else
        { text = cfg.initLua; };
  }
  // (mapAttrs' (
    name: pkg:
    nameValuePair "yazi/plugins/${name}.yazi" { source = pkg; }
  ) cfg.plugins)
  // (mapAttrs' (
    name: pkg:
    nameValuePair "yazi/flavors/${name}.yazi" { source = pkg; }
  ) cfg.flavors);

  allHmConfigFiles = baseHmConfigFiles // (mapAttrs' (
    name: val:
    nameValuePair "yazi/${name}" (if isAttrs val && (val ? text || val ? source) then val else { text = val; })
  ) cfg.extraConfigFiles);
in
{
  options.desktop.fileManager.yazi = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "是否启用 Yazi 现代化极速终端文件管理器。";
    };

    package = mkPackageOption pkgs "yazi" { };

    finalPackage = mkOption {
      type = types.package;
      readOnly = true;
      default = finalPackage;
      description = "经过 extraPackages 依赖扩展包装后的最终 Yazi 软件包。";
    };

    terminal = mkOption {
      type = types.str;
      default = "ghostty";
      description = "启动 Yazi 终端文件管理器的终端模拟器命令（如 ghostty、kitty、foot 等）。";
    };

    themePreset = mkOption {
      type = types.enum [ "default" "catppuccin-mocha" "tokyo-night" "nord" ];
      default = "catppuccin-mocha";
      description = "Yazi 终端文件管理器的开箱即用视觉预设主题配色方案。";
    };

    settings = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "以 Nix 结构化数据编写的 yazi.toml 配置，将与默认预设深度合并。";
    };

    keymap = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "以 Nix 结构化数据编写的 keymap.toml 按键映射配置，将与默认预设深度合并。";
    };

    theme = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "以 Nix 结构化数据编写的 theme.toml 配置，将与选定的预设主题深度合并。";
    };

    vfs = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "以 Nix 结构化数据编写的 vfs.toml 虚拟文件系统连接配置。";
    };

    initLua = mkOption {
      type = types.nullOr (types.either types.path types.lines);
      default = null;
      description = "写入 init.lua 的自定义 Lua 代码字符串或文件路径。";
    };

    plugins = mkOption {
      type = types.attrsOf (types.either types.path types.package);
      default = { };
      description = "自定义 Lua 插件集合，将链接至 yazi/plugins/<name>.yazi。";
    };

    flavors = mkOption {
      type = types.attrsOf (types.either types.path types.package);
      default = { };
      description = "自定义预设视觉风格包集合，将链接至 yazi/flavors/<name>.yazi。";
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = with pkgs; [
        file
        fd
        ripgrep
        fzf
        zoxide
        jq
        chafa
        poppler-utils
        ffmpeg-headless
        resvg
      ];
      description = "注入到 Yazi 运行环境中的命令行工具与文档/多媒体预览依赖列表。";
    };

    shellIntegration = {
      enableZsh = mkOption {
        type = types.bool;
        default = true;
        description = "是否为 Zsh 启用 Yazi 智能 CWD 路径跳转包装函数 (y / yy)。";
      };

      enableBash = mkOption {
        type = types.bool;
        default = true;
        description = "是否为 Bash 启用 Yazi 智能 CWD 路径跳转包装函数 (y / yy)。";
      };

      enableFish = mkOption {
        type = types.bool;
        default = true;
        description = "是否为 Fish 启用 Yazi 智能 CWD 路径跳转包装函数 (y / yy)。";
      };

      shellWrapperName = mkOption {
        type = types.str;
        default = "y";
        description = "Shell 包装函数的命令名称（默认输入 y 即可在退出时切换工作目录）。";
      };

      enableAliasYy = mkOption {
        type = types.bool;
        default = true;
        description = "是否同时为 Shell 包装函数创建 yy 别名。";
      };
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = "追加写入 yazi.toml 的原生纯文本 TOML 配置片段。";
    };

    extraConfigFiles = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "写入 yazi 配置目录的额外自定义配置文件集合。";
    };

    desktopEntry = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否为 Yazi 注册系统与桌面启动器识别的 yazi.desktop 图形启动项。";
      };
    };

    homeManager = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "若系统中启用了 Home Manager，是否自动将 Yazi 配置注入到所有 Home Manager 用户中。";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      # 1. NixOS 系统级软件包与桌面项安装
      environment.systemPackages = [
        finalPackage
      ]
      ++ (optional cfg.desktopEntry.enable yaziDesktopItem)
      ++ cfg.extraPackages;

      # 2. 系统级配置文件部署 (/etc/xdg/yazi/...)
      environment.etc = allEtcFiles;

      # 3. Shell 环境变量与集成函数
      programs.zsh.interactiveShellInit = mkIf cfg.shellIntegration.enableZsh shellWrapperCode;
      programs.bash.interactiveShellInit = mkIf cfg.shellIntegration.enableBash shellWrapperCode;

      # 4. 联动向 Hyprland 注册默认文件管理器启动命令
      desktop.windowManager.hyprland = mkIf (config ? desktop && config.desktop ? windowManager && config.desktop.windowManager ? hyprland && config.desktop.windowManager.hyprland.enable) {
        fileManager = {
          enable = mkDefault true;
          command = mkDefault "${cfg.terminal} -e yazi";
        };
      };
    }

    # 5. Home Manager 自动联动
    (optionalAttrs (options ? home-manager) {
      home-manager = mkIf cfg.homeManager.enable {
        sharedModules = [
          ({ ... }: {
            home.packages = [
              finalPackage
            ]
            ++ (optional cfg.desktopEntry.enable yaziDesktopItem)
            ++ cfg.extraPackages;

            xdg.configFile = allHmConfigFiles;

            programs.zsh.initContent = mkIf cfg.shellIntegration.enableZsh shellWrapperCode;
            programs.bash.initExtra = mkIf cfg.shellIntegration.enableBash shellWrapperCode;
          })
        ];
      };
    })
  ]);
}
