{ pkgs, lib ? pkgs.lib, mkSandboxedApp ? import ../lib/mk-sandboxed-app { inherit pkgs lib; } }:

let
  sources = import ./npins;

  version =
    let
      match = builtins.match ".*/(linuxqq|QQ)_([0-9.-]+)_.*" sources.qq.url;
    in
    if match != null then builtins.elemAt match 1
    else throw "qq: Could not parse version from URL: ${sources.qq.url}";
in
mkSandboxedApp.electronApp {
  pname = "qq";
  inherit version;
  src = { deb = sources.qq; };
  execPath = "opt/QQ/qq";
  runInDirectory = "opt/QQ";

  fhsBase = mkSandboxedApp.extend mkSandboxedApp.fhsBases.desktop-gui-electron-media (pkgs: with pkgs; [
    libuuid
    libgcrypt
    libxft
    gnutls
    nettle
    gmp
  ]);

  sandbox = { homeDirs = [ ".config/QQ" ]; };

  preRunHooks = [
    ''mkdir -p "$HOME/.config/QQ"''
    ''rm -rf "$HOME/.config/QQ/crash_files"/* 2>/dev/null || true''
  ];

  aliases = [ "linuxqq" ];

  desktop = {
    desktopName = "QQ";
    genericName = "Instant Messaging";
    comment = "Tencent QQ Client (Bubblewrap Isolated)";
    categories = [ "Network" "InstantMessaging" "Chat" ];
    icon = "qq";
    startupWMClass = "QQ";
  };
}
