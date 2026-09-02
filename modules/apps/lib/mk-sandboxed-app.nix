{ pkgs, lib ? pkgs.lib }:

let
  profilesLib = import ./profiles.nix { inherit pkgs lib; };
  unpackersLib = import ./unpackers.nix { inherit pkgs lib; };
in
{
  pname,
  version,
  src,
  srcType ? "deb",               # "deb" | "tarball" | "custom"
  execPath,                      # 目标可执行文件相对于 unpacked 根目录的相对路径 (如 "bin/clash-verge" 或 "firefox")
  binaryName ? pname,            # 宿主机生成的命令名称 (默认等于 pname)

  # 依赖集配置
  profiles ? [ "desktop-gui" ],  # 依赖 Profile 列表 (如 [ "desktop-gui" "webkitgtk" ])
  extraPkgs ? (pkgs: []),        # 额外定制的 targetPkgs 依赖函数

  # 透明代理防回环豁免
  bypassProxy ? false,           # 是否豁免 TUN 代理 (绑定 GID 1992 proxy-bypass 并直连出站)

  # 沙箱与隔离配置
  sandbox ? {},                  # 传递给 makeBwrapArgs 的参数 (如 isolatedHome, shareNet, customBinds)
  hostDirs ? [],                 # 宿主机需要初始化的目录 (相对于沙箱根目录)
  sandboxDirs ? [],              # 容器内部需要初始化的目录 (相对于 $HOME)

  # 环境变量与启动逻辑
  environment ? {},              # 容器内启动环境变量键值对
  preRunHook ? "",               # 容器内启动主程序前的自定义 Bash 代码 (支持接收 unpacked 的函数)
  runInDirectory ? null,         # 启动可执行文件前切换的目录 (支持相对路径或接收 unpacked 的函数)

  # Desktop Entry 与图标配置
  desktop ? {},                  # pkgs.makeDesktopItem 传参
  iconStrategy ? "auto",         # "auto" | "hicolor" | "firefox-sizes" | "custom" | "none"
  customPostBuild ? "",          # symlinkJoin 的自定义 postBuild 逻辑
  aliases ? [],                  # 可执行命令别名列表 (如 [ "firefox-devedition" ])
  postUnpack ? "",               # 解包后的自定义处理逻辑
  extraBuildCommands ? "",       # FHS 根文件系统构建期的自定义命令 (如创建软链接或额外文件)
  windowRules ? [],              # 该应用的 Hyprland 专用窗口规则列表 (window_rule)
  hyprlandRules ? [],            # 别名: 等同于 windowRules
}:

