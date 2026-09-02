{
  config,
  pkgs,
  lib,
  options,
  ...
}:

with lib;

let
  cfg = config.desktop.terminal.ghostty;

  toKeyValue = lib.generators.toKeyValue {
    listsAsDuplicateKeys = true;
    mkKeyValue = lib.generators.mkKeyValueDefault { } " = ";
  };

  # 构建基础配置字典
  baseSettings = filterAttrs (n: v: v != null) {
    theme = cfg.theme;
    font-family = cfg.font.family;
    font-size = cfg.font.size;
    font-feature = cfg.font.features;
    font-style = cfg.font.style;
    font-family-bold = cfg.font.familyBold;
    font-family-italic = cfg.font.familyItalic;
    font-family-bold-italic = cfg.font.familyBoldItalic;
    font-thicken = cfg.font.thicken;
    window-decoration = cfg.window.decoration;
    window-theme = cfg.window.theme;
    window-padding-x = cfg.window.padding.x;
    window-padding-y = cfg.window.padding.y;
    window-padding-balance = cfg.window.padding.balance;
    window-padding-color = cfg.window.padding.color;
    background-opacity = cfg.window.opacity;
    background-blur = cfg.window.blur;
    window-vsync = cfg.window.vsync;
    window-step-resize = cfg.window.stepResize;
    window-save-state = cfg.window.saveState;
    unfocused-split-opacity = cfg.window.unfocusedSplitOpacity;
    cursor-style = cfg.cursor.style;
    cursor-style-blink = cfg.cursor.blink;
    cursor-color = cfg.cursor.color;
    cursor-text = cfg.cursor.text;
    cursor-opacity = cfg.cursor.opacity;
    cursor-click-to-move = cfg.cursor.clickToMove;
    mouse-hide-while-typing = cfg.mouse.hideWhileTyping;
    mouse-scroll-multiplier = cfg.mouse.scrollMultiplier;
    mouse-shift-capture = cfg.mouse.shiftCapture;
    scrollback-limit = cfg.scrollbackLimit;
    copy-on-select = cfg.copyOnSelect;
    clipboard-read = cfg.clipboard.read;
    clipboard-write = cfg.clipboard.write;
    clipboard-paste-protection = cfg.clipboard.pasteProtection;
    clipboard-paste-bracketed-safe = cfg.clipboard.pasteBracketedSafe;
    confirm-close-surface = cfg.confirmCloseSurface;
    quit-after-last-window-closed = cfg.quitAfterLastWindowClosed;
    desktop-notifications = cfg.desktopNotifications;
    bell-features = concatStringsSep "," cfg.bell.features;
    gtk-single-instance = cfg.gtk.singleInstance;
    gtk-tabs-location = cfg.gtk.tabsLocation;
    gtk-wide-tabs = cfg.gtk.wideTabs;
    gtk-titlebar = cfg.gtk.titlebar;
    gtk-custom-css = if cfg.gtk.customCss != null then toString cfg.gtk.customCss else null;
    custom-shader = if cfg.customShader != null then toString cfg.customShader else null;
    custom-shader-animation = cfg.customShaderAnimation;
    command = cfg.command;
    initial-command = cfg.initialCommand;
    auto-update = "off";
    keybind = cfg.keybinds;
  } // (optionalAttrs cfg.quickTerminal.enable {
    quick-terminal-position = cfg.quickTerminal.position;
    quick-terminal-autohide = cfg.quickTerminal.autohide;
    quick-terminal-animation-duration = cfg.quickTerminal.animationDuration;
  });

  # 合并用户自由定义的 settings
  finalSettings = recursiveUpdate baseSettings cfg.settings;

  # 生成 Ghostty 主配置文件文本
  generatedConfigText =
    toKeyValue finalSettings
    + optionalString (cfg.extraConfig != "") "\n${cfg.extraConfig}\n";

  # 自定义主题文件映射
  customThemeFiles = mapAttrs' (
    name: themeAttrs:
    nameValuePair "xdg/ghostty/themes/${name}" {
      text = toKeyValue themeAttrs;
    }
  ) cfg.customThemes;

  customThemeEtcFiles = mapAttrs' (
    name: themeAttrs:
    nameValuePair "ghostty/themes/${name}" {
      text = toKeyValue themeAttrs;
    }
  ) cfg.customThemes;
