import ../lib/mk-app-module.nix {
  name = "vscode";
  description = "Visual Studio Code (VS Code)";
  package = ./package.nix;
  aliases = [ "code" ];
  windowRules = [
    "float, class:^(code|Code|vscode)$, title:^(Open Folder|Open File|Save As|Extension:.*)$"
  ];
}
