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
      libxinerama
      libxscrnsaver
      libxshmfence
      libxkbfile
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
      libgbm
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
      fontconfig.lib
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
      gsettings-desktop-schemas
      dconf
      dconf.lib
    ];

    # Qt5 图形框架与 Wayland 运行支持
    qt5 = pkgs: with pkgs; [
      qt5.qtbase
      qt5.qtwayland
      qt5.qtx11extras
      qt5.qtsvg
      qt5.qtdeclarative
    ];

    # Qt6 图形框架与 Wayland 运行支持
    qt6 = pkgs: with pkgs; [
      qt6.qtbase
      qt6.qtwayland
      qt6.qtsvg
      qt6.qtdeclarative
    ];

    # 通用 Qt 运行时 Profile
    qt = pkgs: pkgProfiles.qt5 pkgs ++ pkgProfiles.qt6 pkgs;

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
      libgbm
      libsecret
      libnotify
      nspr
      nss
      systemdLibs
    ];

    # XCB / Qt 附加图形环境 (如 WeChat Universal 等)
    xcb = pkgs: with pkgs; [
      libxcb
      libxcb-util
      libxcb-image
      libxcb-keysyms
      libxcb-render-util
      libxcb-wm
      libxcb-cursor
      libxcb-errors
    ];

    # 桌面 GUI 应用元 Profile (常用 GUI 应用的基础集合)
    desktop-gui = pkgs:
      pkgProfiles.base pkgs
      ++ pkgProfiles.x11 pkgs
      ++ pkgProfiles.wayland pkgs
      ++ pkgProfiles.graphics pkgs
      ++ pkgProfiles.audio pkgs
      ++ pkgProfiles.fonts pkgs
      ++ pkgProfiles.gtk3 pkgs
      ++ pkgProfiles.xcb pkgs;
  };

  # =========================================
  # 2. Bubblewrap 隔离规则参数生成器
  # =========================================
  makeBwrapArgs = {
    sandboxName,
    isolatedHome ? true,
    shareNet ? true,
    wayland ? true,
    x11 ? true,
    audio ? true,
    dbus ? true,
    inputMethod ? true,
    bypassProxy ? false,
    shareDownloads ? true,        # 是否与宿主机共享 ~/Downloads (读写)
    shareUserDirs ? false,       # 是否与宿主机共享常用用户目录 (只读: Documents, Pictures, Desktop 等)
    sharedDirs ? [],             # 额外的读写共享目录 (相对 $HOME 或绝对路径)
    roSharedDirs ? [],           # 额外的只读共享目录 (相对 $HOME 或绝对路径)
    customBinds ? [],
    customRoBinds ? [],
    extraBwrapArgs ? [],
  }:
    let
      sandboxHome = "\${XDG_DATA_HOME:-$HOME}/.sandboxes/${sandboxName}";

      # 常用 XDG 用户目录（中英文双语兼容，支持 --ro-bind-try 自动忽略不存在的目录）
      defaultUserDirs = [
        "Desktop" "桌面"
        "Documents" "文档"
        "Pictures" "图片"
        "Videos" "视频"
        "Music" "音乐"
      ];

      defaultDownloadsDirs = [
        "Downloads" "下载"
      ];

      effectiveSharedDirs = lib.unique (
        (lib.optionals shareDownloads defaultDownloadsDirs)
        ++ sharedDirs
      );

      effectiveRoSharedDirs = lib.unique (
        (lib.optionals shareUserDirs defaultUserDirs)
        ++ roSharedDirs
      );

      formatBindArg = dir:
        if lib.hasPrefix "/" dir then [ dir dir ]
        else [ "\$HOME/${dir}" "\$HOME/${dir}" ];
    in
    lib.optionals isolatedHome [
      "--tmpfs" "$HOME"
      "--bind" sandboxHome "$HOME"
    ]
    ++ lib.optionals isolatedHome (
      (lib.concatMap (dir: [ "--bind-try" ] ++ (formatBindArg dir)) effectiveSharedDirs)
      ++ (lib.concatMap (dir: [ "--ro-bind-try" ] ++ (formatBindArg dir)) effectiveRoSharedDirs)
    )
    ++ lib.optionals bypassProxy [
      "--unshare-user"
      "--gid" "1992"
    ]
    ++ lib.optionals wayland [
      "--ro-bind-try" "\${XDG_RUNTIME_DIR:-/run/user/1000}/\${WAYLAND_DISPLAY:-wayland-0}" "\${XDG_RUNTIME_DIR:-/run/user/1000}/\${WAYLAND_DISPLAY:-wayland-0}"
      "--ro-bind-try" "\${XDG_RUNTIME_DIR:-/run/user/1000}/wayland-0" "\${XDG_RUNTIME_DIR:-/run/user/1000}/wayland-0"
    ]
    ++ lib.optionals x11 [
      "--ro-bind-try" "\${XAUTHORITY:-\$HOME/.Xauthority}" "\${XAUTHORITY:-\$HOME/.Xauthority}"
    ]
    ++ lib.optionals audio [
      "--ro-bind-try" "\${XDG_RUNTIME_DIR:-/run/user/1000}/pulse" "\${XDG_RUNTIME_DIR:-/run/user/1000}/pulse"
      "--ro-bind-try" "\${XDG_RUNTIME_DIR:-/run/user/1000}/pipewire-0" "\${XDG_RUNTIME_DIR:-/run/user/1000}/pipewire-0"
    ]
    ++ lib.optionals dbus [
      "--ro-bind-try" "\${XDG_RUNTIME_DIR:-/run/user/1000}/bus" "\${XDG_RUNTIME_DIR:-/run/user/1000}/bus"
      "--bind-try" "\${XDG_RUNTIME_DIR:-/run/user/1000}/dconf" "\${XDG_RUNTIME_DIR:-/run/user/1000}/dconf"
      "--ro-bind-try" "/var/run/dbus/system_bus_socket" "/var/run/dbus/system_bus_socket"
    ]
    ++ lib.optionals inputMethod [
      "--ro-bind-try" "\${XDG_RUNTIME_DIR:-/run/user/1000}/fcitx5" "\${XDG_RUNTIME_DIR:-/run/user/1000}/fcitx5"
      "--ro-bind-try" "\${XDG_RUNTIME_DIR:-/run/user/1000}/ibus" "\${XDG_RUNTIME_DIR:-/run/user/1000}/ibus"
      "--ro-bind-try" "\${XDG_RUNTIME_DIR:-/run/user/1000}/fcitx" "\${XDG_RUNTIME_DIR:-/run/user/1000}/fcitx"
    ]
    ++ lib.optional shareNet "--share-net"
    ++ (lib.concatMap (b: [ "--bind" (builtins.elemAt b 0) (builtins.elemAt b 1) ]) customBinds)
    ++ (lib.concatMap (b: [ "--ro-bind-try" (builtins.elemAt b 0) (builtins.elemAt b 1) ]) customRoBinds)
    ++ extraBwrapArgs;
}
