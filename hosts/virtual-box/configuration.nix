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
    # 4. 引入通用主机配置集合
    ../../config/default.nix
  ];

  # ==========================================
  # 主机特有硬件与基础配置
  # ==========================================
  networking.hostName = hostConfig.name;

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

  # 硬件报告路径 (占位，待后续生成完整硬件报告)
  hardware.facter.reportPath = ./facter.json;

  # 关闭 VirtualBox Guest 增强驱动（避免高版本内核编译 vboxguest 驱动冲突）
  virtualisation.virtualbox.guest.enable = false;

  # ==========================================
  # 桌面特有配置 (虚拟化兼容模式)
  # ==========================================
  desktop.windowManager.niri.virtualization.enable = true;

  # ==========================================
  # 主机特有桌面应用
  # ==========================================
  desktop.apps.firefox.enable = true;
  desktop.apps.vscode.enable = true;

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
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "input" "proxy-bypass" ];
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
  # 静态测试与合法性断言 (主机特性约束)
  # ==========================================
  assertions = [
    {
      assertion = config.networking.hostName == hostConfig.name;
      message = "主机名配置错误，预期为 ${hostConfig.name}，实际为 ${config.networking.hostName}";
    }
    {
      assertion = config.base.hardware.type == "vps";
      message = "硬件类型配置错误：VirtualBox 虚拟机应当配置为 vps 硬件类型";
    }
    {
      assertion = config.desktop.windowManager.niri.virtualization.enable == true;
      message = "窗口管理器配置错误：虚拟化兼容模式未启用";
    }
    {
      assertion = config.desktop.apps.firefox.enable == true;
      message = "桌面应用配置错误：desktop.apps.firefox 未启用";
    }
    {
      assertion = config.desktop.apps.vscode.enable == true;
      message = "桌面应用配置错误：desktop.apps.vscode 未启用";
    }
    {
      assertion = builtins.elem "proxy-bypass" config.users.users.${hostConfig.user}.extraGroups;
      message = "用户组配置错误：用户 ${hostConfig.user} 未加入 proxy-bypass 组";
    }
  ];
}
