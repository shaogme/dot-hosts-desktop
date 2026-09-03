{ pkgs, lib }:

{
  # 扁平 wrapper: exec + 单条 mkdir 回退, 零 cp/sg/id/grep/for.
  # SANDBOX_HOME 根目录预建由 mk-app-module 的 systemd.user.tmpfiles 接管,
  # 此处单条 mkdir 仅作首次激活回退 (子目录由 tmpfiles 保证).
  # 主题 cp 已删除 (bwrap 只读挂载); 特权切换由 security.wrappers 接管.
  mkWrapper = { pname, binaryName, fhs, sandboxName }:
    pkgs.writeShellScriptBin binaryName ''
      SANDBOX_HOME="''${XDG_DATA_HOME:-$HOME}/.sandboxes/${sandboxName}"
      mkdir -p "$SANDBOX_HOME"
      exec ${fhs}/bin/${pname}-fhs "$@"
    '';
}
