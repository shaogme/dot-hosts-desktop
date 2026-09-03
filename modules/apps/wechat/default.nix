import ../lib/mk-app-module.nix {
  name = "wechat";
  description = "微信桌面客户端 (WeChat Universal)";
  package = ./package.nix;
  aliases = [ "wechat-universal" "weixin" ];
  windowRules = [
    {
      match._props = {
        app-id = "^(wechat|com\\.tencent\\.wechat)$";
        title = "^(微信|WeChat|登录)$";
      };
      open-floating = true;
    }
    {
      match._props = {
        app-id = "^(wechat|com\\.tencent\\.wechat)$";
        title = "^(图片查看|预览|设置|关于微信|意见反馈|聊天记录备份与迁移|ChatContactMenu|chat_menu)$";
      };
      open-floating = true;
    }
    {
      match._props = {
        app-id = "^(wechat|com\\.tencent\\.wechat)$";
        title = "^(ChatContactMenu|chat_menu)$";
      };
      open-focused = true;
    }
  ];
}
