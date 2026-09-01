{ pkgs, lib ? pkgs.lib, ... }:

let
  sources = import ./npins;

  # 从 npins 追踪的 GitHub Release 中获取版本号（如 "v2.5.2" -> "2.5.2"）
  rawVersion = sources.clash-verge-rev.version;
  version = lib.removePrefix "v" rawVersion;

  # 根据 npins 锁定的版本动态下载对应的官方发布二进制
  debUrl = "https://github.com/clash-verge-rev/clash-verge-rev/releases/download/v${version}/Clash.Verge_${version}_amd64.deb";
  debSrc = builtins.fetchurl debUrl;

  unpacked = pkgs.stdenv.mkDerivation {
    pname = "clash-verge-raw";
    inherit version;
    src = debSrc;

    nativeBuildInputs = [ pkgs.dpkg ];
    dontBuild = true;
    dontConfigure = true;

    unpackPhase = "dpkg-deb -x $src .";

    installPhase = ''
      mkdir -p $out
      cp -r usr/* $out/
    '';
  };

  fhs = pkgs.buildFHSEnv {
    name = "clash-verge-fhs";

    targetPkgs = pkgs: with pkgs; [
      # GTK3 / WebKitGTK
      gtk3
      webkitgtk_4_1
      libsoup_3
      glib
      cairo
      pango
      atk
      gdk-pixbuf
      dbus
      libayatana-appindicator
      openssl

      # Wayland / X11
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

      # Audio & GPU
      libGL
      mesa
      pipewire
      alsa-lib
      fontconfig
      freetype
    ];

    extraBwrapArgs = [
      # 1. 屏蔽宿主机真实的 $HOME，阻止容器访问宿主机隐私文件 (~/.ssh, ~/.gnupg, 个人文档等)
      "--tmpfs" "$HOME"
      # 2. 将独立的持久化沙箱目录挂载为容器内部的 $HOME
      "--bind" "\${XDG_DATA_HOME:-$HOME/.local/share}/sandboxes/clash-verge" "$HOME"
      # 3. 基础设备与图形/音频穿透
      "--ro-bind-try" "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"
      "--ro-bind-try" "$XDG_RUNTIME_DIR/wayland-0" "$XDG_RUNTIME_DIR/wayland-0"
      "--ro-bind-try" "/tmp/.X11-unix" "/tmp/.X11-unix"
      "--ro-bind-try" "$XDG_RUNTIME_DIR/pulse" "$XDG_RUNTIME_DIR/pulse"
      "--ro-bind-try" "$XDG_RUNTIME_DIR/pipewire-0" "$XDG_RUNTIME_DIR/pipewire-0"
      "--share-net"
    ];

    runScript = pkgs.writeShellScript "clash-verge-launcher" ''
      # 适配 Wayland / WebKit 渲染环境
      if [ -n "$WAYLAND_DISPLAY" ]; then
        export GDK_BACKEND=wayland,x11
      fi

      exec ${unpacked}/bin/clash-verge "$@"
    '';
  };

  # 宿主机包装脚本：提前创建独立的持久化沙箱目录，然后启动隔离容器
  wrapper = pkgs.writeShellScriptBin "clash-verge" ''
    SANDBOX_HOME="''${XDG_DATA_HOME:-$HOME/.local/share}/sandboxes/clash-verge"
    mkdir -p "$SANDBOX_HOME/.config/clash-verge"

    exec ${fhs}/bin/clash-verge-fhs "$@"
  '';

  desktopItem = pkgs.makeDesktopItem {
    name = "clash-verge";
    desktopName = "Clash Verge Rev";
    genericName = "Proxy GUI Client";
    comment = "Clash Verge Rev - Proxy Client";
    exec = "clash-verge %U";
    icon = "clash-verge";
    terminal = false;
    type = "Application";
    categories = [ "Network" ];
  };
in
pkgs.symlinkJoin {
  name = "clash-verge-rev";
  paths = [
    wrapper
    desktopItem
  ];
  postBuild = ''
    mkdir -p $out/share/icons/hicolor
    if [ -d "${unpacked}/share/icons/hicolor" ]; then
      cp -r ${unpacked}/share/icons/hicolor/* $out/share/icons/hicolor/
    fi
  '';
}
