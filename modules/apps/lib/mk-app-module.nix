{
  name,
  description,
  package,                     # 软件包路径 ./package.nix 或 Derivation 或函数
  aliases ? [],                # 模块别名列表 (如 [ "firefox-devedition" ])
  windowRules ? [],            # 注册到 Hyprland 的专用窗口规则 (window_rule)
  hyprlandRules ? [],          # 别名: 等同于 windowRules
  extraOptions ? {},           # 附加的 NixOS options
  extraConfig ? (cfg: {}),     # 附加的 NixOS config 逻辑
}:

{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.desktop.apps.${name};

  # 检查是否有任何别名被启用
  aliasConfigs = map (alias: config.desktop.apps.${alias}) aliases;
  isAnyAliasEnabled = any (a: a.enable) aliasConfigs;

  resolvedPkg =
    if isPath package then
      import package { inherit pkgs lib; }
    else if isFunction package then
      package { inherit pkgs lib; }
    else
      package;

  # 获取有效生效的 package 实例
  effectivePackage =
    let
      customAliasPkg = findFirst (a: a.enable && a.package != cfg.package) null aliasConfigs;
    in
    if customAliasPkg != null then customAliasPkg.package else cfg.package;

  # 汇总该应用的所有关联窗口规则 (包括直接传入规则及 package passthru 规则)
  effectiveWindowRules = unique (
    windowRules
    ++ hyprlandRules
    ++ (effectivePackage.passthru.windowRules or [ ])
    ++ (effectivePackage.windowRules or [ ])
  );

  # 构造主选项定义
  mainOptions = {
    ${name} = {
      enable = mkEnableOption "${description}（基于 Bubblewrap 沙箱与 FHS 隔离运行）";

      package = mkOption {
        type = types.package;
        default = resolvedPkg;
        defaultText = literalExpression "import ./package.nix { inherit pkgs lib; }";
        description = "使用的 ${description} 软件包实例。";
      };

      windowRules = mkOption {
        type = types.listOf (types.attrsOf types.anything);
        default = effectiveWindowRules;
        description = "该应用程序在 Hyprland 下生效的专用窗口规则 (window_rule)。";
      };
    } // extraOptions;
  };

  # 构造别名选项定义
  aliasOptions = genAttrs aliases (alias: {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "别名选项：等同于 desktop.apps.${name}.enable";
    };
    package = mkOption {
      type = types.package;
      default = cfg.package;
      defaultText = literalExpression "config.desktop.apps.${name}.package";
      description = "别名选项：等同于 desktop.apps.${name}.package";
    };
  });

in
{
  options.desktop.apps = mainOptions // aliasOptions;

  config = mkIf (cfg.enable || isAnyAliasEnabled) (mkMerge [
    {
      environment.systemPackages = [
        effectivePackage
      ];
    }
    (mkIf (cfg.windowRules != [ ] && config ? desktop && config.desktop ? windowManager && config.desktop.windowManager ? hyprland) {
      desktop.windowManager.hyprland.settings.window_rule = cfg.windowRules;
    })
    (extraConfig cfg)
  ]);
}
