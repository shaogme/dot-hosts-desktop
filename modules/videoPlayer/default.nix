{ ... }:

let
  dir = ./.;
  entries = builtins.readDir dir;

  isNixFile = name:
    let len = builtins.stringLength name;
    in len > 4 && builtins.substring (len - 4) 4 name == ".nix";

  # 1. 自动发现包含 default.nix 的视频播放器子模块目录 (如 mpv/)
  subDirModules = builtins.filter
    (name: entries.${name} == "directory" && builtins.pathExists (dir + "/${name}/default.nix"))
    (builtins.attrNames entries);

  # 2. 自动发现 videoPlayer 目录下的独立模块 .nix 文件 (排除 default.nix 本身)
  singleFileModules = builtins.filter
    (name: entries.${name} == "regular" && isNixFile name && name != "default.nix")
    (builtins.attrNames entries);

  allModuleImports =
    (map (name: dir + "/${name}/default.nix") subDirModules)
    ++ (map (name: dir + "/${name}") singleFileModules);
in
{
  imports = allModuleImports;
}
