{ config, pkgs, lib, modulesPath, ... }:

let
  # 导入由 npins 管理的依赖源
  sources = import ./npins;
  
  # 基础库和扩展库
  dot-base = import sources.dot-base { };
  dot-exts = import sources.dot-exts { };

  # 主机基础配置信息
  hostConfig = {
    name = "laptop-8845hs";
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
    # 4. 引入通用主机配置集合
    ../../config/default.nix
  ];

  # ==========================================
  # 主机特有硬件与基础配置
  # ==========================================
  networking.hostName = hostConfig.name;

  # Hardware 配置
  base.hardware.type = "physical";
  exts.hardware.disk.btrfs = {
    enable = true;
    device = "/dev/nvme0n1";
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

  # 图形驱动与硬件加速: 启用 AMD 核显 + NVIDIA 独显混合模式 (PRIME Offload)
  base.hardware.graphics = {
    mode = "hybrid-amd-nvidia";
    hybrid = {
      strategy = "offload";
      integratedBusId = "PCI:6:0:0";
      discreteBusId = "PCI:1:0:0";
    };
    nvidia.open = true;
  };

  # 性能与功耗调优 (TLP + auto-cpufreq 组合优化 - 移动端)
  desktop.tuning.mode = "mobile";

  # 硬件报告路径 (占位，待后续生成完整硬件报告)
  hardware.facter.reportPath = ./facter.json;

  # 内核模块: 启用 KVM 虚拟化支持 (AMD CPU)
  boot.kernelModules = [ "kvm-amd" ];

  # 内核参数: 修复机械革命 GM5HG0A (8845H) 开关屏幕/休眠唤醒时 i8042 键盘控制器超时与通信失败
  boot.kernelParams = [
    "i8042.reset=1"
    "i8042.nomux=1"
    "i8042.nopnp=1"
    "i8042.noloop=1"
  ];

  # ==========================================
  # 主机特有软件包与应用
  # ==========================================
  desktop.packages.wifi.enable = true;

  desktop.apps.onlyoffice.enable = true;

  # ==========================================
  # 用户与认证配置
  # ==========================================
  base.auth.root = {
    mode = "default";
    initialHashedPassword = hostConfig.auth.rootHash;
    authorizedKeys = hostConfig.auth.sshKeys;
  };

  users.users.${hostConfig.user} = {
    isNormalUser = true;
    description = "Shaog";
    shell = pkgs.nushell;
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "input" "kvm" "libvirtd" "proxy-bypass" ];
    initialHashedPassword = hostConfig.auth.rootHash;
    openssh.authorizedKeys.keys = hostConfig.auth.sshKeys;
  };

  home-manager.users.${hostConfig.user} = { pkgs, ... }: {
    home.stateVersion = "26.11";
    home.sessionVariables = {
      EDITOR = "hx";
      VISUAL = "hx";
    };
  };

  # ==========================================
  # 虚拟化与虚拟机管理 (KVM / QEMU / Libvirt)
  # ==========================================
  virtualisation = {
    libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = true;
        swtpm.enable = true;
      };
    };
    spiceUSBRedirection.enable = true;
  };

  # Virt-Manager 图形管理工具
  programs.virt-manager.enable = true;
  programs.dconf.enable = true;

  # ==========================================
  # 静态测试与合法性断言 (主机特性约束)
  # ==========================================
  assertions = [
    {
      assertion = config.networking.hostName == hostConfig.name;
      message = "主机名配置错误，预期为 ${hostConfig.name}，实际为 ${config.networking.hostName}";
    }
    {
      assertion = config.desktop.tuning.mode == "mobile";
      message = "性能调优配置错误：应当启用 mobile 移动端优化模式";
    }
    {
      assertion = config.base.hardware.graphics.mode == "hybrid-amd-nvidia";
      message = "图形驱动配置错误：AMD+NVIDIA 混合显卡驱动与加速未启用";
    }
    {
      assertion = builtins.all (param: builtins.elem param config.boot.kernelParams) [
        "i8042.reset=1"
        "i8042.nomux=1"
        "i8042.nopnp=1"
        "i8042.noloop=1"
      ];
      message = "内核参数配置错误：i8042 键盘控制器调优参数未完全启用";
    }
    {
      assertion = config.desktop.packages.wifi.enable == true;
      message = "软件包集合 Wi-Fi 配置错误：desktop.packages.wifi 未启用";
    }
    {
      assertion = config.desktop.apps.onlyoffice.enable == true;
      message = "桌面应用配置错误：desktop.apps.onlyoffice 未启用";
    }
    {
      assertion = config.virtualisation.libvirtd.enable == true;
      message = "虚拟化配置错误：libvirtd 未启用";
    }
    {
      assertion = builtins.elem "kvm-amd" config.boot.kernelModules;
      message = "内核模块配置错误：kvm-amd 未启用";
    }
    {
      assertion = builtins.elem "kvm" config.users.users.${hostConfig.user}.extraGroups;
      message = "用户组配置错误：用户 ${hostConfig.user} 未加入 kvm 组";
    }
    {
      assertion = builtins.elem "libvirtd" config.users.users.${hostConfig.user}.extraGroups;
      message = "用户组配置错误：用户 ${hostConfig.user} 未加入 libvirtd 组";
    }
    {
      assertion = builtins.elem "proxy-bypass" config.users.users.${hostConfig.user}.extraGroups;
      message = "用户组配置错误：用户 ${hostConfig.user} 未加入 proxy-bypass 组";
    }
    {
      assertion = config.programs.virt-manager.enable == true;
      message = "虚拟机管理工具配置错误：virt-manager 未启用";
    }
    {
      assertion = config.users.defaultUserShell == pkgs.nushell || config.users.users.${hostConfig.user}.shell == pkgs.nushell;
      message = "默认 Shell 配置错误：用户默认 Shell 应当为 Nushell";
    }
  ];
}
