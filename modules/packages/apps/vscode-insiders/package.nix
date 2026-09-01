{ pkgs, lib ? pkgs.lib, mkSandboxedApp ? pkgs.callPackage ../lib/mk-sandboxed-app.nix { inherit lib; } }:

let
  sources = import ./npins;

  version =
    let
      match = builtins.match ".*/code-insiders_([0-9.]+)-.*" sources.vscode-insiders.url;
    in
    if match != null then builtins.elemAt match 0
    else throw "vscode-insiders: Could not parse version from URL: ${sources.vscode-insiders.url}";
in
mkSandboxedApp {
  pname = "vscode-insiders";
  inherit version;
  src = sources.vscode-insiders;
  srcType = "deb";
  execPath = "share/code-insiders/bin/code-insiders";

  profiles = [ "desktop-gui" "media" "electron" ];
  sandboxDirs = [ ".config/Code - Insiders" ".vscode-insiders" ];
  hostDirs = [ ".config/Code - Insiders" ".vscode-insiders" ];

  postUnpack = ''
    mkdir -p $out/share/icons/hicolor/512x512/apps
    if [ -f "$out/share/pixmaps/vscode-insiders.png" ]; then
      cp "$out/share/pixmaps/vscode-insiders.png" "$out/share/icons/hicolor/512x512/apps/vscode-insiders.png"
    fi
  '';

  aliases = [ "code-insiders" "vscode-insider" "code-insider" ];

  desktop = {
    desktopName = "Visual Studio Code - Insiders";
    genericName = "Text Editor";
    comment = "Code Editing. Redefined. (Bubblewrap Isolated)";
    categories = [ "Development" "IDE" "TextEditor" "Utility" ];
    icon = "vscode-insiders";
    startupWMClass = "Code - Insiders";
    mimeTypes = [
      "text/plain"
      "application/x-code-insiders-workspace"
    ];
  };
}
