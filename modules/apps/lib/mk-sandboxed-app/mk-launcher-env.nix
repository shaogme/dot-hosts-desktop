{ pkgs, lib }:

{
  # 构建期预烘焙环境与启动脚本.
  mkLauncherEnv =
    { pname
    , unpacked
    , execPath
    , env ? { }
    , preRunHooks ? [ ]
    , runInDirectory ? null
    }:
    let
      customExports = lib.concatStringsSep "\n"
        (lib.mapAttrsToList (k: v: "export ${k}=\"${toString v}\"") env);

      preRunLines = lib.concatStringsSep "\n" (map
        (h: builtins.replaceStrings [ "@UNPACKED@" ] [ (toString unpacked) ] (toString h))
        preRunHooks);

      runDir =
        if runInDirectory == null then null
        else if lib.hasPrefix "/" runInDirectory then runInDirectory
        else "${unpacked}/${runInDirectory}";

      profile = ''
        # ── ${pname}: Wayland / X11 静态适配 (单 if) ──
        if [ -n "$WAYLAND_DISPLAY" ]; then
          export GDK_BACKEND="wayland,x11"
          export QT_QPA_PLATFORM="wayland;xcb"
          export CLUTTER_BACKEND="wayland"
          export SDL_VIDEODRIVER="wayland,x11,windows"
          export ELECTRON_OZONE_PLATFORM_HINT="auto"
          export NIXOS_OZONE_WL="1"
        else
          export GDK_BACKEND="x11"
          export QT_QPA_PLATFORM="xcb"
        fi
        export QT_AUTO_SCREEN_SCALE_FACTOR="1"
        export QT_WAYLAND_DISABLE_WINDOWDECORATION="1"
        export QT_SCALE_FACTOR_ROUNDING_POLICY="PassThrough"
        export _JAVA_AWT_WM_NONREPARENTING="1"

        # ── 输入法 (shell 内建, 无 fork) ──
        : "''${XMODIFIERS:=@im=fcitx}"
        export XMODIFIERS
        if [ -n "$WAYLAND_DISPLAY" ]; then
          unset GTK_IM_MODULE
        else
          : "''${GTK_IM_MODULE:=fcitx}"
          export GTK_IM_MODULE
        fi
        : "''${QT_IM_MODULE:=fcitx}"
        export QT_IM_MODULE
        : "''${SDL_IM_MODULE:=fcitx}"
        export SDL_IM_MODULE
        : "''${GLFW_IM_MODULE:=ibus}"
        export GLFW_IM_MODULE

        # ── 主题 (启动时从 ro-bind 穿透的 live 文件读) ──
        # ro 快照 + “切换主题必须重启 App”（portal DBus SettingChanged 才是 live 通道，GTK 文件只是启动快照）。
        THEME_MODE_FILE="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/desktop-theme/mode"
        if [ -f "$THEME_MODE_FILE" ]; then
          if CURRENT_THEME_MODE="$(tr -d ' \n' < "$THEME_MODE_FILE")"; then
            case "$CURRENT_THEME_MODE" in dark|light) ;; *) echo "[launcher] warn: invalid mode $CURRENT_THEME_MODE, fallback to dark" >&2; CURRENT_THEME_MODE="dark" ;; esac
          else
            echo "[launcher] warn: failed to read $THEME_MODE_FILE, fallback to dark" >&2
            CURRENT_THEME_MODE="dark"
          fi
        else
          CURRENT_THEME_MODE="dark"
        fi
        export CURRENT_THEME_MODE
        export QT_QPA_PLATFORMTHEME="gtk3"
        # 不设 GSETTINGS_SCHEMA_DIR，靠 FHS targetPkgs 已含 gsettings-desktop-schemas + XDG_DATA_DIRS 穿透。
        ${customExports}
      '';

      targetBin = "${unpacked}/${execPath}";

      runScript =
        if preRunHooks == [ ] && runDir == null then
          targetBin
        else
          pkgs.writeShellScript "${pname}-run" ''
            ${preRunLines}
            ${if runDir != null then "cd \"${runDir}\"" else ""}
            exec "${targetBin}" "$@"
          '';
    in
    { inherit profile runScript; };
}
