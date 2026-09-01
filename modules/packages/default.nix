{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.desktop.packages;
in
{
  options.desktop.packages = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "是否启用桌面与开发常见软件包集合模块。";
    };

    development = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否安装版本控制与基础开发协作工具（如 git, git-lfs, gh, lazygit 等）。";
      };
      packages = mkOption {
        type = types.listOf types.package;
        default = with pkgs; [
          git
          git-lfs
          gh
          lazygit
          gnumake
          gcc
          pkg-config
        ];
        description = "版本控制与开发协作工具包列表。";
      };
    };

    containers = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否安装容器与环境隔离工具（如 distrobox, bubblewrap）。";
      };
      packages = mkOption {
        type = types.listOf types.package;
        default = with pkgs; [
          distrobox
          bubblewrap
        ];
        description = "容器与环境隔离工具包列表。";
      };
    };

    cli = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否安装现代命令行增强与高效检索工具（如 ripgrep, fd, fzf, bat, eza 等）。";
      };
      packages = mkOption {
        type = types.listOf types.package;
        default = with pkgs; [
          ripgrep
          fd
          fzf
          bat
          eza
          zoxide
          jq
          yq-go
          tree
        ];
        description = "现代命令行增强工具包列表。";
      };
    };

    system = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否安装系统监控与硬件诊断工具（如 btop, htop, fastfetch, iotop 等）。";
      };
      packages = mkOption {
        type = types.listOf types.package;
        default = with pkgs; [
          btop
          htop
          fastfetch
          iotop
          lsof
          pciutils
          usbutils
          nvtopPackages.amd
        ];
        description = "系统监控与硬件诊断工具包列表。";
      };
    };

    network = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否安装网络分析与数据传输工具（如 curl, wget, aria2, rsync 等）。";
      };
      packages = mkOption {
        type = types.listOf types.package;
        default = with pkgs; [
          curl
          wget
          aria2
          socat
          rsync
          iperf3
          dnsutils
        ];
        description = "网络分析与数据传输工具包列表。";
      };
    };

    wifi = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "是否安装无线网络与 Wi-Fi 管理工具（如 networkmanager / nmtui, nmcli, iw, wireless-tools 等）。";
      };
      packages = mkOption {
        type = types.listOf types.package;
        default = with pkgs; [
          networkmanager # 提供 nmcli, nmtui
          wirelesstools  # 提供 iwconfig, iwlist 等
          iw
          wavemon
          impala
        ];
        description = "Wi-Fi 与无线网络管理工具包列表。";
      };
    };

    compression = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否安装归档与解压缩工具（如 zip, unzip, p7zip, zstd 等）。";
      };
      packages = mkOption {
        type = types.listOf types.package;
        default = with pkgs; [
          zip
          unzip
          p7zip
          zstd
          gnutar
          xz
          bzip2
          gzip
        ];
        description = "归档与解压缩工具包列表。";
      };
    };

    terminal = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否安装终端复用与文本编辑工具（如 tmux, vim）。";
      };
      packages = mkOption {
        type = types.listOf types.package;
        default = with pkgs; [
          tmux
          vim
        ];
        description = "终端复用与编辑工具包列表。";
      };
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "用户自定义附加的系统软件包列表。";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages =
      optionals cfg.development.enable cfg.development.packages
      ++ optionals cfg.containers.enable cfg.containers.packages
      ++ optionals cfg.cli.enable cfg.cli.packages
      ++ optionals cfg.system.enable cfg.system.packages
      ++ optionals cfg.network.enable cfg.network.packages
      ++ optionals cfg.wifi.enable cfg.wifi.packages
      ++ optionals cfg.compression.enable cfg.compression.packages
      ++ optionals cfg.terminal.enable cfg.terminal.packages
      ++ cfg.extraPackages;
  };
}
