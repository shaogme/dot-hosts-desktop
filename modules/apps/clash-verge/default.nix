import ../lib/mk-app-module.nix {
  name = "clash-verge";
  description = "Clash Verge Rev GUI 客户端";
  package = ./package.nix;
  windowRules = [
    {
      match = {
        class = "^(clash-verge|clash-verge-rev)$";
        title = "^(Settings|设置|Logs|日志|Profiles|配置)$";
      };
      float = true;
    }
  ];
}
