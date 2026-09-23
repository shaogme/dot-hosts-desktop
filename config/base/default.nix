{ config, pkgs, lib, ... }:

let
  defaultEditor = "hx";
in
{
  # ==========================================
  # 通用系统基础配置 (Base)
  # ==========================================
  system.stateVersion = lib.mkDefault "26.11";

  # 启用 Lix 代替默认的 CppNix
  nix.package = lib.mkDefault pkgs.lixPackageSets.git.lix;

  # 基础功能启用
  base.enable = lib.mkDefault true;

  # 全局默认文本编辑器环境变量
  environment.sessionVariables = {
    EDITOR = lib.mkDefault defaultEditor;
    VISUAL = lib.mkDefault defaultEditor;
  };

  # 内存与性能通用设置
  base.performance.tuning.profile = lib.mkDefault "none";
  base.memory.mode = lib.mkDefault "conservative";

  # 容器引擎
  base.container.podman.enable = lib.mkDefault true;

  # 网络配置: 默认使用 NetworkManager 后端
  base.hardware.network = {
    enable = lib.mkDefault true;
    backend = lib.mkDefault "networkmanager";
  };

  # 内核优化: 启用 CachyOS 内核
  exts.kernel.cachyos.enable = lib.mkDefault true;

  # 系统自动更新与同步 (Legacy 模式)
  base.update = {
    enable = lib.mkDefault true;
    upgrade = {
      enable = lib.mkDefault true;
      timer.enable = lib.mkDefault false;
      type = lib.mkDefault "legacy";
    };
    sync = {
      enable = lib.mkDefault true;
      url = lib.mkDefault "https://github.com/shaogme/dot-hosts-desktop";
    };
    path = lib.mkDefault "hosts/${config.networking.hostName}";
  };

  # PAM 登录限制配置 (针对音频与高性能任务的内存锁定限制)
  security.pam.loginLimits = lib.mkDefault [
    {
      domain = "*";
      type = "-";          # 同时设置 soft 和 hard
      item = "memlock";
      value = "10485760";  # 10 GiB (单位为 KB)
    }
  ];

  # Home Manager 全局选项
  home-manager = {
    useGlobalPkgs = lib.mkDefault true;
    useUserPackages = lib.mkDefault true;
  };
}
