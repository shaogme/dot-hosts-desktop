{ lib }:

{
  # 类型化 Bubblewrap 参数生成器 (取代 profiles.nix makeBwrapArgs).
  # 破坏性: 封闭参数集, customBinds/customRoBinds 已更名为 extraBinds/extraRoBinds,
  # 开放 `sandbox // extra` 合并已删除.
  #
  # 输入均为静态值, 输出为字符串列表 (单次求值, 无运行时分支).
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
    , shareTheme ? true
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

      # 静态去重: 调用侧已保证集合语义, 此处仅拼接常量 (O(1) 评估, 无 lib.unique).
      effectiveSharedDirs =
        (lib.optionals shareDownloads defaultDownloadsDirs)
        ++ sharedDirs;

      effectiveRoSharedDirs =
        (lib.optionals shareUserDirs defaultUserDirs)
        ++ roSharedDirs;

      formatBindArg = dir:
        if lib.hasPrefix "/" dir then [ dir dir ]
        else [ "\$HOME/${dir}" "\$HOME/${dir}" ];
    in
    lib.optionals isolatedHome [
      "--tmpfs" "$HOME"
      "--bind" sandboxHome "$HOME"
    ]
    ++ lib.optionals isolatedHome (
      (lib.concatMap (dir: [ "--bind-try" ] ++ (formatBindArg dir)) effectiveSharedDirs)
      ++ (lib.concatMap (dir: [ "--ro-bind-try" ] ++ (formatBindArg dir)) effectiveRoSharedDirs)
    )
    ++ lib.optionals (isolatedHome && shareTheme) [
      "--ro-bind-try" "\${XDG_CONFIG_HOME:-\$HOME/.config}/gtk-3.0" "\${XDG_CONFIG_HOME:-\$HOME/.config}/gtk-3.0"
      "--ro-bind-try" "\${XDG_CONFIG_HOME:-\$HOME/.config}/gtk-4.0" "\${XDG_CONFIG_HOME:-\$HOME/.config}/gtk-4.0"
      "--ro-bind-try" "\${XDG_CONFIG_HOME:-\$HOME/.config}/dconf" "\${XDG_CONFIG_HOME:-\$HOME/.config}/dconf"
      "--ro-bind-try" "\$HOME/.config/dconf" "\$HOME/.config/dconf"
      "--ro-bind-try" "\${XDG_RUNTIME_DIR:-/run/user/1000}/desktop-theme" "\${XDG_RUNTIME_DIR:-/run/user/1000}/desktop-theme"
      "--ro-bind-try" "\${XDG_RUNTIME_DIR:-/run/user/1000}/darkman" "\${XDG_RUNTIME_DIR:-/run/user/1000}/darkman"
      "--ro-bind-try" "\${XDG_DATA_HOME:-\$HOME/.local/share}/icons" "\${XDG_DATA_HOME:-\$HOME/.local/share}/icons"
      "--ro-bind-try" "\$HOME/.icons" "\$HOME/.icons"
    ]
    ++ lib.optionals bypassProxy [
      "--unshare-user"
      "--gid" "1992"
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
    ++ lib.optionals dbus [
      "--ro-bind-try" "\${XDG_RUNTIME_DIR:-/run/user/1000}/bus" "\${XDG_RUNTIME_DIR:-/run/user/1000}/bus"
      "--bind-try" "\${XDG_RUNTIME_DIR:-/run/user/1000}/dconf" "\${XDG_RUNTIME_DIR:-/run/user/1000}/dconf"
      "--ro-bind-try" "/var/run/dbus/system_bus_socket" "/var/run/dbus/system_bus_socket"
    ]
    ++ lib.optionals inputMethod [
      "--ro-bind-try" "\${XDG_RUNTIME_DIR:-/run/user/1000}/fcitx5" "\${XDG_RUNTIME_DIR:-/run/user/1000}/fcitx5"
      "--ro-bind-try" "\${XDG_RUNTIME_DIR:-/run/user/1000}/ibus" "\${XDG_RUNTIME_DIR:-/run/user/1000}/ibus"
      "--ro-bind-try" "\${XDG_RUNTIME_DIR:-/run/user/1000}/fcitx" "\${XDG_RUNTIME_DIR:-/run/user/1000}/fcitx"
    ]
    ++ lib.optional shareNet "--share-net"
    ++ (lib.concatMap (b: [ "--bind" (builtins.elemAt b 0) (builtins.elemAt b 1) ]) extraBinds)
    ++ (lib.concatMap (b: [ "--ro-bind-try" (builtins.elemAt b 0) (builtins.elemAt b 1) ]) extraRoBinds)
    ++ extraBwrapArgs;
}
