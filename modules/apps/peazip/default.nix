{ config, pkgs, lib, ... }:

let
  cfg = config.desktop.apps.peazip;
  peazipPackage = import ./package.nix {
    inherit pkgs lib;
    sevenZip = cfg.sevenZipPackage;
  };
in
(import ../lib/mk-app-module.nix {
  name = "peazip";
  description = "PeaZip 文件压缩与归档管理器";
  package = peazipPackage;
  aliases = [ "PeaZip" ];
  extraOptions = {
    sevenZipPackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.sevenZip or pkgs._7zip-zstd;
      defaultText = lib.literalExpression "pkgs.sevenZip or pkgs._7zip-zstd";
      description = "PeaZip 运行时内部沙箱使用的 7-Zip 引擎实例。";
    };
  };
  windowRules = [
    {
      match._props = {
        app-id = "^(peazip|PeaZip)$";
        title = "^(Password|About|Options|Settings|Extract|Archive|Benchmark|Organize|System benchmark|密码|关于|选项|设置|解压|压缩|归档|性能测试)$";
      };
      open-floating = true;
    }
  ];
}) { inherit config pkgs lib; }
