{ ... }:

let
  dir = ./.;
  entries = builtins.readDir dir;

  isNixFile = name:
    let len = builtins.stringLength name;
    in len > 4 && builtins.substring (len - 4) 4 name == ".nix";

  subDirModules = builtins.filter
    (name: entries.${name} == "directory" && builtins.pathExists (dir + "/${name}/default.nix"))
    (builtins.attrNames entries);

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
