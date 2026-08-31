let
  rootDir = ../.;
  topEntries = builtins.readDir rootDir;
  
  # 白名单分类目录（与 .github/scripts/get-hosts.sh 保持一致）
  categories = [ "hosts" ];

  # 获取所有包含 configuration.nix 的主机项
  hostList = builtins.concatLists (map (category:
    let
      catPath = rootDir + "/${category}";
      catEntries = if builtins.pathExists catPath then builtins.readDir catPath else {};
    in
    builtins.concatLists (map (hostName:
      let
        hostDirPath = catPath + "/${hostName}";
        isDir = catEntries.${hostName} == "directory";
        hasConfig = isDir && builtins.pathExists (hostDirPath + "/configuration.nix");
      in
      if hasConfig then [{
        name = hostName;
        relPath = "${category}/${hostName}";
        dirPath = hostDirPath;
      }] else []
    ) (builtins.attrNames catEntries))
  ) categories);

  # 为单个主机生成静态和运行时测试
  makeHostTests = item:
    let
      sources = import (item.dirPath + "/npins");
      pkgs = import sources.nixpkgs {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };
      configuration = item.dirPath + "/configuration.nix";
    in
    {
      # 静态检查
      staticCheck = import ./static.nix { inherit pkgs configuration; name = item.name; };

      # 虚拟机集成测试
      vmTest = import ./vmtest.nix { inherit pkgs configuration; name = item.name; };
    };

  # 构建映射字典，同时支持主机简称 (如 "home-7950x") 和相对路径 (如 "hosts/home-7950x")
  allTests = builtins.listToAttrs (
    builtins.concatLists (map (item: [
      { name = item.name; value = makeHostTests item; }
      { name = item.relPath; value = makeHostTests item; }
    ]) hostList)
  );
in
allTests
