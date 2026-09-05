{ pkgs, lib ? pkgs.lib }:

let
  typesLib = import ./types.nix { inherit lib; };
  unpackedLib = import ./mk-unpacked.nix { inherit pkgs lib; };
  fhsBasesLib = import ./fhs-bases.nix { inherit lib; };
  sandboxLib = import ./sandbox.nix { inherit lib; };
  fhsEnvLib = import ./mk-fhs-env.nix { inherit pkgs lib; };
  launcherLib = import ./mk-launcher-env.nix { inherit pkgs lib; };
  wrapperLib = import ./mk-wrapper.nix { inherit pkgs lib; };
  desktopLib = import ./mk-desktop.nix { inherit pkgs lib; };

  # 核心装配 (纯静态管线, 无运行时分支).
  mkCore =
    { pname
    , version
    , src
    , execPath
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
    }:
    let
      srcADT = typesLib.normalizeSrc { inherit src; };
      unpacked = unpackedLib.mkUnpacked {
        inherit pname version srcADT postUnpackHooks;
      };

      sandboxCfg = typesLib.normalizeSandbox { inherit sandbox pname; };
      sandboxName = sandboxCfg.name;
      bwrapArgs = sandboxLib.makeBwrapArgs ({
        inherit sandboxName;
      } // (builtins.removeAttrs sandboxCfg [ "name" "homeDirs" ]));

      staticEnv = typesLib.normalizeEnv { inherit env; };

      launcher = launcherLib.mkLauncherEnv {
        inherit pname unpacked execPath;
        env = staticEnv;
        inherit preRunHooks runInDirectory;
      };

      extraBuildCommands = typesLib.resolveExtraBuildCommands { inherit fhsExtraCommands; };

      fhs = fhsEnvLib.mkFhsEnv {
        inherit pname fhsBase extraBwrapArgs;
        inherit extraBuildCommands;
        profile = launcher.profile;
        runScript = launcher.runScript;
        unshareUser = false;
        inherit privateTmp;
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
    desktopLib.mkFinalPackage {
      inherit pname version wrapper desktopItem iconsDrv aliasesDrv postBuildHooks unpacked fhs appMeta;
      windowRules = lib.unique windowRules;
    };

  withDefaults = defaults: args:
    mkCore (defaults // args // {
      sandbox = (defaults.sandbox or { }) // (args.sandbox or { });
      env = (defaults.env or { }) // (args.env or { });
    });

  base = args: mkCore args;

  desktopApp = args: withDefaults { fhsBase = fhsBasesLib.fhsBases.desktop-gui; } args;

  electronApp = args: withDefaults { fhsBase = fhsBasesLib.fhsBases.desktop-gui-electron-media; } args;

  firefoxApp = args: withDefaults {
    fhsBase = fhsBasesLib.fhsBases.desktop-gui-media;
    icons = { firefox = { }; };
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

in
{
  inherit base desktopApp electronApp firefoxApp qtApp webkitApp dotnetApp;
  inherit (fhsBasesLib) fhsBases combine extend;
}
