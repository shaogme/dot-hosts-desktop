{ pkgs, lib ? pkgs.lib, mkSandboxedApp ? pkgs.callPackage ../lib/mk-sandboxed-app.nix { inherit lib; } }:

let
  sources = import ./npins;

  version =
    let
      match = builtins.match ".*/releases/([^/]+)/.*" sources.firefox.url;
    in
    if match != null then builtins.head match else "latest";
in
mkSandboxedApp {
  pname = "firefox";
  inherit version;
  src = sources.firefox;
  srcType = "tarball";
  execPath = "firefox";

  profiles = [ "desktop-gui" "media" ];
  sandboxDirs = [ "Downloads" ".mozilla" ];
  hostDirs = [ "Downloads" ".mozilla" ];
  iconStrategy = "firefox-sizes";

  environment = {
    MOZ_ENABLE_WAYLAND = "1";
  };

  desktop = {
    desktopName = "Firefox";
    genericName = "Web Browser";
    comment = "Mozilla Firefox Web Browser (Bubblewrap Isolated)";
    categories = [ "Network" "WebBrowser" ];
    mimeTypes = [
      "text/html"
      "text/xml"
      "application/xhtml+xml"
      "application/vnd.mozilla.xul+xml"
      "x-scheme-handler/http"
      "x-scheme-handler/https"
      "x-scheme-handler/ftp"
    ];
  };
}
