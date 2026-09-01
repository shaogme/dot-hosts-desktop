import ../lib/mk-app-module.nix {
  name = "qq";
  description = "腾讯 QQ 桌面客户端 (Linux QQ NT)";
  package = ./package.nix;
  aliases = [ "linuxqq" ];
}
