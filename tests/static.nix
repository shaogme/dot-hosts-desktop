{ pkgs, configuration, name, extraModules ? [] }:

let
  # 评估 configuration.nix（支持 extraModules 覆盖注入）
  eval = import (pkgs.path + "/nixos/lib/eval-config.nix") {
    modules = [ configuration ] ++ extraModules ++ [
      {
        # 如果需要可以在这里添加覆盖
      }
    ];
    inherit pkgs;
  };
  
  cfg = eval.config;
  lib = pkgs.lib;

  # 只过滤出失败的断言，避免评估已通过断言的 message 导致惰性求值报错
  failedAssertions = pkgs.lib.filter (x: !x.assertion) cfg.assertions;

  # 将失败的断言转换为 Bash 报错语句
  generateFailure = index: assertionObj: ''
    printf '错误: [%s] 静态断言未通过 - %s\n' ${pkgs.lib.escapeShellArg name} ${pkgs.lib.escapeShellArg assertionObj.message}
  '';

  failuresBash = pkgs.lib.concatStringsSep "\n" (pkgs.lib.imap0 generateFailure failedAssertions);
  failedCount = builtins.length failedAssertions;

  # Rio 配置静态语法与有效性验证
  rioEnabled = cfg.desktop.terminal.rio.enable or false;
  rioConfigFile =
    if cfg.environment.etc ? "xdg/rio/config.toml" && cfg.environment.etc."xdg/rio/config.toml" ? source then
      cfg.environment.etc."xdg/rio/config.toml".source
    else if cfg.environment.etc ? "xdg/rio/config.toml" && cfg.environment.etc."xdg/rio/config.toml" ? text then
      pkgs.writeText "${name}-rio-config" cfg.environment.etc."xdg/rio/config.toml".text
    else
      pkgs.emptyFile;

  # Niri 配置静态语法与有效性验证
  niriEnabled = cfg.desktop.windowManager.niri.enable or false;
  niriConfigFile =
    if cfg.environment.etc ? "xdg/niri/config.kdl" && cfg.environment.etc."xdg/niri/config.kdl" ? source then
      cfg.environment.etc."xdg/niri/config.kdl".source
    else if cfg.environment.etc ? "xdg/niri/config.kdl" && cfg.environment.etc."xdg/niri/config.kdl" ? text then
      pkgs.writeText "${name}-niri-config" cfg.environment.etc."xdg/niri/config.kdl".text
    else
      pkgs.emptyFile;

  niriGamemodeConfigFile =
    if cfg.environment.etc ? "xdg/niri/config-gamemode.kdl" && cfg.environment.etc."xdg/niri/config-gamemode.kdl" ? source then
      cfg.environment.etc."xdg/niri/config-gamemode.kdl".source
    else if cfg.environment.etc ? "xdg/niri/config-gamemode.kdl" && cfg.environment.etc."xdg/niri/config-gamemode.kdl" ? text then
      pkgs.writeText "${name}-niri-gamemode-config" cfg.environment.etc."xdg/niri/config-gamemode.kdl".text
    else
      pkgs.emptyFile;

  # ── 主题模块静态验证（主配置） ──────────────────────────────────────────
  themeEnabled = cfg.desktop.theme.enable or false;
  darkmanConfigFile =
    if cfg.environment.etc ? "xdg/darkman/config.yaml" && cfg.environment.etc."xdg/darkman/config.yaml" ? text then
      pkgs.writeText "${name}-darkman-config" cfg.environment.etc."xdg/darkman/config.yaml".text
    else
      pkgs.emptyFile;
  darkmanConfigText = if cfg.environment.etc ? "xdg/darkman/config.yaml" && cfg.environment.etc."xdg/darkman/config.yaml" ? text then cfg.environment.etc."xdg/darkman/config.yaml".text else "";
  themeHookFile =
    if cfg.environment.etc ? "xdg/darkman/theme-switch.sh" && cfg.environment.etc."xdg/darkman/theme-switch.sh" ? source then
      cfg.environment.etc."xdg/darkman/theme-switch.sh".source
    else
      pkgs.emptyFile;
  themeMode = cfg.desktop.theme.mode or "auto";
  # 用于多项 Nix 属性的 shell 布尔值插值
  hasDarkmanPkg = lib.any (p: lib.hasInfix "darkman" (p.name or p.pname or "")) cfg.environment.systemPackages;
  hasThemeCtlPkg = lib.any (p: lib.hasInfix "theme-ctl" (p.name or p.pname or "")) cfg.environment.systemPackages;
  hasThemeSyncPkg = lib.any (p: lib.hasInfix "theme-sync" (p.name or p.pname or "")) cfg.environment.systemPackages;
  hasDconfPkg = lib.any (p: lib.hasInfix "dconf" (p.name or p.pname or "")) cfg.environment.systemPackages;
  hasAdwaitaPkg = lib.any (p: lib.hasInfix "adwaita-icon-theme" (p.name or p.pname or "")) cfg.environment.systemPackages;
  systemPackagesNames = builtins.concatStringsSep "," (map (p: p.name or p.pname or "") cfg.environment.systemPackages);
  # systemd 派生属性快捷访问
  darkmanService = cfg.systemd.user.services.darkman or null;
  themeSeedService = cfg.systemd.user.services.theme-seed or null;
  themeSyncService = cfg.systemd.user.services.theme-sync or null;
  themeSyncPath = cfg.systemd.user.paths.theme-sync or null;
  tmpfilesRules = cfg.systemd.user.tmpfiles.rules or [];
  themeSyncExec = if themeSyncService != null then themeSyncService.serviceConfig.ExecStart or "" else "";
  themeSeedExec = if themeSeedService != null then themeSeedService.serviceConfig.ExecStart or "" else "";
  hasTmpfilesGtk3 = lib.any (r: lib.hasInfix "gtk-3.0" r) tmpfilesRules;
  hasTmpfilesGtk4 = lib.any (r: lib.hasInfix "gtk-4.0" r) tmpfilesRules;

  # ── 覆盖测试：主题多变体评估（基于当前 host 配置叠加 overlay） ───────
  # 变体1：强制深色模式
  evalThemeDark = import (pkgs.path + "/nixos/lib/eval-config.nix") {
    modules = [ configuration { desktop.theme.mode = lib.mkForce "dark"; } ];
    inherit pkgs;
  };
  cfgThemeDark = evalThemeDark.config;
  hasDarkExecPost = cfgThemeDark.systemd.user.services.darkman.serviceConfig ? ExecStartPost;
  darkExecPostVal = if hasDarkExecPost then cfgThemeDark.systemd.user.services.darkman.serviceConfig.ExecStartPost else "";

  # 变体2：强制浅色模式
  evalThemeLight = import (pkgs.path + "/nixos/lib/eval-config.nix") {
    modules = [ configuration { desktop.theme.mode = lib.mkForce "light"; } ];
    inherit pkgs;
  };
  cfgThemeLight = evalThemeLight.config;
  hasLightExecPost = cfgThemeLight.systemd.user.services.darkman.serviceConfig ? ExecStartPost;
  lightExecPostVal = if hasLightExecPost then cfgThemeLight.systemd.user.services.darkman.serviceConfig.ExecStartPost else "";

  # 变体3：自动模式（应无 ExecStartPost）
  # host 默认已为 auto，直接使用 cfg 验证

  # 变体4：Geoclue 与自定义经纬度
  evalThemeGeoclue = import (pkgs.path + "/nixos/lib/eval-config.nix") {
    modules = [ configuration { desktop.theme.solar = lib.mkForce { latitude = 39.9042; longitude = 116.4074; useGeoclue = true; }; } ];
    inherit pkgs;
  };
  cfgThemeGeoclue = evalThemeGeoclue.config;
  geoclueConfigText = if cfgThemeGeoclue.environment.etc ? "xdg/darkman/config.yaml" && cfgThemeGeoclue.environment.etc."xdg/darkman/config.yaml" ? text then cfgThemeGeoclue.environment.etc."xdg/darkman/config.yaml".text else "";
  geoclueHookFile = if cfgThemeGeoclue.environment.etc ? "xdg/darkman/theme-switch.sh" && cfgThemeGeoclue.environment.etc."xdg/darkman/theme-switch.sh" ? source then cfgThemeGeoclue.environment.etc."xdg/darkman/theme-switch.sh".source else pkgs.emptyFile;

  # 变体5：全自定义主题（覆盖 dark/light/cursor/niri/layout/extraHook/wallpaper）
  evalThemeCustom = import (pkgs.path + "/nixos/lib/eval-config.nix") {
    modules = [ configuration {
      desktop.theme = lib.mkForce {
        enable = true;
        mode = "dark";
        solar = { latitude = 22.5; longitude = 114.1; useGeoclue = false; };
        layout.focusRing.width = 6;
        icons = { enable = true; package = pkgs.adwaita-icon-theme; name = "Papirus"; };
        cursor = { name = "Bibata-Modern-Classic"; size = 32; };
        dark = {
          gtkTheme = "Adwaita-dark-custom";
          iconTheme = "Papirus-Dark";
          cursor = { name = "Bibata-Modern-Classic"; size = 32; };
          niri = { focusRingActiveColor = "#ff0000"; borderActiveColor = "#00ff00"; inactiveColor = "#0000ff"; };
          wallpaper = "/tmp/dark.jpg";
        };
        light = {
          gtkTheme = "Adwaita-custom";
          iconTheme = "Papirus-Light";
          cursor = { name = "Bibata-Modern-Ice"; size = 28; };
          niri = { focusRingActiveColor = "#112233"; borderActiveColor = "#445566"; inactiveColor = "#778899"; };
          wallpaper = "/tmp/light.jpg";
        };
        extraSwitchHooks = ''echo "custom-hook-executed"'';
        homeManager.enable = true;
      };
    } ];
    inherit pkgs;
  };
  cfgThemeCustom = evalThemeCustom.config;
  customDarkmanText = if cfgThemeCustom.environment.etc ? "xdg/darkman/config.yaml" && cfgThemeCustom.environment.etc."xdg/darkman/config.yaml" ? text then cfgThemeCustom.environment.etc."xdg/darkman/config.yaml".text else "";
  customHookFile = if cfgThemeCustom.environment.etc ? "xdg/darkman/theme-switch.sh" && cfgThemeCustom.environment.etc."xdg/darkman/theme-switch.sh" ? source then cfgThemeCustom.environment.etc."xdg/darkman/theme-switch.sh".source else pkgs.emptyFile;
  customHasAwww = lib.hasInfix "awww-set" customDarkmanText || true; # placeholder, actual check via hook file grep in shell
  customSolarLat = toString cfgThemeCustom.desktop.theme.solar.latitude;
  customSolarLng = toString cfgThemeCustom.desktop.theme.solar.longitude;

  # 变体6：禁用主题
  evalThemeDisabled = import (pkgs.path + "/nixos/lib/eval-config.nix") {
    modules = [ configuration { desktop.theme.enable = lib.mkForce false; } ];
    inherit pkgs;
  };
  cfgThemeDisabled = evalThemeDisabled.config;
  disabledHasDarkmanService = cfgThemeDisabled.systemd.user.services ? darkman;
  disabledHasThemeSeedService = cfgThemeDisabled.systemd.user.services ? theme-seed;
  disabledHasThemeSyncService = cfgThemeDisabled.systemd.user.services ? theme-sync;
  disabledHasThemeSyncPath = cfgThemeDisabled.systemd.user.paths ? theme-sync;
  disabledHasDarkmanEtc = cfgThemeDisabled.environment.etc ? "xdg/darkman/config.yaml";
  disabledHasHookEtc = cfgThemeDisabled.environment.etc ? "xdg/darkman/theme-switch.sh";
  disabledHasDarkmanPkg = lib.any (p: lib.hasInfix "darkman" (p.name or p.pname or "")) cfgThemeDisabled.environment.systemPackages;

  # 变体7：禁用图标主题
  evalThemeIconsDisabled = import (pkgs.path + "/nixos/lib/eval-config.nix") {
    modules = [ configuration { desktop.theme.icons.enable = lib.mkForce false; } ];
    inherit pkgs;
  };
  cfgThemeIconsDisabled = evalThemeIconsDisabled.config;
  iconsDisabledHasAdwaita = lib.any (p: lib.hasInfix "adwaita-icon-theme" (p.name or p.pname or "")) cfgThemeIconsDisabled.environment.systemPackages;
  iconsDisabledHasHicolor = lib.any (p: lib.hasInfix "hicolor-icon-theme" (p.name or p.pname or "")) cfgThemeIconsDisabled.environment.systemPackages;

  # 变体8：禁用 homeManager 集成
  evalThemeHMDisabled = import (pkgs.path + "/nixos/lib/eval-config.nix") {
    modules = [ configuration { desktop.theme.homeManager.enable = lib.mkForce false; } ];
    inherit pkgs;
  };
  cfgThemeHMDisabled = evalThemeHMDisabled.config;
  # home-manager 共享模块是否包含主题集成（通过检查 sharedModules 长度与内容）
  hmEnabledSharedModulesLen = builtins.length (cfg.home-manager.sharedModules or []);
  hmDisabledSharedModulesLen = builtins.length (cfgThemeHMDisabled.home-manager.sharedModules or []);
  # 对于 HM 禁用变体，验证其 sharedModules 不包含 gtk 清理逻辑（长度应更少或为0）
  # 由于无法直接 introspect 函数内容，至少验证启用时有模块，禁用时模块数减少

  # 安全转义
  escape = v: lib.escapeShellArg (toString v);
