import ../lib/mk-app-module.nix {
  name = "microsoft-edge";
  description = "Microsoft Edge 网页浏览器";
  package = ./package.nix;
  aliases = [ "edge" "microsoft-edge-stable" ];
  windowRules = [
    {
      match._props = {
        app-id = "^(microsoft-edge|msedge)$";
        title = "^(Picture-in-Picture|Picture in picture|画中画)$";
      };
      open-floating = true;
    }
  ];
}
