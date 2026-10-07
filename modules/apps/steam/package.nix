{ pkgs
, lib ? pkgs.lib
, mkSandboxedApp ? import ../lib/mk-sandboxed-app { inherit pkgs lib; }
, extraCompatPackages ? [ ]
, extraGameDirs ? [ ]
}:

let
  compatPaths = lib.makeSearchPathOutput "steamcompattool" "" extraCompatPackages;
  compatEnv = lib.optionalAttrs (extraCompatPackages != [ ]) {
    STEAM_EXTRA_COMPAT_TOOLS_PATHS = compatPaths;
  };

  # 64 位 Steam 运行时基础工具链
  steamTargetPkgs = pkgs: [
    pkgs.bash
    pkgs.coreutils
    pkgs.file
    pkgs.lsb-release
    pkgs.pciutils
    pkgs.usbutils
    pkgs.xdg-utils
    pkgs.xz
    pkgs.zenity
    pkgs.curl
    pkgs.wget
    pkgs.which
    pkgs.procps
    pkgs.strace
    (pkgs.runCommand "xorg-locale" { } ''
      mkdir -p $out
      ln -s ${pkgs.libx11}/share $out/share
    '')
  ];

  # 32 位与 64 位双架构运行时依赖库
  steamMultiPkgs = pkgs: [
    pkgs.glibc
    pkgs.libxcrypt
    pkgs.libGL
    pkgs.libGLU
    pkgs.libdrm
    pkgs.libgbm
    pkgs.udev
    pkgs.libudev0-shim
    pkgs.libva
    pkgs.libvdpau
    pkgs.vulkan-loader
    pkgs.networkmanager
    pkgs.libcap
    pkgs.pipewire
    pkgs.alsa-lib
    pkgs.libpulseaudio
    pkgs.openssl
    pkgs.gnutls
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
    pkgs.zlib
    pkgs.bzip2
    pkgs.fontconfig.lib
    pkgs.freetype
    pkgs.harfbuzz
    pkgs.gtk3
    pkgs.glib
    pkgs.cairo
    pkgs.pango
    pkgs.atk
    pkgs.gdk-pixbuf
    pkgs.nss
    pkgs.nspr
    pkgs.dbus
  ];

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
  version = pkgs.steam-unwrapped.version;
  src = { custom = pkgs.steam-unwrapped; };
  execPath = "bin/steam";

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
  };
}
