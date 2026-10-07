{ config, pkgs, lib, ... }:

let
  cfg = config.desktop.apps.steam;
  steamPackage = import ./package.nix {
    inherit pkgs lib;
    extraCompatPackages = cfg.extraCompatPackages;
    extraGameDirs = cfg.extraGameDirs;
  };
in
(import ../lib/mk-app-module.nix {
  name = "steam";
  description = "Steam 游戏分发平台与 Proton 兼容运行环境（Bubblewrap 沙箱与 FHS 隔离）";
  package = steamPackage;
  aliases = [ "steam-run" ];
  extraOptions = {
    extraCompatPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      example = lib.literalExpression "with pkgs; [ proton-ge-bin ]";
      description = "注入 Steam 的额外兼容性工具包（如 Proton-GE），将自动添加至 STEAM_EXTRA_COMPAT_TOOLS_PATHS。";
    };
    extraGameDirs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "/data/games" "/mnt/storage/steam" ];
      description = "允许 Steam 穿透访问的额外外部游戏库目录（绝对路径或相对于用户主目录的相对路径）。";
    };
    remotePlay.openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "是否在防火墙中开放 Steam Remote Play 端口。";
    };
    dedicatedServer.openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "是否在防火墙中开放 Source Dedicated Server 端口。";
    };
    localNetworkGameTransfers.openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "是否在防火墙中开放 Steam 本地网络游戏传输端口。";
    };
  };
  extraConfig = cfg: {
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };
    hardware.steam-hardware.enable = true;
    services.pipewire.alsa.support32Bit = config.services.pipewire.alsa.enable or true;
    networking.firewall = lib.mkMerge [
      (lib.mkIf (cfg.remotePlay.openFirewall || cfg.localNetworkGameTransfers.openFirewall) {
        allowedUDPPorts = [ 27036 ];
      })
      (lib.mkIf cfg.remotePlay.openFirewall {
        allowedTCPPorts = [ 27036 27037 ];
        allowedUDPPorts = [ 10400 10401 ];
        allowedUDPPortRanges = [ { from = 27031; to = 27035; } ];
      })
      (lib.mkIf cfg.dedicatedServer.openFirewall {
        allowedTCPPorts = [ 27015 ];
        allowedUDPPorts = [ 27015 ];
      })
      (lib.mkIf cfg.localNetworkGameTransfers.openFirewall {
        allowedTCPPorts = [ 27040 ];
      })
    ];
  };
  windowRules = [
    {
      match._props = {
        app-id = "^(steam)$";
        title = "^(Friends List|Settings|Steam - News|Steam Guard.*|Steam - Self Updater|Steam Settings)$";
      };
      open-floating = true;
    }
  ];
}) { inherit config pkgs lib; }
