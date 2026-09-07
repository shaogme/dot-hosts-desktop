{ pkgs, lib ? pkgs.lib, mkSandboxedApp ? import ../lib/mk-sandboxed-app { inherit pkgs lib; } }:

let
  sources = import ./npins;

  version =
    let
      match = builtins.match ".*/microsoft-edge-dev_([0-9.]+)-.*" sources.microsoft-edge-dev.url;
    in
    if match != null then builtins.head match
    else throw "microsoft-edge-dev: Could not parse version from URL: ${sources.microsoft-edge-dev.url}";
in
mkSandboxedApp.electronApp {
  pname = "microsoft-edge-dev";
  inherit version;
  src = { deb = sources.microsoft-edge-dev; };
  execPath = "opt/microsoft/msedge-dev/microsoft-edge-dev";

  fhsBase = mkSandboxedApp.extend mkSandboxedApp.fhsBases.desktop-gui-electron-media (pkgs: [
    pkgs.xdg-utils
    pkgs.libuuid
  ]);

  # 沙箱与文件访问隔离规则: 共享宿主下载目录 (读写) 与常用用户目录 (只读)
  sandbox = {
    shareDownloads = true;
    shareUserDirs = true;
    homeDirs = [
      "Downloads"
      ".config/microsoft-edge-dev"
      ".cache/microsoft-edge-dev"
      ".pki"
    ];
  };

  preRunHooks = [
    ''
      EXTRA_FLAGS=(
        "--simulate-outdated-no-au=Tue, 31 Dec 2099 23:59:59 GMT"
      )
      if [ -n "$WAYLAND_DISPLAY" ]; then
        EXTRA_FLAGS+=(
          "--ozone-platform-hint=auto"
          "--enable-features=WaylandWindowDecorations"
          "--enable-wayland-ime=true"
          "--wayland-text-input-version=3"
        )
      fi
      set -- "''${EXTRA_FLAGS[@]}" "$@"
    ''
  ];

  postUnpackHooks = [
    ''
      for icon_file in $out/opt/microsoft/msedge-dev/product_logo_[0-9]*_dev.png; do
        num_and_suffix="''${icon_file##*logo_}"
        icon_size="''${num_and_suffix%_*}"
        logo_output_path="$out/share/icons/hicolor/''${icon_size}x''${icon_size}/apps"
        mkdir -p "$logo_output_path"
        cp "$icon_file" "$logo_output_path/microsoft-edge-dev.png"
      done
      if [ -f "$out/opt/microsoft/msedge-dev/product_logo_128_dev.png" ]; then
        mkdir -p "$out/share/pixmaps"
        cp "$out/opt/microsoft/msedge-dev/product_logo_128_dev.png" "$out/share/pixmaps/microsoft-edge-dev.png"
      fi
    ''
  ];

  icons = { hicolor.auto = true; };

  aliases = [ "edge-dev" ];

  desktop = {
    desktopName = "Microsoft Edge (Dev)";
    genericName = "Web Browser";
    comment = "Microsoft Edge Dev Web Browser (Bubblewrap Isolated)";
    categories = [ "Network" "WebBrowser" "Development" ];
    icon = "microsoft-edge-dev";
    startupWMClass = "microsoft-edge-dev";
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
