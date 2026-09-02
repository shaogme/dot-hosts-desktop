import ../lib/mk-app-module.nix {
  name = "qq";
  description = "腾讯 QQ 桌面客户端 (Linux QQ NT)";
  package = ./package.nix;
  aliases = [ "linuxqq" ];
  windowRules = [
    {
      match = {
        class = "^(QQ|qq)$";
        title = "^(图片查看器|音视频通话|转发|设置|关于|快捷反馈|群聊成员|音视频通话.*)$";
      };
      float = true;
    }
    {
      match = {
        class = "^(QQ|qq)$";
        title = "^(设置|关于)$";
      };
      size = "800 600";
    }
    {
      match = {
        class = "^(QQ|qq)$";
        title = "^(图片查看器)$";
      };
      stay_focused = true;
    }
  ];
}
