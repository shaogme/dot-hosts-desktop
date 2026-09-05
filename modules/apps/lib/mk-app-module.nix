{
  name,
  description,
  package,
  aliases ? [ ],
  windowRules ? [ ],
  extraOptions ? { },
  extraConfig ? (cfg: { }),
}:

{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.desktop.apps.${name};

  aliasConfigs = map (alias: config.desktop.apps.${alias}) aliases;
  isAnyAliasEnabled = any (a: a.enable) aliasConfigs;

  resolvedPkg =
    if isPath package then
      import package { inherit pkgs lib; }
    else if isFunction package then
      package { inherit pkgs lib; }
    else
      package;

  effectivePackage =
    let
      customAliasPkg = findFirst (a: a.enable && a.package != cfg.package) null aliasConfigs;
    in
    if customAliasPkg != null then customAliasPkg.package else cfg.package;

  effectiveWindowRules = unique (
    windowRules
    ++ (effectivePackage.passthru.windowRules or [ ])
    ++ (effectivePackage.windowRules or [ ])
  );

  appMeta = effectivePackage.passthru.appMeta or null;
  sandboxName = if appMeta != null then appMeta.sandboxName else name;
  homeDirs = if appMeta != null then appMeta.homeDirs or [ ] else [ ];
  bypassProxy = if appMeta != null then appMeta.bypassProxy or false else false;
  fhsDrv = effectivePackage.passthru.fhs or null;
  pnameOf = if appMeta != null then appMeta.pname else name;

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

      systemd.user.tmpfiles.rules =
        [ "d %h/.sandboxes/${sandboxName} 0755 - - -" ]
        ++ (map (dir: "d %h/.sandboxes/${sandboxName}/${dir} 0755 - - -") homeDirs);

      users.groups.proxy-bypass = mkIf bypassProxy {
        gid = 1992;
      };
    }
    (mkIf (cfg.windowRules != [ ] && config ? desktop && config.desktop ? windowManager && config.desktop.windowManager ? niri) {
      desktop.windowManager.niri.extraRules = cfg.windowRules;
    })
    (extraConfig cfg)
  ]);
}
