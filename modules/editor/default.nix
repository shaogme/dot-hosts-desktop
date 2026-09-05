{
  config,
  lib,
  options,
  ...
}:

with lib;

let
  cfg = config.desktop.editor;

  dir = ./.;
  entries = builtins.readDir dir;

  isNixFile = name:
    let len = builtins.stringLength name;
    in len > 4 && builtins.substring (len - 4) 4 name == ".nix";

  # 1. 自动发现包含 default.nix 的文本编辑器子目录
  subDirModules = builtins.filter
    (name: entries.${name} == "directory" && builtins.pathExists (dir + "/${name}/default.nix"))
    (builtins.attrNames entries);

  # 2. 自动发现 editor 目录下的独立模块 .nix 文件 (排除 default.nix 本身)
  singleFileModules = builtins.filter
    (name: entries.${name} == "regular" && isNixFile name && name != "default.nix")
    (builtins.attrNames entries);

  allModuleImports =
    (map (name: dir + "/${name}/default.nix") subDirModules)
    ++ (map (name: dir + "/${name}") singleFileModules);
in
{
  imports = allModuleImports;

  options.desktop.editor = {
    defaultEditor = mkOption {
      type = types.str;
      default = "";
      example = "hx";
      description = "全局系统与桌面环境默认文本编辑器命令（如 hx、nvim、nano 等）。";
    };
  };

  config = mkIf (cfg.defaultEditor != "") (mkMerge [
    {
      environment.sessionVariables = {
        EDITOR = cfg.defaultEditor;
        VISUAL = cfg.defaultEditor;
      };
    }
    (optionalAttrs (options ? home-manager) {
      home-manager = {
        sharedModules = [
          ({ ... }: {
            home.sessionVariables = {
              EDITOR = cfg.defaultEditor;
              VISUAL = cfg.defaultEditor;
            };
          })
        ];
      };
    })
  ]);
}
