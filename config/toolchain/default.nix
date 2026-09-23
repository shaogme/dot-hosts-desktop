{ lib, ... }:

{
  # ==========================================
  # 开发工具链 (Rust)
  # ==========================================
  desktop.toolchain.rust = {
    enable = lib.mkDefault true;
  };
}
