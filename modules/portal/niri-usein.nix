{ config, pkgs, lib, ... }:

with lib;

let
  patchUseIn = oldUseIn: newDesktops:
    let
      existing = filter (s: s != "") (splitString ";" oldUseIn);
      merged = unique (existing ++ newDesktops);
    in
    concatStringsSep ";" (merged ++ [ "" ]);

  patchPortalFile = portalPath: desktops: ''
    if [ -f "${portalPath}" ]; then
      if grep -q "^UseIn=" "${portalPath}"; then
        sed -i 's/^UseIn=.*/UseIn=${concatStringsSep ";" (desktops ++ [ "" ])}/' "${portalPath}" || echo "[niri-usein] warn: failed to patch ${portalPath}" >&2
      else
        echo "UseIn=${concatStringsSep ";" (desktops ++ [ "" ])}" >> "${portalPath}" || echo "[niri-usein] warn: failed to append ${portalPath}" >&2
      fi
    fi
  '';
in
{
  # 全局生效：强制所有相关 .portal 文件的 UseIn 包含 niri。
  # 背景：darkman.portal UseIn=sway 与 gtk/gnome.portal UseIn=gnome 均与 XDG_CURRENT_DESKTOP=niri 错位。
  # XDP 在显式 [preferred] 下未严格拦截 UseIn，放任即下一个断点。
  nixpkgs.overlays = [
    (final: prev: {
      darkman = prev.darkman.overrideAttrs (old: {
        postInstall = (old.postInstall or "") + ''
          for f in "$out"/share/xdg-desktop-portal/portals/*.portal; do
            [ -f "$f" ] || continue
            if grep -q "^UseIn=" "$f"; then
              if ! grep -q "niri" "$f"; then
                sed -i 's/^UseIn=\(.*\)/UseIn=niri;\1/' "$f"
              fi
            else
              echo "UseIn=niri;" >> "$f"
            fi
          done
        '';
      });
      xdg-desktop-portal-gtk = prev.xdg-desktop-portal-gtk.overrideAttrs (old: {
        postInstall = (old.postInstall or "") + ''
          for f in "$out"/share/xdg-desktop-portal/portals/*.portal; do
            [ -f "$f" ] || continue
            if grep -q "^UseIn=" "$f"; then
              if ! grep -q "niri" "$f"; then
                sed -i 's/^UseIn=\(.*\)/UseIn=niri;\1/' "$f"
              fi
            else
              echo "UseIn=niri;" >> "$f"
            fi
          done
        '';
      });
      xdg-desktop-portal-gnome = prev.xdg-desktop-portal-gnome.overrideAttrs (old: {
        postInstall = (old.postInstall or "") + ''
          for f in "$out"/share/xdg-desktop-portal/portals/*.portal; do
            [ -f "$f" ] || continue
            if grep -q "^UseIn=" "$f"; then
              if ! grep -q "niri" "$f"; then
                sed -i 's/^UseIn=\(.*\)/UseIn=niri;\1/' "$f"
              fi
            else
              echo "UseIn=niri;" >> "$f"
            fi
          done
        '';
      });
      xdg-desktop-portal-termfilechooser = prev.xdg-desktop-portal-termfilechooser.overrideAttrs (old: {
        postInstall = (old.postInstall or "") + ''
          for f in "$out"/share/xdg-desktop-portal/portals/*.portal; do
            [ -f "$f" ] || continue
            if grep -q "^UseIn=" "$f"; then
              if ! grep -q "niri" "$f"; then
                sed -i 's/^UseIn=\(.*\)/UseIn=niri;\1/' "$f"
              fi
            else
              echo "UseIn=niri;" >> "$f"
            fi
          done
        '';
      });
    })
  ];
}
