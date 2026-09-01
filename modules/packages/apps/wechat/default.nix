import ../lib/mk-app-module.nix {
  name = "wechat";
  description = "微信桌面客户端 (WeChat Universal)";
  package = ./package.nix;
  aliases = [ "wechat-universal" "weixin" ];
}
