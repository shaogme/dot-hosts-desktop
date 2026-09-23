{ config, pkgs, lib, ... }:

let
  defaultTerminal = "rio";
  defaultEditor = "hx";
in
{
  # ==========================================
  # 桌面与图形环境 (Niri & 桌面基础设施与组件)
  # ==========================================
  desktop.windowManager.niri = {
    enable = lib.mkDefault true;
    terminal = lib.mkDefault defaultTerminal;
    editor = {
      enable = lib.mkDefault true;
      command = lib.mkDefault "${defaultTerminal} -e ${defaultEditor}";
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
      terminal = lib.mkDefault defaultTerminal;
      cpu = lib.mkDefault "${defaultTerminal} -e btop";
      memory = lib.mkDefault "${defaultTerminal} -e btop";
      network = lib.mkDefault "${defaultTerminal} -e nmtui";
      netSpeed = lib.mkDefault "${defaultTerminal} -e btop";
      bluetooth = lib.mkDefault "${defaultTerminal} -e bluetuith";
      powerDraw = lib.mkDefault "${defaultTerminal} -e btop";
    };
  };

  desktop.launcher.anyrun = {
    enable = lib.mkDefault true;
    terminal = {
      command = lib.mkDefault defaultTerminal;
      args = lib.mkDefault "-e {}";
    };
  };

  desktop.launcher.fuzzel = {
    enable = lib.mkDefault true;
    terminal = lib.mkDefault "${defaultTerminal} -e";
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
    terminal = lib.mkDefault defaultTerminal;
    editor = lib.mkDefault defaultEditor;
    videoPlayer = lib.mkDefault "mpv";
    terminalKeybind = {
      enable = lib.mkDefault true;
      command = lib.mkDefault defaultTerminal;
    };
  };

  # 文本编辑器 (Helix)
  desktop.editor.helix = {
    enable = lib.mkDefault true;
    terminal = lib.mkDefault defaultTerminal;
  };

  # 视频播放器 (MPV)
  desktop.videoPlayer.mpv = {
    enable = lib.mkDefault true;
  };

  desktop.portal.termfilechooser = {
    enable = lib.mkDefault true;
    terminal = lib.mkDefault defaultTerminal;
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
}