in
pkgs.runCommand "${name}-static-check" {
  nativeBuildInputs = [ pkgs.rio pkgs.python3 cfg.desktop.windowManager.niri.package ];
  passthru = { inherit eval evalThemeDark evalThemeLight evalThemeGeoclue evalThemeCustom evalThemeDisabled evalThemeIconsDisabled evalThemeHMDisabled; };
} ''
  echo "--- 正在执行静态检查 [${name}] ---"

  ${if failedCount > 0 then ''
    ${failuresBash}
    exit 1
  '' else ''
    echo "[${name}] 所有静态断言检查通过！"
  ''}

  ${if rioEnabled then ''
    echo "[${name}] 正在验证 Rio 终端 TOML 配置合法性与语法结构..."
    python3 -c "import tomllib; tomllib.load(open('${rioConfigFile}', 'rb'))"
    echo "[${name}] Rio 终端配置合法性验证通过！"
  '' else ""}

  ${if niriEnabled then ''
    echo "[${name}] 正在验证 Niri KDL 配置合法性与语法结构..."
    ${cfg.desktop.windowManager.niri.package}/bin/niri validate --config "${niriConfigFile}"
    ${cfg.desktop.windowManager.niri.package}/bin/niri validate --config "${niriGamemodeConfigFile}"
    echo "[${name}] Niri 核心与游戏模式配置合法性验证通过！"
  '' else ""}

  ${if themeEnabled then ''
    echo "[${name}] 正在验证全局主题模块 (desktop.theme) 配置..."

    # ── 1. darkman YAML 配置文件格式与内容精确校验 ─────────────────────
    echo "[${name}] 验证 darkman YAML 配置文件..."
    test -s "${darkmanConfigFile}" || {
      echo "错误: darkman 配置文件为空或不存在！"
      exit 1
    }
    grep -q "^lat:" "${darkmanConfigFile}" || {
      echo "错误: darkman 配置缺少 lat 字段！"
      exit 1
    }
    grep -q "^lng:" "${darkmanConfigFile}" || {
      echo "错误: darkman 配置缺少 lng 字段！"
      exit 1
    }
    grep -q "^usegeoclue:" "${darkmanConfigFile}" || {
      echo "错误: darkman 配置缺少 usegeoclue 字段！"
      exit 1
    }
    grep -q "^portal: true" "${darkmanConfigFile}" || {
      echo "错误: darkman 配置缺少 portal: true 字段！"
      exit 1
    }
    # 精确值校验：与 Nix 配置保持一致
    grep -q "lat: ${toString cfg.desktop.theme.solar.latitude}" "${darkmanConfigFile}" || {
      echo "错误: darkman lat 值与配置不一致（期望 ${toString cfg.desktop.theme.solar.latitude}）"
      cat "${darkmanConfigFile}"
      exit 1
    }
    grep -q "lng: ${toString cfg.desktop.theme.solar.longitude}" "${darkmanConfigFile}" || {
      echo "错误: darkman lng 值与配置不一致（期望 ${toString cfg.desktop.theme.solar.longitude}）"
      cat "${darkmanConfigFile}"
      exit 1
    }
    if [ "${if cfg.desktop.theme.solar.useGeoclue then "true" else "false"}" = "true" ]; then
      grep -q "usegeoclue: true" "${darkmanConfigFile}" || { echo "错误: usegeoclue 应为 true"; exit 1; }
    else
      grep -q "usegeoclue: false" "${darkmanConfigFile}" || { echo "错误: usegeoclue 应为 false"; exit 1; }
    fi
    echo "[${name}] darkman YAML 配置文件格式验证通过！"

    # ── 2. 主题切换钩子脚本存在性与权限及内容深度校验 ──────────────────
    echo "[${name}] 验证主题切换钩子脚本 theme-switch.sh..."
    test -f "${themeHookFile}" || {
      echo "错误: theme-switch.sh 钩子文件不存在！"
      exit 1
    }
    test -x "${themeHookFile}" || {
      echo "错误: theme-switch.sh 钩子文件无执行权限！"
      exit 1
    }
    # 内容校验：runtime SSOT 架构
    grep -q "RUNTIME_DIR" "${themeHookFile}" || { echo "错误: hook 未包含 RUNTIME_DIR 运行时目录逻辑"; exit 1; }
    grep -q "desktop-theme" "${themeHookFile}" || { echo "错误: hook 未包含 desktop-theme 运行时路径"; exit 1; }
    grep -q "gtk-settings.ini" "${themeHookFile}" || { echo "错误: hook 未包含 gtk-settings.ini 写入逻辑"; exit 1; }
    grep -q "theme-sync" "${themeHookFile}" || { echo "错误: hook 未包含 theme-sync 触发逻辑"; exit 1; }
    grep -q "install -Dm644" "${themeHookFile}" || { echo "错误: hook 未使用 install 声明式写入"; exit 1; }
    # dconf / gsettings 广播
    grep -q "dconf write" "${themeHookFile}" || { echo "错误: hook 未包含 dconf 广播"; exit 1; }
    grep -q "gsettings set" "${themeHookFile}" || { echo "错误: hook 未包含 gsettings 广播"; exit 1; }
    # Niri 动态颜色注入
    grep -q "NIRI_THEME_DIR" "${themeHookFile}" || { echo "错误: hook 未包含 Niri 主题目录逻辑"; exit 1; }
    grep -q "theme.kdl" "${themeHookFile}" || { echo "错误: hook 未包含 Niri theme.kdl 生成"; exit 1; }
    grep -q 'focus-ring' "${themeHookFile}" || { echo "错误: hook 未包含 focus-ring 配置"; exit 1; }
    grep -q 'active-color' "${themeHookFile}" || { echo "错误: hook 未包含 active-color"; exit 1; }
    # 验证深浅色变量已正确内联（来自 Nix 配置）
    grep -q "${cfg.desktop.theme.dark.gtkTheme}" "${themeHookFile}" || { echo "错误: hook 未内联 dark.gtkTheme (${cfg.desktop.theme.dark.gtkTheme})"; exit 1; }
    grep -q "${cfg.desktop.theme.light.gtkTheme}" "${themeHookFile}" || { echo "错误: hook 未内联 light.gtkTheme (${cfg.desktop.theme.light.gtkTheme})"; exit 1; }
    grep -q "${cfg.desktop.theme.dark.iconTheme}" "${themeHookFile}" || { echo "错误: hook 未内联 dark.iconTheme"; exit 1; }
    grep -q "${cfg.desktop.theme.dark.niri.focusRingActiveColor}" "${themeHookFile}" || { echo "错误: hook 未内联 dark niri focusRingActiveColor"; exit 1; }
    grep -q "${cfg.desktop.theme.light.niri.focusRingActiveColor}" "${themeHookFile}" || { echo "错误: hook 未内联 light niri focusRingActiveColor"; exit 1; }
    grep -q "width ${toString cfg.desktop.theme.layout.focusRing.width}" "${themeHookFile}" || { echo "错误: hook 未内联 layout.focusRing.width (${toString cfg.desktop.theme.layout.focusRing.width})"; exit 1; }
    # Waybar / SwayNC 刷新
    grep -q "pkill -SIGUSR2 waybar" "${themeHookFile}" || { echo "错误: hook 未包含 Waybar 热重载"; exit 1; }
    grep -q "swaync-client" "${themeHookFile}" || { echo "错误: hook 未包含 SwayNC 刷新"; exit 1; }
    # 壁纸与 extraHooks（若配置了）
    ${lib.optionalString (cfg.desktop.theme.dark.wallpaper != null || cfg.desktop.theme.light.wallpaper != null) ''
      grep -q "awww-set" "${themeHookFile}" || { echo "错误: hook 在配置壁纸时应包含 awww-set"; exit 1; }
    ''}
    ${lib.optionalString (cfg.desktop.theme.extraSwitchHooks != "") ''
      grep -q "custom-hook" "${themeHookFile}" || true
      # 至少验证 extraSwitchHooks 已原样嵌入
      if ! grep -qF ${escape cfg.desktop.theme.extraSwitchHooks} "${themeHookFile}"; then
        echo "错误: hook 未正确嵌入 extraSwitchHooks 内容"
        exit 1
      fi
    ''}
    echo "[${name}] theme-switch.sh 脚本深度验证通过！"

    # ── 3. 主题模式枚举与 darkman ExecStartPost 逻辑 ───────────────────
    THEME_MODE="${themeMode}"
    case "$THEME_MODE" in
      auto|dark|light)
        echo "[${name}] 主题模式 '${themeMode}' 合法！"
        ;;
      *)
        echo "错误: 主题模式 '${themeMode}' 不合法（必须为 auto/dark/light）！"
        exit 1
        ;;
    esac
    # ExecStartPost 仅在非 auto 模式下存在
    if [ "${themeMode}" = "auto" ]; then
      if [ "${if darkmanService != null && darkmanService.serviceConfig ? ExecStartPost then "true" else "false"}" = "true" ]; then
        echo "错误: auto 模式下不应设置 ExecStartPost"
        exit 1
      fi
      echo "[${name}] auto 模式 ExecStartPost 缺省验证通过！"
    else
      if [ "${if darkmanService != null && darkmanService.serviceConfig ? ExecStartPost then "true" else "false"}" != "true" ]; then
        echo "错误: ${themeMode} 模式下应设置 ExecStartPost"
        exit 1
      fi
      echo "[${name}] ${themeMode} 模式 ExecStartPost 验证通过！"
    fi

    # ── 4. 系统软件包包含性验证 ────────────────────────────────────────
    echo "[${name}] 验证 environment.systemPackages..."
    if [ "${if hasDarkmanPkg then "true" else "false"}" != "true" ]; then
      echo "错误: systemPackages 缺少 darkman (当前: ${systemPackagesNames})"
      exit 1
    fi
    if [ "${if hasThemeCtlPkg then "true" else "false"}" != "true" ]; then
      echo "错误: systemPackages 缺少 theme-ctl"
      exit 1
    fi
    if [ "${if hasThemeSyncPkg then "true" else "false"}" != "true" ]; then
      echo "错误: systemPackages 缺少 theme-sync-apply"
      exit 1
    fi
    if [ "${if hasDconfPkg then "true" else "false"}" != "true" ]; then
      echo "错误: systemPackages 缺少 dconf"
      exit 1
    fi
    ${lib.optionalString cfg.desktop.theme.icons.enable ''
      if [ "${if hasAdwaitaPkg then "true" else "false"}" != "true" ]; then
        echo "错误: icons.enable=true 时 systemPackages 应包含 adwaita-icon-theme"
        exit 1
      fi
    ''}
    echo "[${name}] systemPackages 验证通过！"

    # ── 5. 会话环境变量验证 ─────────────────────────────────────────────
    echo "[${name}] 验证 environment.sessionVariables..."
    if [ "${cfg.environment.sessionVariables.XCURSOR_THEME or ""}" != "${cfg.desktop.theme.cursor.name}" ]; then
      echo "错误: XCURSOR_THEME 与 cursor.name 不一致（期望 ${cfg.desktop.theme.cursor.name}，实际 ${cfg.environment.sessionVariables.XCURSOR_THEME or ""})"
      exit 1
    fi
    if [ "${toString cfg.environment.sessionVariables.XCURSOR_SIZE}" != "${toString cfg.desktop.theme.cursor.size}" ]; then
      echo "错误: XCURSOR_SIZE 与 cursor.size 不一致"
      exit 1
    fi
    echo "[${name}] sessionVariables 验证通过！"

    # ── 6. systemd 用户服务与 tmpfiles / path 单元验证 ─────────────────
    echo "[${name}] 验证 systemd 用户单元..."
    # darkman service
    if [ "${if darkmanService != null then "true" else "false"}" != "true" ]; then
      echo "错误: systemd.user.services.darkman 未定义"
      exit 1
    fi
    if [ "${darkmanService.serviceConfig.Type or ""}" != "dbus" ]; then
      echo "错误: darkman service Type 应为 dbus"
      exit 1
    fi
    if [ "${darkmanService.serviceConfig.BusName or ""}" != "nl.whynothugo.darkman" ]; then
      echo "错误: darkman BusName 不正确"
      exit 1
    fi
    if ! echo "${darkmanService.serviceConfig.ExecStart or ""}" | grep -q "darkman run"; then
      echo "错误: darkman ExecStart 应包含 darkman run"
      exit 1
    fi
    if [ "${if darkmanService.unitConfig ? ConditionEnvironment then "true" else "false"}" != "true" ]; then
      echo "错误: darkman 应设置 ConditionEnvironment=WAYLAND_DISPLAY"
      exit 1
    fi
    if [ "${darkmanService.unitConfig.ConditionEnvironment or ""}" != "WAYLAND_DISPLAY" ]; then
      echo "错误: darkman ConditionEnvironment 值不正确"
      exit 1
    fi
    # tmpfiles
    if [ "${if hasTmpfilesGtk3 then "true" else "false"}" != "true" ]; then
      echo "错误: tmpfiles 未包含 gtk-3.0 目录规则"
      exit 1
    fi
    if [ "${if hasTmpfilesGtk4 then "true" else "false"}" != "true" ]; then
      echo "错误: tmpfiles 未包含 gtk-4.0 目录规则"
      exit 1
    fi
    # theme-sync service (自愈：不再依赖 ConditionPathExists，由脚本内部播种)
    if [ "${if themeSyncService != null then "true" else "false"}" != "true" ]; then
      echo "错误: systemd.user.services.theme-sync 未定义"
      exit 1
    fi
    if [ "${themeSyncService.serviceConfig.Type or ""}" != "oneshot" ]; then
      echo "错误: theme-sync Type 应为 oneshot"
      exit 1
    fi
    if [ "${if themeSyncService.serviceConfig ? RemainAfterExit then "true" else "false"}" != "true" ]; then
      echo "错误: theme-sync 应设置 RemainAfterExit"
      exit 1
    fi
    if ! echo "${themeSyncService.serviceConfig.ExecStart or ""}" | grep -q "theme-sync-apply"; then
      echo "错误: theme-sync ExecStart 应指向 theme-sync-apply"
      exit 1
    fi
    if [ "${if themeSyncService.unitConfig ? ConditionPathExists then "true" else "false"}" = "true" ]; then
      echo "错误: theme-sync 不应设置 ConditionPathExists（已由脚本自愈处理，移除以避免启动期跳过）"
      exit 1
    fi
    if [ "${toString (builtins.length (themeSyncService.wantedBy or []))}" != "0" ]; then
      echo "错误: theme-sync 不应设置 wantedBy（应仅由 path 触发，避免启动期空转）"
      exit 1
    fi
    # theme-seed service (冷启动自愈)
    if [ "${if themeSeedService != null then "true" else "false"}" != "true" ]; then
      echo "错误: systemd.user.services.theme-seed 未定义"
      exit 1
    fi
    if [ "${themeSeedService.serviceConfig.Type or ""}" != "oneshot" ]; then
      echo "错误: theme-seed Type 应为 oneshot"
      exit 1
    fi
    if [ "${if themeSeedService.serviceConfig ? RemainAfterExit then "true" else "false"}" != "true" ]; then
      echo "错误: theme-seed 应设置 RemainAfterExit"
      exit 1
    fi
    if [ "${themeSeedService.unitConfig.ConditionPathExists or ""}" != "!%t/desktop-theme/gtk-settings.ini" ]; then
      echo "错误: theme-seed ConditionPathExists 应为 !%t/desktop-theme/gtk-settings.ini"
      exit 1
    fi
    if [ "${toString (builtins.length (themeSeedService.wantedBy or []))}" = "0" ]; then
      echo "错误: theme-seed 应设置 wantedBy=graphical-session.target"
      exit 1
    fi
    # theme-sync path (PathModified 替代 PathChanged 以可靠捕捉 install 写入)
    if [ "${if themeSyncPath != null then "true" else "false"}" != "true" ]; then
      echo "错误: systemd.user.paths.theme-sync 未定义"
      exit 1
    fi
    if [ "${themeSyncPath.pathConfig.PathModified or ""}" != "%t/desktop-theme/gtk-settings.ini" ]; then
      echo "错误: theme-sync PathModified 应为 %t/desktop-theme/gtk-settings.ini"
      exit 1
    fi
    if [ "${if themeSyncPath.pathConfig ? PathExists then "true" else "false"}" != "true" ]; then
      echo "错误: theme-sync PathExists 未设置"
      exit 1
    fi
    if [ "${themeSyncPath.pathConfig.PathExists or ""}" != "%t/desktop-theme/gtk-settings.ini" ]; then
      echo "错误: theme-sync PathExists 应为 %t/desktop-theme/gtk-settings.ini"
      exit 1
    fi
    if [ "${if themeSyncPath.pathConfig ? MakeDirectory then "true" else "false"}" != "true" ]; then
      echo "错误: theme-sync 应设置 MakeDirectory"
      exit 1
    fi
    if [ "${if themeSyncPath.unitConfig ? TriggerLimitIntervalSec then "true" else "false"}" != "true" ]; then
      echo "错误: theme-sync path 应设置 TriggerLimitIntervalSec"
      exit 1
    fi
    if [ "${if themeSyncPath.unitConfig ? TriggerLimitBurst then "true" else "false"}" != "true" ]; then
      echo "错误: theme-sync path 应设置 TriggerLimitBurst"
      exit 1
    fi
    if [ "${toString (themeSyncPath.unitConfig.TriggerLimitBurst or "")}" != "1" ]; then
      echo "错误: theme-sync path TriggerLimitBurst 应为 1"
      exit 1
    fi
    if [ "${themeSyncPath.pathConfig.Unit or ""}" != "theme-sync.service" ]; then
      echo "错误: theme-sync path Unit 应为 theme-sync.service"
      exit 1
    fi
    # ── 6b. 重试上限与熔断验证（每个服务仅 1 次，根治竞态） ──
    if [ "${toString (themeSyncService.unitConfig.StartLimitBurst or "")}" != "1" ]; then
      echo "错误: theme-sync StartLimitBurst 应为 1"
      exit 1
    fi
    if [ "${themeSyncService.unitConfig.StartLimitIntervalSec or ""}" != "60s" ]; then
      echo "错误: theme-sync StartLimitIntervalSec 应为 60s"
      exit 1
    fi
    if [ "${toString (themeSeedService.unitConfig.StartLimitBurst or "")}" != "1" ]; then
      echo "错误: theme-seed StartLimitBurst 应为 1"
      exit 1
    fi
    if [ "${themeSeedService.unitConfig.StartLimitIntervalSec or ""}" != "60s" ]; then
      echo "错误: theme-seed StartLimitIntervalSec 应为 60s"
      exit 1
    fi
    # 检查脚本内重试计数逻辑（仅 1 次）
    themeSyncBin="${themeSyncExec}"
    if [ -n "$themeSyncBin" ] && [ -f "$themeSyncBin" ]; then
      grep -q "max retries 1" "$themeSyncBin" || { echo "错误: theme-sync-apply 未包含 max retries 1 逻辑"; exit 1; }
      grep -q "RETRY_FILE" "$themeSyncBin" || { echo "错误: theme-sync-apply 未包含 RETRY_FILE"; exit 1; }
    fi
    themeSeedBin="${themeSeedExec}"
    if [ -n "$themeSeedBin" ] && [ -f "$themeSeedBin" ]; then
      grep -q "max retries 1" "$themeSeedBin" || { echo "错误: theme-seed 未包含 max retries 1 逻辑"; exit 1; }
    fi
    if grep -q 'theme-sync-apply.*bin/theme-sync-apply' "${themeHookFile}" 2>/dev/null; then
      echo "错误: theme-switch.sh 不应同步调用 theme-sync-apply（仅允许 systemctl --no-block）"
      exit 1
    fi
    echo "[${name}] 重试熔断验证通过！"
    echo "[${name}] systemd 单元验证通过！"

    # ── 7. dconf 服务验证 ──────────────────────────────────────────────
    if [ "${if cfg.programs.dconf.enable then "true" else "false"}" != "true" ]; then
      echo "错误: programs.dconf.enable 应为 true"
      exit 1
    fi
    echo "[${name}] dconf 验证通过！"

    # ── 8. Home Manager 集成验证（若启用） ─────────────────────────────
    ${lib.optionalString (cfg.homeManager.enable or false) ''
      echo "[${name}] 验证 Home Manager 集成..."
      if [ "${toString hmEnabledSharedModulesLen}" = "0" ]; then
        echo "错误: homeManager.enable=true 时 sharedModules 应非空"
        exit 1
      fi
      echo "[${name}] Home Manager 集成验证通过！(sharedModules 数量: ${toString hmEnabledSharedModulesLen})"
    ''}

    echo "[${name}] 全局主题模块静态配置验证全部通过！"
  '' else ''
    echo "[${name}] 主题模块已禁用，跳过主题启用状态检查..."
    # 禁用时应无主题相关产物
    if [ "${if disabledHasDarkmanService then "true" else "false"}" = "true" ] || [ "${if disabledHasThemeSyncService then "true" else "false"}" = "true" ]; then
      echo "注意: 禁用状态下仍检测到服务（由主配置变体验证覆盖）"
    fi
  ''}

  # ── 9. 主题模块覆盖测试：多变体深度验证（与 host 主配置无关，独立覆盖分支） ──
  echo "[${name}] 正在执行主题模块覆盖测试 (多变体验证)..."

  # 9.1 深色模式变体：ExecStartPost 应为 darkman set dark
  if [ "${if hasDarkExecPost then "true" else "false"}" != "true" ]; then
    echo "错误: [覆盖] dark 模式变体缺失 ExecStartPost"
    exit 1
  fi
  if ! echo ${escape darkExecPostVal} | grep -q "darkman set dark"; then
    echo "错误: [覆盖] dark 变体 ExecStartPost 未包含 'darkman set dark' (实际: ${darkExecPostVal})"
    exit 1
  fi
  echo "[${name}] [覆盖] dark 模式 ExecStartPost 验证通过！"

  # 9.2 浅色模式变体
  if [ "${if hasLightExecPost then "true" else "false"}" != "true" ]; then
    echo "错误: [覆盖] light 模式变体缺失 ExecStartPost"
    exit 1
  fi
  if ! echo ${escape lightExecPostVal} | grep -q "darkman set light"; then
    echo "错误: [覆盖] light 变体 ExecStartPost 未包含 'darkman set light'"
    exit 1
  fi
  echo "[${name}] [覆盖] light 模式 ExecStartPost 验证通过！"

  # 9.3 自动模式已在主配置中验证（无 ExecStartPost），此处额外确认默认 host 为 auto 时无该字段
  if [ "${themeMode}" = "auto" ]; then
    if [ "${if darkmanService != null && darkmanService.serviceConfig ? ExecStartPost then "true" else "false"}" = "true" ]; then
      echo "错误: [覆盖] auto 模式不应有 ExecStartPost"
      exit 1
    fi
    echo "[${name}] [覆盖] auto 模式无 ExecStartPost 验证通过！"
  fi

  # 9.4 Geoclue 变体：darkman 配置应包含 usegeoclue:true 与自定义经纬度
  echo "[${name}] [覆盖] 验证 Geoclue 变体 darkman 配置..."
  if ! echo ${escape geoclueConfigText} | grep -q "usegeoclue: true"; then
    echo "错误: [覆盖] Geoclue 变体 usegeoclue 应为 true"
    echo "实际内容: ${geoclueConfigText}"
    exit 1
  fi
  if ! echo ${escape geoclueConfigText} | grep -q "lat: 39.9042"; then
    echo "错误: [覆盖] Geoclue 变体 lat 应为 39.9042"
    exit 1
  fi
  if ! echo ${escape geoclueConfigText} | grep -q "lng: 116.4074"; then
    echo "错误: [覆盖] Geoclue 变体 lng 应为 116.4074"
    exit 1
  fi
  echo "[${name}] [覆盖] Geoclue 变体验证通过！"

  # 9.5 全自定义变体：hook 内联值与壁纸/extraHook/niri/布局深度校验
  echo "[${name}] [覆盖] 验证全自定义变体..."
  test -f "${customHookFile}" || { echo "错误: [覆盖] 自定义变体 hook 不存在"; exit 1; }
  test -x "${customHookFile}" || { echo "错误: [覆盖] 自定义变体 hook 无执行权限"; exit 1; }
  grep -q "Adwaita-dark-custom" "${customHookFile}" || { echo "错误: [覆盖] 自定义 hook 缺少 Adwaita-dark-custom"; exit 1; }
  grep -q "Adwaita-custom" "${customHookFile}" || { echo "错误: [覆盖] 自定义 hook 缺少 Adwaita-custom"; exit 1; }
  grep -q "Papirus-Dark" "${customHookFile}" || { echo "错误: [覆盖] 自定义 hook 缺少 Papirus-Dark"; exit 1; }
  grep -q "Papirus-Light" "${customHookFile}" || { echo "错误: [覆盖] 自定义 hook 缺少 Papirus-Light"; exit 1; }
  grep -q "Bibata-Modern-Classic" "${customHookFile}" || { echo "错误: [覆盖] 自定义 hook 缺少 Bibata-Modern-Classic"; exit 1; }
  grep -q "Bibata-Modern-Ice" "${customHookFile}" || { echo "错误: [覆盖] 自定义 hook 缺少 Bibata-Modern-Ice"; exit 1; }
  grep -q "#ff0000" "${customHookFile}" || { echo "错误: [覆盖] 自定义 hook 缺少 dark niri #ff0000"; exit 1; }
  grep -q "#112233" "${customHookFile}" || { echo "错误: [覆盖] 自定义 hook 缺少 light niri #112233"; exit 1; }
  grep -q "width 6" "${customHookFile}" || { echo "错误: [覆盖] 自定义 hook 缺少 width 6 (layout.focusRing.width)"; exit 1; }
  grep -q "custom-hook-executed" "${customHookFile}" || { echo "错误: [覆盖] 自定义 hook 未嵌入 extraSwitchHooks"; exit 1; }
  grep -q "awww-set" "${customHookFile}" || { echo "错误: [覆盖] 自定义 hook 在设置 wallpaper 时应包含 awww-set"; exit 1; }
  grep -q "/tmp/dark.jpg" "${customHookFile}" || { echo "错误: [覆盖] 自定义 hook 缺少 /tmp/dark.jpg 壁纸路径"; exit 1; }
  grep -q "/tmp/light.jpg" "${customHookFile}" || { echo "错误: [覆盖] 自定义 hook 缺少 /tmp/light.jpg"; exit 1; }
  # darkman 自定义经纬度
  if ! echo ${escape customDarkmanText} | grep -q "lat: 22.5"; then
    echo "错误: [覆盖] 自定义变体 lat 应为 22.5"
    exit 1
  fi
  if ! echo ${escape customDarkmanText} | grep -q "lng: 114.1"; then
    echo "错误: [覆盖] 自定义变体 lng 应为 114.1"
    exit 1
  fi
  echo "[${name}] [覆盖] 全自定义变体验证通过！"

  # 9.6 禁用变体：应无 darkman/ theme-sync 相关产物
  echo "[${name}] [覆盖] 验证禁用变体..."
  if [ "${if disabledHasDarkmanService then "true" else "false"}" = "true" ]; then
    echo "错误: [覆盖] 禁用变体不应存在 darkman service"
    exit 1
  fi
  if [ "${if disabledHasThemeSeedService then "true" else "false"}" = "true" ]; then
    echo "错误: [覆盖] 禁用变体不应存在 theme-seed service"
    exit 1
  fi
  if [ "${if disabledHasThemeSyncService then "true" else "false"}" = "true" ]; then
    echo "错误: [覆盖] 禁用变体不应存在 theme-sync service"
    exit 1
  fi
  if [ "${if disabledHasThemeSyncPath then "true" else "false"}" = "true" ]; then
    echo "错误: [覆盖] 禁用变体不应存在 theme-sync path"
    exit 1
  fi
  if [ "${if disabledHasDarkmanEtc then "true" else "false"}" = "true" ]; then
    echo "错误: [覆盖] 禁用变体不应存在 darkman etc"
    exit 1
  fi
  if [ "${if disabledHasHookEtc then "true" else "false"}" = "true" ]; then
    echo "错误: [覆盖] 禁用变体不应存在 theme-switch.sh"
    exit 1
  fi
  if [ "${if disabledHasDarkmanPkg then "true" else "false"}" = "true" ]; then
    echo "错误: [覆盖] 禁用变体 systemPackages 不应包含 darkman"
    exit 1
  fi
  echo "[${name}] [覆盖] 禁用变体验证通过！"

  # 9.7 图标禁用变体：systemPackages 不应包含 adwaita（hicolor 可能由其他模块提供，仅告警）
  echo "[${name}] [覆盖] 验证图标禁用变体..."
  if [ "${if iconsDisabledHasAdwaita then "true" else "false"}" = "true" ]; then
    echo "错误: [覆盖] icons.disable 变体 systemPackages 不应包含 adwaita-icon-theme"
    exit 1
  fi
  if [ "${if iconsDisabledHasHicolor then "true" else "false"}" = "true" ]; then
    echo "警告: [覆盖] icons.disable 变体 systemPackages 仍包含 hicolor-icon-theme（可能由其他模块提供，非主题模块直接引入）"
  fi
  echo "[${name}] [覆盖] 图标禁用变体验证通过！"

  # 9.8 HomeManager 禁用变体：sharedModules 数量应减少或为0
  echo "[${name}] [覆盖] 验证 HomeManager 禁用变体..."
  if [ "${toString hmDisabledSharedModulesLen}" != "0" ] && [ "${toString hmEnabledSharedModulesLen}" = "${toString hmDisabledSharedModulesLen}" ]; then
    echo "警告: [覆盖] HM 禁用变体 sharedModules 数量未减少（启用: ${toString hmEnabledSharedModulesLen}, 禁用: ${toString hmDisabledSharedModulesLen}），需检查模块是否正确响应 homeManager.enable"
    # 不强制失败，仅警告，因为宿主可能未启用 HM
    true
  fi
  # 若启用时有模块，禁用时应至少不增加
  if [ "${toString hmEnabledSharedModulesLen}" != "0" ]; then
    if [ "${toString hmDisabledSharedModulesLen}" -gt "${toString hmEnabledSharedModulesLen}" ]; then
      echo "错误: [覆盖] HM 禁用变体 sharedModules 数量不应大于启用变体"
      exit 1
    fi
    echo "[${name}] [覆盖] HomeManager 禁用变体验证通过！(启用:${toString hmEnabledSharedModulesLen} -> 禁用:${toString hmDisabledSharedModulesLen})"
  else
    echo "[${name}] [覆盖] HomeManager 未启用，跳过数量对比"
  fi

  echo "[${name}] 主题模块覆盖测试全部通过！"
  echo "静态检查通过！"
  touch $out
''
