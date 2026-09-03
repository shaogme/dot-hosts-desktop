import ../lib/mk-app-module.nix {
  name = "vscode";
  description = "Visual Studio Code (VS Code)";
  package = ./package.nix;
  aliases = [ "code" ];
  windowRules = [
    {
      match._props = {
        app-id = "^(code|Code|vscode)$";
        title = "^(Open Folder|Open File|Save As|Extension:.*)$";
      };
      open-floating = true;
    }
  ];
}
