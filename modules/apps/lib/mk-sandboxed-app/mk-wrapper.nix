{ pkgs, lib }:

{
  # 扁平 wrapper: 支持通过 sg proxy-bypass 切换 GID 以豁免透明代理回环。
  # SANDBOX_HOME 根目录预建由 mk-app-module 的 systemd.user.tmpfiles 接管,
  # 此处单条 mkdir 仅作首次激活回退 (子目录由 tmpfiles 保证).
  mkWrapper = { pname, binaryName, fhs, sandboxName, bypassProxy ? false }:
    let
      bypassLogic = lib.optionalString bypassProxy ''
        # 当启用 bypassProxy 且当前有效 GID 尚不是 proxy-bypass (1992) 时，
        # 通过 sg proxy-bypass 切换真实与有效 GID 到 1992。
        # 确保创建的所有网络套接字在宿主网络栈带有 sk_gid=1992，命中 nftables 0x55 豁免标记走 table main。
        if [ "$(id -g)" -ne 1992 ]; then
          if getent group proxy-bypass >/dev/null 2>&1 && id -nG | grep -qw "proxy-bypass"; then
            TARGET_BIN="$(command -v "$0" 2>/dev/null || echo "$0")"
            CMD_LINE=$(printf "%q " "$TARGET_BIN" "$@")
            exec sg proxy-bypass -c "exec $CMD_LINE"
          else
            echo "警告: 当前用户未加入 proxy-bypass 组，无法自动获取 TUN 路由豁免标记 (0x55)！" >&2
          fi
        fi
      '';
    in
    pkgs.writeShellScriptBin binaryName ''
      ${bypassLogic}
      SANDBOX_HOME="''${XDG_DATA_HOME:-$HOME}/.sandboxes/${sandboxName}"
      mkdir -p "$SANDBOX_HOME"
      exec ${fhs}/bin/${pname}-fhs "$@"
    '';
}
