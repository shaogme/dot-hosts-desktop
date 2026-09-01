{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.desktop.loginManager.tuigreet;
  tomlFormat = pkgs.formats.toml { };

  # 递归过滤 null 值以及空集合，避免向 TOML 写入无意义的空字段或 null
  filterNulls = attrs:
    let
      filtered = filterAttrs (n: v: v != null) attrs;
      recurse = mapAttrs (n: v:
        if builtins.isAttrs v && !isDerivation v then filterNulls v
        else if builtins.isList v then builtins.filter (x: x != null) v
        else v
      ) filtered;
    in
    filterAttrs (n: v: !(builtins.isAttrs v && v == { })) recurse;

  # 构建结构化的默认 TOML 配置
  rawConfig = {
    general = filterNulls {
      debug = cfg.debug;
      log_file = cfg.logFile;
    };

    session = filterNulls {
      command = cfg.command;
      sessions_dirs = cfg.sessions;
      xsessions_dirs = cfg.xsessions;
      session_wrapper = cfg.session.sessionWrapper;
      xsession_wrapper = cfg.session.xsessionWrapper;
      environments = cfg.session.environments;
    };

    display = filterNulls {
      show_time = cfg.display.showTime;
      time_format = cfg.display.timeFormat;
      greeting = cfg.display.greeting;
      align_greeting = cfg.display.alignGreeting;
      issue = cfg.display.issue;
      battery = cfg.display.battery;
      show_title = cfg.display.showTitle;
      custom_title = cfg.display.customTitle;
    };

    remember = filterNulls {
      username = cfg.remember.username;
      session = cfg.remember.session;
      user_session = cfg.remember.userSession;
    };

    user_menu = filterNulls {
      enabled = cfg.userMenu.enable;
      min_uid = cfg.userMenu.minUid;
      max_uid = cfg.userMenu.maxUid;
    };

    secret = filterNulls {
      mode = cfg.secret.mode;
      characters = cfg.secret.characters;
    };

    layout = filterNulls {
      width = cfg.layout.width;
      window_padding = cfg.layout.windowPadding;
      container_padding = cfg.layout.containerPadding;
      prompt_padding = cfg.layout.promptPadding;
      widgets = filterNulls {
        time_position = cfg.layout.widgets.timePosition;
        status_position = cfg.layout.widgets.statusPosition;
        battery_position = cfg.layout.widgets.batteryPosition;
        status_bar = filterNulls {
          show_reset = cfg.layout.widgets.statusBar.showReset;
          show_command = cfg.layout.widgets.statusBar.showCommand;
          show_session = cfg.layout.widgets.statusBar.showSession;
          show_power = cfg.layout.widgets.statusBar.showPower;
          show_background = cfg.layout.widgets.statusBar.showBackground;
          show_session_status = cfg.layout.widgets.statusBar.showSessionStatus;
          show_caps_lock = cfg.layout.widgets.statusBar.showCapsLock;
        };
      };
    };

    keybindings = filterNulls {
      command = cfg.keybindings.command;
      sessions = cfg.keybindings.sessions;
      background = cfg.keybindings.background;
      power = cfg.keybindings.power;
    };

    background = filterNulls {
      kind = cfg.background.kind;
      fps = cfg.background.fps;
      doom = filterNulls {
        height = cfg.background.doom.height;
        spread = cfg.background.doom.spread;
        top_color = cfg.background.doom.topColor;
        middle_color = cfg.background.doom.middleColor;
        bottom_color = cfg.background.doom.bottomColor;
      };
      matrix = filterNulls {
        head_color = cfg.background.matrix.headColor;
        bright_color = cfg.background.matrix.brightColor;
        dim_color = cfg.background.matrix.dimColor;
        min_length = cfg.background.matrix.minLength;
        max_length = cfg.background.matrix.maxLength;
        min_speed = cfg.background.matrix.minSpeed;
        max_speed = cfg.background.matrix.maxSpeed;
        mutate_chance = cfg.background.matrix.mutateChance;
      };
    };

    power = filterNulls {
      use_setsid = cfg.power.useSetsid;
      shutdown = cfg.power.shutdownCmd;
      reboot = cfg.power.rebootCmd;
    };

    theme = filterNulls cfg.theme;

    outputs = map (o: filterNulls {
      connector = o.connector;
      primary = o.primary;
      enabled = o.enabled;
    }) cfg.outputs;

    terminal = filterNulls {
      cols = cfg.terminal.cols;
      rows = cfg.terminal.rows;
    };
  };

  # 将结构化配置与用户传入的 settings 深度合并
  finalConfig = recursiveUpdate (filterNulls rawConfig) cfg.settings;
  configFile = tomlFormat.generate "tuigreet.toml" finalConfig;
in
{
  options.desktop.loginManager.tuigreet = {
    enable = mkEnableOption "tuigreet 现代化终端图形登录管理器";

    package = mkOption {
      type = types.package;
      default = pkgs.tuigreet;
      defaultText = literalExpression "pkgs.tuigreet";
      description = "使用的 tuigreet 软件包。";
    };

    user = mkOption {
      type = types.str;
      default = "greeter";
      description = "运行 greetd / tuigreet 的系统用户。";
    };

    command = mkOption {
      type = types.nullOr types.str;
      default = "Hyprland";
      description = "默认启动的会话命令（如 Hyprland、sway 等）。";
    };

    sessions = mkOption {
      type = types.listOf types.str;
      default = [
        "${config.services.displayManager.sessionData.desktops}/share/wayland-sessions"
        "${config.services.displayManager.sessionData.desktops}/share/xsessions"
      ];
      defaultText = literalExpression ''
        [
          "''${config.services.displayManager.sessionData.desktops}/share/wayland-sessions"
          "''${config.services.displayManager.sessionData.desktops}/share/xsessions"
        ]
      '';
      description = "Wayland / X11 会话桌面文件（.desktop）的检索目录列表。";
    };

    xsessions = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "单独指定的 X11 会话桌面文件检索目录列表。";
    };

    extraArgs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "传递给 tuigreet 的附加命令行参数列表。";
    };

    # 1. 常规与调试 (general)
    debug = mkOption {
      type = types.bool;
      default = false;
      description = "是否启用调试日志记录。";
    };

    logFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "调试日志文件输出路径（默认为 /tmp/tuigreet.log）。";
    };

    # 2. 显示设置 (display)
    display = {
      showTime = mkOption {
        type = types.bool;
        default = true;
        description = "是否在界面中显示当前时间和日期。";
      };

      timeFormat = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "%Y-%m-%d %H:%M";
        description = "自定义时间和日期显示格式（strftime 语法）。";
      };

      greeting = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "Welcome to NixOS!";
        description = "在登录提示框上方显示的自定义问候文本。";
      };

      alignGreeting = mkOption {
        type = types.enum [ "left" "center" "right" ];
        default = "center";
        description = "问候语在提示框中的对齐方式。";
      };

      issue = mkOption {
        type = types.bool;
        default = false;
        description = "是否在问候语区域显示系统的 /etc/issue 内容。";
      };

      battery = mkOption {
        type = types.bool;
        default = false;
        description = "是否在界面中显示电池电量百分比。";
      };

      showTitle = mkOption {
        type = types.bool;
        default = false;
        description = "是否显示主登录框的标题。";
      };

      customTitle = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "NixOS Login";
        description = "主登录框的自定义标题内容。";
      };
    };

    # 3. 布局与尺寸 (layout)
    layout = {
      width = mkOption {
        type = types.int;
        default = 80;
        description = "主登录输入框宽度（以字符列数为单位）。";
      };

      windowPadding = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "终端边界与主界面之间的内边距。";
      };

      containerPadding = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "主登录框容器内部的边距。";
      };

      promptPadding = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "登录提示行之间的行间距。";
      };

      widgets = {
        timePosition = mkOption {
          type = types.enum [ "default" "top" "bottom" "hidden" ];
          default = "default";
          description = "时间组件的位置。";
        };

        statusPosition = mkOption {
          type = types.enum [ "default" "top" "bottom" "hidden" ];
          default = "default";
          description = "状态栏组件的位置。";
        };

        batteryPosition = mkOption {
          type = types.enum [ "default" "left" "right" "top" "bottom" "hidden" ];
          default = "left";
          description = "电池组件的位置。";
        };

        statusBar = {
          showReset = mkOption {
            type = types.bool;
            default = true;
            description = "是否在状态栏中显示 Reset 操作提示。";
          };
          showCommand = mkOption {
            type = types.bool;
            default = true;
            description = "是否在状态栏中显示 Command (F2) 操作提示。";
          };
          showSession = mkOption {
            type = types.bool;
            default = true;
            description = "是否在状态栏中显示 Sessions (F3) 操作提示。";
          };
          showPower = mkOption {
            type = types.bool;
            default = true;
            description = "是否在状态栏中显示 Power (F12) 操作提示。";
          };
          showBackground = mkOption {
            type = types.bool;
            default = true;
            description = "是否在状态栏中显示 Background (F4) 切换提示。";
          };
          showSessionStatus = mkOption {
            type = types.bool;
            default = true;
            description = "是否显示当前会话状态。";
          };
          showCapsLock = mkOption {
            type = types.bool;
            default = true;
            description = "是否显示 CapsLock 大写锁定状态。";
          };
        };
      };
    };

    # 4. 记忆与会话保留 (remember)
    remember = {
      username = mkOption {
        type = types.bool;
        default = true;
        description = "是否记住上次成功登录的用户名并自动预填。";
      };

      session = mkOption {
        type = types.bool;
        default = true;
        description = "是否在多次登录之间记住全局上次选择的会话。";
      };

      userSession = mkOption {
        type = types.bool;
        default = false;
        description = "是否为每个用户分别独立记住其上次选择的会话。";
      };
    };

    # 5. 用户选择菜单 (userMenu)
    userMenu = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "是否启用图形化用户选择菜单（通过 NSS 读取系统用户）。";
      };

      minUid = mkOption {
        type = types.int;
        default = 1000;
        description = "用户菜单中列出的最小 UID。";
      };

      maxUid = mkOption {
        type = types.int;
        default = 60000;
        description = "用户菜单中列出的最大 UID。";
      };
    };

    # 6. 密码与隐私模式 (secret)
    secret = {
      mode = mkOption {
        type = types.enum [ "hidden" "characters" ];
        default = "characters";
        description = "密码输入遮罩模式（characters 显示遮罩符号，hidden 完全隐藏）。";
      };

      characters = mkOption {
        type = types.str;
        default = "*";
        description = "用于密码遮罩的符号（如 '*' 或 '●'）。";
      };
    };

    # 7. 快捷键配置 (keybindings)
    keybindings = {
      command = mkOption {
        type = types.int;
        default = 2;
        description = "打开修改启动命令菜单的快捷功能键编号（1-12，对应 F1-F12）。";
      };

      sessions = mkOption {
        type = types.int;
        default = 3;
        description = "打开会话选择列表的快捷功能键编号（1-12，对应 F1-F12）。";
      };

      background = mkOption {
        type = types.int;
        default = 4;
        description = "切换动态背景动画的快捷功能键编号（1-12，对应 F1-F12）。";
      };

      power = mkOption {
        type = types.int;
        default = 12;
        description = "打开电源管理菜单的快捷功能键编号（1-12，对应 F1-F12）。";
      };
    };

    # 8. 动态背景特效 (background)
    background = {
      kind = mkOption {
        type = types.enum [ "none" "doom" "matrix" ];
        default = "none";
        description = "登录界面背景动画特效类型（none 为禁用，doom 为经典火焰，matrix 为黑客帝国数字雨）。";
      };

      fps = mkOption {
        type = types.int;
        default = 30;
        description = "动画背景渲染帧率（FPS）。";
      };

      doom = {
        height = mkOption {
          type = types.int;
          default = 6;
          description = "DOOM 火焰高度与衰减控制（1-9，数值越大火焰越高）。";
        };

        spread = mkOption {
          type = types.int;
          default = 2;
          description = "DOOM 火焰水平抖动幅度（0-4）。";
        };

        topColor = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "#9F2707";
          description = "DOOM 火焰顶部渐变颜色。";
        };

        middleColor = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "#C78F17";
          description = "DOOM 火焰中部渐变颜色。";
        };

        bottomColor = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "#FFFFFF";
          description = "DOOM 火焰底部渐变颜色。";
        };
      };

      matrix = {
        headColor = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "#CCFFCC";
          description = "Matrix 数字雨头部字符颜色。";
        };

        brightColor = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "#33FF66";
          description = "Matrix 数字雨明亮流光颜色。";
        };

        dimColor = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "#006622";
          description = "Matrix 数字雨暗淡流光颜色。";
        };

        minLength = mkOption {
          type = types.nullOr types.int;
          default = null;
          example = 6;
          description = "Matrix 数字雨流最小长度（行数）。";
        };

        maxLength = mkOption {
          type = types.nullOr types.int;
          default = null;
          example = 18;
          description = "Matrix 数字雨流最大长度（行数）。";
        };

        minSpeed = mkOption {
          type = types.nullOr types.float;
          default = null;
          example = 0.30;
          description = "Matrix 数字雨流最小下落速度（行/帧）。";
        };

        maxSpeed = mkOption {
          type = types.nullOr types.float;
          default = null;
          example = 1.10;
          description = "Matrix 数字雨流最大下落速度（行/帧）。";
        };

        mutateChance = mkOption {
          type = types.nullOr types.float;
          default = null;
          example = 0.02;
          description = "Matrix 字符闪烁与突变概率。";
        };
      };
    };

    # 9. 会话包装与环境 (session)
    session = {
      sessionWrapper = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "systemd-cat -t sway";
        description = "非 X11（Wayland）会话的执行包装命令。";
      };

      xsessionWrapper = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "startx /usr/bin/env";
        description = "X11 会话的执行包装命令（默认: startx /usr/bin/env）。";
      };

      environments = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "WAYLAND_DISPLAY" "DISPLAY" ];
        description = "传递给会话的环境变量列表。";
      };
    };

    # 10. 电源管理命令 (power)
    power = {
      useSetsid = mkOption {
        type = types.bool;
        default = true;
        description = "是否使用 setsid 脱离 TTY 执行电源管理命令。";
      };

      shutdownCmd = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "shutdown -h now";
        description = "自定义关机命令。";
      };

      rebootCmd = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "shutdown -r now";
        description = "自定义重启命令。";
      };
    };

    # 11. 主题与配色 (theme)
    theme = mkOption {
      type = types.submodule {
        freeformType = (pkgs.formats.toml { }).type;
        options = {
          border = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "登录容器边框颜色。";
          };
          text = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "基础文本颜色。";
          };
          time = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "日期和时间文本颜色。";
          };
          container = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "登录容器背景颜色。";
          };
          title = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "容器标题颜色。";
          };
          greet = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "问候语文本颜色。";
          };
          prompt = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "输入提示（如 'Username:'）颜色。";
          };
          input = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "用户输入字符反馈颜色。";
          };
          action = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "底部状态栏操作说明文本颜色。";
          };
          button = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "底部状态栏操作按键（F键）高亮颜色。";
          };
        };
      };
      default = { };
      description = "tuigreet UI 组件配色主题方案。";
    };

    # 12. 多显示器与终端尺寸 (outputs / terminal)
    outputs = mkOption {
      type = types.listOf (types.submodule {
        options = {
          connector = mkOption {
            type = types.str;
            example = "DP-1";
            description = "显示器连接器名称（如 DP-1, HDMI-A-1）。";
          };
          primary = mkOption {
            type = types.bool;
            default = false;
            description = "是否将此显示器指定为主输出设备用于调整 TTY 分辨率。";
          };
          enabled = mkOption {
            type = types.bool;
            default = true;
            description = "是否启用该输出设备。";
          };
        };
      });
      default = [ ];
      description = "多显示器 TTY 分辨率与输出配置列表。";
    };

    terminal = {
      cols = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "终端虚拟控制台显式指定的字符列数。";
      };
      rows = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "终端虚拟控制台显式指定的字符行数。";
      };
    };

    # 13. 原生与自定义设置 (settings)
    settings = mkOption {
      type = (pkgs.formats.toml { }).type;
      default = { };
      description = "直接写入 tuigreet config.toml 的自由格式 TOML 配置项。将与上述结构化配置深度合并。";
    };
  };

  config = mkIf cfg.enable {
    # 启用底层 greetd 服务并配置 tuigreet
    services.greetd = {
      enable = true;
      useTextGreeter = true;
      settings = {
        default_session = {
          command = "${getExe cfg.package} --config ${configFile}${optionalString (cfg.extraArgs != [ ]) " ${escapeShellArgs cfg.extraArgs}"}";
          user = cfg.user;
        };
      };
    };

    # 确保 tuigreet 缓存目录存在且权限正确（用于记住用户名及上次会话）
    systemd.tmpfiles.rules = [
      "d /var/cache/tuigreet 0755 ${cfg.user} ${cfg.user} -"
    ];

    # 将生成的 TOML 配置文件同步至 /etc/tuigreet/config.toml
    environment.etc."tuigreet/config.toml".source = configFile;

    # 将 tuigreet 添加至系统环境，便于命令行排查与 --mock 预览
    environment.systemPackages = [
      cfg.package
    ];
  };
}
