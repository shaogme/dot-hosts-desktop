{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.desktop.apps.clash-verge;
in
{
  options.desktop.apps.clash-verge = {
    enable = mkEnableOption "Clash Verge Rev GUI 客户端（基于 Bubblewrap 沙箱与 FHS 隔离运行）";

    package = mkOption {
      type = types.package;
      default = import ./package.nix { inherit pkgs lib; };
      defaultText = literalExpression "import ./package.nix { inherit pkgs lib; }";
      description = "使用的 Clash Verge Rev 软件包实例。";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      cfg.package
    ];
  };
}
