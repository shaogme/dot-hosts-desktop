{ pkgs
, lib ? pkgs.lib
, sevenZip ? (pkgs.sevenZip or pkgs._7zip-zstd)
, mkSandboxedApp ? import ../lib/mk-sandboxed-app { inherit pkgs lib; }
}:

let
  sources = import ./npins;

  version =
    let
      match = builtins.match ".*/peazip_([0-9.]+)\\.LINUX\\.Qt6.*" sources.peazip.url;
    in
    if match != null then builtins.head match else "11.3.0";
in
mkSandboxedApp.qtApp {
  pname = "peazip";
  inherit version;
  src = { deb = mkSandboxedApp.fetchWithRetry sources.peazip; };
  execPath = "bin/peazip";

  # ──────────────────────────────────────────────────────────────────────────
  # 动态链接与运行时依赖深度分析：
  #
  # 1. 核心 ELF 直接动态链接 (DT_NEEDED):
  #    - peazip (GUI 主程序) 与 pea (归档/校验引擎):
  #      * libQt6Pas.so.6: Free Pascal (Lazarus) Qt6 界面抽象绑定接口库。
  #      * libX11.so.6: X11 客户端协议通信基础库。
  #      * libc.so.6: GNU C 运行时库。
  #    - libQt6Pas.so.6 (由 pkgs.qt6Packages.libqtpas 及安装包内置动态库提供):
  #      * libQt6PrintSupport.so.6, libQt6Widgets.so.6, libQt6Gui.so.6, libQt6Core.so.6
  #      * libstdc++.so.6, libm.so.6, libgcc_s.so.1, libc.so.6
  #    -> 由 qtApp 基底 (desktop-gui + electron + media + xcb + qt) 与 libqtpas 全量覆盖。
  #
  # 2. Qt6 运行时平台插件 (QPA) 与图形渲染支持:
  #    - Wayland 原生支持: libQt6WaylandClient.so.6, libwayland-client.so.0 (pkgs.qt6.qtwayland)
  #    - X11 / XCB 支持: libqxcb.so 与 libxcb 系列工具库 (pkgs.libxcb, pkgs.libxcb-keysyms 等)
  #    - SVG 图标与矢量资产渲染: pkgs.qt6.qtsvg
  #    - 键盘映射与布局: pkgs.xkeyboard_config, pkgs.libxkbcommon
  #    - GPU / OpenGL / Vulkan 硬件加速: pkgs.libGL, pkgs.libGLU, pkgs.mesa, pkgs.vulkan-loader
  #    - 字体渲染与排版引擎: pkgs.fontconfig.lib, pkgs.freetype, pkgs.harfbuzz
  #
  # 3. 内置及互补压缩归档工具链 (Helper CLI Utilities):
  #    - 安装包内置 64 位核心引擎 (/usr/lib/peazip/res/bin/):
  #      * 7z/7z: 64 位纯静态编译 7-Zip 主程序
  #      * 7z/7zCon.linux.sfx, 7z/7zalt, 7z/Codecs/Rar.so: 依赖 libpthread, libstdc++, libgcc_s, libc
  #      * brotli/brotli: 依赖 libm, libc
  #      * quad/bcm: 依赖 libc
  #      * upx/upx: 64 位纯静态编译可执行文件压缩器
  #      * zpaq/zpaq: 依赖 libstdc++, libm, libgcc_s, libpthread, libc
  #      * zstd/zstd: 依赖 libz, libc
  #    - 注入系统级高兼容度现代归档工具集，替代 32 位老旧二进制并提供 200+ 种格式全覆盖:
  #      * p7zip, _7zz, zstd, brotli, zpaq, upx, gnutar, gzip, bzip2, xz, lzip, lzop, lz4, cpio, cabextract
  # ──────────────────────────────────────────────────────────────────────────
  fhsBase = mkSandboxedApp.extend mkSandboxedApp.fhsBases.desktop-gui-electron-media-xcb-qt (pkgs: [
    pkgs.qt6Packages.libqtpas
    pkgs.xkeyboard_config
    # 统一 7-Zip 引擎
    sevenZip
    # 互补与增强归档格式支持
    pkgs.zstd
    pkgs.brotli
    pkgs.zpaq
    pkgs.upx
    pkgs.gnutar
    pkgs.gzip
    pkgs.bzip2
    pkgs.xz
    pkgs.lzip
    pkgs.lzop
    pkgs.lz4
    pkgs.cpio
    pkgs.cabextract
  ]);

  # 沙箱隔离与持久化配置：
  # 1. 允许访问用户的下载、文档、桌面与外部数据盘以解压和创建压缩包
  # 2. 持久化应用配置文件至 ~/.sandboxes/peazip/.config/peazip
  sandbox = {
    shareDownloads = true;
    shareData = true;
    sharedDirs = [
      "Documents" "文档"
      "Desktop" "桌面"
    ];
    homeDirs = [
      ".config/peazip"
      ".local/share/peazip"
      ".cache/peazip"
    ];
  };

  # 设置内部依赖库搜索路径，确保优先解析安装包自带与系统环境内的 libQt6Pas 及相关库
  preRunHooks = [
    ''export LD_LIBRARY_PATH="@UNPACKED@/lib:@UNPACKED@/lib/peazip''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"''
  ];

  env = {
    QT_XKB_CONFIG_ROOT = "${pkgs.xkeyboard_config}/share/X11/xkb";
    XKB_CONFIG_ROOT = "${pkgs.xkeyboard_config}/share/X11/xkb";
  };

  postUnpackHooks = [
    ''
      # ──────────────────────────────────────────────────────────────────────────
      # 修复上游绝对软链接缺陷：
      #
      # 上游 deb 包中 /usr/lib/peazip/res/share 硬编码指向宿主机物理绝对路径 /usr/share/peazip。
      # 在隔离沙箱及无状态 NixOS 系统中，宿主机根文件系统并无此路径，
      # 导致 PeaZip 无法检索到内置图标、多语言翻译包 (lang/)、主题包 (themes/) 与预设文件 (presets/)。
      # 将其修正为相对路径指向解包目录下的 share/peazip。
      # ──────────────────────────────────────────────────────────────────────────
      ln -sfn ../../../share/peazip $out/lib/peazip/res/share

      # 规范化 bin 入口，支持调用主程序 peazip 与命令行引擎 pea
      mkdir -p $out/bin
      ln -sfn ../lib/peazip/peazip $out/bin/peazip
      ln -sfn ../lib/peazip/pea $out/bin/pea

      # 确保二进制执行权限
      chmod +x $out/lib/peazip/peazip $out/lib/peazip/pea $out/lib/peazip/res/bin/*/* 2>/dev/null || true
    ''
  ];

  icons = { hicolor.auto = true; };

  aliases = [ "PeaZip" ];

  desktop = {
    desktopName = "PeaZip";
    genericName = "Archiver and File Manager";
    comment = "PeaZip free file archiver utility, Qt6 build (Bubblewrap Isolated)";
    categories = [ "Utility" "Archiving" "Compression" ];
    icon = "peazip";
    startupWMClass = "peazip";
    mimeTypes = [
      "application/x-7z-compressed"
      "application/7z"
      "application/zip"
      "application/x-zip"
      "application/x-zip-compressed"
      "application/x-tar"
      "application/x-gzip"
      "application/gzip"
      "application/x-bzip2"
      "application/x-bzip"
      "application/bzip2"
      "application/x-xz"
      "application/x-zstd-compressed-tar"
      "application/zstd"
      "application/x-rar"
      "application/x-rar-compressed"
      "application/vnd.rar"
      "application/x-brotli"
      "application/x-cpio"
      "application/x-deb"
      "application/vnd.debian.binary-package"
      "application/x-rpm"
      "application/vnd.android.package-archive"
      "application/vnd.ms-cab-compressed"
      "application/x-iso9660-image"
      "application/x-cd-image"
      "application/x-lha"
      "application/x-lzh"
      "application/x-lzma"
      "application/x-lzop"
      "application/x-zpaq"
    ];
  };
}
