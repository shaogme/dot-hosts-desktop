{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.desktop.audio.pipewire;
in
{
  options.desktop.audio.pipewire = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "是否启用 PipeWire 音频服务、32 位兼容支持与 rtkit 实时调度支持。";
    };

    alsa = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否启用 ALSA 支持。";
      };
      support32Bit = mkOption {
        type = types.bool;
        default = true;
        description = "是否启用 ALSA 32 位应用兼容支持。";
      };
    };

    pulse = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否启用 PulseAudio 兼容层服务。";
      };
    };
  };

  config = mkIf cfg.enable {
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = cfg.alsa.enable;
      alsa.support32Bit = cfg.alsa.support32Bit;
      pulse.enable = cfg.pulse.enable;
    };
  };
}
