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

      # 验证窗口管理器 (Hyprland)、启动器 (Wofi) 与电源中心 (wlogout)
      if ${if serverCfg.desktop.windowManager.hyprland.enable or false then "True" else "False"}:
          server.succeed("which Hyprland")
          server.succeed("which start-hyprland")
          server.succeed("test -f /etc/xdg/hypr/hyprland.lua")
          server.succeed("test -f /etc/hypr/hyprland.lua")
          server.succeed("test -f /etc/xdg/wofi/config")
          server.succeed("test -f /etc/wofi/config")
          server.succeed("grep -q 'mode=drun' /etc/wofi/config")
          server.succeed("which xdg-terminal-exec")
          server.succeed("test -f /etc/xdg/xdg-terminals.list")
          server.succeed("grep -q 'kitty.desktop' /etc/xdg/xdg-terminals.list")
          server.succeed("test -f /etc/xdg/hyprland-xdg-terminals.list")
          server.succeed("grep -q 'kitty.desktop' /etc/xdg/hyprland-xdg-terminals.list")
          if ${if serverCfg.desktop.windowManager.hyprland.powerMenu.enable or false then "True" else "False"}:
              server.succeed("which wlogout")
              server.succeed("which wlogout-menu")
              server.succeed("test -f /etc/xdg/waybar/config.jsonc")
              server.succeed("test -f /etc/wlogout/layout")
              server.succeed("test -f /etc/wlogout/style.css")

      # 验证 Wi-Fi 管理支持 (Hyprland 与 Packages)
      if ${if serverCfg.desktop.packages.wifi.enable or false then "True" else "False"}:
          server.succeed("which nmcli")
          server.succeed("which nmtui")
          server.succeed("which iw")

      if ${if serverCfg.desktop.windowManager.hyprland.wifi.enable or false then "True" else "False"}:
          server.succeed("which nm-applet")

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

      print("VM 测试全部通过！")
    '';
}
