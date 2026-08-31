{ pkgs, lib ? pkgs.lib, ... }:

let
  # 导入由 npins 锁定的依赖源（禁止在 Nix 表达式中手写 Hash）
  sources = import ./npins;

  # 1. 动态版本解析：从 npins 追踪的 GitHub Release 中获取版本号（如 "7.24.9"）
  rawVersion = sources.v2rayN.version;
  version = lib.removePrefix "v" rawVersion;

  # 2. 多架构二进制适配：根据系统架构映射上游 Release 资产名称
  #    x86_64: v2rayN-linux-64.deb
  #    aarch64: v2rayN-linux-arm64.deb
  #    riscv64: v2rayN-linux-riscv64.deb
  #    loongarch64: v2rayN-linux-loong64.deb
  arch =
    if pkgs.stdenv.hostPlatform.system == "aarch64-linux" then "arm64"
    else if pkgs.stdenv.hostPlatform.system == "riscv64-linux" then "riscv64"
    else if pkgs.stdenv.hostPlatform.system == "loongarch64-linux" then "loong64"
    else "64";

  # 3. 动态构建官方发布包下载链接
  debUrl = "https://github.com/2dust/v2rayN/releases/download/${rawVersion}/v2rayN-linux-${arch}.deb";
  debSrc = builtins.fetchurl debUrl;

  # 4. 二进制解包 Derivation：提取 deb 中的 /opt/v2rayN 与 /usr 资源
  unpacked = pkgs.stdenv.mkDerivation {
    pname = "v2rayn-raw";
    inherit version;
    src = debSrc;

    nativeBuildInputs = [ pkgs.dpkg ];
    dontBuild = true;
    dontConfigure = true;

    unpackPhase = "dpkg-deb -x $src .";

    installPhase = ''
      mkdir -p $out
      # /opt/v2rayN 包含 .NET 程序集、本地原生动态库及内置内核 (xray, sing-box)
      cp -r opt $out/
      # /usr 包含桌面图标与 .desktop 模板
      cp -r usr/* $out/
      # 确保主程序与内置核心程序具有可执行权限
      chmod +x $out/opt/v2rayN/v2rayN $out/opt/v2rayN/bin/*/* 2>/dev/null || true
    '';
  };

  # 5. FHS 环境与 Bubblewrap 沙箱隔离定义
  fhs = pkgs.buildFHSEnv {
    name = "v2rayn-fhs";

    targetPkgs = pkgs: with pkgs; [
      # ==========================================
      # .NET CoreCLR 运行时与核心原生依赖
      # ==========================================
      glibc
      gcc.cc.lib          # libstdc++.so.6, libgcc_s.so.1
      zlib                # 压缩算法支持 (libSystem.IO.Compression.Native)
      openssl             # 加密组件支持 (libSystem.Security.Cryptography.Native)
      icu                 # 全球化与多语言字符处理 (libSystem.Globalization.Native)
      dbus                # 桌面 D-Bus 进程间通信
      sqlite              # 内置 SQLite 数据库支持 (libe_sqlite3)

      # ==========================================
      # Avalonia UI / GTK3 / 桌面集成依赖
      # ==========================================
      gtk3
      glib
      cairo
      pango
      atk
      gdk-pixbuf
      libayatana-appindicator # 系统托盘与指示器支持
      libappindicator-gtk3

      # ==========================================
      # Wayland 与 X11 显示协议库
      # ==========================================
      libxkbcommon
      wayland
      libx11
      libxcomposite
      libxdamage
      libxext
      libxfixes
      libxrandr
      libxcb
      libxi
      libxcursor
      libxtst
      libxrender
      libICE
      libSM

      # ==========================================
      # 图形加速、字体渲染与音频通道
      # ==========================================
      libGL               # OpenGL 硬件加速 (SkiaSharp 渲染器需要)
      mesa
      pipewire
      alsa-lib
      fontconfig          # 字体匹配与加载
      freetype            # 矢量字体光栅化引擎
    ];

    extraBwrapArgs = [
      # 1. 核心安全隔离：屏蔽宿主机真实家目录，防止未授权访问 ~/.ssh, ~/.gnupg 等隐私数据
      "--tmpfs" "$HOME"

      # 2. 独立数据持久化：将专属沙箱持久化路径挂载为容器内部的 $HOME
      "--bind" "\${XDG_DATA_HOME:-$HOME/.local/share}/sandboxes/v2rayn" "$HOME"

      # 3. 基础通道穿透：图形显示（Wayland / X11）与音频（PipeWire / PulseAudio）
      "--ro-bind-try" "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"
      "--ro-bind-try" "$XDG_RUNTIME_DIR/wayland-0" "$XDG_RUNTIME_DIR/wayland-0"
      "--ro-bind-try" "/tmp/.X11-unix" "/tmp/.X11-unix"
      "--ro-bind-try" "$XDG_RUNTIME_DIR/pulse" "$XDG_RUNTIME_DIR/pulse"
      "--ro-bind-try" "$XDG_RUNTIME_DIR/pipewire-0" "$XDG_RUNTIME_DIR/pipewire-0"

      # 4. 网络命名空间共享：允许网络连接与代理功能正常工作
      "--share-net"
    ];

    runScript = pkgs.writeShellScript "v2rayn-launcher" ''
      # =========================================================================
      # 环境变量解析与说明：
      # v2rayN 源码 (ServiceLib/Global.cs) 中定义了 LocalAppData 开关：
      # V2RAYN_LOCAL_APPLICATION_DATA_V2=1
      #
      # 当此变量为 1 时，v2rayN 的 Utils.StartupPath() 会由默认的
      # AppDomain.CurrentDomain.BaseDirectory (只读的 Nix Store /opt/v2rayN)
      # 重定向至 Environment.SpecialFolder.LocalApplicationData (即 $HOME/.local/share/v2rayN)。
      # 这彻底解决了 Nix Store 只读导致无法写入 guiConfigs 配置的问题。
      # =========================================================================
      export V2RAYN_LOCAL_APPLICATION_DATA_V2=1

      # 确保沙箱家目录中的运行时文件夹完整存在
      DATA_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/v2rayN"
      mkdir -p "$DATA_DIR/bin" "$DATA_DIR/guiConfigs" "$DATA_DIR/guiLogs"

      # =========================================================================
      # 核心组件自初始化机制：
      # 在 V2RAYN_LOCAL_APPLICATION_DATA_V2=1 模式下，Utils.GetBinPath() 只会
      # 在 $HOME/.local/share/v2rayN/bin 目录下寻找 xray / sing-box / dat 规则文件。
      # 若沙箱刚创建时目录为空，则自动将软件包中解包出的核心组件复制到沙箱，
      # 既保证了开箱即用，又保留了用户在沙箱内部独立更新/替换内核的灵活性。
      # =========================================================================
      if [ -d "${unpacked}/opt/v2rayN/bin" ]; then
        cp -rn ${unpacked}/opt/v2rayN/bin/* "$DATA_DIR/bin/" 2>/dev/null || true
      fi

      # 适配 Wayland 桌面渲染环境
      if [ -n "$WAYLAND_DISPLAY" ]; then
        export GDK_BACKEND=wayland,x11
      fi

      # 切换至程序目录并执行主程序
      cd ${unpacked}/opt/v2rayN
      exec ${unpacked}/opt/v2rayN/v2rayN "$@"
    '';
  };

  # 6. 宿主机包装器脚本：在启动 Bubblewrap 隔离容器前，确保宿主机沙箱持久化目录已创建
  wrapper = pkgs.writeShellScriptBin "v2rayn" ''
    SANDBOX_HOME="''${XDG_DATA_HOME:-$HOME/.local/share}/sandboxes/v2rayn"
    mkdir -p "$SANDBOX_HOME"

    exec ${fhs}/bin/v2rayn-fhs "$@"
  '';

  # 7. 生成标准 XDG Desktop 快捷方式
  desktopItem = pkgs.makeDesktopItem {
    name = "v2rayn";
    desktopName = "v2rayN";
    genericName = "Proxy GUI Client";
    comment = "v2rayN - Proxy GUI Client (Bubblewrap Isolated)";
    exec = "v2rayn %U";
    icon = "v2rayn";
    terminal = false;
    type = "Application";
    categories = [ "Network" ];
  };
in
pkgs.symlinkJoin {
  name = "v2rayn";
  paths = [
    wrapper
    desktopItem
  ];
  # 合并并安装高分辨率图标至标准 hicolor 路径
  postBuild = ''
    mkdir -p $out/share/icons/hicolor
    if [ -d "${unpacked}/share/icons/hicolor" ]; then
      cp -r ${unpacked}/share/icons/hicolor/* $out/share/icons/hicolor/
    fi
  '';
}
