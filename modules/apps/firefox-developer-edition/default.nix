import ../lib/mk-app-module.nix {
  name = "firefox-developer-edition";
  description = "Firefox Developer Edition 开发者版浏览器";
  package = ./package.nix;
  aliases = [ "firefox-devedition" ];
  windowRules = [
    {
      match._props = {
        app-id = "^(firefox-developer-edition|firefox-devedition)$";
        title = "^(Picture-in-Picture|画中画)$";
      };
      open-floating = true;
    }
    {
      match._props = {
        app-id = "^(firefox-developer-edition|firefox-devedition)$";
        title = "^(Library|Opening.*|About Mozilla Firefox|关于 Mozilla Firefox)$";
      };
      open-floating = true;
    }
  ];
}
