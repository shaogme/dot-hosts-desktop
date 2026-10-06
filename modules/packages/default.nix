{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.desktop.packages;
in
{
  imports = [
    # 提供 desktop.packages.environment 与 desktop.packages.base 互通别名
    (lib.mkAliasOptionModule [ "desktop" "packages" "environment" ] [ "desktop" "packages" "base" ])
  ];

  options.desktop.packages = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "是否启用桌面与开发常见软件包集合模块。";
    };

    base = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否安装底层运行库与系统开发基础环境包（如 openssl, libbpf, libxcrypt 等）。";
      };
      packages = mkOption {
        type = types.listOf types.package;
        default = with pkgs; [
          openssl
          libbpf
          libxcrypt
        ];
        description = "基础环境包列表。";
      };
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
        description = "是否启用系统归档与解压缩工具链集合。";
      };

      sevenZip = {
        variant = mkOption {
          type = types.enum [
            "7zip-zstd"
            "_7zip-zstd"
            "7zip-zstd-rar"
            "_7zip-zstd-rar"
            "7zz"
            "_7zz"
            "7zz-rar"
            "_7zz-rar"
            "p7zip"
            "p7zip-rar"
            "custom"
          ];
          default = "7zip-zstd";
          description = "选择系统采用的 7-Zip 引擎实现。";
        };

        customPackage = mkOption {
          type = types.nullOr types.package;
          default = null;
          description = "当 variant 设置为 'custom' 时指定的自定义 7-Zip 软件包。";
        };

        enableCompatibilitySymlinks = mkOption {
          type = types.bool;
          default = true;
          description = "是否启用全双工二进制兼容软链接（保证 7z 与 7zz 同时存在）。";
        };

        package = mkOption {
          type = types.package;
          default = pkgs.sevenZip;
          defaultText = literalExpression "pkgs.sevenZip";
          description = "最终在系统和沙箱中生效的 7-Zip 统一软件包实例（由 nixpkgs.overlays 全局注入）。";
        };
      };

      extraTools = mkOption {
        type = types.listOf types.package;
        default = with pkgs; [
          zip
          unzip
          zstd
          gnutar
          xz
          bzip2
          gzip
        ];
        description = "除 7-Zip 外的辅助归档与解压缩工具列表。";
      };

      packages = mkOption {
        type = types.listOf types.package;
        default = [ cfg.compression.sevenZip.package ] ++ cfg.compression.extraTools;
        description = "归档模块最终汇总安装的软件包列表。";
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

  config = mkMerge [
    {
      nixpkgs.overlays = [
        (final: prev: {
          sevenZip =
            let
              normalizeVariant = v:
                if v == "7zz" then "_7zz"
                else if v == "7zz-rar" then "_7zz-rar"
                else if v == "7zip-zstd" then "_7zip-zstd"
                else if v == "7zip-zstd-rar" then "_7zip-zstd-rar"
                else v;

              normV = normalizeVariant cfg.compression.sevenZip.variant;

              variantMap = {
                "_7zip-zstd"     = prev._7zip-zstd;
                "_7zip-zstd-rar" = prev._7zip-zstd-rar;
                "_7zz"          = prev._7zz;
                "_7zz-rar"      = prev._7zz-rar;
                "p7zip"         = prev.p7zip;
                "p7zip-rar"     = prev.p7zip-rar;
              };

              basePkg =
                if normV == "custom" then
                  assert assertMsg (cfg.compression.sevenZip.customPackage != null)
                    "当 desktop.packages.compression.sevenZip.variant 为 'custom' 时，必须指定 customPackage！";
                  cfg.compression.sevenZip.customPackage
                else
                  variantMap.${normV};
            in
            if !cfg.compression.sevenZip.enableCompatibilitySymlinks then
              basePkg
            else
              final.symlinkJoin {
                name = "${basePkg.pname or "7zip"}-unified-${basePkg.version or "1.0"}";
                paths = [ basePkg ];
                postBuild = ''
                  mkdir -p "$out/bin"

                  # 1. 确保 7z 与 7zz 全双工互通
                  if [ -x "$out/bin/7zz" ] && [ ! -e "$out/bin/7z" ]; then
                    ln -sf 7zz "$out/bin/7z"
                  fi
                  if [ -x "$out/bin/7z" ] && [ ! -e "$out/bin/7zz" ]; then
                    ln -sf 7z "$out/bin/7zz"
                  fi

                  # 2. 补全 7za 与 7zr
                  for alt in 7za 7zr; do
                    if [ ! -e "$out/bin/$alt" ]; then
                      if [ -e "$out/bin/7zz" ]; then
                        ln -sf 7zz "$out/bin/$alt"
                      elif [ -e "$out/bin/7z" ]; then
                        ln -sf 7z "$out/bin/$alt"
                      fi
                    fi
                  done
                '';
                passthru = (basePkg.passthru or { }) // {
                  unwrapped = basePkg;
                  isUnifiedSevenZip = true;
                };
              };
        })
      ];
    }

    (mkIf cfg.enable {
      assertions = [
        {
          assertion =
            let
              v = cfg.compression.sevenZip.variant;
              isRar = v == "7zip-zstd-rar" || v == "_7zip-zstd-rar" || v == "7zz-rar" || v == "_7zz-rar" || v == "p7zip-rar";
            in
            (!isRar)
            || (config.nixpkgs.config.allowUnfree or false)
            || (lib.isFunction (config.nixpkgs.config.allowUnfreePredicate or null));
          message = ''
            您选择了包含专有 unRAR 代码的 7-Zip 变体 (${cfg.compression.sevenZip.variant})，
            但当前配置未允许非自由软件 (allowUnfree)。请在 configuration.nix 中开启
            nixpkgs.config.allowUnfree = true 或配置 allowUnfreePredicate。
          '';
        }
      ];

      environment.systemPackages =
        optionals cfg.base.enable cfg.base.packages
        ++ optionals cfg.development.enable cfg.development.packages
        ++ optionals cfg.containers.enable cfg.containers.packages
        ++ optionals cfg.cli.enable cfg.cli.packages
        ++ optionals cfg.system.enable cfg.system.packages
        ++ optionals cfg.network.enable cfg.network.packages
        ++ optionals cfg.wifi.enable cfg.wifi.packages
        ++ optionals cfg.compression.enable cfg.compression.packages
        ++ optionals cfg.terminal.enable cfg.terminal.packages
        ++ cfg.extraPackages;
    })
  ];
}
