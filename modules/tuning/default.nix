{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.desktop.tuning;

  # 支持 mode 与 profile 互相兼容规范化
  effectiveMode =
    if cfg.mode != null then cfg.mode
    else if cfg.profile != null then (
      if cfg.profile == "laptop" || cfg.profile == "mobile" then "mobile"
      else if cfg.profile == "vm" then "vm"
      else "desktop"
    )
    else "desktop";

  isDesktop = effectiveMode == "desktop";
  isMobile = effectiveMode == "mobile";
  isVm = effectiveMode == "vm";

  # 默认 TLP 配置
  # 核心协同原则：
  # auto-cpufreq 专注于 CPU 的调度器 (governor)、能效偏好 (EPP) 以及动态睿频 (turbo boost) 实时调谐；
  # TLP 则专注于平台性能配置文件 (platform_profile) 与外设底层硬件节能 (PCIe ASPM, SATA/NVMe, USB, 音频, WiFi, 电池充电阈值)。
  # 两者分工协作，互不冲突，避免 CPU 调优逻辑竞态。
  defaultTlpSettings = mkMerge [
    # 基础通用配置
    {
      TLP_ENABLE = 1;
      TLP_WARN_LEVEL = 3;
    }

    # 1. 桌面端优化预设 (Desktop Profile)
    # 针对高性能桌面台式机/工作站，交流电长供电，注重高吞吐、超低响应延迟与外设连接稳定性
    (mkIf isDesktop {
      # 平台配置模式：最高性能
      PLATFORM_PROFILE_ON_AC = "performance";

      # PCIe ASPM 策略：最高性能，禁止 PCIe 设备（如独立显卡、NVMe 固态、网卡）进入低功耗延迟态
      PCIE_ASPM_ON_AC = "performance";

      # 存储接口与外设运行时电源管理：保持唤醒开启
      AHCI_RUNTIME_PM_ON_AC = "on";
      RUNTIME_PM_ON_AC = "on";

      # 声卡省电：关闭 (0)，避免音频芯片空闲挂起休眠引起爆音、底噪或播放延迟
      SOUND_POWER_SAVE_ON_AC = 0;
      SOUND_POWER_SAVE_CONTROLLER = "N";

      # USB 自动挂起：桌面端禁用，避免键鼠、手柄、音频 DAC 等外设输入休眠与响应迟滞
      USB_AUTOSUSPEND = 0;

      # 无线网卡节能：关闭，确保高吞吐传输与低网络抖动
      WIFI_PWR_ON_AC = "off";

      # 磁盘不设置激进停转
      DISK_IDLE_SECS_ON_AC = 0;
    })

    # 2. 移动端优化预设 (Mobile / Laptop Profile)
    # 针对笔记本移动设备，动态兼顾接通电源时的高性能与电池供电状态下的超长续航与温控表现
    (mkIf isMobile {
      # 平台电源模式：插电高性能，电池供电低功耗
      PLATFORM_PROFILE_ON_AC = "performance";
      PLATFORM_PROFILE_ON_BAT = "low-power";

      # PCIe ASPM 策略：插电保持默认兼容，电池模式启用极致节能 (powersupersave)
      PCIE_ASPM_ON_AC = "default";
      PCIE_ASPM_ON_BAT = "powersupersave";

      # 设备运行时电源管理 (Runtime PM)
      RUNTIME_PM_ON_AC = "on";
      RUNTIME_PM_ON_BAT = "auto";

      # 存储链路接口节能 (SATA / NVMe)
      AHCI_RUNTIME_PM_ON_AC = "on";
      AHCI_RUNTIME_PM_ON_BAT = "auto";

      # 声卡节能控制：插电保证音质无延迟，电池模式开启省电模式
      SOUND_POWER_SAVE_ON_AC = 0;
      SOUND_POWER_SAVE_ON_BAT = 1;
      SOUND_POWER_SAVE_CONTROLLER = "Y";

      # 无线网络节能：插电全速，电池模式开启省电
      WIFI_PWR_ON_AC = "off";
      WIFI_PWR_ON_BAT = "on";

      # USB 自动挂起：插电关闭，电池模式自动挂起空闲 USB 设备
      USB_AUTOSUSPEND = 1;

      # 电池健康保护充电阈值（启用时生效）
      START_CHARGE_THRESH_BAT0 = mkIf cfg.battery.enableChargeThresholds cfg.battery.startThreshold;
      STOP_CHARGE_THRESH_BAT0 = mkIf cfg.battery.enableChargeThresholds cfg.battery.stopThreshold;
    })

    # 3. 虚拟机兼容预设 (VM Profile)
    # 虚拟机环境下精简硬件功耗操作，保持通用高性能
    (mkIf isVm {
      PLATFORM_PROFILE_ON_AC = "performance";
      PCIE_ASPM_ON_AC = "default";
      RUNTIME_PM_ON_AC = "on";
      AHCI_RUNTIME_PM_ON_AC = "on";
      SOUND_POWER_SAVE_ON_AC = 0;
      USB_AUTOSUSPEND = 0;
      WIFI_PWR_ON_AC = "off";
    })

    # 用户额外指定的 TLP 配置优先级最高
    cfg.tlp.settings
  ];

  # 默认 auto-cpufreq 配置
  defaultAutoCpufreqSettings = mkMerge [
    # 桌面端：专注插电持续高性能与低延迟响应
    (mkIf isDesktop {
      charger = {
        governor = cfg.cpu.governor.ac;
        energy_performance_preference = cfg.cpu.epp.ac;
        turbo = cfg.cpu.turbo.ac;
      };
    })

    # 移动端：插电高性能与电池端深度节能双态动态切换
    (mkIf isMobile {
      charger = {
        governor = cfg.cpu.governor.ac;
        energy_performance_preference = cfg.cpu.epp.ac;
        turbo = cfg.cpu.turbo.ac;
      };
      battery = {
        governor = cfg.cpu.governor.bat;
        energy_performance_preference = cfg.cpu.epp.bat;
        turbo = cfg.cpu.turbo.bat;
      };
    })

    # 虚拟机环境
    (mkIf isVm {
      charger = {
        governor = cfg.cpu.governor.ac;
        energy_performance_preference = cfg.cpu.epp.ac;
        turbo = cfg.cpu.turbo.ac;
      };
    })

    # 用户额外指定的 auto-cpufreq 配置
    cfg.auto-cpufreq.settings
  ];

  # 调优状态查看命令行工具
  tuningCtlScript = pkgs.writeShellScriptBin "tuning-ctl" ''
    export PATH="${lib.makeBinPath [ pkgs.coreutils pkgs.systemd pkgs.gnugrep pkgs.tlp pkgs.auto-cpufreq ]}:$PATH"

    case "''${1:-}" in
      status|"")
        echo "=========================================="
        echo "  系统性能与功耗调优状态 (TLP + auto-cpufreq)"
        echo "=========================================="
        echo "当前优化模式: ${effectiveMode}"
        echo ""
        echo "[1] auto-cpufreq 动态 CPU 调度服务:"
        systemctl is-active auto-cpufreq.service 2>/dev/null || echo "inactive"
        echo ""
        echo "[2] TLP 硬件功耗与外设管理服务:"
        systemctl is-active tlp.service 2>/dev/null || echo "inactive"
        echo ""
        echo "[3] CPU 核心调度状态与 EPP 能效偏好:"
        if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
          echo "CPU0 Governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)"
        fi
        if [ -f /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference ]; then
          echo "CPU0 EPP:      $(cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference 2>/dev/null)"
        fi
        echo ""
        echo "提示: 可通过 'sudo tlp-stat -s' 或 'sudo auto-cpufreq --stats' 查看更详细的硬件指标。"
        ;;
      stats)
        auto-cpufreq --stats
        ;;
      tlp)
        shift
        tlp-stat "$@"
        ;;
      *)
        echo "用法: tuning-ctl [status | stats | tlp <args>]"
        exit 1
        ;;
    esac
  '';
