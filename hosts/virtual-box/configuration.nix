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
  base.hardware.type = "vps";
  exts.hardware.disk.btrfs = {
      enable = true;
      device = "/dev/sda";
      swapSize = 4096;
      # 显式指定基础镜像大小，用于 Disko 构建参考
      imageBaseSize = 20480;
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
  # 桌面与图形环境 (Hyprland & 桌面基础设施与组件)
  # ==========================================
  desktop.windowManager.hyprland = {
    enable = true;
    virtualization.enable = true;
  };

  desktop.audio.pipewire = {
    enable = true;
  };

  desktop.bar.waybar = {
    enable = true;
  };

  desktop.launcher.wofi = {
    enable = true;
  };

  desktop.powerMenu.wlogout = {
    enable = true;
  };

  desktop.notification.dunst = {
    enable = true;
  };

  desktop.theme = {
    enable = true;
  };

  # 登录管理器 (tuigreet)
  desktop.loginManager.tuigreet = {
    enable = true;
    defaultSession = "hyprland";
    display = {
      showTime = true;
    };
    remember = {
      username = true;
      session = true;
    };
  };

  # ==========================================
  # Home Manager 配置
  # ==========================================
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.${hostConfig.user} = { pkgs, ... }: {
      home.stateVersion = "26.11";
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

  desktop.apps.firefox = {
    enable = true;
  };

  desktop.apps.firefox-developer-edition = {
    enable = true;
  };

  desktop.apps.wechat = {
    enable = true;
  };

  desktop.apps.qq = {
    enable = true;
  };

  desktop.apps.vscode = {
    enable = true;
  };

  desktop.apps.vscode-insiders = {
    enable = true;
  };

  # ==========================================
  # 统一字体与 Fontconfig 配置
  # ==========================================
  desktop.fonts = {
    enable = true;
  };

  # ==========================================
  # 输入法配置 (Fcitx5 + Rime 雾凇拼音)
  # ==========================================
  desktop.inputMethod.fcitx5 = {
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
      assertion = config.base.hardware.type == "vps";
      message = "硬件类型配置错误：VirtualBox 虚拟机应当配置为 vps 硬件类型";
    }
    {
      assertion = config.desktop.windowManager.hyprland.enable == true;
      message = "窗口管理器配置错误：Hyprland 未启用";
    }
    {
      assertion = config.desktop.windowManager.hyprland.virtualization.enable == true;
      message = "窗口管理器配置错误：虚拟化兼容模式未启用";
    }
    {
      assertion = config.programs.hyprland.enable == true;
      message = "桌面环境配置错误：Hyprland 未启用";
    }
    {
      assertion = config.desktop.audio.pipewire.enable == true;
      message = "音频服务配置错误：PipeWire 未启用";
    }
    {
      assertion = config.desktop.bar.waybar.enable == true;
      message = "状态栏配置错误：Waybar 未启用";
    }
    {
      assertion = config.desktop.launcher.wofi.enable == true;
      message = "桌面启动器配置错误：Wofi 未启用";
    }
    {
      assertion = config.desktop.launcher.wofi.allowImages == true;
      message = "桌面启动器配置错误：Wofi 图像与图标渲染 (allowImages) 未启用";
    }
    {
      assertion = config.desktop.launcher.wofi.mode == "drun";
      message = "桌面启动器配置错误：Wofi 默认模式应当为 drun";
    }
    {
      assertion = config.desktop.powerMenu.wlogout.enable == true;
      message = "桌面电源管理配置错误：wlogout 电源中心 (powerMenu.wlogout) 未启用";
    }
    {
      assertion = config.desktop.theme.enable == true;
      message = "桌面主题配置错误：desktop.theme 未启用";
    }
    {
      assertion = config.desktop.notification.dunst.enable == true;
      message = "通知服务配置错误：Dunst 未启用";
    }
    {
      assertion = config.desktop.loginManager.tuigreet.enable == true;
      message = "登录管理器配置错误：tuigreet 未启用";
    }
    {
      assertion = config.desktop.loginManager.tuigreet.defaultSession == "hyprland";
      message = "登录管理器配置错误：tuigreet 默认会话应配置为 hyprland";
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
    {
      assertion = config.desktop.apps.firefox.enable == true;
      message = "桌面应用配置错误：desktop.apps.firefox 未启用";
    }
    {
      assertion = config.desktop.apps.firefox-developer-edition.enable == true;
      message = "桌面应用配置错误：desktop.apps.firefox-developer-edition 未启用";
    }
    {
      assertion = config.desktop.apps.wechat.enable == true;
      message = "桌面应用配置错误：desktop.apps.wechat 未启用";
    }
    {
      assertion = config.desktop.apps.qq.enable == true;
      message = "桌面应用配置错误：desktop.apps.qq 未启用";
    }
    {
      assertion = config.desktop.apps.vscode.enable == true;
      message = "桌面应用配置错误：desktop.apps.vscode 未启用";
    }
    {
      assertion = config.desktop.apps.vscode-insiders.enable == true;
      message = "桌面应用配置错误：desktop.apps.vscode-insiders 未启用";
    }
    {
      assertion = config.desktop.fonts.enable == true;
      message = "字体配置错误：desktop.fonts 未启用";
    }
    {
      assertion = config.fonts.fontconfig.enable == true;
      message = "字体配置错误：Fontconfig 未启用";
    }
    {
      assertion = config.desktop.inputMethod.fcitx5.enable == true;
      message = "输入法配置错误：Fcitx5 输入法未启用";
    }
    {
      assertion = config.desktop.inputMethod.fcitx5.rime.enable == true;
      message = "输入法配置错误：Rime 引擎未启用";
    }
    {
      assertion = config.desktop.inputMethod.fcitx5.rime.defaultSchema == "rime_ice";
      message = "输入法配置错误：Rime 默认方案应为 rime_ice 雾凇拼音";
    }
    {
      assertion = config.i18n.inputMethod.enable == true;
      message = "输入法配置错误：i18n.inputMethod 未启用";
    }
    {
      assertion = config.i18n.inputMethod.type == "fcitx5";
      message = "输入法配置错误：输入法框架类型应为 fcitx5";
    }
  ];
}
