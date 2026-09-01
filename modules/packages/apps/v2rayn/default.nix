{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.desktop.apps.v2rayn;
in
{
  # =========================================================================
  # NixOS 模块选项定义：desktop.apps.v2rayn
  # 该模块可被 modules/packages/apps/default.nix 的自动发现机制自动引入。
  # =========================================================================
  options.desktop.apps.v2rayn = {
    enable = mkEnableOption "v2rayN GUI 桌面应用程序（基于 Bubblewrap 沙箱与 FHS 隔离运行）";

    package = mkOption {
      type = types.package;
      default = import ./package.nix { inherit pkgs lib; };
      defaultText = literalExpression "import ./package.nix { inherit pkgs lib; }";
      description = "使用的 v2rayN 软件包实例（默认使用内置沙箱隔离包装）。";
    };
  };

  # 启用时将 v2rayN 包装器及桌面快捷方式注册至系统环境
  config = mkIf cfg.enable {
    environment.systemPackages = [
      cfg.package
    ];
  };
}
