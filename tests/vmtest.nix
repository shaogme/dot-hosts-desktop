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

      if ${if serverCfg.desktop.apps.v2rayn.enable or false then "True" else "False"}:
          server.succeed("which v2rayn")
          server.succeed("test -f /run/current-system/sw/share/applications/v2rayn.desktop")
          server.succeed("test -f /run/current-system/sw/share/icons/hicolor/256x256/apps/v2rayn.png")

      # 验证登录管理器 (tuigreet)
      if ${if serverCfg.desktop.loginManager.tuigreet.enable or false then "True" else "False"}:
          server.succeed("which tuigreet")
          server.succeed("test -f /etc/tuigreet/config.toml")
          server.succeed("test -d /var/cache/tuigreet")

      print("VM 测试全部通过！")
    '';
}
