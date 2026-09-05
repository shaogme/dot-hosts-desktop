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
    };
    opener = {
      edit = [
        { run = "${cfg.editor} %s"; block = true; desc = "Edit"; }
      ];
      open = [
        { run = "xdg-open %s1"; desc = "Open"; }
      ];
      reveal = [
        { run = "xdg-open %d1"; desc = "Reveal"; }
      ];
    };
    open = {
      rules = [
        { url = "*/"; use = [ "edit" "open" "reveal" ]; }
        { mime = "text/*"; use = [ "edit" "reveal" ]; }
        { mime = "image/*"; use = [ "open" "reveal" ]; }
        { mime = "video/*"; use = [ "open" "reveal" ]; }
        { mime = "audio/*"; use = [ "open" "reveal" ]; }
        { url = "*"; use = [ "open" "reveal" ]; }
      ];
    };
  };

  # 终端快捷键有效配置解析
  effectiveTerminalKeybind =
    if cfg.terminalKey != null then
      cfg.terminalKey
    else
      cfg.terminalKeybind;

  terminalKeybindKey =
    if effectiveTerminalKeybind.key != null then
      effectiveTerminalKeybind.key
    else
      effectiveTerminalKeybind.keybind;

  terminalKeybindCommand =
    if effectiveTerminalKeybind.terminal != null then
      effectiveTerminalKeybind.terminal
    else
      effectiveTerminalKeybind.command;

  # 终端快捷键绑定条目
  terminalKeybindEntry = optional (effectiveTerminalKeybind.enable && terminalKeybindCommand != "") {
    on = if isList terminalKeybindKey then terminalKeybindKey else [ terminalKeybindKey ];
    run = ''shell "${terminalKeybindCommand}" ${optionalString effectiveTerminalKeybind.orphan "--orphan"}'';
    desc = "在当前工作目录打开终端";
  };

  # 默认快捷键预设 (keymap.toml)
  defaultKeymap = {
    mgr.prepend_keymap = [
      { on = [ "<C-q>" ]; run = "close"; desc = "关闭当前标签页或退出 Yazi"; }
    ] ++ terminalKeybindEntry;
  };

  # 主题方案合并
  presetTheme = themes.presets.${cfg.themePreset} or { };
  mergedTheme = recursiveUpdate presetTheme cfg.theme;

  # 深度合并用户配置与预设
  mergedSettings = recursiveUpdate defaultSettings cfg.settings;
  baseMergedKeymap = recursiveUpdate defaultKeymap cfg.keymap;
  mergedKeymap =
    if cfg.keymap ? mgr && cfg.keymap.mgr ? prepend_keymap then
      recursiveUpdate baseMergedKeymap {
        mgr.prepend_keymap = defaultKeymap.mgr.prepend_keymap ++ cfg.keymap.mgr.prepend_keymap;
      }
    else
      baseMergedKeymap;

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

  # 生成桌面启动项 (yazi.desktop)，赋予更高优先级以在 buildEnv 合并时优先选用
  yaziDesktopItem = lib.hiPrio (pkgs.makeDesktopItem {
    name = "yazi";
    desktopName = "Yazi";
    comment = "极速现代终端文件管理器";
    icon = "system-file-manager";
    exec = "${cfg.terminal} -e yazi %u";
    terminal = false;
    type = "Application";
    categories = [ "Utility" "FileManager" ];
    mimeTypes = [ "inode/directory" ];
  });

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

  # 生成供 termfilechooser 等桌面门户使用的 Yazi 文件选择器包装脚本
  yaziWrapperPkg = pkgs.writeShellScriptBin "yazi-wrapper.sh" ''
    set -e

    # 保证终端模拟器与基础命令行工具在 PATH 中可寻址
    export PATH="/run/wrappers/bin:/run/current-system/sw/bin:/etc/profiles/per-user/''${USER:-$(id -un)}/bin:$HOME/.nix-profile/bin:$PATH"

    multiple="$1"
    directory="$2"
    save="$3"
    path="$4"
    out="$5"
    debug="$6"

    if [ "$debug" = "1" ]; then
        set -x
    fi

    cmd="${finalPackage}/bin/yazi"
    termcmd="''${TERMCMD:-${cfg.terminal} --app-id=termfilechooser --title-placeholder=termfilechooser -e}"

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
      default = "rio";
      description = "启动 Yazi 终端文件管理器的终端模拟器命令（如 rio、kitty、foot 等）。";
    };

    terminalKeybind = mkOption {
      type = types.coercedTo types.str
        (cmd: {
          enable = true;
          command = cmd;
        })
        (types.submodule ({ config, ... }: {
          options = {
            enable = mkOption {
              type = types.bool;
              default = false;
              description = "是否在 Yazi 中启用通过快捷键打开终端模拟器。";
            };

            keybind = mkOption {
              type = types.either types.str (types.listOf types.str);
              default = if config.key != null then config.key else "<C-t>";
              description = "在 Yazi 中唤起终端的快捷键绑定，默认按键为 <C-t>。";
            };

            key = mkOption {
              type = types.nullOr (types.either types.str (types.listOf types.str));
              default = null;
              description = "keybind 的别名。";
            };

            command = mkOption {
              type = types.str;
              default = if config.terminal != null then config.terminal else "";
              description = "唤起的终端模拟器命令（需用户手动指定，例如 rio）。";
            };

            terminal = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "command 的别名。";
            };

            orphan = mkOption {
              type = types.bool;
              default = true;
              description = "是否以独立进程模式启动终端（--orphan），避免阻塞 Yazi。";
            };
          };
        }));
      default = { };
      description = "在 Yazi 中通过快捷键绑定快速调出外部终端模拟器的配置项。";
    };

    terminalKey = mkOption {
      type = types.nullOr (types.coercedTo types.str
        (cmd: {
          enable = true;
          command = cmd;
        })
        (types.submodule ({ config, ... }: {
          options = {
            enable = mkOption {
              type = types.bool;
              default = false;
              description = "是否启用在当前工作目录唤起终端的快捷键绑定（需手动开启）。";
            };

            keybind = mkOption {
              type = types.either types.str (types.listOf types.str);
              default = if config.key != null then config.key else "<C-t>";
              description = "在 Yazi 中唤起终端的快捷键绑定，默认按键为 <C-t>。";
            };

            key = mkOption {
              type = types.nullOr (types.either types.str (types.listOf types.str));
              default = null;
              description = "keybind 的别名。";
            };

            command = mkOption {
              type = types.str;
              default = if config.terminal != null then config.terminal else "";
              description = "唤起的终端模拟器命令（需用户手动指定，例如 rio）。";
            };

            terminal = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "command 的别名。";
            };

            orphan = mkOption {
              type = types.bool;
              default = true;
              description = "是否以独立进程模式启动终端（--orphan），避免阻塞 Yazi。";
            };
          };
        })));
      default = null;
      description = "terminalKeybind 的兼容性别名配置项。";
    };

    editor = mkOption {
      type = types.str;
      description = "Yazi 打开文本文件时调用的文本编辑器命令（如 hx、nvim 等，必须显式配置，禁止提供默认 fallback）。";
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

    niri = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否自动联动注册为 Niri 默认文件管理器。";
      };

      keybind = mkOption {
        type = types.str;
        default = "Mod+E";
        description = "在 Niri 中唤起 Yazi 的快捷键绑定（设为空字符串则不注册）。";
      };
    };

    termfilechooser = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否自动为 xdg-desktop-portal-termfilechooser 提供 Yazi 包装脚本作为文件选择器后端。";
      };
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
      assertions = [
        {
          assertion = !effectiveTerminalKeybind.enable || terminalKeybindCommand != "";
          message = "desktop.fileManager.yazi.terminalKeybind 已启用，但未指定 terminal 终端命令（如 rio）。";
        }
        {
          assertion = cfg.editor != "";
          message = "desktop.fileManager.yazi: 启用了 Yazi 文件管理器时，必须显式配置文本编辑器 (desktop.fileManager.yazi.editor)，禁止提供默认 fallback。";
        }
      ];

      # 1. NixOS 系统级软件包与桌面项安装
      environment.systemPackages = [
        finalPackage
      ]
      ++ cfg.extraPackages;

      # 2. 系统级配置文件部署 (/etc/xdg/yazi/... 与 termfilechooser 包装脚本)
      environment.etc = allEtcFiles // (optionalAttrs (config ? desktop && config.desktop ? portal && config.desktop.portal ? termfilechooser && config.desktop.portal.termfilechooser.enable && cfg.termfilechooser.enable) {
        "xdg/xdg-desktop-portal-termfilechooser/yazi-wrapper.sh" = {
          source = "${yaziWrapperPkg}/bin/yazi-wrapper.sh";
          mode = "0755";
        };
      });

      # 3. Shell 环境变量与集成函数
      programs.zsh.interactiveShellInit = mkIf cfg.shellIntegration.enableZsh shellWrapperCode;
      programs.bash.interactiveShellInit = mkIf cfg.shellIntegration.enableBash shellWrapperCode;

      # 4. 联动向 Niri 注册默认文件管理器启动命令
      desktop.windowManager.niri = mkIf (config ? desktop && config.desktop ? windowManager && config.desktop.windowManager ? niri && config.desktop.windowManager.niri.enable && cfg.niri.enable) {
        fileManager = {
          enable = mkDefault true;
          command = mkDefault "${cfg.terminal} -e yazi";
          keybind = mkDefault cfg.niri.keybind;
        };
      };

      # 5. 联动向 termfilechooser 注册 Yazi 文件选择器包装脚本
      desktop.portal.termfilechooser = mkIf (config ? desktop && config.desktop ? portal && config.desktop.portal ? termfilechooser && config.desktop.portal.termfilechooser.enable && cfg.termfilechooser.enable) {
        wrapperScript = mkDefault yaziWrapperPkg;
      };
    }

    # 6. Home Manager 自动联动
    (optionalAttrs (options ? home-manager) {
      home-manager = mkIf cfg.homeManager.enable {
        sharedModules = [
          ({ ... }: {
            home.packages = [
              finalPackage
            ]
            ++ cfg.extraPackages;

            xdg.configFile = allHmConfigFiles // (optionalAttrs (config ? desktop && config.desktop ? portal && config.desktop.portal ? termfilechooser && config.desktop.portal.termfilechooser.enable && cfg.termfilechooser.enable) {
              "xdg-desktop-portal-termfilechooser/yazi-wrapper.sh" = {
                source = "${yaziWrapperPkg}/bin/yazi-wrapper.sh";
                executable = true;
              };
            });

            programs.zsh.initContent = mkIf cfg.shellIntegration.enableZsh shellWrapperCode;
            programs.bash.initExtra = mkIf cfg.shellIntegration.enableBash shellWrapperCode;
          })
        ];
      };
    })
  ]);
}
