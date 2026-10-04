{
  config,
  pkgs,
  lib,
  options,
  ...
}:

with lib;

let
  cfg = config.desktop.screenshot.satty;

  filterNull = filterAttrs (_: v: v != null);

  # 1. 结构化构建各配置段落（与 Satty 源码严格对齐，支持深入定制）
  generalConfig = filterNull (
    (optionalAttrs (cfg.general.fullscreen != null) { fullscreen = cfg.general.fullscreen; })
    // (optionalAttrs (cfg.general.resize.mode != null) {
      resize = filterNull {
        mode = cfg.general.resize.mode;
        width = cfg.general.resize.width;
        height = cfg.general.resize.height;
      };
    })
    // (optionalAttrs (cfg.general.floatingHack != null) { floating-hack = cfg.general.floatingHack; })
    // (optionalAttrs (cfg.general.earlyExit != null) { early-exit = cfg.general.earlyExit; })
    // (optionalAttrs (cfg.general.cornerRoundness != null) { corner-roundness = cfg.general.cornerRoundness; })
    // (optionalAttrs (cfg.general.initialTool != null) { initial-tool = cfg.general.initialTool; })
    // (optionalAttrs (cfg.general.copyCommand != null) { copy-command = cfg.general.copyCommand; })
    // (optionalAttrs (cfg.general.annotationSizeFactor != null) { annotation-size-factor = cfg.general.annotationSizeFactor; })
    // (optionalAttrs (cfg.general.outputFilename != null) { output-filename = cfg.general.outputFilename; })
    // (optionalAttrs (cfg.general.saveAfterCopy != null) { save-after-copy = cfg.general.saveAfterCopy; })
    // (optionalAttrs (cfg.general.autoCopy != null) { auto-copy = cfg.general.autoCopy; })
    // (optionalAttrs (cfg.general.defaultHideToolbars != null) { default-hide-toolbars = cfg.general.defaultHideToolbars; })
    // (optionalAttrs (cfg.general.focusTogglesToolbars != null) { focus-toggles-toolbars = cfg.general.focusTogglesToolbars; })
    // (optionalAttrs (cfg.general.defaultFillShapes != null) { default-fill-shapes = cfg.general.defaultFillShapes; })
    // (optionalAttrs (cfg.general.defaultRoundCaps != null) { default-round-caps = cfg.general.defaultRoundCaps; })
    // (optionalAttrs (cfg.general.primaryHighlighter != null) { primary-highlighter = cfg.general.primaryHighlighter; })
    // (optionalAttrs (cfg.general.disableNotifications != null) { disable-notifications = cfg.general.disableNotifications; })
    // (optionalAttrs (cfg.general.actionsOnRightClick != [ ]) { actions-on-right-click = cfg.general.actionsOnRightClick; })
    // (optionalAttrs (cfg.general.actionsOnEnter != [ ]) { actions-on-enter = cfg.general.actionsOnEnter; })
    // (optionalAttrs (cfg.general.actionsOnEscape != [ ]) { actions-on-escape = cfg.general.actionsOnEscape; })
    // (optionalAttrs (cfg.general.noWindowDecoration != null) { no-window-decoration = cfg.general.noWindowDecoration; })
    // (optionalAttrs (cfg.general.brushSmoothHistorySize != null) { brush-smooth-history-size = cfg.general.brushSmoothHistorySize; })
    // (optionalAttrs (cfg.general.panStepSize != null) { pan-step-size = cfg.general.panStepSize; })
    // (optionalAttrs (cfg.general.zoomFactor != null) { zoom-factor = cfg.general.zoomFactor; })
    // (optionalAttrs (cfg.general.textMoveLength != null) { text-move-length = cfg.general.textMoveLength; })
    // (optionalAttrs (cfg.general.inputScale != null) { input-scale = cfg.general.inputScale; })
    // (optionalAttrs (cfg.general.title != null) { title = cfg.general.title; })
    // (optionalAttrs (cfg.general.appId != null) { app-id = cfg.general.appId; })
    // (optionalAttrs (cfg.general.notificationThumbnail != null) { notification-thumbnail = cfg.general.notificationThumbnail; })
  );

  keybindsConfig = filterNull {
    inherit (cfg.keybinds)
      pointer
      crop
      brush
      line
      arrow
      rectangle
      ellipse
      text
      marker
      blur
      highlight;
  };

  fontConfig = filterNull (
    (optionalAttrs (cfg.font.family != null) { family = cfg.font.family; })
    // (optionalAttrs (cfg.font.style != null) { style = cfg.font.style; })
    // (optionalAttrs (cfg.font.fallback != [ ]) { fallback = cfg.font.fallback; })
  );

  colorPaletteConfig = filterNull (
    (optionalAttrs (cfg.colorPalette.palette != [ ]) { palette = cfg.colorPalette.palette; })
    // (optionalAttrs (cfg.colorPalette.custom != [ ]) { custom = cfg.colorPalette.custom; })
  );

  defaultConfigAttrs = filterNull {
    general = optionalAttrs (generalConfig != { }) generalConfig;
    keybinds = optionalAttrs (keybindsConfig != { }) keybindsConfig;
    font = optionalAttrs (fontConfig != { }) fontConfig;
    color-palette = optionalAttrs (colorPaletteConfig != { }) colorPaletteConfig;
  };

  mergedConfigAttrs = recursiveUpdate defaultConfigAttrs cfg.settings;

  tomlFormat = pkgs.formats.toml { };
  baseConfigFile = tomlFormat.generate "satty-config.toml" mergedConfigAttrs;

  configFile = pkgs.runCommand "config.toml" {
    nativeBuildInputs = optional cfg.checkConfig cfg.package;
  } ''
    cat ${baseConfigFile} > $out
    ${optionalString (cfg.extraConfig != "") ''
      printf '\n%s\n' ${escapeShellArg cfg.extraConfig} >> $out
    ''}
    ${optionalString cfg.checkConfig ''
      # 验证生成的 Satty TOML 配置文件语法及字段合法性（Satty 对未知字段具有严格的 deny_unknown_fields 检查）
      satty --config "$out" -f - < /dev/null >/dev/null 2>&1 || code=$?
      if [ "''${code:-0}" -eq 3 ]; then
        echo "错误: 生成的 Satty 配置文件存在语法或未知字段错误 (exit code 3)" >&2
        satty --config "$out" -f - < /dev/null >&2 || true
        exit 1
      fi
    ''}
  '';

  # 2. 交互式截屏封装脚本 (集成 grim, slurp, satty 与 niri IPC)
  sattyScreenshotScript = pkgs.writeShellScriptBin cfg.wrapper.name ''
    set -euo pipefail

    usage() {
      cat <<'EOF'
用法: ${cfg.wrapper.name} [选项] [模式]

模式:
  area, -a, --area          交互式区域框选截屏 (默认)
  screen, -s, --screen      全屏截屏 (捕捉整个屏幕输出)
  window, -w, --window      窗口截屏 (若在 Niri 环境下优先通过 IPC 截取活动窗口，否则回退框选)

选项:
  -h, --help                显示此帮助信息
  -- <satty-args...>        将后续参数透传给 Satty 原生命令
EOF
    }

    MODE="area"

    while [ $# -gt 0 ]; do
      case "$1" in
        area|-a|--area)
          MODE="area"
          shift
          ;;
        screen|-s|--screen|--fullscreen)
          MODE="screen"
          shift
          ;;
        window|-w|--window)
          MODE="window"
          shift
          ;;
        -h|--help)
          usage
          exit 0
          ;;
        --)
          shift
          break
          ;;
        *)
          break
          ;;
      esac
    done

    case "$MODE" in
      area)
        GEOM=$(${lib.getExe pkgs.slurp} 2>/dev/null) || exit 0
        if [ -z "$GEOM" ]; then
          exit 0
        fi
        ${lib.getExe pkgs.grim} -g "$GEOM" - | ${lib.getExe cfg.package} --filename - "$@"
        ;;
      screen)
        ${lib.getExe pkgs.grim} - | ${lib.getExe cfg.package} --filename - "$@"
        ;;
      window)
        CAPTURED=0
        TMP_IMG=$(mktemp --suffix=.png)
        if [ -n "''${NIRI_SOCKET:-}" ] || command -v niri >/dev/null 2>&1; then
          if niri msg action screenshot-window --path "$TMP_IMG" 2>/dev/null; then
            if [ -s "$TMP_IMG" ]; then
              CAPTURED=1
              ${lib.getExe cfg.package} --filename "$TMP_IMG" "$@"
              rm -f "$TMP_IMG"
            fi
          fi
        fi
        if [ "$CAPTURED" -eq 0 ]; then
          rm -f "$TMP_IMG"
          GEOM=$(${lib.getExe pkgs.slurp} 2>/dev/null) || exit 0
          if [ -n "$GEOM" ]; then
            ${lib.getExe pkgs.grim} -g "$GEOM" - | ${lib.getExe cfg.package} --filename - "$@"
          fi
        fi
        ;;
    esac
  '';
