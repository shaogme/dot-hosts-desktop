{ lib, ... }:

{
  # ==========================================
  # 截屏软件配置 (Satty)
  # ==========================================
  desktop.screenshot.satty = {
    enable = lib.mkDefault true;
  };
}
