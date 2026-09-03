{
  config,
  pkgs,
  lib,
  options,
  ...
}:

with lib;

let
  cfg = config.desktop.windowManager.niri;

  toKdl = import ./lib/toKdl.nix { inherit lib; };
  defaultWindowRules = import ./rules;
  defaultSettings = import ./core/defaultSettings.nix { inherit cfg lib; };


  # 递归合并基础配置与用户自定义 settings
  mergedSettings = recursiveUpdate defaultSettings cfg.settings;

  # 规范化窗口规则，兼容 Niri 原生结构及跨模块通用属性
  normalizeRule = rule:
    if !isAttrs rule then
      rule
    else if rule ? _raw then
      rule
    else
      let
        hasMatch = rule ? match;
        rawMatch = rule.match or { };
        isAlreadyNiriMatch = isAttrs rawMatch && rawMatch ? _props;
        normalizedMatch =
          if !hasMatch then
            null
          else if isAlreadyNiriMatch then
            rawMatch
          else if isAttrs rawMatch then
            let
              appId = rawMatch.app-id or rawMatch.class or null;
              title = rawMatch.title or null;
              matchProps = (optionalAttrs (appId != null) { app-id = appId; })
                // (optionalAttrs (title != null) { inherit title; })
                // (removeAttrs rawMatch [ "class" "app-id" "title" ]);
            in
            { _props = matchProps; }
          else
            rawMatch;

        sizeParts =
          if rule ? size && isString rule.size then
            filter (s: s != "") (splitString " " rule.size)
          else
            [ ];
        hasSize = length sizeParts == 2;
        parsedWidth = if hasSize then toInt (elemAt sizeParts 0) else null;
        parsedHeight = if hasSize then toInt (elemAt sizeParts 1) else null;

        openFloating = rule.open-floating or rule.float or null;
        openFocused = rule.open-focused or rule.stay_focused or null;
        openFullscreen = rule.open-fullscreen or rule.fullscreen or null;

        cleanedRule = removeAttrs rule [
          "class"
          "float"
          "stay_focused"
          "fullscreen"
          "pin"
          "center"
          "keep_aspect_ratio"
          "no_blur"
          "no_shadow"
          "size"
        ];
      in
      cleanedRule
      // (optionalAttrs (normalizedMatch != null) { match = normalizedMatch; })
      // (optionalAttrs (openFloating != null) { open-floating = openFloating; })
      // (optionalAttrs (openFocused != null) { open-focused = openFocused; })
      // (optionalAttrs (openFullscreen != null) { open-fullscreen = openFullscreen; })
      // (optionalAttrs (hasSize && parsedWidth != null && !(rule ? default-column-width)) {
        default-column-width = { fixed = parsedWidth; };
      })
      // (optionalAttrs (hasSize && parsedHeight != null && !(rule ? default-window-height)) {
        default-window-height = { fixed = parsedHeight; };
      });

  # 合并所有窗口规则并规范化
  rawWindowRules = unique (
    (optionals cfg.windowRules.enable defaultWindowRules)
    ++ (mergedSettings.window-rule or [ ])
    ++ cfg.extraRules
    ++ cfg.windowRules.extraRules
  );
  allWindowRules = map normalizeRule rawWindowRules;

  # 合并图层规则
  allLayerRules = unique (
    (mergedSettings.layer-rule or [ ])
    ++ cfg.layerRules
  );

  # 最终合成设置
  finalSettings = (removeAttrs mergedSettings [ "window-rule" "layer-rule" "binds" ]) // {
    binds = recursiveUpdate (mergedSettings.binds or { }) cfg.extraBinds;
  }
  // (optionalAttrs (allWindowRules != [ ]) { window-rule = allWindowRules; })
  // (optionalAttrs (allLayerRules != [ ]) { layer-rule = allLayerRules; });

  generatedBody = toKdl finalSettings;

  generatedText = concatStringsSep "\n" (
    filter (s: s != "") [
      cfg.extraConfigEarly
      generatedBody
      cfg.extraConfig
    ]
  );

  # 构建静态主题初始值文件，用于 niri validate 检查期（此时没有运行时 theme.kdl）
  # 内容对应 dark 模式默认颜色（若未启用 themeIntegration，则不会 include）
  staticThemeKdl = pkgs.writeText "niri-theme-static.kdl" ''
    layout {
        focus-ring {
            width 4
            active-color "#7fc8ff"
            inactive-color "#505050"
        }
        border {
            active-color "#ffc87f"
            inactive-color "#505050"
        }
    }
  '';

  configFile = pkgs.writeTextFile {
    name = "niri-config.kdl";
    text = generatedText + optionalString cfg.themeIntegration.enable ''

include "${staticThemeKdl}"
'';
    checkPhase = optionalString cfg.checkConfig ''
      ${lib.getExe cfg.package} validate --config "$target"
    '';
  };

  gamemodeConfigFile = pkgs.writeTextFile {
    name = "niri-config-gamemode.kdl";
    text = ''
      include "${configFile}"

      animations {
          off
      }

      layout {
          shadow {
              off
          }
      }
    '';
    checkPhase = optionalString cfg.checkConfig ''
      ${lib.getExe cfg.package} validate --config "$target"
    '';
  };
