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
  iconStrategy ? "hicolor",      # "hicolor" | "firefox-sizes" | "custom" | "none"
  customPostBuild ? "",          # symlinkJoin 的自定义 postBuild 逻辑
  aliases ? [],                  # 可执行命令别名列表 (如 [ "firefox-devedition" ])
  postUnpack ? "",               # 解包后的自定义处理逻辑
}:

let
  sandboxName = sandbox.name or pname;

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

  # 4. 构造 Bubblewrap 隔离参数
  bwrapArgs = profilesLib.makeBwrapArgs ({
    inherit sandboxName;
  } // sandbox);

  # 5. 生成容器内部的 Launcher 脚本
  launcherScript = pkgs.writeShellScript "${pname}-launcher" ''
    # 自动 Wayland 环境适配
    if [ -n "$WAYLAND_DISPLAY" ]; then
      export GDK_BACKEND=wayland,x11
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

  # 6. 构建 FHS 运行环境
  fhs = pkgs.buildFHSEnv {
    name = "${pname}-fhs";
    targetPkgs = resolvedTargetPkgs;
    extraBwrapArgs = bwrapArgs;
    runScript = launcherScript;
  };

  # 7. 生成宿主机 Wrapper 包装器脚本
  wrapper = pkgs.writeShellScriptBin binaryName ''
    SANDBOX_HOME="''${XDG_DATA_HOME:-$HOME/.local/share}/sandboxes/${sandboxName}"
    mkdir -p "$SANDBOX_HOME"
    ${lib.concatStringsSep "\n" (map (dir: "mkdir -p \"$SANDBOX_HOME/${dir}\"") hostDirs)}

    exec "${fhs}/bin/${pname}-fhs" "$@"
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
  } // (builtins.removeAttrs desktop [ "desktopName" "genericName" "comment" "icon" "terminal" "categories" ]));

  # 9. 图标安装 PostBuild Hook 生成
  iconPostBuild =
    if iconStrategy == "hicolor" then ''
      mkdir -p $out/share/icons/hicolor
      if [ -d "${unpacked}/share/icons/hicolor" ]; then
        cp -rn ${unpacked}/share/icons/hicolor/* $out/share/icons/hicolor/
      fi
    ''
    else if iconStrategy == "firefox-sizes" then ''
      for size in 16 32 48 64 128; do
        icon_file="${unpacked}/browser/chrome/icons/default/default''${size}.png"
        if [ -f "$icon_file" ]; then
          mkdir -p "$out/share/icons/hicolor/''${size}x''${size}/apps"
          cp "$icon_file" "$out/share/icons/hicolor/''${size}x''${size}/apps/${pname}.png"
          ${lib.concatStringsSep "\n" (map (alias: ''
            cp "$icon_file" "$out/share/icons/hicolor/''${size}x''${size}/apps/${alias}.png"
          '') aliases)}
        fi
      done
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
  };
}
