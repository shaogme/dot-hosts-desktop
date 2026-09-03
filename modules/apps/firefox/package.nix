{ pkgs, lib ? pkgs.lib, mkSandboxedApp ? import ../lib/mk-sandboxed-app { inherit pkgs lib; } }:

let
  sources = import ./npins;

  version =
    let
      match = builtins.match ".*/releases/([^/]+)/.*" sources.firefox.url;
    in
    if match != null then builtins.head match else "latest";
in
mkSandboxedApp.firefoxApp {
  pname = "firefox";
  inherit version;
  src = { tarball = sources.firefox; };
  execPath = "firefox";

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