in
{
  options.desktop.terminal.ghostty = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "是否启用 Ghostty 现代化高性能 GPU 加速 Wayland 原生终端（默认关闭）。";
    };

    package = mkPackageOption pkgs "ghostty" { };

    command = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Ghostty 启动时执行的默认命令行（留空则自动使用系统默认登录 Shell）。";
    };

    initialCommand = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Ghostty 初始启动窗口时执行的命令行。";
    };

    theme = mkOption {
      type = types.nullOr types.str;
      default = "Catppuccin Mocha";
      description = "Ghostty 终端配色主题名称（可使用内置主题如 Catppuccin Mocha、Tokyo Night、Nord，或在 customThemes 中声明）。";
    };

    font = {
      family = mkOption {
        type = types.str;
        default = "Maple Mono NF CN";
        description = "终端默认主等宽字体族名称。";
      };

      size = mkOption {
        type = types.either types.int types.float;
        default = 13;
        description = "终端默认字体字号大小。";
      };

      features = mkOption {
        type = types.listOf types.str;
        default = [
          "calt"
          "liga"
          "dlig"
        ];
        description = "启用 OpenType 字体特性与连字支持。";
      };

      style = mkOption {
        type = types.str;
        default = "default";
        description = "主字体字重样式（如 default, regular, medium, bold）。";
      };

      familyBold = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "自定义粗体字体族名称。";
      };

      familyItalic = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "自定义斜体字体族名称。";
      };

      familyBoldItalic = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "自定义粗斜体字体族名称。";
      };

      thicken = mkOption {
        type = types.bool;
        default = false;
        description = "是否启用字体笔画微量加粗渲染。";
      };
    };

    window = {
      decoration = mkOption {
        type = types.either types.bool (types.enum [ "auto" "client" "server" "none" ]);
        default = false;
        description = "是否开启窗口客户端边框与标题栏装饰（Hyprland 平铺环境下默认建议为 false）。";
      };

      theme = mkOption {
        type = types.enum [ "auto" "dark" "light" "system" ];
        default = "dark";
        description = "窗口暗黑/明亮主体风格。";
      };

      padding = {
        x = mkOption {
          type = types.int;
          default = 12;
          description = "终端窗口水平内边距像素大小。";
        };

        y = mkOption {
          type = types.int;
          default = 12;
          description = "终端窗口垂直内边距像素大小。";
        };

        balance = mkOption {
          type = types.bool;
          default = true;
          description = "是否自动平衡对齐内边距。";
        };

        color = mkOption {
          type = types.enum [ "background" "extend" ];
          default = "background";
          description = "内边距背景颜色模式。";
        };
      };

      opacity = mkOption {
        type = types.either types.int types.float;
        default = 0.92;
        description = "终端背景透明度 (0.0 完全透明 - 1.0 完全不透明)。";
      };

      blur = mkOption {
        type = types.bool;
        default = true;
        description = "是否启用背景毛玻璃模糊效果。";
      };

      vsync = mkOption {
        type = types.bool;
        default = true;
        description = "是否启用渲染垂直同步以消除画面撕裂。";
      };

      stepResize = mkOption {
        type = types.bool;
        default = false;
        description = "是否按字符网格单元步进调整窗口尺寸。";
      };

      saveState = mkOption {
        type = types.enum [ "default" "always" "never" ];
        default = "default";
        description = "窗口几何与状态保存策略。";
      };

      unfocusedSplitOpacity = mkOption {
        type = types.either types.int types.float;
        default = 0.85;
        description = "失焦分屏区域的透明度。";
      };
    };

    cursor = {
      style = mkOption {
        type = types.enum [ "bar" "block" "underline" ];
        default = "bar";
        description = "光标显示形状外观（bar 竖线, block 方块, underline 下划线）。";
      };

      blink = mkOption {
        type = types.nullOr types.bool;
        default = true;
        description = "光标是否启用闪烁动画。";
      };

      color = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "自定义光标填充颜色（HEX 格式）。";
      };

      text = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "自定义光标覆盖字符反色颜色。";
      };

      opacity = mkOption {
        type = types.either types.int types.float;
        default = 1.0;
        description = "光标不透明度 (0.0 - 1.0)。";
      };

      clickToMove = mkOption {
        type = types.bool;
        default = true;
        description = "是否支持鼠标点击直接定位移动光标位置。";
      };
    };

    mouse = {
      hideWhileTyping = mkOption {
        type = types.bool;
        default = true;
        description = "键盘输入打字时是否自动隐藏鼠标光标指针。";
      };

      scrollMultiplier = mkOption {
        type = types.either types.int types.str;
        default = 2;
        description = "鼠标滚轮滚动加速倍率。";
      };

      shiftCapture = mkOption {
        type = types.bool;
        default = false;
        description = "按住 Shift 键时是否强制由 Ghostty 客户端捕获鼠标。";
      };
    };

    scrollbackLimit = mkOption {
      type = types.int;
      default = 100000;
      description = "终端回滚缓冲区保留的最大历史行数上限。";
    };

    copyOnSelect = mkOption {
      type = types.either types.bool (types.enum [ "clipboard" ]);
      default = "clipboard";
      description = "选中文本时是否自动复制到系统剪贴板。";
    };

    clipboard = {
      read = mkOption {
        type = types.enum [ "ask" "allow" "deny" ];
        default = "allow";
        description = "终端程序读取系统剪贴板策略。";
      };

      write = mkOption {
        type = types.enum [ "ask" "allow" "deny" ];
        default = "allow";
        description = "终端程序写入系统剪贴板策略。";
      };

      pasteProtection = mkOption {
        type = types.bool;
        default = true;
        description = "多行或包含控制字符文本粘贴时的安全确认保护。";
      };

      pasteBracketedSafe = mkOption {
        type = types.bool;
        default = true;
        description = "是否启用括号化安全粘贴协议 (Bracketed Paste Mode)。";
      };
    };

    confirmCloseSurface = mkOption {
      type = types.bool;
      default = false;
      description = "关闭存在运行中子进程的终端窗口/标签时是否弹出确认提示。";
    };

    quitAfterLastWindowClosed = mkOption {
      type = types.bool;
      default = true;
      description = "当最后一个窗口关闭后是否完全退出 Ghostty 进程。";
    };

    desktopNotifications = mkOption {
      type = types.bool;
      default = true;
      description = "是否允许向系统通知中心发送桌面通知。";
    };

    bell = {
      features = mkOption {
        type = types.listOf types.str;
        default = [
          "no-system"
          "no-audio"
          "attention"
          "title"
          "no-border"
        ];
        description = "响铃通知特性集合。";
      };
    };

    gtk = {
      singleInstance = mkOption {
        type = types.either types.bool (types.enum [ "detect" ]);
        default = true;
        description = "是否启用 GTK 单实例守护模式（极大加速后续窗口呼出速度）。";
      };

      tabsLocation = mkOption {
        type = types.enum [ "top" "bottom" "left" "right" "hidden" ];
        default = "top";
        description = "多标签栏摆放方位。";
      };

      wideTabs = mkOption {
        type = types.bool;
        default = false;
        description = "标签是否拉伸占满顶部宽度。";
      };

      titlebar = mkOption {
        type = types.bool;
        default = false;
        description = "是否显示 GTK 标题栏。";
      };

      customCss = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "GTK 自定义 CSS 样式表路径。";
      };
    };

    quickTerminal = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "是否启用下拉式快速终端（Quake Mode 模式）。";
      };

      position = mkOption {
        type = types.enum [ "top" "bottom" "left" "right" "center" ];
        default = "top";
        description = "快速终端弹出方位。";
      };

      autohide = mkOption {
        type = types.bool;
        default = false;
        description = "失焦时是否自动隐藏快速终端。";
      };

      animationDuration = mkOption {
        type = types.either types.int types.float;
        default = 0.2;
        description = "快速终端弹出动画时长（秒）。";
      };
    };

    customShader = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "自定义 GLSL 着色器特效文件路径（如 CRT 复古扫描线特效）。";
    };

    customShaderAnimation = mkOption {
      type = types.bool;
      default = true;
      description = "自定义着色器是否启用动态时间动画传递。";
    };

    keybinds = mkOption {
      type = types.listOf types.str;
      default = [
        "ctrl+shift+v=paste_from_clipboard"
        "ctrl+shift+c=copy_to_clipboard"
        "ctrl+equal=increase_font_size:1"
        "ctrl+minus=decrease_font_size:1"
        "ctrl+zero=reset_font_size"
        "ctrl+shift+enter=toggle_split_zoom"
        "ctrl+shift+o=new_split:right"
        "ctrl+shift+e=new_split:down"
        "ctrl+shift+w=close_surface"
        "ctrl+shift+t=new_tab"
        "ctrl+shift+n=new_window"
      ];
      description = "Ghostty 快捷键按键绑定映射列表。";
    };

    customThemes = mkOption {
      type = types.attrsOf (types.attrsOf types.anything);
      default = { };
      description = "以 Nix 结构化数据编写的自定义主题字典，将自动写入 ghostty/themes/<name>。";
      example = literalExpression ''
        {
          "custom-dark" = {
            background = "#181825";
            foreground = "#cdd6f4";
            cursor-color = "#f5e0dc";
            palette = [
              "0=#45475a"
              "1=#f38ba8"
              "2=#a6e3a1"
              "3=#f9e2af"
              "4=#89b4fa"
              "5=#f5c2e7"
              "6=#94e2d5"
              "7=#bac2de"
            ];
          };
        }
      '';
    };

    settings = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "以 Nix 结构化数据编写的任意 Ghostty 原生配置，与默认预设深度合并。";
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = "追加写入 ghostty 主配置文件的原生纯文本内容。";
    };

    setAsDefaultTerminal = mkOption {
      type = types.bool;
      default = true;
      description = "是否将 Ghostty 注册并设置为系统与 XDG 默认终端 (xdg-terminal-exec)。";
    };

    systemd = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否启用 Ghostty systemd 用户服务支持。";
      };
    };

    shellIntegration = {
      enableZsh = mkOption {
        type = types.bool;
        default = true;
        description = "是否自动配置 Ghostty 与 Zsh 的深度集成。";
      };

      enableBash = mkOption {
        type = types.bool;
        default = true;
        description = "是否自动配置 Ghostty 与 Bash 的深度集成。";
      };

      enableFish = mkOption {
        type = types.bool;
        default = true;
        description = "是否自动配置 Ghostty 与 Fish 的深度集成。";
      };
    };

    homeManager = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "若系统中启用了 Home Manager，是否自动将 Ghostty 深度配置应用到所有 Home Manager 用户。";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      # 1. NixOS 系统级 Ghostty 软件包安装
      environment.systemPackages = [
        cfg.package
      ];

      # 2. 系统级配置文件部署 (/etc/xdg/ghostty/config 及 /etc/ghostty/config)
      environment.etc = (
        {
          "xdg/ghostty/config".text = generatedConfigText;
          "ghostty/config".text = generatedConfigText;
        }
        // customThemeFiles
        // customThemeEtcFiles
        // (optionalAttrs cfg.setAsDefaultTerminal {
          "xdg/xdg-terminals.list".text = "com.mitchellh.ghostty.desktop\nghostty.desktop\n";
          "xdg/hyprland-xdg-terminals.list".text = "com.mitchellh.ghostty.desktop\nghostty.desktop\n";
        })
      );

      # 3. 注册 XDG 默认终端规范 (xdg-terminal-exec)
      xdg.terminal-exec = mkIf cfg.setAsDefaultTerminal {
        enable = true;
        settings = {
          default = [
            "com.mitchellh.ghostty.desktop"
            "ghostty.desktop"
          ];
          Hyprland = [
            "com.mitchellh.ghostty.desktop"
            "ghostty.desktop"
          ];
          hyprland = [
            "com.mitchellh.ghostty.desktop"
            "ghostty.desktop"
          ];
        };
      };
    }

    # 4. Home Manager 用户级深度联动配置
    (optionalAttrs (options ? home-manager) {
      home-manager = mkIf cfg.homeManager.enable {
        sharedModules = [
          ({ ... }: {
            programs.ghostty = {
              enable = true;
              package = cfg.package;
              settings = finalSettings;
              themes = cfg.customThemes;
              enableZshIntegration = cfg.shellIntegration.enableZsh;
              enableBashIntegration = cfg.shellIntegration.enableBash;
              enableFishIntegration = cfg.shellIntegration.enableFish;
              systemd.enable = cfg.systemd.enable;
            };

            xdg.configFile = mkIf cfg.setAsDefaultTerminal {
              "xdg-terminals.list".text = "com.mitchellh.ghostty.desktop\nghostty.desktop\n";
              "hyprland-xdg-terminals.list".text = "com.mitchellh.ghostty.desktop\nghostty.desktop\n";
            };
          })
        ];
      };
    })
  ]);
}
