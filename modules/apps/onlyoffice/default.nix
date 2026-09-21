import ../lib/mk-app-module.nix {
  name = "onlyoffice";
  description = "ONLYOFFICE 桌面办公套件";
  package = ./package.nix;
  aliases = [ "onlyoffice-desktopeditors" "desktopeditors" ];
  windowRules = [
    {
      match._props = {
        app-id = "^(onlyoffice|DesktopEditors)$";
        title = "^(Open Document|Save Document|Print|Options|About|打开文档|保存文档|打印|选项|关于)$";
      };
      open-floating = true;
    }
  ];
}
