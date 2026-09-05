{
  config,
  pkgs,
  lib,
  options,
  ...
}:

with lib;

let
  cfg = config.desktop.launcher.fuzzel;
  themeCfg = config.desktop.theme;

  iniFormat = pkgs.formats.ini { };

  # 直接引入调色板模块 modules/theme/palette.nix
  paletteLib = import ../../theme/palette.nix { inherit lib; };

  # ── 全格式数学级色彩转换引擎 ──────────────────────────────────────────
  colorLib = rec {
    hexDigits = [ "0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "a" "b" "c" "d" "e" "f" ];

    # 将 0-255 整数转为 2 位小写 16 进制字符串
    toHex2 = n:
      let
        clamped = if n < 0 then 0 else if n > 255 then 255 else n;
        hi = clamped / 16;
        lo = clamped - (hi * 16);
      in
      "${builtins.elemAt hexDigits hi}${builtins.elemAt hexDigits lo}";

    # 将浮点 Alpha 字符串 (如 "0.85", "1.0", "0") 转换为 0-255 对应的 2 位 16 进制
    alphaToHex2 = a:
      if a == "1" || a == "1.0" then "ff"
      else if a == "0" || a == "0.0" then "00"
      else
        let
          m = builtins.match "0\\.([0-9]+)" a;
        in
        if m == null then "ff"
        else
          let
            fracStr = builtins.head m;
            paddedFrac = if builtins.stringLength fracStr == 1 then "${fracStr}0" else builtins.substring 0 2 fracStr;
            val = (lib.toInt paddedFrac) * 255 / 100;
          in
          toHex2 val;

    # 全能转换函数：将 #RGB, #RRGGBB, #RRGGBBAA, rgb(r,g,b), rgba(r,g,b,a) 规范化为 RRGGBBAA
    toFuzzelColor = rawColor: fallback:
      let
        c = lib.strings.trim (toString rawColor);
        rgbaMatch = builtins.match "rgba\\(([0-9]+),[ ]*([0-9]+),[ ]*([0-9]+),[ ]*([0-9.]+)\\)" c;
        rgbMatch = builtins.match "rgb\\(([0-9]+),[ ]*([0-9]+),[ ]*([0-9]+)\\)" c;
        cleanHex = lib.removePrefix "#" c;
        hexLen = builtins.stringLength cleanHex;
      in
      if rgbaMatch != null then
        let
          r = lib.toInt (builtins.elemAt rgbaMatch 0);
          g = lib.toInt (builtins.elemAt rgbaMatch 1);
          b = lib.toInt (builtins.elemAt rgbaMatch 2);
          aHex = alphaToHex2 (builtins.elemAt rgbaMatch 3);
        in
        "${toHex2 r}${toHex2 g}${toHex2 b}${aHex}"
      else if rgbMatch != null then
        let
          r = lib.toInt (builtins.elemAt rgbMatch 0);
          g = lib.toInt (builtins.elemAt rgbMatch 1);
          b = lib.toInt (builtins.elemAt rgbMatch 2);
        in
        "${toHex2 r}${toHex2 g}${toHex2 b}ff"
      else if hexLen == 6 then
        "${lib.toLower cleanHex}ff"
      else if hexLen == 8 then
        lib.toLower cleanHex
      else
        fallback;
  };

  # 深色模式颜色映射（优先读取 desktop.theme.palette.dark，回退 paletteLib.palettes.dark）
  darkColorsDerived = {
    background = colorLib.toFuzzelColor (themeCfg.palette.dark.background or paletteLib.palettes.dark.background) "14141cd8";
    text = colorLib.toFuzzelColor (themeCfg.palette.dark.foreground or paletteLib.palettes.dark.foreground) "cdd6f4ff";
    prompt = colorLib.toFuzzelColor (themeCfg.palette.dark.accent or paletteLib.palettes.dark.accent) "89b4faff";
    placeholder = colorLib.toFuzzelColor (themeCfg.palette.dark.foregroundDim or paletteLib.palettes.dark.foregroundDim) "6c7086ff";
    input = colorLib.toFuzzelColor (themeCfg.palette.dark.foreground or paletteLib.palettes.dark.foreground) "cdd6f4ff";
    match = colorLib.toFuzzelColor (themeCfg.palette.dark.critical or paletteLib.palettes.dark.critical) "f38ba8ff";
    selection = colorLib.toFuzzelColor (themeCfg.palette.dark.selectedBg or paletteLib.palettes.dark.selectedBg) "313244ff";
    selection-text = colorLib.toFuzzelColor (themeCfg.palette.dark.foreground or paletteLib.palettes.dark.foreground) "cdd6f4ff";
    selection-match = colorLib.toFuzzelColor (themeCfg.palette.dark.warning or paletteLib.palettes.dark.warning) "f9e2afff";
    counter = colorLib.toFuzzelColor (themeCfg.palette.dark.foregroundDim or paletteLib.palettes.dark.foregroundDim) "6c7086ff";
    border = colorLib.toFuzzelColor (themeCfg.palette.dark.activeBorder or paletteLib.palettes.dark.activeBorder) "89b4faff";
  };

  # 浅色模式颜色映射（优先读取 desktop.theme.palette.light，回退 paletteLib.palettes.light）
  lightColorsDerived = {
    background = colorLib.toFuzzelColor (themeCfg.palette.light.background or paletteLib.palettes.light.background) "eff1f5e6";
    text = colorLib.toFuzzelColor (themeCfg.palette.light.foreground or paletteLib.palettes.light.foreground) "4c4f69ff";
    prompt = colorLib.toFuzzelColor (themeCfg.palette.light.accent or paletteLib.palettes.light.accent) "1e66f5ff";
    placeholder = colorLib.toFuzzelColor (themeCfg.palette.light.foregroundDim or paletteLib.palettes.light.foregroundDim) "8c8fa1ff";
    input = colorLib.toFuzzelColor (themeCfg.palette.light.foreground or paletteLib.palettes.light.foreground) "4c4f69ff";
    match = colorLib.toFuzzelColor (themeCfg.palette.light.critical or paletteLib.palettes.light.critical) "d20f39ff";
    selection = colorLib.toFuzzelColor (themeCfg.palette.light.selectedBg or paletteLib.palettes.light.selectedBg) "ccd0daff";
    selection-text = colorLib.toFuzzelColor (themeCfg.palette.light.foreground or paletteLib.palettes.light.foreground) "4c4f69ff";
    selection-match = colorLib.toFuzzelColor (themeCfg.palette.light.warning or paletteLib.palettes.light.warning) "df8e1dff";
    counter = colorLib.toFuzzelColor (themeCfg.palette.light.foregroundDim or paletteLib.palettes.light.foregroundDim) "8c8fa1ff";
    border = colorLib.toFuzzelColor (themeCfg.palette.light.activeBorder or paletteLib.palettes.light.activeBorder) "1e66f5ff";
  };

  darkColors = darkColorsDerived // cfg.theme.darkColors;
  lightColors = lightColorsDerived // cfg.theme.lightColors;

  # 基础开箱即用布局参数
  baseSettings = {
    main = {
      terminal = cfg.terminal;
      layer = cfg.layout.layer;
      exit-on-keyboard-focus-loss = if cfg.layout.exitOnFocusLoss then "yes" else "no";
      keyboard-focus = cfg.layout.keyboardFocus;
      anchor = cfg.layout.anchor;
      prompt = ''"${cfg.layout.prompt}"'';
      placeholder = ''"${cfg.layout.placeholder}"'';
      lines = cfg.layout.lines;
      minimal-lines = if cfg.layout.minimalLines then "yes" else "no";
      width = cfg.layout.width;
      horizontal-pad = cfg.layout.horizontalPad;
      vertical-pad = cfg.layout.verticalPad;
      inner-pad = cfg.layout.innerPad;
      image-size-ratio = cfg.icons.sizeRatio;
      icons-enabled = if cfg.icons.enable then "yes" else "no";
      font = "${cfg.font.family}:size=${toString cfg.font.size}${if cfg.font.weight != "normal" then ":weight=${cfg.font.weight}" else ""}";
      dpi-aware = cfg.font.dpiAware;
      match-mode = cfg.search.matchMode;
      sort-result = if cfg.search.sortResult then "yes" else "no";
      match-counter = if cfg.search.matchCounter then "yes" else "no";
      filter-desktop = if cfg.search.filterDesktop then "yes" else "no";
      show-actions = if cfg.search.showActions then "yes" else "no";
    }
    // (optionalAttrs (cfg.font.lineHeight != null) { line-height = cfg.font.lineHeight; })
    // (optionalAttrs (cfg.font.letterSpacing != 0) { letter-spacing = cfg.font.letterSpacing; })
    // (optionalAttrs (cfg.icons.theme != null) { icon-theme = cfg.icons.theme; });

    border = {
      width = cfg.border.width;
      radius = cfg.border.radius;
    }
    // (optionalAttrs (cfg.border.selectionRadius != null) { selection-radius = cfg.border.selectionRadius; });

    dmenu = {
      mode = cfg.dmenu.mode;
      exit-immediately-if-empty = if cfg.dmenu.exitImmediatelyIfEmpty then "yes" else "no";
    };

    key-bindings = mapAttrs (k: v: concatStringsSep " " v) cfg.keybindings;
  };

  # 根据主题分别生成深色与浅色合并配置
  darkMergedSettings = recursiveUpdate (recursiveUpdate baseSettings { colors = darkColors; }) cfg.settings;
  lightMergedSettings = recursiveUpdate (recursiveUpdate baseSettings { colors = lightColors; }) cfg.settings;

  darkIniFile = iniFormat.generate "fuzzel-dark.ini" darkMergedSettings;
  lightIniFile = iniFormat.generate "fuzzel-light.ini" lightMergedSettings;

  mkFinalIniText = iniFile:
    let
      baseText = builtins.readFile iniFile;
    in
    if cfg.extraConfig != "" then
      baseText + "\n# --- Extra Custom Configuration ---\n" + cfg.extraConfig + "\n"
    else
      baseText;

  darkFinalIniText = mkFinalIniText darkIniFile;
  lightFinalIniText = mkFinalIniText lightIniFile;

  # ── 实用包装器与脚本套件 ─────────────────────────────────────────────
  # 智能启动包装器：优先加载运行时活动配置，避免污染用户主目录
  fuzzelWrapped = pkgs.writeShellScriptBin "fuzzel" ''
    set -euo pipefail
    RUNTIME_INI="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/desktop-theme/fuzzel.ini"
    HAS_CONFIG=0
    for arg in "$@"; do
      case "$arg" in
        --config|--config=*)
          HAS_CONFIG=1
          break
          ;;
      esac
    done

    if [ "$HAS_CONFIG" -eq 0 ] && [ -f "$RUNTIME_INI" ]; then
      exec ${cfg.package}/bin/fuzzel --config "$RUNTIME_INI" "$@"
    else
      exec ${cfg.package}/bin/fuzzel "$@"
    fi
  '';

  # fuzzel-dmenu: 标准 dmenu 兼容包装器
  fuzzelDmenuScript = pkgs.writeShellScriptBin "fuzzel-dmenu" ''
    set -euo pipefail
    exec ${fuzzelWrapped}/bin/fuzzel --dmenu "$@"
  '';

  # fuzzel-power: Wayland 电源与会话管理菜单
  fuzzelPowerScript = pkgs.writeShellScriptBin "fuzzel-power" ''
    set -euo pipefail
    OPTIONS="🔒 锁定屏幕\n🚪 注销登录\n💤 睡眠挂起\n🧊 休眠挂起\n🔄 重启系统\n🛑 关闭计算机"
    CHOICE=$(printf "%b" "$OPTIONS" | ${fuzzelDmenuScript}/bin/fuzzel-dmenu --prompt "⚡ 电源管理: ") || exit 0

    case "$CHOICE" in
      *"锁定屏幕"*)
        loginctl lock-session || true
        ;;
      *"注销登录"*)
        if command -v niri >/dev/null 2>&1; then
          niri msg action quit --skip-confirmation || loginctl terminate-user "$USER"
        else
          loginctl terminate-user "$USER"
        fi
        ;;
      *"睡眠挂起"*)
        systemctl suspend
        ;;
      *"休眠挂起"*)
        systemctl hibernate
        ;;
      *"重启系统"*)
        systemctl reboot
        ;;
      *"关闭计算机"*)
        systemctl poweroff
        ;;
    esac
  '';

  # fuzzel-niri: Niri 专属活动窗口模糊切换工具
  fuzzelNiriScript = pkgs.writeShellScriptBin "fuzzel-niri" ''
    set -euo pipefail
    if ! command -v niri >/dev/null 2>&1; then
      echo "错误: niri 命令未找到" >&2
      exit 1
    fi

    WINDOWS_JSON=$(niri msg --json windows 2>/dev/null) || {
      echo "错误: 无法获取 niri 窗口列表，请确保 niri 正在运行" >&2
      exit 1
    }

    ENTRIES=$(echo "$WINDOWS_JSON" | ${pkgs.jq}/bin/jq -r '
      .[] | "\(.id)\t[\(.app_id // "unknown")] \(.title // "Untitled")\u0000icon\u001f\(.app_id // "")"
    ')

    if [ -z "$ENTRIES" ]; then
      exit 0
    fi

    CHOSEN=$(printf "%b" "$ENTRIES" | ${fuzzelDmenuScript}/bin/fuzzel-dmenu --with-nth 2 --prompt "🪟 切换窗口: ") || exit 0

    if [ -n "$CHOSEN" ]; then
      WIN_ID=$(printf "%s" "$CHOSEN" | cut -f1)
      if [ -n "$WIN_ID" ]; then
        niri msg action focus-window --id "$WIN_ID"
      fi
    fi
  '';

  fuzzelFinalPackage = pkgs.symlinkJoin {
    name = "fuzzel-wrapped-${cfg.package.version or "1.0"}";
    paths = [
      fuzzelWrapped
      cfg.package
    ];
  };
in
{
  options.desktop.launcher.fuzzel = {
    enable = mkEnableOption "Fuzzel 现代化 Wayland 动态模糊轻量启动器与交互菜单";

    package = mkPackageOption pkgs "fuzzel" { };

    terminal = mkOption {
      type = types.str;
      default = "";
      description = "Fuzzel 启动终端应用程序时调用的终端命令行（如 foot -e, rio -e 等，禁止隐式 fallback）。";
    };

    # ── 1. 字体与排版体系 (font) ─────────────────────────────────────────
    font = {
      family = mkOption {
        type = types.str;
        default = "monospace";
        description = "字体家族名称（支持 Fontconfig 匹配格式）。";
      };
      size = mkOption {
        type = types.int;
        default = 11;
        description = "基准字号大小 (pt)。";
      };
      weight = mkOption {
        type = types.enum [ "normal" "bold" "light" "medium" "semibold" "black" ];
        default = "normal";
        description = "字体字重。";
      };
      dpiAware = mkOption {
        type = types.enum [ "auto" "yes" "no" ];
        default = "auto";
        description = "是否启用 DPI 自适应计算。";
      };
      lineHeight = mkOption {
        type = types.nullOr types.int;
        default = 24;
        description = "条目行高 (px)。设为 null 则自动使用字体指标。";
      };
      letterSpacing = mkOption {
        type = types.int;
        default = 0;
        description = "字符间距附加偏移量。";
      };
    };

    # ── 2. 窗口几何与交互布局 (layout) ───────────────────────────────────
    layout = {
      anchor = mkOption {
        type = types.enum [ "center" "top" "left" "right" "bottom" "top-left" "top-right" "bottom-left" "bottom-right" ];
        default = "center";
        description = "启动器在活动监视器上的锚定基准位置。";
      };
      lines = mkOption {
        type = types.int;
        default = 15;
        description = "最大垂直展示的候选条目行数。";
      };
      minimalLines = mkOption {
        type = types.bool;
        default = false;
        description = "是否启用紧凑自适应行数（根据实际匹配结果动态收缩窗口高度）。";
      };
      width = mkOption {
        type = types.int;
        default = 45;
        description = "窗口宽度（以平均字符宽度为基准单位）。";
      };
      horizontalPad = mkOption {
        type = types.int;
        default = 20;
        description = "窗口左右水平内边距 (px)。";
      };
      verticalPad = mkOption {
        type = types.int;
        default = 12;
        description = "窗口上下垂直内边距 (px)。";
      };
      innerPad = mkOption {
        type = types.int;
        default = 8;
        description = "输入框与首个条目、条目之间的内部间隔 (px)。";
      };
      prompt = mkOption {
        type = types.str;
        default = " ❯ ";
        description = "输入框前缀提示符号。";
      };
      placeholder = mkOption {
        type = types.str;
        default = "Search apps, commands or clipboard...";
        description = "输入框无输入时的占位提示文本。";
      };
      layer = mkOption {
        type = types.enum [ "top" "overlay" ];
        default = "overlay";
        description = "Wayland Layer Shell 层级（overlay 层级浮动于全屏应用之上）。";
      };
      keyboardFocus = mkOption {
        type = types.enum [ "exclusive" "on-demand" ];
        default = "exclusive";
        description = "键盘焦点模式（exclusive 独占键盘输入）。";
      };
      exitOnFocusLoss = mkOption {
        type = types.bool;
        default = true;
        description = "当用户点击外部区域导致窗口失去焦点时，是否自动退出。";
      };
    };

    # ── 3. 边框与视觉圆角 (border) ───────────────────────────────────────
    border = {
      width = mkOption {
        type = types.int;
        default = 2;
        description = "外边框物理像素宽度。";
      };
      radius = mkOption {
        type = types.int;
        default = 10;
        description = "窗口主体外轮廓圆角半径 (px)。";
      };
      selectionRadius = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "高亮选中项背景块的圆角半径 (px)。设为 null 时由 Fuzzel 默认决定。";
      };
    };

    # ── 4. 图标展示策略 (icons) ──────────────────────────────────────────
    icons = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否启用应用图标与 dmenu 扩展协议图标渲染。";
      };
      theme = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "强制指定的 XDG 图标主题名。设为 null 则自动继承系统环境。";
      };
      sizeRatio = mkOption {
        type = types.str;
        default = "0.5";
        description = "图标相对于行高的缩放尺寸比例（取值 0.0 ~ 1.0）。";
      };
    };

    # ── 5. 搜索过滤与结果排序 (search) ───────────────────────────────────
    search = {
      matchMode = mkOption {
        type = types.enum [ "fzf" "fuzzy" "exact" ];
        default = "fzf";
        description = "字符串过滤匹配算法（fzf 模式为多子串交互匹配，fuzzy 为莱文斯坦模糊匹配）。";
      };
      sortResult = mkOption {
        type = types.bool;
        default = true;
        description = "是否按照匹配得分智能排序结果列表。";
      };
      matchCounter = mkOption {
        type = types.bool;
        default = true;
        description = "是否在界面右上角渲染匹配结果总数计数器。";
      };
      filterDesktop = mkOption {
        type = types.bool;
        default = false;
        description = "是否依据 desktop 文件中的 OnlyShowIn / NotShowIn 标记过滤条目。";
      };
      showActions = mkOption {
        type = types.bool;
        default = false;
        description = "是否在应用主条目下方展开展示 .desktop 定义的附加 actions 项。";
      };
    };

    # ── 6. Dmenu 模式专属配置 (dmenu) ───────────────────────────────────
    dmenu = {
      mode = mkOption {
        type = types.enum [ "text" "index" ];
        default = "text";
        description = "dmenu 模式下回车输出格式（text 输出条目字符串，index 输出行号数字）。";
      };
      exitImmediatelyIfEmpty = mkOption {
        type = types.bool;
        default = false;
        description = "若当前过滤结果为空，按下回车是否立刻退出。";
      };
    };

    # ── 7. 键位映射与扩展操作 (keybindings) ──────────────────────────────
    keybindings = mkOption {
      type = types.attrsOf (types.listOf types.str);
      default = {
        cancel = [ "Escape" "Control+g" "Control+c" ];
        execute = [ "Return" "KP_Enter" "Control+y" ];
        prev = [ "Up" "Control+p" "Control+k" ];
        next = [ "Down" "Control+n" "Control+j" ];
        delete-prev-word = [ "Mod1+BackSpace" "Control+BackSpace" "Control+w" ];
        custom-1 = [ "Mod1+1" ];
        custom-10 = [ "Mod1+0" ];
      };
      description = "Fuzzel [key-bindings] 映射表。支持针对 custom-1 ~ custom-19 绑定特定 exit code。";
    };

    # ── 8. 主题与配色联动 (theme) ────────────────────────────────────────
    theme = {
      syncDesktopTheme = mkOption {
        type = types.bool;
        default = true;
        description = "是否深度集成全局 desktop.theme 调色板与暗浅色切换事件。";
      };
      darkColors = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "深色模式颜色映射显式覆盖（覆盖自动由 palette 派生的色彩）。";
      };
      lightColors = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "浅色模式颜色映射显式覆盖（覆盖自动由 palette 派生的色彩）。";
      };
    };

    # ── 9. 高级底层覆盖 (settings & extraConfig) ─────────────────────────
    settings = mkOption {
      inherit (iniFormat) type;
      default = { };
      description = "原始 fuzzel.ini 结构化配置，将深度合并覆盖高阶抽象选项。";
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = "追加写入 fuzzel.ini 文件尾部的原生配置片段。";
    };

    # ── 10. 专属桌面实用工具集 (wrappers) ────────────────────────────────
    wrappers = {
      powerMenu = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "是否构建并导出 Wayland 专用电源与会话管理菜单 (fuzzel-power)。";
        };
      };
      windowSwitch = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "是否构建并导出 Niri 专属的活动窗口模糊切换工具 (fuzzel-niri)。";
        };
      };
      dmenuWrapper = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "是否构建并导出通用 dmenu 兼容包装命令 (fuzzel-dmenu)。";
        };
      };
    };

    homeManager = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否将 Fuzzel 配置与工具同步至 Home Manager。";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      assertions = [
        {
          assertion = cfg.terminal != "";
          message = "desktop.launcher.fuzzel: 启用了 Fuzzel 启动器时，必须显式配置终端命令 (desktop.launcher.fuzzel.terminal)，禁止提供默认 fallback。";
        }
      ];

      # 1. 系统软件包安装：包装后的 fuzzel 主程序及配套工具链
      environment.systemPackages = [
        fuzzelFinalPackage
      ]
      ++ (optional cfg.wrappers.dmenuWrapper.enable fuzzelDmenuScript)
      ++ (optional cfg.wrappers.powerMenu.enable fuzzelPowerScript)
      ++ (optional cfg.wrappers.windowSwitch.enable fuzzelNiriScript);

      # 2. 系统级静态初始配置文件部署 (/etc/xdg/fuzzel/fuzzel.ini 与 /etc/fuzzel/fuzzel.ini)
      environment.etc = {
        "xdg/fuzzel/fuzzel.ini".text = darkFinalIniText;
        "fuzzel/fuzzel.ini".text = darkFinalIniText;
      };

      # 3. 主题服务主动联动：通过 desktop.theme.hookFragmentsSeedSafe 注册切换钩子
      #    采用运行时活动配置注入 ($RUNTIME_DIR/desktop-theme/fuzzel.ini)，避免破坏 Home Manager 只读符号链接
      desktop.theme.hookFragmentsSeedSafe = mkIf ((config.desktop.theme.enable or false) && cfg.theme.syncDesktopTheme) [
        ''
          # --- Fuzzel 主题动态联动（由 modules/launcher/fuzzel 注入）---
          if [ "$MODE" = "dark" ]; then
            FUZZEL_THEME_CONTENT=${escapeShellArg darkFinalIniText}
          else
            FUZZEL_THEME_CONTENT=${escapeShellArg lightFinalIniText}
          fi
          FUZZEL_RUNTIME_DIR="$RUNTIME_DIR/desktop-theme"
          mkdir -p "$FUZZEL_RUNTIME_DIR" || true
          printf '%s' "$FUZZEL_THEME_CONTENT" > "$FUZZEL_RUNTIME_DIR/fuzzel.ini" || echo "[theme-switch] warn: failed to write fuzzel runtime ini" >&2
        ''
      ];
    }

    # 4. Home Manager 自动联动
    (optionalAttrs (options ? home-manager) {
      home-manager = mkIf cfg.homeManager.enable {
        sharedModules = [
          ({ ... }: {
            home.packages = [
              fuzzelFinalPackage
            ]
            ++ (optional cfg.wrappers.dmenuWrapper.enable fuzzelDmenuScript)
            ++ (optional cfg.wrappers.powerMenu.enable fuzzelPowerScript)
            ++ (optional cfg.wrappers.windowSwitch.enable fuzzelNiriScript);
            xdg.configFile."fuzzel/fuzzel.ini".text = darkFinalIniText;
          })
        ];
      };
    })
  ]);
}
