{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.desktop.apps.firefox-developer-edition;
  cfgAlias = config.desktop.apps.firefox-devedition;
in
{
  options.desktop.apps = {
    firefox-developer-edition = {
      enable = mkEnableOption "Firefox Developer Edition 开发者版浏览器（基于 Bubblewrap 沙箱隔离）";

      package = mkOption {
        type = types.package;
        default = import ./package.nix { inherit pkgs lib; };
        defaultText = literalExpression "import ./package.nix { inherit pkgs lib; }";
        description = "使用的 Firefox Developer Edition 软件包实例。";
      };
    };

    firefox-devedition = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "别名选项：等同于 desktop.apps.firefox-developer-edition.enable";
      };
      package = mkOption {
        type = types.package;
        default = cfg.package;
        defaultText = literalExpression "config.desktop.apps.firefox-developer-edition.package";
        description = "别名选项：等同于 desktop.apps.firefox-developer-edition.package";
      };
    };
  };

  config = mkIf (cfg.enable || cfgAlias.enable) {
    environment.systemPackages = [
      (if cfgAlias.enable && cfgAlias.package != cfg.package then cfgAlias.package else cfg.package)
    ];
  };
}
