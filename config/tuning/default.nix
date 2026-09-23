{ lib, ... }:

{
  # ==========================================
  # 性能与功耗调优 (TLP + auto-cpufreq 组合优化)
  # ==========================================
  desktop.tuning = {
    enable = lib.mkDefault true;
    mode = lib.mkDefault "desktop";
  };
}
