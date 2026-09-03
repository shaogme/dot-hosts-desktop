{ pkgs, lib ? pkgs.lib, mkSandboxedApp ? import ../lib/mk-sandboxed-app { inherit pkgs lib; } }:

let
  sources = import ./npins;

  version =
    let
      match = builtins.match ".*/releases/([^/]+)/.*" sources.firefox-developer-edition.url;
    in
    if match != null then builtins.head match else "latest";
in
mkSandboxedApp.firefoxApp {
  pname = "firefox-developer-edition";
  inherit version;
  src = { tarball = sources.firefox-developer-edition; };
  execPath = "firefox";

  aliases = [ "firefox-devedition" ];

  # 沙箱与文件访问隔离规则: 共享宿主下载目录 (读写) 与常用用户目录 (只读)
  sandbox = {
    shareDownloads = true;
    shareUserDirs = true;
    homeDirs = [ "Downloads" ".mozilla" ];
  };

  env = {
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
