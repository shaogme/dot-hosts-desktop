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
    , extraPreBwrapCmds ? ""
    , extraBuildCommands ? ""
    , profile ? ""
    , runScript
    , unshareUser ? false
    , privateTmp ? true
    , chdirToPwd ? false
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

      defaultPreBwrapCmds = ''
        # 拦截 buildFHSEnv 自动遍历根目录 /* 并无条件 bind 的非沙箱默认行为。
        # 仅放行基础系统虚拟文件系统，其余非系统目录（如 /home, /data, /mnt, /media, /root 等）
        # 均加入 ignored 列表，交由沙箱隔离层 (sandbox.nix) 显式控制挂载与权限。
        for d in /*; do
          case "$d" in
            /nix|/dev|/proc|/etc|/tmp|/sys) ;;
            *) ignored+=("$d") ;;
          esac
        done
      '';

      effectivePreBwrapCmds = defaultPreBwrapCmds + "\n" + extraPreBwrapCmds;
    in
    pkgs.buildFHSEnv ({
      name = "${pname}-fhs";
      targetPkgs = fhsBasesLib.resolveTargetPkgs fhsBase;
      extraPreBwrapCmds = effectivePreBwrapCmds;
      inherit extraBwrapArgs extraBuildCommands profile runScript unshareUser privateTmp chdirToPwd;
    } // lib.optionalAttrs effectiveMultiArch {
      multiArch = true;
      multiPkgs = effectiveMultiPkgs;
    });
}
