import ../lib/mk-app-module.nix {
  name = "firefox";
  description = "Firefox 网页浏览器";
  package = ./package.nix;
  windowRules = [
    {
      match = {
        class = "^(firefox)$";
        title = "^(Picture-in-Picture|画中画)$";
      };
      float = true;
      pin = true;
      keep_aspect_ratio = true;
    }
    {
      match = {
        class = "^(firefox)$";
        title = "^(Library|Opening.*|About Mozilla Firefox|关于 Mozilla Firefox)$";
      };
      float = true;
      center = true;
    }
  ];
}
