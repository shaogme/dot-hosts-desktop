{ config, pkgs, lib, ... }:

let
  defaultTerminal = "rio";
  defaultTerminalExecutable = lib.getExe config.desktop.terminal.${defaultTerminal}.package;
  defaultEditor = "hx";
in
{
  # ==========================================
  # 桌面与图形环境 (Niri & 桌面基础设施与组件)
  # ==========================================
  desktop.windowManager.niri = {
    enable = lib.mkDefault true;
    terminal = lib.mkDefault defaultTerminalExecutable;
    editor = {
      enable = lib.mkDefault true;
      command = lib.mkDefault "${defaultTerminalExecutable} -e ${defaultEditor}";
    };
    clipboard = {
      enable = lib.mkDefault true;
      command = lib.mkDefault "cliphist-pick";
      keybind = lib.mkDefault "Ctrl+grave";
    };
  };

  desktop.audio.pipewire = {
    enable = lib.mkDefault true;
  };

  desktop.bar.waybar = {
    enable = lib.mkDefault true;
    commands = {
      menu = lib.mkDefault config.desktop.launcher.anyrun.integration.menuCommand;
      terminal = lib.mkDefault defaultTerminalExecutable;
      cpu = lib.mkDefault "${defaultTerminalExecutable} -e btop";
      memory = lib.mkDefault "${defaultTerminalExecutable} -e btop";
      network = lib.mkDefault "${defaultTerminalExecutable} -e nmtui";
      netSpeed = lib.mkDefault "${defaultTerminalExecutable} -e btop";
      bluetooth = lib.mkDefault "${defaultTerminalExecutable} -e bluetuith";
      audioControl = lib.mkDefault (lib.getExe pkgs.pavucontrol);
      audioMuteToggle = lib.mkDefault "${lib.getExe pkgs.pamixer} -t";
      powerMenu = lib.mkDefault config.desktop.launcher.anyrun.integration.powerMenuCommand;
      powerDraw = lib.mkDefault "${defaultTerminalExecutable} -e btop";
    };
  };

  desktop.launcher.anyrun = {
    enable = lib.mkDefault true;
    terminal = {
      command = lib.mkDefault defaultTerminalExecutable;
      desktopId = lib.mkDefault "${defaultTerminal}.desktop";
      args = lib.mkDefault "-e {}";
    };
  };

  desktop.launcher.fuzzel = {
    enable = lib.mkDefault true;
    terminal = lib.mkDefault "${defaultTerminalExecutable} -e";
    font = {
      family = lib.mkDefault "monospace";
      size = lib.mkDefault 11;
    };
    layout = {
      width = lib.mkDefault 45;
      lines = lib.mkDefault 15;
      prompt = lib.mkDefault " ❯ ";
    };
    search.matchMode = lib.mkDefault "fzf";
    wrappers = {
      powerMenu.enable = lib.mkDefault true;
      windowSwitch.enable = lib.mkDefault true;
      dmenuWrapper.enable = lib.mkDefault true;
    };
  };

  desktop.clipboard.cliphist = {
    enable = lib.mkDefault true;
    storage = {
      text.enable = lib.mkDefault true;
      images.enable = lib.mkDefault true;
      maxItems = lib.mkDefault 1000;
    };
    selector = {
      command = lib.mkDefault "fuzzel-dmenu --with-nth 2";
      previewThumbnails = lib.mkDefault true;
    };
  };

  # 文件管理器与桌面门户 (Yazi & termfilechooser)
  desktop.fileManager.yazi = {
    enable = lib.mkDefault true;
    terminal = lib.mkDefault defaultTerminalExecutable;
    editor = lib.mkDefault defaultEditor;
    videoPlayer = lib.mkDefault "mpv";
    terminalKeybind = {
      enable = lib.mkDefault true;
      command = lib.mkDefault defaultTerminalExecutable;
    };
  };

  # 文本编辑器 (Helix)
  desktop.editor.helix = {
    enable = lib.mkDefault true;
    terminal = lib.mkDefault defaultTerminalExecutable;
  };

  # 视频播放器 (MPV)
  desktop.videoPlayer.mpv = {
    enable = lib.mkDefault true;
  };

  desktop.portal.termfilechooser = {
    enable = lib.mkDefault true;
    terminal = lib.mkDefault defaultTerminalExecutable;
    env = {
      EDITOR = lib.mkDefault defaultEditor;
    };
  };

  desktop.notification.swaync = {
    enable = lib.mkDefault true;
  };

  desktop.theme = {
    enable = lib.mkDefault true;
  };

  desktop.wallpaper.awww = {
    enable = lib.mkDefault true;
    wallpaper = lib.mkDefault config.desktop.wallpaper.wallpapers.defaultWallpaper;
  };

  # 登录管理器 (tuigreet)
  desktop.loginManager.tuigreet = {
    enable = lib.mkDefault true;
    defaultSession = lib.mkDefault "niri";
    display = {
      showTime = lib.mkDefault true;
    };
    remember = {
      username = lib.mkDefault true;
      session = lib.mkDefault true;
    };
  };

  # Swaylock 通过 Niri 的 Wayland session-lock 支持锁定桌面；systemd-lock-handler
  # 将启动器中的 loginctl lock-session 请求转发给该锁屏服务。
  desktop.loginManager.swaylock.enable = lib.mkDefault true;
}
