{ lib }:

{
  # 类型化 Bubblewrap 参数生成器
  makeBwrapArgs =
    { sandboxName
    , isolatedHome ? true
    , shareNet ? true
    , wayland ? true
    , x11 ? true
    , audio ? true
    , dbus ? true
    , inputMethod ? true
    , bypassProxy ? false
    , shareDownloads ? true
    , shareUserDirs ? false
    , shareData ? true
    , shareMedia ? true
    , shareGames ? false
    , shareInput ? false
    , shareShm ? true
    , shareThemeStatic ? true
    , shareThemeLive ? true
    , sharedDirs ? [ ]
    , roSharedDirs ? [ ]
    , extraBinds ? [ ]
    , extraRoBinds ? [ ]
    , extraBwrapArgs ? [ ]
    }:
    let
      sandboxHome = "\${XDG_DATA_HOME:-$HOME}/.sandboxes/${sandboxName}";

      defaultUserDirs = [
        "Desktop" "桌面"
        "Documents" "文档"
        "Pictures" "图片"
        "Videos" "视频"
        "Music" "音乐"
      ];

      defaultDownloadsDirs = [
        "Downloads" "下载"
      ];

      defaultDataDirs = [
        "/data"
      ];

      defaultMediaDirs = [
        "/mnt"
        "/media"
        "/run/media"
      ];

      defaultGameDirs = [
        "Games" "游戏"
      ];

      # 静态去重: 调用侧已保证集合语义, 此处仅拼接常量 (O(1) 评估, 无 lib.unique).
      effectiveSharedDirs =
        (lib.optionals shareDownloads defaultDownloadsDirs)
        ++ (lib.optionals shareData defaultDataDirs)
        ++ (lib.optionals shareMedia defaultMediaDirs)
        ++ (lib.optionals shareGames defaultGameDirs)
        ++ sharedDirs;

      effectiveRoSharedDirs =
        (lib.optionals shareUserDirs defaultUserDirs)
        ++ roSharedDirs;

      formatBindArg = rawDir:
        let
          dir = if rawDir != "/" && lib.hasSuffix "/" rawDir then lib.removeSuffix "/" rawDir else rawDir;
        in
        if lib.hasPrefix "/" dir then [ dir dir ]
        else [ "\$HOME/${dir}" "\$HOME/${dir}" ];
    in
    lib.optionals isolatedHome [
      "--tmpfs" "$HOME"
      "--bind" sandboxHome "$HOME"
    ]
    ++ (
      let
        dirsToBind = if isolatedHome then effectiveSharedDirs else (lib.filter (d: lib.hasPrefix "/" d) effectiveSharedDirs);
        roDirsToBind = if isolatedHome then effectiveRoSharedDirs else (lib.filter (d: lib.hasPrefix "/" d) effectiveRoSharedDirs);
      in
      (lib.concatMap (dir: [ "--bind-try" ] ++ (formatBindArg dir)) dirsToBind)
      ++ (lib.concatMap (dir: [ "--ro-bind-try" ] ++ (formatBindArg dir)) roDirsToBind)
    )
    # 静态快照（icons/gtk ini）：关掉会连图标一起丢，允许按 App 关 live 但保持静态。
    ++ lib.optionals (isolatedHome && shareThemeStatic) [
      "--ro-bind-try" "\${XDG_CONFIG_HOME:-\$HOME/.config}/gtk-3.0" "\${XDG_CONFIG_HOME:-\$HOME/.config}/gtk-3.0"
      "--ro-bind-try" "\${XDG_CONFIG_HOME:-\$HOME/.config}/gtk-4.0" "\${XDG_CONFIG_HOME:-\$HOME/.config}/gtk-4.0"
      "--ro-bind-try" "\${XDG_DATA_HOME:-\$HOME/.local/share}/icons" "\${XDG_DATA_HOME:-\$HOME/.local/share}/icons"
      "--ro-bind-try" "\$HOME/.icons" "\$HOME/.icons"
    ]
    # live 快照（desktop-theme/darkman/dconf）：ro 快照，切换主题需重启 App 方可跟随。
    ++ lib.optionals (isolatedHome && shareThemeLive) [
      "--ro-bind-try" "\${XDG_CONFIG_HOME:-\$HOME/.config}/dconf" "\${XDG_CONFIG_HOME:-\$HOME/.config}/dconf"
      "--ro-bind-try" "\$HOME/.config/dconf" "\$HOME/.config/dconf"
      "--ro-bind-try" "\${XDG_RUNTIME_DIR:-/run/user/1000}/desktop-theme" "\${XDG_RUNTIME_DIR:-/run/user/1000}/desktop-theme"
      "--ro-bind-try" "\${XDG_RUNTIME_DIR:-/run/user/1000}/darkman" "\${XDG_RUNTIME_DIR:-/run/user/1000}/darkman"
    ]
    ++ lib.optionals wayland [
      "--ro-bind-try" "\${XDG_RUNTIME_DIR:-/run/user/1000}/\${WAYLAND_DISPLAY:-wayland-0}" "\${XDG_RUNTIME_DIR:-/run/user/1000}/\${WAYLAND_DISPLAY:-wayland-0}"
      "--ro-bind-try" "\${XDG_RUNTIME_DIR:-/run/user/1000}/wayland-0" "\${XDG_RUNTIME_DIR:-/run/user/1000}/wayland-0"
    ]
    ++ lib.optionals x11 [
      "--ro-bind-try" "\${XAUTHORITY:-\$HOME/.Xauthority}" "\${XAUTHORITY:-\$HOME/.Xauthority}"
    ]
    ++ lib.optionals audio [
      "--ro-bind-try" "\${XDG_RUNTIME_DIR:-/run/user/1000}/pulse" "\${XDG_RUNTIME_DIR:-/run/user/1000}/pulse"
      "--ro-bind-try" "\${XDG_RUNTIME_DIR:-/run/user/1000}/pipewire-0" "\${XDG_RUNTIME_DIR:-/run/user/1000}/pipewire-0"
    ]
    # bus 必须 rw（--bind-try）。Unix socket 新连接需要 socket 文件写权限，
    # ro-bind 会阻断沙箱内新发起的 portal/dbus 调用（已建连不受影响）。
    ++ lib.optionals dbus [
      "--bind-try" "\${XDG_RUNTIME_DIR:-/run/user/1000}/bus" "\${XDG_RUNTIME_DIR:-/run/user/1000}/bus"
      "--bind-try" "\${XDG_RUNTIME_DIR:-/run/user/1000}/dconf" "\${XDG_RUNTIME_DIR:-/run/user/1000}/dconf"
      "--ro-bind-try" "/var/run/dbus/system_bus_socket" "/var/run/dbus/system_bus_socket"
    ]
    ++ lib.optionals inputMethod [
      "--ro-bind-try" "\${XDG_RUNTIME_DIR:-/run/user/1000}/fcitx5" "\${XDG_RUNTIME_DIR:-/run/user/1000}/fcitx5"
      "--ro-bind-try" "\${XDG_RUNTIME_DIR:-/run/user/1000}/ibus" "\${XDG_RUNTIME_DIR:-/run/user/1000}/ibus"
      "--ro-bind-try" "\${XDG_RUNTIME_DIR:-/run/user/1000}/fcitx" "\${XDG_RUNTIME_DIR:-/run/user/1000}/fcitx"
    ]
    ++ lib.optionals shareShm [
      "--bind-try" "/dev/shm" "/dev/shm"
    ]
    ++ lib.optionals shareInput [
      "--dev-bind-try" "/dev/uinput" "/dev/uinput"
      "--dev-bind-try" "/dev/input" "/dev/input"
      "--ro-bind-try" "/run/udev" "/run/udev"
    ]
    ++ [
      "--ro-bind-try" "/run/opengl-driver" "/run/opengl-driver"
      "--ro-bind-try" "/run/opengl-driver-32" "/run/opengl-driver-32"
    ]
    ++ lib.optional shareNet "--share-net"
    ++ (lib.concatMap (b: [ "--bind" (builtins.elemAt b 0) (builtins.elemAt b 1) ]) extraBinds)
    ++ (lib.concatMap (b: [ "--ro-bind-try" (builtins.elemAt b 0) (builtins.elemAt b 1) ]) extraRoBinds)
    ++ extraBwrapArgs;
}
