{ hostPath }:
let
  # 统一处理相对路径或绝对路径
  resolvedHostPath =
    if builtins.isPath hostPath then
      hostPath
    else
      /. + builtins.unsafeDiscardStringContext (toString hostPath);

  # 导入目标主机目录下的 npins 源
  sources = import (resolvedHostPath + "/npins");
  pkgs = import sources.nixpkgs {
    system = "x86_64-linux";
    config.allowUnfree = true;
  };
  lib = pkgs.lib;

  # 1. 评估目标主机系统配置 (如 hosts/home-7950x)
  targetHost = (import (sources.nixpkgs + "/nixos/lib/eval-config.nix") {
    inherit pkgs;
    modules = [ (resolvedHostPath + "/configuration.nix") ];
  });

  targetToplevel = targetHost.config.system.build.toplevel;
  diskoScript = targetHost.config.system.build.diskoScript;
  targetDisk = targetHost.config.exts.hardware.disk.btrfs.device or "/dev/sda";
  hostName = targetHost.config.networking.hostName;

  # 2. 导出主机配置源码至 Nix Store，供 ISO 安装时复制到目标系统 /etc/nixos
  hostConfigSource = pkgs.runCommand "host-config-${hostName}" { } ''
    mkdir -p $out
    cp -rT ${resolvedHostPath} $out
  '';

  # 3. 收集所有相关 npins 源码路径，确保离线环境中本地源码完备
  sourceStores = lib.filter (x: builtins.isPath x || lib.isDerivation x) (
    builtins.attrValues sources
  );

  # 4. 离线自动化安装脚本定义
  installScript = pkgs.writeShellScriptBin "nixos-autoinstall" ''
    set -euo pipefail

    echo "======================================================"
    echo " Starting Offline Desktop Auto-Installer for: ${hostName}"
    echo " Target Disk: ${targetDisk}"
    echo "======================================================"

    # 1. 确保目标磁盘设备就绪
    echo ">> Waiting for disk ${targetDisk} to be ready..."
    for i in $(seq 1 30); do
      if [ -b "${targetDisk}" ]; then
        break
      fi
      echo "Waiting for ${targetDisk}... ($i/30)"
      sleep 1
    done

    if [ ! -b "${targetDisk}" ]; then
      echo "ERROR: Target disk ${targetDisk} not found!"
      exit 1
    fi

    # 2. 执行 Disko 自动分区、格式化并挂载至 /mnt
    echo ">> Partitioning and formatting ${targetDisk} using Disko..."
    ${diskoScript}

    # 3. 离线安装目标系统 Closure
    echo ">> Installing NixOS system closure offline to /mnt..."
    nixos-install --system "${targetToplevel}" \
      --no-root-password \
      --no-channel-copy \
      --substituters "" \
      --option binary-caches ""

    # 4. 复制主机配置至目标系统的 /etc/nixos
    echo ">> Copying host configuration files to /mnt/etc/nixos..."
    mkdir -p /mnt/etc/nixos
    cp -rT "${hostConfigSource}" /mnt/etc/nixos/
    chmod -R u+w /mnt/etc/nixos

    # 5. 修复 GPT 备份表至物理磁盘末端
    echo ">> Relocating Backup GPT table to the end of the disk..."
    sgdisk -e "${targetDisk}" || true
    partprobe "${targetDisk}" || true
    sync

    echo "======================================================"
    echo " Installation Finished Successfully in Offline Mode!"
    echo " System will reboot into ${hostName} in 10 seconds..."
    echo "======================================================"
    sleep 10
    reboot
  '';

  # 5. 评估全自动无人值守离线安装 ISO
  installerIso = (import (sources.nixpkgs + "/nixos/lib/eval-config.nix") {
    inherit pkgs;
    modules = [
      # 引入 NixOS 官方 Minimal CD 模块
      (sources.nixpkgs + "/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix")

      ({ config, pkgs, ... }: {
        # 禁用系统休眠与挂起
        systemd.targets.sleep.enable = false;
        systemd.targets.suspend.enable = false;
        systemd.targets.hibernate.enable = false;
        systemd.targets.hybrid-sleep.enable = false;

        # 默认 root 自动免密登录 console
        services.getty.autologinUser = lib.mkDefault "root";

        # ISO 镜像命名
        image.baseName = lib.mkForce "nixos-desktop-autoinstall-${hostName}";

        # 预打包所有构建与运行时闭包依赖，确保 ISO 在 100% 纯离线环境下执行安装
        isoImage.storeContents = [
          targetToplevel
          hostConfigSource
          diskoScript
        ] ++ sourceStores;

        # 使用高压缩率 zstd 压缩 squashfs
        isoImage.squashfsCompression = "zstd -Xcompression-level 19";

        # 环境工具
        environment.systemPackages = with pkgs; [
          installScript
          gptfdisk
          util-linux
          systemd
          coreutils
          btrfs-progs
          dosfstools
          e2fsprogs
          rsync
        ];

        # 自动化安装 Service
        systemd.services.nixos-autoinstall = {
          description = "Unattended Offline Desktop Installer for ${hostName}";
          wantedBy = [ "multi-user.target" ];
          after = [ "local-fs.target" ];

          serviceConfig = {
            Type = "oneshot";
            StandardOutput = "journal+console";
            StandardError = "journal+console";
          };

          path = with pkgs; [
            installScript
            gptfdisk
            util-linux
            systemd
            coreutils
            btrfs-progs
            dosfstools
            nixos-install-tools
            kmod
          ];

          script = ''
            exec ${installScript}/bin/nixos-autoinstall
          '';
        };
      })
    ];
  });
in
installerIso.config.system.build.isoImage
