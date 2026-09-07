{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.desktop.storage;

  enabledPaths = filterAttrs (_: p: p.enable) cfg.paths;

  mkTmpfilesRule = p:
    let
      # 确保路径不带多余的尾随斜杠以规范化
      cleanPath = if p.path != "/" && hasSuffix "/" p.path then removeSuffix "/" p.path else p.path;
      ruleD = "d ${cleanPath} ${p.mode} ${p.user} ${p.group} - -";
      ruleZ = "z ${cleanPath} ${p.mode} ${p.user} ${p.group} - -";
      ruleAcl = optional p.acl.enable
        "a+ ${cleanPath} - - - - d:u::rwx,d:g::rwx,d:m::rwx,d:o::r-x";
    in
    [ ruleD ruleZ ] ++ ruleAcl;
in
{
  imports = [
    # 提供顶层 storage 与 desktop.storage 互通别名
    (lib.mkAliasOptionModule [ "storage" ] [ "desktop" "storage" ])
  ];

  options.desktop.storage = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "是否启用自定义存储路径管理模块。";
    };

    group = mkOption {
      type = types.str;
      default = "users";
      description = "跨用户共享存储的默认所属组。默认为 users，确保所有普通用户与 root 均具备读写访问权限。";
    };

    paths = mkOption {
      type = types.attrsOf (types.submodule ({ name, ... }: {
        options = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = "是否启用该存储路径的管理。";
          };

          path = mkOption {
            type = types.str;
            default = name;
            description = "存储目录的绝对路径，例如 /data。";
          };

          user = mkOption {
            type = types.str;
            default = "root";
            description = "存储目录的所有者用户。默认为 root。";
          };

          group = mkOption {
            type = types.str;
            default = cfg.group;
            description = "存储目录的所有者组。默认为 desktop.storage.group (users)。";
          };

          mode = mkOption {
            type = types.str;
            default = "2775";
            description = ''
              存储目录的权限模式。默认为 2775：
              - 包含 setgid 位 (2xxx)，确保在该目录下新建的子目录和文件自动继承父目录的所属组 (users)；
              - 所有者与所属组具备完整读、写、执行权限 (rwx)；
              - 其他用户具备读与执行权限 (r-x)。
            '';
          };

          acl = {
            enable = mkOption {
              type = types.bool;
              default = true;
              description = "是否配置 POSIX 默认 ACL 规则，保证新建文件与目录对所属组均具备读写执行继承权限。";
            };
          };

          shareWithSandbox = mkOption {
            type = types.bool;
            default = true;
            description = "是否将该路径作为共享目录暴露给所有 Bubblewrap 沙箱应用程序。";
          };
        };
      }));
      default = {
        "/data" = { };
      };
      description = "受管的自定义跨用户存储路径配置映射表。";
    };
  };

  config = mkIf cfg.enable {
    # 静态断言：所有配置的路径必须是绝对路径
    assertions = mapAttrsToList (name: p: {
      assertion = hasPrefix "/" p.path;
      message = "desktop.storage: 存储路径 '${p.path}' 必须为绝对路径！";
    }) enabledPaths;

    # 声明式目录与权限管理 (tmpfiles)
    systemd.tmpfiles.rules = flatten (mapAttrsToList (_: mkTmpfilesRule) enabledPaths);

    # 安装 ACL 管理工具，便于诊断与查看权限 (getfacl / setfacl)
    environment.systemPackages = [
      pkgs.acl
    ];
  };
}
