{ lib, ... }:

{
  # ==========================================
  # 统一字体与 Fontconfig 配置
  # ==========================================
  desktop.fonts = {
    enable = lib.mkDefault true;

    # 显式开启 Office 办公与公文常用字体包（含宋体、黑体、仿宋、楷体、微软雅黑、等线等）
    office = {
      enable = true;
    };
  };
}
