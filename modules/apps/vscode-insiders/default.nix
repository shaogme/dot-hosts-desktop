import ../lib/mk-app-module.nix {
  name = "vscode-insiders";
  description = "Visual Studio Code Insiders (VS Code Insiders)";
  package = ./package.nix;
  aliases = [ "code-insiders" "vscode-insider" "code-insider" ];
  windowRules = [
    {
      match._props = {
        app-id = "^(code-insiders|Code - Insiders|vscode-insiders)$";
        title = "^(Open Folder|Open File|Save As|Extension:.*)$";
      };
      open-floating = true;
    }
  ];
}
