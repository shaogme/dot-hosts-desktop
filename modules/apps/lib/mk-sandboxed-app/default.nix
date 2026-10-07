{ pkgs, lib ? pkgs.lib }:

let
  typesLib = import ./types.nix { inherit lib; };
  unpackedLib = import ./mk-unpacked.nix { inherit pkgs lib; };
  fhsBasesLib = import ./fhs-bases.nix { inherit lib; };
  sandboxLib = import ./sandbox.nix { inherit lib; };
  fhsEnvLib = import ./mk-fhs-env.nix { inherit pkgs lib; };
  launcherLib = import ./mk-launcher-env.nix { inherit pkgs lib; };
  wineLauncherLib = import ./mk-wine-launcher.nix { inherit pkgs lib; };
  wrapperLib = import ./mk-wrapper.nix { inherit pkgs lib; };
  desktopLib = import ./mk-desktop.nix { inherit pkgs lib; };
  fetchWithRetry = import ../fetch-with-retry.nix { inherit pkgs lib; };

  # 核心装配
  mkCore =
    { pname
    , version
    , src
    , execPath ? null
    , winExecPath ? null
    , wine ? null
    , officeFontsPackage ? null
    , binaryName ? pname
    , fhsBase
    , sandbox ? { }
    , env ? { }
    , preRunHooks ? [ ]
    , runInDirectory ? null
    , fhsExtraCommands ? [ ]
    , postUnpackHooks ? [ ]
    , postBuildHooks ? [ ]
    , icons ? null
    , desktop ? { }
    , aliases ? [ ]
    , windowRules ? [ ]
    , privateTmp ? true
    , extraPreBwrapCmds ? ""
    , chdirToPwd ? false
    , multiArch ? false
    , multiPkgs ? null
    }:
    let
      isWine = winExecPath != null || wine != null;
      _checkExec =
        if !isWine && execPath == null then
          throw "mkSandboxedApp: 必须提供 execPath (若为 wineApp 可省略 winExecPath 以进入通用 Wine 容器模式)"
        else true;

      srcADT = typesLib.normalizeSrc { inherit src; };
      unpacked = unpackedLib.mkUnpacked {
        inherit pname version srcADT postUnpackHooks;
      };

      rawSandboxCfg = typesLib.normalizeSandbox { inherit sandbox pname; };
      sandboxCfg = rawSandboxCfg // {
        homeDirs =
          if isWine then
            lib.unique (rawSandboxCfg.homeDirs ++ [ "wineprefix" ])
          else
            rawSandboxCfg.homeDirs;
      };
      sandboxName = sandboxCfg.name;
      bwrapArgs = sandboxLib.makeBwrapArgs ({
        inherit sandboxName;
      } // (builtins.removeAttrs sandboxCfg [ "name" "homeDirs" ]));

      staticEnv = typesLib.normalizeEnv { inherit env; };

      launcher =
        if isWine then
          let
            wineCfg = typesLib.normalizeWine (if wine != null then wine else { });
            wineLauncherArgs = {
              inherit pname unpacked winExecPath wineCfg sandboxName;
              env = staticEnv;
              inherit preRunHooks runInDirectory;
            } // (lib.optionalAttrs (officeFontsPackage != null) { inherit officeFontsPackage; });
          in
          wineLauncherLib.mkWineLauncherEnv wineLauncherArgs
        else
          launcherLib.mkLauncherEnv {
            inherit pname unpacked execPath;
            env = staticEnv;
            inherit preRunHooks runInDirectory;
          };

      extraBuildCommands = typesLib.resolveExtraBuildCommands { inherit fhsExtraCommands; };

      fhs = fhsEnvLib.mkFhsEnv {
        inherit pname fhsBase extraBwrapArgs extraPreBwrapCmds chdirToPwd;
        inherit extraBuildCommands;
        profile = launcher.profile;
        runScript = launcher.runScript;
        unshareUser = false;
        privateTmp = if isWine then true else privateTmp;
        inherit multiArch multiPkgs;
      };
      extraBwrapArgs = bwrapArgs;

      wrapper = wrapperLib.mkWrapper {
        inherit pname binaryName fhs sandboxName;
        bypassProxy = sandboxCfg.bypassProxy;
      };

      iconsADT = typesLib.normalizeIcons { inherit icons; };
      desktopItem = desktopLib.mkDesktopItem { inherit pname binaryName desktop; };
      iconsDrv = desktopLib.mkIcons { inherit pname unpacked iconsADT aliases; };
      aliasesDrv = desktopLib.mkAliases { inherit pname binaryName aliases wrapper; };

      appMeta = {
        inherit pname binaryName sandboxName;
        bypassProxy = sandboxCfg.bypassProxy;
        homeDirs = lib.unique (sandboxCfg.homeDirs or [ ]);
      };
    in
    assert _checkExec;
    desktopLib.mkFinalPackage {
      inherit pname version wrapper desktopItem iconsDrv aliasesDrv postBuildHooks unpacked fhs appMeta;
      windowRules = lib.unique windowRules;
    };

  withDefaults = defaults: args:
    mkCore (defaults // args // {
      sandbox = (defaults.sandbox or { }) // (args.sandbox or { });
      env = (defaults.env or { }) // (args.env or { });
      fhsExtraCommands = (defaults.fhsExtraCommands or [ ]) ++ (args.fhsExtraCommands or [ ]);
      extraPreBwrapCmds = (defaults.extraPreBwrapCmds or "") + (args.extraPreBwrapCmds or "");
      chdirToPwd = args.chdirToPwd or (defaults.chdirToPwd or false);
      preRunHooks = (defaults.preRunHooks or [ ]) ++ (args.preRunHooks or [ ]);
      postUnpackHooks = (defaults.postUnpackHooks or [ ]) ++ (args.postUnpackHooks or [ ]);
      postBuildHooks = (defaults.postBuildHooks or [ ]) ++ (args.postBuildHooks or [ ]);
      aliases = (defaults.aliases or [ ]) ++ (args.aliases or [ ]);
      windowRules = (defaults.windowRules or [ ]) ++ (args.windowRules or [ ]);
    });

  base = args: mkCore args;

  desktopApp = args: withDefaults { fhsBase = fhsBasesLib.fhsBases.desktop-gui; } args;

  electronApp = args: withDefaults { fhsBase = fhsBasesLib.fhsBases.desktop-gui-electron-media; } args;

  firefoxApp = args: withDefaults {
    fhsBase = fhsBasesLib.fhsBases.desktop-gui-media;
    icons = { firefox = { }; };
    env = {
      MOZ_LEGACY_PROFILES = "1";
      MOZ_ALLOW_DOWNGRADE = "1";
    };
  } args;

  qtApp = args: withDefaults {
    fhsBase = fhsBasesLib.fhsBases.desktop-gui-electron-media-xcb-qt;
  } args;

  webkitApp = args: withDefaults {
    fhsBase = fhsBasesLib.fhsBases.desktop-gui-webkitgtk;
  } args;

  dotnetApp = args: withDefaults {
    fhsBase = fhsBasesLib.fhsBases.desktop-gui-dotnet;
  } args;

  wineApp = args:
    let
      wineNormalized = typesLib.normalizeWine (args.wine or { });
      customFhs =
        if wineNormalized.dxvk then
          fhsBasesLib.extend fhsBasesLib.fhsBases.desktop-gui-wine (p: [ p.dxvk.bin (p.dxvk.out or p.dxvk) ])
        else
          fhsBasesLib.fhsBases.desktop-gui-wine;
      wineExtraCommands = [
        "mkdir -p $out/usr/bin"
        "ln -sf wine $out/usr/bin/wine64"
      ];
    in
    withDefaults {
      fhsBase = customFhs;
      wine = wineNormalized;
      privateTmp = true;
      fhsExtraCommands = wineExtraCommands;
    } args;

in
{
  inherit fetchWithRetry;
  fetchDeb = fetchWithRetry;
  inherit base desktopApp electronApp firefoxApp qtApp webkitApp dotnetApp wineApp;
  inherit (fhsBasesLib) fhsBases combine extend mkMultiFhsBase;
}
