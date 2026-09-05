# Tuning 性能与功耗调优模块

本模块结合 **TLP** 与 **auto-cpufreq**，为 NixOS 系统提供针对不同硬件场景（桌面端与移动端）的协同调优能力。

## 架构与分工原则

在传统的 Linux 电源管理中，如果同时无序启用多个守护进程（例如 TuneD、TLP、auto-cpufreq、power-profiles-daemon），会导致 CPU 调频策略与能效偏好产生竞态或断言冲突。

本模块采用**分层协同**架构：

1. **auto-cpufreq**：专职负责 CPU 核心调度。
   - 动态监控 CPU 负载、温度及电源状态（AC/电池）。
   - 实时调节 CPU 调频器（governor，如 `performance` / `powersave`）。
   - 动态调节能效性能偏好（EPP，如 `performance` / `balance_performance` / `power`）。
   - 动态控制 Turbo Boost（睿频加速）。
2. **TLP**：专职负责底层硬件与外设节能，完全放开 CPU 调度给 auto-cpufreq。
   - 平台电源配置文件（`PLATFORM_PROFILE`）。
   - PCIe 主动状态电源管理（ASPM）。
   - 存储链路运行时电源管理（SATA / NVMe）。
   - 总线设备运行时电源管理（Runtime PM）。
   - 音频接口省电（避免空闲休眠引起的爆音/噼啪声）。
   - USB 自动挂起（针对外设延迟进行针对性配置）。
   - 无线网络（WiFi）节能控制。
   - 笔记本电池健康充电阈值控制（如 75% 开始，80% 停止）。
3. **互斥清理**：
   - 自动禁用并屏蔽 `power-profiles-daemon` 与 `services.tuned`，消除 DBus 接口抢占与调度冲突。

---

## 优化模式 (Modes / Profiles)

模块提供预设模式，亦支持细粒度参数覆盖：

### 1. 桌面端优化 (`mode = "desktop"`)

- **适用设备**：高性能桌面台式机、工作站（如 AMD Ryzen 9 7950X）。
- **优化重点**：持续 AC 供电，追求极致高吞吐性能与微秒级响应，消除所有不必要的外设节能休眠。
- **调优策略**：
  - CPU Governor：`performance`
  - EPP：`performance`
  - Turbo Boost：`auto`
  - PCIe ASPM：`performance`
  - 声卡节能：关闭（`SOUND_POWER_SAVE_ON_AC = 0`）
  - USB 自动挂起：关闭（`USB_AUTOSUSPEND = 0`）
  - WiFi 节能：关闭（`WIFI_PWR_ON_AC = off`）

### 2. 移动端优化 (`mode = "mobile"`)

- **适用设备**：笔记本电脑、便携设备（如 AMD Ryzen 7 8845HS）。
- **优化重点**：在插电时释放全速性能，在电池供电时显著降低能耗、延长续航并优化机身发热。
- **调优策略**：
  - **AC 状态**：CPU Governor `performance`，EPP `balance_performance`，Turbo `auto`，外设保持高性能。
  - **Battery 状态**：CPU Governor `powersave`，EPP `power`，Turbo `never`；PCIe ASPM 开启 `powersupersave`；开启声卡与 USB 自动挂起，开启 WiFi 节能。
  - **电池保护**：支持电池健康阈值设置（默认 75% ~ 80%）。

### 3. 虚拟机兼容优化 (`mode = "vm"`)

- **适用设备**：VirtualBox / KVM 虚拟机客户机。
- **优化重点**：轻量级响应，关闭虚机无需管理的物理外设激进策略。

---

## 配置使用示例

### 桌面端主机配置 (`hosts/home-7950x/configuration.nix`)

```nix
desktop.tuning = {
  enable = true;
  mode = "desktop";
};
```

### 移动端主机配置 (`hosts/laptop-8845hs/configuration.nix`)

```nix
desktop.tuning = {
  enable = true;
  mode = "mobile";
  battery = {
    enableChargeThresholds = true;
    startThreshold = 75;
    stopThreshold = 80;
  };
};
```

---

## 诊断与调试命令

模块内置了 `tuning-ctl` 诊断工具，同时暴露标准系统命令：

```bash
# 查看整体调优状态与服务概览
tuning-ctl status

# 实时查看 auto-cpufreq 动态频率与统计
tuning-ctl stats
# 或
sudo auto-cpufreq --stats

# 查看 TLP 硬件电源状态报告
tuning-ctl tlp -s
# 或
sudo tlp-stat -s
```
