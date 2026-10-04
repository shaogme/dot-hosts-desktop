{ pkgs, lib ? pkgs.lib, mkSandboxedApp ? import ../lib/mk-sandboxed-app { inherit pkgs lib; } }:

let
  sources = import ./npins;

  version =
    let
      match = builtins.match ".*/td-setup-linux-x64-([0-9.]+)\\.tar\\.xz" sources.telegram-desktop.url;
    in
    if match != null then builtins.head match else "latest";
in
mkSandboxedApp.desktopApp {
  pname = "telegram-desktop";
  inherit version;
  src = { tarball = mkSandboxedApp.fetchWithRetry sources.telegram-desktop; };
  execPath = "Telegram";

  # ──────────────────────────────────────────────────────────────────────────
  # 动态链接与运行时依赖分析：
  #
  # 1. 直接 ELF 动态链接 (DT_NEEDED):
  #    - glibc: libc.so.6, libm.so.6, libdl.so.2, libpthread.so.0, librt.so.1, ld-linux-x86-64.so.2
  #    - glib / GObject / GIO: libglib-2.0.so.0, libgobject-2.0.so.0, libgio-2.0.so.0
  #    - cairo / pango: libcairo.so.2, libpango-1.0.so.0, libpangoft2-1.0.so.0, libpangocairo-1.0.so.0
  #    - 字体引擎: libfontconfig.so.1, libfreetype.so.6
  #    -> 均由 desktop-gui 基底 (base + gtk3 + fonts) 全量覆盖。
  #
  # 2. 上游 implib-gen 延迟绑定存根 (必须在环境内可被 dlopen 解析，否则断言失败退出):
  #    - libudev.so.1: 硬件与外设热插拔感知 (pkgs.systemdLibs)
  #    - libvdpau.so.1: VDPAU 硬件视频加速 (pkgs.libvdpau)
  #    - libva.so.2, libva-drm.so.2, libva-x11.so.2: VA-API 硬件加速 (pkgs.libva)
  #    - libdrm.so.2, libgbm.so.1: Direct Rendering & Buffer Management (pkgs.libdrm, pkgs.mesa)
  #    - libEGL.so.1, libGLX.so.0, libOpenGL.so.0: 统一 OpenGL/EGL 调度器 (pkgs.libGL)
  #    - libwayland-client/cursor/egl/server.so.0: Wayland 客户端与合成器协议 (pkgs.wayland)
  #    - libX11.so.6, libX11-xcb.so.1, libxcb.so.1: X11/XCB 协议通道 (pkgs.libx11, pkgs.libxcb)
  #    - libgtk-3.so.0, libgdk-3.so.0, libgdk_pixbuf-2.0.so.0: 原生 GTK 文件选择对话框与通知 (pkgs.gtk3)
  #
  # 3. 运行时特性与多媒体动态加载 (dlopen):
  #    - 音频后端: PipeWire (libpipewire-0.3.so.0), PulseAudio (libpulse.so.0), ALSA (libasound.so.2)
  #    - 小程序/内置浏览器: WebKitGTK 4.1 (libwebkit2gtk-4.1.so.0) 与 glib-networking TLS 认证
  #    - 键盘布局与快捷键: xkeyboard_config, libxkbcommon, libxcb-keysyms, libxtst (全局呼叫/热键)
  # ──────────────────────────────────────────────────────────────────────────
  fhsBase = mkSandboxedApp.extend mkSandboxedApp.fhsBases.desktop-gui (pkgs: [
    pkgs.systemdLibs
    pkgs.libvdpau
    pkgs.webkitgtk_4_1
    pkgs.glib-networking
  ]);

  # 沙箱隔离与持久化配置:
  # 1. 允许访问用户的下载目录以收发文件与媒体
  # 2. 持久化数据与缓存统一映射至 ~/.sandboxes/telegram-desktop
  sandbox = {
    shareDownloads = true;
    homeDirs = [
      ".local/share/TelegramDesktop"
    ];
  };

  env = {
    TDESKTOP_DISABLE_AUTOUPDATE = "1";
    GIO_MODULE_DIR = "${pkgs.glib-networking}/lib/gio/modules";
    QT_XKB_CONFIG_ROOT = "${pkgs.xkeyboard_config}/share/X11/xkb";
    XKB_CONFIG_ROOT = "${pkgs.xkeyboard_config}/share/X11/xkb";
  };

  postUnpackHooks = [
    ''
      mkdir -p $out/share/icons/hicolor/256x256/apps $out/share/pixmaps
      for name in telegram telegram-desktop org.telegram.desktop; do
        cp ${./telegram.png} "$out/share/icons/hicolor/256x256/apps/$name.png"
        cp ${./telegram.png} "$out/share/pixmaps/$name.png"
      done
      chmod +x $out/Telegram $out/Updater 2>/dev/null || true
    ''
  ];

  icons = { hicolor.auto = true; };

  aliases = [ "telegram" "Telegram" ];

  desktop = {
    desktopName = "Telegram Desktop";
    genericName = "Instant Messaging";
    comment = "Official Telegram Desktop messaging app (Bubblewrap Isolated)";
    categories = [ "Network" "InstantMessaging" "Chat" ];
    icon = "telegram-desktop";
    startupWMClass = "TelegramDesktop";
    mimeTypes = [ "x-scheme-handler/tg" ];
    exec = "telegram-desktop -noupdate -- %u";
  };
}
