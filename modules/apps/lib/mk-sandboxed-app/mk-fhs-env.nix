{ pkgs, lib }:

let
  fhsBasesLib = import ./fhs-bases.nix { inherit lib; };
in
{
  # 专用 FHS 构造器
  mkFhsEnv =
    { pname
    , fhsBase
    , extraBwrapArgs
    , extraBuildCommands ? ""
    , profile ? ""
    , runScript
    , unshareUser ? false
    , privateTmp ? true
    , multiArch ? false
    , multiPkgs ? null
    }:
    let
      resolvedMulti = fhsBasesLib.resolveMultiPkgs fhsBase;
      effectiveMultiPkgs =
        if multiPkgs != null then
          (if lib.isFunction multiPkgs then (p: fhsBasesLib.dedupePkgs (multiPkgs p)) else multiPkgs)
        else
          resolvedMulti;
      effectiveMultiArch = multiArch || (effectiveMultiPkgs != null);
    in
    pkgs.buildFHSEnv ({
      name = "${pname}-fhs";
      targetPkgs = fhsBasesLib.resolveTargetPkgs fhsBase;
      inherit extraBwrapArgs extraBuildCommands profile runScript unshareUser privateTmp;
    } // lib.optionalAttrs effectiveMultiArch {
      multiArch = true;
      multiPkgs = effectiveMultiPkgs;
    });
}