in
{
  imports = [
    # 提供顶层 tuning 与 desktop.tuning 互通别名
    (lib.mkAliasOptionModule [ "tuning" ] [ "desktop" "tuning" ])
  ];

  options.desktop.tuning = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "是否启用基于 TLP 与 auto-cpufreq 组合的性能与功耗调优模块。";
    };

    mode = mkOption {
      type = types.enum [ "desktop" "mobile" "vm" ];
      default = "desktop";
      description = ''
        调优目标平台模式：
        - `desktop`: 桌面端高性能优化。针对台式机/工作站持续供电环境，最大化高吞吐性能与响应速度，禁用不必要的声卡与 USB 节能休眠。
        - `mobile`: 移动端（笔记本）优化。接通电源时提供强劲性能，电池供电状态下动态降频、关闭激进睿频并开启深度外设节能。
        - `vm`: 虚拟机环境轻量调优。
      '';
    };

    profile = mkOption {
      type = types.enum [ "desktop" "mobile" "vm" "desktop-performance" "laptop" ];
      default = cfg.mode;
      description = "调优配置文件名称别名，与 mode 选项保持互通。";
    };

    tlp = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否启用 TLP 硬件功耗与外设电源管理服务。";
      };

      settings = mkOption {
        type = types.attrsOf types.anything;
        default = { };
        description = "用户自定义的 TLP 附加或覆盖配置字典。";
      };
    };

    auto-cpufreq = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否启用 auto-cpufreq 动态 CPU 频率与能效调度服务。";
      };

      settings = mkOption {
        type = types.attrsOf types.anything;
        default = { };
        description = "用户自定义的 auto-cpufreq 附加或覆盖配置字典。";
      };
    };

    battery = {
      enableChargeThresholds = mkOption {
        type = types.bool;
        default = isMobile;
        description = "是否启用电池健康充电阈值控制（默认仅移动端模式开启）。";
      };

      startThreshold = mkOption {
        type = types.int;
        default = 75;
        description = "电池开始充电的电量阈值百分比。";
      };

      stopThreshold = mkOption {
        type = types.int;
        default = 80;
        description = "电池停止充电的电量阈值百分比。";
      };
    };

    cpu = {
      governor = {
        ac = mkOption {
          type = types.str;
          default = "performance";
          description = "交流电 (AC) 供电状态下的 CPU 调频器 (governor)。";
        };

        bat = mkOption {
          type = types.str;
          default = "powersave";
          description = "电池 (Battery) 供电状态下的 CPU 调频器 (governor)。";
        };
      };

      epp = {
        ac = mkOption {
          type = types.str;
          default = if isDesktop then "performance" else "balance_performance";
          description = "交流电 (AC) 供电状态下的能量性能偏好 (Energy Performance Preference)。";
        };

        bat = mkOption {
          type = types.str;
          default = "power";
          description = "电池 (Battery) 供电状态下的能量性能偏好 (Energy Performance Preference)。";
        };
      };

      turbo = {
        ac = mkOption {
          type = types.enum [ "always" "auto" "never" ];
          default = "auto";
          description = "交流电 (AC) 供电状态下的 CPU Turbo Boost 策略。";
        };

        bat = mkOption {
          type = types.enum [ "always" "auto" "never" ];
          default = "never";
          description = "电池 (Battery) 供电状态下的 CPU Turbo Boost 策略。";
        };
      };
    };
  };

  config = mkIf cfg.enable {
    # 强制禁用冲突的电源管理服务（避免 DBus 接口或调频逻辑竞争）
    services.power-profiles-daemon.enable = mkForce false;
    services.tuned.enable = mkForce false;

    # 1. 启用并配置 TLP
    services.tlp = mkIf cfg.tlp.enable {
      enable = true;
      settings = defaultTlpSettings;
    };

    # 2. 启用并配置 auto-cpufreq
    services.auto-cpufreq = mkIf cfg.auto-cpufreq.enable {
      enable = true;
      settings = defaultAutoCpufreqSettings;
    };

    # 3. 注入系统工具包
    environment.systemPackages = [
      pkgs.tlp
      pkgs.auto-cpufreq
      tuningCtlScript
    ];
  };
}
