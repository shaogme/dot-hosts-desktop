import ../lib/mk-app-module.nix {
  name = "telegram-desktop";
  description = "Telegram Desktop 即时通讯客户端";
  package = ./package.nix;
  aliases = [ "telegram" ];
  windowRules = [
    {
      match._props = {
        app-id = "^(org\\.telegram\\.desktop|TelegramDesktop)$";
        title = "^(Media viewer|媒体查看器)$";
      };
      open-floating = true;
    }
  ];
}
