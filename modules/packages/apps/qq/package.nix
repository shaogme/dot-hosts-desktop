{ pkgs, lib ? pkgs.lib, mkSandboxedApp ? pkgs.callPackage ../lib/mk-sandboxed-app.nix { inherit lib; } }:

let
  sources = import ./npins;

  version =
    let
      match = builtins.match ".*/(linuxqq|QQ)_([0-9.-]+)_.*" sources.qq.url;
    in
    if match != null then builtins.elemAt match 1
    else throw "qq: Could not parse version from URL: ${sources.qq.url}";
in
mkSandboxedApp {
  pname = "qq";
  inherit version;
  src = sources.qq;
  srcType = "deb";
  execPath = "opt/QQ/qq";
  runInDirectory = "opt/QQ";

  profiles = [ "desktop-gui" "media" "electron" ];
  sandboxDirs = [ ".config/QQ" ];
  hostDirs = [ ".config/QQ" ];

  preRunHook = ''
    mkdir -p "$HOME/.config/QQ"
    rm -rf "$HOME/.config/QQ/crash_files"/* 2>/dev/null || true
  '';

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
