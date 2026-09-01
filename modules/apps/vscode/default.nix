import ../lib/mk-app-module.nix {
  name = "vscode";
  description = "Visual Studio Code (VS Code)";
  package = ./package.nix;
  aliases = [ "code" ];
}
