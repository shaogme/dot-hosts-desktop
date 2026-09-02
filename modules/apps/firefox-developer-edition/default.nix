import ../lib/mk-app-module.nix {
  name = "firefox-developer-edition";
  description = "Firefox Developer Edition 开发者版浏览器";
  package = ./package.nix;
  aliases = [ "firefox-devedition" ];
  windowRules = [
    {
      match = {
        class = "^(firefox-developer-edition|firefox-devedition)$";
        title = "^(Picture-in-Picture|画中画)$";
      };
      float = true;
      pin = true;
      keep_aspect_ratio = true;
    }
    {
      match = {
        class = "^(firefox-developer-edition|firefox-devedition)$";
        title = "^(Library|Opening.*|About Mozilla Firefox|关于 Mozilla Firefox)$";
      };
      float = true;
      center = true;
    }
  ];
}
