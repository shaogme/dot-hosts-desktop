{
  config,
  pkgs,
  lib,
  options,
  ...
}:

with lib;

let
  cfg = config.desktop.wallpaper.awww;

  scripts = import ./scripts.nix {
    inherit
      pkgs
      lib
      cfg
      ;
  };

  sessionVars = {
    AWWW_TRANSITION = cfg.transition.type;
    AWWW_TRANSITION_DURATION = toString cfg.transition.duration;
    AWWW_TRANSITION_FPS = toString cfg.transition.fps;
    AWWW_TRANSITION_ANGLE = toString cfg.transition.angle;
    AWWW_TRANSITION_POS = cfg.transition.pos;
    AWWW_TRANSITION_BEZIER = cfg.transition.bezier;
    AWWW_TRANSITION_WAVE = cfg.transition.wave;
  } // optionalAttrs (cfg.transition.step != null) {
    AWWW_TRANSITION_STEP = toString cfg.transition.step;
  };

  allPackages = [
    cfg.package
    scripts.awwwSetScript
    scripts.awwwRandomScript
    scripts.awwwNextScript
    scripts.awwwSwitchScript
    scripts.awwwRestoreScript
    scripts.awwwInitScript
  ];
in
{
  options.desktop.wallpaper.awww = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "是否启用基于 awww (原 swww) 的高性能动态壁纸守护进程与深度自定义壁纸管理模块。";
    };

    package = mkPackageOption pkgs "awww" { };

    wallpaper = mkOption {
      type = types.nullOr (types.either types.path types.str);
      default = null;
      description = "系统全局壁纸图片路径。";
    };

    wallpaperDir = mkOption {
      type = types.nullOr (types.either types.path types.str);
      default = null;
      description = "壁纸轮播与随机选择检索目录（若未指定，默认检索 ~/Pictures/Wallpapers、~/Pictures/wallpaper 及 /etc/wallpapers）。";
    };

    color = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "纯色背景填充 Hex 色值（如 1e1e2e 或 141419，对应 awww clear）。";
    };

    outputs = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          wallpaper = mkOption {
            type = types.nullOr (types.either types.path types.str);
            default = null;
            description = "该显示器输出绑定的独立壁纸文件路径。";
          };
          resize = mkOption {
            type = types.nullOr (types.enum [ "crop" "fit" "stretch" "no" ]);
            default = null;
            description = "该输出的专属图像缩放策略（null 则遵循全局 render.resize）。";
          };
          cropGravity = mkOption {
            type = types.nullOr (types.enum [
              "center"
              "top-left"
              "top"
              "top-right"
              "left"
              "right"
              "bottom-left"
              "bottom"
              "bottom-right"
            ]);
            default = null;
            description = "该输出的裁剪锚点方位（null 则遵循全局 render.cropGravity）。";
          };
          filter = mkOption {
            type = types.nullOr (types.enum [ "Lanczos3" "Nearest" "Bilinear" "CatmullRom" "Mitchell" ]);
            default = null;
            description = "该输出的图像缩放插值算法（null 则遵循全局 render.filter）。";
          };
          fillColor = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "该输出的背景留白填充色（null 则遵循全局 render.fillColor）。";
          };
          transitionType = mkOption {
            type = types.nullOr (types.enum [
              "none"
              "simple"
              "fade"
              "left"
              "right"
              "top"
              "bottom"
              "wipe"
              "wave"
              "grow"
              "center"
              "any"
              "outer"
              "random"
            ]);
            default = null;
            description = "该输出的转场过渡类型（null 则遵循全局 transition.type）。";
          };
        };
      });
      default = { };
      description = "多显示器独立输出映射配置（key 为显示器名称，如 DP-1、HDMI-A-1、eDP-1）。";
    };

    daemon = {
      format = mkOption {
        type = types.enum [ "argb" "abgr" "rgb" "bgr" ];
        default = "argb";
        description = "强制守护进程使用的 wl_shm 像素内存格式（argb 兼容性最好，rgb/bgr 占用内存减少 25%）。";
      };

      layer = mkOption {
        type = types.enum [ "background" "bottom" ];
        default = "background";
        description = "壁纸渲染所在的 Wayland 图层 (layer-shell)。";
      };

      namespace = mkOption {
        type = types.str;
        default = "";
        description = "守护进程自定义 Wayland 命名空间及 socket 隔离标识。";
      };

      noCache = mkOption {
        type = types.bool;
        default = false;
        description = "守护进程启动时不自动从磁盘缓存恢复上次壁纸。";
      };

      quiet = mkOption {
        type = types.bool;
        default = false;
        description = "守护进程仅输出错误日志。";
      };

      extraArgs = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "传递给 awww-daemon 的附加命令行参数列表。";
      };

      systemd = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "是否通过 systemd 用户服务 (awww-daemon.service) 托管运行壁纸守护进程。";
        };
      };
    };

    render = {
      resize = mkOption {
        type = types.enum [ "crop" "fit" "stretch" "no" ];
        default = "crop";
        description = "壁纸图像缩放策略：crop(全屏裁剪填满)、fit(完整比例缩放留白)、stretch(拉伸填满)、no(不缩放居中)。";
      };

      cropGravity = mkOption {
        type = types.enum [
          "center"
          "top-left"
          "top"
          "top-right"
          "left"
          "right"
          "bottom-left"
          "bottom"
          "bottom-right"
        ];
        default = "center";
        description = "crop 模式下的锚点方位。";
      };

      filter = mkOption {
        type = types.enum [ "Lanczos3" "Nearest" "Bilinear" "CatmullRom" "Mitchell" ];
        default = "Lanczos3";
        description = "图像缩放插值算法（Lanczos3 画质最高，Nearest 适合像素艺术风格）。";
      };

      fillColor = mkOption {
        type = types.str;
        default = "000000";
        description = "fit 或 no 缩放留白背景填充色 (RRGGBB)。";
      };
    };

    transition = {
      type = mkOption {
        type = types.enum [
          "none"
          "simple"
          "fade"
          "left"
          "right"
          "top"
          "bottom"
          "wipe"
          "wave"
          "grow"
          "center"
          "any"
          "outer"
          "random"
        ];
        default = "fade";
        description = "壁纸切换时的转场特效类型（fade 贝塞尔平滑淡入、grow 扩散圆、wipe 线性擦除、wave 波动擦除等）。";
      };

      duration = mkOption {
        type = types.either types.int types.float;
        default = 2.0;
        description = "转场动画持续时间（秒）。";
      };

      fps = mkOption {
        type = types.int;
        default = 60;
        description = "转场动画刷新帧率。";
      };

      step = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "转场步长（1-255，值越小越平滑细腻；null 表示使用 awww 内部默认）。";
      };

      angle = mkOption {
        type = types.either types.int types.float;
        default = 45.0;
        description = "wipe 和 wave 转场模式下的擦除扫描角度（度数，0 为右至左，90 为上至下，45 为对角斜线）。";
      };

      pos = mkOption {
        type = types.str;
        default = "center";
        description = "grow 和 outer 转场模式下的圆心起始位置（支持 center、top-left 等别名，或 0.5,0.5 百分比，或 200,400 像素）。";
      };

      invertY = mkOption {
        type = types.bool;
        default = false;
        description = "是否翻转 grow/outer 转场中 Y 轴的起始坐标方向。";
      };

      bezier = mkOption {
        type = types.str;
        default = ".54,0,.34,.99";
        description = "转场动画的三次贝塞尔曲线插值参数 (f1,f2,f3,f4)。";
      };

      wave = mkOption {
        type = types.str;
        default = "20,20";
        description = "wave 波动转场模式下的波宽与波高 (width,height)。";
      };
    };

    slideshow = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "是否启用壁纸自动定时轮播功能。";
      };

      interval = mkOption {
        type = types.int;
        default = 300;
        description = "壁纸轮换时间间隔（秒，默认 300 秒即 5 分钟）。";
      };

      random = mkOption {
        type = types.bool;
        default = true;
        description = "轮播时是否随机打乱顺序（false 为按文件名顺序轮换）。";
      };

      systemdTimer = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "是否使用 systemd 用户定时器 (awww-slideshow.timer) 驱动轮播。";
        };
      };
    };

    niri = {
      autostart = mkOption {
        type = types.bool;
        default = true;
        description = "是否在 Niri 启动时自动初始化 awww 守护进程并应用初始壁纸。";
      };

      keybinds = {
        randomWallpaper = mkOption {
          type = types.str;
          default = "Mod+Alt+W";
          description = "在 Niri 中一键随机切换壁纸的快捷键（设为空则不注册）。";
        };

        nextWallpaper = mkOption {
          type = types.str;
          default = "Mod+Ctrl+W";
          description = "在 Niri 中切换下一张壁纸的快捷键（设为空则不注册）。";
        };

        selectWallpaper = mkOption {
          type = types.str;
          default = "Mod+Shift+W";
          description = "在 Niri 中弹出壁纸交互选择器的快捷键（设为空则不注册）。";
        };
      };
    };

    homeManager = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "若系统中启用了 Home Manager，是否自动将 awww 软件包与配置注入到所有 Home Manager 用户中。";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      # 编译期断言：壁纸路径必须显式配置
      assertions = [
        {
          assertion = cfg.wallpaper != null;
          message = "desktop.wallpaper.awww: 必须显式配置壁纸图片路径 (desktop.wallpaper.awww.wallpaper)。";
        }
      ];

      # ── 主题联动：显式声明 awww 对主题钩子的 PATH 与壁纸切换注入（条件化） ──
      # 仅当全局主题的深/浅色壁纸已配置时才注入，避免在未使用壁纸切换的主机上引入无谓闭包
      desktop.theme.hookPackages = mkIf (config.desktop.theme.enable or false && (config.desktop.theme.dark.wallpaper != null || config.desktop.theme.light.wallpaper != null)) [
        cfg.package
        scripts.awwwSetScript
        pkgs.procps
        pkgs.systemd
      ];
      desktop.theme.hookFragmentsReload = mkIf (config.desktop.theme.enable or false && (config.desktop.theme.dark.wallpaper != null || config.desktop.theme.light.wallpaper != null)) [''
        # --- Wallpaper 主题联动 reload（由 modules/wallpaper/awww 注入，条件化于 theme wallpaper，需 awww 守护进程，seed 跳过） ---
        WALLPAPER_PATH=""
        if [ "$MODE" = "dark" ]; then
          WALLPAPER_PATH="${toString (if config.desktop.theme.dark.wallpaper != null then config.desktop.theme.dark.wallpaper else "")}"
        else
          WALLPAPER_PATH="${toString (if config.desktop.theme.light.wallpaper != null then config.desktop.theme.light.wallpaper else "")}"
        fi
        if [ -n "$WALLPAPER_PATH" ] && [ -f "$WALLPAPER_PATH" ]; then
          if systemctl --user is-active awww-daemon.service >/dev/null 2>&1 || pgrep -x awww-daemon >/dev/null 2>&1; then
            if command -v awww-set >/dev/null 2>&1; then
              awww-set "$WALLPAPER_PATH" 2>/dev/null || true
            elif [ -x "${scripts.awwwSetScript}/bin/awww-set" ]; then
              ${scripts.awwwSetScript}/bin/awww-set "$WALLPAPER_PATH" 2>/dev/null || true
            elif [ -x "${cfg.package}/bin/awww" ]; then
              ${cfg.package}/bin/awww img "$WALLPAPER_PATH" 2>/dev/null || true
            fi
          else
            echo "[theme-switch] diag: awww-daemon not ready, skipping wallpaper" >&2
          fi
        fi
      ''];

      # 1. 系统级软件包与工具脚本
      environment.systemPackages = allPackages;

      # 2. 会话环境变量（使任意终端和脚本继承默认转场设置）
      environment.sessionVariables = sessionVars;

      # 3. Systemd 用户服务：awww-daemon
      systemd.user.services.awww-daemon = mkIf cfg.daemon.systemd.enable {
        description = "awww - High-performance Wayland Wallpaper Daemon";
        documentation = [ "man:awww-daemon(1)" ];
        partOf = [ "graphical-session.target" ];
        after = [ "graphical-session.target" ];
        wantedBy = [ "graphical-session.target" ];
        unitConfig = {
          ConditionEnvironment = "WAYLAND_DISPLAY";
        };
        serviceConfig = {
          Type = "notify";
          ExecStart = "${cfg.package}/bin/awww-daemon ${scripts.daemonArgsStr}";
          ExecStartPost = "${scripts.awwwInitScript}/bin/awww-init --apply-only";
          ExecStop = "${cfg.package}/bin/awww ${optionalString (cfg.daemon.namespace != "") "--namespace ${cfg.daemon.namespace}"} kill";
          Restart = "on-failure";
          RestartSec = 1;
        };
      };

      # 4. Systemd 定时轮播服务与定时器 (awww-slideshow)
      systemd.user.services.awww-slideshow = mkIf (cfg.slideshow.enable && cfg.slideshow.systemdTimer.enable) {
        description = "awww - Automatic Wallpaper Slideshow Rotator";
        partOf = [ "graphical-session.target" ];
        after = [ "awww-daemon.service" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart =
            if cfg.slideshow.random then
              "${scripts.awwwRandomScript}/bin/awww-random"
            else
              "${scripts.awwwNextScript}/bin/awww-next";
        };
      };

      systemd.user.timers.awww-slideshow = mkIf (cfg.slideshow.enable && cfg.slideshow.systemdTimer.enable) {
        description = "awww - Wallpaper Slideshow Timer";
        partOf = [ "graphical-session.target" ];
        wantedBy = [ "timers.target" "graphical-session.target" ];
        timerConfig = {
          OnUnitActiveSec = "${toString cfg.slideshow.interval}s";
          OnBootSec = "15s";
          Persistent = true;
        };
      };

      # 5. 联动 Niri 注册自启动与快捷键
      desktop.windowManager.niri = mkIf (config ? desktop && config.desktop ? windowManager && config.desktop.windowManager ? niri && config.desktop.windowManager.niri.enable) {
        # 仅在未启用 systemd 服务管理时通过 Niri 命令行拉起，避免同时启动产生竞态导致 "There is an awww-daemon instance already running on this socket!" 崩溃
        autostart = mkIf (cfg.niri.autostart && !cfg.daemon.systemd.enable) [
          "${scripts.awwwInitScript}/bin/awww-init"
        ];
        extraBinds = (optionalAttrs (cfg.niri.keybinds.randomWallpaper != "") {
          "${cfg.niri.keybinds.randomWallpaper}" = {
            _props.hotkey-overlay-title = "Random Wallpaper";
            spawn = [ "${scripts.awwwRandomScript}/bin/awww-random" ];
          };
        }) // (optionalAttrs (cfg.niri.keybinds.nextWallpaper != "") {
          "${cfg.niri.keybinds.nextWallpaper}" = {
            _props.hotkey-overlay-title = "Next Wallpaper";
            spawn = [ "${scripts.awwwNextScript}/bin/awww-next" ];
          };
        }) // (optionalAttrs (cfg.niri.keybinds.selectWallpaper != "") {
          "${cfg.niri.keybinds.selectWallpaper}" = {
            _props.hotkey-overlay-title = "Select Wallpaper";
            spawn = [ "${scripts.awwwSwitchScript}/bin/awww-switch" ];
          };
        });
      };
    }

    # 6. Home Manager 用户环境联动
    (optionalAttrs (options ? home-manager) {
      home-manager = mkIf cfg.homeManager.enable {
        sharedModules = [
          ({ ... }: {
            # 系统级环境已通过 environment.systemPackages 提供了全局可用的二进制及壁纸资源，
            # 并通过系统级 systemd.user.services 与 timers 统一管理生命周期。
            # 此处注入环境变量，确保用户终端与子进程均可继承。
            home.sessionVariables = sessionVars;
          })
        ];
      };
    })
  ]);
}
