import ../lib/mk-app-module.nix {
  name = "peazip";
  description = "PeaZip 文件压缩与归档管理器";
  package = ./package.nix;
  aliases = [ "PeaZip" ];
  windowRules = [
    {
      match._props = {
        app-id = "^(peazip|PeaZip)$";
        title = "^(Password|About|Options|Settings|Extract|Archive|Benchmark|Organize|System benchmark|密码|关于|选项|设置|解压|压缩|归档|性能测试)$";
      };
      open-floating = true;
    }
  ];
}
