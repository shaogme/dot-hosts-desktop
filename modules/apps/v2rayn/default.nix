import ../lib/mk-app-module.nix {
  name = "v2rayn";
  description = "v2rayN GUI 桌面应用程序";
  package = ./package.nix;
  windowRules = [
    {
      match = {
        class = "^(v2rayn|v2rayN)$";
        title = "^(Settings|设置|Add.*|Edit.*|添加.*|编辑.*|Routing.*|路由.*|Promote.*|提示.*)$";
      };
      float = true;
    }
  ];
}
