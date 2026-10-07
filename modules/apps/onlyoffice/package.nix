{ pkgs, lib ? pkgs.lib, mkSandboxedApp ? import ../lib/mk-sandboxed-app { inherit pkgs lib; } }:

let
  sources = import ./npins;
  system = pkgs.stdenv.hostPlatform.system;
  pin =
    if system == "x86_64-linux" then
      sources.onlyoffice-x86_64
    else if system == "aarch64-linux" then
      sources.onlyoffice-aarch64
    else
      throw "onlyoffice: 不支持的系统架构 '${system}'";

  version =
    let
      match = builtins.match ".*/download/v?([0-9.]+)/.*" pin.url;
    in
    if match != null then builtins.head match else "9.4.0";
in
mkSandboxedApp.qtApp {
  pname = "onlyoffice";
  inherit version;
  src = { deb = mkSandboxedApp.fetchWithRetry pin; };
  execPath = "opt/onlyoffice/desktopeditors/DesktopEditors";
  runInDirectory = "opt/onlyoffice/desktopeditors";

  # 扩展 Qt 基底，补充多媒体编解码（GStreamer全套插件、x265、libva）、辅助功能（speechd）、XKB 配置与 udev shim
  fhsBase = mkSandboxedApp.extend mkSandboxedApp.fhsBases.desktop-gui-electron-media-xcb-qt (pkgs: [
    pkgs.gst_all_1.gstreamer
    pkgs.gst_all_1.gst-plugins-base
    pkgs.gst_all_1.gst-plugins-good
    pkgs.gst_all_1.gst-plugins-bad
    pkgs.gst_all_1.gst-plugins-ugly
    pkgs.gst_all_1.gst-libav
    pkgs.libudev0-shim
    pkgs.speechd
    pkgs.x265
    pkgs.libva
    pkgs.libvpx
    pkgs.xkeyboard_config
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

  # 设置内部依赖库搜索路径，解决 converter 内部依赖库 (如 libUnicodeConverter.so 等) 缺失的问题
  preRunHooks = [
    ''export LD_LIBRARY_PATH="@UNPACKED@/opt/onlyoffice/desktopeditors:@UNPACKED@/opt/onlyoffice/desktopeditors/converter''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"''
  ];

  env = {
    QT_QPA_PLATFORM = "xcb";
    QT_XKB_CONFIG_ROOT = "${pkgs.xkeyboard_config}/share/X11/xkb";
    QTCOMPOSE = "${pkgs.libx11}/share/X11/locale";
    GST_PLUGIN_SYSTEM_PATH_1_0 = "/usr/lib/gstreamer-1.0:/usr/lib64/gstreamer-1.0";
    # 显式指定 NixOS 系统字体目录，使 ONLYOFFICE 核心引擎在扫描字体时检索宿主机通过 fonts.packages 安装的全部字体（含 Office 字体）
    CUSTOM_FONTS_PATH = "/run/current-system/sw/share/X11/fonts";
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

      # ──────────────────────────────────────────────────────────────────────────
      # 修复 ONLYOFFICE 内部字体扫描引擎忽略软链接 (DT_LNK) 的缺陷：
      #
      # 背景与根因：
      # ONLYOFFICE 编辑器正文排版引擎不走系统的 Fontconfig，而是通过 NSDirectory::GetFiles2
      # 遍历目录项查找字体文件。在 Linux 下该函数只直接处理 DT_REG(8) 与 DT_DIR(4)，
      # 对于非 0 的其他类型全部跳过丢弃（遗漏了软链接 DT_LNK = 10）。而在 NixOS 中，
      # 系统 /usr/share/fonts 与 /run/current-system/sw/share/X11/fonts 均为符号链接农场，
      # 导致 ONLYOFFICE 遍历后识别到的系统字体数量为 0，中文正文渲染成乱码豆腐块，
      # 下拉列表亦无法选到任何中文字体。
      #
      # 修复机制：
      # patch-libkernel.py 通过精确匹配 NSDirectory::GetFiles2 中的指令序列，
      # 将 `test %al, %al; jne ...` 指令替换为 4 个 NOP，使得遇到 DT_LNK 时透传落入
      # 后方的 stat() 判定逻辑中，从而透明解析出指向的物理字体文件及子目录。
      #
      # 严格错误校验：
      # patch-libkernel.py 会在目标符号范围内校验机器码特征，若随版本升级导致特征不匹配
      # 或匹配出现歧义，脚本会抛出异常退出（返回非 0 状态码），使构建立即失败并打印
      # 调试指引，防止未修补产物带病上线。
      # ──────────────────────────────────────────────────────────────────────────
      ${pkgs.python3}/bin/python3 ${./patch-libkernel.py} "$out/opt/onlyoffice/desktopeditors/converter/libkernel.so"
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
