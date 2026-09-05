let
  rootDir = ../.;
  topEntries = builtins.readDir rootDir;
  
  # 白名单分类目录（与 .github/scripts/get-hosts.sh 保持一致）
  categories = [ "hosts" ];

  # 获取所有包含 configuration.nix 的主机项
  hostList = builtins.concatLists (map (category:
    let
      catPath = rootDir + "/${category}";
      catEntries = if builtins.pathExists catPath then builtins.readDir catPath else {};
    in
    builtins.concatLists (map (hostName:
      let
        hostDirPath = catPath + "/${hostName}";
        isDir = catEntries.${hostName} == "directory";
        hasConfig = isDir && builtins.pathExists (hostDirPath + "/configuration.nix");
      in
      if hasConfig then [{
        name = hostName;
        relPath = "${category}/${hostName}";
        dirPath = hostDirPath;
      }] else []
    ) (builtins.attrNames catEntries))
  ) categories);

  # 为单个主机生成静态和运行时测试
  makeHostTests = item:
    let
      sources = import (item.dirPath + "/npins");
      pkgs = import sources.nixpkgs {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };
      configuration = item.dirPath + "/configuration.nix";
    in
    {
      # 静态检查（含主题多变体覆盖）
      staticCheck = import ./static.nix { inherit pkgs configuration; name = item.name; };

      # 虚拟机集成测试
      vmTest = import ./vmtest.nix { inherit pkgs configuration; name = item.name; };
    };

  # 构建映射字典，同时支持主机简称 (如 "home-7950x") 和相对路径 (如 "hosts/home-7950x")
  allTests = builtins.listToAttrs (
    builtins.concatLists (map (item: [
      { name = item.name; value = makeHostTests item; }
      { name = item.relPath; value = makeHostTests item; }
    ]) hostList)
  );

  # ── 主题模块覆盖测试（Overlay / 覆盖分支） ───────────────────────────────
  # 为 modules/theme/default.nix 提供独立于具体主机的覆盖测试，确保所有
  # 配置分支（mode/solar/icons/cursor/layout/wallpaper/extraHooks/homeManager）
  # 均被静态检查覆盖。变体基于 virtual-box 的最小可用配置进行叠加。
  variantBasePath = rootDir + "/hosts/virtual-box";
  variantHasBase = builtins.pathExists (variantBasePath + "/configuration.nix") && builtins.pathExists (variantBasePath + "/npins");
  variantPkgs = if variantHasBase then
    let s = import (variantBasePath + "/npins"); in import s.nixpkgs { system = "x86_64-linux"; config.allowUnfree = true; }
  else if hostList != [] then
    let s = import ((builtins.head hostList).dirPath + "/npins"); in import s.nixpkgs { system = "x86_64-linux"; config.allowUnfree = true; }
  else
    import <nixpkgs> { system = "x86_64-linux"; config.allowUnfree = true; };
  variantBaseConfig = if variantHasBase then variantBasePath + "/configuration.nix" else if hostList != [] then (builtins.head hostList).dirPath + "/configuration.nix" else null;
  libVariant = variantPkgs.lib;

  # 主题覆盖变体定义：每个变体通过 extraModules 覆盖 desktop.theme 的关键选项
  themeVariantDefs = libVariant.optionals (variantBaseConfig != null) [
    {
      name = "theme-auto";
      description = "主题自动模式（覆盖验证 auto 分支无 ExecStartPost）";
      extraModules = [{ desktop.theme.mode = libVariant.mkForce "auto"; }];
    }
    {
      name = "theme-dark";
      description = "强制深色模式（覆盖验证 dark 分支 ExecStartPost）";
      extraModules = [{ desktop.theme.mode = libVariant.mkForce "dark"; }];
    }
    {
      name = "theme-light";
      description = "强制浅色模式（覆盖验证 light 分支 ExecStartPost）";
      extraModules = [{ desktop.theme.mode = libVariant.mkForce "light"; }];
    }
    {
      name = "theme-geoclue";
      description = "地理位置自动获取与自定义经纬度（覆盖 solar 分支）";
      extraModules = [{ desktop.theme.solar = libVariant.mkForce { latitude = 39.9042; longitude = 116.4074; useGeoclue = true; }; }];
    }
    {
      name = "theme-custom";
      description = "全自定义主题（覆盖 dark/light/cursor/niri/layout/wallpaper/extraHooks）";
      extraModules = [{
        desktop.theme = libVariant.mkForce {
          enable = true;
          mode = "dark";
          solar = { latitude = 22.5; longitude = 114.1; useGeoclue = false; };
          layout.focusRing.width = 6;
          icons = { enable = true; package = variantPkgs.adwaita-icon-theme; name = "Papirus"; };
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
      }];
    }
    {
      name = "theme-disabled";
      description = "禁用主题模块（覆盖 enable=false 分支）";
      extraModules = [
        { desktop.theme.enable = libVariant.mkForce false; }
        # 主机配置中对 desktop.theme.enable 的断言在禁用时会失败，需覆盖清除
        { assertions = libVariant.mkForce []; }
      ];
    }
    {
      name = "theme-icons-disabled";
      description = "禁用图标主题（覆盖 icons.enable=false 分支）";
      extraModules = [{ desktop.theme.icons.enable = libVariant.mkForce false; }];
    }
    {
      name = "theme-hm-disabled";
      description = "禁用 HomeManager 集成（覆盖 homeManager.enable=false 分支）";
      extraModules = [{ desktop.theme.homeManager.enable = libVariant.mkForce false; }];
    }
    {
      name = "theme-wallpaper-null";
      description = "无壁纸配置（覆盖 wallpaper=null 分支，应无 awww-set）";
      extraModules = [{
        desktop.theme.dark.wallpaper = libVariant.mkForce null;
        desktop.theme.light.wallpaper = libVariant.mkForce null;
        desktop.theme.extraSwitchHooks = libVariant.mkForce "";
      }];
    }
    {
      name = "theme-wallpaper-set";
      description = "设置壁纸路径（覆盖 wallpaper!=null 分支，应含 awww-set）";
      extraModules = [{
        desktop.theme.dark.wallpaper = libVariant.mkForce "/tmp/wall-dark.jpg";
        desktop.theme.light.wallpaper = libVariant.mkForce "/tmp/wall-light.jpg";
      }];
    }
    {
      name = "awww-wallpaperdir-set";
      description = "配置 awww.wallpaperDir 路径（覆盖 wallpaperDir!=null 分支）";
      extraModules = [{
        desktop.wallpaper.awww.wallpaperDir = libVariant.mkForce "/share/wallpapers";
      }];
    }
  ];

  makeThemeVariantTest = variant:
    let
      configuration = variantBaseConfig;
      pkgs = variantPkgs;
    in
    {
      staticCheck = import ./static.nix {
        inherit pkgs configuration;
        name = variant.name;
        extraModules = variant.extraModules;
      };
      # 变体 VM 测试：同样注入覆盖模块，验证运行时 darkman/theme-sync 等服务
      vmTest = import ./vmtest.nix {
        inherit pkgs configuration;
        name = variant.name;
        extraModules = variant.extraModules;
      };
    };

  themeCoverage = builtins.listToAttrs (map (v: { name = v.name; value = makeThemeVariantTest v; }) themeVariantDefs);

in
allTests // themeCoverage // { __themeVariants = themeVariantDefs; }
