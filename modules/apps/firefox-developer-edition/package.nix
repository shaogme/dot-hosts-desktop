{ pkgs, lib ? pkgs.lib, mkSandboxedApp ? pkgs.callPackage ../lib/mk-sandboxed-app.nix { inherit lib; } }:

let
  sources = import ./npins;

  version =
    let
      match = builtins.match ".*/releases/([^/]+)/.*" sources.firefox-developer-edition.url;
    in
    if match != null then builtins.head match else "latest";
in
mkSandboxedApp {
  pname = "firefox-developer-edition";
  inherit version;
  src = sources.firefox-developer-edition;
  srcType = "tarball";
  execPath = "firefox";

  aliases = [ "firefox-devedition" ];
  profiles = [ "desktop-gui" "media" ];
  sandboxDirs = [ "Downloads" ".mozilla" ];
  hostDirs = [ "Downloads" ".mozilla" ];
  iconStrategy = "firefox-sizes";

  environment = {
    MOZ_ENABLE_WAYLAND = "1";
  };

  desktop = {
    desktopName = "Firefox Developer Edition";
    genericName = "Web Browser";
    comment = "Mozilla Firefox Developer Edition (Bubblewrap Isolated)";
    categories = [ "Network" "WebBrowser" "Development" ];
    mimeTypes = [
      "text/html"
      "text/xml"
      "application/xhtml+xml"
      "application/vnd.mozilla.xul+xml"
      "x-scheme-handler/http"
      "x-scheme-handler/https"
    ];
  };
}
