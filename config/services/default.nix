{ lib, ... }:

{
  # ==========================================
  # 透明代理服务 (sing-box SOCKS5 TUN)
  # ==========================================
  services.socks-tun = {
    enable = lib.mkDefault true;
    defaultPort = lib.mkDefault 10808;
  };
}
