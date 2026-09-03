import ../lib/mk-app-module.nix {
  name = "qq";
  description = "腾讯 QQ 桌面客户端 (Linux QQ NT)";
  package = ./package.nix;
  aliases = [ "linuxqq" ];
  windowRules = [
    {
      match._props = {
        app-id = "^(QQ|qq)$";
        title = "^(图片查看器|音视频通话|转发|设置|关于|快捷反馈|群聊成员|音视频通话.*)$";
      };
      open-floating = true;
    }
    {
      match._props = {
        app-id = "^(QQ|qq)$";
        title = "^(设置|关于)$";
      };
      default-column-width = { fixed = 800; };
      default-window-height = { fixed = 600; };
    }
    {
      match._props = {
        app-id = "^(QQ|qq)$";
        title = "^(图片查看器)$";
      };
      open-focused = true;
    }
  ];
}
