{ pkgs, lib }:

let
  typesLib = import ./types.nix { inherit lib; };

  # 复用 modules/fonts/npins 中的 Windows 原厂 Office 字体 (包含 SimSun, YaHei 等)
  fontsSourcesPath = ../../../fonts/npins;
  fontsSources =
    if builtins.pathExists fontsSourcesPath then
      import fontsSourcesPath
    else
      null;

  defaultOfficeFonts =
    if fontsSources != null && fontsSources ? win-fonts then
      pkgs.stdenvNoCC.mkDerivation {
        pname = "wine-office-fonts";
        version = "10.0";
        src = fontsSources.win-fonts;
        nativeBuildInputs = [ pkgs.unzip ];
        unpackPhase = ''
          runHook preUnpack
          unzip -q $src
          runHook postUnpack
        '';
        installPhase = ''
          runHook preInstall
          mkdir -p $out/share/fonts/truetype
          find . -maxdepth 1 -type f \( -iname "*.ttf" -o -iname "*.ttc" -o -iname "*.otf" \) \
            -exec install -Dm644 {} $out/share/fonts/truetype/ \;
          runHook postInstall
        '';
      }
    else
      pkgs.noto-fonts-cjk-sans;
in
{
  mkWineLauncherEnv =
    { pname
    , unpacked
    , winExecPath
    , wineCfg
    , sandboxName
    , env ? { }
    , preRunHooks ? [ ]
    , runInDirectory ? null
    , officeFontsPackage ? defaultOfficeFonts
    }:
    let
      # ── 1. 注册表生成器 ──
      # A. CJK 字体映射与 ClearType 平滑渲染补丁
      cjkFontsReg = pkgs.writeText "${pname}-cjk-fonts.reg" ''
        Windows Registry Editor Version 5.00

        [HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion\FontSubstitutes]
        "MS Shell Dlg"="SimSun"
        "MS Shell Dlg 2"="Microsoft YaHei"
        "Tahoma"="SimSun"
        "Arial"="Microsoft YaHei"
        "Segoe UI"="Microsoft YaHei"
        "System"="SimSun"
        "SimSun"="SimSun"
        "Microsoft YaHei"="Microsoft YaHei"
        "宋体"="SimSun"
        "新宋体"="NSimSun"
        "微软雅黑"="Microsoft YaHei"
        "FangSong_GB2312"="FangSong"
        "KaiTi_GB2312"="KaiTi"

        [HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink]
        "Lucida Sans Unicode"=hex(7):6d,00,73,00,79,00,68,00,2e,00,74,00,74,00,63,00,\
          00,00,00,00
        "Microsoft Sans Serif"=hex(7):6d,00,73,00,79,00,68,00,2e,00,74,00,74,00,63,00,\
          00,00,00,00
        "Tahoma"=hex(7):6d,00,73,00,79,00,68,00,2e,00,74,00,74,00,63,00,00,00,73,00,\
          69,00,6d,00,73,00,75,00,6e,00,2e,00,74,00,74,00,63,00,00,00,00,00
        "Segoe UI"=hex(7):6d,00,73,00,79,00,68,00,2e,00,74,00,74,00,63,00,00,00,00,00

        [HKEY_CURRENT_USER\Control Panel\Desktop]
        "FontSmoothing"="2"
        "FontSmoothingType"=dword:00000002
        "FontSmoothingGamma"=dword:00000578
        "FontSmoothingOrientation"=dword:00000001
      '';

      # B. DLL Overrides 注册表补丁
      effectiveDllOverrides =
        (lib.optionalAttrs wineCfg.dxvk {
          d3d11 = "native";
          dxgi = "native";
          d3d9 = "native";
          d3d8 = "native";
        })
        // wineCfg.dllOverrides;

      dllOverridesReg =
        if effectiveDllOverrides != { } then
          pkgs.writeText "${pname}-dll-overrides.reg" ''
            Windows Registry Editor Version 5.00

            [HKEY_CURRENT_USER\Software\Wine\DllOverrides]
            ${lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: ''"${k}"="${v}"'') effectiveDllOverrides)}
          ''
        else
          null;

      # C. HiDPI 注册表补丁
      dpiReg =
        if wineCfg.dpi != null then
          pkgs.writeText "${pname}-dpi.reg" ''
            Windows Registry Editor Version 5.00

            [HKEY_CURRENT_CONFIG\Software\Fonts]
            "LogPixels"=dword:${lib.toHexString wineCfg.dpi}
          ''
        else
          null;

      # D. 用户自定义字典转译注册表
      customReg =
        if wineCfg.registry != { } then
          let
            sections = lib.mapAttrsToList (section: entries: ''
              [${section}]
              ${lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v:
                if builtins.isInt v then ''"${k}"=dword:${lib.toHexString v}''
                else ''"${k}"="${toString v}"''
              ) entries)}
            '') wineCfg.registry;
          in
          pkgs.writeText "${pname}-custom.reg" ''
            Windows Registry Editor Version 5.00

            ${lib.concatStringsSep "\n\n" sections}
          ''
        else
          null;

      allRegFiles =
        (lib.optional wineCfg.fonts.enableCjkFallback cjkFontsReg)
        ++ (lib.optional (dllOverridesReg != null) dllOverridesReg)
        ++ (lib.optional (dpiReg != null) dpiReg)
        ++ (lib.optional (customReg != null) customReg)
        ++ wineCfg.regFiles;

      # ── 2. 字体包收集与 Fontconfig 配置 ──
      allFontPackages =
        (lib.optional wineCfg.fonts.enableOfficeFonts officeFontsPackage)
        ++ wineCfg.fonts.customFonts;

      fontsConf = pkgs.makeFontsConf {
        fontDirectories = allFontPackages;
      };

      # ── 3. 环境变量导出 ──
      customExports = lib.concatStringsSep "\n"
        (lib.mapAttrsToList (k: v: "export ${k}=${lib.escapeShellArg (toString v)}") env);

      # @UNPACKED@ 构建期宏替换
      preRunLines = lib.concatStringsSep "\n" (map
        (h: builtins.replaceStrings [ "@UNPACKED@" ] [ (toString unpacked) ] (toString h))
        preRunHooks);

      runDir =
        if runInDirectory == null then null
        else if lib.hasPrefix "/" runInDirectory then runInDirectory
        else "${unpacked}/${runInDirectory}";

      targetBin = if winExecPath != null then "${unpacked}/${winExecPath}" else null;
      uniquePackageHash = builtins.hashString "sha256" (
        toString pname
        + toString unpacked
        + toString winExecPath
        + builtins.toJSON wineCfg
      );

      # ── 4. Profile 环境 ──
      profile = ''
        # ── ${pname}: Wine 运行时适配 ──
        export WINE="wine"
        export WINE64="wine"
        export WINEPREFIX="$HOME/.sandboxes/${sandboxName}/wineprefix"
        export WINEARCH="${wineCfg.arch}"
        export WINEDEBUG="${wineCfg.debug}"
        export FONTCONFIG_FILE="${fontsConf}"

        # ── 确保 XDG_RUNTIME_DIR 有效，防止 Wayland/图形驱动报错 ──
        if [ -z "''${XDG_RUNTIME_DIR:-}" ]; then
          export XDG_RUNTIME_DIR="/run/user/$(id -u 2>/dev/null || echo 1000)"
          if [ ! -d "$XDG_RUNTIME_DIR" ]; then
            export XDG_RUNTIME_DIR="/tmp/user-$(id -u 2>/dev/null || echo 1000)-runtime"
            mkdir -p "$XDG_RUNTIME_DIR" 2>/dev/null || true
            chmod 700 "$XDG_RUNTIME_DIR" 2>/dev/null || true
          fi
        fi

        # ── 强制 XIM / X11 兼容输入法 ──
        export XMODIFIERS="@im=fcitx"
        export GTK_IM_MODULE="fcitx"
        export QT_IM_MODULE="fcitx"
        export SDL_IM_MODULE="fcitx"

        # ── 音频与基础环境 ──
        export PULSE_LATENCY_MSEC="60"

        ${customExports}
      '';

      # ── 5. RunScript 状态机与启动管理 ──
      runScript = pkgs.writeShellScript "${pname}-wine-run" ''
        set -euo pipefail

        SANDBOX_ROOT="$HOME/.sandboxes/${sandboxName}"
        PREFIX_DIR="$SANDBOX_ROOT/wineprefix"
        META_FILE="$PREFIX_DIR/.nix-prefix-meta"
        CURRENT_HASH="${uniquePackageHash}"

        export WINE="wine"
        export WINE64="wine"
        export WINEPREFIX="$PREFIX_DIR"
        export WINEARCH="${wineCfg.arch}"
        export WINEDEBUG="${wineCfg.debug}"
        export WINEDLLOVERRIDES="mscoree,mshtml="
        export FONTCONFIG_FILE="${fontsConf}"

        # ── 确保 XDG_RUNTIME_DIR 有效 ──
        if [ -z "''${XDG_RUNTIME_DIR:-}" ]; then
          export XDG_RUNTIME_DIR="/run/user/$(id -u 2>/dev/null || echo 1000)"
          if [ ! -d "$XDG_RUNTIME_DIR" ]; then
            export XDG_RUNTIME_DIR="/tmp/user-$(id -u 2>/dev/null || echo 1000)-runtime"
            mkdir -p "$XDG_RUNTIME_DIR" 2>/dev/null || true
            chmod 700 "$XDG_RUNTIME_DIR" 2>/dev/null || true
          fi
        fi

        link_fonts() {
          mkdir -p "$PREFIX_DIR/drive_c/windows/Fonts"
          ${lib.concatMapStringsSep "\n" (pkg: ''
            if [ -d "${pkg}/share/fonts" ]; then
              find "${pkg}/share/fonts" -type f \( -iname "*.ttf" -o -iname "*.ttc" -o -iname "*.otf" \) \
                -exec ln -sf {} "$PREFIX_DIR/drive_c/windows/Fonts/" \; 2>/dev/null || true
            fi
          '') allFontPackages}
        }

        apply_registries() {
          ${lib.concatMapStringsSep "\n" (reg: ''
            if [ -f "${reg}" ]; then
              wine regedit /S "${reg}" 2>/dev/null || true
            fi
          '') allRegFiles}
          wineserver -w
        }

        setup_drives() {
          mkdir -p "$PREFIX_DIR/dosdevices"
          # 确保全局 Z: 盘正确映射至沙箱根目录，保证 Wine 能够将沙箱内的 Linux 绝对路径 (如 /tmp, /data, ~/.cache)
          # 透明转换为 Windows DOS 路径，避免 ShellExecuteEx 因盘符缺失找不到文件
          ln -sfn "/" "$PREFIX_DIR/dosdevices/z:" 2>/dev/null || true

          # 声明式映射常用虚拟驱动器盘符 (如 D: 映射到 Downloads, E: 映射到 Games)
          ${lib.concatStringsSep "\n" (lib.mapAttrsToList (drive: target: ''
            mkdir -p "$SANDBOX_ROOT/${target}"
            ln -sfn "$SANDBOX_ROOT/${target}" "$PREFIX_DIR/dosdevices/${drive}" 2>/dev/null || true
          '') wineCfg.drives)}
        }

        setup_dxvk() {
          ${lib.optionalString wineCfg.dxvk ''
            if command -v setup_dxvk.sh &>/dev/null; then
              setup_dxvk.sh install --symlink 2>/dev/null || true
              wineserver -w
            fi
          ''}
        }

        # ── 状态机检测与初始化 ──
        if [ ! -f "$META_FILE" ]; then
          echo ">>> [WineApp] 正在为 ${pname} 初始化隔离容器 (WINEPREFIX: $PREFIX_DIR)..."
          mkdir -p "$PREFIX_DIR"

          # 1. 静默创建骨架
          wineboot -u
          wineserver -w

          # 2. 注入 CJK 字体软链接
          link_fonts

          # 3. 下发声明式注册表配置
          apply_registries

          # 4. DXVK 驱动部署 (若启用)
          setup_dxvk

          # 5. 虚拟驱动器盘符初始化
          setup_drives

          # 6. 写入版本标记
          echo "$CURRENT_HASH" > "$META_FILE"
          echo ">>> [WineApp] ${pname} 容器初始化完成。"
        elif [ "$(cat "$META_FILE" 2>/dev/null || true)" != "$CURRENT_HASH" ]; then
          echo ">>> [WineApp] 检测到 ${pname} 版本更新，正在执行增量配置同步..."
          wineboot -u
          wineserver -w
          link_fonts
          apply_registries
          setup_dxvk
          setup_drives
          echo "$CURRENT_HASH" > "$META_FILE"
          echo ">>> [WineApp] ${pname} 增量配置同步完成。"
        else
          # 每次启动确保盘符软链接健康
          setup_drives
        fi

        # ── 预执行钩子 ──
        ${preRunLines}

        # ── 切换工作目录 ──
        ${if runDir != null then "cd \"${runDir}\"" else ""}

        # ── 启动主应用程序与多命令路由 ──
        CALL_CMD="''${SANDBOX_CALL_CMD:-$(basename "$0" 2>/dev/null || echo "")}"

        # 兼容直接输入 `wine winetricks ...` 或 `wine winecfg` 的调用方式
        if [ "$CALL_CMD" = "wine" ] || [ "$CALL_CMD" = "${pname}" ] || [ -z "$CALL_CMD" ] || [ "$CALL_CMD" = "${pname}-wine-run" ]; then
          case "''${1:-}" in
            winetricks|winecfg|wineserver|regedit|winefile|wineboot)
              CALL_CMD="$1"
              shift
              ;;
          esac
        fi

        case "$CALL_CMD" in
          winecfg)
            wine winecfg "$@"
            APP_EXIT_CODE=$?
            ;;
          winetricks)
            winetricks "$@"
            APP_EXIT_CODE=$?
            ;;
          wineserver)
            wineserver "$@"
            APP_EXIT_CODE=$?
            ;;
          regedit)
            wine regedit "$@"
            APP_EXIT_CODE=$?
            ;;
          winefile)
            wine winefile "$@"
            APP_EXIT_CODE=$?
            ;;
          wineboot)
            wineboot "$@"
            APP_EXIT_CODE=$?
            ;;
          *)
            ${if winExecPath != null then ''
              echo ">>> [WineApp] 正在启动 ${pname}..."
              wine "${targetBin}" "$@"
              APP_EXIT_CODE=$?
            '' else ''
              if [ $# -eq 0 ]; then
                echo ">>> [WineApp] 未指定运行参数，启动 Wine 资源管理器 (explorer.exe)..."
                wine explorer.exe 2>/dev/null || true
                APP_EXIT_CODE=$?
              else
                wine "$@"
                APP_EXIT_CODE=$?
              fi
            ''}
            ;;
        esac

        # ── 进程清理与守护 (非 wineserver 命令时等待) ──
        if [ "$CALL_CMD" != "wineserver" ]; then
          ${lib.optionalString wineCfg.waitWineserver "wineserver -w"}
        fi

        exit $APP_EXIT_CODE
      '';
    in
    { inherit profile runScript; };
}
