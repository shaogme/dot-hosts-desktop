{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.desktop.apps.firefox;
in
{
  options.desktop.apps.firefox = {
    enable = mkEnableOption "Firefox 网页浏览器（基于 Bubblewrap 沙箱隔离）";

    package = mkOption {
      type = types.package;
      default = import ./package.nix { inherit pkgs lib; };
      defaultText = literalExpression "import ./package.nix { inherit pkgs lib; }";
      description = "使用的 Firefox 软件包实例。";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      cfg.package
    ];
  };
}