let
  sandboxName = sandbox.name or pname;
  effectiveWindowRules = lib.unique (windowRules ++ hyprlandRules);

  # 1. 解包上游二进制资源
  unpacked = unpackersLib.mkUnpackedDerivation {
    inherit pname version src srcType postUnpack;
  };

  # 2. 解析预运行 Hook 与工作目录
  resolvedPreRunHook =
    if lib.isFunction preRunHook then preRunHook unpacked
    else preRunHook;

  resolvedRunInDirectory =
    if lib.isFunction runInDirectory then runInDirectory unpacked
    else if runInDirectory != null then
      (if lib.hasPrefix "/" runInDirectory then runInDirectory else "${unpacked}/${runInDirectory}")
    else null;

  # 3. 合并所有 Profile 与自定义依赖
  resolvedTargetPkgs = pkgs:
    let
      profilePkgs = lib.concatMap (profName:
        if profilesLib.pkgProfiles ? ${profName} then
          profilesLib.pkgProfiles.${profName} pkgs
        else
          throw "Unknown dependency profile: '${profName}'"
      ) profiles;
      customPkgs = if lib.isFunction extraPkgs then extraPkgs pkgs else extraPkgs;
    in
    lib.unique (profilePkgs ++ customPkgs);

  effectiveBypassProxy = sandbox.bypassProxy or bypassProxy;

  # 4. 构造 Bubblewrap 隔离参数
  bwrapArgs = profilesLib.makeBwrapArgs ({
    inherit sandboxName;
    bypassProxy = effectiveBypassProxy;
  } // sandbox);

  # 5. 生成容器内部的 Launcher 脚本
  launcherScript = pkgs.writeShellScript "${pname}-launcher" ''
    # 自动 Wayland 与 XWayland / X11 环境适配
    if [ -n "$WAYLAND_DISPLAY" ]; then
      export GDK_BACKEND=wayland,x11
      export QT_QPA_PLATFORM="wayland;xcb"
      export CLUTTER_BACKEND=wayland
      export SDL_VIDEODRIVER="wayland,x11,windows"
      export ELECTRON_OZONE_PLATFORM_HINT="auto"
      export NIXOS_OZONE_WL="1"
    else
      export GDK_BACKEND=x11
      export QT_QPA_PLATFORM=xcb
    fi

    # Qt 框架高分屏缩放与渲染清晰度优化 (避免分数缩放模糊与双重标题栏)
    export QT_AUTO_SCREEN_SCALE_FACTOR="1"
    export QT_WAYLAND_DISABLE_WINDOWDECORATION="1"
    export QT_SCALE_FACTOR_ROUNDING_POLICY="PassThrough"

    # Java / AWT 窗口管理器无父重定优化 (避免平铺 WM 窗口白屏/灰屏)
    export _JAVA_AWT_WM_NONREPARENTING="1"

    # 自动输入法环境适配
    if [ -z "''${XMODIFIERS:-}" ]; then
      export XMODIFIERS="@im=fcitx"
    fi
    if [ -n "$WAYLAND_DISPLAY" ]; then
      unset GTK_IM_MODULE
    elif [ -z "''${GTK_IM_MODULE:-}" ]; then
      export GTK_IM_MODULE="fcitx"
    fi
    if [ -z "''${QT_IM_MODULE:-}" ]; then
      export QT_IM_MODULE="fcitx"
    fi
    if [ -z "''${SDL_IM_MODULE:-}" ]; then
      export SDL_IM_MODULE="fcitx"
    fi
    if [ -z "''${GLFW_IM_MODULE:-}" ]; then
      export GLFW_IM_MODULE="ibus"
    fi

    # 导出自定义环境变量
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "export ${k}=\"${toString v}\"") environment)}

    # 容器内沙箱目录预建
    ${lib.concatStringsSep "\n" (map (dir: "mkdir -p \"$HOME/${dir}\"") sandboxDirs)}

    # 执行启动前预处理 Hook
    ${resolvedPreRunHook}

    ${if resolvedRunInDirectory != null then "cd \"${resolvedRunInDirectory}\"" else ""}
    exec "${unpacked}/${execPath}" "$@"
  '';

  resolvedExtraBuildCommands =
    if lib.isFunction extraBuildCommands then extraBuildCommands pkgs
    else extraBuildCommands;

  # 6. 构建 FHS 运行环境
  fhs = pkgs.buildFHSEnv {
    name = "${pname}-fhs";
    targetPkgs = resolvedTargetPkgs;
    extraBwrapArgs = bwrapArgs;
    extraBuildCommands = resolvedExtraBuildCommands;
    runScript = launcherScript;
    unshareUser = effectiveBypassProxy;
  };

  # 7. 生成宿主机 Wrapper 包装器脚本
  wrapper = pkgs.writeShellScriptBin binaryName ''
    SANDBOX_HOME="''${XDG_DATA_HOME:-$HOME}/.sandboxes/${sandboxName}"
    mkdir -p "$SANDBOX_HOME"
    ${lib.concatStringsSep "\n" (map (dir: "mkdir -p \"$SANDBOX_HOME/${dir}\"") hostDirs)}

    if [ -n "$XDG_RUNTIME_DIR" ]; then
      mkdir -p "$XDG_RUNTIME_DIR/dconf"
    fi

    ${if effectiveBypassProxy then ''
      SG_BIN="$(command -v sg 2>/dev/null || true)"
      if [ -z "$SG_BIN" ] && [ -x "/run/wrappers/bin/sg" ]; then
        SG_BIN="/run/wrappers/bin/sg"
      fi

      USER_NAME="$(whoami 2>/dev/null || echo "$USER")"
      IS_MEMBER=0
      if id -G 2>/dev/null | grep -qw 1992 || id -nG 2>/dev/null | grep -qw proxy-bypass; then
        IS_MEMBER=1
      elif [ -f /etc/group ] && grep -E "^proxy-bypass:.*[ :,]$USER_NAME($|,)" /etc/group >/dev/null 2>&1; then
        IS_MEMBER=1
      fi

      if [ "$IS_MEMBER" = "1" ] && [ -n "$SG_BIN" ]; then
        exec "$SG_BIN" proxy-bypass -c "${fhs}/bin/${pname}-fhs \"\$@\""
      else
        exec "${fhs}/bin/${pname}-fhs" "$@"
      fi
    '' else ''
      exec "${fhs}/bin/${pname}-fhs" "$@"
    ''}
  '';

  # 8. 生成 XDG Desktop Entry
  desktopItem = pkgs.makeDesktopItem ({
    name = pname;
    desktopName = desktop.desktopName or pname;
    genericName = desktop.genericName or "Application";
    comment = desktop.comment or "${pname} (Bubblewrap Isolated)";
    exec = "${binaryName} %U";
    icon = desktop.icon or pname;
    terminal = desktop.terminal or false;
    type = "Application";
    categories = desktop.categories or [ "Utility" ];
    startupWMClass = desktop.startupWMClass or pname;
  } // (builtins.removeAttrs desktop [ "desktopName" "genericName" "comment" "icon" "terminal" "categories" "startupWMClass" ]));

  # 9. 图标安装 PostBuild Hook 生成
  iconPostBuild =
    if iconStrategy == "auto" || iconStrategy == "hicolor" then ''
      if [ -d "${unpacked}/share/icons" ]; then
        mkdir -p $out/share/icons
        cp -rn ${unpacked}/share/icons/* $out/share/icons/
        chmod -R u+w $out/share/icons
      fi
      if [ -d "${unpacked}/share/pixmaps" ]; then
        mkdir -p $out/share/pixmaps
        cp -rn ${unpacked}/share/pixmaps/* $out/share/pixmaps/
        chmod -R u+w $out/share/pixmaps
      fi

      # 补充 HiDPI / 特殊目录到基础目录的回退与别名映射
      if [ -d "$out/share/icons/hicolor" ]; then
        if [ -d "$out/share/icons/hicolor/256x256@2/apps" ] && [ ! -d "$out/share/icons/hicolor/256x256/apps" ]; then
          mkdir -p "$out/share/icons/hicolor/256x256/apps"
          for f in "$out/share/icons/hicolor/256x256@2/apps"/*; do
            if [ -f "$f" ]; then
              ln -sf "$f" "$out/share/icons/hicolor/256x256/apps/$(basename "$f")"
            fi
          done
        fi

        ${lib.concatStringsSep "\n" (map (alias: ''
          for icon_dir in "$out"/share/icons/hicolor/*/apps; do
            if [ -d "$icon_dir" ]; then
              for ext in png svg xpm; do
                if [ -f "$icon_dir/${pname}.$ext" ] && [ ! -f "$icon_dir/${alias}.$ext" ]; then
                  ln -sf "$icon_dir/${pname}.$ext" "$icon_dir/${alias}.$ext"
                fi
              done
            fi
          done
          if [ -d "$out/share/pixmaps" ]; then
            for ext in png svg xpm; do
              if [ -f "$out/share/pixmaps/${pname}.$ext" ] && [ ! -f "$out/share/pixmaps/${alias}.$ext" ]; then
                ln -sf "$out/share/pixmaps/${pname}.$ext" "$out/share/pixmaps/${alias}.$ext"
              fi
            done
          fi
        '') aliases)}
      fi
    ''
    else if iconStrategy == "firefox-sizes" then ''
      for size in 16 24 32 48 64 128 256; do
        icon_file="${unpacked}/browser/chrome/icons/default/default''${size}.png"
        if [ -f "$icon_file" ]; then
          mkdir -p "$out/share/icons/hicolor/''${size}x''${size}/apps"
          cp "$icon_file" "$out/share/icons/hicolor/''${size}x''${size}/apps/${pname}.png"
          ${lib.concatStringsSep "\n" (map (alias: ''
            cp "$icon_file" "$out/share/icons/hicolor/''${size}x''${size}/apps/${alias}.png"
          '') aliases)}
        fi
      done
      if [ -f "${unpacked}/browser/chrome/icons/default/default128.png" ]; then
        mkdir -p "$out/share/pixmaps"
        cp "${unpacked}/browser/chrome/icons/default/default128.png" "$out/share/pixmaps/${pname}.png"
        ${lib.concatStringsSep "\n" (map (alias: ''
          cp "${unpacked}/browser/chrome/icons/default/default128.png" "$out/share/pixmaps/${alias}.png"
        '') aliases)}
      fi
    ''
    else "";

  # 10. 别名软链接生成
  aliasPostBuild = lib.concatStringsSep "\n" (map (alias: ''
    ln -s "${binaryName}" "$out/bin/${alias}"
  '') aliases);

in
pkgs.symlinkJoin {
  name = "${pname}-${version}";
  paths = [
    wrapper
    desktopItem
  ];
  postBuild = ''
    ${aliasPostBuild}
    ${iconPostBuild}
    ${customPostBuild}
  '';
  passthru = {
    inherit unpacked fhs;
    windowRules = effectiveWindowRules;
  };
}
