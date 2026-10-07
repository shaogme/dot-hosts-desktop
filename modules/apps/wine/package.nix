{ pkgs, lib ? pkgs.lib, mkSandboxedApp ? import ../lib/mk-sandboxed-app { inherit pkgs lib; } }:

let
  winePkg = pkgs.wineWow64Packages.stagingFull;
in
mkSandboxedApp.wineApp {
  pname = "wine";
  version = winePkg.version;

  # 从 Wine 官方包中提取图标等静态资产
  src = {
    custom = pkgs.stdenv.mkDerivation {
      name = "wine-assets";
      dontUnpack = true;
      installPhase = ''
        mkdir -p $out/share
        if [ -d "${winePkg}/share/icons" ]; then
          cp -a ${winePkg}/share/icons $out/share/ 2>/dev/null || true
        fi
        if [ -d "${winePkg}/share/pixmaps" ]; then
          cp -a ${winePkg}/share/pixmaps $out/share/ 2>/dev/null || true
        fi
      '';
    };
  };

  # winExecPath 为 null 代表通用 Wine 容器模式：
  # 1. 终端执行 wine <file.exe> 直接进入沙箱运行
  # 2. 终端执行 winecfg / winetricks / wineserver / regedit 自动路由执行
  # 3. 桌面环境双击打开时，默认启动 Wine 文件资源管理器 (explorer.exe)
  winExecPath = null;

  wine = {
    package = winePkg;
    arch = "win64";
    dxvk = true; # 默认装配 DXVK 2.x (Direct3D 8/9/10/11 -> Vulkan 加速引擎)
    fonts = {
      enableCjkFallback = true;   # 自动下发 FontSubstitutes 与 FontLink 映射（宿主机系统与用户字体由沙箱默认继承）
      enableFontSmoothing = true; # 开启 ClearType 抗锯齿平滑渲染
    };
    drives = {
      "d:" = "Downloads";
      "e:" = "Games";
    };
    dllOverrides = {
      riched20 = "native,builtin";
    };
    registry = {
      "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" = {
        "InputStyle" = "root";
      };
    };
  };

  # 沙箱隔离与持久化：
  # 1. 自动持久化容器状态至 ~/.sandboxes/wine/wineprefix
  # 2. 允许访问用户的游戏、下载与文档目录，便于安装与保存数据
  sandbox = {
    shareDownloads = true;
    shareData = true;
    sharedDirs = [
      "Downloads" "下载"
      "Documents" "文档"
      "Games" "游戏"
      "Desktop" "桌面"
    ];
    homeDirs = [
      "wineprefix"
      "Downloads"
      "Games"
      ".cache/winetricks"
    ];
  };

  icons = { hicolor.auto = true; };

  # 提供全套常用配套命令别名
  aliases = [ "winecfg" "winetricks" "wineserver" "regedit" "winefile" "wineboot" ];

  desktop = {
    desktopName = "Wine Windows 程序加载器";
    genericName = "Windows 兼容环境";
    comment = "在 Bubblewrap 沙箱隔离容器中运行 Windows 游戏与应用程序";
    categories = [ "Utility" "Emulator" "System" ];
    icon = "wine";
    mimeTypes = [
      "application/x-ms-dos-executable"
      "application/x-msi"
      "application/x-ms-shortcut"
    ];
  };
}
