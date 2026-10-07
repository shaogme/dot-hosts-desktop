{ pkgs
, lib ? pkgs.lib
, mkSandboxedApp ? import ../lib/mk-sandboxed-app { inherit pkgs lib; }
, extraCompatPackages ? [ ]
, extraGameDirs ? [ ]
}:

let
  sources = import ./npins;

  version =
    let
      match = builtins.match ".*/steam-launcher_([0-9.]+)_.*" sources.steam.url;
    in
    if match != null then builtins.head match
    else throw "steam: Could not parse version from URL: ${sources.steam.url}";

  compatPaths = lib.makeSearchPathOutput "steamcompattool" "" extraCompatPackages;
  compatEnv = lib.optionalAttrs (extraCompatPackages != [ ]) {
    STEAM_EXTRA_COMPAT_TOOLS_PATHS = compatPaths;
  };

  # 64 位 Steam 运行时基础工具链（对齐 Valve 官方 steam-launcher.deb 依赖与 Steam Linux Runtime 规范）
  steamTargetPkgs = pkgs: [
    # 核心 Shell 与系统工具链
    pkgs.bash
    pkgs.coreutils
    pkgs.diffutils
    pkgs.findutils
    pkgs.gnutar
    pkgs.xz
    pkgs.file
    pkgs.which
    pkgs.procps
    pkgs.util-linux
    pkgs.strace

    # 桌面与外设环境发现（官方 Depends: lsof, zenity, xdg-user-dirs, xdg-utils）
    pkgs.lsof
    pkgs.zenity
    pkgs.xdg-utils
    pkgs.xdg-user-dirs
    pkgs.lsb-release
    pkgs.pciutils
    pkgs.usbutils

    # 网络与下载诊断工具
    pkgs.curl
    pkgs.wget

    # 音频控制工具 (提供 pactl，用于 Steam 探测系统音频设备与音量状态)
    pkgs.pulseaudio

    # 字体工具与内置中文字体包（确保 FHS 内部 /usr/share/fonts 具备完整 CJK 回退字体）
    pkgs.fontconfig
    pkgs.noto-fonts-cjk-sans
    pkgs.wqy_zenhei

    # Glibc 基础二进制工具 (ldd, getconf, locale 等)
    pkgs.glibc.bin

    # X11 Locale 数据软链接（避免 libX11 启动因找不到 Locale 闪退）
    (pkgs.runCommand "xorg-locale" { } ''
      mkdir -p $out
      ln -s ${pkgs.libx11}/share $out/share
    '')
  ];

  # 32 位与 64 位双架构运行时依赖库（对齐 Valve 官方 steam-libs-amd64 与 steam-libs-i386 元包规范）
  steamMultiPkgs = pkgs: [
    # C/C++ 基础运行时与底层系统库
    pkgs.glibc
    pkgs.gcc.cc.lib
    pkgs.libxcrypt
    pkgs.libgpg-error
    pkgs.attr
    pkgs.zlib
    pkgs.bzip2

    # 图形驱动与硬件加速基础设施
    pkgs.mesa
    pkgs.libGL
    pkgs.libGLU
    pkgs.libdrm
    pkgs.libgbm
    pkgs.vulkan-loader
    pkgs.libva
    pkgs.libvdpau

    # 窗口系统与 GUI 工具包 (X11 / XCB / GTK3 / Cairo 依赖)
    pkgs.libx11
    pkgs.libxcomposite
    pkgs.libxdamage
    pkgs.libxext
    pkgs.libxfixes
    pkgs.libxrandr
    pkgs.libxrender
    pkgs.libxtst
    pkgs.libxcb
    pkgs.libxi
    pkgs.libxcursor
    pkgs.libxinerama
    pkgs.libxscrnsaver
    pkgs.libxshmfence
    pkgs.libxkbfile
    pkgs.libxkbcommon
    pkgs.gtk3
    pkgs.glib
    pkgs.cairo
    pkgs.pixman
    pkgs.libpng
    pkgs.expat
    pkgs.brotli
    pkgs.pango
    pkgs.atk
    pkgs.gdk-pixbuf

    # 音频服务与驱动通道 (PipeWire, ALSA, PulseAudio)
    pkgs.pipewire
    pkgs.alsa-lib
    pkgs.alsa-plugins
    pkgs.libpulseaudio

    # 字体与排版引擎
    pkgs.fontconfig.lib
    pkgs.freetype
    pkgs.harfbuzz

    # 网络协议、安全证书与系统服务通信
    pkgs.dbus
    pkgs.networkmanager
    pkgs.openssl
    pkgs.gnutls
    pkgs.nss
    pkgs.nspr
    pkgs.libcap
    pkgs.udev
    pkgs.libudev0-shim
  ];

  # FHS 构建补充指令：
  # Steam 期望 /sbin/ldconfig 存在；如果在嵌套容器中使用软链接会导致循环软链接错误，故复制实体二进制文件
  steamExtraCommands = [
    "cp -f $out/usr/{bin,sbin}/ldconfig"
  ];

  # Steam 专用 profile 环境准备
  steamProfile = ''
    # 防止 SteamRT GTK 尝试加载宿主机 GIO 模块导致错误日志刷屏
    unset GIO_EXTRA_MODULES

    # 容器内 udev 事件通知不稳定，引导 SDL2 回退为基于 inotify 扫描设备
    export SDL_JOYSTICK_DISABLE_UDEV=1

    # 修复非 CJK locale 或 Wayland 下 Steam 中文输入法
    export GTK_IM_MODULE='xim'

    # 显卡驱动与 Vulkan ICD 加载路径
    export LIBGL_DRIVERS_PATH=/run/opengl-driver/lib/dri:/run/opengl-driver-32/lib/dri
    export __EGL_VENDOR_LIBRARY_DIRS=/run/opengl-driver/share/glvnd/egl_vendor.d:/run/opengl-driver-32/share/glvnd/egl_vendor.d
    export LIBVA_DRIVERS_PATH=/run/opengl-driver/lib/dri:/run/opengl-driver-32/lib/dri
    export VDPAU_DRIVER_PATH=/run/opengl-driver/lib/vdpau:/run/opengl-driver-32/lib/vdpau
    export XDG_DATA_DIRS=$XDG_DATA_DIRS''${XDG_DATA_DIRS:+:}/run/opengl-driver/share:/run/opengl-driver-32/share

    # 字体配置兜底：若宿主机 /etc/fonts/fonts.conf 不存在，回退使用 fontconfig 缺省配置
    if [ ! -f /etc/fonts/fonts.conf ] && [ -f "${pkgs.fontconfig.out}/etc/fonts/fonts.conf" ]; then
      export FONTCONFIG_FILE="${pkgs.fontconfig.out}/etc/fonts/fonts.conf"
    fi

    # 时区自动矫正，消除软链接混淆
    if [ -z "''${TZ+x}" ]; then
      new_TZ="$(readlink -f /etc/localtime | grep -P -o '(?<=/zoneinfo/).*$' || true)"
      if [ -n "$new_TZ" ]; then
        export TZ="$new_TZ"
      fi
    fi

    # 嵌套 Bwrap / steam-run 调度逻辑：
    # 当通过 steam-run 别名调用时，直接执行后续参数命令
    if [ "''${SANDBOX_CALL_CMD:-}" = "steam-run" ]; then
      if [ $# -eq 0 ]; then
        echo "Usage: steam-run command-to-run args..." >&2
        exit 1
      fi
      exec "$@"
    fi
  '';
in
mkSandboxedApp.base {
  pname = "steam";
  inherit version;
  includeClosures = true;
  src = { deb = mkSandboxedApp.fetchWithRetry sources.steam; };
  execPath = "bin/steam";

  postUnpackHooks = [
    # 移除 Debian 专有的 steamdeps 脚本（其依赖 apt），避免启动时输出缺少 python3-apt 的无害日志
    "rm -f $out/bin/steamdeps $out/lib/steam/bin_steamdeps.py"

    # 补丁 bin_steam.sh：强制使用 cp -f 覆盖 bootstrap 归档文件。
    # 从 Nix Store 复制出的 bootstrap 归档为只读权限 (0444)，后续客户端自检时裸 cp 会因权限不足导致覆写失败
    "substituteInPlace $out/lib/steam/bin_steam.sh --replace-fail 'cp \"$LAUNCHSTEAMBOOTSTRAPFILE\"' 'cp -f \"$LAUNCHSTEAMBOOTSTRAPFILE\"'"
  ];

  fhsBase = mkSandboxedApp.mkMultiFhsBase {
    label = "steam-fhs";
    pkgsList = steamTargetPkgs;
    multiPkgsList = steamMultiPkgs;
  };

  privateTmp = true;
  fhsExtraCommands = steamExtraCommands;
  preRunHooks = [ steamProfile ];
  env = compatEnv;

  sandbox = {
    shareInput = true;
    shareGames = true;
    shareMedia = true;
    shareShm = true;
    shareDownloads = true;
    shareData = true;
    homeDirs = [
      ".local/share/Steam"
      ".steam"
      ".cache"
    ];
    sharedDirs = [ "SteamLibrary" ] ++ extraGameDirs;
    extraBinds = [
      [ "/tmp/dumps" "/tmp/dumps" ]
    ];
  };

  aliases = [ "steam-run" ];

  desktop = {
    desktopName = "Steam";
    genericName = "游戏分发平台";
    comment = "在 Bubblewrap 沙箱隔离容器中运行 Steam 游戏与 Proton Windows 兼容环境";
    categories = [ "Network" "Game" ];
    icon = "steam";
    mimeTypes = [
      "x-scheme-handler/steam"
      "x-scheme-handler/steamlink"
    ];
    actions = {
      Store = {
        name = "Store";
        exec = "steam steam://store";
      };
      Community = {
        name = "Community";
        exec = "steam steam://url/CommunityHome/";
      };
      Library = {
        name = "Library";
        exec = "steam steam://open/games";
      };
      Servers = {
        name = "Servers";
        exec = "steam steam://open/servers";
      };
      Screenshots = {
        name = "Screenshots";
        exec = "steam steam://open/screenshots";
      };
      News = {
        name = "News";
        exec = "steam steam://openurl/https://store.steampowered.com/news";
      };
      Settings = {
        name = "Settings";
        exec = "steam steam://open/settings";
      };
      BigPicture = {
        name = "Big Picture";
        exec = "steam steam://open/bigpicture";
      };
      Friends = {
        name = "Friends";
        exec = "steam steam://open/friends";
      };
    };
  };
}
