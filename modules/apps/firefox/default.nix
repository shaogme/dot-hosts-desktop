import ../lib/mk-app-module.nix {
  name = "firefox";
  description = "Firefox 网页浏览器";
  package = ./package.nix;
  windowRules = [
    "float, class:^(firefox)$, title:^(Picture-in-Picture|画中画)$"
    "pin, class:^(firefox)$, title:^(Picture-in-Picture|画中画)$"
    "keepaspectratio, class:^(firefox)$, title:^(Picture-in-Picture|画中画)$"
    "float, class:^(firefox)$, title:^(Library|Opening.*|About Mozilla Firefox|关于 Mozilla Firefox)$"
    "center, class:^(firefox)$, title:^(Library|Opening.*|About Mozilla Firefox|关于 Mozilla Firefox)$"
  ];
}