in
{
  imports = [
    (lib.mkAliasOptionModule [ "desktop" "screenShot" "satty" ] [ "desktop" "screenshot" "satty" ])
  ];

  options.desktop.screenshot.satty = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "是否启用 Satty 现代化 Wayland 截屏标注工具及配套脚本。";
    };

    package = mkPackageOption pkgs "satty" { };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [
        pkgs.grim
        pkgs.slurp
        pkgs.wl-clipboard
      ];
      description = "截屏配套组件列表，默认包含 Wayland 截屏底座 grim、区域选框工具 slurp 与剪贴板工具 wl-clipboard。";
    };

    configFile = mkOption {
      type = types.package;
      readOnly = true;
      default = configFile;
      description = "根据配置选项生成的 Satty 配置文件 (config.toml) 派生包。";
    };

    checkConfig = mkOption {
      type = types.bool;
      default = true;
      description = "是否在构建期使用 Satty 二进制静态校验生成的 config.toml 结构合法性与未知字段。";
    };

    wrapper = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否构建并导出通用的截屏封装脚本 satty-screenshot。";
      };

      name = mkOption {
        type = types.str;
        default = "satty-screenshot";
        description = "生成的截屏包装可执行脚本名称。";
      };
    };

    # ── 1. General 配置段落 (对应 [general]) ─────────────────────────────────
    general = {
      fullscreen = mkOption {
        type = types.nullOr (types.enum [ "current-screen" "all" ]);
        default = null;
        description = "启动时是否全屏显示 Satty 标注窗口（支持 current-screen 或 all）。设为 null 则以窗口模式启动。";
      };

      resize = {
        mode = mkOption {
          type = types.nullOr (types.enum [ "smart" "size" ]);
          default = "smart";
          description = "初始窗口尺寸调整模式。smart 自动根据图片和屏幕调整；size 为指定具体宽高。";
        };

        width = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "当 mode 为 size 时的窗口宽度。";
        };

        height = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "当 mode 为 size 时的窗口高度。";
        };
      };

      floatingHack = mkOption {
        type = types.nullOr types.bool;
        default = true;
        description = "尝试请求平铺合成器将窗口设为浮动（floating-hack）。";
      };

      earlyExit = mkOption {
        type = types.nullOr (types.either types.bool (types.listOf (types.enum [ "all" "copy" "save" "save-as" ])));
        default = [ "all" ];
        description = "在执行保存或复制操作后立即退出 Satty 的触发条件（如 [ \"all\" ] 或 [ \"copy\" \"save\" ]）。";
      };

      cornerRoundness = mkOption {
        type = types.nullOr types.numbers.nonnegative;
        default = 12;
        description = "矩形工具圆角半径（设为 0 禁用圆角）。";
      };

      initialTool = mkOption {
        type = types.nullOr (types.enum [
          "pointer"
          "crop"
          "line"
          "arrow"
          "rectangle"
          "ellipse"
          "text"
          "marker"
          "blur"
          "highlight"
          "brush"
        ]);
        default = "brush";
        description = "Satty 启动时默认选中的标注工具。";
      };

      copyCommand = mkOption {
        type = types.nullOr types.str;
        default = "wl-copy";
        description = "复制标注图片到剪贴板时调用的系统命令。";
      };

      annotationSizeFactor = mkOption {
        type = types.nullOr types.numbers.positive;
        default = 2.0;
        description = "标注线条与图标缩放系数倍率。";
      };

      outputFilename = mkOption {
        type = types.nullOr types.str;
        default = "/tmp/satty-%Y-%m-%d_%H:%M:%S.png";
        description = "保存动作的默认目标文件名模板（支持 strftime 格式化占位符及 ~ 家目录）。";
      };

      saveAfterCopy = mkOption {
        type = types.nullOr types.bool;
        default = false;
        description = "复制截图到剪贴板后，是否自动同步保存到文件。";
      };

      autoCopy = mkOption {
        type = types.nullOr types.bool;
        default = false;
        description = "每次标注内容发生变更时，是否自动将最新画面拷贝至剪贴板。";
      };

      defaultHideToolbars = mkOption {
        type = types.nullOr types.bool;
        default = false;
        description = "启动时是否默认隐藏工具栏。";
      };

      focusTogglesToolbars = mkOption {
        type = types.nullOr types.bool;
        default = false;
        description = "窗口获得/失去焦点时是否自动切换工具栏可见性。";
      };

      defaultFillShapes = mkOption {
        type = types.nullOr types.bool;
        default = false;
        description = "绘制矩形/椭圆等几何图形时是否默认填充形状内部。";
      };

      defaultRoundCaps = mkOption {
        type = types.nullOr types.bool;
        default = true;
        description = "线条与箭头端点是否采用圆角末端 (round caps)。";
      };

      primaryHighlighter = mkOption {
        type = types.nullOr (types.enum [ "block" "freehand" ]);
        default = "block";
        description = "默认高亮工具形态（block 块状遮罩或 freehand 手绘涂抹）。";
      };

      disableNotifications = mkOption {
        type = types.nullOr types.bool;
        default = false;
        description = "是否禁用保存与复制完成后的桌面通知。";
      };

      actionsOnRightClick = mkOption {
        type = types.listOf (types.enum [
          "save-to-clipboard"
          "save-to-file"
          "save-to-file-as"
          "copy-filepath-to-clipboard"
          "exit"
        ]);
        default = [ ];
        description = "鼠标右键点击标注画布时触发的动作列表（按顺序执行）。";
      };

      actionsOnEnter = mkOption {
        type = types.listOf (types.enum [
          "save-to-clipboard"
          "save-to-file"
          "save-to-file-as"
          "copy-filepath-to-clipboard"
          "exit"
        ]);
        default = [ "save-to-clipboard" ];
        description = "按下 Enter 回车键时触发的动作列表。";
      };

      actionsOnEscape = mkOption {
        type = types.listOf (types.enum [
          "save-to-clipboard"
          "save-to-file"
          "save-to-file-as"
          "copy-filepath-to-clipboard"
          "exit"
        ]);
        default = [ "exit" ];
        description = "按下 Escape 退出键时触发的动作列表。";
      };

      noWindowDecoration = mkOption {
        type = types.nullOr types.bool;
        default = true;
        description = "是否请求合成器隐藏标题栏及客户端装饰 (CSD)。";
      };

      brushSmoothHistorySize = mkOption {
        type = types.nullOr types.ints.unsigned;
        default = 10;
        description = "画笔平滑轨迹采样历史点数（0 为禁用平滑曲线）。";
      };

      panStepSize = mkOption {
        type = types.nullOr types.numbers.positive;
        default = 50.0;
        description = "使用方向键平移画面时的单次位移步长。";
      };

      zoomFactor = mkOption {
        type = types.nullOr types.numbers.positive;
        default = 1.1;
        description = "画面缩放倍率步进值。";
      };

      textMoveLength = mkOption {
        type = types.nullOr types.numbers.positive;
        default = 50.0;
        description = "方向键调整文本标注位置时的步长。";
      };

      inputScale = mkOption {
        type = types.nullOr types.numbers.positive;
        default = null;
        description = "输入图片 DPI 缩放比率补偿（设为 null 遵循默认屏幕配置）。";
      };

      title = mkOption {
        type = types.nullOr types.str;
        default = "Satty";
        description = "Satty 窗口标题名。";
      };

      appId = mkOption {
        type = types.nullOr types.str;
        default = "org.satty.satty";
        description = "Satty 窗口的 Wayland app_id（需符合 D-Bus 命名规范）。";
      };

      notificationThumbnail = mkOption {
        type = types.nullOr (types.enum [ "screenshot" "app-icon" ]);
        default = "screenshot";
        description = "桌面通知中的预览图标类型（screenshot 为截屏缩略图，app-icon 为程序图标）。";
      };
    };

    # ── 2. Keybinds 配置段落 (对应 [keybinds]) ───────────────────────────────
    keybinds = {
      pointer = mkOption {
        type = types.nullOr types.str;
        default = "p";
        description = "选择指针工具的单字符快捷键。";
      };
      crop = mkOption {
        type = types.nullOr types.str;
        default = "c";
        description = "选择裁剪工具的单字符快捷键。";
      };
      brush = mkOption {
        type = types.nullOr types.str;
        default = "b";
        description = "选择画笔工具的单字符快捷键。";
      };
      line = mkOption {
        type = types.nullOr types.str;
        default = "i";
        description = "选择直线工具的单字符快捷键。";
      };
      arrow = mkOption {
        type = types.nullOr types.str;
        default = "z";
        description = "选择箭头工具的单字符快捷键。";
      };
      rectangle = mkOption {
        type = types.nullOr types.str;
        default = "r";
        description = "选择矩形工具的单字符快捷键。";
      };
      ellipse = mkOption {
        type = types.nullOr types.str;
        default = "e";
        description = "选择椭圆工具的单字符快捷键。";
      };
      text = mkOption {
        type = types.nullOr types.str;
        default = "t";
        description = "选择文字工具的单字符快捷键。";
      };
      marker = mkOption {
        type = types.nullOr types.str;
        default = "m";
        description = "选择记号笔工具的单字符快捷键。";
      };
      blur = mkOption {
        type = types.nullOr types.str;
        default = "u";
        description = "选择模糊/马赛克工具的单字符快捷键。";
      };
      highlight = mkOption {
        type = types.nullOr types.str;
        default = "g";
        description = "选择高亮荧光笔工具的单字符快捷键。";
      };
    };

    # ── 3. Font 配置段落 (对应 [font]) ───────────────────────────────────────
    font = {
      family = mkOption {
        type = types.nullOr types.str;
        default = "Roboto";
        description = "文字标注默认字体家族名。";
      };

      style = mkOption {
        type = types.nullOr types.str;
        default = "Regular";
        description = "文字标注字体样式 (如 Regular, Bold, Italic)。";
      };

      fallback = mkOption {
        type = types.listOf types.str;
        default = [ "Noto Sans CJK SC" ];
        description = "文字标注候选后备字体族列表（包含中日韩汉字支持）。";
      };
    };

    # ── 4. Color Palette 配置段落 (对应 [color-palette]) ─────────────────────
    colorPalette = {
      palette = mkOption {
        type = types.listOf types.str;
        default = [
          "#f0932bff"
          "#eb4d4bff"
          "#6ab04cff"
          "#22a6b3ff"
          "#130f40FF"
        ];
        description = "工具栏快捷调色板颜色列表（格式为 #RRGGBBAA，末尾两位为透明度通道）。";
      };

      custom = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "颜色选择器预设自定义色板列表。留空则使用 GTK 系统默认预设。";
      };
    };

    # ── 5. 高级底层配置覆盖 (settings & extraConfig) ─────────────────────────
    settings = mkOption {
      inherit (tomlFormat) type;
      default = { };
      description = "原始 Satty config.toml 结构化配置，将深度合并覆盖高阶抽象选项。";
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = "追加写入 Satty config.toml 文件尾部的原生配置片段。";
    };

    # ── 6. Niri 窗口管理器集成 ───────────────────────────────────────────────
    niri = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否自动为 Niri 窗口管理器配置 Satty 联动（窗口规则与截屏按键绑定）。";
      };

      openFloating = mkOption {
        type = types.bool;
        default = true;
        description = "是否在 Niri 窗口管理器中默认以浮动窗口打开 Satty 标注界面。";
      };

      bindScreenshots = mkOption {
        type = types.bool;
        default = true;
        description = "是否自动将 Satty 截图脚本注册为 Niri 自定义截屏工具。";
      };

      keybind = mkOption {
        type = types.str;
        default = "Print";
        description = "在 Niri 中唤起 Satty 区域/交互式截屏的主快捷键绑定。";
      };

      altKeybind = mkOption {
        type = types.str;
        default = "Mod+P";
        description = "在 Niri 中唤起 Satty 区域/交互式截屏的辅助快捷键绑定。";
      };

      screenKeybind = mkOption {
        type = types.str;
        default = "Ctrl+Print";
        description = "在 Niri 中唤起 Satty 全屏截屏的主快捷键绑定。";
      };

      altScreenKeybind = mkOption {
        type = types.str;
        default = "Mod+Ctrl+P";
        description = "在 Niri 中唤起 Satty 全屏截屏的辅助快捷键绑定。";
      };

      windowKeybind = mkOption {
        type = types.str;
        default = "Alt+Print";
        description = "在 Niri 中唤起 Satty 窗口截屏的主快捷键绑定。";
      };

      altWindowKeybind = mkOption {
        type = types.str;
        default = "Mod+Alt+P";
        description = "在 Niri 中唤起 Satty 窗口截屏的辅助快捷键绑定。";
      };
    };

    homeManager = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "若系统中启用了 Home Manager，是否自动将 Satty 软件包与用户配置文件注入到所有 Home Manager 用户中。";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      # 1. NixOS 系统级软件包安装
      environment.systemPackages = [
        cfg.package
      ]
      ++ (optional cfg.wrapper.enable sattyScreenshotScript)
      ++ cfg.extraPackages;

      # 2. 系统级配置文件部署 (/etc/xdg/satty/config.toml)
      environment.etc."xdg/satty/config.toml".source = configFile;

      # 3. 联动向 Niri 注册窗口规则与自定义截屏工具
      desktop.windowManager.niri = mkIf (config ? desktop && config.desktop ? windowManager && config.desktop.windowManager ? niri && config.desktop.windowManager.niri.enable && cfg.niri.enable) (mkMerge [
        (mkIf cfg.niri.openFloating {
          windowRules.extraRules = [
            {
              match._props = {
                app-id = "^(org\\.satty\\.satty|satty)$";
              };
              open-floating = true;
            }
          ];
        })
        (mkIf cfg.niri.bindScreenshots {
          screenshot = {
            enable = mkDefault true;
            command = mkDefault "${sattyScreenshotScript}/bin/${cfg.wrapper.name} --area";
            screenCommand = mkDefault "${sattyScreenshotScript}/bin/${cfg.wrapper.name} --screen";
            windowCommand = mkDefault "${sattyScreenshotScript}/bin/${cfg.wrapper.name} --window";
            keybind = mkDefault cfg.niri.keybind;
            altKeybind = mkDefault cfg.niri.altKeybind;
            screenKeybind = mkDefault cfg.niri.screenKeybind;
            altScreenKeybind = mkDefault cfg.niri.altScreenKeybind;
            windowKeybind = mkDefault cfg.niri.windowKeybind;
            altWindowKeybind = mkDefault cfg.niri.altWindowKeybind;
          };
        })
      ]);
    }

    # 4. Home Manager 深度联动
    (optionalAttrs (options ? home-manager) {
      home-manager = mkIf cfg.homeManager.enable {
        sharedModules = [
          ({ ... }: {
            home.packages = [
              cfg.package
            ]
            ++ (optional cfg.wrapper.enable sattyScreenshotScript)
            ++ cfg.extraPackages;

            xdg.configFile."satty/config.toml".source = configFile;
          })
        ];
      };
    })
  ]);
}
