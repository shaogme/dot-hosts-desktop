import ../lib/mk-app-module.nix {
  name = "firefox";
  description = "Firefox 网页浏览器";
  package = ./package.nix;
  windowRules = [
    {
      match._props = {
        app-id = "^(firefox)$";
        title = "^(Picture-in-Picture|画中画)$";
      };
      open-floating = true;
    }
    {
      match._props = {
        app-id = "^(firefox)$";
        title = "^(Library|Opening.*|About Mozilla Firefox|关于 Mozilla Firefox)$";
      };
      open-floating = true;
    }
  ];
}
