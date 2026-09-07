import ../lib/mk-app-module.nix {
  name = "microsoft-edge-dev";
  description = "Microsoft Edge Dev 开发者版浏览器";
  package = ./package.nix;
  aliases = [ "edge-dev" ];
  windowRules = [
    {
      match._props = {
        app-id = "^(microsoft-edge-dev|msedge-dev)$";
        title = "^(Picture-in-Picture|Picture in picture|画中画)$";
      };
      open-floating = true;
    }
  ];
}
