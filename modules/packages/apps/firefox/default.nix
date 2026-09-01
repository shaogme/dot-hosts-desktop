import ../lib/mk-app-module.nix {
  name = "firefox";
  description = "Firefox 网页浏览器";
  package = ./package.nix;
}
