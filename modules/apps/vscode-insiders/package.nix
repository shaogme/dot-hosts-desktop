{ pkgs, lib ? pkgs.lib, mkSandboxedApp ? import ../lib/mk-sandboxed-app { inherit pkgs lib; } }:

let
  sources = import ./npins;

  version =
    let
      match = builtins.match ".*/code-insiders_([0-9.]+)-.*" sources.vscode-insiders.url;
    in
    if match != null then builtins.elemAt match 0
    else throw "vscode-insiders: Could not parse version from URL: ${sources.vscode-insiders.url}";
in
mkSandboxedApp.electronApp {
  pname = "vscode-insiders";
  inherit version;
  src = { deb = sources.vscode-insiders; };
  execPath = "share/code-insiders/bin/code-insiders";

  sandbox = { homeDirs = [ ".config/Code - Insiders" ".vscode-insiders" ]; };

  postUnpackHooks = [
    ''
      mkdir -p $out/share/icons/hicolor/512x512/apps
      if [ -f "$out/share/pixmaps/vscode-insiders.png" ]; then
        cp "$out/share/pixmaps/vscode-insiders.png" "$out/share/icons/hicolor/512x512/apps/vscode-insiders.png"
      fi
    ''
  ];

  icons = { hicolor.auto = true; };

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
