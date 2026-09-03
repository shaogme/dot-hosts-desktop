{ pkgs, lib ? pkgs.lib, mkSandboxedApp ? import ../lib/mk-sandboxed-app { inherit pkgs lib; } }:

let
  sources = import ./npins;
  rawVersion = sources.clash-verge-rev.version;
  version = lib.removePrefix "v" rawVersion;
  debUrl = "https://github.com/clash-verge-rev/clash-verge-rev/releases/download/v${version}/Clash.Verge_${version}_amd64.deb";
in
mkSandboxedApp.webkitApp {
  pname = "clash-verge";
  inherit version;
  src = { deb = builtins.fetchurl debUrl; };
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
