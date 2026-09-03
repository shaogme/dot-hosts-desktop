{
  config,
  pkgs,
  lib,
  options,
  ...
}:

with lib;

let
  cfg = config.desktop.terminal.rio;

  tomlFormat = pkgs.formats.toml { };

  cleanSubTable = attrs:
    let
      filtered = filterAttrs (n: v: v != null) attrs;
    in
    if filtered == { } then null else filtered;

  # 内置预设配色方案 (包含完整的 ANSI 16 色、背景色、前景色、光标、分屏线、标签页等)
  builtinThemes = {
    "catppuccin-mocha" = {
      colors = {
        background = "#1e1e2e";
        foreground = "#cdd6f4";
        cursor = "#f5e0dc";
        vi-cursor = "#b4befe";
        tabs = "#6c7086";
        tabs-active = "#cdd6f4";
        split = "#313244";
        split-active = "#cba6f7";
        selection-background = "#585b70";
        selection-foreground = "#cdd6f4";
        search-match-background = "#313244";
        search-match-foreground = "#f9e2af";
        search-focused-match-background = "#f9e2af";
        search-focused-match-foreground = "#1e1e2e";
        black = "#45475a";
        red = "#f38ba8";
        green = "#a6e3a1";
        yellow = "#f9e2af";
        blue = "#89b4fa";
        magenta = "#f5c2e7";
        cyan = "#94e2d5";
        white = "#bac2de";
        light-black = "#585b70";
        light-red = "#f38ba8";
        light-green = "#a6e3a1";
        light-yellow = "#f9e2af";
        light-blue = "#89b4fa";
        light-magenta = "#f5c2e7";
        light-cyan = "#94e2d5";
        light-white = "#a6adc8";
        dim-black = "#313244";
        dim-red = "#eba0ac";
        dim-green = "#94e2d5";
        dim-yellow = "#f9e2af";
        dim-blue = "#74c7ec";
        dim-magenta = "#f5c2e7";
        dim-cyan = "#89dceb";
        dim-white = "#6c7086";
      };
    };

    "catppuccin-latte" = {
      colors = {
        background = "#eff1f5";
        foreground = "#4c4f69";
        cursor = "#dc8a78";
        vi-cursor = "#7287fd";
        tabs = "#9ca0b0";
        tabs-active = "#4c4f69";
        split = "#ccd0da";
        split-active = "#8839ef";
        selection-background = "#acb0be";
        selection-foreground = "#4c4f69";
        black = "#5c5f77";
        red = "#d20f39";
        green = "#40a02b";
        yellow = "#df8e1d";
        blue = "#1e66f5";
        magenta = "#ea76cb";
        cyan = "#179299";
        white = "#acb0be";
        light-black = "#6c6f85";
        light-red = "#d20f39";
        light-green = "#40a02b";
        light-yellow = "#df8e1d";
        light-blue = "#1e66f5";
        light-magenta = "#ea76cb";
        light-cyan = "#179299";
        light-white = "#bcc0cc";
      };
    };

    "tokyo-night" = {
      colors = {
        background = "#1a1b26";
        foreground = "#c0caf5";
        cursor = "#c0caf5";
        vi-cursor = "#7aa2f7";
        tabs = "#565f89";
        tabs-active = "#7aa2f7";
        split = "#24283b";
        split-active = "#bb9af7";
        selection-background = "#283457";
        selection-foreground = "#c0caf5";
        black = "#15161e";
        red = "#f7768e";
        green = "#9ece6a";
        yellow = "#e0af68";
        blue = "#7aa2f7";
        magenta = "#bb9af7";
        cyan = "#7dcfff";
        white = "#a9b1d6";
        light-black = "#414868";
        light-red = "#f7768e";
        light-green = "#9ece6a";
        light-yellow = "#e0af68";
        light-blue = "#7aa2f7";
        light-magenta = "#bb9af7";
        light-cyan = "#7dcfff";
        light-white = "#c0caf5";
      };
    };

    "nord" = {
      colors = {
        background = "#2e3440";
        foreground = "#d8dee9";
        cursor = "#d8dee9";
        vi-cursor = "#88c0d0";
        tabs = "#4c566a";
        tabs-active = "#eceff4";
        split = "#3b4252";
        split-active = "#88c0d0";
        selection-background = "#434c5e";
        selection-foreground = "#eceff4";
        black = "#3b4252";
        red = "#bf616a";
        green = "#a3be8c";
        yellow = "#ebcb8b";
        blue = "#81a1c1";
        magenta = "#b48ead";
        cyan = "#88c0d0";
        white = "#e5e9f0";
        light-black = "#4c566a";
        light-red = "#bf616a";
        light-green = "#a3be8c";
        light-yellow = "#ebcb8b";
        light-blue = "#81a1c1";
        light-magenta = "#b48ead";
        light-cyan = "#8fbcbb";
        light-white = "#eceff4";
      };
    };

    "dracula" = {
      colors = {
        background = "#282a36";
        foreground = "#f8f8f2";
        cursor = "#f8f8f2";
        vi-cursor = "#bd93f9";
        tabs = "#6272a4";
        tabs-active = "#f8f8f2";
        split = "#44475a";
        split-active = "#bd93f9";
        selection-background = "#44475a";
        selection-foreground = "#f8f8f2";
        black = "#21222c";
        red = "#ff5555";
        green = "#50fa7b";
        yellow = "#f1fa8c";
        blue = "#bd93f9";
        magenta = "#ff79c6";
        cyan = "#8be9fd";
        white = "#f8f8f2";
        light-black = "#6272a4";
        light-red = "#ff6e6e";
        light-green = "#69ff94";
        light-yellow = "#ffffa5";
        light-blue = "#d6acff";
        light-magenta = "#ff92df";
        light-cyan = "#a4ffff";
        light-white = "#ffffff";
      };
    };

    "gruvbox-dark" = {
      colors = {
        background = "#282828";
        foreground = "#ebdbb2";
        cursor = "#ebdbb2";
        vi-cursor = "#fabd2f";
        tabs = "#928374";
        tabs-active = "#ebdbb2";
        split = "#3c3836";
        split-active = "#d79921";
        selection-background = "#504945";
        selection-foreground = "#ebdbb2";
        black = "#282828";
        red = "#cc241d";
        green = "#98971a";
        yellow = "#d79921";
        blue = "#458588";
        magenta = "#b16286";
        cyan = "#689d6a";
        white = "#a89984";
        light-black = "#928374";
        light-red = "#fb4934";
        light-green = "#b8bb26";
        light-yellow = "#fabd2f";
        light-blue = "#83a598";
        light-magenta = "#d3869b";
        light-cyan = "#8ec07c";
        light-white = "#ebdbb2";
      };
    };

    "one-dark" = {
      colors = {
        background = "#282c34";
        foreground = "#abb2bf";
        cursor = "#528bff";
        vi-cursor = "#c678dd";
        tabs = "#5c6370";
        tabs-active = "#abb2bf";
        split = "#3e4452";
        split-active = "#61afef";
        selection-background = "#3e4452";
        selection-foreground = "#abb2bf";
        black = "#282c34";
        red = "#e06c75";
        green = "#98c379";
        yellow = "#e5c07b";
        blue = "#61afef";
        magenta = "#c678dd";
        cyan = "#56b6c2";
        white = "#abb2bf";
        light-black = "#5c6370";
        light-red = "#be5046";
        light-green = "#98c379";
        light-yellow = "#e5c07b";
        light-blue = "#61afef";
        light-magenta = "#c678dd";
        light-cyan = "#56b6c2";
        light-white = "#ffffff";
      };
    };
  };

  # 合并内置与用户自定义主题
  allThemes = recursiveUpdate builtinThemes cfg.customThemes;

  # 构建基础配置字典 (过滤掉 null 值)
  baseSettings = filterAttrs (n: v: v != null) {
    theme = cfg.theme;
    adaptive-theme = cleanSubTable {
      dark = cfg.adaptiveTheme.dark;
      light = cfg.adaptiveTheme.light;
    };
    force-theme = cfg.forceTheme;
    confirm-before-quit = cfg.confirmBeforeQuit;
    line-height = cfg.lineHeight;
    grapheme-clustering = cfg.graphemeClustering;
    copy-on-select = cfg.copyOnSelect;
    hide-mouse-cursor-when-typing = cfg.hideCursorWhenTyping;
    draw-bold-text-with-light-colors = cfg.drawBoldTextWithLightColors;
    ignore-selection-foreground-color = cfg.ignoreSelectionForegroundColor;
    use-fork = cfg.useFork;
    working-dir = cfg.workingDir;
    scrollback-history-limit = cfg.scrollbackHistoryLimit;
    env-vars = if cfg.envVars != [ ] then cfg.envVars else null;
    option-as-alt = if cfg.optionAsAlt != "none" then cfg.optionAsAlt else null;

    shell = cleanSubTable {
      program = cfg.shell.program;
      args = if cfg.shell.args != [ ] then cfg.shell.args else null;
    };

    editor = cleanSubTable {
      program = cfg.editor.program;
      args = if cfg.editor.args != [ ] then cfg.editor.args else null;
    };

    fonts = cleanSubTable {
      size = cfg.fonts.size;
      family = cfg.fonts.family;
      features = if cfg.fonts.features != [ ] then cfg.fonts.features else null;
      hinting = cfg.fonts.hinting;
      use-drawable-chars = cfg.fonts.useDrawableChars;
      disable-warnings-not-found = cfg.fonts.disableWarningsNotFound;
      additional-dirs = if cfg.fonts.additionalDirs != [ ] then cfg.fonts.additionalDirs else null;

      regular = cleanSubTable {
        family = cfg.fonts.regular.family;
        style = cfg.fonts.regular.style;
        weight = cfg.fonts.regular.weight;
      };

      bold = cleanSubTable {
        family = cfg.fonts.bold.family;
        style = cfg.fonts.bold.style;
        weight = cfg.fonts.bold.weight;
      };

      italic = cleanSubTable {
        family = cfg.fonts.italic.family;
        style = cfg.fonts.italic.style;
        weight = cfg.fonts.italic.weight;
      };

      bold-italic = cleanSubTable {
        family = cfg.fonts.boldItalic.family;
        style = cfg.fonts.boldItalic.style;
        weight = cfg.fonts.boldItalic.weight;
      };

      symbol-map = if cfg.fonts.symbolMap != [ ] then cfg.fonts.symbolMap else null;
    };

    window = cleanSubTable {
      width = cfg.window.width;
      height = cfg.window.height;
      mode = cfg.window.mode;
      opacity = cfg.window.opacity;
      opacity-cells = cfg.window.opacityCells;
      blur = cfg.window.blur;
      decorations = cfg.window.decorations;
      colorspace = cfg.window.colorspace;
      columns = cfg.window.columns;
      rows = cfg.window.rows;
      quake-width-percentage = cfg.window.quake.widthPercentage;
      quake-height-percentage = cfg.window.quake.heightPercentage;
      background-image =
        if cfg.window.backgroundImage.path != null then {
          path = toString cfg.window.backgroundImage.path;
          opacity = cfg.window.backgroundImage.opacity;
        } else null;
    };

    cursor = cleanSubTable {
      shape = cfg.cursor.shape;
      blinking = cfg.cursor.blinking;
      blinking-interval = cfg.cursor.blinkingInterval;
    };

    scroll = cleanSubTable {
      multiplier = cfg.scroll.multiplier;
      divider = cfg.scroll.divider;
    };

    enable-scroll-bar = cfg.scroll.enableScrollBar;

    navigation = cleanSubTable {
      mode = cfg.navigation.mode;
      clickable = cfg.navigation.clickable;
      current-working-directory = cfg.navigation.currentWorkingDirectory;
      use-terminal-title = cfg.navigation.useTerminalTitle;
      hide-if-single = cfg.navigation.hideIfSingle;
      use-split = cfg.navigation.useSplit;
      open-config-with-split = cfg.navigation.openConfigWithSplit;
      unfocused-split-opacity = cfg.navigation.unfocusedSplitOpacity;
      unfocused-split-fill = cfg.navigation.unfocusedSplitFill;
      max-tab-width = cfg.navigation.maxTabWidth;
      color-automation = if cfg.navigation.colorAutomation != [ ] then cfg.navigation.colorAutomation else null;
    };

    renderer = cleanSubTable {
      backend = cfg.renderer.backend;
      strategy = cfg.renderer.strategy;
      disable-unfocused-render = cfg.renderer.disableUnfocusedRender;
      disable-occluded-render = cfg.renderer.disableOccludedRender;
      use-cpu = cfg.renderer.useCpu;
    };

    effects = cleanSubTable {
      custom-mouse-cursor = cfg.effects.customMouseCursor;
      trail-cursor = cfg.effects.trailCursor;
      trail-cursor-color = cfg.effects.trailCursorColor;
      trail-cursor-opacity = cfg.effects.trailCursorOpacity;
      trail-cursor-decay = if cfg.effects.trailCursor then cfg.effects.trailCursorDecay else null;
      trail-cursor-start-threshold = if cfg.effects.trailCursor then cfg.effects.trailCursorStartThreshold else null;
    };

    keyboard = cleanSubTable {
      ime-cursor-positioning = cfg.keyboard.imeCursorPositioning;
      disable-ctlseqs-alt = cfg.keyboard.disableCtlseqsAlt;
      forward-to-ime-modifier-mask = if cfg.keyboard.forwardToImeModifierMask != [ ] then cfg.keyboard.forwardToImeModifierMask else null;
    };

    developer = cleanSubTable {
      log-level = cfg.developer.logLevel;
      enable-log-file = cfg.developer.enableLogFile;
      enable-fps-counter = cfg.developer.enableFpsCounter;
    };

    bell = cleanSubTable {
      audio = cfg.bell.audio;
    };

    bindings = cleanSubTable {
      keys = if cfg.bindings.keys != [ ] then cfg.bindings.keys else null;
    };

    colors = cleanSubTable cfg.colors;
  };

  # 合并用户自由定义的 settings 字典
  finalSettings = recursiveUpdate baseSettings cfg.settings;

  # 生成基础 TOML 配置文件 Derivation
  baseConfigFile = tomlFormat.generate "rio-base.toml" finalSettings;

  # 若提供了 extraConfig 纯文本片段，则追加到生成的 TOML 配置文件尾部
  configFile =
    if cfg.extraConfig != "" then
      pkgs.runCommand "rio.toml" { } ''
        cat ${baseConfigFile} > $out
        echo "" >> $out
        cat ${pkgs.writeText "rio-extra.toml" cfg.extraConfig} >> $out
      ''
    else
      baseConfigFile;

  # 自定义及内置主题文件映射 (/etc/xdg/rio/themes/<name>.toml 及 /etc/rio/themes/<name>.toml)
  makeThemeFile = name: themeAttrs:
    let
      # 确保主题结构包含 [colors] 顶层表
      formattedTheme = if themeAttrs ? colors then themeAttrs else { colors = themeAttrs; };
    in
    tomlFormat.generate "rio-theme-${name}.toml" formattedTheme;

  customThemeXdgFiles = mapAttrs' (
    name: themeAttrs:
    nameValuePair "xdg/rio/themes/${name}.toml" {
      source = makeThemeFile name themeAttrs;
    }
  ) allThemes;

  customThemeEtcFiles = mapAttrs' (
    name: themeAttrs:
    nameValuePair "rio/themes/${name}.toml" {
      source = makeThemeFile name themeAttrs;
    }
  ) allThemes;

  customThemeHomeFiles = mapAttrs' (
    name: themeAttrs:
    nameValuePair "rio/themes/${name}.toml" {
      source = makeThemeFile name themeAttrs;
    }
  ) allThemes;
