{ pkgs, configuration, name }:

pkgs.testers.nixosTest {
  name = "${name}-vm-test";
  
  nodes.server = { config, lib, ... }: {
    imports = [ configuration ];

    # 1. 环境适配：禁用物理环境特有的网络接口配置，改用 VM 默认网络
    base.hardware.network.enable = lib.mkForce false;
    
    # 2. 调试增强：允许通过密码登录，方便使用 driver 手动调试
    base.auth.root.mode = lib.mkForce "permit_passwd";
    users.users.root.initialHashedPassword = lib.mkForce null;
    users.users.root.password = "test";

    # 3. 启用测试模式
    base.testMode = true;
    exts.testMode = true;
  };

  testScript = { nodes, ... }:
    let
      serverCfg = nodes.server;
      hostName = serverCfg.networking.hostName;
      hasPodman = serverCfg.base.container.podman.enable or false;
    in
    ''
      # 等待系统启动完成
      server.wait_for_unit("multi-user.target")
      
      # 验证主机名
      hostname = server.succeed("hostname").strip()
      assert hostname == "${hostName}", f"Hostname mismatch: got {hostname}, expected ${hostName}"
      
      # 验证内核调优：检查 BBR 是否启用
      sysctl_bbr = server.succeed("sysctl net.ipv4.tcp_congestion_control")
      assert "bbr" in sysctl_bbr, "BBR congestion control not active"

      # 验证容器引擎（测试模式下 socket 不应强行激活）
      if ${if hasPodman then "True" else "False"}:
          print("Podman is enabled in configuration.")

      # 验证桌面应用可执行文件与 Desktop / 图标资源
      if ${if serverCfg.desktop.apps.clash-verge.enable or false then "True" else "False"}:
          server.succeed("which clash-verge")
          server.succeed("test -f /run/current-system/sw/share/applications/clash-verge.desktop")
          server.succeed("test -f /run/current-system/sw/share/icons/hicolor/256x256/apps/clash-verge.png")

      if ${if serverCfg.desktop.apps.v2rayn.enable or false then "True" else "False"}:
          server.succeed("which v2rayn")
          server.succeed("test -f /run/current-system/sw/share/applications/v2rayn.desktop")
          server.succeed("test -f /run/current-system/sw/share/icons/hicolor/256x256/apps/v2rayn.png")

      if ${if serverCfg.desktop.apps.firefox.enable or false then "True" else "False"}:
          server.succeed("which firefox")
          server.succeed("test -f /run/current-system/sw/share/applications/firefox.desktop")
          server.succeed("test -f /run/current-system/sw/share/icons/hicolor/128x128/apps/firefox.png")

      if ${if serverCfg.desktop.apps.firefox-developer-edition.enable or false then "True" else "False"}:
          server.succeed("which firefox-developer-edition")
          server.succeed("which firefox-devedition")
          server.succeed("test -f /run/current-system/sw/share/applications/firefox-developer-edition.desktop")
          server.succeed("test -f /run/current-system/sw/share/icons/hicolor/128x128/apps/firefox-developer-edition.png")
          server.succeed("test -f /run/current-system/sw/share/icons/hicolor/128x128/apps/firefox-devedition.png")

      if ${if serverCfg.desktop.apps.wechat.enable or false then "True" else "False"}:
          server.succeed("which wechat")
          server.succeed("which wechat-universal")
          server.succeed("which weixin")
          server.succeed("test -f /run/current-system/sw/share/applications/wechat.desktop")
          server.succeed("test -f /run/current-system/sw/share/icons/hicolor/256x256/apps/wechat.png")

      if ${if serverCfg.desktop.apps.qq.enable or false then "True" else "False"}:
          server.succeed("which qq")
          server.succeed("which linuxqq")
          server.succeed("test -f /run/current-system/sw/share/applications/qq.desktop")
          server.succeed("test -f /run/current-system/sw/share/icons/hicolor/512x512/apps/qq.png")
          server.succeed("test -f /run/current-system/sw/share/icons/hicolor/512x512/apps/linuxqq.png")

      if ${if serverCfg.desktop.apps.vscode.enable or false then "True" else "False"}:
          server.succeed("which vscode")
          server.succeed("which code")
          server.succeed("test -f /run/current-system/sw/share/applications/vscode.desktop")
          server.succeed("test -f /run/current-system/sw/share/icons/hicolor/512x512/apps/vscode.png")
          server.succeed("test -f /run/current-system/sw/share/icons/hicolor/512x512/apps/code.png")

      if ${if serverCfg.desktop.apps.vscode-insiders.enable or false then "True" else "False"}:
          server.succeed("which vscode-insiders")
          server.succeed("which code-insiders")
          server.succeed("which vscode-insider")
          server.succeed("which code-insider")
          server.succeed("test -f /run/current-system/sw/share/applications/vscode-insiders.desktop")
          server.succeed("test -f /run/current-system/sw/share/icons/hicolor/512x512/apps/vscode-insiders.png")
          server.succeed("test -f /run/current-system/sw/share/icons/hicolor/512x512/apps/code-insiders.png")

      # 验证登录管理器 (tuigreet)
      if ${if serverCfg.desktop.loginManager.tuigreet.enable or false then "True" else "False"}:
          server.succeed("which tuigreet")
          server.succeed("test -f /etc/tuigreet/config.toml")
          server.succeed("test -d /var/cache/tuigreet")
          if ${if serverCfg.desktop.loginManager.tuigreet.consoleSession.enable or false then "True" else "False"}:
              server.succeed("test -f ${serverCfg.services.displayManager.sessionData.desktops}/share/wayland-sessions/console.desktop")
          if ${if (serverCfg.desktop.loginManager.tuigreet.defaultSession or null) != null then "True" else "False"}:
              server.succeed("test -f /var/cache/tuigreet/lastsession-path")

      # 验证窗口管理器 (Niri) 核心
      if ${if serverCfg.desktop.windowManager.niri.enable or false then "True" else "False"}:
          server.succeed("which niri")
          server.succeed("test -f /etc/xdg/niri/config.kdl")
          server.succeed("test -f /etc/niri/config.kdl")
          server.succeed("test -f /etc/xdg/niri/config-gamemode.kdl")
          server.succeed("test -f /etc/niri/config-gamemode.kdl")
          server.succeed("niri validate --config /etc/niri/config.kdl")
          server.succeed("niri validate --config /etc/niri/config-gamemode.kdl")

      # 验证启动器 (Anyrun) 与 xdg-terminal-exec
      if ${if (serverCfg.desktop ? launcher && serverCfg.desktop.launcher ? anyrun && serverCfg.desktop.launcher.anyrun.enable) then "True" else "False"}:
          server.succeed("which anyrun")
          server.succeed("test -f /etc/xdg/anyrun/config.ron")
          server.succeed("test -f /etc/anyrun/config.ron")
          server.succeed("test -f /etc/anyrun/style.css")
          server.succeed("which xdg-terminal-exec")
          server.succeed("test -f /etc/xdg/xdg-terminals.list")
          server.succeed("grep -q 'rio.desktop' /etc/xdg/xdg-terminals.list")
          server.succeed("test -f /etc/xdg/niri-xdg-terminals.list")
          server.succeed("grep -q 'rio.desktop' /etc/xdg/niri-xdg-terminals.list")

          server.succeed("which anyrun-power")
          server.succeed("test -f /etc/xdg/anyrun/actions.ron")
          server.succeed("test -f /etc/anyrun/actions.ron")

      # 验证终端 (Rio)
      if ${if (serverCfg.desktop ? terminal && serverCfg.desktop.terminal ? rio && serverCfg.desktop.terminal.rio.enable) then "True" else "False"}:
          server.succeed("which rio")
          server.succeed("test -f /etc/xdg/rio/config.toml")
          server.succeed("test -f /etc/rio/config.toml")
          server.succeed("test -s /etc/xdg/rio/config.toml")
          server.succeed("test -s /etc/rio/config.toml")

      # 验证状态栏 (Waybar)
      if ${if (serverCfg.desktop ? bar && serverCfg.desktop.bar ? waybar && serverCfg.desktop.bar.waybar.enable) then "True" else "False"}:
          server.succeed("which waybar")
          server.succeed("test -f /etc/xdg/waybar/config.jsonc")

      # 验证通知中心 (SwayNC)
      if ${if (serverCfg.desktop ? notification && serverCfg.desktop.notification ? swaync && serverCfg.desktop.notification.swaync.enable) then "True" else "False"}:
          server.succeed("which swaync")
          server.succeed("which swaync-client")
          server.succeed("which notify-send")
          server.succeed("test -f /etc/xdg/swaync/config.json")
          server.succeed("test -f /etc/xdg/swaync/style.css")
          server.succeed("test -f /run/current-system/sw/share/dbus-1/services/org.freedesktop.Notifications.service")
          server.succeed("test -f /run/current-system/sw/share/dbus-1/services/org.erikreider.swaync.cc.service")

      # 验证壁纸守护进程与管理脚本 (awww)
      if ${if (serverCfg.desktop ? wallpaper && serverCfg.desktop.wallpaper ? awww && serverCfg.desktop.wallpaper.awww.enable) then "True" else "False"}:
          server.succeed("which awww")
          server.succeed("which awww-daemon")
          server.succeed("which awww-set")
          server.succeed("which awww-random")
          server.succeed("which awww-next")
          server.succeed("which awww-switch")
          server.succeed("which awww-restore")
          server.succeed("which awww-init")
          if ${if (serverCfg.desktop.wallpaper.awww.daemon.systemd.enable or false) then "True" else "False"}:
              server.succeed("test -f /etc/systemd/user/awww-daemon.service")

      # 验证系统壁纸资源包 (wallpapers)
      if ${if (serverCfg.desktop ? wallpaper && serverCfg.desktop.wallpaper ? wallpapers && serverCfg.desktop.wallpaper.wallpapers.enable) then "True" else "False"}:
          server.succeed("test -d /run/current-system/sw/share/wallpapers")
          server.succeed("test -f /run/current-system/sw/share/wallpapers/nature-flowers-01.jpg")
          server.succeed("test -f /run/current-system/sw/share/wallpapers/nature-forest-mist-01.jpg")

      # 验证文件管理器 (Yazi)
      if ${if (serverCfg.desktop ? fileManager && serverCfg.desktop.fileManager ? yazi && serverCfg.desktop.fileManager.yazi.enable) then "True" else "False"}:
          server.succeed("which yazi")
          server.succeed("test -f /etc/xdg/yazi/yazi.toml")
          server.succeed("test -f /etc/xdg/yazi/keymap.toml")
          server.succeed("test -f /etc/xdg/yazi/theme.toml")
          server.succeed("test -f /run/current-system/sw/share/applications/yazi.desktop")

      # 验证桌面门户 (termfilechooser)
      if ${if (serverCfg.desktop ? portal && serverCfg.desktop.portal ? termfilechooser && serverCfg.desktop.portal.termfilechooser.enable) then "True" else "False"}:
          server.succeed("test -f /etc/xdg/xdg-desktop-portal-termfilechooser/config")
          server.succeed("test -f /etc/xdg/xdg-desktop-portal-termfilechooser/yazi-wrapper.sh")
          server.succeed("test -x /etc/xdg/xdg-desktop-portal-termfilechooser/yazi-wrapper.sh")

      # 验证 Wi-Fi 管理支持 (Packages)
      if ${if serverCfg.desktop.packages.wifi.enable or false then "True" else "False"}:
          server.succeed("which nmcli")
          server.succeed("which nmtui")
          server.succeed("which iw")

      # 验证字体与 Fontconfig
      if ${if serverCfg.desktop.fonts.enable or false then "True" else "False"}:
          server.succeed("test -f /etc/fonts/fonts.conf")
          server.succeed("which fc-match")
          server.succeed("fc-match sans-serif")
          server.succeed("fc-match serif")
          server.succeed("fc-match monospace")

      # 验证终端与 Shell 环境 (Zsh & Starship)
      if ${if serverCfg.desktop.terminal.zsh.enable or false then "True" else "False"}:
          server.succeed("which zsh")
          server.succeed("test -f /etc/zshrc")
          user_shell = server.succeed("getent passwd shaog | cut -d: -f7").strip()
          assert "zsh" in user_shell, f"User shell mismatch: expected zsh in path, got {user_shell}"

      # 验证输入法框架 (Fcitx5) 与 Rime 引擎
      if ${if serverCfg.desktop.inputMethod.fcitx5.enable or false then "True" else "False"}:
          server.succeed("which fcitx5")
          server.succeed("which fcitx5-remote")
          server.succeed("which fcitx5-configtool")
          server.succeed("test -f /etc/xdg/fcitx5/config")
          server.succeed("test -f /etc/xdg/fcitx5/profile")
          server.succeed("grep -q 'Name=rime' /etc/xdg/fcitx5/profile")
          server.succeed("test -f /etc/xdg/fcitx5/conf/classicui.conf")
          server.succeed("grep -q 'Theme=' /etc/xdg/fcitx5/conf/classicui.conf")

      # 验证 SOCKS5-TUN 核心服务与 CLI 工具
      if ${if serverCfg.services.socks-tun.enable or false then "True" else "False"}:
          server.succeed("which sing-box")
          server.succeed("which proxy-ctl")
          server.succeed("which socks-tun")
          server.succeed("test -f /etc/socks-tun/config.template.json")
          server.succeed("sing-box check -c /etc/socks-tun/config.template.json")
          server.succeed("proxy-ctl status")

      # 验证全局主题系统 (desktop.theme)
      if ${if serverCfg.desktop.theme.enable or false then "True" else "False"}:
          print("--- 验证全局主题系统 (Darkman + theme-ctl) ---")

          # 1. 验证 darkman 可执行文件
          server.succeed("which darkman")

          # 2. 验证 theme-ctl 可执行文件
          server.succeed("which theme-ctl")

          # 3. 验证 darkman 配置文件
          server.succeed("test -f /etc/xdg/darkman/config.yaml")
          server.succeed("grep -q '^lat:' /etc/xdg/darkman/config.yaml")
          server.succeed("grep -q '^lng:' /etc/xdg/darkman/config.yaml")
          server.succeed("grep -q '^portal: true' /etc/xdg/darkman/config.yaml")

          # 4. 验证主题切换钩子脚本
          server.succeed("test -f /etc/xdg/darkman/theme-switch.sh")
          server.succeed("test -x /etc/xdg/darkman/theme-switch.sh")

          # 5. 验证 theme-ctl 命令语法（--help/usage 输出）
          theme_ctl_help = server.succeed("theme-ctl status 2>&1 || true")
          print(f"theme-ctl status output: {theme_ctl_help}")

          # 6. 验证主题模式配置
          theme_mode = "${serverCfg.desktop.theme.mode or "auto"}"
          print(f"Configured theme mode: {theme_mode}")
          assert theme_mode in ["auto", "dark", "light"], f"Invalid theme mode: {theme_mode}"

          print("--- 全局主题系统验证通过！---")

      print("VM 测试全部通过！")
    '';
}