in
{
  options.desktop.windowManager.niri = {
    enable = mkEnableOption "Niri 现代化滚动平铺 Wayland 合成器核心";

    package = mkPackageOption pkgs "niri" { };

    terminal = mkOption {
      type = types.str;
      default = "rio";
      description = "Niri 默认快捷键 (Mod + Return / Mod + T) 启动的终端命令或可执行程序名称。";
    };

    fileManager = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "是否在 Niri 中启用默认文件管理器快捷键联动。";
      };

      command = mkOption {
        type = types.str;
        default = "";
        description = "Niri 启动文件管理器的命令行（默认按键 Mod + E 唤起）。";
      };

      keybind = mkOption {
        type = types.str;
        default = "Mod+E";
        description = "在 Niri 中唤起文件管理器的快捷键绑定（设为空字符串则不注册）。";
      };
    };

    portal = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否启用 Niri 桌面门户 (XDG Desktop Portal) 整合与配置。";
      };

      extraPortals = mkOption {
        type = types.listOf types.package;
        default = [ pkgs.xdg-desktop-portal-gnome ];
        description = "附加注册至 Niri 会话的 XDG Desktop Portal 后端列表。";
      };

      filechooser = mkOption {
        type = types.enum [ "termfilechooser" "gtk" "gnome" "none" ];
        default = "gnome";
        description = "Niri 会话中默认处理文件选择接口 (org.freedesktop.impl.portal.FileChooser) 的门户后端。";
      };

      config = mkOption {
        type = types.attrsOf types.anything;
        default = { };
        description = "附加至 xdg.portal.config.niri 的自定义门户映射配置。";
      };
    };

    xwayland = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否启用 XWayland 兼容支持（通过 xwayland-satellite 按需激活）。";
      };

      package = mkPackageOption pkgs "xwayland-satellite" {
        nullable = true;
      };
    };

    themeIntegration = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否启用 Darkman 深浅色主题与 Niri 的动态联动（注册 include 动态主题 KDL）。默认 true 以保证主题联动开箱即用。";
      };

      themeToggleKeybind = mkOption {
        type = types.str;
        default = "Mod+Shift+T";
        description = "在 Niri 中切换深色/浅色主题的快捷键（设为空字符串则不注册）。";
      };
    };

    layout = {
      gaps = mkOption {
        type = types.int;
        default = 16;
        description = "窗口间距与屏幕边距（逻辑像素）。";
      };

      centerFocusedColumn = mkOption {
        type = types.enum [ "never" "always" "on-overflow" ];
        default = "never";
        description = "切换焦点时是否居中活动列：never (默认), always (始终居中), on-overflow (溢出时居中)。";
      };

      presetColumnWidths = mkOption {
        type = types.listOf types.float;
        default = [ 0.33333 0.5 0.66667 ];
        description = "快捷键 Mod+R 循环切换的列宽比例预设列表。";
      };

      defaultColumnWidth = mkOption {
        type = types.attrsOf types.anything;
        default = { proportion = 0.5; };
        description = "新窗口打开时的默认列宽配置，例如 { proportion = 0.5; }。";
      };

      focusRing = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "是否启用活动窗口焦点环外框。";
        };

        width = mkOption {
          type = types.int;
          default = 4;
          description = "焦点环外框宽度（逻辑像素）。";
        };

        activeColor = mkOption {
          type = types.str;
          default = "#7fc8ff";
          description = "当前活动监视器上活动窗口的焦点环颜色。";
        };

        inactiveColor = mkOption {
          type = types.str;
          default = "#505050";
          description = "非活动监视器上活动窗口的焦点环颜色。";
        };
      };

      border = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "是否启用所有窗口始终可见的静态边框。";
        };

        width = mkOption {
          type = types.int;
          default = 4;
          description = "静态边框宽度（逻辑像素）。";
        };

        activeColor = mkOption {
          type = types.str;
          default = "#ffc87f";
          description = "活动窗口静态边框颜色。";
        };

        inactiveColor = mkOption {
          type = types.str;
          default = "#505050";
          description = "非活动窗口静态边框颜色。";
        };
      };

      shadow = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "是否启用窗口投影阴影。";
        };

        softness = mkOption {
          type = types.int;
          default = 30;
          description = "投影阴影模糊半径。";
        };

        spread = mkOption {
          type = types.int;
          default = 5;
          description = "投影阴影扩散范围。";
        };

        offset = mkOption {
          type = types.attrsOf types.int;
          default = { x = 0; y = 5; };
          description = "投影阴影偏移坐标 { x, y }。";
        };

        color = mkOption {
          type = types.str;
          default = "#0007";
          description = "投影阴影颜色与透明度。";
        };
      };
    };

    input = {
      keyboard = {
        xkb = mkOption {
          type = types.attrsOf types.str;
          default = { };
          description = "键盘布局与选项（如 layout, options, model, variant）。";
        };

        numlock = mkOption {
          type = types.bool;
          default = true;
          description = "是否在启动时自动开启数字小键盘锁 (NumLock)。";
        };
      };

      touchpad = {
        tap = mkOption {
          type = types.bool;
          default = true;
          description = "触摸板是否开启轻触点击 (tap)。";
        };

        naturalScroll = mkOption {
          type = types.bool;
          default = true;
          description = "触摸板是否开启自然滚动。";
        };

        accelSpeed = mkOption {
          type = types.nullOr types.float;
          default = null;
          description = "触摸板指针加速速度 (-1.0 到 1.0)。";
        };

        accelProfile = mkOption {
          type = types.nullOr (types.enum [ "flat" "adaptive" ]);
          default = null;
          description = "触摸板指针加速曲线。";
        };
      };

      mouse = {
        naturalScroll = mkOption {
          type = types.bool;
          default = false;
          description = "鼠标是否开启自然滚动。";
        };

        accelSpeed = mkOption {
          type = types.nullOr types.float;
          default = null;
          description = "鼠标指针加速速度 (-1.0 到 1.0)。";
        };

        accelProfile = mkOption {
          type = types.nullOr (types.enum [ "flat" "adaptive" ]);
          default = null;
          description = "鼠标指针加速曲线。";
        };
      };

      warpMouseToFocus = mkOption {
        type = types.bool;
        default = false;
        description = "在焦点改变时是否自动将鼠标光标移动至新聚焦窗口的中心。";
      };

      focusFollowsMouse = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "是否启用鼠标光标悬停跟随对焦。";
        };

        maxScrollAmount = mkOption {
          type = types.str;
          default = "0%";
          description = "鼠标悬停跟随对焦时的最大允许滚动比例。";
        };
      };
    };

    outputs = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = "是否启用该显示输出。设为 false 将生成 off 指令关闭输出。";
          };

          mode = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "1920x1080@120.030";
            description = "显示分辨率与刷新率。";
          };

          scale = mkOption {
            type = types.nullOr (types.either types.int types.float);
            default = null;
            example = 1.5;
            description = "显示缩放比例。";
          };

          transform = mkOption {
            type = types.enum [ "normal" "90" "180" "270" "flipped" "flipped-90" "flipped-180" "flipped-270" ];
            default = "normal";
            description = "显示旋转或翻转角度。";
          };

          position = mkOption {
            type = types.nullOr (types.attrsOf types.int);
            default = null;
            example = { x = 1920; y = 0; };
            description = "全局坐标系中的显示器相对位置。";
          };
        };
      });
      default = { };
      description = "显示输出监视器配置列表，以输出接口名称为键（如 eDP-1, DP-1）。";
    };

    animations = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否启用 Niri 窗口与工作区动画效果。";
      };

      slowdown = mkOption {
        type = types.nullOr types.float;
        default = null;
        description = "动画减速/加速倍率（大于 1 减速，小于 1 加速）。";
      };
    };

    cursor = {
      theme = mkOption {
        type = types.str;
        default = "default";
        description = "XCursor 鼠标指针主题名称。";
      };

      size = mkOption {
        type = types.int;
        default = 24;
        description = "XCursor 鼠标指针像素大小。";
      };
    };

    preferNoCsd = mkOption {
      type = types.bool;
      default = false;
      description = "是否请求客户端优先省略客户端装饰 (CSD)，由 Niri 统一绘制边框与焦点环。";
    };

    screenshotPath = mkOption {
      type = types.nullOr types.str;
      default = "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png";
      description = "快捷键截图保存的目标路径模版（支持 strftime 语法，设为 null 则禁用保存到磁盘）。";
    };

    hotkeyOverlay = {
      skipAtStartup = mkOption {
        type = types.bool;
        default = false;
        description = "是否在 Niri 启动时禁用快捷键提示弹窗 (Important Hotkeys)。";
      };
    };

    windowRules = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否启用默认精细化窗口规则集合（优化弹窗、媒体播放、文件选择器及对话框）。";
      };

      extraRules = mkOption {
        type = types.listOf (types.attrsOf types.anything);
        default = [ ];
        description = "附加的自定义窗口规则列表（追加写入 window-rule）。";
      };
    };

    extraRules = mkOption {
      type = types.listOf (types.attrsOf types.anything);
      default = [ ];
      description = "快捷注册的自定义窗口规则列表（追加写入 window-rule）。";
    };

    layerRules = mkOption {
      type = types.listOf (types.attrsOf types.anything);
      default = [ ];
      description = "附加的图层规则列表（追加写入 layer-rule）。";
    };

    autostart = mkOption {
      type = types.listOf (types.either types.str (types.listOf types.str));
      default = [ ];
      description = "在 Niri 启动时自启动执行的命令列表（写入 spawn-at-startup / spawn-sh-at-startup）。";
    };

    extraSpawn = mkOption {
      type = types.listOf (types.either types.str (types.listOf types.str));
      default = [ ];
      description = "附加的自启动执行命令列表。";
    };

    extraBinds = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "附加的快捷键绑定属性集。";
    };

    virtualization = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "是否启用虚拟机环境兼容设置（禁用光标平面以适配 VirtualBox / VMware / QEMU 等环境。注意：Niri 在 TTY/DRM 下会跳过纯软件 EGL 渲染器，虚拟机须启用 3D 硬件加速）。";
      };
    };

    sessionVariables = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "桌面会话所需的环境变量。";
    };

    settings = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "以 Nix 结构化数据编写的 Niri 配置，将与默认预设深度合并。支持 _args, _props, _children, _raw 等扩展。";
    };

    extraConfigEarly = mkOption {
      type = types.lines;
      default = "";
      description = "追加写入到 config.kdl 最前端的原生配置文本。";
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = "追加写入到 config.kdl 最末尾的原生配置文本。";
    };

    checkConfig = mkOption {
      type = types.bool;
      default = true;
      description = "是否在构建期使用 niri validate 严格验证配置文件的合法性。";
    };

    homeManager = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "若系统中启用了 Home Manager，是否自动将 Niri 配置注入到所有 Home Manager 用户中。";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      # 校验：虚拟机兼容模式只允许在虚拟机环境下开启
      assertions = [
        {
          assertion = cfg.virtualization.enable -> (
            if config ? base && config.base ? hardware && config.base.hardware ? type then
              config.base.hardware.type != "physical"
            else
              true
          );
          message = "桌面环境配置错误：Niri 虚拟机兼容模式 (desktop.windowManager.niri.virtualization.enable) 仅允许在虚拟机环境 (base.hardware.type != \"physical\") 下开启。";
        }
      ];

      # ── 主题联动：显式声明 Niri 对主题钩子的 PATH 与脚本注入 ───────────────
      # 当全局主题启用时，向 theme 钩子注入 Niri 动态颜色逻辑与所需二进制
      desktop.theme.hookPackages = mkIf (config.desktop.theme.enable or false) [
        cfg.package
        pkgs.coreutils
        pkgs.procps
      ];

      desktop.theme.hookFragmentsSeedSafe = mkIf (config.desktop.theme.enable or false) [''
        # --- Niri 主题联动 seedSafe（由 modules/windowManager/niri 注入，仅落盘） ---
        if [ "$MODE" = "dark" ]; then
          NIRI_FOCUS_ACTIVE="${config.desktop.theme.dark.niri.focusRingActiveColor}"
          NIRI_BORDER_ACTIVE="${config.desktop.theme.dark.niri.borderActiveColor}"
          NIRI_INACTIVE="${config.desktop.theme.dark.niri.inactiveColor}"
        else
          NIRI_FOCUS_ACTIVE="${config.desktop.theme.light.niri.focusRingActiveColor}"
          NIRI_BORDER_ACTIVE="${config.desktop.theme.light.niri.borderActiveColor}"
          NIRI_INACTIVE="${config.desktop.theme.light.niri.inactiveColor}"
        fi
        NIRI_THEME_DIR="$RUNTIME_DIR/niri"
        if [ -e "$NIRI_THEME_DIR" ] && [ ! -d "$NIRI_THEME_DIR" ]; then
          echo "[theme-switch] warn: $NIRI_THEME_DIR is not a directory" >&2
        else
          mkdir -p "$NIRI_THEME_DIR" 2>/dev/null || true
          NIRI_THEME_CONTENT="layout {
        focus-ring {
            width ${toString config.desktop.theme.layout.focusRing.width}
            active-color \"$NIRI_FOCUS_ACTIVE\"
            inactive-color \"$NIRI_INACTIVE\"
        }
        border {
            active-color \"$NIRI_BORDER_ACTIVE\"
            inactive-color \"$NIRI_INACTIVE\"
        }
        }
        "
          if ! printf '%s' "$NIRI_THEME_CONTENT" | ${pkgs.coreutils}/bin/install -Dm644 /dev/stdin "$NIRI_THEME_DIR/theme.kdl" 2>/dev/null; then
            printf '%s' "$NIRI_THEME_CONTENT" > "$NIRI_THEME_DIR/theme.kdl" 2>/dev/null || echo "[theme-switch] warn: failed to write niri theme" >&2
          fi
        fi
      ''];

      desktop.theme.hookFragmentsReload = mkIf (config.desktop.theme.enable or false) [''
        # --- Niri 主题联动 reload（由 modules/windowManager/niri 注入，需 niri 守护进程） ---
        NIRI_THEME_DIR="$RUNTIME_DIR/niri"
        if [ -d "$NIRI_THEME_DIR" ] && command -v niri >/dev/null 2>&1; then
          # 仅当 niri 守护进程可响应时才 reload，避免冷启动阻塞
          if pgrep -x niri >/dev/null 2>&1 || niri msg --help >/dev/null 2>&1; then
            NIRI_CONFIG_DIR="''${XDG_CONFIG_HOME:-$HOME/.config}/niri"
            NIRI_SYSTEM_CONFIG="/etc/xdg/niri/config.kdl"
            if [ -f "$NIRI_CONFIG_DIR/config.kdl" ]; then
              niri msg action load-config-file --path "$NIRI_CONFIG_DIR/config.kdl" 2>/dev/null || true
            elif [ -f "$NIRI_SYSTEM_CONFIG" ]; then
              niri msg action load-config-file --path "$NIRI_SYSTEM_CONFIG" 2>/dev/null || true
            fi
          else
            echo "[theme-switch] diag: niri not ready, skipping reload" >&2
          fi
        fi
      ''];

      # 1. 启用 NixOS 官方 programs.niri 支持
      programs.niri = {
        enable = true;
        package = cfg.package;
        useNautilus = (cfg.portal.filechooser == "gnome");
      };

      # 2. 基础 Wayland 桌面配套工具与 XWayland 兼容层
      environment.systemPackages = [
        cfg.package
        pkgs.wl-clipboard
        pkgs.grim
        pkgs.slurp
      ] ++ (optional (cfg.xwayland.enable && cfg.xwayland.package != null) cfg.xwayland.package);

      # 3. 会话环境变量
      environment.sessionVariables = mkMerge [
        {
          NIXOS_OZONE_WL = "1";
          QT_QPA_PLATFORM = "wayland;xcb";
          QT_AUTO_SCREEN_SCALE_FACTOR = "1";
          QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
          QT_SCALE_FACTOR_ROUNDING_POLICY = "PassThrough";
          GDK_BACKEND = "wayland,x11";
          CLUTTER_BACKEND = "wayland";
          SDL_VIDEODRIVER = "wayland,x11,windows";
          _JAVA_AWT_WM_NONREPARENTING = "1";
          ELECTRON_OZONE_PLATFORM_HINT = "auto";
        }
        cfg.sessionVariables
      ];

      # 4. 系统级 Niri 配置文件部署
      environment.etc = {
        "niri/config.kdl".source = configFile;
        "xdg/niri/config.kdl".source = configFile;
        "niri/config-gamemode.kdl".source = gamemodeConfigFile;
        "xdg/niri/config-gamemode.kdl".source = gamemodeConfigFile;
      };

      # 5. XDG Desktop Portal 桌面门户集成配置
      xdg.portal = mkIf cfg.portal.enable {
        enable = true;
        extraPortals = cfg.portal.extraPortals;
        config = {
          niri = mkMerge [
            {
              default = [
                "gnome"
                "gtk"
              ];
              "org.freedesktop.impl.portal.Access" = "gtk";
              "org.freedesktop.impl.portal.Notification" = "gtk";
              "org.freedesktop.impl.portal.Secret" = "gnome-keyring";
            }
            (optionalAttrs (cfg.portal.filechooser != "none") {
              "org.freedesktop.impl.portal.FileChooser" = mkForce cfg.portal.filechooser;
            })
            cfg.portal.config
          ];
        };
      };

      # 5b. 主题切换快捷键
      desktop.windowManager.niri.extraBinds = mkIf (cfg.themeIntegration.enable && cfg.themeIntegration.themeToggleKeybind != "") {
        "${cfg.themeIntegration.themeToggleKeybind}" = {
          _props.hotkey-overlay-title = "Toggle Dark/Light Theme";
          spawn-sh = [ "theme-ctl toggle" ];
        };
      };
    }

    # 6. Home Manager 自动联动
    (optionalAttrs (options ? home-manager) {
      home-manager = mkIf cfg.homeManager.enable {
        sharedModules = [
          ({ ... }: {
            xdg.configFile."niri/config.kdl".source = configFile;
            xdg.configFile."niri/config-gamemode.kdl".source = gamemodeConfigFile;
            home.packages = [
              pkgs.wl-clipboard
              pkgs.grim
              pkgs.slurp
            ] ++ (optional (cfg.xwayland.enable && cfg.xwayland.package != null) cfg.xwayland.package);
          })
        ];
      };
    })
  ]);
}