in
{
  options.desktop.terminal.rio = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "是否启用 Rio 现代化硬件加速 GPU 终端模拟器（默认关闭）。";
    };

    package = mkPackageOption pkgs "rio" { };

    theme = mkOption {
      type = types.nullOr types.str;
      default = "catppuccin-mocha";
      description = "Rio 终端配色主题名称（可使用内置主题如 catppuccin-mocha, catppuccin-latte, tokyo-night, nord, dracula, gruvbox-dark, one-dark，或在 customThemes 中声明）。";
    };

    adaptiveTheme = {
      dark = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "系统暗色模式下激活的主题名称。";
      };

      light = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "系统明亮模式下激活的主题名称。";
      };
    };

    forceTheme = mkOption {
      type = types.nullOr (types.enum [ "dark" "light" ]);
      default = null;
      description = "强制指定终端外观模式（dark / light），忽略系统自适应。";
    };

    confirmBeforeQuit = mkOption {
      type = types.bool;
      default = false;
      description = "退出终端前是否需要确认提示。";
    };

    lineHeight = mkOption {
      type = types.either types.int types.float;
      default = 1.0;
      description = "终端字符单元行高比例系数。";
    };

    graphemeClustering = mkOption {
      type = types.bool;
      default = true;
      description = "是否启用 Unicode 字素簇单元排版（支持复杂连字、宽字符与多码点符号）。";
    };

    copyOnSelect = mkOption {
      type = types.bool;
      default = true;
      description = "鼠标选中文本时是否自动复制到系统剪贴板。";
    };

    hideCursorWhenTyping = mkOption {
      type = types.bool;
      default = true;
      description = "键盘打字输入时是否自动隐藏鼠标指针。";
    };

    drawBoldTextWithLightColors = mkOption {
      type = types.bool;
      default = false;
      description = "粗体文本是否自动使用对应的亮色系颜色绘制。";
    };

    ignoreSelectionForegroundColor = mkOption {
      type = types.bool;
      default = false;
      description = "是否忽略选中文本前景色以保留原有语法高亮颜色。";
    };

    useFork = mkOption {
      type = types.bool;
      default = true;
      description = "在 Linux 环境下是否使用 fork 机制衍生终端子进程。";
    };

    workingDir = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "终端启动时默认的工作目录路径（留空则跟随启动环境）。";
    };

    scrollbackHistoryLimit = mkOption {
      type = types.int;
      default = 100000;
      description = "终端回滚缓冲区保留的最大历史行数上限。";
    };

    envVars = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "为终端进程注入的环境变量列表（例如 [ \"TERM=xterm-256color\" ]）。";
    };

    optionAsAlt = mkOption {
      type = types.enum [ "none" "left" "right" "both" ];
      default = "none";
      description = "将 Option / Alt 键处理为 Alt 控制修饰键的策略。";
    };

    shell = {
      program = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "终端启动时执行的默认 Shell 程序（留空自动使用系统默认登录 Shell）。";
      };

      args = mkOption {
        type = types.listOf types.str;
        default = [ "--login" ];
        description = "启动 Shell 时传递的参数列表。";
      };
    };

    editor = {
      program = mkOption {
        type = types.str;
        default = "vi";
        description = "Rio 打开配置文件时调用的文本编辑器命令。";
      };

      args = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "调用编辑器时传递的命令行参数。";
      };
    };

    fonts = {
      family = mkOption {
        type = types.str;
        default = "Maple Mono NF CN";
        description = "终端默认主等宽字体族名称。";
      };

      size = mkOption {
        type = types.either types.int types.float;
        default = 13.0;
        description = "终端默认字体字号大小（点数 pt）。";
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

      hinting = mkOption {
        type = types.bool;
        default = true;
        description = "是否启用字体微调渲染 (Hinting)。";
      };

      useDrawableChars = mkOption {
        type = types.bool;
        default = true;
        description = "是否使用内置高质量字符渲染制表符与边框。";
      };

      disableWarningsNotFound = mkOption {
        type = types.bool;
        default = false;
        description = "字体未找到时是否抑制控制台警告提示。";
      };

      additionalDirs = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "额外加载字体的自定义搜索目录路径列表。";
      };

      regular = {
        family = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "常规常规字重字体族。";
        };

        style = mkOption {
          type = types.nullOr (types.either types.str types.bool);
          default = null;
          description = "常规字型样式名称或禁用 (false)。";
        };

        weight = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "常规字重数值 (如 400)。";
        };
      };

      bold = {
        family = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "粗体字体族。";
        };

        style = mkOption {
          type = types.nullOr (types.either types.str types.bool);
          default = null;
          description = "粗体字型样式名称或禁用 (false)。";
        };

        weight = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "粗体字重数值 (如 800)。";
        };
      };

      italic = {
        family = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "斜体字体族。";
        };

        style = mkOption {
          type = types.nullOr (types.either types.str types.bool);
          default = null;
          description = "斜体字型样式名称或禁用 (false)。";
        };

        weight = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "斜体字重数值 (如 400)。";
        };
      };

      boldItalic = {
        family = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "粗斜体字体族。";
        };

        style = mkOption {
          type = types.nullOr (types.either types.str types.bool);
          default = null;
          description = "粗斜体字型样式名称或禁用 (false)。";
        };

        weight = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "粗斜体字重数值 (如 800)。";
        };
      };

      symbolMap = mkOption {
        type = types.listOf (types.attrsOf types.str);
        default = [ ];
        description = "特定 Unicode 字符区间的字体映射列表。";
      };
    };

    window = {
      width = mkOption {
        type = types.int;
        default = 600;
        description = "终端窗口初始宽度像素大小。";
      };

      height = mkOption {
        type = types.int;
        default = 400;
        description = "终端窗口初始高度像素大小。";
      };

      mode = mkOption {
        type = types.enum [ "Windowed" "Maximized" "Fullscreen" ];
        default = "Windowed";
        description = "窗口启动模式。";
      };

      opacity = mkOption {
        type = types.either types.int types.float;
        default = 0.92;
        description = "终端背景透明度 (0.0 完全透明 - 1.0 完全不透明)。";
      };

      opacityCells = mkOption {
        type = types.bool;
        default = false;
        description = "背景透明度是否同时作用于带显式背景色的字符单元。";
      };

      blur = mkOption {
        type = types.either types.bool (types.enum [ "macos-glass-regular" "macos-glass-clear" ]);
        default = true;
        description = "是否启用合成器背景毛玻璃模糊效果。";
      };

      decorations = mkOption {
        type = types.enum [ "Enabled" "Disabled" "Transparent" "Buttonless" ];
        default = "Disabled";
        description = "窗口标题栏与客户端边框装饰（Hyprland 平铺环境下推荐 Disabled）。";
      };

      colorspace = mkOption {
        type = types.enum [ "srgb" "display-p3" "rec2020" ];
        default = "srgb";
        description = "窗口颜色空间标准。";
      };

      columns = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "窗口初始字符列数。";
      };

      rows = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "窗口初始字符行数。";
      };

      quake = {
        widthPercentage = mkOption {
          type = types.either types.int types.float;
          default = 1.0;
          description = "Quake 下拉模式窗口占屏幕宽度的比例 (0.0 - 1.0)。";
        };

        heightPercentage = mkOption {
          type = types.either types.int types.float;
          default = 0.4;
          description = "Quake 下拉模式窗口占屏幕高度的比例 (0.0 - 1.0)。";
        };
      };

      backgroundImage = {
        path = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "窗口背景壁纸图片路径。";
        };

        opacity = mkOption {
          type = types.either types.int types.float;
          default = 1.0;
          description = "背景图片不透明度 (0.0 - 1.0)。";
        };
      };
    };

    cursor = {
      shape = mkOption {
        type = types.enum [ "beam" "block" "underline" ];
        default = "beam";
        description = "光标显示外观形状（beam 竖线, block 方块, underline 下划线）。";
      };

      blinking = mkOption {
        type = types.bool;
        default = true;
        description = "光标是否启用闪烁动画。";
      };

      blinkingInterval = mkOption {
        type = types.int;
        default = 800;
        description = "光标闪烁频率间隔（毫秒，350-1200）。";
      };
    };

    scroll = {
      multiplier = mkOption {
        type = types.either types.int types.float;
        default = 3.0;
        description = "鼠标滚轮滚动速度倍率。";
      };

      divider = mkOption {
        type = types.either types.int types.float;
        default = 1.0;
        description = "滚动灵敏度微调分频器。";
      };

      enableScrollBar = mkOption {
        type = types.bool;
        default = false;
        description = "是否显示右侧滚动条。";
      };
    };

    navigation = {
      mode = mkOption {
        type = types.enum [ "Tab" "Plain" "NativeTab" ];
        default = "Tab";
        description = "导航多标签栏展示模式（Tab 原生 GPU 标签栏，Plain 纯净无标签栏）。";
      };

      clickable = mkOption {
        type = types.bool;
        default = true;
        description = "多标签栏是否支持鼠标点击交互。";
      };

      currentWorkingDirectory = mkOption {
        type = types.bool;
        default = true;
        description = "标签标题是否自动显示当前工作目录相对路径。";
      };

      useTerminalTitle = mkOption {
        type = types.bool;
        default = false;
        description = "是否优先采用应用程序设置的终端动态标题。";
      };

      hideIfSingle = mkOption {
        type = types.bool;
        default = true;
        description = "仅有一个标签页时是否自动隐藏标签栏。";
      };

      useSplit = mkOption {
        type = types.bool;
        default = true;
        description = "是否启用分屏拆分面板支持。";
      };

      openConfigWithSplit = mkOption {
        type = types.bool;
        default = true;
        description = "快捷打开配置编辑器时是否自动分屏。";
      };

      unfocusedSplitOpacity = mkOption {
        type = types.either types.int types.float;
        default = 0.85;
        description = "失焦分屏面板的透明度 (0.15 - 1.0)。";
      };

      unfocusedSplitFill = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "失焦分屏面板遮罩填充颜色 HEX。";
      };

      maxTabWidth = mkOption {
        type = types.either types.int types.float;
        default = 240.0;
        description = "标签项最大像素宽度上限 (80.0 - 280.0)。";
      };

      colorAutomation = mkOption {
        type = types.listOf (types.attrsOf types.str);
        default = [ ];
        description = "根据程序或路径模式自动为标签页着色的规则列表。";
      };
    };

    renderer = {
      backend = mkOption {
        type = types.enum [ "Vulkan" "Webgpu" "Metal" ];
        default = "Vulkan";
        description = "渲染图形后端引擎（Linux Wayland 环境下强烈推荐 Vulkan）。";
      };

      strategy = mkOption {
        type = types.enum [ "Events" "Game" ];
        default = "Events";
        description = "渲染帧率调度策略（Events 基于事件按需重绘，极度省电；Game 连续游戏循环）。";
      };

      disableUnfocusedRender = mkOption {
        type = types.bool;
        default = false;
        description = "窗口失焦时是否挂起渲染以大幅节省能耗。";
      };

      disableOccludedRender = mkOption {
        type = types.bool;
        default = false;
        description = "窗口被其他窗口完全遮挡时是否停止渲染。";
      };

      useCpu = mkOption {
        type = types.bool;
        default = false;
        description = "是否启用 CPU 软件光栅化渲染器（实验性）。";
      };
    };

    effects = {
      customMouseCursor = mkOption {
        type = types.bool;
        default = false;
        description = "是否启用 Rio 自定义图形鼠标指针。";
      };

      trailCursor = mkOption {
        type = types.bool;
        default = false;
        description = "是否启用光标移动粒子拖尾特效。";
      };

      trailCursorColor = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "拖尾特效颜色 HEX（留空自动跟随光标主色）。";
      };

      trailCursorOpacity = mkOption {
        type = types.either types.int types.float;
        default = 1.0;
        description = "拖尾特效不透明度 (0.0 - 1.0)。";
      };

      trailCursorDecay = mkOption {
        type = types.listOf types.int;
        default = [ 100 400 ];
        description = "拖尾消散延迟时间范围 [快速端, 慢速端]（毫秒）。";
      };

      trailCursorStartThreshold = mkOption {
        type = types.int;
        default = 2;
        description = "触发拖尾效果的光标最小跨越单元格距离阈值。";
      };
    };

    keyboard = {
      imeCursorPositioning = mkOption {
        type = types.bool;
        default = true;
        description = "输入法候选词浮窗是否精确吸附于光标位置（Fcitx5 / Rime 深度整合）。";
      };

      disableCtlseqsAlt = mkOption {
        type = types.bool;
        default = false;
        description = "是否禁用带 ALT 键的控制序列。";
      };

      forwardToImeModifierMask = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "直接转发给输入法的修饰键掩码列表。";
      };
    };

    developer = {
      logLevel = mkOption {
        type = types.enum [ "OFF" "ERROR" "WARN" "INFO" "DEBUG" "TRACE" ];
        default = "OFF";
        description = "调试日志记录级别。";
      };

      enableLogFile = mkOption {
        type = types.bool;
        default = false;
        description = "是否将终端日志写入配置目录下的日志文件。";
      };

      enableFpsCounter = mkOption {
        type = types.bool;
        default = false;
        description = "是否在窗口角标显示实时渲染帧率 FPS 计数器。";
      };
    };

    bell = {
      audio = mkOption {
        type = types.bool;
        default = false;
        description = "终端产生响铃控制符时是否播放系统音频声响。";
      };
    };

    bindings = {
      keys = mkOption {
        type = types.listOf (types.attrsOf types.anything);
        default = [
          { key = "c"; "with" = "ctrl | shift"; action = "copy"; }
          { key = "v"; "with" = "ctrl | shift"; action = "paste"; }
          { key = "t"; "with" = "ctrl | shift"; action = "createtab"; }
          { key = "w"; "with" = "ctrl | shift"; action = "closesplitortab"; }
          { key = "n"; "with" = "ctrl | shift"; action = "createwindow"; }
          { key = "o"; "with" = "ctrl | shift"; action = "splitright"; }
          { key = "e"; "with" = "ctrl | shift"; action = "splitdown"; }
          { key = "Left"; "with" = "ctrl | shift"; action = "selectprevtab"; }
          { key = "Right"; "with" = "ctrl | shift"; action = "selectnexttab"; }
          { key = "equal"; "with" = "ctrl"; action = "increasefontsize"; }
          { key = "plus"; "with" = "ctrl"; action = "increasefontsize"; }
          { key = "minus"; "with" = "ctrl"; action = "decreasefontsize"; }
          { key = "0"; "with" = "ctrl"; action = "resetfontsize"; }
          { key = "Space"; "with" = "ctrl | shift"; action = "togglevimode"; }
          { key = "f"; "with" = "ctrl | shift"; action = "searchforward"; }
        ];
        description = "Rio 快捷键绑定规则列表。";
      };
    };

    colors = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "直接注入并覆盖当前配色方案的颜色键值表。";
    };

    customThemes = mkOption {
      type = types.attrsOf (types.attrsOf types.anything);
      default = { };
      description = "以 Nix 结构化数据编写的自定义配色主题字典，将自动写入 xdg/rio/themes/<name>.toml。";
      example = literalExpression ''
        {
          "my-dark-theme" = {
            colors = {
              background = "#181825";
              foreground = "#cdd6f4";
              cursor = "#f5e0dc";
              black = "#45475a";
              red = "#f38ba8";
              green = "#a6e3a1";
              yellow = "#f9e2af";
              blue = "#89b4fa";
              magenta = "#f5c2e7";
              cyan = "#94e2d5";
              white = "#bac2de";
            };
          };
        }
      '';
    };

    settings = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "以 Nix 结构化数据编写的任意 Rio 原生 TOML 配置，将与默认预设深度合并。";
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = "追加写入 rio 主配置文件的原生纯文本 TOML 内容。";
    };

    setAsDefaultTerminal = mkOption {
      type = types.bool;
      default = true;
      description = "是否将 Rio 注册并设置为系统与 XDG 默认终端 (xdg-terminal-exec)。";
    };

    homeManager = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "若系统中启用了 Home Manager，是否自动将 Rio 深度配置应用到所有 Home Manager 用户。";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      # 1. NixOS 系统级 Rio 软件包安装
      environment.systemPackages = [
        cfg.package
      ];

      # 2. 系统级配置文件部署 (/etc/xdg/rio/config.toml 及 /etc/rio/config.toml)
      environment.etc = (
        {
          "xdg/rio/config.toml".source = configFile;
          "rio/config.toml".source = configFile;
        }
        // customThemeXdgFiles
        // customThemeEtcFiles
        // (optionalAttrs cfg.setAsDefaultTerminal {
          "xdg/xdg-terminals.list".text = "rio.desktop\n";
          "xdg/niri-xdg-terminals.list".text = "rio.desktop\n";
        })
      );

      # 3. 注册 XDG 默认终端规范 (xdg-terminal-exec)
      xdg.terminal-exec = mkIf cfg.setAsDefaultTerminal {
        enable = true;
        settings = {
          default = [
            "rio.desktop"
          ];
          Niri = [
            "rio.desktop"
          ];
          niri = [
            "rio.desktop"
          ];
        };
      };
    }

    # 4. Home Manager 用户级深度联动配置
    (optionalAttrs (options ? home-manager) {
      home-manager = mkIf cfg.homeManager.enable {
        sharedModules = [
          ({ ... }: {
            xdg.configFile = (
              {
                "rio/config.toml".source = configFile;
              }
              // customThemeHomeFiles
              // (optionalAttrs cfg.setAsDefaultTerminal {
                "xdg-terminals.list".text = "rio.desktop\n";
                "niri-xdg-terminals.list".text = "rio.desktop\n";
              })
            );
          })
        ];
      };
    })
  ]);
}
