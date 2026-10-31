{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.desktop.loginManager.swaylock;
in
{
  options.desktop.loginManager.swaylock = {
    enable = mkEnableOption "swaylock Wayland 锁屏工具与会话锁定管理器";

    package = mkPackageOption pkgs "swaylock" { };

    niri.keybind = mkOption {
      type = types.str;
      default = "Mod+Shift+L";
      description = "Niri 中触发当前会话锁屏的快捷键（设为空字符串则不注册）。";
    };
  };

  config = mkIf cfg.enable {
    security.pam.services.swaylock = { };

    environment.systemPackages = [ cfg.package ];

    # 将 loginctl lock-session 转换为 lock.target，并在屏幕解锁时关闭该 target。
    services.systemd-lock-handler.enable = true;

    systemd.user.services.swaylock = {
      description = "Swaylock Wayland screen locker";
      documentation = [ "man:swaylock(1)" ];
      onSuccess = [ "unlock.target" ];
      partOf = [ "lock.target" ];
      before = [ "lock.target" ];
      wantedBy = [ "lock.target" ];
      serviceConfig = {
        Type = "forking";
        ExecStart = "${lib.getExe cfg.package} -f";
        Restart = "on-failure";
        RestartSec = 0;
      };
    };

    desktop.windowManager.niri = mkIf (
      config.desktop.windowManager.niri.enable && cfg.niri.keybind != ""
    ) {
      extraBinds.${cfg.niri.keybind} = {
        _props.hotkey-overlay-title = "Lock Screen";
        # Niri blocks most keybinds while locked; this also lets users start a
        # replacement locker if swaylock ever exits while Niri remains locked.
        _props.allow-when-locked = true;
        spawn = [ (lib.getExe cfg.package) ];
      };
    };
  };
}
