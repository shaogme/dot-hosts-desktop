{
  config,
  pkgs,
  lib,
  ...
}:

with lib;

let
  cfg = config.desktop.bar.waybar;

  powerDaemonScript = pkgs.writeShellScriptBin "desktop-power-daemon" ''
    set -u

    INTERVAL="${toString cfg.powerDraw.interval}"
    OUTPUT_DIR="/run/desktop-power"
    OUTPUT_FILE="$OUTPUT_DIR/power.json"
    TMP_FILE="$OUTPUT_DIR/power.json.tmp"

    ${pkgs.coreutils}/bin/mkdir -p "$OUTPUT_DIR"
    ${pkgs.coreutils}/bin/chmod 755 "$OUTPUT_DIR"

    format_watts() {
      local uW=$1
      local w_x10=$(( uW / 100000 ))
      printf "%d.%01d" "$(( w_x10 / 10 ))" "$(( w_x10 % 10 ))"
    }

    declare -A prev_rapl_uj
    prev_rapl_time=0

    # 首次采样初始化 RAPL 节点
    for dom in /sys/class/powercap/intel-rapl:* /sys/devices/virtual/powercap/intel-rapl/intel-rapl:*; do
      if [ -f "$dom/energy_uj" ]; then
        prev_rapl_uj["$dom"]=$(${pkgs.coreutils}/bin/cat "$dom/energy_uj" 2>/dev/null || echo 0)
      fi
    done
    prev_rapl_time=$(${pkgs.coreutils}/bin/date +%s%N)

    while true; do
      now_ns=$(${pkgs.coreutils}/bin/date +%s%N)

      total_uW=0
      cpu_uW=0
      gpu_uW=0
      bat_uW=0
      bat_status=""
      bat_cap=""
      has_bat=0

      # 1. 采集电池供电数据（移动端设备）
      for bat in /sys/class/power_supply/*; do
        [ -d "$bat" ] || continue
        type_file="$bat/type"
        if [ -f "$type_file" ] && [ "$(${pkgs.coreutils}/bin/cat "$type_file" 2>/dev/null)" = "Battery" ]; then
          has_bat=1
          [ -f "$bat/status" ] && bat_status=$(${pkgs.coreutils}/bin/cat "$bat/status" 2>/dev/null)
          [ -f "$bat/capacity" ] && bat_cap=$(${pkgs.coreutils}/bin/cat "$bat/capacity" 2>/dev/null)

          b_p=0
          if [ -f "$bat/power_now" ]; then
            b_p=$(${pkgs.coreutils}/bin/cat "$bat/power_now" 2>/dev/null || echo 0)
          elif [ -f "$bat/current_now" ] && [ -f "$bat/voltage_now" ]; then
            c_uA=$(${pkgs.coreutils}/bin/cat "$bat/current_now" 2>/dev/null || echo 0)
            v_uV=$(${pkgs.coreutils}/bin/cat "$bat/voltage_now" 2>/dev/null || echo 0)
            b_p=$(( (c_uA * v_uV) / 1000000 ))
          fi
          (( b_p < 0 )) && b_p=$(( -b_p ))
          bat_uW=$(( bat_uW + b_p ))
        fi
      done

      # 2. 采集 CPU RAPL 功耗（Package 域，兼容 Intel / AMD Zen）
      rapl_detected=0
      for dom in /sys/class/powercap/intel-rapl:* /sys/devices/virtual/powercap/intel-rapl/intel-rapl:*; do
        [ -f "$dom/energy_uj" ] || continue
        name="package"
        [ -f "$dom/name" ] && name=$(${pkgs.coreutils}/bin/cat "$dom/name" 2>/dev/null)
        [[ "$name" =~ (core|dram|uncore) ]] && continue

        cur_uj=$(${pkgs.coreutils}/bin/cat "$dom/energy_uj" 2>/dev/null || echo 0)
        max_uj=0
        [ -f "$dom/max_energy_range_uj" ] && max_uj=$(${pkgs.coreutils}/bin/cat "$dom/max_energy_range_uj" 2>/dev/null || echo 0)

        if [ -n "''${prev_rapl_uj["$dom"]:-}" ] && [ "$prev_rapl_time" -gt 0 ]; then
          last_uj=''${prev_rapl_uj["$dom"]}
          diff_uj=0
          if (( cur_uj >= last_uj )); then
            diff_uj=$(( cur_uj - last_uj ))
          elif (( max_uj > 0 )); then
            diff_uj=$(( (cur_uj + max_uj) - last_uj ))
          fi

          time_diff_ns=$(( now_ns - prev_rapl_time ))
          time_diff_ms=$(( time_diff_ns / 1000000 ))
          if (( time_diff_ms > 0 )); then
            p_uW=$(( (diff_uj * 1000) / time_diff_ms ))
            cpu_uW=$(( cpu_uW + p_uW ))
            rapl_detected=1
          fi
        fi
        prev_rapl_uj["$dom"]=$cur_uj
      done
      prev_rapl_time=$now_ns

      # 3. 若无 RAPL，回退检测 hwmon CPU 功耗（例如 AMD k10temp / zenpower）
      if (( rapl_detected == 0 )); then
        for hw in /sys/class/hwmon/hwmon*; do
          [ -d "$hw" ] || continue
          hw_name=""
          [ -f "$hw/name" ] && hw_name=$(${pkgs.coreutils}/bin/cat "$hw/name" 2>/dev/null)
          if [[ "$hw_name" =~ (k10temp|zenpower|coretemp) ]] && [ -f "$hw/power1_input" ]; then
            p_uW=$(${pkgs.coreutils}/bin/cat "$hw/power1_input" 2>/dev/null || echo 0)
            cpu_uW=$(( cpu_uW + p_uW ))
            break
          fi
        done
      fi

      # 4. 采集 GPU 显卡功耗 (AMD / Intel DRM hwmon / NVIDIA)
      for card_hw in /sys/class/drm/card*/device/hwmon/hwmon*; do
        [ -d "$card_hw" ] || continue
        g_p=0
        if [ -f "$card_hw/power1_average" ]; then
          g_p=$(${pkgs.coreutils}/bin/cat "$card_hw/power1_average" 2>/dev/null || echo 0)
        elif [ -f "$card_hw/power1_input" ]; then
          g_p=$(${pkgs.coreutils}/bin/cat "$card_hw/power1_input" 2>/dev/null || echo 0)
        fi
        gpu_uW=$(( gpu_uW + g_p ))
      done

      # NVIDIA 显卡探测 (若存在 nvidia-smi)
      if command -v nvidia-smi >/dev/null 2>&1; then
        nv_val=$(nvidia-smi --query-gpu=power.draw --format=csv,noheader,nounits 2>/dev/null | ${pkgs.gawk}/bin/awk '{s+=$1} END {print s}')
        if [ -n "$nv_val" ]; then
          nv_uW=$(${pkgs.gawk}/bin/awk -v v="$nv_val" 'BEGIN { printf "%.0f", v * 1000000 }' 2>/dev/null || echo 0)
          gpu_uW=$(( gpu_uW + nv_uW ))
        fi
      fi

      # 5. 决策整机总功耗与状态显示
      power_class="normal"
      tooltip_details=""

      if (( has_bat == 1 )) && [ "$bat_status" = "Discharging" ] && (( bat_uW > 0 )); then
        total_uW=$bat_uW
        power_class="discharging"
        state_str="电池放电"
        [ -n "$bat_cap" ] && state_str="电池供电 ($bat_cap%)"
        tooltip_details="• 整机功耗 (电池): <b>$(format_watts "$total_uW") W</b>\n"
        (( cpu_uW > 0 )) && tooltip_details+="• CPU 封装: $(format_watts "$cpu_uW") W\n"
        (( gpu_uW > 0 )) && tooltip_details+="• GPU 显卡: $(format_watts "$gpu_uW") W\n"
        tooltip_details+="• 供电状态: $state_str"
      elif (( has_bat == 1 )) && [ "$bat_status" = "Charging" ]; then
        total_uW=$(( cpu_uW + gpu_uW ))
        power_class="charging"
        state_str="充电中"
        [ -n "$bat_cap" ] && state_str="充电中 ($bat_cap%)"
        tooltip_details="• 核心总功耗: <b>$(format_watts "$total_uW") W</b>\n"
        (( cpu_uW > 0 )) && tooltip_details+="• CPU 封装: $(format_watts "$cpu_uW") W\n"
        (( gpu_uW > 0 )) && tooltip_details+="• GPU 显卡: $(format_watts "$gpu_uW") W\n"
        (( bat_uW > 0 )) && tooltip_details+="• 充电功率: +$(format_watts "$bat_uW") W\n"
        tooltip_details+="• 供电状态: $state_str"
      else
        total_uW=$(( cpu_uW + gpu_uW ))
        state_str="交流供电 (AC)"
        tooltip_details="• 核心总功耗: <b>$(format_watts "$total_uW") W</b>\n"
        (( cpu_uW > 0 )) && tooltip_details+="• CPU 封装: $(format_watts "$cpu_uW") W\n"
        (( gpu_uW > 0 )) && tooltip_details+="• GPU 显卡: $(format_watts "$gpu_uW") W\n"
        tooltip_details+="• 供电状态: $state_str"
      fi

      if (( total_uW > 75000000 )); then
        power_class="$power_class high"
      elif (( total_uW > 30000000 )); then
        power_class="$power_class medium"
      else
        power_class="$power_class low"
      fi

      if (( total_uW == 0 && cpu_uW == 0 && gpu_uW == 0 && bat_uW == 0 )); then
        main_text="⚡ --W"
        tooltip="<b>实时硬件功耗监控</b>\n\n未检测到可用的硬件功耗传感器 (RAPL / HWMON / 电池)"
        power_class="unknown"
      else
        main_text="⚡ $(format_watts "$total_uW")W"
        tooltip="<b>实时硬件功耗监控</b>\n\n$tooltip_details"
      fi

      ${pkgs.jq}/bin/jq -nc \
        --arg text "$main_text" \
        --arg tooltip "$tooltip" \
        --arg class "$power_class" \
        '{ text: $text, tooltip: $tooltip, class: $class }' > "$TMP_FILE"

      ${pkgs.coreutils}/bin/chmod 644 "$TMP_FILE"
      ${pkgs.coreutils}/bin/mv -f "$TMP_FILE" "$OUTPUT_FILE"

      ${pkgs.coreutils}/bin/sleep "$INTERVAL"
    done
  '';
in
{
  config = mkIf (cfg.enable && cfg.powerDraw.enable) {
    systemd.services.desktop-power-daemon = {
      description = "Desktop Hardware Power Consumption Monitoring Daemon";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-modules-load.service" ];
      path = [ pkgs.coreutils pkgs.gawk pkgs.jq ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${powerDaemonScript}/bin/desktop-power-daemon";
        Restart = "always";
        RestartSec = 3;
        RuntimeDirectory = "desktop-power";
        RuntimeDirectoryMode = "0755";
      };
    };
  };
}
