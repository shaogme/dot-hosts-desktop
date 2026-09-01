{ pkgs, lib ? pkgs.lib, ... }:

let
  sources = import ./npins;

  # 从 npins 锁定源获取官方发布包
  unpacked = sources.firefox;

  # 从 sources.json 中的 URL 提取版本号
  version =
    let
      match = builtins.match ".*/releases/([^/]+)/.*" sources.firefox.url;
    in
    if match != null then builtins.head match else "latest";

  # Bubblewrap + FHS 隔离运行环境
  fhs = pkgs.buildFHSEnv {
    name = "firefox-fhs";

    targetPkgs = pkgs: with pkgs; [
      # 核心 C 运行时与系统库
      glibc
      gcc.cc.lib
      zlib
      bzip2
      xz
      dbus
      dbus-glib

      # GTK3 与桌面环境组件
      gtk3
      glib
      cairo
      pango
      atk
      gdk-pixbuf
      libayatana-appindicator

      # X11 与 Wayland 显示支持
      libxkbcommon
      wayland
      libx11
      libxcomposite
      libxdamage
      libxext
      libxfixes
      libxrandr
      libxrender
      libxtst
      libxcb
      libxi
      libxcursor
      libICE
      libSM

      # 音频支持 (PipeWire & ALSA & PulseAudio)
      pipewire
      alsa-lib
      libpulseaudio

      # 图形加速、DRI 与 GPU 硬件解码
      libGL
      libGLU
      mesa
      libva
      libdrm
      vulkan-loader
      pciutils

      # 字体匹配与渲染引擎
      fontconfig
      freetype
      harfbuzz

      # 媒体编解码支持
      ffmpeg
      libvpx
      libevent

      # 安全与网络组件
      openssl
      nss
      nspr
      curl
      krb5
      cups
    ];

    extraBwrapArgs = [
      # 1. 核心安全隔离：屏蔽宿主机真实家目录，阻止访问宿主机隐私文件 (~/.ssh, ~/.gnupg 等)
      "--tmpfs" "$HOME"

      # 2. 独立沙箱持久化：将专属沙箱持久化目录挂载为容器内部的 $HOME
      "--bind" "\${XDG_DATA_HOME:-$HOME/.local/share}/sandboxes/firefox" "$HOME"

      # 3. 基础通道穿透：图形显示（Wayland / X11）
      "--ro-bind-try" "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"
      "--ro-bind-try" "$XDG_RUNTIME_DIR/wayland-0" "$XDG_RUNTIME_DIR/wayland-0"
      "--ro-bind-try" "/tmp/.X11-unix" "/tmp/.X11-unix"

      # 4. 音频通道穿透 (PipeWire & PulseAudio)
      "--ro-bind-try" "$XDG_RUNTIME_DIR/pulse" "$XDG_RUNTIME_DIR/pulse"
      "--ro-bind-try" "$XDG_RUNTIME_DIR/pipewire-0" "$XDG_RUNTIME_DIR/pipewire-0"

      # 5. D-Bus 进程间通信（用于桌面通知、XDG Desktop Portal 等）
      "--ro-bind-try" "$XDG_RUNTIME_DIR/bus" "$XDG_RUNTIME_DIR/bus"
      "--ro-bind-try" "$XDG_RUNTIME_DIR/dconf" "$XDG_RUNTIME_DIR/dconf"

      # 6. 网络命名空间共享：允许网络连接
      "--share-net"
    ];

    runScript = pkgs.writeShellScript "firefox-launcher" ''
      # 适配 Wayland 桌面环境
      if [ -n "$WAYLAND_DISPLAY" ]; then
        export MOZ_ENABLE_WAYLAND=1
        export GDK_BACKEND=wayland,x11
      fi

      # 确保沙箱内部基础目录结构存在
      mkdir -p "$HOME/Downloads" "$HOME/.mozilla"

      # 启动 Firefox 主程序
      exec ${unpacked}/firefox "$@"
    '';
  };

  # 宿主机包装脚本：提前创建独立的持久化沙箱目录，然后启动隔离容器
  wrapper = pkgs.writeShellScriptBin "firefox" ''
    SANDBOX_HOME="''${XDG_DATA_HOME:-$HOME/.local/share}/sandboxes/firefox"
    mkdir -p "$SANDBOX_HOME/Downloads" "$SANDBOX_HOME/.mozilla"

    exec ${fhs}/bin/firefox-fhs "$@"
  '';

  # 生成标准 XDG Desktop 快捷方式
  desktopItem = pkgs.makeDesktopItem {
    name = "firefox";
    desktopName = "Firefox";
    genericName = "Web Browser";
    comment = "Mozilla Firefox Web Browser (Bubblewrap Isolated)";
    exec = "firefox %U";
    icon = "firefox";
    terminal = false;
    type = "Application";
    categories = [ "Network" "WebBrowser" ];
    mimeTypes = [
      "text/html"
      "text/xml"
      "application/xhtml+xml"
      "application/vnd.mozilla.xul+xml"
      "x-scheme-handler/http"
      "x-scheme-handler/https"
      "x-scheme-handler/ftp"
    ];
  };
in
pkgs.symlinkJoin {
  name = "firefox-${version}";
  paths = [
    wrapper
    desktopItem
  ];
  postBuild = ''
    # 安装不同分辨率的桌面图标至标准 hicolor 路径
    for size in 16 32 48 64 128; do
      icon_file="${unpacked}/browser/chrome/icons/default/default''${size}.png"
      if [ -f "$icon_file" ]; then
        mkdir -p "$out/share/icons/hicolor/''${size}x''${size}/apps"
        cp "$icon_file" "$out/share/icons/hicolor/''${size}x''${size}/apps/firefox.png"
      fi
    done
  '';
}
