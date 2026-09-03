{ pkgs, lib }:

let
  fhsBasesLib = import ./fhs-bases.nix { inherit lib; };
in
{
  # 专用 FHS 构造器 (无通用 extraBuildCommands 字符串, 仅静态列表拼接结果).
  mkFhsEnv =
    { pname
    , fhsBase
    , extraBwrapArgs
    , extraBuildCommands ? ""
    , profile ? ""
    , runScript
    , unshareUser ? false
    , privateTmp ? true
    }:
    pkgs.buildFHSEnv {
      name = "${pname}-fhs";
      targetPkgs = fhsBasesLib.resolveTargetPkgs fhsBase;
      inherit extraBwrapArgs extraBuildCommands profile runScript unshareUser privateTmp;
    };
}
