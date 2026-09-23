{ lib, ... }:

{
  # ==========================================
  # 自定义跨用户存储路径配置 (/data)
  # ==========================================
  desktop.storage = {
    enable = lib.mkDefault true;
    paths = {
      "/data" = {
        user = lib.mkDefault "root";
        group = lib.mkDefault "users";
        mode = lib.mkDefault "2775";
        acl.enable = lib.mkDefault true;
      };
    };
  };
}
