{ config, pkgs, lib, modulesPath, ... }:

let
  # 导入由 npins 管理的依赖源
  sources = import ./npins;
  
  # 基础库和扩展库
  dot-base = import sources.dot-base { };
  dot-exts = import sources.dot-exts { };

  # 主机基础配置信息
  hostConfig = {
    name = "virtual-box";
    user = "shaog";

    auth = {
      # 你的 Hash 密码
      rootHash = "$6$o03HUIIXmYHQQlfy$cn03Aj2Dup1aKbrbyNqvQ//oJjimR66gE8krV1.ZU0k.ptFA.6FvVK.MQ4bWJiagIQKD1USvAKkEjm5VLU7Mw0";
      # SSH Keys
      sshKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFNCU2PbTCr6HbrCdthvfbfTeXBePXNei7ER13hwotjr hi@shaog.me" ];
    };
  };
in
{
  imports = [
    # 1. 引入模块库
    dot-base.nixosModules.default
    dot-exts.nixosModules.kernel.cachyos
    dot-exts.nixosModules.hardware.disk.btrfs
    # 2. 引入 Home Manager 模块
    "${sources.home-manager}/nixos"
    # 3. 引入公共模块集合
    ../../modules/default.nix
  ];

  # ==========================================
  # 通用系统配置 (Base)
  # ==========================================
  system.stateVersion = "26.11"; 
  
  # 启用 Lix 代替默认的 CppNix
  nix.package = pkgs.lixPackageSets.git.lix;
  
  # 基础功能启用
  base.enable = true;
  
  # Hardware 配置
  base.hardware.type = "physical";
  exts.hardware.disk.btrfs = {
      enable = true;
      device = "/dev/sda";
      swapSize = 4096;
      # 显式指定基础镜像大小（MB），用于 Disko 构建参考
      imageBaseSize = 8192; 
      partitions.root = {
        size = "100%";
        subvolumes = {
          "@" = { mountpoint = "/"; };
          "@home" = { mountpoint = "/home"; };
          "@nix" = { mountpoint = "/nix"; };
          "@log" = { mountpoint = "/var/log"; neededForBoot = true; };
        };
      };
  };

  # 虚拟机环境适配 (Hyprland / Wayland 兼容性)
  environment.sessionVariables = {
    WLR_NO_HARDWARE_CURSORS = "1";
    WLR_RENDERER_ALLOW_SOFTWARE = "1";
  };
  
  # 性能与内存调优
  base.performance.tuning.profile = "desktop-performance";
  base.memory.mode = "conservative";
  # 容器引擎
  base.container.podman.enable = true;
  
  # 系统自动更新与同步 (Legacy 模式)
  base.update = {
    enable = true;
    upgrade = {
      enable = false;
      type = "legacy";
      allowReboot = true;
    };
    sync = {
      enable = true;
      url = "https://github.com/shaogme/dot-hosts-desktop";
    };
    # 指定追踪 dot-hosts-desktop 仓库中的子路径
    path = "hosts/${hostConfig.name}"; 
  };

  # ==========================================
  # 桌面与图形环境 (Hyprland & Audio & Greetd)
  # ==========================================
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # 登录管理器 (tuigreet)
  desktop.loginManager.tuigreet = {
    enable = true;
    command = "Hyprland";
    display = {
      showTime = true;
    };
    remember = {
      username = true;
      session = true;
    };
  };

  # 音频服务支持 (PipeWire)
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # ==========================================
  # Home Manager 配置
  # ==========================================
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.${hostConfig.user} = { pkgs, ... }: {
      home.stateVersion = "26.11";

      # Wayland / Hyprland 窗口管理器配置
      wayland.windowManager.hyprland = {
        enable = true;
        systemd.enable = true;
        settings = {
          env = [
            "WLR_NO_HARDWARE_CURSORS,1"
            "WLR_RENDERER_ALLOW_SOFTWARE,1"
          ];

          "$mod" = "SUPER";
          "$terminal" = "kitty";
          "$menu" = "wofi --show drun";

          monitor = [
            ",preferred,auto,auto"
          ];

          exec-once = [
            "waybar"
            "dunst"
          ];

          general = {
            gaps_in = 5;
            gaps_out = 10;
            border_size = 2;
            layout = "dwindle";
          };

          decoration = {
            rounding = 8;
            blur = {
              enabled = true;
              size = 5;
              passes = 2;
            };
          };

          animations = {
            enabled = true;
          };

          bind = [
            "$mod, Return, exec, $terminal"
            "$mod, Q, killactive,"
            "$mod, M, exit,"
            "$mod, Space, exec, $menu"
            "$mod, V, togglefloating,"
            "$mod, F, fullscreen,"

            # 窗口焦点移动
            "$mod, left, movefocus, l"
            "$mod, right, movefocus, r"
            "$mod, up, movefocus, u"
            "$mod, down, movefocus, d"
            "$mod, h, movefocus, l"
            "$mod, l, movefocus, r"
            "$mod, k, movefocus, u"
            "$mod, j, movefocus, d"

            # 工作区切换 (1-9)
            "$mod, 1, workspace, 1"
            "$mod, 2, workspace, 2"
            "$mod, 3, workspace, 3"
            "$mod, 4, workspace, 4"
            "$mod, 5, workspace, 5"
            "$mod, 6, workspace, 6"
            "$mod, 7, workspace, 7"
            "$mod, 8, workspace, 8"
            "$mod, 9, workspace, 9"

            # 移动活动窗口至工作区
            "$mod SHIFT, 1, movetoworkspace, 1"
            "$mod SHIFT, 2, movetoworkspace, 2"
            "$mod SHIFT, 3, movetoworkspace, 3"
            "$mod SHIFT, 4, movetoworkspace, 4"
            "$mod SHIFT, 5, movetoworkspace, 5"
            "$mod SHIFT, 6, movetoworkspace, 6"
            "$mod SHIFT, 7, movetoworkspace, 7"
            "$mod SHIFT, 8, movetoworkspace, 8"
            "$mod SHIFT, 9, movetoworkspace, 9"
          ];

          bindm = [
            "$mod, mouse:272, movewindow"
            "$mod, mouse:273, resizewindow"
          ];
        };
      };

      # 用户环境常用 Wayland 桌面配套工具
      home.packages = with pkgs; [
        kitty
        waybar
        wofi
        wl-clipboard
        grim
        slurp
        dunst
        libnotify
      ];
    };
  };

  # ==========================================
  # 主机特有配置
  # ==========================================
  networking.hostName = hostConfig.name;
  
  # 硬件报告路径 (占位，待后续生成完整硬件报告)
  hardware.facter.reportPath = ./facter.json;

  # 关闭 VirtualBox Guest 增强驱动（避免高版本内核编译 vboxguest 驱动冲突）
  virtualisation.virtualbox.guest.enable = false;

  # 内核优化: 启用 CachyOS 内核
  exts.kernel.cachyos.enable = true;

  # 网络配置: 使用 NetworkManager 后端
  base.hardware.network = {
    enable = true;
    backend = "networkmanager";
  };
  
  # 认证与安全: 用户与 Root 配置
  base.auth.root = {
    mode = "default";
    initialHashedPassword = hostConfig.auth.rootHash;
    authorizedKeys = hostConfig.auth.sshKeys;
  };

  users.users.${hostConfig.user} = {
    isNormalUser = true;
    description = "Shaog";
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "input" ];
    initialHashedPassword = hostConfig.auth.rootHash;
    openssh.authorizedKeys.keys = hostConfig.auth.sshKeys;
  };

  # ==========================================
  # 常用软件包集合配置
  # ==========================================
  desktop.packages = {
    enable = true;
  };

  # 桌面应用配置
  desktop.apps.clash-verge = {
    enable = true;
  };

  desktop.apps.v2rayn = {
    enable = true;
  };

  # 静态测试与合法性断言 (与配置同模块维护)
  assertions = [
    {
      assertion = config.networking.hostName == hostConfig.name;
      message = "主机名配置错误，预期为 ${hostConfig.name}，实际为 ${config.networking.hostName}";
    }
    {
      assertion = config.base.update.upgrade.type == "legacy";
      message = "更新模式配置错误，预期为 legacy，实际为 ${config.base.update.upgrade.type}";
    }
    {
      assertion = config.base.update.sync.url == "https://github.com/shaogme/dot-hosts-desktop";
      message = "更新同步 URL 配置错误，预期为 https://github.com/shaogme/dot-hosts-desktop，实际为 ${config.base.update.sync.url}";
    }
    {
      assertion = config.exts.kernel.cachyos.enable == true;
      message = "内核配置错误：CachyOS 内核未启用";
    }
    {
      assertion = config.base.performance.tuning.profile == "desktop-performance";
      message = "性能调优配置错误：应当启用 desktop-performance 配置文件";
    }
    {
      assertion = config.base.hardware.network.backend == "networkmanager";
      message = "网络后端配置错误：应当使用 networkmanager";
    }
    {
      assertion = config.programs.hyprland.enable == true;
      message = "桌面环境配置错误：Hyprland 未启用";
    }
    {
      assertion = config.desktop.loginManager.tuigreet.enable == true;
      message = "登录管理器配置错误：tuigreet 未启用";
    }
    {
      assertion = config.base.container.podman.enable == true;
      message = "容器引擎配置错误：Podman 未启用";
    }
    {
      assertion = config.desktop.packages.enable == true;
      message = "软件包集合配置错误：desktop.packages 未启用";
    }
    {
      assertion = config.desktop.apps.clash-verge.enable == true;
      message = "桌面应用配置错误：desktop.apps.clash-verge 未启用";
    }
    {
      assertion = config.desktop.apps.v2rayn.enable == true;
      message = "桌面应用配置错误：desktop.apps.v2rayn 未启用";
    }
  ];
}
