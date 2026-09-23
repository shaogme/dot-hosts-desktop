{ lib, ... }:

{
  # ==========================================
  # 通用桌面应用配置
  # ==========================================
  desktop.apps = {
    clash-verge.enable = lib.mkDefault true;
    v2rayn.enable = lib.mkDefault true;
    firefox-developer-edition.enable = lib.mkDefault true;
    wechat.enable = lib.mkDefault true;
    qq.enable = lib.mkDefault true;
    vscode-insiders.enable = lib.mkDefault true;
    microsoft-edge.enable = lib.mkDefault true;
  };
}
