import ../lib/mk-app-module.nix {
  name = "firefox-developer-edition";
  description = "Firefox Developer Edition 开发者版浏览器";
  package = ./package.nix;
  aliases = [ "firefox-devedition" ];
}
