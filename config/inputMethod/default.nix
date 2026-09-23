{ lib, ... }:

{
  # ==========================================
  # 输入法配置 (Fcitx5 + Rime 雾凇拼音)
  # ==========================================
  desktop.inputMethod.fcitx5 = {
    enable = lib.mkDefault true;
  };
}
