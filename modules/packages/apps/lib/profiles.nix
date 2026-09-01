{ pkgs, lib }:

rec {
  # =========================================================================
  # 1. 运行时依赖包集 Profile
  # =========================================================================
  pkgProfiles = {
    # 基础 C 运行时与核心库
    base = pkgs: with pkgs; [
      glibc
      gcc.cc.lib
      zlib
      bzip2
      xz
      dbus
      openssl
    ];

    # X11 显示协议支持
    x11 = pkgs: with pkgs; [
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
    ];

    # Wayland 显示协议支持
    wayland = pkgs: with pkgs; [
      wayland
      libxkbcommon
    ];

    # GPU 图形加速与硬件解码
    graphics = pkgs: with pkgs; [
      libGL
      libGLU
      mesa
      libva
      libdrm
      vulkan-loader
      pciutils
    ];

    # 音频服务支持 (PipeWire, ALSA, PulseAudio)
    audio = pkgs: with pkgs; [
      pipewire
      alsa-lib
      libpulseaudio
    ];

    # 字体与文本排版引擎
    fonts = pkgs: with pkgs; [
      fontconfig
      freetype
      harfbuzz
    ];

    # GTK3 桌面组件集与系统托盘
    gtk3 = pkgs: with pkgs; [
      gtk3
      glib
      cairo
      pango
      atk
      gdk-pixbuf
      libayatana-appindicator
      libappindicator-gtk3
    ];

    # WebKitGTK 浏览器内核 (如 Clash Verge Rev)
    webkitgtk = pkgs: with pkgs; [
      webkitgtk_4_1
      libsoup_3
    ];

    # .NET CoreCLR / Avalonia UI 运行时支持 (如 v2rayN)
    dotnet = pkgs: with pkgs; [
      icu
      sqlite
    ];

    # 多媒体与高级网络安全组件 (如 Firefox)
    media = pkgs: with pkgs; [
      ffmpeg
      libvpx
      libevent
      nss
      nspr
      curl
      krb5
      cups
    ];

    # Electron / Chromium 基础运行环境 (如 Linux QQ, VSCode, Slack 等)
    electron = pkgs: with pkgs; [
      at-spi2-core
      cups
      expat
      libsecret
      libnotify
      nspr
      nss
      systemdLibs
    ];

    # XCB / Qt 附加图形环境 (如 WeChat Universal 等)
    xcb = pkgs: with pkgs; [
      xorg.libxcb
      xorg.xcbutil
      xorg.xcbutilimage
      xorg.xcbutilkeysyms
      xorg.xcbutilrenderutil
      xorg.xcbutilwm
      xorg.xcbutilcursor
      xorg.xcbutilerrors
    ];

    # 桌面 GUI 应用元 Profile (常用 GUI 应用的基础集合)
    desktop-gui = pkgs:
      pkgProfiles.base pkgs
      ++ pkgProfiles.x11 pkgs
      ++ pkgProfiles.wayland pkgs
      ++ pkgProfiles.graphics pkgs
      ++ pkgProfiles.audio pkgs
      ++ pkgProfiles.fonts pkgs
      ++ pkgProfiles.gtk3 pkgs;
  };

  # =========================================================================
  # 2. Bubblewrap 隔离规则参数生成器
  # =========================================================================
  makeBwrapArgs = {
    sandboxName,
    isolatedHome ? true,
    shareNet ? true,
    wayland ? true,
    x11 ? true,
    audio ? true,
    dbus ? true,
    customBinds ? [],
    customRoBinds ? [],
    extraBwrapArgs ? [],
  }:
    let
      sandboxHome = "\${XDG_DATA_HOME:-$HOME}/.sandboxes/${sandboxName}";
    in
    lib.optionals isolatedHome [
      "--tmpfs" "$HOME"
      "--bind" sandboxHome "$HOME"
    ]
    ++ lib.optionals wayland [
      "--ro-bind-try" "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"
      "--ro-bind-try" "$XDG_RUNTIME_DIR/wayland-0" "$XDG_RUNTIME_DIR/wayland-0"
    ]
    ++ lib.optionals x11 [
      "--ro-bind-try" "/tmp/.X11-unix" "/tmp/.X11-unix"
    ]
    ++ lib.optionals audio [
      "--ro-bind-try" "$XDG_RUNTIME_DIR/pulse" "$XDG_RUNTIME_DIR/pulse"
      "--ro-bind-try" "$XDG_RUNTIME_DIR/pipewire-0" "$XDG_RUNTIME_DIR/pipewire-0"
    ]
    ++ lib.optionals dbus [
      "--ro-bind-try" "$XDG_RUNTIME_DIR/bus" "$XDG_RUNTIME_DIR/bus"
      "--bind-try" "$XDG_RUNTIME_DIR/dconf" "$XDG_RUNTIME_DIR/dconf"
    ]
    ++ lib.optional shareNet "--share-net"
    ++ (lib.concatMap (b: [ "--bind" (builtins.elemAt b 0) (builtins.elemAt b 1) ]) customBinds)
    ++ (lib.concatMap (b: [ "--ro-bind-try" (builtins.elemAt b 0) (builtins.elemAt b 1) ]) customRoBinds)
    ++ extraBwrapArgs;
}
