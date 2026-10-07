{ pkgs, lib ? pkgs.lib, mkSandboxedApp ? import ../lib/mk-sandboxed-app { inherit pkgs lib; } }:

let
  sources = import ./npins;
  version =
    let
      match = builtins.match ".*/v?([0-9.]+)/Clash\\.Verge.*" sources.clash-verge.url;
    in
    if match != null then builtins.head match else "2.5.7";
in
mkSandboxedApp.webkitApp {
  pname = "clash-verge";
  inherit version;
  src = { deb = mkSandboxedApp.fetchWithRetry sources.clash-verge; };
  execPath = "bin/clash-verge";

  sandbox = {
    bypassProxy = true;
    homeDirs = [ ".config/clash-verge" ".config/clash-verge-rev" ];
  };

  icons = { hicolor.auto = true; };

  desktop = {
    desktopName = "Clash Verge Rev";
    genericName = "Proxy GUI Client";
    comment = "Clash Verge Rev - Proxy Client";
    icon = "clash-verge";
    categories = [ "Network" ];
  };
}
