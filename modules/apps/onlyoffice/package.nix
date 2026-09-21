{ pkgs, lib ? pkgs.lib, mkSandboxedApp ? import ../lib/mk-sandboxed-app { inherit pkgs lib; } }:

let
  mkUnpacked = import ../lib/mk-sandboxed-app/mk-unpacked.nix { inherit pkgs lib; };
  sources = import ./npins;
  rawVersion = sources.onlyoffice.version;
  version = lib.removePrefix "v" rawVersion;

  arch = mkUnpacked.resolveArch {
    x86_64 = "amd64";
    aarch64 = "arm64";
  };

  debUrl = "https://github.com/ONLYOFFICE/DesktopEditors/releases/download/v${version}/onlyoffice-desktopeditors_${arch}.deb";
in
mkSandboxedApp.qtApp {
  pname = "onlyoffice";
  inherit version;
  src = { deb = builtins.fetchurl debUrl; };
  execPath = "opt/onlyoffice/desktopeditors/DesktopEditors";
  runInDirectory = "opt/onlyoffice/desktopeditors";

  # 扩展 Qt 基底，补充多媒体编解码、XKB 配置、udev shim 与默认中文字体支持
  fhsBase = mkSandboxedApp.extend mkSandboxedApp.fhsBases.desktop-gui-electron-media-xcb-qt (pkgs: [
    pkgs.gst_all_1.gstreamer
    pkgs.gst_all_1.gst-plugins-base
    pkgs.xkeyboard_config
    pkgs.libudev0-shim
    pkgs.noto-fonts-cjk-sans
  ]);

  # 沙箱隔离与持久化配置：
  # 1. 允许访问用户的文档与桌面目录以读写编辑办公文件
  # 2. 持久化应用配置与缓存至 ~/.sandboxes/onlyoffice
  sandbox = {
    shareDownloads = true;
    shareData = true;
    sharedDirs = [
      "Documents" "文档"
      "Desktop" "桌面"
    ];
    homeDirs = [
      ".config/onlyoffice"
      ".local/share/onlyoffice"
      ".cache/onlyoffice"
    ];
  };

  env = {
    QT_QPA_PLATFORM = "xcb";
    QT_XKB_CONFIG_ROOT = "${pkgs.xkeyboard_config}/share/X11/xkb";
    QTCOMPOSE = "${pkgs.libx11}/share/X11/locale";
  };

  postUnpackHooks = [
    ''
      # 保证 onlyoffice 图标在 hicolor 目录中存在，供 mkIcons 自动生成别名链接
      for icon_path in $out/share/icons/hicolor/*/apps/onlyoffice-desktopeditors.png; do
        if [ -f "$icon_path" ]; then
          d=$(dirname "$icon_path")
          cp "$icon_path" "$d/onlyoffice.png"
        fi
      done
      for f in $out/opt/onlyoffice/desktopeditors/asc-de-*.png; do
        if [ -f "$f" ]; then
          size=$(basename "$f" ".png" | cut -d"-" -f3)
          res="''${size}x''${size}"
          mkdir -p "$out/share/icons/hicolor/$res/apps"
          cp "$f" "$out/share/icons/hicolor/$res/apps/onlyoffice.png"
          cp "$f" "$out/share/icons/hicolor/$res/apps/onlyoffice-desktopeditors.png"
        fi
      done
      if [ -f "$out/share/icons/hicolor/256x256/apps/onlyoffice.png" ]; then
        mkdir -p "$out/share/pixmaps"
        cp "$out/share/icons/hicolor/256x256/apps/onlyoffice.png" "$out/share/pixmaps/onlyoffice.png"
        cp "$out/share/icons/hicolor/256x256/apps/onlyoffice.png" "$out/share/pixmaps/onlyoffice-desktopeditors.png"
      fi

      # 修正启动脚本中可能存在的绝对路径引用
      if [ -f "$out/bin/onlyoffice-desktopeditors" ]; then
        sed -i "s|/opt/onlyoffice/desktopeditors|$out/opt/onlyoffice/desktopeditors|g" "$out/bin/onlyoffice-desktopeditors" 2>/dev/null || true
      fi
    ''
  ];

  icons = { hicolor.auto = true; };

  aliases = [ "onlyoffice-desktopeditors" "desktopeditors" ];

  desktop = {
    desktopName = "ONLYOFFICE Desktop Editors";
    genericName = "Office Suite";
    comment = "Office suite that combines text, spreadsheet and presentation editors (Bubblewrap Isolated)";
    categories = [ "Office" "WordProcessor" "Spreadsheet" "Presentation" ];
    icon = "onlyoffice";
    startupWMClass = "DesktopEditors";
    mimeTypes = [
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
      "application/vnd.openxmlformats-officedocument.presentationml.presentation"
      "application/msword"
      "application/vnd.ms-excel"
      "application/vnd.ms-powerpoint"
      "application/pdf"
      "application/rtf"
      "text/plain"
      "application/x-ole-storage"
      "application/vnd.oasis.opendocument.text"
      "application/vnd.oasis.opendocument.spreadsheet"
      "application/vnd.oasis.opendocument.presentation"
    ];
  };
}
