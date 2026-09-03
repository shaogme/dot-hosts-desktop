{ pkgs, lib ? pkgs.lib, mkSandboxedApp ? import ../lib/mk-sandboxed-app { inherit pkgs lib; } }:

let
  sources = import ./npins;

  version =
    let
      match = builtins.match ".*/code_([0-9.]+)-.*" sources.vscode.url;
    in
    if match != null then builtins.elemAt match 0
    else throw "vscode: Could not parse version from URL: ${sources.vscode.url}";
in
mkSandboxedApp.electronApp {
  pname = "vscode";
  inherit version;
  src = { deb = sources.vscode; };
  execPath = "share/code/bin/code";

  sandbox = { homeDirs = [ ".config/Code" ".vscode" ]; };

  postUnpackHooks = [
    ''
      mkdir -p $out/share/icons/hicolor/512x512/apps
      if [ -f "$out/share/pixmaps/vscode.png" ]; then
        cp "$out/share/pixmaps/vscode.png" "$out/share/icons/hicolor/512x512/apps/vscode.png"
      fi
    ''
  ];

  icons = { hicolor.auto = true; };

  aliases = [ "code" ];

  desktop = {
    desktopName = "Visual Studio Code";
    genericName = "Text Editor";
    comment = "Code Editing. Redefined. (Bubblewrap Isolated)";
    categories = [ "Development" "IDE" "TextEditor" "Utility" ];
    icon = "vscode";
    startupWMClass = "Code";
    mimeTypes = [
      "text/plain"
      "application/x-code-workspace"
    ];
  };
}
