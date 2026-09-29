{ lib, ... }:

{
  # ==========================================
  # 录屏软件配置 (OBS Studio)
  # ==========================================
  desktop.screenRecorder.obs = {
    enable = lib.mkDefault true;
  };
}
