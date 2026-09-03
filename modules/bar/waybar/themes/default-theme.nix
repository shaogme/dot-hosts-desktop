{
  pkgs,
  lib,
  config,
  ...
}:

with lib;

let
  cfg = config.desktop.bar.waybar;
  paletteLib = import ../../../theme/palette.nix { inherit lib; };
  # 优先使用用户通过 desktop.theme.palette 配置的调色板，回退至 palette.nix 默认
  paletteDark = (config.desktop.theme.palette.dark or paletteLib.palettes.dark);
  fallbackCss = paletteLib.toCss paletteDark;
  netSpeedCfg = cfg.netSpeed or {
    enable = true;
    mode = "custom";
    interval = 1;
  };

  waybarNetSpeedScript = pkgs.writeShellScriptBin "waybar-netspeed" ''
    set -u

    INTERVAL="''${INTERVAL:-${toString netSpeedCfg.interval}}"

    format_bytes() {
      local b=$1
      if (( b < 1024 )); then
        printf "%4d.0 B/s" "$b"
      elif (( b < 1048576 )); then
        local kb_x10=$(( b * 10 / 1024 ))
        printf "%3d.%d KB/s" "$(( kb_x10 / 10 ))" "$(( kb_x10 % 10 ))"
      elif (( b < 1073741824 )); then
        local mb_x10=$(( b * 10 / 1048576 ))
        printf "%3d.%d MB/s" "$(( mb_x10 / 10 ))" "$(( mb_x10 % 10 ))"
      else
        local gb_x10=$(( b * 10 / 1073741824 ))
        printf "%3d.%d GB/s" "$(( gb_x10 / 10 ))" "$(( gb_x10 % 10 ))"
      fi
    }

    declare -A prev_rx prev_tx

    # 首次采样初始化网卡计数
    while IFS=': ' read -r iface r_bytes r_pkts r_errs r_drop r_fifo r_frame r_comp r_mcast t_bytes t_pkts t_errs t_drop t_fifo t_colls t_carrier t_comp rest; do
      [[ "$iface" =~ ^(Inter-\||face|lo|docker.*|veth.*|br-.*|virbr.*)$ ]] && continue
      [[ -z "$iface" || -z "$r_bytes" || -z "$t_bytes" ]] && continue
      prev_rx["$iface"]=$r_bytes
      prev_tx["$iface"]=$t_bytes
    done < /proc/net/dev

    # 初始默认输出
    down_zero=$(format_bytes 0)
    up_zero=$(format_bytes 0)
    init_text="<span size='7000' foreground='#a6e3a1'>⇣ $down_zero</span>"$'\n'"<span size='7000' foreground='#89b4fa'>⇡ $up_zero</span>"
    ${pkgs.jq}/bin/jq -nc \
      --arg text "$init_text" \
      --arg tooltip "实时网速监控正在初始化..." \
      --arg class "custom-netspeed" \
      '{ text: $text, tooltip: $tooltip, class: $class }'

    # 持续流式监控输出
    while true; do
      sleep "$INTERVAL"

      total_rx_rate=0
      total_tx_rate=0
      details=""

      while IFS=': ' read -r iface r_bytes r_pkts r_errs r_drop r_fifo r_frame r_comp r_mcast t_bytes t_pkts t_errs t_drop t_fifo t_colls t_carrier t_comp rest; do
        [[ "$iface" =~ ^(Inter-\||face|lo|docker.*|veth.*|br-.*|virbr.*)$ ]] && continue
        [[ -z "$iface" || -z "$r_bytes" || -z "$t_bytes" ]] && continue

        prx="''${prev_rx["$iface"]:-$r_bytes}"
        ptx="''${prev_tx["$iface"]:-$t_bytes}"

        prev_rx["$iface"]=$r_bytes
        prev_tx["$iface"]=$t_bytes

        drx=$(( (r_bytes - prx) / INTERVAL ))
        dtx=$(( (t_bytes - ptx) / INTERVAL ))
        (( drx < 0 )) && drx=0
        (( dtx < 0 )) && dtx=0

        total_rx_rate=$(( total_rx_rate + drx ))
        total_tx_rate=$(( total_tx_rate + dtx ))

        rx_fmt=$(format_bytes "$drx")
        tx_fmt=$(format_bytes "$dtx")
        details+="• $iface:  ⇣ $rx_fmt   ⇡ $tx_fmt"$'\n'
      done < /proc/net/dev

      down_str=$(format_bytes "$total_rx_rate")
      up_str=$(format_bytes "$total_tx_rate")

      text="<span size='7000' foreground='#a6e3a1'>⇣ $down_str</span>"$'\n'"<span size='7000' foreground='#89b4fa'>⇡ $up_str</span>"
      tooltip="<b>网络实时上下行速率</b>"$'\n\n'"总下行: <b>$down_str</b>"$'\n'"总上行: <b>$up_str</b>"$'\n\n'"<b>活动网卡明细:</b>"$'\n'"$details"

      ${pkgs.jq}/bin/jq -nc \
        --arg text "$text" \
        --arg tooltip "$tooltip" \
        --arg class "custom-netspeed" \
        '{ text: $text, tooltip: $tooltip, class: $class }'
    done
  '';

  waybarClockScript = pkgs.writeShellScriptBin "waybar-clock" ''
    time=$(date +"%I:%M %p")
    date_str=$(date +"%A, %d/%m")
    tooltip=$(date +"%Y年%m月%d日 %A")
    ${pkgs.jq}/bin/jq -nc \
      --arg text "$time"$'\n'"$date_str" \
      --arg tooltip "$tooltip" \
      '{ text: $text, tooltip: $tooltip }'
  '';

  waybarGamemodeStatusScript = pkgs.writeShellScriptBin "waybar-gamemode-status" ''
    CACHE_FILE="''${XDG_CACHE_HOME:-$HOME/.cache}/niri_gamemode"
    if [ -f "$CACHE_FILE" ]; then
      echo '{"text":"","class":"active","tooltip":"游戏模式：已开启（动画与阴影已通过备选配置禁用）"}'
    else
      echo '{"text":"","class":"inactive","tooltip":"游戏模式：已关闭（点击开启）"}'
    fi
  '';

  waybarGamemodeToggleScript = pkgs.writeShellScriptBin "waybar-gamemode-toggle" ''
    set -u
    CACHE_FILE="''${XDG_CACHE_HOME:-$HOME/.cache}/niri_gamemode"
    CONFIG_DIR="''${XDG_CONFIG_HOME:-$HOME/.config}/niri"

    if [ ! -f "$CONFIG_DIR/config.kdl" ]; then
      CONFIG_DIR="/etc/xdg/niri"
    fi

    if [ -f "$CACHE_FILE" ]; then
      rm -f "$CACHE_FILE"
      ${pkgs.niri}/bin/niri msg action load-config-file --path "$CONFIG_DIR/config.kdl" >/dev/null 2>&1 || true
    else
      mkdir -p "$(dirname "$CACHE_FILE")"
      touch "$CACHE_FILE"
      ${pkgs.niri}/bin/niri msg action load-config-file --path "$CONFIG_DIR/config-gamemode.kdl" >/dev/null 2>&1 || true
    fi
    ${pkgs.procps}/bin/pkill -SIGRTMIN+8 waybar 2>/dev/null || true
  '';

  waybarMediaScript = pkgs.writeShellScriptBin "waybar-media" ''
    if ! command -v ${pkgs.playerctl}/bin/playerctl >/dev/null 2>&1; then
      echo '{"text":" No media","tooltip":"未找到 playerctl"}'
      exit 0
    fi

    status=$(${pkgs.playerctl}/bin/playerctl status 2>/dev/null || echo "Stopped")
    if [ "$status" = "Stopped" ] || [ -z "$status" ]; then
      echo '{"text":" No media","tooltip":"暂无正在播放的媒体"}'
      exit 0
    fi

    title=$(${pkgs.playerctl}/bin/playerctl metadata --format '{{title}}' 2>/dev/null || echo "")
    artist=$(${pkgs.playerctl}/bin/playerctl metadata --format '{{artist}}' 2>/dev/null || echo "")

    if [ -z "$title" ]; then
      echo '{"text":" No media","tooltip":"暂无正在播放的媒体"}'
      exit 0
    fi

    display_title="$title"
    if (( ''${#display_title} > 20 )); then
      display_title="''${display_title:0:17}..."
    fi

    icon=""
    if [ "$status" = "Playing" ]; then
      icon="󰎈"
    elif [ "$status" = "Paused" ]; then
      icon="󰏤"
    fi

    text="$icon $display_title"
    tooltip="媒体：$title"
    if [ -n "$artist" ]; then
      tooltip="$tooltip ($artist)"
    fi
    tooltip="$tooltip\n状态：$status\n• 左键：播放/暂停\n• 右键：下一曲\n• 中键：上一曲"

    ${pkgs.jq}/bin/jq -nc \
      --arg text "$text" \
      --arg tooltip "$tooltip" \
      --arg class "$status" \
      '{ text: $text, tooltip: $tooltip, class: $class }'
  '';

  settings = {
    reload_style_on_change = true;
    layer = "top";
    position = cfg.position;
    spacing = 0;
    height = 42;
    margin-top = 4;
    margin-left = 10;
    margin-right = 10;
    modules-left = [ ];
    modules-center = [
      "group/center4"
      "group/center3"
      "niri/workspaces"
      "group/center2"
    ];
    modules-right = [ ];

    "group/center4" = {
      orientation = "inherit";
      modules = [
        "custom/menu"
        "niri/window"
        "custom/separator#blank"
        "custom/separator#dot"
        "tray"
        "network"
      ]
      ++ optional (netSpeedCfg.enable && netSpeedCfg.mode == "custom") "custom/netspeed"
      ++ [
        "bluetooth"
      ];
    };

    "group/center3" = {
      orientation = "inherit";
      modules = [
        "custom/separator#blank"
        "custom/gamemode"
        "custom/notification"
        "custom/wallpaper"
        "custom/media"
      ];
    };

    "niri/workspaces" = {
      format = "{icon}";
      format-icons = {
        default = "";
        "1" = "<span size='13500'>󰲠</span>";
        "2" = "<span size='13500'>󰲢</span>";
        "3" = "<span size='13500'>󰲤</span>";
        "4" = "<span size='13500'>󰲦</span>";
        "5" = "<span size='13500'>󰲨</span>";
        "6" = "<span size='13500'>󰲪</span>";
        "7" = "<span size='13500'>󰲬</span>";
        "8" = "<span size='13500'>󰲮</span>";
        "9" = "<span size='13500'>󰲰</span>";
        "10" = "<span size='13500'>󰿬</span>";
      };
    };

    "group/center2" = {
      orientation = "inherit";
      modules = [
        "custom/clock"
        "pulseaudio"
        "battery"
        "cpu"
        "memory"
        "custom/power"
      ];
    };

    "custom/menu" = {
      format = "<span size='11500'></span>";
      tooltip = true;
      tooltip-format = "应用启动器 (Anyrun)\n• 左键：搜索并启动应用\n• 右键：打开终端";
      on-click = cfg.commands.menu;
      on-click-right = cfg.commands.terminal;
    };

    "niri/window" = {
      format = "{title}";
      rewrite = {
        "(.*) - Mozilla Firefox" = "🌎 $1";
        "(.*) - Visual Studio Code" = "󰨞 $1";
        "(.*) - Discord" = "󰙯 $1";
      };
      separate-outputs = true;
      icon = true;
      icon-size = 14;
      max-length = 30;
    };

    "custom/gamemode" = {
      exec = "${waybarGamemodeStatusScript}/bin/waybar-gamemode-status";
      on-click = "${waybarGamemodeToggleScript}/bin/waybar-gamemode-toggle";
      signal = 8;
      interval = 2;
      return-type = "json";
      tooltip = true;
    };

    "custom/notification" = {
      tooltip = false;
      format = "{icon}";
      format-icons = {
        notification = "<span foreground='#f38ba8'><sup></sup></span>";
        none = "";
        dnd-notification = "<span foreground='#f38ba8'><sup></sup></span>";
        dnd-none = "";
        inhibited-notification = "<span foreground='#f38ba8'><sup></sup></span>";
        inhibited-none = "";
        dnd-inhibited-notification = "<span foreground='#f38ba8'><sup></sup></span>";
        dnd-inhibited-none = "";
      };
      return-type = "json";
      exec-if = "which swaync-client";
      exec = "swaync-client -df -p";
      on-click = "swaync-client -t -sw";
      on-click-right = "swaync-client -d -sw";
      escape = true;
    };

    "custom/wallpaper" = {
      format = "󰸉";
      tooltip = true;
      tooltip-format = "桌面壁纸管理\n• 左键：随机换壁纸\n• 右键：选择壁纸\n• 中键：恢复上次壁纸";
      on-click = "awww-random";
      on-click-right = "awww-switch";
      on-click-middle = "awww-restore";
    };

    "custom/media" = {
      exec = "${waybarMediaScript}/bin/waybar-media";
      interval = 2;
      return-type = "json";
      on-click = "${pkgs.playerctl}/bin/playerctl play-pause";
      on-click-right = "${pkgs.playerctl}/bin/playerctl next";
      on-click-middle = "${pkgs.playerctl}/bin/playerctl previous";
      tooltip = true;
    };

    "custom/clock" = {
      exec = "${waybarClockScript}/bin/waybar-clock";
      interval = 1;
      return-type = "json";
      tooltip = true;
    };

    cpu = {
      interval = 2;
      format = "{icon} {usage}%";
      format-icons = [ "󰪞" "󰪟" "󰪠" "󰪡" "󰪢" "󰪣" "󰪤" "󰪥" ];
      tooltip = true;
      tooltip-format = "CPU 使用率: {usage}%";
      on-click = cfg.commands.cpu;
    };

    memory = {
      interval = 2;
      format = "{icon} {percentage}%";
      format-icons = [ "󰪞" "󰪟" "󰪠" "󰪡" "󰪢" "󰪣" "󰪤" "󰪥" ];
      tooltip = true;
      tooltip-format = "内存使用率: {percentage}% ({used:0.1f}G/{total:0.1f}G)";
      on-click = cfg.commands.memory;
    };

    network = {
      interval = if (netSpeedCfg.enable && netSpeedCfg.mode == "native") then netSpeedCfg.interval else 3;
      format = if (netSpeedCfg.enable && netSpeedCfg.mode == "native")
        then "{icon} <span size='7000' foreground='#a6e3a1'>⇣{bandwidthDownBytes}</span> <span size='7000' foreground='#89b4fa'>⇡{bandwidthUpBytes}</span>"
        else "{icon}";
      format-wifi = if (netSpeedCfg.enable && netSpeedCfg.mode == "native")
        then "{icon} <span size='7000' foreground='#a6e3a1'>⇣{bandwidthDownBytes}</span> <span size='7000' foreground='#89b4fa'>⇡{bandwidthUpBytes}</span>"
        else "{icon}";
      format-ethernet = if (netSpeedCfg.enable && netSpeedCfg.mode == "native")
        then "<span size='11500'>󰌘</span> <span size='7000' foreground='#a6e3a1'>⇣{bandwidthDownBytes}</span> <span size='7000' foreground='#89b4fa'>⇡{bandwidthUpBytes}</span>"
        else "<span size='11500'>󰌘</span>";
      format-disconnected = "<span size='11500' foreground='#f38ba8'>󰤮</span>";
      format-icons = [ "󰤯" "󰤟" "󰤢" "󰤥" "󰤨" ];
      tooltip-format-wifi = "Wi-Fi: {essid} ({signalStrength}%)\n⇣{bandwidthDownBytes}  ⇡{bandwidthUpBytes}";
      tooltip-format-ethernet = "以太网: {ipaddr}/{cidr}\n⇣{bandwidthDownBytes}  ⇡{bandwidthUpBytes}";
      tooltip-format-disconnected = "网络已断开";
      on-click = cfg.commands.network;
    };

    bluetooth = {
      format = "<span size='11500'>󰂯</span>";
      format-disabled = "<span size='11500' foreground='#6c7086'>󰂲</span>";
      format-connected = "<span size='11500' foreground='#89b4fa'></span>";
      format-no-controller = "";
      tooltip-format = "蓝牙设备已连接: {num_connections}";
      tooltip-format-disabled = "蓝牙已关闭";
      on-click = cfg.commands.bluetooth;
    };

    pulseaudio = {
      format = "{icon} {volume}%";
      format-muted = "<span foreground='#6c7086'></span>";
      format-icons = {
        default = [ "" "" "" ];
      };
      tooltip-format = "音量: {volume}%";
      scroll-step = 5;
      on-click = cfg.commands.audioControl;
      on-click-right = cfg.commands.audioMuteToggle;
    };

    battery = {
      states = {
        warning = 30;
        critical = 15;
      };
      format = "{capacity}% {icon}";
      format-discharging = "{capacity}% {icon}";
      format-charging = "{capacity}% 󰂄";
      format-plugged = "{capacity}% ";
      format-full = "100% 󰂅";
      format-icons = [ "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹" ];
      tooltip-format = "{timeTo}, 功率: {power:>1.0f}W";
      interval = 5;
      on-click = cfg.commands.powerMenu;
    };

    tray = {
      icon-size = 16;
      spacing = 8;
    };

    "custom/separator#blank" = {
      format = " ";
      interval = "once";
      tooltip = false;
    };

    "custom/separator#dot" = {
      format = " ";
      interval = "once";
      tooltip = false;
    };

    "custom/power" = {
      format = "";
      tooltip = false;
      on-click = cfg.commands.powerMenu;
    };
  } // optionalAttrs (netSpeedCfg.enable && netSpeedCfg.mode == "custom") {
    "custom/netspeed" = {
      exec = "${waybarNetSpeedScript}/bin/waybar-netspeed";
      return-type = "json";
      restart-interval = 3;
      on-click = cfg.commands.netSpeed;
      tooltip = true;
    };
  };

  style = ''
    /* 统一调色板 fallback (palette.dark)：由 modules/theme/palette.nix 提供 */
    ${fallbackCss}
    /* 动态覆盖：由 desktop.theme 在 $XDG_RUNTIME_DIR/desktop-theme/colors.css 及 $XDG_CONFIG_HOME/waybar/colors.css 生成，Waybar SIGUSR2 热重载 */
    /* 若 colors.css 存在则覆盖上方 fallback；缺失则静默回退 */
    @import "colors.css";

    * {
      border: none;
      border-radius: 0;
      min-height: 0;
      font-family: "Geist", "TsangerJinKai04", "Maple Mono NF CN", "Symbols Nerd Font", sans-serif;
      font-size: 13px;
    }

    window#waybar {
      background-color: transparent;
      transition-property: background-color;
      transition-duration: .5s;
    }

    window#waybar.empty #window {
      background: transparent;
      background-color: transparent;
      border: none;
      border-radius: 0;
      color: transparent;
      padding: 0;
      margin: 0;
    }

    #waybar.empty .modules-center {
      opacity: 0;
    }

    /* 居中胶囊岛风格分组容器 (Pills) */
    #group-center4,
    #group_center4,
    #center4,
    #group-center3,
    #group_center3,
    #center3,
    #group-center2,
    #group_center2,
    #center2,
    #workspaces {
      background-color: @background;
      border: 1px solid @border-color;
      border-radius: 14px;
      padding: 0 8px;
      margin: 4px 3px;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.35);
      color: @foreground;
    }

    /* 工作区指示器 */
    #workspaces {
      padding: 0 6px;
    }

    #workspaces button {
      color: @foreground;
      padding: 0 4px;
      margin: 0 1px;
      min-width: 14px;
      border-radius: 8px;
      transition: all 0.2s ease-in-out;
    }

    #workspaces button.empty {
      color: @foreground;
      opacity: 0.45;
    }

    #workspaces button.active {
      transition: all 120ms ease-out;
      border-top: 2px solid @active-border;
      background-color: rgba(137, 180, 250, 0.15);
      color: #ffffff;
      opacity: 1;
    }

    #workspaces button:hover {
      background-color: @hover-bg;
      opacity: 1;
    }

    /* 活动窗口组件 (紧凑卡片) */
    #window,
    #custom-active_window {
      padding: 2px 8px;
      margin-top: 2px;
      margin-bottom: 2px;
      border-radius: 10px;
      background: rgba(255, 255, 255, 0.05);
      font-size: 12px;
    }

    /* 实时网速组件 (双行紧凑卡片) */
    #custom-netspeed {
      padding: 2px 6px;
      margin-top: 2px;
      margin-bottom: 2px;
      border-radius: 8px;
      background: rgba(255, 255, 255, 0.04);
      font-size: 10px;
      font-family: "Maple Mono NF CN", "Geist", monospace;
    }

    /* 时钟组件 (双行排版) */
    #custom-clock {
      margin-left: 4px;
      margin-right: 6px;
      font-weight: 700;
      font-size: 11px;
    }

    /* 启动器图标 */
    #custom-menu {
      margin-left: 4px;
      margin-right: 6px;
      font-size: 14px;
      color: #89b4fa;
    }

    #custom-menu:hover {
      color: #b4befe;
    }

    /* 系统托盘 */
    #tray {
      background: transparent;
      padding: 0 4px;
      margin: 0 2px;
    }

    #tray > .passive {
      -gtk-icon-effect: dim;
    }

    #tray > .needs-attention {
      -gtk-icon-effect: highlight;
      background-color: @critical;
    }

    /* 基础功能模块通用样式 */
    #network,
    #custom-netspeed,
    #bluetooth,
    #pulseaudio,
    #custom-gamemode,
    #custom-notification,
    #custom-wallpaper,
    #custom-media,
    #cpu,
    #memory,
    #battery,
    #custom-power {
      padding: 0 5px;
      margin: 0 1px;
      color: @foreground;
      transition: all 0.2s ease;
    }

    #custom-gamemode.active {
      color: @critical;
      font-weight: bold;
    }

    #custom-wallpaper {
      color: #cba6f7;
    }

    #custom-wallpaper:hover {
      color: #f5c2e7;
    }

    #custom-notification {
      font-size: 13px;
    }

    #custom-notification:hover {
      color: #89b4fa;
    }

    #cpu, #memory {
      font-size: 12px;
    }

    #battery.warning {
      color: @warning;
    }

    #battery.critical {
      color: @critical;
      animation-name: blink;
      animation-duration: 0.8s;
      animation-timing-function: linear;
      animation-iteration-count: infinite;
      animation-direction: alternate;
    }

    @keyframes blink {
      to {
        color: #ffffff;
        background-color: @critical;
      }
    }

    #custom-power {
      color: @critical;
      font-size: 14px;
      font-weight: bold;
      margin-right: 2px;
    }

    #custom-power:hover {
      color: #ff7777;
      background-color: rgba(243, 139, 168, 0.2);
      border-radius: 6px;
    }

    tooltip {
      background: @background-card;
      border: 1px solid @border-color;
      border-radius: 10px;
      box-shadow: 0 4px 16px rgba(0, 0, 0, 0.4);
    }

    tooltip label {
      color: @foreground;
      padding: 4px;
    }
  '';
in
{
  inherit settings style;
  extraPackages = [
    waybarClockScript
    waybarGamemodeStatusScript
    waybarGamemodeToggleScript
    waybarMediaScript
    pkgs.playerctl
    pkgs.jq
    pkgs.pamixer
    pkgs.pavucontrol
  ] ++ optional (netSpeedCfg.enable && netSpeedCfg.mode == "custom") waybarNetSpeedScript;
}
