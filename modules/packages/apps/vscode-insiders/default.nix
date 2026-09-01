import ../lib/mk-app-module.nix {
  name = "vscode-insiders";
  description = "Visual Studio Code Insiders (VS Code Insiders)";
  package = ./package.nix;
  aliases = [ "code-insiders" "vscode-insider" "code-insider" ];
}
