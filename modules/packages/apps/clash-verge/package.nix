{ pkgs, lib ? pkgs.lib, mkSandboxedApp ? pkgs.callPackage ../lib/mk-sandboxed-app.nix { inherit lib; } }:

let
  sources = import ./npins;
  rawVersion = sources.clash-verge-rev.version;
  version = lib.removePrefix "v" rawVersion;
  debUrl = "https://github.com/clash-verge-rev/clash-verge-rev/releases/download/v${version}/Clash.Verge_${version}_amd64.deb";
in
mkSandboxedApp {
  pname = "clash-verge";
  inherit version;
  src = builtins.fetchurl debUrl;
  srcType = "deb";
  execPath = "bin/clash-verge";

  profiles = [ "desktop-gui" "webkitgtk" ];
  hostDirs = [ ".config/clash-verge" ".config/clash-verge-rev" ];

  desktop = {
    desktopName = "Clash Verge Rev";
    genericName = "Proxy GUI Client";
    comment = "Clash Verge Rev - Proxy Client";
    icon = "clash-verge";
    categories = [ "Network" ];
  };
}
