import ../lib/mk-app-module.nix {
  name = "wine";
  description = "Wine Windows 兼容运行环境（Bubblewrap 沙箱隔离）";
  package = ./package.nix;
  aliases = [ "wine-sandboxed" "wine-box" ];
  windowRules = [
    {
      match._props = {
        app-id = "^(wine|winecfg|winefile|explorer.exe)$";
      };
      open-floating = true;
    }
  ];
}
