import ../lib/mk-app-module.nix {
  name = "qq";
  description = "腾讯 QQ 桌面客户端 (Linux QQ NT)";
  package = ./package.nix;
  aliases = [ "linuxqq" ];
  windowRules = [
    "float, class:^(QQ|qq)$, title:^(图片查看器|音视频通话|转发|设置|关于|快捷反馈|群聊成员|音视频通话.*)$"
    "size 800 600, class:^(QQ|qq)$, title:^(设置|关于)$"
    "stayfocused, class:^(QQ|qq)$, title:^(图片查看器)$"
  ];
}
